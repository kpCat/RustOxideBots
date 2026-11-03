#Requires -Version 5.1
[CmdletBinding()]
param([string]$LeaseDirectory, [string]$InstallRoot, [int]$ControllerPid, [long]$ControllerStartTicks)

function Open-ProbeFirewallReservation([string]$lease) {
    Assert-ProbePlainPath $lease
    $handle = [IO.File]::Open((Join-Path $lease 'lifecycle.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::Read)
    try {
        if ((Test-Path (Join-Path $lease 'closing.marker')) -or (Test-Path (Join-Path $lease 'closed.json'))) { throw 'Firewall lease is closing' }
        return $handle
    } catch { $handle.Dispose(); throw }
}
function Assert-ProbeFirewallLease([string]$lease, [string]$install) {
    Assert-ProbePlainPath $lease
    if ((Test-Path (Join-Path $lease 'closing.marker')) -or (Test-Path (Join-Path $lease 'closed.json'))) { throw 'Firewall lease is closed/closing' }
    $state = Get-Content (Join-Path $lease 'ready.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($state.InstallRoot -ne $install -or -not $state.ActiveStoreVerified) { throw 'Firewall lease install/proof mismatch' }
    $broker = Get-Process -Id $state.BrokerPid -ErrorAction Stop
    if ($broker.StartTime.ToUniversalTime().Ticks -ne $state.BrokerStartTicks) { throw 'Firewall lease broker PID reused' }
    $fw = New-Object -ComObject HNetCfg.FwPolicy2
    foreach ($profile in @(1,2,4)) { if (-not $fw.FirewallEnabled($profile)) { throw 'Firewall profile disabled' } }
    $executables = @(Get-ChildItem -LiteralPath $install -Filter '*.exe' -Recurse)
    if (@($state.Rules).Count -ne 2*$executables.Count) { throw 'Firewall executable inventory changed' }
    foreach ($exe in $executables) {
        foreach ($direction in @(1,2)) {
            $expected = @($state.Rules | Where-Object { $_.Program -eq $exe.FullName -and $_.Direction -eq $direction })
            if ($expected.Count -ne 1 -or $expected[0].Name -notlike ('RustBots001-Lease-'+(Split-Path $lease -Leaf)+'-*')) { throw 'Firewall rule inventory mismatch' }
            $rule = $fw.Rules.Item($expected[0].Name)
            if (-not $rule.Enabled -or $rule.Action -ne 0 -or $rule.Direction -ne $direction -or $rule.Profiles -ne 2147483647 -or $rule.ApplicationName -ne $exe.FullName) {
                throw 'Firewall COM rule verification failed'
            }
        }
    }
    return $state
}
function Start-ProbeFirewallLease([string]$repo, [string]$install, [int]$ownerPid=$PID) {
    $base = Join-Path $repo '.local\probe-firewall'
    if (Test-Path $base) { Assert-ProbePlainPath $base }
    $lease = Join-Path $base ([Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory $lease -Force | Out-Null
    $owner = Get-Process -Id $ownerPid
    $arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $repo 'scripts\ProbeFirewall.ps1') +
        '" -LeaseDirectory "'+$lease+'" -InstallRoot "'+$install+'" -ControllerPid '+$ownerPid+
        ' -ControllerStartTicks '+$owner.StartTime.ToUniversalTime().Ticks
    $windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $broker = $null
    try {
    if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $broker = Start-Process -FilePath $windowsPowerShell -ArgumentList $arguments -WindowStyle Hidden -PassThru
    } else {
        Write-Host 'Windows UAC authorization required for test-only firewall broker; game process stays unelevated.'
        $broker = Start-Process -FilePath $windowsPowerShell -ArgumentList $arguments -Verb RunAs -WindowStyle Hidden -PassThru
    }
    $deadline = [DateTime]::UtcNow.AddSeconds(60)
    while (-not (Test-Path (Join-Path $lease 'ready.json'))) {
        if (Test-Path (Join-Path $lease 'error.txt')) { throw ([IO.File]::ReadAllText((Join-Path $lease 'error.txt'))) }
        if ($broker.HasExited -or [DateTime]::UtcNow -gt $deadline) { throw 'Firewall broker did not become ready' }
        Start-Sleep -Milliseconds 250
    }
    $null = Assert-ProbeFirewallLease $lease $install
    return $lease
    } catch {
        $failure = $_
        if ($broker) {
            try { Stop-ProbeFirewallLease $lease }
            catch { Write-Warning ('Firewall startup cleanup not confirmed: '+$_.Exception.ToString()) }
        }
        throw $failure
    }
}
function Stop-ProbeFirewallLease([string]$lease) {
    [IO.File]::WriteAllText((Join-Path $lease 'stop.request'), 'stop')
    $deadline = [DateTime]::UtcNow.AddSeconds(45)
    while (-not (Test-Path (Join-Path $lease 'closed.json'))) {
        if ([DateTime]::UtcNow -gt $deadline) { throw 'Firewall broker cleanup not confirmed; rules retained fail-closed' }
        Start-Sleep -Milliseconds 250
    }
    $closed = Get-Content (Join-Path $lease 'closed.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $closed.Removed) { throw 'Firewall broker retained rules: test executable still running or cleanup failed' }
}

if ($LeaseDirectory) {
    $ErrorActionPreference = 'Stop'
    . (Join-Path $PSScriptRoot 'ProbeSafety.ps1')
    Initialize-ProbeUtf8
    $repo = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
    $created = New-Object 'Collections.Generic.List[string]'
    $removed = $false
    $safeReportDirectory = $false
    try {
        $expectedBase = Join-Path $repo '.local\probe-firewall'
        if ((Split-Path $LeaseDirectory -Parent) -ne $expectedBase -or (Split-Path $LeaseDirectory -Leaf) -notmatch '^[0-9a-f]{32}$') { throw 'Unsafe firewall lease path' }
        $cacheBase = Join-Path $repo '.local\probe-cache'
        if ($InstallRoot -notmatch ('^'+[regex]::Escape($cacheBase)+'\\[0-9a-f]{64}\\install$')) { throw 'Unsafe firewall install root' }
        Assert-ProbePlainPath $LeaseDirectory
        $safeReportDirectory = $true
        Assert-ProbePlainTree $InstallRoot
        $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Broker Windows token is not Administrator' }
        $profiles = @(Get-NetFirewallProfile -PolicyStore ActiveStore)
        if ($profiles.Count -ne 3 -or @($profiles | Where-Object { -not $_.Enabled -or $_.AllowLocalFirewallRules -eq 'False' }).Count) { throw 'Effective firewall cannot enforce local block rules' }
        $owner = Get-Process -Id $ControllerPid
        if ($owner.StartTime.ToUniversalTime().Ticks -ne $ControllerStartTicks) { throw 'Controller PID reused' }
        $entries = @()
        foreach ($exe in @(Get-ChildItem -LiteralPath $InstallRoot -Filter '*.exe' -Recurse)) {
            foreach ($direction in @(1,2)) {
                $name = 'RustBots001-Lease-'+(Split-Path $LeaseDirectory -Leaf)+'-'+$created.Count
                $created.Add($name)
                $dir = if ($direction -eq 1) { 'Inbound' } else { 'Outbound' }
                New-NetFirewallRule -Name $name -DisplayName $name -Program $exe.FullName -Direction $dir -Action Block -Enabled True -Profile Any | Out-Null
                $active = Get-NetFirewallRule -PolicyStore ActiveStore -Name $name
                $program = $active | Get-NetFirewallApplicationFilter
                if ($active.Enabled -ne 'True' -or $active.Action -ne 'Block' -or $program.Program -ne $exe.FullName) { throw 'ActiveStore firewall verification failed' }
                $entries += @{ Name=$name; Program=$exe.FullName; Direction=$direction }
            }
        }
        @{ InstallRoot=$InstallRoot; BrokerPid=$PID; BrokerStartTicks=(Get-Process -Id $PID).StartTime.ToUniversalTime().Ticks;
            Administrator=$true; ActiveStoreVerified=$true; Rules=$entries } | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $LeaseDirectory 'ready.tmp') -Encoding UTF8
        Move-Item -LiteralPath (Join-Path $LeaseDirectory 'ready.tmp') -Destination (Join-Path $LeaseDirectory 'ready.json')
        # A bounded lease can cover multiple agent-driven attempts without another UAC.
        $expiry = [DateTime]::UtcNow.AddHours(1)
        while (-not (Test-Path (Join-Path $LeaseDirectory 'stop.request')) -and [DateTime]::UtcNow -lt $expiry) {
            $owner = Get-Process -Id $ControllerPid -ErrorAction SilentlyContinue
            if (-not $owner -or $owner.StartTime.ToUniversalTime().Ticks -ne $ControllerStartTicks) { break }
            Start-Sleep -Seconds 1
        }
    } catch {
        if ($safeReportDirectory) { [IO.File]::WriteAllText((Join-Path $LeaseDirectory 'error.txt'), $_.Exception.ToString(), (New-Object Text.UTF8Encoding($false))) }
        else { Write-Error $_ }
    } finally {
        # Mark closing first, then take the same lock held from runner preflight
        # through owned job exit. No verification/start/removal race is possible.
        $closeLock = $null
        if ($safeReportDirectory) {
            [IO.File]::WriteAllText((Join-Path $LeaseDirectory 'closing.marker'),'closing')
            $deadline = [DateTime]::UtcNow.AddSeconds(45)
            while (-not $closeLock -and [DateTime]::UtcNow -lt $deadline) {
                try { $closeLock = [IO.File]::Open((Join-Path $LeaseDirectory 'lifecycle.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None) }
                catch [IO.IOException] { Start-Sleep -Milliseconds 250 }
            }
        }
        $running = @()
        $deadline = [DateTime]::UtcNow.AddSeconds(15)
        do {
            $running = @(Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($InstallRoot+'\',[StringComparison]::OrdinalIgnoreCase) })
            if ($running.Count) { Start-Sleep -Milliseconds 250 }
        } while ($running.Count -and [DateTime]::UtcNow -lt $deadline)
        if ($closeLock -and $running.Count -eq 0) {
            $removed = $true
            foreach ($name in $created) {
                try {
                    if (Get-NetFirewallRule -Name $name -ErrorAction SilentlyContinue) { Remove-NetFirewallRule -Name $name -ErrorAction Stop }
                    if (Get-NetFirewallRule -Name $name -ErrorAction SilentlyContinue) { $removed=$false }
                } catch { $removed=$false }
            }
        }
        if ($safeReportDirectory) {
            @{ Removed=$removed; RemainingProcesses=$running.Count; Utc=[DateTime]::UtcNow.ToString('o') } | ConvertTo-Json | Set-Content (Join-Path $LeaseDirectory 'closed.json') -Encoding UTF8
        }
        if ($closeLock) { $closeLock.Dispose() }
    }
}
