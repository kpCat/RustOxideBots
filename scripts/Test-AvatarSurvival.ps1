#Requires -Version 5.1
$ErrorActionPreference='Stop'
$validator=Join-Path $PSScriptRoot 'AvatarSurvivalValidation.ps1'
if(-not (Test-Path $validator)){throw '007 receipt validator is missing'}
. $validator
function Denied([scriptblock]$action) { $caught=$false;try { & $action }catch{$caught=$true};if(-not $caught){throw 'False-positive receipt accepted'} }
function Clone($o) { $o | ConvertTo-Json -Depth 30 | ConvertFrom-Json | ForEach-Object { $_ } }
# One synthetic contract fixture; never evidence of executing Rust.
$rock=[pscustomobject]@{Uid='11';Shortname='rock';Amount=1;Condition=90;MaxCondition=100;Role='BELT';Slot=0;ContainerUid='2';OwnerNetId='9'}
$axe=[pscustomobject]@{Uid='14';Shortname='stonehatchet';Amount=1;Condition=100;MaxCondition=100;Role='BELT';Slot=1;ContainerUid='2';OwnerNetId='9'}
$kit=Clone $rock;$kit.Condition=100
$wood=Clone $rock;$wood.Uid='12';$wood.Shortname='wood';$wood.Amount=200;$wood.Condition=0;$wood.MaxCondition=0;$wood.Role='MAIN';$wood.Slot=0;$wood.ContainerUid='1'
$stone=Clone $wood;$stone.Uid='13';$stone.Shortname='stones';$stone.Amount=100;$stone.Slot=1
$n=[pscustomobject]@{Status='GREEN';Mode='JOURNEY';SpawnCount=1;ManualPositionWrites=0;
 Actor=[pscustomobject]@{NetId='9';Type='ScientistNPC';IsBasePlayer=$true;IsNpc=$true;HasConnection=$false;NativeBotId=$true;Prefab='assets/rust.ai/agents/npcplayer/humannpc/scientist/scientistnpc_roam.prefab'};
 State=[pscustomobject]@{ActorId='avatar-007-0123456789abcdef0123456789abcdef';Goal='COMPLETE';ToolUid='11';ProductUid='14';ActiveUid='14';CraftIntent='paid';CraftStatus='CRAFTED'};
 Containers=@(@{Role='MAIN';Uid='1';OwnerNetId='9';Capacity=24},@{Role='BELT';Uid='2';OwnerNetId='9';Capacity=6},@{Role='WEAR';Uid='3';OwnerNetId='9';Capacity=8});
 Normalization=@{Before=@();AfterStrip=@();RemovedAbsent=$true};StarterKit=@($kit);Inventory=@($rock,$axe);
 Equipment=@{ActorNetId='9';ActiveUid='14';ItemUid='14';OwnerNetId='9';HeldOwnerNetId='9';HeldParentNetId='9';HeldType='BaseMelee';IsHeld=$true;HeldNetId='15';HeldItemUid='14'};
 EquipmentChecks=4;Persistence=@{Saved=$true;Restored=$false};Conservation=@{Ok=$true};
 Recipe=@{Shortname='stonehatchet';AmountToCreate=1;Known=$true;Workbench=0;Ingredients=@(@{Shortname='wood';Amount=200},@{Shortname='stones';Amount=100})};
 Samples=@(@{Time=1;Position=@(0,0,0)},@{Time=1.5;Position=@(1,0,0)},@{Time=2;Position=@(2,0,0)},@{Time=2.5;Position=@(3,0,0)},@{Time=3;Position=@(4,0,0)});TotalTraveled=4;
 Legs=@(@{Status='ARRIVED';SourceId='20';Planned='PathComplete';IssuedSpeed=3;Start=@(0,0,0);End=@(2,0,0);Target=@(2,0,0)},@{Status='ARRIVED';SourceId='21';Planned='PathComplete';IssuedSpeed=3;Start=@(2,0,0);End=@(4,0,0);Target=@(4,0,0)});
 Harvests=@(@{SourceId='20';Resource='wood';Provenance='NATURAL';Mechanism='NATIVE_PLAYER_GATHER';Amount=200;PoolBefore=1000;PoolAfter=760;ToolConditionBefore=100;ToolConditionAfter=95;InitiatorPlayer=$true;WeaponOwned=$true;DidGather=$true;AdapterCredit=0;Distance=2;LineOfSight=$true;Grounded=$true;Before=@($kit);After=@()},@{SourceId='21';Resource='stones';Provenance='NATURAL';Mechanism='NATIVE_PLAYER_GATHER';Amount=100;PoolBefore=500;PoolAfter=380;ToolConditionBefore=95;ToolConditionAfter=90;InitiatorPlayer=$true;WeaponOwned=$true;DidGather=$true;AdapterCredit=0;Distance=2;LineOfSight=$true;Grounded=$true;Before=@();After=@()});
 Craft=@{Mechanism='NATIVE_PLAYER_CRAFT';Before=@($rock,$wood,$stone);After=@($rock,$axe);Output=$axe;Debits=@(@{Uid='12';Shortname='wood';Consumed=200},@{Uid='13';Shortname='stones';Consumed=100});NativeAccepted=$true;QueueAfter=0;Elapsed=16};
 Negatives=@(@{Kind='MISSING_UID';Accepted=$false;Unchanged=$true},@{Kind='FOREIGN_UID';Accepted=$false;Unchanged=$true},@{Kind='MISSING_INGREDIENTS';Accepted=$false;Unchanged=$true},@{Kind='RECIPE_UNAVAILABLE';Accepted=$false;Unchanged=$true},@{Kind='WORKBENCH_REQUIRED';Accepted=$false;Unchanged=$true},@{Kind='DUPLICATE_INTENT';Accepted=$false;Unchanged=$true})}
$mid=Clone $kit;$mid.Condition=95
$n.Harvests[0].After=@($mid,$wood);$n.Harvests[1].Before=@($mid,$wood);$n.Harvests[1].After=@($rock,$wood,$stone)
foreach($s in $n.Samples){$s.ActorNetId='9'}
$n.Legs[0].StartTime=1;$n.Legs[0].EndTime=2;$n.Legs[1].StartTime=2;$n.Legs[1].EndTime=3
for($j=0;$j -lt 2;$j++){
    $h=$n.Harvests[$j];$h.ActorNetId='9';$h.Time=2+$j;$h.Actor=@((2+2*$j),0,0);$h.SourcePosition=@((4+2*$j),0,0)
    $h.SourceType=if($j -eq 0){'TreeEntity'}else{'OreResourceEntity'};$h.SourcePrefab='assets/synthetic/resource.prefab';$h.NewDrops=0
}
$n=Clone $n
Assert-AvatarSurvivalResult $n
foreach($mutate in @(
 {param($x)$x.Equipment.ActiveUid='99'}, {param($x)$x.Inventory[1].Uid='99'},
 {param($x)$x.Inventory+=Clone $wood}, {param($x)$x.Normalization.AfterStrip=@($wood)},
 {param($x)$x.Harvests[0].AdapterCredit=200}, {param($x)$x.Harvests[0].InitiatorPlayer=$false},
 {param($x)$x.Harvests[0].PoolAfter=1000}, {param($x)$x.Inventory[0].Condition=100},
 {param($x)$x.Legs[1].IssuedSpeed=0}, {param($x)$x.Negatives[0].Accepted=$true},
 {param($x)$x.Harvests[0].Actor=@(90,0,0)}, {param($x)$x.Legs[1].End=@(80,0,0)},
 {param($x)$x.Craft.After=@($x.Craft.After|Where-Object Shortname -ne 'stonehatchet')},
 {param($x)$x.Craft.Output.Condition=20}, {param($x)$x.Harvests[0].After[0].OwnerNetId='98'},
 {param($x)$x.Harvests[0].After[0].Condition=100}, {param($x)$x.Equipment.HeldItemUid='98'}
)){$x=Clone $n;Assert-AvatarSurvivalResult $x;& $mutate $x;Denied {Assert-AvatarSurvivalResult $x}}
Write-Output 'PASS FIXTURE 1: balances, earned exact held UID, natural debit, normalization and speed guards'
$r=Clone $n;$r.Mode='RESTORE';$r.Harvests=@();$r.Craft=$null;$r.StarterKit=@();$r.Persistence.Restored=$true
$r.Actor.NetId='19'
foreach($c in $r.Containers){$c.OwnerNetId='19'}
foreach($i in $r.Inventory){$i.OwnerNetId='19'}
foreach($field in @('ActorNetId','OwnerNetId','HeldOwnerNetId','HeldParentNetId')){$r.Equipment.$field='19'}
$r.Equipment.HeldNetId='25'
$alias=@{Found=$true;NetId='15';Type='BaseMelee';Prefab='assets/synthetic/foreign.prefab';ParentNetId='90';OwnerNetId='90';ItemUid='91';OwnerItemUid='91';IsDestroyed=$false;InTestWorld=$true;ProbeOwned=$false}
$absent=@{Found=$false;NetId='16'}
$r | Add-Member NoteProperty RestoreAudit ([pscustomobject]@{Stage='COMPLETE';LoadCalled=$true;IncomingAbsent=$true;PreLoadHeldZero=$true;SourceUnchanged=$true;
 ItemsBefore=10;ItemsAfter=12;ForeignItemsUnchanged=$true;ForeignEntitiesUnchanged=$true;ParentPasses=2;HeldStable=$true;
 SourceInventory=(Clone $n.Inventory);Loaded=(Clone $r.Inventory);NativeBefore=(Clone $n.Inventory);SourceContainers=(Clone $n.Containers);
 TransientRefs=@(@{ItemUid='14';SavedHeldNetId='15';Before=$alias;After=(Clone $alias)},@{ItemUid='11';SavedHeldNetId='16';Before=$absent;After=(Clone $absent)});
 HeldItems=@(@{Uid='11';HeldNetId='24';HeldItemUid='11';OwnerNetId='19';ParentNetId='19'},@{Uid='14';HeldNetId='25';HeldItemUid='14';OwnerNetId='19';ParentNetId='19'})})
$r | Add-Member NoteProperty EquipmentSamples @(@{Time=1;Equipment=(Clone $r.Equipment)},@{Time=1.5;Equipment=(Clone $r.Equipment)},@{Time=2;Equipment=(Clone $r.Equipment)})
Assert-AvatarSurvivalResult $r
Assert-AvatarSurvivalRestart $n $r
foreach($mutate in @(
 {param($x)$x.RestoreAudit.PreLoadHeldZero=$false}, {param($x)$x.RestoreAudit.IncomingAbsent=$false},
 {param($x)$x.RestoreAudit.TransientRefs[0].After.OwnerNetId='19'}, {param($x)$x.RestoreAudit.ItemsAfter=13},
 {param($x)$x.RestoreAudit.HeldItems[1].HeldNetId='15'}, {param($x)$x.RestoreAudit.HeldItems[1].HeldNetId=$null},
 {param($x)$x.RestoreAudit.HeldStable=$false}, {param($x)$x.EquipmentSamples[2].Equipment.HeldNetId='99'},
 {param($x)$x.Inventory[1].Uid='11'}, {param($x)$x.Inventory[0].Condition=100},
 {param($x)$x.Inventory[0].Role='MAIN'}, {param($x)$x.StarterKit=@($kit)},
 {param($x)$x.Harvests=@($n.Harvests[0])}, {param($x)$x.Craft=$n.Craft},
 {param($x)$x.RestoreAudit.SourceUnchanged=$false},
 {param($x)$x.RestoreAudit.HeldItems[1].Uid='11';$x.RestoreAudit.HeldItems[1].HeldItemUid='11'},
 {param($x)$x.RestoreAudit.HeldItems[1].HeldNetId='26'},
 {param($x)$x.RestoreAudit.TransientRefs[1].SavedHeldNetId='15';$x.RestoreAudit.TransientRefs[1].Before.NetId='15';$x.RestoreAudit.TransientRefs[1].After.NetId='15'},
 {param($x)$x.Containers[2].Uid='99'}, {param($x)$x.RestoreAudit.SourceContainers[2].Capacity=0}
)){$x=Clone $r;Assert-AvatarSurvivalRestart $n $x;& $mutate $x;Denied {Assert-AvatarSurvivalRestart $n $x}}
$x=Clone $r;$x.Inventory[1].Slot=3;Denied {Assert-AvatarSurvivalRestart $n $x}
$x=Clone $r;$x.Equipment.IsHeld=$false;Denied {Assert-AvatarSurvivalResult $x}
$partial=Clone $r;$partial.Status='PARTIAL';$partial.State=$null;$partial.Inventory=@();$partial.Persistence.Restored=$false
Assert-AvatarSurvivalRestart $n $partial
$partial.Conservation | Add-Member NoteProperty EconomicFailure $true
Denied {Assert-AvatarSurvivalResult $partial}
Write-Output 'PASS FIXTURE 2: exact native inventory/state/held restart, no awards or UID substitution'
$p=@{RunId='run';Status='GREEN';Shutdown='GRACEFUL';OwnedProcessAbsent=$true;PortsReleased=$true;FirewallRemoved=$true;Cache=@{Key='key';Promoted=$true};WorldInventorySHA256='inv';ActorStateSHA256='actor'}
$proof=@{RunId='run';CacheKey='key';Generation='gen';SavSHA256='sav';SnapshotSHA256='inv';ActorStateSHA256='actor'}
Assert-AvatarSurvivalBinding $p $proof 'key' 'gen' 'WARM' 'sav' 'inv' 'actor'
$bad=Clone $proof;$bad.Generation='foreign';Denied {Assert-AvatarSurvivalBinding $p $bad 'key' 'gen' 'WARM' 'sav' 'inv' 'actor'}
$bad=Clone $proof;$bad.SnapshotSHA256='bad';Denied {Assert-AvatarSurvivalBinding $p $bad 'key' 'gen' 'WARM' 'sav' 'inv' 'actor'}
Write-Output 'PASS FIXTURE 3: stale world and corrupt snapshot blocked before restore'
