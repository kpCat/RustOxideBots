#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ProbeSafety.ps1')
. (Join-Path $PSScriptRoot 'ProbeFirewall.ps1')
$fixture = Join-Path (Split-Path $PSScriptRoot -Parent) ('.local\tests\firewall-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $fixture | Out-Null
$reservation = Open-ProbeFirewallReservation $fixture
try {
    $rejected = $false
    try { $closing = [IO.File]::Open((Join-Path $fixture 'lifecycle.lock'),[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None); $closing.Dispose() } catch [IO.IOException] { $rejected=$true }
    if (-not $rejected) { throw 'Broker can close rules during an active run reservation' }
} finally { $reservation.Dispose() }
[IO.File]::WriteAllText((Join-Path $fixture 'closing.marker'),'closing')
$rejected = $false
try { $late = Open-ProbeFirewallReservation $fixture; $late.Dispose() } catch { $rejected=$true }
if (-not $rejected) { throw 'New run can reserve a closing lease' }
Write-Output 'PASS: active run prevents broker close; closing lease prevents new run'
