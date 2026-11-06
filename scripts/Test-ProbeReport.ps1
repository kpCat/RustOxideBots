#Requires -Version 5.1
param([ValidatePattern('^[0-9a-f]{32}$')][string]$FrozenRunId,[switch]$ReferenceOnly,
    [ValidatePattern('^[0-9A-Fa-f]{64}$')][string]$FrozenManifestSHA256)
$ErrorActionPreference='Stop'
# OFFLINE_ONLY: execute the real serializer function, never the runner/startup body.
$repo=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'ProbeSafety.ps1')
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'Invoke-NavigationProbe.ps1'),[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Runner does not parse'}
foreach($name in @('Get-ProbeNavigationReference','Read-ProbeReportNavigation','Save-Report')){
    $definition=$ast.Find({param($node)$node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq $name},$false)
    if(-not $definition){throw ('Missing runner report function '+$name)}
    . ([scriptblock]::Create($definition.Extent.Text))
}
$audit=Join-Path $repo '.local\audit\traversal020'
Assert-ProbePlainPath $repo
foreach($path in @((Join-Path $repo '.local'),(Join-Path $repo '.local\audit'),$audit)){
    if(Test-Path -LiteralPath $path){Assert-ProbePlainPath $path}
}
New-Item -ItemType Directory -Force -Path $audit|Out-Null
$runtime=Join-Path $audit ('p2-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $runtime|Out-Null
$encoding=New-Object Text.UTF8Encoding($false,$true)
function Read-ProbeReport([string]$path){
    $bytes=[IO.File]::ReadAllBytes($path)
    if($bytes -contains 0){throw 'Report contains NUL bytes'}
    $text=$encoding.GetString($bytes).TrimStart([char]0xFEFF)
    $text|ConvertFrom-Json
}
function Assert-ReportVector($actual,$expected){
    if($actual -is [string] -or @($actual).Count -ne 3 -or @($expected).Count -ne 3){throw 'Secondary report lost numeric triplet shape'}
    for($i=0;$i -lt 3;$i++){
        if($actual[$i] -is [string] -or $actual[$i] -is [bool] -or $actual[$i] -isnot [ValueType] -or
            [double]$actual[$i] -ne [double]$expected[$i]){throw 'Secondary report changed numeric triplet semantics'}
    }
}
function Deny-ProbeReport([scriptblock]$action,[string]$name){
    $denied=$false;try{$null=& $action}catch{$denied=$true}
    if(-not $denied){throw ('Unsafe report binding accepted: '+$name)}
}
function New-PoisonNavigation {
    $value=[pscustomobject]@{Retained='same object'}
    $value|Add-Member ScriptProperty Poison {$script:ProbeReportNavigationReads++;throw 'Navigation must not be serialized'}
    $value
}
$TraversalBench=$true;$runId='11111111111111111111111111111111'
$primary=@{RunId=$runId;Status='PARTIAL';Traversal=@{Frames=@(@{Event='MOVE_DECISION';Navigation=@{RoutePlan=@(@{
    NativeCorners=@(@(1.25,-2.5,3.75),@(4,5,6));ActorCorners=@(@(1.25,-2.5,3.75),@(4,5,6));NativePolys=@('101','102');ActorPolys=@('101','102')
})};StationaryReplan=@{Ready=@{Last=@{Native=@{Origin=@(7.5,8.25,-9.5)}}}}})}}|ConvertTo-Json -Depth 24|ConvertFrom-Json
$primary|ConvertTo-Json -Depth 24|Set-Content -LiteralPath (Join-Path $runtime 'plugin-result.json') -Encoding UTF8
$script:ProbeReportNavigationReads=0;$poison=New-PoisonNavigation
$report=[ordered]@{Status='FAILED';Reason='synthetic validation refusal';RunId=$runId;TraversalBench=$true;Navigation=$poison;
    ValidationError='synthetic retained failure';Shutdown='GRACEFUL';OwnedProcessAbsent=$true;PortsReleased=$true;FirewallRemoved=$true;Cache=@{Promoted=$false}}
# The runner's ambient RCON value must never become a serializer input.
$password='synthetic-ambient-secret-excluded'
Save-Report
$saved=Read-ProbeReport (Join-Path $runtime 'result.json')
if($script:ProbeReportNavigationReads -ne 0 -or -not [object]::ReferenceEquals($report.Navigation,$poison)){throw 'Save-Report traversed/replaced in-memory Navigation'}
if($saved.Status -cne 'FAILED' -or $saved.ValidationError -cne $report.ValidationError -or -not $saved.OwnedProcessAbsent -or $saved.Cache.Promoted -ne $false){throw 'Reference report lost runner failure/cleanup truth'}
$resolved=Read-ProbeReportNavigation $saved $runtime
Assert-ReportVector $resolved.Traversal.Frames[0].Navigation.RoutePlan[0].NativeCorners[0] @(1.25,-2.5,3.75)
Assert-ReportVector $resolved.Traversal.Frames[0].Navigation.RoutePlan[0].ActorCorners[1] @(4,5,6)
Assert-ReportVector $resolved.Traversal.Frames[0].StationaryReplan.Ready.Last.Native.Origin @(7.5,8.25,-9.5)
if(($resolved.Traversal.Frames[0].Navigation.RoutePlan[0].NativePolys -join ',') -cne '101,102'){throw 'Reference changed native polygon refs'}
$inline=[pscustomobject]@{Navigation=$primary};if(-not [object]::ReferenceEquals((Read-ProbeReportNavigation $inline $runtime),$primary)){throw 'Legacy inline Navigation reader changed'}
if([IO.File]::ReadAllText((Join-Path $runtime 'result.json')).Contains($password)){throw 'Serializer exposed ambient secret'}
Write-Output 'PASS OFFLINE_ONLY: small reference skips poison Navigation, preserves runner failure/cleanup and deep numeric bytes; legacy inline reader retained'
$denied=0
foreach($case in @(
    {param($x)$x.NavigationReference.Policy='UNKNOWN'},
    {param($x)$x.NavigationReference.Schema='1'},
    {param($x)$x.NavigationReference.File='..\plugin-result.json'},
    {param($x)$x.NavigationReference.File='D:\plugin-result.json'},
    {param($x)$x.NavigationReference.Length++},
    {param($x)$x.NavigationReference.SHA256=('0'*64)},
    {param($x)$x.NavigationReference.RunId=('2'*32)},
    {param($x)$x.RunId=('2'*32)},
    {param($x)$x.NavigationReference=$null},
    {param($x)$x.Navigation='NOT_VERIFIED'}
)){$x=$saved|ConvertTo-Json -Depth 12|ConvertFrom-Json;& $case $x;Deny-ProbeReport {Read-ProbeReportNavigation $x $runtime} 'reference metadata';$denied++}
$primary.RunId=('2'*32);$primary|ConvertTo-Json -Depth 24|Set-Content (Join-Path $runtime 'plugin-result.json') -Encoding UTF8
$x=$saved|ConvertTo-Json -Depth 12|ConvertFrom-Json;$x.NavigationReference=Get-ProbeNavigationReference $runtime $runId
Deny-ProbeReport {Read-ProbeReportNavigation $x $runtime} 'actual primary run token';$denied++
Save-Report
$changed=Read-ProbeReport (Join-Path $runtime 'result.json')
if($changed.Navigation -cne 'PRIMARY_REFERENCE_UNAVAILABLE' -or $changed.Status -cne 'FAILED' -or $script:ProbeReportNavigationReads -ne 0){throw 'Changed immutable reference did not fail closed'}
Remove-Item -LiteralPath (Join-Path $runtime 'plugin-result.json')
$report=[ordered]@{Status='PARTIAL';Reason='synthetic';RunId=$runId;TraversalBench=$true;Navigation=$poison}
Save-Report;$missing=Read-ProbeReport (Join-Path $runtime 'result.json')
if($missing.Navigation -cne 'PRIMARY_REFERENCE_UNAVAILABLE' -or $missing.Status -cne 'FAILED' -or $script:ProbeReportNavigationReads -ne 0){throw 'Missing primary traversed Navigation or claimed success'}
Deny-ProbeReport {Read-ProbeReportNavigation $saved $runtime} 'missing artifact';$denied++
$report=[ordered]@{Status='BLOCKED';Reason='';RunId=$runId;TraversalBench=$true;Navigation='NOT_VERIFIED';Shutdown='PENDING'}
Save-Report;$startup=Read-ProbeReport (Join-Path $runtime 'result.json')
if($startup.Status -cne 'BLOCKED' -or $startup.Navigation -cne 'NOT_VERIFIED' -or $startup.NavigationReference){throw 'Startup report fabricated a completed primary'}
Write-Output ('PASS OFFLINE_ONLY: '+$denied+' reference-binding negatives, immutable repeated saves, missing-primary failure and honest startup')

# Non-traversal paths retain their exact prior Depth8 representation and field locations.
$TraversalBench=$false
foreach($context in @('WORLD_ROAM','PLAYER_AVATAR','AVATAR_SURVIVAL','FIRST_HOME','RESTORE','PARTIAL_FAILURE')){
    $report=[ordered]@{Status='PARTIAL';Scenario=$context;Shutdown='GRACEFUL';OwnedProcessAbsent=$true;
        Cache=@{Key='synthetic';Promoted=$false};Navigation=(@{Mode=$context;Persistence=@{Saved=$true;Restored=($context -eq 'RESTORE')};
            Conservation=@{Ok=$true};Inventory=@(@{Uid='101';Shortname='wood';Amount=5});ActorState=@{Position=@(1,2,3)}}|ConvertTo-Json -Depth 8|ConvertFrom-Json)}
    $prior=$report|ConvertTo-Json -Depth 8;Save-Report
    $current=[IO.File]::ReadAllText((Join-Path $runtime 'result.json')).TrimEnd([char[]]"`r`n").TrimStart([char]0xFEFF)
    if($current -cne $prior){throw ('Legacy report representation changed: '+$context)}
}
$source=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Invoke-NavigationProbe.ps1'))
if($source -notmatch 'try\s*\{\s*if \(Test-Path -LiteralPath \$runtime\) \{ Save-Report \}' -or $source -notmatch 'finally \{ if \(\$cache\) \{ \$cache.Lock.Dispose\(\) \} \}'){throw 'Final report export can bypass the existing cache-lock finally'}
Write-Output 'PASS OFFLINE_ONLY: six ordinary contexts retain exact Depth8 output; final report remains inside cache-lock finally'
if(-not $FrozenRunId){return}

$frozen=Join-Path $repo ('.local\runtime\'+$FrozenRunId);Assert-ProbePlainPath $frozen
$primaryPath=Join-Path $frozen 'plugin-result.json';$secondaryPath=Join-Path $frozen 'result.json'
$before=@(foreach($path in @($primaryPath,$secondaryPath)){Assert-ProbePlainPath $path;[pscustomobject]@{Path=$path;Length=(Get-Item $path).Length;SHA256=(Get-FileHash $path -Algorithm SHA256).Hash}})
$manifestPath=$null
if($ReferenceOnly){
    if(-not $FrozenManifestSHA256){throw 'Reference-only frozen proof requires its independently frozen manifest hash'}
    $manifestPath=Join-Path $audit ($FrozenRunId+'-raw-manifest.json');Assert-ProbePlainPath $manifestPath
    if((Get-FileHash $manifestPath -Algorithm SHA256).Hash -ine $FrozenManifestSHA256){throw 'Frozen manifest changed'}
    $manifest=Read-ProbeReport $manifestPath
    foreach($row in $before){$entry=@($manifest|Where-Object Path -ceq ([IO.Path]::GetFileName($row.Path)));if($entry.Count -ne 1 -or $entry[0].Length -ne $row.Length -or $entry[0].SHA256 -ine $row.SHA256){throw 'Actual-size input does not match frozen manifest'}}
}
$primaryValidation='NOT_RUN_REFERENCE_ONLY';$plans=$null;$triplets=$null
if(-not $ReferenceOnly){
    . (Join-Path $PSScriptRoot 'TraversalValidation.ps1')
    $primary=Read-ProbeReport $primaryPath;Assert-TraversalResult $primary;$primaryValidation='PASS';$plans=0;$triplets=0
    foreach($frame in @($primary.Traversal.Frames)){foreach($plan in @($frame.Navigation.RoutePlan)){if($null -eq $plan){continue};$plans++;foreach($field in @('NativeCorners','ActorCorners')){foreach($v in @($plan.$field)){Assert-ReportVector $v $v;$triplets++}}}}
    if(-not $plans -or -not $triplets){throw 'Frozen primary does not cover deep native routes'}
    $primary=$null
}
$originalHeaderStatus='NOT_PARSED';$originalStartupHeader=$null
if($before[1].Length -le 65536){$header=Read-ProbeReport $secondaryPath;$originalHeaderStatus=$header.Status;$originalStartupHeader=$header.Navigation -is [string] -and $header.Navigation -ceq 'NOT_VERIFIED' -and $header.Shutdown -ceq 'PENDING'}
Copy-Item -LiteralPath $primaryPath -Destination (Join-Path $runtime 'plugin-result.json')
$TraversalBench=$true;$script:ProbeReportNavigationReads=0;$poison=New-PoisonNavigation
$report=[ordered]@{Status='FAILED';Reason='OFFLINE_REFERENCE_REPACK_NOT_A_RUNNER_COMPLETION';RunId=$FrozenRunId;TraversalBench=$true;Navigation=$poison;OfflineRepack=$true;
    OriginalSecondarySHA256=$before[1].SHA256;OriginalSecondaryBytes=$before[1].Length;OriginalSecondaryStatus=$originalHeaderStatus;OriginalSecondaryIsStartupHeader=$originalStartupHeader;PrimaryValidation=$primaryValidation}
$timer=[Diagnostics.Stopwatch]::StartNew();Save-Report;$saveSeconds=$timer.Elapsed.TotalSeconds
$outputPath=Join-Path $runtime 'result.json';$saved=Read-ProbeReport $outputPath
$reference=Get-ProbeNavigationReference $runtime $FrozenRunId $saved.NavigationReference
if($reference.Length -ne $before[0].Length -or $reference.SHA256 -cne $before[0].SHA256 -or $script:ProbeReportNavigationReads -ne 0){throw 'Actual-size reference lost exact primary bytes or traversed Navigation'}
foreach($row in $before){if((Get-Item $row.Path).Length -ne $row.Length -or (Get-FileHash $row.Path -Algorithm SHA256).Hash -cne $row.SHA256){throw 'Frozen input changed'}}
if($manifestPath -and (Get-FileHash $manifestPath -Algorithm SHA256).Hash -ine $FrozenManifestSHA256){throw 'Frozen manifest changed after proof'}
$summary=[ordered]@{PowerShell=$PSVersionTable.PSVersion.ToString();FrozenRun=$FrozenRunId;PrimaryValidation=$primaryValidation;SecondaryValidation='REFERENCE_BYTES_EXACT';
    NativePlans=$plans;NumericTriplets=$triplets;NavigationSemantics='EXACT_PRIMARY_BYTES';FrozenInputsUnchanged=$true;PrimaryJSONParsed=(-not [bool]$ReferenceOnly);
    PrimaryBytes=$before[0].Length;HistoricalSecondaryBytes=$before[1].Length;SecondaryBytes=(Get-Item $outputPath).Length;SaveSeconds=$saveSeconds;
    PeakWorkingSetBytes=(Get-Process -Id $PID).PeakWorkingSet64;Utf8Nul='PASS';SecondarySHA256=(Get-FileHash $outputPath -Algorithm SHA256).Hash}
$summary|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $runtime 'validation.json') -Encoding UTF8
$summary|ConvertTo-Json -Depth 4
