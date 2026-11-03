#Requires -Version 5.1
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'AvatarValidation.ps1')

# Synthetic validator inputs only. No fixture below proves native engine behavior.
function New-AvatarFixture {
    $default=[pscustomobject]@{Uid='201';Shortname='wood';Amount=3;Condition=0;MaxCondition=0;ContainerUid='10';OwnerNetId='100'}
    $rock=[pscustomobject]@{Uid='200';Shortname='rock';Amount=1;Condition=100;MaxCondition=100;ContainerUid='11';OwnerNetId='100'}
    $items=@($default,$rock)
    $equip=[pscustomobject]@{ActorNetId='100';RequestedUid='200';ActiveUid='200';ItemUid='200';ContainerUid='11';OwnerNetId='100';
        HeldNetId='600';HeldType='BaseMelee';HeldPrefab='assets/prefabs/weapons/rock/rock.entity.prefab';HeldOwnerNetId='100';HeldParentNetId='100';IsHeld=$true}
    $samples=@(0..64 | ForEach-Object {
        [pscustomobject]@{ActorNetId='100';Time=$_*0.5;Position=@($_,5,0);ActiveUid='200';HeldNetId='600';HeldOwnerNetId='100';
            PathStatus='PathComplete';HasPath=$true;Remaining=$(if($_ -le 32){32-$_}else{64-$_})}
    })
    $foreign=[pscustomobject]@{Uid='701';Shortname='scrap';Amount=1;Condition=0;MaxCondition=0;ContainerUid='900';OwnerNetId=$null}|ConvertTo-Json -Compress
    $negative=@(foreach($kind in @('MISSING','FOREIGN')) {
        [pscustomobject]@{Kind=$kind;RequestedUid=$(if($kind -eq 'MISSING'){'700'}else{'701'});FoundInBelt=$false;Accepted=$false;
            Mechanism='GUARD_BEFORE_NATIVE_UPDATE_UID';Lookup='NATIVE_BELT_UID';NativeApiCalled=$false;LookupItemUid=$null;
            MissingUidAbsentGlobally=($kind -eq 'MISSING');
            BeforeActiveUid='200';AfterActiveUid='200';Before=$items;After=$items;ForeignOwnerNetId=$(if($kind -eq 'FOREIGN'){'container:900'}else{''});
            ForeignBefore=$(if($kind -eq 'FOREIGN'){$foreign}else{$null});ForeignAfter=$(if($kind -eq 'FOREIGN'){$foreign}else{$null})}
    })
    [pscustomobject]@{Status='GREEN';Persistence='NOT_VERIFIED';Backend='RustNavMeshAgent/RustNav';ManualPositionWrites=0;SpawnCount=1;
        Parts=[pscustomobject]@{AVATAR='GREEN';NAV='GREEN';PLAYER_INVENTORY='GREEN';HELD_ITEM='GREEN';NEGATIVE='GREEN'};
        Actor=[pscustomobject]@{NetId='100';Type='ScientistNPC';IsBasePlayer=$true;IsNpc=$true;HasConnection=$false;NativeBotId=$true;
            Prefab='assets/rust.ai/agents/npcplayer/humannpc/scientist/scientistnpc_full_any.prefab';Agent='Rust.Ai.Gen2.RustNavMeshAgent'};
        Inventory=[pscustomobject]@{ActorNetId='100';Component='PlayerInventory';Main=[pscustomobject]@{Uid='10';OwnerNetId='100'};
            Belt=[pscustomobject]@{Uid='11';OwnerNetId='100'};Wear=[pscustomobject]@{Uid='12';OwnerNetId='100'};Before=@($default);After=$items};
        Fixture=[pscustomobject]@{Kind='TEST_FIXTURE';Created=1;Item=$rock};Equipment=$equip;
        EquipmentFinal=($equip | ConvertTo-Json | ConvertFrom-Json);Negative=$negative;Samples=$samples;
        Legs=@([pscustomobject]@{ActorNetId='100';Leg=1;Status='ARRIVED';PlannedPathStatus='PathComplete';PlannedPathLength=32;IssuedPathStatus='PathComplete';StoppingDistance=1;PathStatus='PathComplete';ArrivalHasPath=$true;ArrivalRemaining=0;Start=@(0,5,0);Target=@(32,5,0);End=@(32,5,0);StartTime=0;EndTime=16;Traveled=32;Net=32;Stuck=0;Repath=0},
            [pscustomobject]@{ActorNetId='100';Leg=2;Status='ARRIVED';PlannedPathStatus='PathComplete';PlannedPathLength=32;IssuedPathStatus='PathComplete';StoppingDistance=1;PathStatus='PathComplete';ArrivalHasPath=$true;ArrivalRemaining=0;Start=@(32,5,0);Target=@(64,5,0);End=@(64,5,0);StartTime=16;EndTime=32;Traveled=32;Net=32;Stuck=0;Repath=0});
        CompletedLegs=2;TotalTraveled=64}
}
function New-AvatarConsumedFixture {
    $n=New-AvatarFixture
    $n.Samples[-1].PathStatus='PathInvalid';$n.Samples[-1].HasPath=$false
    $n.Legs[-1].PathStatus='PathInvalid';$n.Legs[-1].ArrivalHasPath=$false
    $n
}
function Must-RejectAvatar([string]$case,[scriptblock]$action) {
    $rejected=$false
    try { & $action } catch { $rejected=$true }
    if(-not $rejected){throw ('Invalid avatar receipt accepted: '+$case)}
}
function Test-AvatarMutation([string]$case,[scriptblock]$mutate,[switch]$Consumed) {
    $n=if($Consumed){New-AvatarConsumedFixture}else{New-AvatarFixture}
    & $mutate $n
    Must-RejectAvatar $case {Assert-AvatarResult $n}
}

# Removing ownership/conservation/native held checks must fail this group.
Assert-AvatarResult (New-AvatarFixture)
$ownership=@(
    @('Gen2 actor',{param($n)$n.Actor.Type='Rust.Ai.Gen2.ScientistNPC2';$n.Actor.IsBasePlayer=$false}),
    @('false player type',{param($n)$n.Actor.IsBasePlayer=$false}),
    @('real connection',{param($n)$n.Actor.HasConnection=$true}),
    @('fake bot identity',{param($n)$n.Actor.NativeBotId=$false}),
    @('multiple actors',{param($n)$n.SpawnCount=2}),
    @('zero actor ID',{param($n)$n.Actor.NetId='0'}),
    @('arbitrary container',{param($n)$n.Inventory.Component='ItemContainer'}),
    @('foreign inventory actor',{param($n)$n.Inventory.ActorNetId='999'}),
    @('foreign belt owner',{param($n)$n.Inventory.Belt.OwnerNetId='999'}),
    @('shared native containers',{param($n)$n.Inventory.Main.Uid='11'}),
    @('fake UID',{param($n)$n.Fixture.Item.Uid='invented'}),
    @('zero UID',{param($n)$n.Fixture.Item.Uid='0'}),
    @('duplicate fixture',{param($n)$n.Fixture.Created=2}),
    @('duplicate inventory UID',{param($n)$n.Inventory.After=@($n.Inventory.After)+@($n.Inventory.After[-1])}),
    @('fixture missing',{param($n)$n.Inventory.After=@($n.Inventory.After[0])}),
    @('default removed',{param($n)$n.Inventory.After=@($n.Inventory.After[-1])}),
    @('default changed',{param($n)$n.Inventory.After[0]=$n.Inventory.After[0]|ConvertTo-Json|ConvertFrom-Json;$n.Inventory.After[0].Amount=9}),
    @('unexplained award',{param($n)$n.Inventory.After+=([pscustomobject]@{Uid='202';Shortname='stones';Amount=1;Condition=0;MaxCondition=0;ContainerUid='10';OwnerNetId='100'})}),
    @('fixture foreign owner',{param($n)$n.Fixture.Item.OwnerNetId='999'}),
    @('fixture outside belt',{param($n)$n.Fixture.Item.ContainerUid='10'}),
    @('not marked fixture',{param($n)$n.Fixture.Kind='EARNED'}),
    @('unrelated active UID',{param($n)$n.Equipment.ActiveUid='201'}),
    @('absent held entity',{param($n)$n.Equipment.HeldNetId='0'}),
    @('held prefab missing',{param($n)$n.Equipment.HeldPrefab=''}),
    @('held type missing',{param($n)$n.Equipment.HeldType=''}),
    @('missing GetHeldEntity',{param($n)$n.Equipment=$null}),
    @('foreign held owner',{param($n)$n.Equipment.HeldOwnerNetId='999'}),
    @('foreign held parent',{param($n)$n.Equipment.HeldParentNetId='999'}),
    @('held state false',{param($n)$n.Equipment.IsHeld=$false}),
    @('final held disappeared',{param($n)$n.EquipmentFinal=$null}),
    @('final held changed',{param($n)$n.EquipmentFinal.HeldNetId='601'})
)
foreach($case in $ownership){Test-AvatarMutation $case[0] $case[1]}
Write-Output 'PASS FIXTURE 1: same actor, PlayerInventory conservation and native held receipt contract'

# Removing negative guards or trusting declared travel must fail this group.
$movement=@(
    @('old NULL_ITEM_GUARD receipt',{param($n)$n.Negative[0].Mechanism='NULL_ITEM_GUARD';$n.Negative[0].PSObject.Properties.Remove('Lookup');$n.Negative[0].PSObject.Properties.Remove('LookupItemUid');$n.Negative[0].PSObject.Properties.Remove('MissingUidAbsentGlobally')}),
    @('old native update guard receipt',{param($n)$n.Negative[0].Mechanism='GUARD_BEFORE_NATIVE_UPDATE'}),
    @('missing guard mechanism',{param($n)$n.Negative[1].PSObject.Properties.Remove('Mechanism')}),
    @('lookup is not native belt UID',{param($n)$n.Negative[0].Lookup='ITEM_REFERENCE'}),
    @('native API called on negative UID',{param($n)$n.Negative[1].NativeApiCalled=$true}),
    @('native API call state absent',{param($n)$n.Negative[0].PSObject.Properties.Remove('NativeApiCalled')}),
    @('lookup returned item',{param($n)$n.Negative[0].LookupItemUid='200'}),
    @('lookup item receipt absent',{param($n)$n.Negative[1].PSObject.Properties.Remove('LookupItemUid')}),
    @('missing UID exists globally',{param($n)$n.Negative[0].MissingUidAbsentGlobally=$false}),
    @('missing UID global check absent',{param($n)$n.Negative[0].PSObject.Properties.Remove('MissingUidAbsentGlobally')}),
    @('negative accepted',{param($n)$n.Negative[0].Accepted=$true}),
    @('negative found in belt',{param($n)$n.Negative[0].FoundInBelt=$true}),
    @('foreign UID is fixture',{param($n)$n.Negative[1].RequestedUid='200'}),
    @('foreign owner is actor',{param($n)$n.Negative[1].ForeignOwnerNetId='100'}),
    @('foreign snapshot missing',{param($n)$n.Negative[1].ForeignBefore=$null;$n.Negative[1].ForeignAfter=$null}),
    @('foreign snapshot changed',{param($n)$n.Negative[1].ForeignAfter=$n.Negative[1].ForeignAfter.Replace('scrap','wood')}),
    @('foreign snapshot wrong UID',{param($n)$n.Negative[1].ForeignBefore=$n.Negative[1].ForeignBefore.Replace('701','702');$n.Negative[1].ForeignAfter=$n.Negative[1].ForeignBefore}),
    @('foreign snapshot wrong container',{param($n)$n.Negative[1].ForeignOwnerNetId='container:901'}),
    @('negative changes active item',{param($n)$n.Negative[0].AfterActiveUid='0'}),
    @('negative creates item',{param($n)$n.Negative[0].After=@($n.Inventory.After[0])}),
    @('missing negative class',{param($n)$n.Negative=@($n.Negative[0])}),
    @('zero travel',{param($n)foreach($s in $n.Samples){$s.Position=@(0,5,0)};$n.TotalTraveled=0}),
    @('manual warp',{param($n)$n.ManualPositionWrites=1}),
    @('sample warp',{param($n)$n.Samples[20].Position=@(600,5,0)}),
    @('wrong sample actor',{param($n)$n.Samples[20].ActorNetId='999'}),
    @('sample active changed',{param($n)$n.Samples[20].ActiveUid='201'}),
    @('sample held changed',{param($n)$n.Samples[20].HeldNetId='601'}),
    @('sample owner changed',{param($n)$n.Samples[20].HeldOwnerNetId='999'}),
    @('missing samples',{param($n)$n.Samples=@()}),
    @('sample time gap',{param($n)$n.Samples[20].Time=20}),
    @('nonfinite position',{param($n)$n.Samples[20].Position=@([double]::NaN,5,0)}),
    @('nonfinite total',{param($n)$n.TotalTraveled=[double]::NaN}),
    @('false total',{param($n)$n.TotalTraveled=600}),
    @('one complete leg',{param($n)$n.Legs=@($n.Legs[0]);$n.CompletedLegs=1}),
    @('false count',{param($n)$n.CompletedLegs=3}),
    @('partial path',{param($n)$n.Legs[0].PathStatus='PathPartial'}),
    @('wrong leg actor',{param($n)$n.Legs[1].ActorNetId='999'}),
    @('false arrival',{param($n)$n.Legs[0].Target=@(100,5,0)}),
    @('broken leg chain',{param($n)$n.Legs[1].Start=@(20,5,0)}),
    @('false leg distance',{param($n)$n.Legs[0].Traveled=60}),
    @('false leg net',{param($n)$n.Legs[0].Net=20}),
    @('false leg time',{param($n)$n.Legs[0].EndTime=15.5}),
    @('unbounded stuck',{param($n)$n.Legs[0].Stuck=2}),
    @('unbounded repath',{param($n)$n.Legs[0].Repath=2}),
    @('leg timeout exceeded',{param($n)
        foreach($s in $n.Samples){$s.Time*=3}
        $n.Legs[0].End=@(48,5,0);$n.Legs[0].Target=@(48,5,0);$n.Legs[0].EndTime=72;$n.Legs[0].Traveled=48;$n.Legs[0].Net=48
        $n.Legs[1].Start=@(48,5,0);$n.Legs[1].StartTime=72;$n.Legs[1].EndTime=96;$n.Legs[1].Traveled=16;$n.Legs[1].Net=16}),
    @('NAV missing agent',{param($n)$n.Actor.Agent=$null}),
    @('wrong navigation backend',{param($n)$n.Backend='UnityNavMesh'})
)
foreach($case in $movement){Test-AvatarMutation $case[0] $case[1]}
# Native RustNav clears a completed path at its endpoint; preserve the raw status.
Assert-AvatarResult (New-AvatarConsumedFixture)
$n=New-AvatarConsumedFixture
$n.Samples[32].PathStatus='PathInvalid';$n.Samples[32].HasPath=$false
$n.Legs[0].PathStatus='PathInvalid';$n.Legs[0].ArrivalHasPath=$false
Assert-AvatarResult $n
$consumed=@(
    @('consumed path far from target',{param($n)$n.Legs[-1].Target=@(100,5,0)}),
    @('consumed outside native stopping distance',{param($n)$n.Legs[-1].Target=@(65.1,5,0)}),
    @('invalid path before arrival',{param($n)$n.Samples[50].PathStatus='PathInvalid';$n.Samples[50].HasPath=$false;$n.Samples[50].Remaining=0}),
    @('partial path before arrival',{param($n)$n.Samples[50].PathStatus='PathPartial'}),
    @('complete sample without path',{param($n)$n.Samples[50].HasPath=$false}),
    @('missing planned path',{param($n)$n.Legs[-1].PSObject.Properties.Remove('PlannedPathStatus')}),
    @('missing issued path',{param($n)$n.Legs[-1].PSObject.Properties.Remove('IssuedPathStatus')}),
    @('partial planned path',{param($n)$n.Legs[-1].PlannedPathStatus='PathPartial'}),
    @('partial issued path',{param($n)$n.Legs[-1].IssuedPathStatus='PathPartial'}),
    @('planned path too short',{param($n)$n.Legs[-1].PlannedPathLength=27}),
    @('planned path length missing',{param($n)$n.Legs[-1].PSObject.Properties.Remove('PlannedPathLength')}),
    @('planned path length nonfinite',{param($n)$n.Legs[-1].PlannedPathLength=[double]::NaN}),
    @('native stopping distance missing',{param($n)$n.Legs[-1].PSObject.Properties.Remove('StoppingDistance')}),
    @('native stopping distance changed',{param($n)$n.Legs[-1].StoppingDistance=2}),
    @('native stopping distance is boolean',{param($n)$n.Legs[-1].StoppingDistance=$true}),
    @('consumed path after stuck',{param($n)$n.Legs[-1].Stuck=1}),
    @('consumed path after repath',{param($n)$n.Legs[-1].Repath=1}),
    @('consumed arrival still has path',{param($n)$n.Legs[-1].ArrivalHasPath=$true;$n.Samples[-1].HasPath=$true}),
    @('consumed arrival remaining distance',{param($n)$n.Legs[-1].ArrivalRemaining=1;$n.Samples[-1].Remaining=1}),
    @('arrival status disagrees with sample',{param($n)$n.Samples[-1].PathStatus='PathComplete';$n.Samples[-1].HasPath=$true}),
    @('arrival remaining disagrees with sample',{param($n)$n.Legs[-1].ArrivalRemaining=0.5}),
    @('arrival remaining small mismatch',{param($n)$n.Legs[-1].ArrivalRemaining=0.0005}),
    @('missing sample path state',{param($n)$n.Samples[50].PSObject.Properties.Remove('HasPath')}),
    @('missing arrival remaining',{param($n)$n.Legs[-1].PSObject.Properties.Remove('ArrivalRemaining')}),
    @('nonfinite native remaining',{param($n)$n.Samples[50].Remaining=[double]::NaN}),
    @('initial path not complete',{param($n)$n.Samples[0].PathStatus='PathInvalid';$n.Samples[0].HasPath=$false;$n.Samples[0].Remaining=0}),
    @('no real intermediate sample',{param($n)
        $n.Legs[0].End=@(1,5,0);$n.Legs[0].Target=@(1,5,0);$n.Legs[0].EndTime=0.5;$n.Legs[0].Traveled=1;$n.Legs[0].Net=1;$n.Legs[0].ArrivalRemaining=31
        $n.Legs[1].Start=@(1,5,0);$n.Legs[1].StartTime=0.5;$n.Legs[1].Traveled=63;$n.Legs[1].Net=63})
)
foreach($case in $consumed){Test-AvatarMutation $case[0] $case[1] -Consumed}
$source=Get-Content (Join-Path $PSScriptRoot '..\src\plugins\RustBotsAvatarProbe.cs') -Raw
if($source -match '\b(?:transform\s*\.\s*(?:position|localPosition)|(?:npc|actor)\s*\.\s*(?:Position|ServerPosition))\s*(?:[+\-*/]=|=(?!=))|\.\s*(?:MovePosition|Warp|Teleport|SetPosition|SetPositionAndRotation)\s*\(') {
    throw 'Avatar probe must navigate without direct position writes or warp APIs'
}
Write-Output 'PASS FIXTURE 2: missing/foreign activation guards and continuous same-actor RustNav movement'

# A failed gate cannot be promoted; partial gates only validate their GREEN claims.
$n=New-AvatarFixture;$n.Status='PARTIAL';$n.Parts.NAV='PARTIAL';$n.Samples=@();$n.Legs=@();$n.EquipmentFinal=$null
$n.Actor.Agent=$null
Assert-AvatarResult $n
$n.Inventory.Belt.OwnerNetId='999'
Must-RejectAvatar 'partial still claims native inventory GREEN' {Assert-AvatarResult $n}
Assert-AvatarResult ([pscustomobject]@{Status='BLOCKED';Persistence='NOT_VERIFIED'})
Test-AvatarMutation 'missing GREEN part' {param($n)$n.Parts.HELD_ITEM='NOT_VERIFIED'}
Test-AvatarMutation 'invented persistence proof' {param($n)$n.Persistence='GREEN'}
$safe=[pscustomobject]@{Status='GREEN';Shutdown='GRACEFUL';OwnedProcessAbsent=$true;PortsReleased=$true;FirewallRemoved=$true;ServerPid=1234;ServerExitCode=-1;AvatarCompletedSave=$true}
Assert-AvatarSafety $safe
foreach($field in @('Shutdown','OwnedProcessAbsent','PortsReleased','FirewallRemoved','ServerPid','ServerExitCode','AvatarCompletedSave')) {
    $bad=$safe|ConvertTo-Json|ConvertFrom-Json
    switch($field){Shutdown {$bad.Shutdown='FORCED_OWNED_JOB'} ServerPid {$bad.ServerPid=0} ServerExitCode {$bad.ServerExitCode=7} default {$bad.$field=$false}}
    Must-RejectAvatar ('failed shutdown '+$field) {Assert-AvatarSafety $bad}
}
$bad=$safe|ConvertTo-Json|ConvertFrom-Json;$bad.PSObject.Properties.Remove('AvatarCompletedSave')
Must-RejectAvatar 'missing completed-save evidence' {Assert-AvatarSafety $bad}
Assert-AvatarSafety ([pscustomobject]@{Status='BLOCKED'})
Write-Output 'PASS FIXTURE 3: honest partial/blocked status and fail-closed shutdown safety'
