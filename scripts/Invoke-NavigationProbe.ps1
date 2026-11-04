#Requires -Version 5.1
[CmdletBinding()]
param([switch]$PreflightOnly, [ValidateRange(60,1800)][int]$StartupTimeoutSeconds = 900,
    [ValidateRange(60,1200)][int]$NavigationTimeoutSeconds = 900, [string]$FirewallLease,
    [ValidateRange(0,300)][int]$DiagnosticHoldSeconds = 0, [switch]$WorldRoam,
    [ValidatePattern('^[0-9a-f]{32}$')][string]$RestoreFrom, [switch]$ResumeJourney, [switch]$SurvivalGather, [switch]$SurvivalCraft, [switch]$PlayerAvatar, [switch]$AvatarSurvival, [switch]$WorldEconomy)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ProbeSafety.ps1')
. (Join-Path $PSScriptRoot 'ProbeCache.ps1')
. (Join-Path $PSScriptRoot 'ProbeFirewall.ps1')
. (Join-Path $PSScriptRoot 'WorldRoamValidation.ps1')
. (Join-Path $PSScriptRoot 'SurvivalValidation.ps1')
. (Join-Path $PSScriptRoot 'CraftValidation.ps1')
. (Join-Path $PSScriptRoot 'AvatarValidation.ps1')
. (Join-Path $PSScriptRoot 'AvatarSurvivalValidation.ps1')
. (Join-Path $PSScriptRoot 'EconomyValidation.ps1')
if($WorldEconomy){if($AvatarSurvival){throw 'WorldEconomy already selects AvatarSurvival'};$AvatarSurvival=$true}
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
$oldScenario = $env:RUST_BOTS_SCENARIO
$oldRestore = $env:RUST_BOTS_RESTORE
$oldResume = $env:RUST_BOTS_RESUME_JOURNEY
$oldEconomy=$env:RUST_BOTS_WORLD_ECONOMY
$isSurvival = $SurvivalGather -or $SurvivalCraft
$scenario = if ($AvatarSurvival) {'AVATAR_SURVIVAL'} elseif ($PlayerAvatar) {'PLAYER_AVATAR'} elseif ($SurvivalCraft) {'SURVIVAL_CRAFT'} elseif ($SurvivalGather) {'SURVIVAL_GATHER'} elseif ($WorldRoam) {'WORLD_ROAM'} else {'NAVIGATION'}
$pluginName = if ($AvatarSurvival) {'RustBotsAvatarSurvival'} elseif ($PlayerAvatar) {'RustBotsAvatarProbe'} elseif ($isSurvival) { 'RustBotsSurvival' } elseif ($WorldRoam) { 'RustBotsWorldRoam' } else { 'RustBotsNavigationProbe' }
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
    if (([int][bool]$SurvivalGather+[int][bool]$SurvivalCraft+[int][bool]$WorldRoam+[int][bool]$PlayerAvatar+[int][bool]$AvatarSurvival) -gt 1 -or (($isSurvival -or $PlayerAvatar -or $AvatarSurvival) -and $ResumeJourney)) { throw 'Probe scenario modes are exclusive; avatar/survival do not support ResumeJourney' }
    if ($RestoreFrom -and -not ($WorldRoam -or $isSurvival -or $AvatarSurvival)) { throw 'RestoreFrom requires WorldRoam or Survival mode' }
    if ($ResumeJourney -and -not $RestoreFrom) { throw 'ResumeJourney requires RestoreFrom' }
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
        if($WorldEconomy -and $cache.WorldStatus -ne 'WARM'){throw 'WorldEconomy requires an exact verified warm world; no speculative live start'}
        if (($isSurvival -or $AvatarSurvival) -and $cache.WorldStatus -eq 'WARM') {
            $loadedManifest=Get-Content (Join-Path $cache.Root 'world-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
            $report.Cache['LoadedGeneration']=$loadedManifest.Generation
            $report.Cache['LoadedSaveSHA256']=@($loadedManifest.Files | Where-Object { $_.Name -match '\.sav$' })[0].SHA256
        }
        Assert-ProbePlainTree $install
        Copy-Item -LiteralPath (Join-Path $repo ('src\plugins\'+$pluginName+'.cs')) -Destination (Join-Path $install 'oxide\plugins')
        if($AvatarSurvival){
            $pluginPath=Join-Path $install ('oxide\plugins\'+$pluginName+'.cs')
            [IO.File]::AppendAllText($pluginPath,[Environment]::NewLine+[IO.File]::ReadAllText((Join-Path $repo 'src\economy\EconomyJournal.cs')),[Text.Encoding]::UTF8)
        }
        Copy-Item -LiteralPath (Join-Path $repo ('src\plugins\'+$pluginName+'.cs')) -Destination (Join-Path $runtime ($pluginName+'.cs'))
        if($AvatarSurvival){Copy-Item -LiteralPath $pluginPath -Destination (Join-Path $runtime ($pluginName+'.cs')) -Force}
        $report['PluginSHA256']=(Get-FileHash -LiteralPath (Join-Path $runtime ($pluginName+'.cs')) -Algorithm SHA256).Hash
        $report['Scenario']=$scenario
        $env:RUST_BOTS_TEST_ROOT = $install
        $env:RUST_BOTS_RUN_TOKEN = $runId
        $env:RUST_BOTS_TEST_IDENTITY = $cache.Identity
        $env:RUST_BOTS_SCENARIO = $scenario
        $env:RUST_BOTS_RESTORE = if ($RestoreFrom) { '1' } else { '' }
        $env:RUST_BOTS_RESUME_JOURNEY = if ($ResumeJourney) { '1' } else { '' }
        $env:RUST_BOTS_WORLD_ECONOMY=if($WorldEconomy){'1'}else{''}
        if($WorldEconomy){
            $map=@($loadedManifest.Files|Where-Object Name -match '\.map$')
            if($map.Count -ne 1){throw 'Missing exact economy map identity'}
            if($map[0].Name -notmatch '\.([0-9]+)\.map$'){throw 'Unknown test map format'}
            $report['EconomyMap']=@{Kind='PROCEDURAL';Level=$cache.Compatibility.Description.Level;Seed=$cache.Compatibility.Seed;Size=$cache.Compatibility.Size;MapVersion=$matches[1];MapSHA256=$map[0].SHA256}
            $report['WorldEconomy']=$true
        }
        if ($RestoreFrom) {
            $priorRoot = Join-Path $repo ('.local\runtime\'+$RestoreFrom)
            Assert-ProbePlainTree $priorRoot
            $prior = Get-Content (Join-Path $priorRoot 'result.json') -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($prior.RunId -ne $RestoreFrom -or $prior.Shutdown -ne 'GRACEFUL' -or -not $prior.OwnedProcessAbsent -or
                -not $prior.PortsReleased -or -not $prior.FirewallRemoved -or $prior.Cache.Key -ne $cache.Compatibility.Key -or
                -not $prior.Navigation.Persistence.Saved -or -not $prior.Navigation.Conservation.Ok) { throw 'Unsafe/incomplete restore provenance' }
            if ($AvatarSurvival) {
                if($prior.Scenario -ne $scenario -or ($prior.Navigation.Mode -ne 'JOURNEY' -and -not ($WorldEconomy -and $prior.Navigation.Mode -eq 'RESTORE'))){throw 'Avatar restore requires completed journey/checkpoint'}
                Assert-AvatarSurvivalResult $prior.Navigation
                if($WorldEconomy){Assert-EconomyResult $prior.Navigation;if(-not $prior.WorldEconomy){throw 'Source is not WorldEconomy'}}
                elseif($prior.WorldEconomy){throw 'WorldEconomy snapshot requires WorldEconomy restore'}
            } elseif ($isSurvival) {
                if ($prior.Scenario -ne $scenario) { throw 'Restore scenario mismatch' }
                if($SurvivalCraft -and $prior.Navigation.Mode -ne 'CRAFT'){throw 'Craft restore requires completed CRAFT source'}
                Assert-SurvivalScenarioResult $prior.Navigation $scenario
            } else { Assert-WorldRoamResult $prior.Navigation }
            $snapshot = Join-Path $priorRoot 'inventory.bin'
            if ((Get-FileHash -LiteralPath $snapshot -Algorithm SHA256).Hash -ne $prior.WorldInventorySHA256) { throw 'Native inventory snapshot hash mismatch' }
            $proof=Get-Content (Join-Path $priorRoot 'world-proof.json') -Raw -Encoding UTF8 | ConvertFrom-Json
            $manifest=Get-Content (Join-Path $cache.Root 'world-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
            $sav=@(Get-ProbeWorldFiles $cache.World $cache.Compatibility | Where-Object Extension -eq '.sav')
            if ($sav.Count -ne 1 -or $prior.RunId -ne $RestoreFrom) { throw 'Missing exact restored save' }
            $savHash=(Get-FileHash -LiteralPath $sav[0].FullName -Algorithm SHA256).Hash
            $snapshotHash=(Get-FileHash -LiteralPath $snapshot -Algorithm SHA256).Hash
            if ($AvatarSurvival) {
                $actorSnapshot=Join-Path $priorRoot 'actor-state.json'
                $actorHash=(Get-FileHash -LiteralPath $actorSnapshot -Algorithm SHA256).Hash
                Assert-AvatarSurvivalBinding $prior $proof $cache.Compatibility.Key $manifest.Generation $cache.WorldStatus $savHash $snapshotHash $actorHash
                $report['RestoreBinding']=$proof
                if($WorldEconomy){
                    Assert-EconomyBinding $prior $proof $priorRoot
                    Assert-EconomyMapMatch $prior.Navigation.Economy.World $report.EconomyMap
                    $economyDirectory=Get-EconomyDataDirectory $install $prior.Navigation.Economy.WorldKey
                    New-Item -ItemType Directory -Force -Path $economyDirectory | Out-Null
                    foreach($name in @('economy.journal','economy.json')) {
                        Copy-Item -LiteralPath (Join-Path $priorRoot $name) -Destination (Join-Path $economyDirectory $name)
                    }
                }
                Copy-Item -LiteralPath $actorSnapshot -Destination (Join-Path $install 'oxide\data\RustBotsAvatarSurvival.state.json')
                Copy-Item -LiteralPath (Join-Path $priorRoot 'world-proof.json') -Destination (Join-Path $runtime 'restore-world-proof.json')
            } elseif ($isSurvival) {
                $actorSnapshot=Join-Path $priorRoot 'actor-state.json'
                $actorHash=(Get-FileHash -LiteralPath $actorSnapshot -Algorithm SHA256).Hash
                Assert-SurvivalRestoreBinding $prior $proof $cache.Compatibility.Key $manifest.Generation $cache.WorldStatus $savHash $snapshotHash $actorHash
                $report['RestoreBinding']=$proof
                Copy-Item -LiteralPath (Join-Path $priorRoot 'world-proof.json') -Destination (Join-Path $runtime 'restore-world-proof.json')
                Copy-Item -LiteralPath $actorSnapshot -Destination (Join-Path $install 'oxide\data\RustBotsSurvival.state.json')
                $prior.Navigation.ActorState | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $install 'oxide\data\RustBotsSurvival.expected-state.json') -Encoding UTF8
            } else { Assert-WorldRoamRestoreBinding $prior $proof $cache.Compatibility.Key $manifest.Generation $cache.WorldStatus $savHash $snapshotHash }
            Copy-Item -LiteralPath $snapshot -Destination (Join-Path $install ('oxide\data\'+$pluginName+'.inventory.bin'))
            ConvertTo-Json -InputObject @($prior.Navigation.Inventory) -Depth 8 | Set-Content (Join-Path $install ('oxide\data\'+$pluginName+'.expected.json')) -Encoding UTF8
            $report['RestoreFrom']=$RestoreFrom
        }
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
            $navFile = Join-Path $install ('oxide\data\'+$pluginName+'.result.json')
            if ($navigationDeadline -and (Test-Path -LiteralPath $navFile)) {
                $nav = Get-Content -LiteralPath $navFile -Raw | ConvertFrom-Json
                if ($nav.RunId -ne $runId) { throw 'BLOCKED: navigation result run token mismatch' }
                $report.Navigation = $nav
                Copy-Item -LiteralPath $navFile -Destination (Join-Path $runtime 'plugin-result.json')
                try {
                    if ($AvatarSurvival) {
                        Assert-AvatarSurvivalResult $nav
                        if($RestoreFrom){Assert-AvatarSurvivalRestart $prior.Navigation $nav}
                        if($WorldEconomy){Assert-EconomyResult $nav;if($nav.Status -eq 'GREEN'){Assert-EconomyMapMatch $nav.Economy.World $report.EconomyMap}}
                    } elseif ($PlayerAvatar) {
                        Assert-AvatarResult $nav
                    } elseif ($isSurvival) {
                        $expectedMode=if ($RestoreFrom) { 'RESTORE' } elseif ($SurvivalCraft) { 'CRAFT' } else { 'GATHER' }
                        if ($nav.Mode -ne $expectedMode) { throw 'Unexpected survival mode' }
                        Assert-SurvivalScenarioResult $nav $scenario
                        if($SurvivalCraft -and $RestoreFrom -and (Get-CraftRecipeKey $nav.Crafting.Recipe) -ne (Get-CraftRecipeKey $prior.Navigation.Crafting.Recipe)){throw 'Loaded restore recipe changed'}
                        if ($RestoreFrom -and (-not $nav.Persistence.Restored -or (Get-SurvivalInventoryKey $nav.Inventory) -ne (Get-SurvivalInventoryKey $prior.Navigation.Inventory) -or
                            (Get-SurvivalStateKey $nav.ActorState) -ne (Get-SurvivalStateKey $prior.Navigation.ActorState))) { throw 'Survivor inventory/state restart mismatch' }
                    } elseif ($WorldRoam) {
                        $expectedMode=if ($RestoreFrom -and -not $ResumeJourney) { 'RESTORE' } else { 'JOURNEY' }
                        if ($nav.Mode -ne $expectedMode) { throw 'Unexpected world mode for runner request' }
                        Assert-WorldRoamResult $nav
                        if ($RestoreFrom -and (-not $nav.Persistence.Restored -or (Get-WorldInventoryKey $nav.Persistence.RestoreActual) -ne (Get-WorldInventoryKey $prior.Navigation.Inventory))) { throw 'Restart did not restore the prior native inventory' }
                    } else { Assert-ProbeNavigationResult $nav }
                } catch { $report['ValidationError']=$_.Exception.Message; throw }
                if (($WorldRoam -or $isSurvival -or $AvatarSurvival) -and $nav.Persistence.Saved) {
                    $snapshot = Join-Path $install ('oxide\data\'+$pluginName+'.inventory.bin')
                    Copy-Item -LiteralPath $snapshot -Destination (Join-Path $runtime 'inventory.bin')
                    $report['WorldInventorySHA256']=(Get-FileHash -LiteralPath (Join-Path $runtime 'inventory.bin') -Algorithm SHA256).Hash
                    if ($isSurvival -or $AvatarSurvival) {
                        Copy-Item -LiteralPath (Join-Path $install ('oxide\data\'+$pluginName+'.state.json')) -Destination (Join-Path $runtime 'actor-state.json')
                        $report['ActorStateSHA256']=(Get-FileHash -LiteralPath (Join-Path $runtime 'actor-state.json') -Algorithm SHA256).Hash
                        if($WorldEconomy){
                            $economyDirectory=Get-EconomyDataDirectory $install $nav.Economy.WorldKey
                            foreach($name in @('economy.journal','economy.json')) {
                                Copy-Item -LiteralPath (Join-Path $economyDirectory $name) -Destination (Join-Path $runtime $name)
                            }
                            $report['EconomyJournalSHA256']=(Get-FileHash -LiteralPath (Join-Path $runtime 'economy.journal') -Algorithm SHA256).Hash
                            $report['EconomyStateSHA256']=(Get-FileHash -LiteralPath (Join-Path $runtime 'economy.json') -Algorithm SHA256).Hash
                        }
                    }
                }
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
    $report.Status = if ($report.Contains('ValidationError')) { 'FAILED' } else { 'BLOCKED' }
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
            if ($cache -and $report.Status -ne 'FAILED' -and (Test-ProbeCompletedSave $report (Read-ProbeLog $log))) {
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
        $env:RUST_BOTS_TEST_ROOT = $oldTestRoot
        $env:RUST_BOTS_RUN_TOKEN = $oldToken
        $env:RUST_BOTS_TEST_IDENTITY = $oldIdentity
        $env:RUST_BOTS_SCENARIO = $oldScenario
        $env:RUST_BOTS_RESTORE = $oldRestore
        $env:RUST_BOTS_RESUME_JOURNEY = $oldResume
        $env:RUST_BOTS_WORLD_ECONOMY=$oldEconomy
        if (-not $report.OwnedProcessAbsent -or $report.PortsReleased -eq $false) { $report.Status = 'FAILED' }
        if (($PlayerAvatar -or $AvatarSurvival) -and $report.Status -eq 'GREEN') {
            $report['AvatarCompletedSave']=Test-ProbeCompletedSave $report (Read-ProbeLog $log)
            try { Assert-AvatarSafety $report }
            catch { $report.Status='FAILED'; $report.Reason=$_.Exception.Message }
        }
        if (Test-Path -LiteralPath $runtime) { Save-Report }
        try {
            if ($AvatarSurvival -and (-not $RestoreFrom -or $WorldEconomy) -and $cache -and $report.Cache.Promoted -and $report.Status -eq 'GREEN') {
                Write-AvatarSurvivalSaveProof $runtime $cache.Root
                if($WorldEconomy){Write-EconomySaveProof $runtime}
            }
            if ($isSurvival -and -not $RestoreFrom -and $cache -and $report.Cache.Promoted -and $report.Navigation.Persistence.Saved -and $report.Status -in @('GREEN','PARTIAL')) {
                Write-SurvivalSaveProof $runtime $cache.Root
            }
            if ($WorldRoam -and (-not $RestoreFrom -or $ResumeJourney) -and $cache -and $report.Cache.Promoted -and $report.Navigation.Persistence.Saved -and $report.Status -in @('GREEN','PARTIAL')) {
                Write-WorldRoamSaveProof $runtime $cache.Root -LockHeld
            }
        } catch { $report.Status='PARTIAL'; $report.Reason='Journey ended; exact saved-world proof failed: '+$_.Exception.Message; Save-Report }
        finally { if ($cache) { $cache.Lock.Dispose() } }
        Write-Output ($report.Status + ': ' + $report.Reason)
        Write-Output ('Local evidence: .local/runtime/' + $runId + '/result.json')
    }
}
if ($report.Status -eq 'GREEN') { exit 0 }
if ($report.Status -eq 'PARTIAL') { exit 1 }
exit 2
