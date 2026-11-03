#Requires -Version 5.1
[CmdletBinding()]
param([switch]$PreflightOnly, [ValidateRange(60,1800)][int]$StartupTimeoutSeconds = 900,
    [ValidateRange(60,1200)][int]$NavigationTimeoutSeconds = 900, [string]$FirewallLease,
    [ValidateRange(0,300)][int]$DiagnosticHoldSeconds = 0)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ProbeSafety.ps1')
. (Join-Path $PSScriptRoot 'ProbeCache.ps1')
. (Join-Path $PSScriptRoot 'ProbeFirewall.ps1')
Initialize-ProbeUtf8
$repo = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$source = Join-Path $repo 'Server\rustds'
$runId = [Guid]::NewGuid().ToString('N')
$runtime = Join-Path $repo ('.local\runtime\' + $runId)
$install = Join-Path $runtime 'install'
$owned = $null
$cache = $null
$ownsLease = $false
$leaseReservation = $null
$oldTestRoot = $env:RUST_BOTS_TEST_ROOT
$oldToken = $env:RUST_BOTS_RUN_TOKEN
$oldIdentity = $env:RUST_BOTS_TEST_IDENTITY
$clock = [Diagnostics.Stopwatch]::StartNew()
$report = [ordered]@{
    Status = 'BLOCKED'; Reason = ''; RunId = $runId; ServerPid = $null
    StartedUtc = $null; ReadySeconds = $null; PluginSeconds = $null
    Timeline = @(); Navigation = 'NOT_VERIFIED'; Shutdown = 'NOT_STARTED'
    OwnedProcessAbsent = $true; PortsReleased = $null; FirewallRemoved = $true
    Cache = $null; ServerExitCode = $null; RunnerElevated = $false
}
$ports = @(28965,28966,28967,28968)

function Assert-NoForeignRust {
    if (@(Get-Process -Name RustDedicated,RustClient,Rust,steamcmd -ErrorAction SilentlyContinue).Count) {
        throw 'BLOCKED: foreign Rust or SteamCMD process present; no shutdown attempted'
    }
}
function Assert-PortsFree {
    $tcp = @(Get-NetTCPConnection -ErrorAction Stop | Where-Object { $_.LocalPort -in $ports })
    $udp = @(Get-NetUDPEndpoint -ErrorAction Stop | Where-Object { $_.LocalPort -in $ports })
    if ($tcp.Count + $udp.Count) { throw 'BLOCKED: test ports occupied; no foreign shutdown attempted' }
}
function Save-Report {
    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $runtime 'result.json') -Encoding UTF8
}

try {
    # Check links before the first write, including the ignored parent directories.
    Assert-ProbePlainPath $repo
    foreach ($path in @((Join-Path $repo '.local'),(Join-Path $repo '.local\runtime'))) {
        if (Test-Path -LiteralPath $path) { Assert-ProbePlainPath $path }
    }
    New-Item -ItemType Directory -Path $runtime | Out-Null
    Assert-NoForeignRust
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $report.RunnerElevated = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    Assert-PortsFree
    foreach ($required in @('RustDedicated.exe','RustDedicated_Data\Managed\Assembly-CSharp.dll','RustDedicated_Data\Managed\Oxide.Rust.dll','Oxide.Compiler.exe')) {
        if (-not (Test-Path -LiteralPath (Join-Path $source $required))) { throw "BLOCKED: installed runtime component missing: $required" }
    }
    Assert-ProbePlainPath $source
    # Never copy the owner's writable/configuration trees.
    $copyDirs = @('RustDedicated_Data','Bundles','MonoBleedingEdge')
    foreach ($dir in $copyDirs) {
        $path = Join-Path $source $dir
        Assert-ProbePlainTree $path
    }
    $copyFiles = @(Get-ChildItem -LiteralPath $source -File | Where-Object { $_.Extension -in @('.exe','.dll') })
    foreach ($file in $copyFiles) { Assert-ProbePlainPath $file.FullName }
    if ($PreflightOnly) {
        $report.Status = 'PARTIAL'; $report.Reason = 'Preflight passed; live firewall delegation/cache/start not requested'
    } else {
        $cache = Initialize-ProbeCache $repo $source $runtime
        $install = $cache.Install
        $report.Cache = @{ Key=$cache.Compatibility.Key; State=$cache.WorldStatus; InvalidReason=$cache.InvalidReason; Promoted=$false }
        Assert-ProbePlainTree $install
        Copy-Item -LiteralPath (Join-Path $repo 'src\plugins\RustBotsNavigationProbe.cs') -Destination (Join-Path $install 'oxide\plugins')
        $env:RUST_BOTS_TEST_ROOT = $install
        $env:RUST_BOTS_RUN_TOKEN = $runId
        $env:RUST_BOTS_TEST_IDENTITY = $cache.Identity
        [IO.File]::WriteAllText((Join-Path $install 'rustbots-test.marker'), $runId)
        $bytes = New-Object byte[] 32
        $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
        try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
        $password = [Convert]::ToBase64String($bytes)
        @{ RconPassword = $password } | ConvertTo-Json | Set-Content (Join-Path $runtime 'secrets.json') -Encoding UTF8
        $report.FirewallRemoved = $null
        if (-not $FirewallLease) { $FirewallLease = Start-ProbeFirewallLease $repo $install; $ownsLease = $true }
        $leaseReservation = Open-ProbeFirewallReservation $FirewallLease
        $null = Assert-ProbeFirewallLease $FirewallLease $install
        $report.FirewallRemoved = $false
        $report['FirewallLease'] = $FirewallLease
        Assert-NoForeignRust
        Assert-PortsFree
        Add-Type -Path (Join-Path $PSScriptRoot 'OwnedServerProcess.cs')
        $log = Join-Path $runtime 'server.log'
        $arguments = '-batchmode -nographics -logfile "' + $log + '"' +
            ' +server.identity ' + $cache.Identity + ' +server.hostname "Local navigation probe"' +
            ' +server.ip 127.0.0.1 +server.port 28965 +server.queryport 28967' +
            ' +rcon.ip 127.0.0.1 +rcon.port 28966 +rcon.web 1 +rcon.password "' + $password + '"' +
            ' +app.listenip 127.0.0.1 +app.port 28968 +server.maxplayers 1' +
            ' +server.level "Procedural Map" +server.seed 424242 +server.worldsize 2000'
        $clock.Restart()
        $owned = [RustBots.OwnedServerProcess]::Start((Join-Path $install 'RustDedicated.exe'), $arguments, $install)
        $report.ServerPid = $owned.Process.Id
        $report.StartedUtc = [DateTime]::UtcNow.ToString('o')
        $report.OwnedProcessAbsent = $false
        $report.Shutdown = 'PENDING'
        Save-Report
        $seen = @{}
        $navigationDeadline = $null
        while ($true) {
            if ($owned.Process.HasExited) { throw 'BLOCKED: test server exited before completed probe' }
            $content = Read-ProbeLog $log
            foreach ($phase in @('Loading Oxide','Loading World','Spawning World','Processing World','Finalizing World','Navmesh Build','Server startup complete','RUSTBOTS_READY')) {
                if (-not $seen.ContainsKey($phase) -and $content.Contains($phase)) {
                    $seen[$phase] = $true
                    $report.Timeline += [pscustomobject]@{ Phase = $phase; ObservedSeconds = [Math]::Round($clock.Elapsed.TotalSeconds,2) }
                }
            }
            if ($seen.ContainsKey('Server startup complete') -and $null -eq $report.ReadySeconds) { $report.ReadySeconds = $clock.Elapsed.TotalSeconds }
            if ($seen.ContainsKey('RUSTBOTS_READY') -and $null -eq $report.PluginSeconds) { $report.PluginSeconds = $clock.Elapsed.TotalSeconds }
            if ($null -ne $report.ReadySeconds -and $null -ne $report.PluginSeconds -and $null -eq $navigationDeadline) {
                $navigationDeadline = $clock.Elapsed.TotalSeconds + $NavigationTimeoutSeconds
            }
            $navFile = Join-Path $install 'oxide\data\RustBotsNavigationProbe.result.json'
            if ($navigationDeadline -and (Test-Path -LiteralPath $navFile)) {
                $nav = Get-Content -LiteralPath $navFile -Raw | ConvertFrom-Json
                if ($nav.RunId -ne $runId) { throw 'BLOCKED: navigation result run token mismatch' }
                Assert-ProbeNavigationResult $nav
                $report.Navigation = $nav
                $report.Status = $nav.Status
                $report.Reason = $nav.Reason
                if ($nav.Status -ne 'GREEN' -and $DiagnosticHoldSeconds -gt 0) {
                    Save-Report
                    Write-Host ('Diagnostic hold for '+$DiagnosticHoldSeconds+' seconds; owned server will still stop automatically.')
                    $holdUntil = [DateTime]::UtcNow.AddSeconds($DiagnosticHoldSeconds)
                    while ([DateTime]::UtcNow -lt $holdUntil -and -not $owned.Process.HasExited) {
                        if (Test-Path (Join-Path $runtime 'end-diagnostic-hold.request')) { break }
                        Start-Sleep -Seconds 1
                    }
                }
                break
            }
            if ((-not $navigationDeadline -and $clock.Elapsed.TotalSeconds -gt $StartupTimeoutSeconds) -or
                ($navigationDeadline -and $clock.Elapsed.TotalSeconds -gt $navigationDeadline)) {
                throw 'BLOCKED: bounded readiness/navigation timeout; inspect local logs'
            }
            Start-Sleep -Seconds 1
        }
    }
} catch {
    $report.Status = 'BLOCKED'
    $report.Reason = $_.Exception.Message
    $report['Exception'] = $_.Exception.ToString()
    Write-Warning $_.Exception.ToString()
} finally {
    try {
        if ($owned) {
            try {
                if (-not $owned.Process.HasExited) {
                    # Plugin owns the only graceful quit path; command file is test-root scoped.
                    [IO.File]::WriteAllText((Join-Path $install 'rustbots-stop.request'), $runId)
                    if ($owned.Process.WaitForExit(30000)) { $report.Shutdown = 'GRACEFUL' }
                    else { $report.Shutdown = 'FORCED_OWNED_JOB' }
                } else { $report.Shutdown = 'ALREADY_EXITED' }
            } finally {
                $owned.Dispose()
                $report.OwnedProcessAbsent = $owned.Process.HasExited
                $report.ServerExitCode = $owned.Process.ExitCode
            }
            try { Assert-PortsFree; $report.PortsReleased = $true } catch { $report.PortsReleased = $false }
            if ($cache -and (Test-ProbeCompletedSave $report (Read-ProbeLog $log))) {
                try { Save-ProbeWorldCache $cache $cache.World; $report.Cache.Promoted = $true }
                catch { Write-Warning $_.Exception.ToString(); $report.Cache['PromotionError']=$_.Exception.Message; if ($report.Status -eq 'GREEN') { $report.Status='PARTIAL'; $report.Reason='Navigation passed; cache promotion failed' } }
            }
        }
    } catch {
        $report.Status = 'FAILED'; $report.Reason = 'Owned-process cleanup failed: ' + $_.Exception.Message
    } finally {
        if ($leaseReservation) { $leaseReservation.Dispose() }
        if ($report.OwnedProcessAbsent -and $ownsLease) {
            try { Stop-ProbeFirewallLease $FirewallLease; $report.FirewallRemoved=$true }
            catch { $report.Status='FAILED'; $report.Reason='Test firewall cleanup failed'; Write-Warning $_.Exception.ToString() }
        }
        if ($cache) { $cache.Lock.Dispose() }
        $env:RUST_BOTS_TEST_ROOT = $oldTestRoot
        $env:RUST_BOTS_RUN_TOKEN = $oldToken
        $env:RUST_BOTS_TEST_IDENTITY = $oldIdentity
        if (-not $report.OwnedProcessAbsent -or $report.PortsReleased -eq $false) { $report.Status = 'FAILED' }
        if (Test-Path -LiteralPath $runtime) { Save-Report }
        Write-Output ($report.Status + ': ' + $report.Reason)
        Write-Output ('Local evidence: .local/runtime/' + $runId + '/result.json')
    }
}
if ($report.Status -eq 'GREEN') { exit 0 }
if ($report.Status -eq 'PARTIAL') { exit 1 }
exit 2
