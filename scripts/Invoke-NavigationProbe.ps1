#Requires -Version 5.1
[CmdletBinding()]
param([switch]$PreflightOnly, [ValidateRange(60,1800)][int]$StartupTimeoutSeconds = 900)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ProbeSafety.ps1')
$repo = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$source = Join-Path $repo 'Server\rustds'
$runId = [Guid]::NewGuid().ToString('N')
$runtime = Join-Path $repo ('.local\runtime\' + $runId)
$install = Join-Path $runtime 'install'
$rules = New-Object 'Collections.Generic.List[string]'
$owned = $null
$oldTestRoot = $env:RUST_BOTS_TEST_ROOT
$oldToken = $env:RUST_BOTS_RUN_TOKEN
$clock = [Diagnostics.Stopwatch]::StartNew()
$report = [ordered]@{
    Status = 'BLOCKED'; Reason = ''; RunId = $runId; ServerPid = $null
    StartedUtc = $null; ReadySeconds = $null; PluginSeconds = $null
    Timeline = @(); Navigation = 'NOT_VERIFIED'; Shutdown = 'NOT_STARTED'
    OwnedProcessAbsent = $true; PortsReleased = $null; FirewallRemoved = $true
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
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'BLOCKED: administrator rights required for verified per-test firewall isolation; server not started'
    }
    $profiles = @(Get-NetFirewallProfile -PolicyStore ActiveStore)
    if ($profiles.Count -ne 3 -or @($profiles | Where-Object { -not $_.Enabled -or $_.AllowLocalFirewallRules -eq 'False' }).Count) {
        throw 'BLOCKED: effective firewall profiles cannot enforce local block rules'
    }
    Assert-PortsFree
    foreach ($required in @('RustDedicated.exe','RustDedicated_Data\Managed\Assembly-CSharp.dll','RustDedicated_Data\Managed\Oxide.Rust.dll','Oxide.Compiler.exe')) {
        if (-not (Test-Path -LiteralPath (Join-Path $source $required))) { throw "BLOCKED: installed runtime component missing: $required" }
    }
    Assert-ProbePlainPath $source
    # Fresh real copies only. Never copy the owner's writable/configuration trees.
    $copyDirs = @('RustDedicated_Data','Bundles','MonoBleedingEdge')
    foreach ($dir in $copyDirs) {
        $path = Join-Path $source $dir
        Assert-ProbePlainTree $path
    }
    $copyFiles = @(Get-ChildItem -LiteralPath $source -File | Where-Object { $_.Extension -in @('.exe','.dll') })
    foreach ($file in $copyFiles) { Assert-ProbePlainPath $file.FullName }
    if ($PreflightOnly) {
        $report.Status = 'PARTIAL'; $report.Reason = 'Preflight passed; live install/start not requested'
    } else {
        New-Item -ItemType Directory -Path $install | Out-Null
        foreach ($dir in $copyDirs) { Copy-Item -LiteralPath (Join-Path $source $dir) -Destination $install -Recurse }
        $copyFiles | Copy-Item -Destination $install
        foreach ($dir in @('oxide\plugins','oxide\config','oxide\data','oxide\logs','server','cfg','config','logs')) {
            New-Item -ItemType Directory -Path (Join-Path $install $dir) -Force | Out-Null
        }
        if (@(Get-ChildItem -LiteralPath $install -Recurse -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count) {
            throw 'BLOCKED: test install has linked entries'
        }
        Copy-Item -LiteralPath (Join-Path $repo 'src\plugins\RustBotsNavigationProbe.cs') -Destination (Join-Path $install 'oxide\plugins')
        $env:RUST_BOTS_TEST_ROOT = $install
        $env:RUST_BOTS_RUN_TOKEN = $runId
        [IO.File]::WriteAllText((Join-Path $install 'rustbots-test.marker'), $runId)
        $bytes = New-Object byte[] 32
        $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
        try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
        $password = [Convert]::ToBase64String($bytes)
        @{ RconPassword = $password } | ConvertTo-Json | Set-Content (Join-Path $runtime 'secrets.json') -Encoding UTF8
        # Block every copied executable, including the compiler and crash helper.
        # Loopback bindings are additional protection, not a substitute for egress denial.
        foreach ($exe in @(Get-ChildItem -LiteralPath $install -Filter '*.exe' -Recurse)) {
            foreach ($direction in @('Inbound','Outbound')) {
                $name = 'RustBots001-' + $runId + '-' + $rules.Count
                $rules.Add($name)
                New-NetFirewallRule -Name $name -DisplayName $name -Program $exe.FullName -Direction $direction -Action Block -Enabled True -Profile Any | Out-Null
                $active = Get-NetFirewallRule -PolicyStore ActiveStore -Name $name
                $program = $active | Get-NetFirewallApplicationFilter
                if ($active.Action -ne 'Block' -or $active.Enabled -ne 'True' -or $program.Program -ne $exe.FullName) {
                    throw 'BLOCKED: effective test firewall rule mismatch'
                }
            }
        }
        Assert-NoForeignRust
        Assert-PortsFree
        Add-Type -Path (Join-Path $PSScriptRoot 'OwnedServerProcess.cs')
        $log = Join-Path $runtime 'server.log'
        $arguments = '-batchmode -nographics -logfile "' + $log + '"' +
            ' +server.identity rustbots_probe_' + $runId + ' +server.hostname "Local navigation probe"' +
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
                $navigationDeadline = $clock.Elapsed.TotalSeconds + 300
            }
            $navFile = Join-Path $install 'oxide\data\RustBotsNavigationProbe.result.json'
            if ($navigationDeadline -and (Test-Path -LiteralPath $navFile)) {
                $nav = Get-Content -LiteralPath $navFile -Raw | ConvertFrom-Json
                if ($nav.RunId -ne $runId) { throw 'BLOCKED: navigation result run token mismatch' }
                Assert-ProbeNavigationResult $nav
                $report.Navigation = $nav
                $report.Status = $nav.Status
                $report.Reason = $nav.Reason
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
            }
            try { Assert-PortsFree; $report.PortsReleased = $true } catch { $report.PortsReleased = $false }
        }
    } catch {
        $report.Status = 'FAILED'; $report.Reason = 'Owned-process cleanup failed: ' + $_.Exception.Message
    } finally {
        # Keep network denial in place if process absence cannot be proven.
        if ($report.OwnedProcessAbsent) {
            foreach ($name in $rules) {
                try {
                    Remove-NetFirewallRule -Name $name -ErrorAction Stop
                    if (Get-NetFirewallRule -Name $name -ErrorAction SilentlyContinue) { throw 'Firewall rule remains' }
                } catch { $report.FirewallRemoved = $false; $report.Status = 'FAILED'; $report.Reason = 'Test firewall cleanup failed' }
            }
        }
        $env:RUST_BOTS_TEST_ROOT = $oldTestRoot
        $env:RUST_BOTS_RUN_TOKEN = $oldToken
        if (-not $report.OwnedProcessAbsent -or $report.PortsReleased -eq $false) { $report.Status = 'FAILED' }
        if (Test-Path -LiteralPath $runtime) { Save-Report }
        Write-Output ($report.Status + ': ' + $report.Reason)
        Write-Output ('Local evidence: .local/runtime/' + $runId + '/result.json')
    }
}
if ($report.Status -eq 'GREEN') { exit 0 }
if ($report.Status -eq 'PARTIAL') { exit 1 }
exit 2
