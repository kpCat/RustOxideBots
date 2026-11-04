#Requires -Version 5.1
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$helper=Join-Path $repo 'src\economy\EconomyJournal.cs'
if(-not (Test-Path $helper)){throw '009 durable economy helper is not implemented'}
Add-Type -Path $helper
$root=Join-Path $repo ('.local\economy-fixture-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $root | Out-Null
function Denied([scriptblock]$action){$denied=$false;try{& $action}catch{$denied=$true};if(-not $denied){throw 'Unsafe economy operation accepted'}}
function Check($actual,$expected){if($actual -cne $expected){throw "Expected $expected, observed $actual"}}
# Real helper, real durable writes: duplicate payment/output and all interrupted stages.
foreach($stop in @('PREPARED','DEBITTING','DEBITED','OUTPUT_CREATED','COMMITTED')) {
    $path=Join-Path $root ($stop+'.journal')
    $j=New-Object RustBots.EconomyJournal($path,'world/gen/save','actor','recipe')
    Denied {$other=New-Object RustBots.EconomyJournal($path,'world/gen/save','actor','recipe');$other.Dispose()}
    foreach($stage in @('PREPARED','DEBITTING','DEBITED','OUTPUT_CREATED','COMMITTED')) {
        $j.Append('CRAFT','intent',$stage,'{"Uid":"14"}')
        if($stage -eq $stop){break}
    }
    $j.Dispose()
    $j=New-Object RustBots.EconomyJournal($path,'world/gen/save','actor','recipe')
    try {
        Check ($j.RecoveryState('intent')) $(if($stop -eq 'COMMITTED'){'COMMITTED'}else{'IN_DOUBT'})
        Denied {$j.Append('CRAFT','intent','PREPARED','retry must never pay/create')}
        if($stop -ne 'COMMITTED'){Denied {$j.Append('CRAFT','intent','COMMITTED','unproven recovery')}}
    }finally{$j.Dispose()}
    Denied {$x=New-Object RustBots.EconomyJournal($path,'wrong world','actor','recipe');$x.Dispose()}
    Denied {$x=New-Object RustBots.EconomyJournal($path,'world/gen/save','wrong actor','recipe');$x.Dispose()}
    Denied {$x=New-Object RustBots.EconomyJournal($path,'world/gen/save','actor','wrong recipe');$x.Dispose()}
}
$good=[IO.File]::ReadAllBytes((Join-Path $root 'COMMITTED.journal'))
$torn=Join-Path $root 'torn.journal';[IO.File]::WriteAllBytes($torn,$good[0..($good.Length-2)])
Denied {$x=New-Object RustBots.EconomyJournal($torn,'world/gen/save','actor','recipe');$x.Dispose()}
$bad=Join-Path $root 'corrupt.journal';$good[10]=$good[10] -bxor 1;[IO.File]::WriteAllBytes($bad,$good)
Denied {$x=New-Object RustBots.EconomyJournal($bad,'world/gen/save','actor','recipe');$x.Dispose()}
Write-Output 'PASS: OFFLINE_ONLY journal integrity/binding, duplicate denial and five interrupted craft checkpoints'
# Same-source restoration policy. A geometric match without native disk incarnation is refused.
Check ([RustBots.EconomyJournal]::PoolDecision(1000,760,1,0.76,1000,1,$true,1)) 'APPLY'
Check ([RustBots.EconomyJournal]::PoolDecision(1000,760,1,0.76,760,0.76,$true,1)) 'NOOP'
foreach($case in @(
    @(1000,760,1,0.76,1000,1,$false,1), # same geometry, new respawn/no disk witness
    @(1000,760,1,0.76,1000,1,$true,2), # ambiguous
    @(1000,760,1,0.76,1000,1,$true,0), # absent
    @(1000,760,1,0.76,700,0.7,$true,1), # unexpected lower pool
    @(1000,760,1,0.76,900,0.9,$true,1), # not a proven full reset
    @(1000,760,1,0.76,1000,0.9,$true,1))) {
    Denied {[RustBots.EconomyJournal]::PoolDecision($case[0],$case[1],$case[2],$case[3],$case[4],$case[5],$case[6],$case[7])}
}
Write-Output 'PASS: OFFLINE_ONLY source reset/NOOP, absent/ambiguous/respawn and incompatible pool fail closed'
Check ([RustBots.EconomyJournal]::LoadedHealthMatches($true,80,80,100,100)) $true
Check ([RustBots.EconomyJournal]::LoadedHealthMatches($false,80,80,80,100)) $true
Check ([RustBots.EconomyJournal]::LoadedHealthMatches($true,70,80,100,100)) $false
Check ([RustBots.EconomyJournal]::LoadedHealthMatches($false,80,80,100,100)) $false
# Warm pools can reset while saved tree health remains depleted. Never exhaust that incarnation.
Check ([RustBots.EconomyJournal]::CanSustainHarvest(375,375,196.8,600,10,0.5,200)) $false
Check ([RustBots.EconomyJournal]::CanSustainHarvest(1500,1500,1000,1000,10,0.5,200)) $true
Check ([RustBots.EconomyJournal]::CanSustainHarvest(1000,1000,5,1000,10,0.5,1)) $false
Check ([RustBots.EconomyJournal]::CanSustainHarvest(1000,1000,90,1000,20,0.5,1)) $false
. (Join-Path $PSScriptRoot 'EconomyValidation.ps1')
$parsed=@(Read-EconomyJournal (Join-Path $root 'COMMITTED.journal') 'world/gen/save' 'actor' 'recipe')
Check $parsed.Count 6
Denied {Read-EconomyJournal $torn 'world/gen/save' 'actor' 'recipe'}
Denied {Read-EconomyJournal $bad 'world/gen/save' 'actor' 'recipe'}
Denied {Read-EconomyJournal (Join-Path $root 'DEBITED.journal') 'world/gen/save' 'actor' 'recipe'}
Denied {Read-EconomyJournal (Join-Path $root 'COMMITTED.journal') 'wrong generation' 'actor' 'recipe'}
$empty=Join-Path $root 'empty.journal';[IO.File]::WriteAllBytes($empty,[byte[]]@())
Denied {$x=New-Object RustBots.EconomyJournal($empty,'world/gen/save','actor','recipe');$x.Dispose()}
# Independent receipt validator must reject an invented replay success.
$sources=@(@{Incarnation='tree';SavedUid='20';Prefab='tree.prefab';Type='TreeEntity';Resource='wood';InitialPool=1000;ExpectedPool=760;InitialFraction=1;ExpectedFraction=0.76},
 @{Incarnation='ore';SavedUid='21';Prefab='ore.prefab';Type='OreResourceEntity';Resource='stones';InitialPool=500;ExpectedPool=380;InitialFraction=1;ExpectedFraction=0.76})
foreach($s in $sources){$s.Position=@(1,2,3);$s.Rotation=@(0,0,0,1);$s.Scale=@(1,1,1);$s.Bounds=@(0,0,0,1,1,1);$s.Population='natural';$s.StartAmount=$s.InitialPool;$s.Health=80}
$replays=@(foreach($pass in @(1,2)){foreach($s in $sources){@{Pass=$pass;Incarnation=$s.Incarnation;SavedUid=$s.SavedUid;Candidates=1;DiskWitness=$true;Decision=$(if($pass -eq 1){'APPLY'}else{'NOOP'});Before=$(if($pass -eq 1){$s.InitialPool}else{$s.ExpectedPool});After=$s.ExpectedPool;FractionBefore=$(if($pass -eq 1){1}else{0.76});FractionAfter=0.76;Neighbors=2;NeighborsUnchanged=$true;ItemCredits=0}}})
foreach($r in $replays){$s=$sources|Where-Object Incarnation -eq $r.Incarnation;$r.Actual=@{};foreach($key in $s.Keys){$r.Actual[$key]=$s[$key]};$r.SavedHealth=80;$r.StartHealth=100;$r.Staged=$s.Type -eq 'OreResourceEntity';$r.CurrentHealth=if($r.Staged){100}else{80}}
$fixture=@{Status='GREEN';Mode='RESTORE';State=@{ActorId='actor';CraftIntent='intent';ProductUid='14'};Economy=@{WorldKey='world';State=@{ActorId='actor';CraftIntent='intent';ProductUid='14';Sources=$sources};CrashAtomic='NOT_PROVEN';CrashRecovery='OFFLINE_ONLY';Replays=$replays;CraftReplay=@{CraftState='COMMITTED';DuplicateDenied=$true;InventoryUnchanged=$true;OutputUid='14'}}}
Assert-EconomyResult $fixture
foreach($mutate in @({param($n)$n.Economy.Replays[0].DiskWitness=$false},{param($n)$n.Economy.Replays[0].Candidates=2},{param($n)$n.Economy.Replays[2].Decision='APPLY'},
 {param($n)$n.Economy.Replays[0].After=1000},{param($n)$n.Economy.Replays[0].NeighborsUnchanged=$false},{param($n)$n.Economy.Replays[0].ItemCredits=1},
 {param($n)$n.Economy.CraftReplay.CraftState='DEBITED'},{param($n)$n.Economy.CraftReplay.OutputUid='99'},
 {param($n)$n.Economy.Replays[0].Before=[double]::NaN;$n.Economy.Replays[0].After=[double]::NaN;$n.Economy.Replays[0].FractionBefore=[double]::NaN;$n.Economy.Replays[0].FractionAfter=[double]::NaN},
 {param($n)$n.Economy.Replays[0].Actual.Position[0]=99},{param($n)$n.Economy.Replays[0].Actual.Prefab='other.prefab'},
 {param($n)$n.Economy.Replays[1].CurrentHealth=80})) {
    $n=$fixture|ConvertTo-Json -Depth 20|ConvertFrom-Json;Assert-EconomyResult $n;& $mutate $n;Denied {Assert-EconomyResult $n}
}
Write-Output 'PASS: independent OFFLINE_ONLY economic replay validator rejects false GREEN'
