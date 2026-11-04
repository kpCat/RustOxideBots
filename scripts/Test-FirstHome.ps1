#Requires -Version 5.1
$ErrorActionPreference='Stop'
$validator=Join-Path $PSScriptRoot 'FirstHomeValidation.ps1'
if(-not (Test-Path -LiteralPath $validator)){throw 'FirstHome safety contracts are not implemented'}
. $validator
$site=[pscustomobject]@{HeightRange=1.09;FoundationDepth=2.8;EntryDelta=0.224;OutsideDelta=0.069;NativePreview=$true;Water=$false;Topology=0;ForbiddenTopology=16776578;Monument=$false;Road=$false;Foreign=$false;Collision=$false;Permission=$true;Path='PathComplete';
    MonumentOriginDistance=130;MonumentBoundsDistance=10;ForeignDistance=50;RoadDistance=30;PreventBuilding=$false;PrivilegeChecked=$true;PermissionCached=$false;PrivilegeId=$null;PathLength=700;TravelSeconds=264;DeadlineRemaining=700;PhaseReserve=360}
Assert-FirstHomeSite $site
function Copy-HomeFixture($value){$value|ConvertTo-Json -Depth 30|ConvertFrom-Json}
function Deny-HomeFixture([scriptblock]$action){$denied=$false;try{& $action}catch{$denied=$true};if(-not $denied){throw 'Unsafe home receipt was accepted'}}
foreach($mutation in @(
 {param($x)$x.HeightRange=1.41}, {param($x)$x.EntryDelta=0.26}, {param($x)$x.OutsideDelta=-0.26},
 {param($x)$x.NativePreview=$false}, {param($x)$x.Collision=$true}, {param($x)$x.Topology=2048},
 {param($x)$x.MonumentBoundsDistance=0}, {param($x)$x.MonumentOriginDistance=119}, {param($x)$x.ForeignDistance=44},
 {param($x)$x.RoadDistance=24}, {param($x)$x.PreventBuilding=$true}, {param($x)$x.PrivilegeId='88'},
 {param($x)$x.PermissionCached=$true}, {param($x)$x.PrivilegeChecked=$false}, {param($x)$x.PathLength=801}, {param($x)$x.TravelSeconds=301}, {param($x)$x.DeadlineRemaining=623}
)){$x=Copy-HomeFixture $site;& $mutation $x;Deny-HomeFixture {Assert-FirstHomeSite $x}}
# Synthetic inputs only. A free or disconnected spawned prefab must never pass as a home.
$roles=@('FOUNDATION','WALL_N','WALL_E','WALL_W','DOORWAY','ROOF','DOOR','TC')
$rows=@(for($i=0;$i -lt 8;$i++){@{Role=$roles[$i];NetId=[string](100+$i);Type=$(if($i -lt 6){'BuildingBlock'}elseif($i -eq 6){'Door'}else{'BuildingPrivlidge'});Prefab='assets/synthetic/home.prefab';Owner='123';BuildingId='10';Health=100;Saving=$true;Registered=$true;Support=$true;Links=$(if($i -lt 6){1}else{0});Grade=$(if($i -lt 6){'Wood'}else{$null});Position=@($i,1,0);Rotation=@(0,0,0,1)}})
$h=[pscustomobject]@{Entities=$rows;Owner='123';BuildingId='10';Placement='SERVER_ACCOUNTED_BUILD';ForeignUnchanged=$true}
Assert-FirstHomeStructure $h
foreach($mutation in @(
 {param($x)$x.Entities[3].Registered=$false}, {param($x)$x.Entities[0].Support=$false},
 {param($x)$x.Entities[4].Owner='456'}, {param($x)$x.Entities[1].BuildingId='11'},
 {param($x)$x.Entities[2].Links=0}, {param($x)$x.Entities[7].Type='StorageContainer'},
 {param($x)$x.Entities[6].NetId=$x.Entities[7].NetId}, {param($x)$x.ForeignUnchanged=$false}
)){$x=Copy-HomeFixture $h;Assert-FirstHomeStructure $x;& $mutation $x;Deny-HomeFixture {Assert-FirstHomeStructure $x}}
Write-Output 'PASS OFFLINE_ONLY 1: real native structure, support, owner, unique entities and registration contract'
# Cost is independently specified: 50 wood consumed, never 0/free or 51.
$payment=[pscustomobject]@{Before=@(@{Uid='1';Shortname='wood';Amount=80;Condition=0;MaxCondition=0},@{Uid='3';Shortname='stonehatchet';Amount=1;Condition=80;MaxCondition=100});After=@(@{Uid='1';Shortname='wood';Amount=30;Condition=0;MaxCondition=0},@{Uid='3';Shortname='stonehatchet';Amount=1;Condition=80;MaxCondition=100});Costs=@(@{Shortname='wood';Amount=50});Output=$null}
$payment=Copy-HomeFixture $payment
Assert-FirstHomePayment $payment
foreach($amount in @(80,29)){$x=Copy-HomeFixture $payment;$x.After[0].Amount=$amount;Deny-HomeFixture {Assert-FirstHomePayment $x}}
$x=Copy-HomeFixture $payment;$x.After+=@{Uid='2';Shortname='stones';Amount=5};Deny-HomeFixture {Assert-FirstHomePayment $x}
$x=Copy-HomeFixture $payment;$x.After[0].Uid='2';Deny-HomeFixture {Assert-FirstHomePayment $x}
$x=Copy-HomeFixture $payment;$x.After[1].Condition=100;Deny-HomeFixture {Assert-FirstHomePayment $x}
Write-Output 'PASS OFFLINE_ONLY 2: exact native UID payment, no free build, recredit or unrelated output'
$switch=Copy-HomeFixture @{FromUid='3';ToUid='1';Wear=0.334;Reserve=1;Before=@(@{Uid='1';Shortname='rock';Amount=1;Condition=82;MaxCondition=100},@{Uid='3';Shortname='stonehatchet';Amount=1;Condition=1.3;MaxCondition=100});
    After=@(@{Uid='1';Shortname='rock';Amount=1;Condition=82;MaxCondition=100},@{Uid='3';Shortname='stonehatchet';Amount=1;Condition=1.3;MaxCondition=100});
    Equipment=@{ActiveUid='1';ItemUid='1';HeldItemUid='1';ActorNetId='19';OwnerNetId='19';HeldOwnerNetId='19';HeldParentNetId='19';HeldType='BaseMelee';IsHeld=$true}}
Assert-FirstHomeToolSwitch $switch '1' '3'
foreach($mutation in @({param($x)$x.Before[1].Condition=0},{param($x)$x.After[1].Condition=100},{param($x)$x.ToUid='7'},{param($x)$x.Equipment.HeldOwnerNetId='77'},{param($x)$x.Equipment.ItemUid='3'},{param($x)$x.Wear=0})){
    $x=Copy-HomeFixture $switch;& $mutation $x;Deny-HomeFixture {Assert-FirstHomeToolSwitch $x '1' '3'}
}
$op=Copy-HomeFixture @{Before=$switch.Before;Harvest=@{ToolUid='1'}}
if((Assert-FirstHomeGatherTool $op $switch '3' '1' '3' '19') -ne '1'){throw 'Original rock transition missing'}
Deny-HomeFixture {Assert-FirstHomeGatherTool $op $null '3' '1' '3' '19'}
Deny-HomeFixture {Assert-FirstHomeGatherTool $op $switch '3' '1' '3' '20'}
$x=Copy-HomeFixture $op;$x.Before[0].Condition=81;Deny-HomeFixture {Assert-FirstHomeGatherTool $x $switch '3' '1' '3' '19'}
$x=Copy-HomeFixture $op;$x.Harvest.ToolUid='3';Deny-HomeFixture {Assert-FirstHomeGatherTool $x $switch '1' '1' '3' '19'}
$s=[pscustomobject]@{WorldKey=('A'*64);ActorId='avatar-007-0123456789abcdef0123456789abcdef';Home=$h;InventorySHA256=('B'*64)}
$r=Copy-HomeFixture $s
Assert-FirstHomeRestore $s $r
$x=Copy-HomeFixture $r;$x.WorldKey='C'*64;Deny-HomeFixture {Assert-FirstHomeRestore $s $x}
$x=Copy-HomeFixture $r;$x.Home.Entities[7].NetId='999';Deny-HomeFixture {Assert-FirstHomeRestore $s $x}
$x=Copy-HomeFixture $r;$x.ActorId='another';Deny-HomeFixture {Assert-FirstHomeRestore $s $x}
Write-Output 'PASS OFFLINE_ONLY 3: exact same world/home/logical owner restore; missing or foreign TC denied'
if((Get-WorldDistance (Get-HomeRotated @(0,0,0,1) @(1,2,3)) @(1,2,3)) -gt 0.00001 -or
    (Get-WorldDistance (Get-HomeRotated @(0,0.7071067811865475,0,0.7071067811865475) @(1,0,0)) @(0,0,-1)) -gt 0.00001){throw 'Native door aperture rotation math is invalid'}
$samples=@(for($i=0;$i -lt 7;$i++){@{Time=$i*0.5;Position=@(@(-2,-1,0.2,1,0.2,-1,-2)[$i],0,0);ActorNetId='19'}})
$events=@(
 @{Event='ISSUED';Stage='INSIDE_TC';Time=0;Start=@(-2,0,0);Target=@(1,0,0);Path='PathComplete'},
 @{Event='ARRIVED';Time=1.5;Position=@(1,0,0)},
 @{Event='ISSUED';Stage='OUTSIDE';Time=1.5;Start=@(1,0,0);Target=@(-2,0,0);Path='PathComplete'},
 @{Event='ARRIVED';Time=3;Position=@(-2,0,0)},
 @{Event='CROSSED_IN';Time=1;Position=@(0,0,0)},@{Event='CROSSED_OUT';Time=2.5;Position=@(0,0,0)},
 @{Event='TC_REACHED';Time=1.5;Position=@(1,0,0);LineOfSight=$true;Range=0.5},
 @{Event='DOOR_COLLIDER';Changed=$true;Closed=@{Center=@(0,1,0)};Open=@{Center=@(0.5,1,0.5)}})
foreach($sample in $samples|Select-Object -Skip 1){$events+=@{Event='PHYSICS';Time=$sample.Time;Position=$sample.Position;Clear=$true;Inside=$sample.Position[0] -gt 0;OwnedFloor=$true;DoorOpen=$true}}
$nav=Copy-HomeFixture @{Samples=$samples;FirstHome=@{Home=@{Entities=@(@{Role='DOOR';NetId='107';Position=@(0,0,0);Rotation=@(0,0,0,1)})};
 Portal=@{DoorNetId='107';LocalCenter=@(0,1,0);LocalExtents=@(0.1,1.1,0.65);Scale=@(1,1,1);Center=@(0,1,0);Normal=@(1,0,0);Right=@(0,0,1);Up=@(0,1,0);Outside=@(-2,0,0);Inside=@(1,0,0);HalfWidth=0.65;HalfHeight=1.1;Radius=0.5;Height=1.8};Navigation=$events}}
Assert-FirstHomeNavigation $nav
foreach($mutation in @(
 {param($x)($x.FirstHome.Navigation|Where-Object Event -eq CROSSED_IN).Position=@(9,0,0)},
 {param($x)($x.FirstHome.Navigation|Where-Object Stage -eq INSIDE_TC).Path='PathPartial'},
 {param($x)($x.FirstHome.Navigation|Where-Object Event -eq DOOR_COLLIDER).Open=@{Center=@(0,1,0)}},
 {param($x)($x.FirstHome.Navigation|Where-Object {$_.Event -eq 'PHYSICS' -and $_.Inside})[0].OwnedFloor=$false},
 {param($x)($x.FirstHome.Navigation|Where-Object Event -eq PHYSICS)[0].Clear=$false},
 {param($x)($x.FirstHome.Navigation|Where-Object Event -eq PHYSICS)[0].DoorOpen=$false},
 {param($x)$x.FirstHome.Portal.LocalExtents[2]=0.4;$x.FirstHome.Portal.HalfWidth=0.4}
)){$x=Copy-HomeFixture $nav;& $mutation $x;Deny-HomeFixture {Assert-FirstHomeNavigation $x}}
Write-Output 'PASS OFFLINE_ONLY 4: measured portal crossing, native collider motion, complete path and capsule/floor clearance'
$world=@{Kind='PROCEDURAL';Level='Procedural Map';Seed=17;Size=3500;MapVersion='289';MapSHA256=('A'*64);WipeId='11111111-1111-1111-1111-111111111111'}
$keys=Get-EconomyWorldKeys $world
$sources=@(for($i=0;$i -lt 3;$i++){@{Incarnation=('source'+$i);SavedUid=[string](20+$i);Prefab='synthetic-resource.prefab';Type=$(if($i -eq 2){'OreResourceEntity'}else{'TreeEntity'});Resource=$(if($i -eq 2){'stones'}else{'wood'});InitialPool=1000;ExpectedPool=760;InitialFraction=1;ExpectedFraction=0.76;Position=@($i,2,3);Rotation=@(0,0,0,1);Scale=@(1,1,1);Bounds=@(0,0,0,1,1,1);Population='natural';StartAmount=1000;Health=80}})
$replays=@(foreach($pass in @(1,2)){foreach($source in $sources){@{Pass=$pass;Incarnation=$source.Incarnation;SavedUid=$source.SavedUid;Candidates=1;DiskWitness=$true;Decision=$(if($pass -eq 1){'APPLY'}else{'NOOP'});Before=$(if($pass -eq 1){1000}else{760});After=760;FractionBefore=$(if($pass -eq 1){1}else{0.76});FractionAfter=0.76;Neighbors=2;NeighborsUnchanged=$true;ItemCredits=0;Actual=(Copy-HomeFixture $source);SavedHealth=80;CheckpointHealth=80;StartHealth=100;Staged=$source.Type -eq 'OreResourceEntity';CurrentHealth=$(if($source.Type -eq 'OreResourceEntity'){100}else{80})}}})
$sourceFixture=Copy-HomeFixture @{Status='GREEN';Mode='RESTORE';State=@{ActorId='actor';CraftIntent='intent';ProductUid='14'};
 Economy=@{World=$world;WorldKey=$keys.WorldKey;MapKey=$keys.MapKey;State=@{Schema=2;World=$world;WorldKey=$keys.WorldKey;ActorId='actor';CraftIntent='intent';ProductUid='14';Sources=$sources;SnapshotHealth=@{source0=80;source1=80;source2=100}};
 CrashAtomic='NOT_PROVEN';CrashRecovery='OFFLINE_ONLY';Replays=$replays;InputSnapshotHealth=@{source0=80;source1=80;source2=80};CraftReplay=@{CraftState='COMMITTED';DuplicateDenied=$true;InventoryUnchanged=$true;OutputUid='14'}}}
Assert-FirstHomeSources $sourceFixture
foreach($mutation in @(
 {param($x)$x.Economy.Replays=@($x.Economy.Replays|Where-Object Incarnation -ne 'source1')},
 {param($x)$x.Economy.Replays[1].DiskWitness=$false}, {param($x)$x.Economy.Replays[1].Actual.Position[0]=999},
 {param($x)$x.Economy.Replays[1].ItemCredits=1}, {param($x)$x.Economy.Replays[1].NeighborsUnchanged=$false},
 {param($x)$x.Economy.Replays[4].Decision='APPLY'}, {param($x)$x.Economy.CraftReplay.CraftState='DEBITED'}
)){$x=Copy-HomeFixture $sourceFixture;& $mutation $x;Deny-HomeFixture {Assert-FirstHomeSources $x}}
Write-Output 'PASS OFFLINE_ONLY 5: arbitrary source count retains exact 009 disk/geometry/depletion/NOOP/neighbor contracts'
$inventory=@(for($i=0;$i -lt 4;$i++){@{Uid=@('11','14','12','13')[$i];Shortname=@('rock','stonehatchet','building.planner','hammer')[$i];Amount=1;Condition=$(if($i -eq 2){0}else{80});MaxCondition=$(if($i -eq 2){0}else{100});Role='BELT';Slot=$i;ContainerUid='2';OwnerNetId='19'}})
$containers=@(@{Role='MAIN';Uid='1';Capacity=24;OwnerNetId='19'},@{Role='BELT';Uid='2';Capacity=6;OwnerNetId='19'},@{Role='WEAR';Uid='3';Capacity=8;OwnerNetId='19'})
$held=@(for($i=0;$i -lt 4;$i++){@{Uid=$inventory[$i].Uid;HeldNetId=[string](60+$i);HeldItemUid=$inventory[$i].Uid;OwnerNetId='19';ParentNetId='19'}})
$refs=@(for($i=0;$i -lt 4;$i++){@{ItemUid=$inventory[$i].Uid;SavedHeldNetId=[string](50+$i);Before=@{NetId=[string](50+$i);Found=$false};After=@{NetId=[string](50+$i);Found=$false}}})
$equipment=@{HeldNetId='61';ActorNetId='19';ActiveUid='14'}
$heldFixture=Copy-HomeFixture @{Actor=@{NetId='19'};State=@{ProductUid='14'};Containers=$containers;Inventory=$inventory;Equipment=$equipment;
 EquipmentSamples=@(foreach($t in @(1,1.5,2)){@{Time=$t;Equipment=(Copy-HomeFixture $equipment)}});
 RestoreAudit=@{Stage='COMPLETE';ParentPasses=2;ItemsBefore=10;ItemsAfter=14;LoadCalled=$true;IncomingAbsent=$true;PreLoadHeldZero=$true;SourceUnchanged=$true;ForeignItemsUnchanged=$true;ForeignEntitiesUnchanged=$true;HeldStable=$true;
 SourceContainers=$containers;SourceInventory=$inventory;NativeBefore=$inventory;Loaded=$inventory;TransientRefs=$refs;HeldItems=$held}}
Assert-FirstHomeHeldRestore $heldFixture
foreach($mutation in @(
 {param($x)$x.RestoreAudit.HeldItems=@($x.RestoreAudit.HeldItems|Select-Object -First 3)},
 {param($x)$x.RestoreAudit.HeldItems[3].HeldNetId='53'}, {param($x)$x.RestoreAudit.HeldItems[2].OwnerNetId='90'},
 {param($x)$x.RestoreAudit.TransientRefs[3].After.Found=$true}, {param($x)$x.RestoreAudit.NativeBefore[3].Condition=90},
 {param($x)$x.RestoreAudit.SourceContainers[0].Capacity=0}, {param($x)$x.EquipmentSamples[2].Equipment.HeldNetId='99'}
)){$x=Copy-HomeFixture $heldFixture;& $mutation $x;Deny-HomeFixture {Assert-FirstHomeHeldRestore $x}}
Write-Output 'PASS OFFLINE_ONLY 6: all four paid/native held items restore with strict original UID and alias/foreign guards'

$repo=Split-Path $PSScriptRoot -Parent
$homeSource=Get-Content (Join-Path $repo 'src/home/FirstHome.cs') -Raw
$avatarSource=Get-Content (Join-Path $repo 'src/plugins/RustBotsAvatarSurvival.cs') -Raw
$runnerSource=Get-Content (Join-Path $PSScriptRoot 'Invoke-NavigationProbe.ps1') -Raw
if($homeSource -notmatch 'HomeJourneySeconds=2100' -or $homeSource -notmatch 'HomeBuildReserve=360' -or
    $avatarSource -match 'firstHome\?1100' -or $avatarSource -notmatch 'HomeJourneySeconds' -or
    $runnerSource -notmatch 'FirstHomeSmoke' -or $runnerSource -notmatch '2400' -or
    $homeSource -match 'RUSTNAV_OR_TRAVEL_BOUND' -or $homeSource -notmatch 'reasons.Add\("TIME_BUDGET"\)' -or
    $homeSource -notmatch 'reasons.Add\("NAV_PATH"\)' -or $homeSource -notmatch 'DeadlineRemaining=remaining,PhaseReserve=reserve'){
    throw '011 phase schedule still conflates path/time or runner/plugin deadlines'
}
$fake=Copy-HomeFixture @{Status='PARTIAL';FirstHome=@{Schema=1;DiagnosticOnly=$true;Fixture=@{Source='TEST_FIXTURE_WOOD'}}}
Deny-HomeFixture {Assert-FirstHomeResult $fake}
Write-Output 'PASS OFFLINE_ONLY 7: measured FirstHome schedule, independent runner deadline and no fixture promotion to natural receipt'

# A foundation surface without a female socket still uses Socket_Free.TestTarget(onTerrain).
# Reject the exact 011 target, missing native previews, blocked geometry and paid retries.
if(-not (Get-Command Assert-FirstHomeTcPlacement -ErrorAction SilentlyContinue)){throw '012 TC native placement evidence contract is not implemented'}
$tc=Copy-HomeFixture @{Role='TC';Entity='108';NativeCall='Planner.DoBuild(Construction.Target,Construction)';
    Before=@(@{Uid='41';Shortname='cupboard.tool';Amount=1;Condition=0;MaxCondition=0});After=@();
    Diagnostic=@{OnTerrain=$true;Socket=$null;Parent='100';SurfaceParent='100';MaleSockets=1;NativePreview=$true;NativeLos=$true;InsideObject=$false;DeployBlocked=$false;CanBuild=$true;HookDenied=$false;Reach=3;MaxReach=4;Unchanged=$true;LegacyUnchanged=$true}}
Assert-FirstHomeTcPlacement @($tc)
foreach($mutation in @({param($x)$x.Diagnostic.OnTerrain=$false;$x.Diagnostic.MaleSockets=0},
    {param($x)$x.Diagnostic.SurfaceParent='999'},{param($x)$x.Diagnostic.NativeLos=$false},
    {param($x)$x.Diagnostic.DeployBlocked=$true},{param($x)$x.Diagnostic.NativePreview=$false},
    {param($x)$x.Diagnostic.Unchanged=$false},{param($x)$x.Diagnostic.LegacyUnchanged=$false},{param($x)$x.After=$x.Before})){
    $x=Copy-HomeFixture $tc;& $mutation $x;Deny-HomeFixture {Assert-FirstHomeTcPlacement @($x)}
}
Deny-HomeFixture {Assert-FirstHomeTcPlacement @($tc,$tc)}
Write-Output 'PASS OFFLINE_ONLY 8: free-surface TC native preview, exact one-item debit and no paid retry'

# The live 012 failure was a native Unity getter on a detached prefab attribute.
# Inspect the actual compiled method, without loading/executing game assemblies.
& (Join-Path $PSScriptRoot 'Test-PluginCompile.ps1') -PluginName RustBotsAvatarSurvival
$diagnosticIl=& dotnet run --file (Join-Path $PSScriptRoot 'Inspect-RustApi.cs') -p:PublishAot=false -p:NuGetAudit=false -- (Join-Path $repo '.local/compile/RustBotsAvatarSurvival.dll') 'RustBotsAvatarSurvival$' '^HomePreviewTc$'
if($LASTEXITCODE -ne 0){throw 'TC diagnostic metadata inspection failed'}
$diagnosticText=$diagnosticIl -join "`n"
if($diagnosticText -match 'ldfld \.Construction::deployable\r?\n\s*IL_[0-9A-F]+: callvirt UnityEngine.Object::get_name'){
    throw 'TC telemetry dereferences native Unity Object.name on detached prefab attribute'
}
Write-Output 'PASS OFFLINE_ONLY 9: compiled TC telemetry avoids native name getter on prefab attribute'

if(-not (Get-Command Assert-FirstHomeTcAuthorization -ErrorAction SilentlyContinue)){throw '012 native TC autoauth contract is not implemented'}
$auth=Copy-HomeFixture @{TcNetId='108';Actor='15';Owner='15';BeforeAuthorized=@('15');AfterAuthorized=@('15');InventoryCount=0;NativeAutoauth=$true;NativeAddCalled=$false;AuthorizationHookAllowed=$true;Authed=$true;CanBuild=$true;Registered=$true;BuildingId='10';ExpectedBuildingId='10'}
$actualTc=Copy-HomeFixture @{NetId='108';Role='TC';Type='BuildingPrivlidge';Owner='15';BuildingId='10'}
Assert-FirstHomeTcAuthorization $auth '15' '10' $actualTc
$self=Copy-HomeFixture $auth;$self.BeforeAuthorized=@();$self.NativeAutoauth=$false;$self.NativeAddCalled=$true
Assert-FirstHomeTcAuthorization $self '15' '10' $actualTc
foreach($mutation in @({param($x)$x.BeforeAuthorized=@('15','16')},{param($x)$x.AfterAuthorized=@('16')},
    {param($x)$x.Owner='16'},{param($x)$x.InventoryCount=1},{param($x)$x.BuildingId='11'},
    {param($x)$x.Authed=$false},{param($x)$x.NativeAddCalled=$true},{param($x)$x.AuthorizationHookAllowed=$false})){
    $x=Copy-HomeFixture $auth;& $mutation $x;Deny-HomeFixture {Assert-FirstHomeTcAuthorization $x '15' '10' $actualTc}
}
$x=Copy-HomeFixture $auth;$x.Actor=$x.Owner='16';$x.BeforeAuthorized=$x.AfterAuthorized=@('16')
Deny-HomeFixture {Assert-FirstHomeTcAuthorization $x '15' '10' $actualTc}
$x=Copy-HomeFixture $auth;$x.BuildingId=$x.ExpectedBuildingId='11'
Deny-HomeFixture {Assert-FirstHomeTcAuthorization $x '15' '10' $actualTc}
$x=Copy-HomeFixture $auth;$x.TcNetId='109'
Deny-HomeFixture {Assert-FirstHomeTcAuthorization $x '15' '10' $actualTc}
Write-Output 'PASS OFFLINE_ONLY 10: own native autoauth accepted, foreign auth/items/group and unauthorized self-add denied'

# 013: a composite false or an uncalculated default path must never be evidence.
if(-not (Get-Command Assert-FirstHomeApproach -ErrorAction SilentlyContinue)){throw '013 separate approach evidence contract is not implemented'}
$approach=Copy-HomeFixture @{Step=7;Label='CURRENT';ActorNetId='19';Actor=@(0,0,0);Candidate=@(0,0,0);Sampled=$true;NavPoint=@(0,0,0);Foot=@(0,0.05,0);
    Surface='GROUND_TERRAIN';SurfaceEntity=$null;SampleDelta=0;TerrainDelta=0;NormalY=1;WaterDepth=0;CapsuleClear=$true;Pending=$false;OnNavmesh=$true;
    PathCalculated=$true;Path='PathComplete';PathLength=0;CanBuild=$true;Los=$true;Reach=2;MaxReach=4;Accepted=$true;Reason='ACCEPTED'}
Assert-FirstHomeApproach $approach
foreach($mutation in @({param($x)$x.Reason=$null},{param($x)$x.Sampled=$false},{param($x)$x.PathCalculated=$false},
    {param($x)$x.Path='PathPartial'},{param($x)$x.CapsuleClear=$false},{param($x)$x.Surface='ROOF'},
    {param($x)$x.Pending=$true},{param($x)$x.Los=$false},{param($x)$x.Reach=4.1})){
    $x=Copy-HomeFixture $approach;& $mutation $x;Deny-HomeFixture {Assert-FirstHomeApproach $x}
}
$x=Copy-HomeFixture $approach;$x.Accepted=$false;$x.Reason='NAV_SAMPLE';$x.Sampled=$false
Assert-FirstHomeApproach $x
$x.Reason=$null;Deny-HomeFixture {Assert-FirstHomeApproach $x}
$legacy=Copy-HomeFixture @{Label='LEGACY_COMPOSITE';Step=7;ActorNetId='19';Actor=@(0,0,0);Input=@(0,0,-3);Sampled=$true;NavPoint=@(0,0,-3);RayHit=$true;Reason='CAPSULE_OVERLAP';SampleDelta=0;TerrainDelta=0;Normal=@(0,1,0);WaterDepth=0;Overlaps=@(@{Self=$true})}
$diagnosis=Copy-HomeFixture @{NavigationComplete=$true;Restored=$false;Approaches=@($legacy,$approach)}
Assert-FirstHomeApproaches $diagnosis '19'
$x=Copy-HomeFixture $diagnosis;$x.Approaches[0].Reason=$null;Deny-HomeFixture {Assert-FirstHomeApproaches $x '19'}
$x=Copy-HomeFixture $diagnosis;$x.Approaches=@($approach);Deny-HomeFixture {Assert-FirstHomeApproaches $x '19'}
$x=Copy-HomeFixture $diagnosis;$x.Approaches[0].Reason='ACCEPTED';Deny-HomeFixture {Assert-FirstHomeApproaches $x '19'}
Write-Output 'PASS OFFLINE_ONLY 11: approach subreason, physical support, pending tiles and actual complete path'

if(-not (Get-Command Assert-FirstHomeDoorPlacement -ErrorAction SilentlyContinue)){throw '013 native door evidence contract is not implemented'}
$door=Copy-HomeFixture @{Role='DOOR';Entity='107';Parent='104';Socket='synthetic/doorway-female/1';NativeCall='Planner.DoBuild(Construction.Target,Construction)';
    Before=@(@{Uid='42';Shortname='door.hinged.wood';Amount=1;Condition=0;MaxCondition=0});After=@()}
$doorRow=Copy-HomeFixture @{Role='DOOR';NetId='107';Type='Door';Owner='19';BuildingId='10';Registered=$true;Saving=$true;Support=$true;Health=100}
Assert-FirstHomeDoorPlacement @($door) $doorRow '104'
foreach($mutation in @({param($x)$x.NativeCall='Spawn'},{param($x)$x.After=$x.Before},{param($x)$x.Entity='108'},{param($x)$x.Parent='999'},{param($x)$x.Socket=$null})){
    $x=Copy-HomeFixture $door;& $mutation $x;Deny-HomeFixture {Assert-FirstHomeDoorPlacement @($x) $doorRow '104'}
}
Deny-HomeFixture {Assert-FirstHomeDoorPlacement @($door,$door) $doorRow '104'}
Write-Output 'PASS OFFLINE_ONLY 12: native door socket/entity binding and exact paid item, no fake spawn or retry'

if(-not (Get-Command Assert-FirstHomeUpkeep -ErrorAction SilentlyContinue)){throw '013 native upkeep evidence contract is not implemented'}
$upkeep=Copy-HomeFixture @{Before=@(@{Uid='50';Shortname='wood';Amount=5;Condition=0;MaxCondition=0});After=@();Transferred=@(@{Uid='50';Shortname='wood';Amount=5;Condition=0;MaxCondition=0});
    TcInventory=@(@{Uid='50';Shortname='wood';Amount=5;Condition=0;MaxCondition=0});Rate=@(@{Shortname='wood';Amount=100});NativeRate=@(@{Shortname='wood';Amount=99.5});
    Period=1440;MinutesBefore=0;MinutesAfter=72.36181;Authed=$true;Privilege=$true;DecayEnabled=$true}
Assert-FirstHomeUpkeep $upkeep
foreach($mutation in @({param($x)$x.MinutesAfter=59.9},{param($x)$x.MinutesBefore=100},{param($x)$x.TcInventory[0].Uid='51'},
    {param($x)$x.NativeRate[0].Amount=0},{param($x)$x.DecayEnabled=$false},{param($x)$x.Transferred=@()})){
    $x=Copy-HomeFixture $upkeep;& $mutation $x;Deny-HomeFixture {Assert-FirstHomeUpkeep $x}
}
Write-Output 'PASS OFFLINE_ONLY 13: native fractional upkeep, >=60 actual minutes, exact UID conservation and no free credit'
