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
# Map identity is stable across saves and independent of test cache generations.
function WorldFixture {
    $w=New-Object RustBots.EconomyWorldIdentity
    $w.Kind='PROCEDURAL';$w.Level='Procedural Map';$w.Seed=17;$w.Size=3500;$w.MapVersion='289';$w.MapSHA256='A'*64;$w.WipeId='11111111-1111-1111-1111-111111111111'
    return $w
}
$world=WorldFixture;$same=WorldFixture
Check ($world.WorldKey()) ($same.WorldKey())
$worldPath=$world.JournalDirectory($root)
New-Item -ItemType Directory $worldPath | Out-Null
$worldJournal=Join-Path $worldPath 'economy.journal'
$j=New-Object RustBots.EconomyJournal($worldJournal,$world.WorldKey(),'actor','recipe')
foreach($stage in @('PREPARED','DEBITTING','DEBITED','OUTPUT_CREATED','COMMITTED')){$j.Append('CRAFT','paid',$stage,'{"Uid":"14"}')};$j.Dispose()
# A changed .sav hash/generation is separate state proof and is not an identity input.
$saveProof1=@{Generation='save-A';SHA256='B'*64};$saveProof2=@{Generation='save-B';SHA256='C'*64}
$j=New-Object RustBots.EconomyJournal($worldJournal,$same.WorldKey(),'actor','recipe')
try{Check ($j.RecoveryState('paid')) 'COMMITTED'}finally{$j.Dispose()}
$originalHash=(Get-FileHash $worldJournal -Algorithm SHA256).Hash
foreach($change in @({param($w)$w.Seed++},{param($w)$w.Size=4500},{param($w)$w.Level='Barren'},{param($w)$w.MapSHA256='D'*64},
 {param($w)$w.MapVersion='290'},{param($w)$w.WipeId='22222222-2222-2222-2222-222222222222'},
 {param($w)$w.Kind='CUSTOM';$w.Level='Custom island'},{param($w)$w.WipeId=''})) {
    $other=WorldFixture;& $change $other
    Denied {$world.RequireSame($other)}
    Denied {$x=New-Object RustBots.EconomyJournal($worldJournal,$other.WorldKey(),'actor','recipe');$x.Dispose()}
    if($other.WipeId){if($other.JournalDirectory($root) -ceq $worldPath){throw 'Cross-world namespace collision'}}
}
$custom=WorldFixture;$custom.Kind='CUSTOM';$custom.Level='Custom island'
$custom2=WorldFixture;$custom2.Kind='CUSTOM';$custom2.Level='Custom island'
$custom.RequireSame($custom2)
$custom2.MapSHA256='E'*64;Denied {$custom.RequireSame($custom2)}
Check ((Get-FileHash $worldJournal -Algorithm SHA256).Hash) $originalHash
Write-Output 'PASS: OFFLINE_ONLY procedural/custom identity, same-world save independence, map/seed/size/wipe isolation; cross-world mutations=0'
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
foreach($r in $replays){$s=$sources|Where-Object Incarnation -eq $r.Incarnation;$r.Actual=@{};foreach($key in $s.Keys){$r.Actual[$key]=$s[$key]};$r.SavedHealth=80;$r.CheckpointHealth=80;$r.StartHealth=100;$r.Staged=$s.Type -eq 'OreResourceEntity';$r.CurrentHealth=if($r.Staged){100}else{80}}
$fixture=@{Status='GREEN';Mode='RESTORE';State=@{ActorId='actor';CraftIntent='intent';ProductUid='14'};Economy=@{WorldKey='world';State=@{ActorId='actor';CraftIntent='intent';ProductUid='14';Sources=$sources};CrashAtomic='NOT_PROVEN';CrashRecovery='OFFLINE_ONLY';Replays=$replays;CraftReplay=@{CraftState='COMMITTED';DuplicateDenied=$true;InventoryUnchanged=$true;OutputUid='14'}}}
$fixtureWorld=WorldFixture;$keys=Get-EconomyWorldKeys $fixtureWorld
Check $keys.WorldKey ($fixtureWorld.WorldKey());Check $keys.MapKey ($fixtureWorld.MapKey())
$fixture.Economy.World=$fixtureWorld;$fixture.Economy.MapKey=$keys.MapKey;$fixture.Economy.WorldKey=$keys.WorldKey
$fixture.Economy.State.Schema=2;$fixture.Economy.State.World=$fixtureWorld;$fixture.Economy.State.WorldKey=$keys.WorldKey;$fixture.Economy.State.SnapshotHealth=@{tree=80;ore=100}
$fixture.Economy.InputSnapshotHealth=@{tree=80;ore=80}
Assert-EconomyMapMatch $fixtureWorld $same
$wrongMap=WorldFixture;$wrongMap.Seed++;Denied {Assert-EconomyMapMatch $fixtureWorld $wrongMap}
Assert-EconomyResult $fixture
$checkpoint=$fixture|ConvertTo-Json -Depth 20|ConvertFrom-Json
$checkpoint.Economy.State.SnapshotHealth.ore=100
$checkpoint.Economy.InputSnapshotHealth.ore=100
foreach($r in @($checkpoint.Economy.Replays|Where-Object Incarnation -eq ore)){$r.CheckpointHealth=100;$r.SavedHealth=100}
Assert-EconomyResult $checkpoint
Check $checkpoint.Economy.WorldKey $fixture.Economy.WorldKey
foreach($mutate in @({param($n)$n.Economy.Replays[0].DiskWitness=$false},{param($n)$n.Economy.Replays[0].Candidates=2},{param($n)$n.Economy.Replays[2].Decision='APPLY'},
 {param($n)$n.Economy.Replays[0].After=1000},{param($n)$n.Economy.Replays[0].NeighborsUnchanged=$false},{param($n)$n.Economy.Replays[0].ItemCredits=1},
 {param($n)$n.Economy.CraftReplay.CraftState='DEBITED'},{param($n)$n.Economy.CraftReplay.OutputUid='99'},
 {param($n)$n.Economy.Replays[0].Before=[double]::NaN;$n.Economy.Replays[0].After=[double]::NaN;$n.Economy.Replays[0].FractionBefore=[double]::NaN;$n.Economy.Replays[0].FractionAfter=[double]::NaN},
 {param($n)$n.Economy.Replays[0].Actual.Position[0]=99},{param($n)$n.Economy.Replays[0].Actual.Prefab='other.prefab'},
 {param($n)$n.Economy.Replays[1].CurrentHealth=80},{param($n)$n.Economy.World.Seed++},
 {param($n)$n.Economy.State.World.Size++},{param($n)$n.Economy.World.WipeId='22222222-2222-2222-2222-222222222222'})) {
    $n=$fixture|ConvertTo-Json -Depth 20|ConvertFrom-Json;Assert-EconomyResult $n;& $mutate $n;Denied {Assert-EconomyResult $n}
}
Write-Output 'PASS: independent OFFLINE_ONLY economic replay validator rejects false GREEN'
