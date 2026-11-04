#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ProbeSafety.ps1')
. (Join-Path $PSScriptRoot 'ProbeCache.ps1')
$repo = Split-Path $PSScriptRoot -Parent
$fixture = Join-Path $repo ('.local\tests\cache-' + [Guid]::NewGuid().ToString('N'))
$source = Join-Path $fixture 'source'
New-Item -ItemType Directory -Path $source -Force | Out-Null
foreach ($relative in (Get-ProbeFingerprintPaths)) {
    $path = Join-Path $source $relative
    New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null
    [IO.File]::WriteAllText($path, 'fixture runtime ' + $relative)
}
New-Item -ItemType Directory -Path (Join-Path $source 'Bundles') | Out-Null
foreach ($name in @('gunrack.horizontal.json','gunrack_stand.json')) { [IO.File]::WriteAllText((Join-Path $source ('Bundles\'+$name)), 'fixture') }
$a = Get-ProbeCompatibility $source 424242 2000
$b = Get-ProbeCompatibility $source 424243 2000
if ($a.Key -eq $b.Key) { throw 'Map parameter change did not invalidate cache key' }
[IO.File]::AppendAllText((Join-Path $source 'RustDedicated_Data\Managed\Assembly-CSharp.dll'), 'changed')
$c = Get-ProbeCompatibility $source 424242 2000
if ($a.Key -eq $c.Key) { throw 'Runtime change did not invalidate cache key' }
Write-Output 'PASS: cache key binds runtime fingerprints and map parameters'

if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) {
    $script = Join-Path $fixture 'cross-host.ps1'
    $out = Join-Path $fixture 'cross-host-key.txt'
    @'
param($Repo,$Source,$OutputPath)
. (Join-Path $Repo 'scripts\ProbeSafety.ps1')
. (Join-Path $Repo 'scripts\ProbeCache.ps1')
(Get-ProbeCompatibility $Source).Key | Set-Content -LiteralPath $OutputPath -Encoding ASCII
'@ | Set-Content $script -Encoding ASCII
    & pwsh.exe -NoProfile -File $script $repo $source $out
    if ((Get-Content $out -Raw).Trim() -ne $c.Key) { throw 'PS5/PS7 cache key differs for identical source' }
    Write-Output 'PASS: cache key is stable across Windows PowerShell and PowerShell 7'
}

$installManifest = Join-Path $fixture 'install-manifest.json'
Save-ProbeInstallManifest $source $installManifest
Assert-ProbeInstallManifest $source $installManifest
Remove-Item -LiteralPath (Join-Path $source 'Bundles\gunrack.horizontal.json')
$rejected = $false
try { Assert-ProbeInstallManifest $source $installManifest } catch { $rejected = $true }
if (-not $rejected) { throw 'Incomplete cached install accepted' }
Write-Output 'PASS: incomplete cached runtime is rejected'

$quit = [pscustomobject]@{ Shutdown='GRACEFUL'; OwnedProcessAbsent=$true; ServerExitCode=-1 }
$savedLog = 'RUSTBOTS_SHUTDOWN_ACK Successfully saved navmesh Saving complete'
if (-not (Test-ProbeCompletedSave $quit $savedLog)) { throw 'Installed native quit exit -1 rejected despite acknowledged complete save' }
if (Test-ProbeCompletedSave $quit 'RUSTBOTS_SHUTDOWN_ACK') { throw 'Incomplete save accepted' }
Write-Output 'PASS: native quit exit -1 requires acknowledged complete save before promotion'

$world = Join-Path $fixture 'world-source'
$cache = Join-Path $fixture 'cache'
$restore = Join-Path $fixture 'restored-world'
New-Item -ItemType Directory -Path $world,$cache,$restore | Out-Null
foreach ($ext in @('map','sav','navmesh')) { [IO.File]::WriteAllText((Join-Path $world ('proceduralmap.2000.424242.289.'+$ext)), 'fixture world payload: '+$ext) }
[IO.File]::WriteAllText((Join-Path $world 'serverauto.cfg'), 'private fixture config must not be cached')
$context = [pscustomobject]@{ Root=$cache; Compatibility=$a; WorldStatus=''; InvalidReason='' }
Save-ProbeWorldCache $context $world
if (-not (Restore-ProbeWorldCache $context $restore)) { throw 'Valid cache was rejected' }
if (@(Get-ChildItem $restore -File).Count -ne 3 -or (Test-Path (Join-Path $restore 'serverauto.cfg'))) { throw 'World cache included non-world data' }
$manifest = Get-Content (Join-Path $cache 'world-manifest.json') -Raw | ConvertFrom-Json
[IO.File]::AppendAllText((Join-Path (Join-Path $cache $manifest.Generation) $manifest.Files[0].Name), 'corrupt')
$restore2 = Join-Path $fixture 'restore-corrupt'
New-Item -ItemType Directory $restore2 | Out-Null
if (Restore-ProbeWorldCache $context $restore2) { throw 'Corrupted cache was accepted' }
if (@(Get-ChildItem $restore2 -File).Count) { throw 'Corrupted cache was partially applied' }
Write-Output 'PASS: verified world files restored physically; configs excluded; corruption rejected before copy'

# 011 diagnostic smoke must fork real files and cannot promote fixture economy.
$isolatedRepo=Join-Path $fixture 'smoke-repo'
$runtime=Join-Path $isolatedRepo '.local/runtime/smoke'
$compat=Get-ProbeCompatibility $source
$trusted=Join-Path $isolatedRepo ('.local/probe-cache/'+$compat.Key)
$template=Join-Path $trusted 'install'
New-Item -ItemType Directory -Force -Path $runtime,$trusted,(Join-Path $source 'MonoBleedingEdge') | Out-Null
Copy-Item -LiteralPath $source -Destination $template -Recurse
Save-ProbeInstallManifest $template (Join-Path $trusted 'install-manifest.json')
$trustedContext=[pscustomobject]@{Root=$trusted;Compatibility=$compat;WorldStatus='';InvalidReason=''}
Save-ProbeWorldCache $trustedContext $world
$manifestBefore=(Get-FileHash (Join-Path $trusted 'world-manifest.json')).Hash
$smoke=$null
try {
    $smoke=Initialize-ProbeCache $isolatedRepo $source $runtime -DiagnosticOnly
    if(-not $smoke.DiagnosticOnly -or $smoke.Root -eq $trusted -or -not $smoke.Install.StartsWith($runtime+'\') -or $smoke.WorldStatus -ne 'WARM'){throw 'Smoke reused trusted writable root'}
    $copy=Join-Path $smoke.World 'proceduralmap.2000.424242.289.sav'
    [IO.File]::AppendAllText($copy,' test fixture mutation')
    $denied=$false;try {Save-ProbeWorldCache $smoke $smoke.World}catch{$denied=$true}
    if(-not $denied){throw 'Fixture cache promotion accepted'}
    if((Get-FileHash (Join-Path $trusted 'world-manifest.json')).Hash -ne $manifestBefore){throw 'Smoke changed trusted manifest'}
    $check=Join-Path $fixture 'trusted-after-smoke';New-Item -ItemType Directory $check | Out-Null
    if(-not (Restore-ProbeWorldCache $trustedContext $check) -or (Get-FileHash (Join-Path $check 'proceduralmap.2000.424242.289.sav')).Hash -eq (Get-FileHash $copy).Hash){throw 'Smoke writable world aliases trusted files'}
} finally {if($smoke){$smoke.Lock.Dispose()}}
Write-Output 'PASS: diagnostic physical world/runtime fork, unchanged trusted cache and fail-closed fixture promotion'
$naturalRuntime=Join-Path $isolatedRepo '.local/runtime/natural'
New-Item -ItemType Directory -Path $naturalRuntime | Out-Null
$natural=$null
try {
    $natural=Initialize-ProbeCache $isolatedRepo $source $naturalRuntime -PhysicalRun
    if($natural.DiagnosticOnly -or $natural.Root -ne $trusted -or -not $natural.Install.StartsWith($naturalRuntime+'\') -or
        (Get-FileHash (Join-Path $natural.World 'proceduralmap.2000.424242.289.sav')).Hash -ne (Get-FileHash (Join-Path $world 'proceduralmap.2000.424242.289.sav')).Hash){throw 'Natural physical fork inherited fixture world'}
} finally {if($natural){$natural.Lock.Dispose()}}
Write-Output 'PASS: natural FirstHome uses a fresh physical install and pristine trusted save'
