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

$runId=[Guid]::NewGuid().ToString('N')
$runInstall=Join-Path $fixture ('.local/runtime/'+$runId+'/install')
New-Item -ItemType Directory -Force -Path $runInstall | Out-Null
[IO.File]::WriteAllText((Join-Path $runInstall 'rustbots-test.marker'),$runId)
Assert-ProbeFirewallInstallRoot $fixture $runInstall
foreach($path in @((Join-Path $fixture 'Server/rustds'),(Join-Path $fixture '.local/runtime/wrong/install'),(Join-Path $runInstall 'child'))) {
    $rejected=$false;try{Assert-ProbeFirewallInstallRoot $fixture $path}catch{$rejected=$true}
    if(-not $rejected){throw 'Firewall install scope admitted owner or malformed root'}
}
[IO.File]::WriteAllText((Join-Path $runInstall 'rustbots-test.marker'),'wrong')
$rejected=$false;try{Assert-ProbeFirewallInstallRoot $fixture $runInstall}catch{$rejected=$true}
if(-not $rejected){throw 'Runtime firewall root admitted mismatched run marker'}
Write-Output 'PASS: firewall runtime root requires exact run-id path and matching marker; owner and malformed paths denied'
