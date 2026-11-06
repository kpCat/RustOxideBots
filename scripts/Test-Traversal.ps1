#Requires -Version 5.1
param([switch]$ReadinessOnly,[switch]$RecoveryOnly)
$ErrorActionPreference='Stop'
# OFFLINE_ONLY: synthetic receipts exercise validation, never Unity/PhysX or live movement.
$validator=Join-Path $PSScriptRoot 'TraversalValidation.ps1'
if(-not (Test-Path -LiteralPath $validator)){throw 'Traversal safety contracts are not implemented'}
. $validator
foreach($name in @('Assert-TraversalFrames','Assert-TraversalResult')){
    if(-not (Get-Command $name -CommandType Function -ErrorAction SilentlyContinue)){throw ('Missing traversal contract '+$name)}
}
function Copy-TraversalFixture($value){$value|ConvertTo-Json -Depth 60|ConvertFrom-Json}
function Deny-TraversalFixture([scriptblock]$action,[string]$name){
    $denied=$false;try{& $action}catch{$denied=$true}
    if(-not $denied){throw ('Unsafe traversal receipt accepted: '+$name)}
}
Deny-TraversalFixture {Assert-TraversalFrames @() '19' 'synthetic-world'} 'missing frames'
function New-TraversalFrame([string]$event,[int]$command,[double]$time,$from,$actual,[double]$speed){
    $collider=@{Instance=40;Type='UnityEngine.TerrainCollider';Entity='';Prefab='';Enabled=$true;Trigger=$false;Layer=23;BoundsCenter=@(0,-1,0);BoundsSize=@(100,2,100)}
    $a=@($actual[0],($actual[1]+0.5),$actual[2]);$b=@($actual[0],($actual[1]+1.3),$actual[2])
    $origin=@($actual[0],($actual[1]+0.77),$actual[2]);$center=@($actual[0],($actual[1]+0.5),$actual[2]);$point=@($actual[0],$actual[1],$actual[2])
    $d=Get-WorldDistance $from $actual
    $f=@{Schema=1;Event=$event;Actor='19';World='synthetic-world';Stage='OUTDOOR';Time=$time;Tick=[int]($time*20);Command=$command;Classification='SMALL_STEP_UP';Reason='SYNTHETIC_ONLY';
        Body=@{Instance=10;Actor='19';RigidbodyInstance=11;Radius=0.5;Height=1.8;Center=@(0,0.9,0);Direction=1;Scale=@(1,1,1);Enabled=$true;Trigger=$false;A=$a;B=$b;WorldRadius=0.5;Position=$actual;Rotation=@(0,0,0,1);Kinematic=$true;Gravity=$false;DetectCollisions=$true;Layer=17;CollisionMode='Discrete';RigidbodyPosition=$actual;AgentStopped=$true;AgentUpdatePosition=$false;AgentUpdateRotation=$false};
        Profile=@{MaxStep=0.2;MaxDrop=0.2;MaxSlope=45;MaxSpeed=1.2;MaxAcceleration=4;MaxTick=0.1;Skin=0.02;SupportTolerance=0.07;NavClimb=0.4;NavSlope=45;NativeStepCeiling=0.2};
        Support=@{Found=$true;Kind='SURFACE';Collider=$collider;Origin=$origin;Radius=0.5;Length=0.54;Point=$point;Normal=@(0,1,0);Distance=0.27;Center=$center;FootY=$actual[1];Gap=0;PlaneClearance=0;Hits=@(@{Collider=$collider;Point=$point;Normal=@(0,1,0);Distance=0.27})};
        From=$from;Requested=$actual;Actual=$actual;PreviousTime=($time-0.05);Dt=0.05;Distance=$d;Speed=$speed;Acceleration=0;Sweeps=@();Overlaps=@();NativeResult='OBSERVED';Actuator='Rigidbody.MovePosition';Mask=-1;Triggers='Ignore';
        Navigation=@{OnNavMesh=$true;PendingTiles=$false;RouteStatus='PathComplete';RouteFrom=$from;RouteTo=$actual;Corners=@($from,$actual);PlannedTileChangeVersion=1;PlannedTileDataVersion=1;TileChangeVersion=1;TileDataVersion=1;PlannedMesh='synthetic-native-mesh';Mesh='synthetic-native-mesh'};Casts=4;QueryMilliseconds=0.1;MotionMode='SUPPORTED_ADVANCE'}
    if($event -eq 'MOVE_DECISION'){$f.Requested=$actual;$f.Actual=$from;$f.Body.Position=$from;$f.Body.RigidbodyPosition=$from;$f.Body.A=@($from[0],($from[1]+0.5),$from[2]);$f.Body.B=@($from[0],($from[1]+1.3),$from[2]);$f.Distance=0;$f.NativeResult='PRECHECKED'}
    $f.Landing=Copy-TraversalFixture $f.Support;$f.LandingOverlaps=@()
    $f.Sweeps=@(@{From=$from;To=$actual;A=@($from[0],($from[1]+0.5),$from[2]);B=@($from[0],($from[1]+1.3),$from[2]);Radius=0.5;Distance=$d;Hits=@();Mask=-1;Triggers='Ignore'})
    Copy-TraversalFixture $f
}
function New-TraversalFrames {
    $p0=@(0,0,0);$p1=@(0.009,0.002,0);$p2=@(0.027,0.006,0)
    $d1=New-TraversalFrame 'MOVE_DECISION' 1 1 $p0 $p1 0
    $d2=New-TraversalFrame 'MOVE_DECISION' 2 1.05 $p1 $p2 ([Math]::Sqrt(0.000085)/0.05)
    # Decision support is measured at the current pose, not the future request.
    foreach($pair in @(@($d1,$p0),@($d2,$p1))){$f=$pair[0];$p=$pair[1];$f.Support.Origin=@($p[0],($p[1]+0.77),$p[2]);$f.Support.Center=@($p[0],($p[1]+0.5),$p[2]);$f.Support.Point=$p;$f.Support.FootY=$p[1];$f.Support.Hits[0].Point=$p}
    $w1=New-TraversalFrame 'MOTION_WITNESS' 1 1.05 $p0 $p1 ([Math]::Sqrt(0.000085)/0.05)
    $w2=New-TraversalFrame 'MOTION_WITNESS' 2 1.1 $p1 $p2 ([Math]::Sqrt(0.000340)/0.05)
    $w1.Acceleration=$w1.Speed/0.05;$w2.Acceleration=($w2.Speed-$w1.Speed)/0.05
    @($d1,$w1,$d2,$w2)
}
# OFFLINE_ONLY020: receipt contracts, never a PhysX movement claim.
if(-not (Get-Command Assert-TraversalRecovery -CommandType Function -ErrorAction SilentlyContinue)){
    throw 'Missing measured moving recovery contract (moving REPATH must not invent rest)'
}
function New-RecoveryProjection($from,$to,$prior,[double]$dt,[string]$kind='DECELERATION'){
    $f=New-TraversalFrame 'MOVE_DECISION' 10 1 $from $to 0
    $current=New-TraversalFrame 'MOTION_WITNESS' 9 1 $from $from 0
    $f.Support=$current.Support
    $f.Classification='CLEAR';$f.MotionMode='ACTUAL_BRAKE';$f.Dt=$dt
    $f|Add-Member NoteProperty Kind $kind
    $f|Add-Member NoteProperty PriorVelocity $prior
    $f|Add-Member NoteProperty Velocity (Get-TraversalPhysicsVelocity $to $from $dt)
    $f|Add-Member NoteProperty Permission $true;$f|Add-Member NoteProperty WaterDepth (-1)
    $f|Add-Member NoteProperty SupportAccepted $true;$f|Add-Member NoteProperty OverlapClear $true
    $f|Add-Member NoteProperty LandingPermission $true;$f|Add-Member NoteProperty LandingWaterDepth (-1)
    $f|Add-Member NoteProperty LandingSupportAccepted $true
    foreach($s in @($f.Support,$f.Landing)){
        $s.Collider|Add-Member NoteProperty MovingEntity $false -Force
        $s.Collider|Add-Member NoteProperty RigidbodyInstance $null -Force
    }
    $f
}
function New-RecoveryFrames {
    $dt=0.0625;$position=@(0,0,0);$velocity=@(0.6,0,0);$sequence=100;$rows=@()
    $meta=Copy-TraversalFixture @{Kind='MEASURED_BRAKE_V1';Session=1;Attempt=1;StartSequence=100;StartWall=1;StartPosition=$position;StartVelocity=$velocity;
        Step=0;MaxSteps=8;MaxSeconds=1;Deceleration=3;Floor=40;FloorCenter=@(0,-1,0);FloorSize=@(100,2,100);Corridor=@();RequiredDistance=0}
    $prior=New-TraversalFrame 'MOTION_WITNESS' 9 1 @(-0.0375,0,0) $position 0.6
    $prior.Dt=$dt;$prior|Add-Member NoteProperty Clock @{Sequence=100;WallTime=1;FixedTime=1;Delta=$dt}
    $prior.Body|Add-Member NoteProperty Velocity $velocity
    $prior.Support.Collider|Add-Member NoteProperty MovingEntity $false
    $prior.Support.Collider|Add-Member NoteProperty RigidbodyInstance $null
    $meta|Add-Member NoteProperty FloorCollider (Copy-TraversalFixture $prior.Support.Collider)
    $rows+=,$prior
    $request=Copy-TraversalFixture $prior;$request.Event='BRAKE_REQUESTED'
    $request|Add-Member NoteProperty Recovery $meta;$rows+=,$request
    for($step=1;$step -le 4;$step++){
        $command=9+$step;$meta=Copy-TraversalFixture $meta;$meta.Step=$step
        $speed=Get-WorldDistance $velocity @(0,0,0);$cursor=$position;$v=$velocity;$corridor=@()
        for($j=0;$j -lt 8;$j++){
            $nextSpeed=[Math]::Max(0.0,(Get-WorldDistance $v @(0,0,0))-3*$dt)
            $to=@([single]([single]$cursor[0]+[single]($nextSpeed*$dt)),0,0)
            $segment=New-RecoveryProjection $cursor $to $v $dt
            $corridor+=,$segment;$cursor=$to;$v=$segment.Velocity
            if((Get-WorldDistance $v @(0,0,0)) -eq 0){break}
        }
        $meta.RequiredDistance=$speed*$speed/6+$speed*$dt+0.02
        $length=0.0;foreach($part in $corridor){$length+=Get-WorldDistance $part.From $part.Requested}
        $reserve=@([single]($cursor[0]+[Math]::Max(0.0,$meta.RequiredDistance-$length)+0.001),0,0)
        $corridor+=,(New-RecoveryProjection $cursor $reserve @(0,0,0) $dt 'RESERVE')
        $meta.Corridor=$corridor
        $decision=Copy-TraversalFixture $corridor[0];$decision.Command=$command;$decision.Time=1+($step-1)*$dt
        $decision|Add-Member NoteProperty Clock @{Sequence=$sequence;WallTime=$decision.Time;FixedTime=$decision.Time;Delta=$dt}
        $decision|Add-Member NoteProperty Recovery $meta
        $decision.Body|Add-Member NoteProperty Velocity $velocity
        $decision.MotionMode=if((Get-WorldDistance $decision.Velocity @(0,0,0)) -eq 0){'BRAKE_HOLD'}else{'ACTUAL_BRAKE'}
        $rows+=,$decision
        $issued=Copy-TraversalFixture $decision;$issued.Event='MOVE_ISSUED';$issued.NativeResult='ISSUED';$rows+=,$issued
        $brakeIssued=Copy-TraversalFixture $issued;$brakeIssued.Event='BRAKE_ISSUED';$rows+=,$brakeIssued
        $witness=New-TraversalFrame 'MOTION_WITNESS' $command ($decision.Time+$dt) $position $decision.Requested 0
        $witness.Classification='CLEAR';$witness.Dt=$dt;$witness.MotionMode=$decision.MotionMode
        $witness.Support.Collider|Add-Member NoteProperty MovingEntity $false
        $witness.Support.Collider|Add-Member NoteProperty RigidbodyInstance $null
        $witness|Add-Member NoteProperty Clock @{Sequence=($sequence+1);WallTime=$witness.Time;FixedTime=$witness.Time;Delta=$dt}
        $witness|Add-Member NoteProperty Recovery $meta
        $velocity=Get-TraversalPhysicsVelocity $witness.Actual $witness.From $dt
        $witness.Speed=Get-WorldDistance $velocity @(0,0,0);$witness.Body|Add-Member NoteProperty Velocity $velocity
        $witness|Add-Member NoteProperty ObservedVelocity $velocity
        $rows+=,$witness
        $observed=Copy-TraversalFixture $witness;$observed.Event='BRAKE_WITNESSED';$rows+=,$observed
        $position=$witness.Actual;$sequence++
    }
    $rest=Copy-TraversalFixture $rows[-1];$rest.Event='ACTUAL_REST';$rows+=,$rest
    $repath=Copy-TraversalFixture $rest;$repath.Event='REPATH_AFTER_REST';$rows+=,$repath
    foreach($row in $rows){$row|Add-Member NoteProperty MotionSession 1}
    $rows
}
$recovery=New-RecoveryFrames
Assert-TraversalRecovery $recovery
Deny-TraversalFixture {Assert-TraversalRecovery @($recovery|Where-Object Event -notin @('BRAKE_REQUESTED','BRAKE_ISSUED','BRAKE_WITNESSED','ACTUAL_REST','REPATH_AFTER_REST'))} 'omitted braking lifecycle cannot bypass contract'
$secondRecovery=Copy-TraversalFixture $recovery
foreach($f in $secondRecovery){$f.MotionSession=2;if($null -ne $f.Recovery){$f.Recovery.Session=2}}
Assert-TraversalRecovery @($recovery+$secondRecovery)
Deny-TraversalFixture {Assert-TraversalRecovery @($recovery+$recovery)} 'same destination replays recovery budget'
$clockBoundRecovery=Copy-TraversalFixture $recovery
foreach($f in $clockBoundRecovery){$f.Schema=2;$f|Add-Member NoteProperty RecoveryPolicy 'MEASURED_BRAKE_V1'}
$sessionBaseline=Copy-TraversalFixture $clockBoundRecovery[0];$sessionBaseline.Event='CLOCK_BASELINE';$sessionBaseline.Speed=0
Assert-TraversalRecovery @(@($sessionBaseline)+$clockBoundRecovery)
Deny-TraversalFixture {Assert-TraversalRecovery $clockBoundRecovery} 'motion session lacks native baseline'
Deny-TraversalFixture {$x=Copy-TraversalFixture $clockBoundRecovery;$x[1].MotionSession=2;$x[1].Recovery.Session=2;Assert-TraversalRecovery @(@($sessionBaseline)+$x)} 'invented destination session while moving'
foreach($case in @(
    @{Name='moving REPATH without command/rest';Change={param($x)$x[1].Event='REPATH';$x[1].Recovery=$null}},
    @{Name='wall at one centimetre / short corridor';Change={param($x)$x[2].Recovery.Corridor=@($x[2].Recovery.Corridor[0])}},
    @{Name='unsupported braking landing';Change={param($x)$x[2].Recovery.Corridor[0].Landing.Found=$false}},
    @{Name='foreign TC braking permission';Change={param($x)$x[2].Recovery.Corridor[0].LandingPermission=$false}},
    @{Name='closed door / solid swept contact';Change={param($x)$x[2].Recovery.Corridor[0].Sweeps=@()}},
    @{Name='missed fixed tick';Change={param($x)$x[5].Clock.Sequence+=1}},
    @{Name='fake zero native velocity';Change={param($x)$x[-2].Body.Velocity=@(0.1,0,0)}},
    @{Name='late recovery completion cannot claim rest/replan';Change={param($x)$x[-2].Clock.WallTime=2.1}},
    @{Name='changed final braking floor';Change={param($x)$x[-4].Support.Collider.Instance=41}},
    @{Name='changed brake floor owner';Change={param($x)$x[2].Recovery.Corridor[0].Landing.Collider|Add-Member NoteProperty Owner 'foreign' -Force}},
    @{Name='sideways reserve is not braking distance';Change={param($x)$p=$x[2].Recovery.Corridor[-1];$x[2].Recovery.Corridor[-1]=New-RecoveryProjection $p.From @($p.Requested[0],0,1) @(0,0,0) 0.0625 'RESERVE'}},
    @{Name='actual endpoint mismatch';Change={param($x)$x[5].Actual=@(1,0,0)}},
    @{Name='unbounded brake';Change={param($x)$x[2].Recovery.MaxSteps=999}},
    @{Name='out of sequence brake';Change={param($x)$x[2].Recovery.Step=2}},
    @{Name='replayed second recovery';Change={param($x)$x[1].Recovery.Attempt=2}}
)){
    $x=Copy-TraversalFixture $recovery;& $case.Change $x
    Deny-TraversalFixture {Assert-TraversalRecovery $x} $case.Name
}
$noBrake=Copy-TraversalFixture @($recovery[0],$recovery[1],$recovery[1],$recovery[1])
$noBrake[2].Event='BLOCKED_UNSAFE_BRAKING';$noBrake[2].NativeResult='NOT_ISSUED'
$noBrake[3].Event='BLOCKED';$noBrake[3].Reason='NO_SAFE_BRAKING_TRAJECTORY:SOLID_WALL'
Assert-TraversalRecovery $noBrake
Write-Output 'PASS OFFLINE_ONLY020 recovery: bounded full-body braking/rest/replan, unsafe corridor STOP and no invented motion'
$recoverySource=[IO.File]::ReadAllText((Join-Path (Split-Path $PSScriptRoot -Parent) 'src/navigation/ObstacleTraversal.cs'))
foreach($token in @('BRAKE_REQUESTED','BRAKE_ISSUED','BRAKE_WITNESSED','ACTUAL_REST','REPATH_AFTER_REST','BLOCKED_UNSAFE_BRAKING','CLOCK_UNOBSERVED_ACTIVE_HOLD','CheckBrakeCorridor')){
    if(-not $recoverySource.Contains($token)){throw ('Missing actual controller recovery path: '+$token)}
}
if(-not $recoverySource.Contains('QueueMeasuredReplan') -or -not $recoverySource.Contains('DIAGNOSTIC_PLANNED_REPLAN')){throw 'Missing bounded diagnostic native recovery proof hook'}
if($recoverySource -match 'lastVelocity\s*=\s*Vector3.zero'){throw 'Controller fabricated zero velocity'}
$benchHotpath=[IO.File]::ReadAllText((Join-Path (Split-Path $PSScriptRoot -Parent) 'src/navigation/TraversalBench.cs'))
if(-not $benchHotpath.Contains('COMPACT_CONSOLE_FULL_PRIMARY_V1') -or $benchHotpath.Contains('Log("TRAVERSAL",row)')){throw 'Full primary evidence must not be repeatedly serialized to the physics console'}
foreach($phase in @('ProbeSinkSeconds','NativePhaseSeconds','NATIVE_ROUTE_CHECK_STALE')){if(-not $recoverySource.Contains($phase)){throw ('Missing disaggregated rejected native admission phase '+$phase)}}
# OFFLINE_ONLY: separate native proof never grants movement/rest/replan by itself.
function New-EpochBrakeFixture {
    $recovery=New-RecoveryFrames;$prior=Copy-TraversalFixture $recovery[0];$f=Copy-TraversalFixture $recovery[1]
    $clock=@{Schema=2;Sequence=100;Frame=100;WallTime=1.0;FixedTime=1.0;FixedUnscaledTime=1.0;Delta=0.0625;UnscaledDelta=0.0625;TimeScale=1;MaximumDelta=0.125;InFixedStep=$true;PhysicsMode='FixedUpdate'}
    $prior.Clock=Copy-TraversalFixture $clock;$f.Clock=Copy-TraversalFixture $clock;$prior.Schema=2;$f.Schema=2
    foreach($row in @($prior,$f)){$row.Profile|Add-Member NoteProperty NavRadius 0.5;$row.Profile|Add-Member NoteProperty NavHeight 1.8}
    $plan=@{Kind='DEFAULT_NATIVE_PATH_V1';Mesh='synthetic-native-mesh';From=@(-1,0,0);To=@(2,0,0);Filter=$true;ChangeBefore=11;ChangeAfter=11;DataBefore=5;DataAfter=5;NativeCalculated=$true;ActorCalculated=$true;
        NativeStatus='PathComplete';ActorStatus='PathComplete';Capacity=256;NativePolys=@('101','102');ActorPolys=@('101','102');NativeCorners=@(@(-1,0,0),@(2,0,0));ActorCorners=@(@(-1,0,0),@(2,0,0))}
    $prior.Navigation=Copy-TraversalFixture @{OnNavMesh=$true;PendingTiles=$true;DefaultBuilt=$true;RouteStatus='PathComplete';AdmissionPolicy='NATIVE_CURRENT_ROUTE_V1';RoutePlan=@($plan);RouteFrom=$plan.From;RouteTo=$plan.To;
        Corners=$plan.NativeCorners;RoutePolys=$plan.NativePolys;RouteFilter=$true;PlannedMesh=$plan.Mesh;Mesh=$plan.Mesh;PlannedTileChangeVersion=11;PlannedTileDataVersion=5;TileChangeVersion=12;TileDataVersion=6}
    $original=Copy-TraversalFixture $plan;$original.ChangeBefore=12;$original.ChangeAfter=12;$original.DataBefore=6;$original.DataAfter=6
    $current=Copy-TraversalFixture $original;$current.From=@(0,0,0);$current.NativePolys=@('102');$current.ActorPolys=@('102');$current.NativeCorners=@(@(0,0,0),@(2,0,0));$current.ActorCorners=$current.NativeCorners
    $parts=$recovery[2].Recovery.Corridor;$points=@(,@(0,0,0));foreach($part in $parts){$points+=,@($part.Requested)}
    $r=Copy-TraversalFixture @{Kind='SAME_COMMITTED_ROUTE_EPOCH_V1';Accepted=$true;Phase='SEALED_BRAKE_ONLY';Actor='19';World='synthetic-world';Session=1;Command=9;Attempt=1;MaxAttempts=1;Clock=$clock;
        StartedWall=1.001;NativeCompletedWall=1.003;CompletedWall=1.005;RouteStartedWall=0.5;Mesh=$plan.Mesh;OriginalObjectMatched=$true;CurrentObjectMatched=$true;OldChange=11;OldData=5;NewChange=12;NewData=6;Filter=$true;OriginalIndex=1;
        From=$plan.From;Goal=$plan.To;Actual=@(0,0,0);Velocity=@(0.6,0,0);NativeVelocity=$prior.Body.Velocity;Body=$prior.Body;CommittedPlan=@($plan);CommittedPolys=$plan.NativePolys;CommittedCorners=$plan.NativeCorners;
        OriginalQuery=$original;CurrentQuery=$current;CurrentSuffix=1;OldRefsBefore=@(@{Ref='101';Valid=$true},@{Ref='102';Valid=$true});OldRefsAfter=@(@{Ref='101';Valid=$true},@{Ref='102';Valid=$true});
        CurrentRefsBefore=@(@{Ref='102';Valid=$true});CurrentRefsAfter=@(@{Ref='102';Valid=$true});GlobalPendingBefore=$true;GlobalPendingAfterNative=$true;GlobalPendingAtSeal=$true;
        BuildBefore=@{Climb=0.4;Slope=45;Radius=0.5;Height=1.8};BuildAfter=@{Climb=0.4;Slope=45;Radius=0.5;Height=1.8};Anchor=$prior.Support;Floor=$prior.Support.Collider;FloorCenter=@(0,-1,0);FloorSize=@(100,2,100);
        Corridor=$parts;CorridorPoints=$points;RequiredDistance=$recovery[2].Recovery.RequiredDistance}
    $f.Event='NATIVE_ROUTE_EPOCH_REVALIDATED';$f.NativeResult='REVALIDATED';$f.Navigation=Copy-TraversalFixture $prior.Navigation
    $f.Navigation|Add-Member NoteProperty AdmissionTileChangeVersion 12;$f.Navigation|Add-Member NoteProperty AdmissionTileDataVersion 6;$f.Navigation|Add-Member NoteProperty EpochRevalidation $r
    $f|Add-Member NoteProperty EpochRevalidation $r;$f|Add-Member NoteProperty WriterCalled $false;$f|Add-Member NoteProperty UnobservedCommand $false
    $f|Add-Member NoteProperty Permission $true;$f|Add-Member NoteProperty WaterDepth (-1);$f|Add-Member NoteProperty SupportAccepted $true;$f|Add-Member NoteProperty OverlapClear $true
    [pscustomobject]@{Prior=$prior;Transition=$f;Recovery=$recovery}
}
$epochBrake=New-EpochBrakeFixture
Assert-TraversalEpochProof $epochBrake.Transition $epochBrake.Prior
foreach($case in @(
    @{Name='old committed plan retagged as new';Change={param($x)$x.Transition.Navigation.RoutePlan[0].ChangeAfter=12}},
    @{Name='changed real default object';Change={param($x)$x.Transition.EpochRevalidation.CurrentObjectMatched=$false}},
    @{Name='invalid old public polygon';Change={param($x)$x.Transition.EpochRevalidation.OldRefsAfter[0].Valid=$false}},
    @{Name='native profile changed';Change={param($x)$x.Transition.EpochRevalidation.BuildAfter.Radius=0.4}},
    @{Name='current suffix replaced';Change={param($x)$x.Transition.EpochRevalidation.CurrentSuffix=0}},
    @{Name='corridor endpoint rotated to fit new path';Change={param($x)$x.Transition.EpochRevalidation.CorridorPoints[1][2]=0.01}},
    @{Name='foreign braking permission';Change={param($x)$x.Transition.EpochRevalidation.Corridor[0].Permission=$false}},
    @{Name='original floor acquired rigidbody';Change={param($x)$x.Transition.EpochRevalidation.Floor.RigidbodyInstance=555}},
    @{Name='proof callback horizon refreshed';Change={param($x)$x.Transition.EpochRevalidation.CompletedWall=1.101}}
)){$x=Copy-TraversalFixture $epochBrake;& $case.Change $x;Deny-TraversalFixture {Assert-TraversalEpochProof $x.Transition $x.Prior} $case.Name}
$baseline=Copy-TraversalFixture $epochBrake.Prior;$baseline.Event='CLOCK_BASELINE';$baseline|Add-Member NoteProperty PosePreviousTime 0.5
$stopped=Copy-TraversalFixture $epochBrake.Transition;$stopped.Event='BLOCKED';$stopped.NativeResult='STOPPED'
Assert-TraversalEpochTransitions @($baseline,$epochBrake.Prior,$epochBrake.Transition,$stopped)
Deny-TraversalFixture {Assert-TraversalEpochTransitions @($baseline,$epochBrake.Prior,$epochBrake.Transition,$epochBrake.Transition)} 'epoch proof repeated within same motion session'
Assert-TraversalRecovery $epochBrake.Recovery
Write-Output 'PASS OFFLINE_ONLY020 epoch brake: immutable committed plan, fresh separate dual-query proof, original3D corridor, static floor, terminal no-writer prefix and actual-rest recovery'
# OFFLINE_ONLY: proof authorizes only the source's measured brake FSM or truthful terminal refusal.
function New-EpochLifecycleReplay {
    $x=New-EpochBrakeFixture;$base=Copy-TraversalFixture $x.Prior;$base.Event='CLOCK_BASELINE';$base|Add-Member NoteProperty PosePreviousTime 0.5
    $rows=@($base,$x.Prior,$x.Transition)
    for($i=1;$i -lt $x.Recovery.Count;$i++){
        $f=Copy-TraversalFixture $x.Recovery[$i];$f.Navigation=Copy-TraversalFixture $x.Transition.Navigation
        if($f.Event -ceq 'BRAKE_REQUESTED'){$f.Clock=Copy-TraversalFixture $x.Transition.Clock;$f|Add-Member NoteProperty EpochRevalidation (Copy-TraversalFixture $x.Transition.EpochRevalidation)}
        if($f.Event -ceq 'REPATH_AFTER_REST'){
            $f.Navigation.EpochRevalidation=$null;$f.Navigation.PlannedTileChangeVersion=12;$f.Navigation.PlannedTileDataVersion=6
            $plan=Copy-TraversalFixture $x.Transition.EpochRevalidation.CurrentQuery;$plan.From=$f.Actual;$plan.NativeCorners=@($f.Actual,$plan.To);$plan.ActorCorners=$plan.NativeCorners
            $f.Navigation.RoutePlan=@($plan);$f.Navigation.RouteFrom=$f.Actual;$f.Navigation.Corners=$plan.NativeCorners;$f.Navigation.RoutePolys=$plan.NativePolys
        }
        $rows+=,$f
    }
    ,$rows
}
$epochReplay=New-EpochLifecycleReplay
Assert-TraversalEpochTransitions $epochReplay;Assert-TraversalRecovery $epochReplay
foreach($case in @(
    @{Name='epoch proof licenses ordinary motion without brake request';Change={param($rows)$rows=@($rows|Where-Object Event -cne 'BRAKE_REQUESTED');foreach($f in $rows){if($f.Event -in @('MOVE_DECISION','MOVE_ISSUED','MOTION_WITNESS') -and $f.Command -gt 9){$f.MotionMode='SUPPORTED_ADVANCE';$f.Recovery=$null}};,$rows}},
    @{Name='ordinary motion relabeled inside epoch brake';Change={param($rows)@($rows|Where-Object Event -ceq 'MOVE_DECISION')[0].MotionMode='SUPPORTED_ADVANCE';,$rows}},
    @{Name='published brake request top/nav proof differs';Change={param($rows)@($rows|Where-Object Event -ceq 'BRAKE_REQUESTED')[0].EpochRevalidation.CompletedWall=1.006;,$rows}},
    @{Name='epoch brake loses linked current admission';Change={param($rows)@($rows|Where-Object Event -ceq 'MOVE_DECISION')[0].Navigation.EpochRevalidation=$null;,$rows}},
    @{Name='post-rest replan retained old committed origin';Change={param($rows)@($rows|Where-Object Event -ceq 'REPATH_AFTER_REST')[0].Navigation.RouteFrom=@(-1,0,0);,$rows}},
    @{Name='epoch proof followed by incomplete lifecycle';Change={param($rows),@($rows[0..2])}}
)){$rows=Copy-TraversalFixture $epochReplay;$rows=& $case.Change $rows;Deny-TraversalFixture {Assert-TraversalEpochTransitions $rows} $case.Name}
$splitEpoch=Copy-TraversalFixture (New-EpochBrakeFixture);$splitEpoch.Transition.Navigation.EpochRevalidation.CompletedWall=1.006
Deny-TraversalFixture {Assert-TraversalEpochProof $splitEpoch.Transition $splitEpoch.Prior} 'standalone top/current epoch proof split'
# An accepted read-only proof may be followed by an honest prewriter refusal, with no brake/rest credit.
$prewriter=Copy-TraversalFixture @($epochReplay[0..3]);$stop=Copy-TraversalFixture $prewriter[-1];$stop.Event='BLOCKED';$stop.NativeResult='STOPPED';$prewriter+=,$stop
Assert-TraversalEpochTransitions $prewriter;Assert-TraversalRecovery $prewriter
Write-Output 'PASS OFFLINE_ONLY020 epoch lifecycle: immediate brake-only request, exact top/current proof, actual-rest replan and honest no-writer terminal'
$velocityIntent=Copy-TraversalFixture $epochBrake.Prior;$velocityIntent.Profile|Add-Member NoteProperty FinalVelocityPolicy 'NATIVE_POST_SINK_VELOCITY_V1'
$velocityGuard=Copy-TraversalFixture @{Accepted=$true;Error=$null;StartedWall=1.006;CheckedWall=1.008;VelocityPolicy='NATIVE_POST_SINK_VELOCITY_V1';ExpectedVelocity=@(0.6,0,0);NativeVelocity=@(0.6,0,0);ExpectedVelocityFinite=$true;NativeVelocityFinite=$true;VelocityError=0;VelocityMatches=$true;VelocityCheckedWall=1.007}
Assert-TraversalFinalVelocity $velocityGuard $velocityIntent @(0.6,0,0)
$velocityBoundary=Copy-TraversalFixture $velocityGuard;$velocityBoundary.NativeVelocity=@(0.601,0,0);$velocityBoundary.VelocityError=0.0009999871
Assert-TraversalFinalVelocity $velocityBoundary $velocityIntent @(0.6,0,0)
foreach($case in @(
    @{Name='native velocity changed by decision sink';Change={param($x)$x.NativeVelocity[0]=0.2;$x.VelocityError=0.4;$x.VelocityMatches=$false}},
    @{Name='fake measured zero';Change={param($x)$x.ExpectedVelocity=@(0,0,0);$x.NativeVelocity=@(0,0,0)}},
    @{Name='reported error tolerance hid unsafe actual velocity';Change={param($x)$x.NativeVelocity=@(0.6010005,0,0);$x.VelocityError=0.0009996}},
    @{Name='new profile lost final velocity telemetry';Change={param($x)$x.PSObject.Properties.Remove('VelocityPolicy')}}
)){$x=Copy-TraversalFixture $velocityGuard;& $case.Change $x;Deny-TraversalFixture {Assert-TraversalFinalVelocity $x $velocityIntent @(0.6,0,0)} $case.Name}
$changedGuard=Copy-TraversalFixture $velocityGuard;$changedGuard.Accepted=$false;$changedGuard.NativeVelocity[0]=0.2;$changedGuard.VelocityError=0.4;$changedGuard.VelocityMatches=$false
Assert-TraversalFinalVelocity $changedGuard $velocityIntent @(0.6,0,0) -Rejected
$nanGuard=Copy-TraversalFixture $velocityGuard;$nanGuard.Accepted=$false;$nanGuard.NativeVelocity=@('NaN',0,0);$nanGuard.NativeVelocityFinite=$false;$nanGuard.VelocityError=$null;$nanGuard.VelocityMatches=$false
Assert-TraversalFinalVelocity $nanGuard $velocityIntent @(0.6,0,0) -Rejected
$exceptionGuard=Copy-TraversalFixture $nanGuard;$exceptionGuard.Error='NATIVE_EXCEPTION:InvalidOperationException';$exceptionGuard.NativeVelocity=$null;$exceptionGuard.NativeVelocityFinite=$null;$exceptionGuard.VelocityCheckedWall=$null
Assert-TraversalFinalVelocity $exceptionGuard $velocityIntent @(0.6,0,0) -Rejected
Assert-TraversalFinalVelocity ([pscustomobject]@{Accepted=$false;Error='DECISION_SINK_REFUSED:InvalidOperationException'}) $velocityIntent @(0.6,0,0) -Rejected
Write-Output 'PASS OFFLINE_ONLY020 final velocity: explicit source policy, real post-sink current/expected measured vectors; NaN/native-exception/sink-refusal diagnostics never license writer'
# OFFLINE_ONLY: source-shaped recertification receipts never prove native physics.
function Set-SeriesClock($f){
    $sequence=$f.Clock.Sequence;$wall=$f.Clock.WallTime
    $f.Clock=Copy-TraversalFixture @{Schema=2;Sequence=$sequence;Frame=(100+$sequence);WallTime=$wall;FixedTime=$wall;FixedUnscaledTime=$wall;Delta=0.0625;UnscaledDelta=0.0625;TimeScale=1;MaximumDelta=0.125;InFixedStep=$true;PhysicsMode='FixedUpdate'}
    $f.Schema=2;$f|Add-Member NoteProperty RecoveryPolicy 'MEASURED_BRAKE_V1' -Force
    $f.Profile|Add-Member NoteProperty EpochRevalidationPolicy 'SAME_COMMITTED_ROUTE_EPOCH_V2' -Force
    $f.Profile|Add-Member NoteProperty NavRadius 0.5 -Force;$f.Profile|Add-Member NoteProperty NavHeight 1.8 -Force
}
function New-SeriesTransition($template,$prior,$next,$ordinal,$previous,[bool]$starts){
    $p=Copy-TraversalFixture $template.EpochRevalidation;$p.Kind='SAME_COMMITTED_ROUTE_EPOCH_V2';$p.Attempt=$ordinal;$p.MaxAttempts=8
    $p.Clock=Copy-TraversalFixture $prior.Clock;$p.Command=$prior.Command;$p.Actual=$prior.Actual;$p.Body=$prior.Body;$p.Anchor=$prior.Support;$p.NativeVelocity=$prior.Body.Velocity
    $p.Velocity=if($starts){$next.Recovery.StartVelocity}else{Get-TraversalPhysicsVelocity $prior.Actual $prior.From $prior.Dt};$p.StartedWall=$p.Clock.WallTime+0.001;$p.NativeCompletedWall=$p.Clock.WallTime+0.003;$p.CompletedWall=$p.Clock.WallTime+0.005
    $p.NewChange=11+$ordinal;$p.NewData=5+$ordinal
    foreach($q in @($p.OriginalQuery,$p.CurrentQuery)){$q.ChangeBefore=$p.NewChange;$q.ChangeAfter=$p.NewChange;$q.DataBefore=$p.NewData;$q.DataAfter=$p.NewData}
    $p.CurrentQuery.From=$prior.Actual;$p.CurrentQuery.NativeCorners=@($prior.Actual,$p.Goal);$p.CurrentQuery.ActorCorners=$p.CurrentQuery.NativeCorners
    $p.Corridor=@(foreach($part in $next.Recovery.Corridor){Copy-TraversalFixture $part});$p.RequiredDistance=$next.Recovery.RequiredDistance
    $points=New-Object 'System.Collections.Generic.List[object]';$points.Add([double[]]@($prior.Actual[0],$prior.Actual[1],$prior.Actual[2]))
    foreach($part in $p.Corridor){$points.Add([double[]]@($part.Requested[0],$part.Requested[1],$part.Requested[2]))};$p.CorridorPoints=$points.ToArray()
    $before=$next.Recovery.Step-1
    foreach($pair in @(@('Ordinal',$ordinal),@('StartsBrake',$starts),@('BeforeStep',$before),@('NextStep',($before+1)),@('PreviousOrdinal',($ordinal-1)),@('PreviousCommand',$(if($previous){$previous.Command}else{0})),
        @('PreviousSequence',$(if($previous){$previous.Clock.Sequence}else{0})),@('PreviousCompletedWall',$(if($previous){$previous.CompletedWall}else{0})),
        @('PreviousAdmissionChange',$(if($previous){$previous.NewChange}else{$p.OldChange})),@('PreviousAdmissionData',$(if($previous){$previous.NewData}else{$p.OldData})),
        @('BrakeClock',(Copy-TraversalFixture $template.Clock)),@('BrakeOrigin',@(0,0,0)),@('BrakeVelocity',@(0.6,0,0)),@('RecoveryAttempt',1),
        @('ControlActive',$true),@('ControlBlocked',$false),@('ControlArrived',$false),@('UnobservedTerminal',$false))){$p|Add-Member NoteProperty $pair[0] $pair[1] -Force}
    $f=Copy-TraversalFixture $prior;$f.Event='NATIVE_ROUTE_EPOCH_REVALIDATED';$f.NativeResult='REVALIDATED';$f.From=$prior.Actual;$f.Requested=$prior.Actual
    $f|Add-Member NoteProperty Recovery (Copy-TraversalFixture $next.Recovery) -Force;$f.Recovery.Step=$before
    $f.Navigation=Copy-TraversalFixture $template.Navigation;$f.Navigation.EpochRevalidation=$p;$f.Navigation.AdmissionTileChangeVersion=$p.NewChange;$f.Navigation.AdmissionTileDataVersion=$p.NewData;$f.Navigation.TileChangeVersion=$p.NewChange;$f.Navigation.TileDataVersion=$p.NewData
    $f|Add-Member NoteProperty EpochRevalidation $p -Force;$f|Add-Member NoteProperty WriterCalled $false -Force;$f|Add-Member NoteProperty UnobservedCommand $false -Force
    $f|Add-Member NoteProperty Permission $true -Force;$f|Add-Member NoteProperty WaterDepth (-1) -Force;$f|Add-Member NoteProperty SupportAccepted $true -Force;$f|Add-Member NoteProperty OverlapClear $true -Force
    $f
}
function New-SeriesRestGuard($f,$phase){
    Copy-TraversalFixture @{Policy='EXACT_BRAKE_REST_V1';Phase=$phase;Accepted=$true;Session=$f.MotionSession;Command=$f.Command;Step=$f.Recovery.Step;Clock=$f.Clock;
        CheckedWall=($f.Clock.WallTime+0.002);Actual=$f.Actual;RigidbodyPosition=$f.Body.RigidbodyPosition;NativeVelocity=@(0,0,0);MeasuredVelocity=@(0,0,0);
        BodyValid=$true;ContextMatched=$true;QueriesExecuted=$true;FloorCurrent=$true;Support=$f.Support;Overlaps=@();OverlapClear=$true;Permission=$true;WaterDepth=-1;ClockAccepted=$true;Unchanged=$true;
        ControlActive=$true;ControlBlocked=$false;ControlArrived=$false;UnobservedTerminal=$false}
}
function New-EpochSeriesFixture([int[]]$RefreshSteps=@(1),[switch]$OrdinaryFirst){
    $source=Copy-TraversalFixture (New-EpochLifecycleReplay);$template=Copy-TraversalFixture @($source|Where-Object Event -ceq 'NATIVE_ROUTE_EPOCH_REVALIDATED')[0]
    Set-SeriesClock $template;$rows=@();$prior=$null;$latest=$null;$ordinal=0;$rest=$null
    foreach($f in $source){
        Set-SeriesClock $f
        if($f.Event -ceq 'CLOCK_BASELINE'){$f.Speed=0;$f.Body.Velocity=@(0,0,0)}
        if($f.Event -ceq 'NATIVE_ROUTE_EPOCH_REVALIDATED'){
            if($OrdinaryFirst){continue}
            $next=@($source|Where-Object Event -ceq 'MOVE_DECISION')[0];$transition=New-SeriesTransition $template $prior $next 1 $null $true
            $latest=$transition.EpochRevalidation;$ordinal=1;$rows+=,$transition;continue
        }
        if($f.Event -ceq 'MOVE_DECISION' -and $RefreshSteps -contains ($f.Recovery.Step-1)){
            $ordinal++;$transition=New-SeriesTransition $template $prior $f $ordinal $latest $false;$latest=$transition.EpochRevalidation;$rows+=,$transition
        }
        $f.Navigation=Copy-TraversalFixture $template.Navigation
        $f.Navigation.EpochRevalidation=if($latest){Copy-TraversalFixture $latest}else{$null}
        $change=if($latest){$latest.NewChange}else{11};$data=if($latest){$latest.NewData}else{5}
        $f.Navigation.AdmissionTileChangeVersion=$change;$f.Navigation.AdmissionTileDataVersion=$data;$f.Navigation.TileChangeVersion=$change;$f.Navigation.TileDataVersion=$data
        if($f.Event -ceq 'BRAKE_REQUESTED'){
            if($latest){$f|Add-Member NoteProperty EpochRevalidation (Copy-TraversalFixture $latest) -Force}else{$f.PSObject.Properties.Remove('EpochRevalidation')}
        }
        if($f.Event -ceq 'ACTUAL_REST'){
            $f.Navigation.TileChangeVersion++;$f.Navigation.TileDataVersion++
            $rest=Copy-TraversalFixture @{Policy='EXACT_BRAKE_REST_V1';Session=$f.MotionSession;Command=$f.Command;Step=$f.Recovery.Step;Attempt=1;Clock=$f.Clock;BrakeClock=$template.Clock;
                Actual=$f.Actual;RigidbodyPosition=$f.Body.RigidbodyPosition;Goal=@(2,0,0);BrakeOrigin=@(0,0,0);BrakeVelocity=@(0.6,0,0);Floor=$f.Recovery.FloorCollider;Guard=(New-SeriesRestGuard $f 'REST_ACK')}
            $f|Add-Member NoteProperty RestAdmission $rest
        }
        if($f.Event -ceq 'REPATH_AFTER_REST'){
            $f.Navigation.EpochRevalidation=$null;$f.Navigation.PlannedTileChangeVersion=$change+1;$f.Navigation.PlannedTileDataVersion=$data+1
            $f.Navigation.AdmissionTileChangeVersion=$change+1;$f.Navigation.AdmissionTileDataVersion=$data+1;$f.Navigation.TileChangeVersion=$change+1;$f.Navigation.TileDataVersion=$data+1
            $plan=Copy-TraversalFixture $template.EpochRevalidation.CurrentQuery;$plan.From=$f.Actual;$plan.NativeCorners=@($f.Actual,$plan.To);$plan.ActorCorners=$plan.NativeCorners
            $plan.ChangeBefore=$change+1;$plan.ChangeAfter=$change+1;$plan.DataBefore=$data+1;$plan.DataAfter=$data+1
            $f.Navigation.RoutePlan=@($plan);$f.Navigation.RouteFrom=$f.Actual;$f.Navigation.Corners=$plan.NativeCorners;$f.Navigation.RoutePolys=$plan.NativePolys
            $f|Add-Member NoteProperty RestReplan @{Kind='PLAN';Accepted=$true;Guard=(New-SeriesRestGuard $f 'REST_PLAN_PRECOMMIT');Time=($f.Clock.WallTime+0.003)}
        }
        $rows+=,$f;if($f.Event -ceq 'MOTION_WITNESS'){$prior=$f}
    }
    ,$rows
}
$series=New-EpochSeriesFixture
Assert-TraversalEpochTransitions $series;Assert-TraversalRecovery $series
$roundtrip=Copy-TraversalFixture $series;Assert-TraversalEpochTransitions $roundtrip
$ordinarySeries=New-EpochSeriesFixture -OrdinaryFirst -RefreshSteps @(1,3)
Assert-TraversalEpochTransitions $ordinarySeries;Assert-TraversalRecovery $ordinarySeries
$ordinaryNoEpoch=New-EpochSeriesFixture -OrdinaryFirst -RefreshSteps @()
$plainRest=@($ordinaryNoEpoch|Where-Object Event -ceq 'ACTUAL_REST')[0];$plainRest.Navigation.TileChangeVersion=11;$plainRest.Navigation.TileDataVersion=5
$plainPlan=@($ordinaryNoEpoch|Where-Object Event -ceq 'REPATH_AFTER_REST')[0];$plainPlan.RestReplan.Kind='OBSTACLE';$plainPlan.RestReplan.Guard.Phase='REST_OBSTACLE_PRECOMMIT'
$legs=@();$via=@(0.5,0,0.5)
for($i=0;$i -lt 2;$i++){
    $leg=Copy-TraversalFixture $plainPlan.Navigation.RoutePlan[0];$leg.From=if($i -eq 0){$plainPlan.Actual}else{$via};$leg.To=if($i -eq 0){$via}else{@(2,0,0)}
    $leg.NativeCorners=@($leg.From,$leg.To);$leg.ActorCorners=$leg.NativeCorners;$leg.ChangeBefore=11;$leg.ChangeAfter=11;$leg.DataBefore=5;$leg.DataAfter=5;$legs+=,$leg
}
$plainPlan.Navigation.RoutePlan=$legs;$plainPlan.Navigation.Corners=@($legs[0].From,$via,$legs[1].To);$plainPlan.Navigation.RoutePolys=@($legs[0].NativePolys)+@($legs[1].NativePolys)
foreach($key in @('PlannedTileChangeVersion','AdmissionTileChangeVersion','TileChangeVersion')){$plainPlan.Navigation.$key=11}
foreach($key in @('PlannedTileDataVersion','AdmissionTileDataVersion','TileDataVersion')){$plainPlan.Navigation.$key=5}
Assert-TraversalEpochTransitions $ordinaryNoEpoch;Assert-TraversalRecovery $ordinaryNoEpoch
$failedOrdinary=@($ordinaryNoEpoch|Where-Object Event -cne 'REPATH_AFTER_REST');$failed=Copy-TraversalFixture $plainPlan;$failed.Event='REPATH';$failed.RestReplan.Accepted=$false;$failed.Navigation=Copy-TraversalFixture $plainRest.Navigation
$failedOrdinary+=,$failed;$stop=Copy-TraversalFixture $failed;$stop.Event='BLOCKED';$stop.NativeResult='NOT_ISSUED';$failedOrdinary+=,$stop
Assert-TraversalEpochTransitions $failedOrdinary
Deny-TraversalFixture {Assert-TraversalEpochTransitions @($failedOrdinary+$plainPlan)} 'failed ordinary sidepath followed by credited progress'
foreach($case in @(
    @{Name='second brake request during refresh';Change={param($x)$p=@($x|Where-Object Event -ceq 'NATIVE_ROUTE_EPOCH_REVALIDATED')[-1];$p.Event='BRAKE_REQUESTED'}},
    @{Name='proof ordinal confused with skipped stable brake steps';Change={param($x)$p=@($x|Where-Object Event -ceq 'NATIVE_ROUTE_EPOCH_REVALIDATED')[-1];$p.EpochRevalidation.Ordinal=4}},
    @{Name='previous proof timestamp rebound';Change={param($x)$p=@($x|Where-Object Event -ceq 'NATIVE_ROUTE_EPOCH_REVALIDATED')[-1];$p.EpochRevalidation.PreviousCompletedWall+=0.01}},
    @{Name='original brake clock reset';Change={param($x)$p=@($x|Where-Object Event -ceq 'NATIVE_ROUTE_EPOCH_REVALIDATED')[-1];$p.EpochRevalidation.BrakeClock.Sequence++}},
    @{Name='projection extends remaining step budget';Change={param($x)$p=@($x|Where-Object Event -ceq 'NATIVE_ROUTE_EPOCH_REVALIDATED')[-1];$p.EpochRevalidation.BeforeStep=7;$p.EpochRevalidation.NextStep=8}},
    @{Name='new source policy stripped from one frame';Change={param($x)$x[-1].Profile.PSObject.Properties.Remove('EpochRevalidationPolicy')}},
    @{Name='post-sink rest cancellation licensed replan';Change={param($x)$p=@($x|Where-Object Event -ceq 'REPATH_AFTER_REST')[0];$p.RestReplan.Guard.ControlActive=$false;$p.RestReplan.Guard.ControlBlocked=$true}},
    @{Name='native nonzero became measured rest';Change={param($x)$p=@($x|Where-Object Event -ceq 'ACTUAL_REST')[0];$p.RestAdmission.Guard.NativeVelocity=@(0.00001,0,0)}},
    @{Name='current water unsafe at exact rest acknowledgement';Change={param($x)$p=@($x|Where-Object Event -ceq 'ACTUAL_REST')[0];$p.RestAdmission.Guard.WaterDepth=1.0}},
    @{Name='current water unsafe at native rest replan commit';Change={param($x)$p=@($x|Where-Object Event -ceq 'REPATH_AFTER_REST')[0];$p.RestReplan.Guard.WaterDepth=1.0}},
    @{Name='replan timestamp exceeds the original callback';Change={param($x)$p=@($x|Where-Object Event -ceq 'REPATH_AFTER_REST')[0];$p.RestReplan.Time=$p.Clock.WallTime+100}},
    @{Name='replan timestamp follows its actual emission';Change={param($x)$p=@($x|Where-Object Event -ceq 'REPATH_AFTER_REST')[0];$p|Add-Member NoteProperty WallTelemetry @{ReadDelay=0.0025}}}
)){$x=Copy-TraversalFixture $ordinarySeries;& $case.Change $x;Deny-TraversalFixture {Assert-TraversalEpochTransitions $x} $case.Name}
$cancel=Copy-TraversalFixture @($series[0..2]);$stop=Copy-TraversalFixture $cancel[-1];$stop.Event='BLOCKED';$stop.NativeResult='STOPPED';$cancel+=,$stop
Assert-TraversalEpochTransitions $cancel
Deny-TraversalFixture {Assert-TraversalEpochTransitions @($cancel+$series[3])} 'proof cancellation followed by a ghost brake request'
Write-Output 'PASS OFFLINE_ONLY020 V2 series: multiple same-brake proofs, first proof during ordinary brake, skipped stable epochs, immutable original budgets/links and truthful cancellation'
Write-Output 'PASS OFFLINE_ONLY020 exact rest: native+measured zero across epoch change, guarded fresh Plan and denied sink cancellation/nonzero/fake clock or step reset'
$afterDone=Copy-TraversalFixture $series[-1];$afterDone.Event='MOVE_DECISION';$afterDone.MotionMode='SUPPORTED_ADVANCE';$afterDone.Recovery=$null;$afterDone.Command++
$afterDone.Navigation=Copy-TraversalFixture @($series|Where-Object Event -ceq 'NATIVE_ROUTE_EPOCH_REVALIDATED')[-1].Navigation
Deny-TraversalFixture {Assert-TraversalEpochTransitions @($series+$afterDone)} 'completed replan reused an obsolete brake-only proof'
$lateRestTestNew=$true
function New-LateRestFixture([string]$phase='REST_ACK',[switch]$PublicStop,[switch]$ChangedNative,[switch]$PlanOnly){
    $all=@(New-RecoveryFrames);$last=@($all|Where-Object Event -ceq 'MOTION_WITNESS')[-1];$rows=@();foreach($f in $all){$rows+=,$f;if([object]::ReferenceEquals($f,$last)){break}}
    foreach($f in $rows){
        $seq=$f.Clock.Sequence;$wall=$f.Clock.WallTime
        $f.Schema=2;$f.Clock=Copy-TraversalFixture @{Schema=2;Sequence=$seq;Frame=(100+$seq);WallTime=$wall;FixedTime=$wall;FixedUnscaledTime=$wall;Delta=0.0625;UnscaledDelta=0.0625;TimeScale=1;MaximumDelta=0.125;InFixedStep=$true;PhysicsMode='FixedUpdate'}
        $f|Add-Member NoteProperty PreviousClock (Copy-TraversalFixture $f.Clock) -Force;$f.PreviousClock.Sequence--;$f.PreviousClock.Frame--;$f.PreviousClock.WallTime-=0.0625;$f.PreviousClock.FixedTime-=0.0625;$f.PreviousClock.FixedUnscaledTime-=0.0625
        $f|Add-Member NoteProperty WallDt 0.0625 -Force;$f|Add-Member NoteProperty RecoveryPolicy 'MEASURED_BRAKE_V1' -Force
        $f.Profile|Add-Member NoteProperty EpochRevalidationPolicy 'SAME_COMMITTED_ROUTE_EPOCH_V2' -Force;$f.Profile|Add-Member NoteProperty FinalVelocityPolicy 'NATIVE_POST_SINK_VELOCITY_V1' -Force
        $f.Profile|Add-Member NoteProperty MaxWallStall 1.5 -Force;$f.Profile|Add-Member NoteProperty NativeMaximumDelta 0.125 -Force
        $f|Add-Member NoteProperty WallTelemetry (Copy-TraversalFixture @{CallbackGap=0.0625;ReadDelay=0.01;MaxWallStall=1.5;NativeMaximumDelta=0.125;NativeCatchupExceeded=$false;State='ON_TIME'}) -Force
        foreach($pair in @(@('Permission',$true),@('SupportAccepted',$true),@('OverlapClear',$true),@('WaterDepth',-1))){$f|Add-Member NoteProperty $pair[0] $pair[1] -Force}
        if($f.Event -ceq 'MOVE_ISSUED'){$f|Add-Member NoteProperty WriterCalled $true -Force;$f|Add-Member NoteProperty Actuations $f.Command -Force}
        if($f.Event -ceq 'MOTION_WITNESS'){$f|Add-Member NoteProperty NativeVelocityMatches $true -Force;$f|Add-Member NoteProperty NativeVelocityError 0 -Force}
    }
    $w=$rows[-1];$issued=@($rows|Where-Object {$_.Event -ceq 'MOVE_ISSUED' -and $_.Command -eq $w.Command})[0];$w|Add-Member NoteProperty IssuedClock (Copy-TraversalFixture $issued.Clock) -Force
    $br=Copy-TraversalFixture $w;$br.Event='BRAKE_WITNESSED';$rows+=,$br
    $g=Copy-TraversalFixture @{Policy='EXACT_BRAKE_REST_V1';Phase=$phase;Accepted=$false;Session=$w.MotionSession;Command=$w.Command;Step=$w.Recovery.Step;Clock=$w.Clock;CheckedWall=($w.Clock.WallTime+0.2);Actual=$w.Actual;RigidbodyPosition=$w.Body.RigidbodyPosition;NativeVelocity=@(0,0,0);MeasuredVelocity=@(0,0,0);BodyValid=$true;ContextMatched=$true;ClockAccepted=$false;Unchanged=$true;QueriesExecuted=$true;FloorCurrent=$true;OverlapClear=$true;Permission=$true;WaterDepth=-1;ControlActive=$true;ControlBlocked=$false;ControlArrived=$false;UnobservedTerminal=$false}
    if($phase -cne 'REST_ACK'){$rest=Copy-TraversalFixture $w;$rest.Event='ACTUAL_REST';$rest|Add-Member NoteProperty RestAdmission @{Policy='EXACT_BRAKE_REST_V1';Guard=@{Accepted=$true}};$rows+=,$rest}
    $block=Copy-TraversalFixture $w;$block.Event='BLOCKED';$block.NativeResult='NOT_ISSUED';$block.Classification='UNKNOWN';$block.Reason=if($PlanOnly){'BRAKE_REST_NATIVE_REPLAN_INVALID'}elseif($phase -ceq 'REST_ACK'){'BRAKE_REST_CONTEXT_UNCERTAIN'}elseif($phase -ceq 'REST_OBSTACLE_REFUSED'){'BRAKE_REST_CHANGED_DURING_NATIVE_REPATH'}else{'BRAKE_REST_CHANGED_AFTER_SINK'}
    foreach($pair in @(@('WriterCalled',$false),@('UnobservedCommand',$false),@('PendingDecision',$null))){$block|Add-Member NoteProperty $pair[0] $pair[1] -Force}
    $block.WallTelemetry.ReadDelay=0.21
    if($PlanOnly){$g.Accepted=$true;$g.ClockAccepted=$true;$g.CheckedWall=$w.Clock.WallTime+0.02;$block|Add-Member NoteProperty RestReplan @{Kind='PLAN';Accepted=$false;Guard=$g;Time=($w.Clock.WallTime+0.2)}}else{$block|Add-Member NoteProperty RestReplanGuard $g}
    if($ChangedNative){$g.NativeVelocity=@('NaN',0,0);$g.BodyValid=$false;$g.ContextMatched=$false;$block.Body.Velocity=@('NaN',0,0);$block.Body.Radius=0.45}
    if($PublicStop){$early=Copy-TraversalFixture $block;$early.NativeResult='STOPPED';$early.PSObject.Properties.Remove('RestReplanGuard');$early.PSObject.Properties.Remove('RestReplan');$rows+=,$early}
    $rows+=,$block;$stop=Copy-TraversalFixture $block;$stop.NativeResult='STOPPED';$stop.Clock=$null;$stop.PreviousClock=$null;$stop.Time+=0.1;$rows+=,$stop
    [pscustomobject]@{Frames=$rows;Witness=$w;Failure=$block;FirstLate=$(if($PublicStop){$early}else{$block});Nav=@{Status='PARTIAL';Actor=@{NetId='19'};Traversal=@{Frames=$rows;Completed=$false;Scenes=@()}}}
}
function New-LateFailedRepathFixture([switch]$SinkStop){
    $x=New-LateRestFixture 'AFTER_REST_SINK';$f=$x.Failure;$g=$f.RestReplanGuard
    $g.Accepted=$true;$g.ClockAccepted=$true;$g.CheckedWall=$x.Witness.Clock.WallTime+0.02
    $f.PSObject.Properties.Remove('RestReplanGuard');$f|Add-Member NoteProperty RestReplan @{Kind='OBSTACLE';Accepted=$false;Guard=$g;Time=($x.Witness.Clock.WallTime+0.2)}
    $route=Copy-TraversalFixture $f;$route.Event='REPATH';$route.NativeResult='OBSERVED';$route.Reason='NO_BOUNDED_SUPPORTED_TRAJECTORY'
    if($SinkStop){$f.NativeResult='STOPPED';$f.PSObject.Properties.Remove('RestReplan')}
    $x.Frames=@($x.Frames[0..($x.Frames.Count-3)])+@($route,$f,$x.Frames[-1]);$x.FirstLate=$route;$x.Nav.Traversal.Frames=$x.Frames
    $x
}
$positiveCases=@((New-LateRestFixture),(New-LateRestFixture 'AFTER_REST_SINK' -PublicStop),(New-LateRestFixture 'REST_PLAN_REFUSED' -PlanOnly),(New-LateRestFixture -ChangedNative))
if($lateRestTestNew){$positiveCases+=@((New-LateFailedRepathFixture),(New-LateFailedRepathFixture -SinkStop),(New-LateRestFixture 'REST_OBSTACLE_REFUSED'))}
$positive=@();foreach($case in $positiveCases){$ok=$true;$why=$null;$originalEvent=$case.FirstLate.Event;$originalResult=$case.FirstLate.NativeResult;try{if($lateRestTestNew){Assert-TraversalLateRestRefusal $case.FirstLate $case.Witness $null $case.Frames '19';Assert-TraversalLateRestResult $case.Nav;if($case.FirstLate.Event -cne $originalEvent -or $case.FirstLate.NativeResult -cne $originalResult){throw 'Diagnostic validator view mutated original raw shape'}}else{Assert-TraversalTerminalRefusal $case.Failure $case.Witness $null $case.Frames[-1] $case.Frames '19'}}catch{$ok=$false;$why=$_.Exception.Message};$positive+=,[pscustomobject]@{Pass=$ok;Error=$why}}
if(@($positive|Where-Object {-not $_.Pass}).Count){throw ($positive|ConvertTo-Json -Compress)}
$historicalScene=New-LateRestFixture;$historicalScene.Nav.Traversal.Scenes=@(@{Status='PASSED';FramesTo=1});Assert-TraversalLateRestResult $historicalScene.Nav
$denied=0
foreach($mutation in @(
    {param($x)$x.Witness.Body.Velocity=@(0.00001,0,0)},
    {param($x)$x.Witness.From[0]-=0.001},
    {param($x)$x.Witness.MotionMode='SUPPORTED_ADVANCE'},
    {param($x)$x.Witness.Casts=65},
    {param($x)$x.Witness.Dt=0.2},
    {param($x)$x.Failure.PSObject.Properties.Remove('RestReplanGuard')},
    {param($x)$x.Failure.RestReplanGuard.CheckedWall=$x.Witness.Clock.WallTime+0.02},
    {param($x)$x.Witness.Recovery.Step=9},
    {param($x)$x.Failure.Profile.EpochRevalidationPolicy='UNKNOWN'},
    {param($x)$x.Frames=@($x.Frames|Where-Object Event -cne 'MOVE_ISSUED')},
    {param($x)$future=Copy-TraversalFixture $x.Failure;$future.Event='MOVE_DECISION';$x.Frames=@($x.Frames[0..($x.Frames.Count-2)])+@($future,$x.Frames[-1])}
)){$x=New-LateRestFixture;& $mutation $x;Deny-TraversalFixture {Assert-TraversalLateRestRefusal $x.Failure $x.Witness $null $x.Frames '19'} 'invalid late-rest diagnostic lineage';$denied++}
$x=New-LateRestFixture;Deny-TraversalFixture {Assert-TraversalLateRestRefusal $x.Failure $x.Witness $x.Frames[1] $x.Frames '19'} 'pending writer at late rest';$denied++
$x=New-LateRestFixture;$x.Nav.Status='GREEN';Deny-TraversalFixture {Assert-TraversalLateRestResult $x.Nav} 'late rest claimed GREEN';$denied++
$x=New-LateRestFixture;$x.Nav.Traversal.Scenes=@(@{Status='PASSED';FramesTo=$x.Frames.Count});Deny-TraversalFixture {Assert-TraversalLateRestResult $x.Nav} 'scene success after late refusal';$denied++
foreach($mutation in @(
    {param($x)$x.FirstLate.RestReplan.Accepted=$true},
    {param($x)$x.FirstLate.RestReplan.Guard.Permission=$false},
    {param($x)$x.FirstLate.RestReplan.Guard.WaterDepth=0.16},
    {param($x)$x.Frames=@($x.Frames|Where-Object Event -cne 'ACTUAL_REST')},
    {param($x)$x.Frames=@($x.Frames|Where-Object Event -cne 'BLOCKED')},
    {param($x)$x.FirstLate.RestReplan.Time=$x.Witness.Clock.WallTime+0.02}
)){$x=New-LateFailedRepathFixture;& $mutation $x;Deny-TraversalFixture {Assert-TraversalLateRestRefusal $x.FirstLate $x.Witness $null $x.Frames '19'} 'invalid late failed side-path diagnostic';$denied++}
Write-Output ('PASS V2 late rest positives='+$positive.Count+' grouped negatives='+$denied)
# Whole-result closure preserves the old paid prefix and terminal diagnostic snapshots.
function New-LateRestResultFixture{
    $x=New-LateRestFixture;$cutoff=123.456789123
    $x.FirstLate.Clock.WallTime=$cutoff
    $old=[double][single]$cutoff
    $x.Nav.FirstHome=@{NativePlacements=@(@{Time=$old});Operations=@(@{Time=$old});Navigation=@(@{Event='TC_REACHED';Time=$old});Phases=@(@{Phase='NAV';Time=$old});Home=@{Historical=$true};Upkeep=@{Historical=$true};Portal=@{Historical=$true}}
    $x.Nav.Traversal.Fixture=@{Time=$old};$x.Nav.Traversal.FixtureTransitions=@(@{Event='FULL_HOME_READY';Time=$old})
    $x.Nav.Traversal.BuildRests=@(@{Time=$old;Arrived=$true});$x.Nav.Traversal.Detour=@{Time=$old}
    $x.Nav.Traversal.BuildPlans=@(@{Time=($cutoff-0.00000001)});$x.Nav.Traversal.DestinationWindows=@(@{Contract=@{Start=($cutoff-0.00000001)}})
    $x
}
$lateWhole=New-LateRestResultFixture;Assert-TraversalLateRestResult $lateWhole.Nav
$lateWhole=New-LateRestFixture;Assert-TraversalLateRestResult $lateWhole.Nav
$lateWholeDenied=0
foreach($mutation in @(
    {param($x)$x.Nav.FirstHome.NativePlacements[0].Time+=0.01},
    {param($x)$x.Nav.FirstHome.Operations[0].Time+=0.01},
    {param($x)$x.Nav.Traversal.FixtureTransitions[0].Time+=0.01},
    {param($x)$x.Nav.Traversal.Fixture.Time+=0.01},
    {param($x)$x.Nav.FirstHome.Navigation[0].Time+=0.01},
    {param($x)$x.Nav.FirstHome.Phases[0].Time+=0.01},
    {param($x)$x.Nav.Traversal.BuildRests[0].Time+=0.01},
    {param($x)$x.Nav.Traversal.Detour.Time+=0.01},
    {param($x)$x.Nav.Traversal.BuildPlans[0].Time=$x.FirstLate.Clock.WallTime+0.00000001},
    {param($x)$x.Nav.Traversal.DestinationWindows[0].Contract.Start=$x.FirstLate.Clock.WallTime+0.00000001}
)){$lateWhole=New-LateRestResultFixture;& $mutation $lateWhole;Deny-TraversalFixture {Assert-TraversalLateRestResult $lateWhole.Nav} 'post-refusal native progress';$lateWholeDenied++}
Write-Output ('PASS V2 late rest whole-result old-prefix/partial positives=2 grouped future-progress negatives='+$lateWholeDenied)
# OFFLINE_ONLY: source-shaped receipts; no Unity/native execution or movement proof.
function New-StationaryClock([int]$sequence,[double]$wall){
    Copy-TraversalFixture @{Schema=2;Sequence=$sequence;Frame=(100+$sequence);WallTime=$wall;FixedTime=$wall;FixedUnscaledTime=$wall;Delta=0.0625;UnscaledDelta=0.0625;TimeScale=1;MaximumDelta=0.125;InFixedStep=$true;PhysicsMode='FixedUpdate'}
}
function New-StationaryFrozenBody($b){
    Copy-TraversalFixture @{Position=$b.Position;RigidbodyPosition=$b.RigidbodyPosition;CapsulePosition=$b.Position;Rotation=$b.Rotation;CapsuleRotation=$b.Rotation;
        Scale=$b.Scale;Center=$b.Center;A=$b.A;B=$b.B;Radius=$b.Radius;Height=$b.Height;Capsule=$b.Instance;Rigidbody=$b.RigidbodyInstance;Direction=$b.Direction;Layer=$b.Layer;
        Enabled=$b.Enabled;Trigger=$b.Trigger;Kinematic=$b.Kinematic;Gravity=$b.Gravity;Detect=$b.DetectCollisions;CollisionMode=$b.CollisionMode;AgentStopped=$b.AgentStopped;AgentPosition=$b.AgentUpdatePosition;AgentRotation=$b.AgentUpdateRotation}
}
function New-StationaryNative($clock,[bool]$pending,[int]$change=12,[bool]$compared=$false){
    Copy-TraversalFixture @{StartedWall=($clock.WallTime+0.0015);CompletedWall=($clock.WallTime+0.002);Available=$true;DefaultMesh=$true;Handle='7';Built=$true;PendingTiles=$pending;
        OnMesh=$true;ProfileMatched=$true;FilterMatched=$true;Change=$change;Data=6;ComparedToSpan=$compared;SameSpanObject=$(if($compared){$true}else{$null});Ready=(-not $pending);Reason=$(if($pending){'NATIVE_PENDING_OR_UNKNOWN'}else{$null})}
}
function New-StationaryPhysicalGuard($f,[string]$phase='OBSERVATION',[double]$offset=0.001){
    Copy-TraversalFixture @{Phase=$phase;Accepted=$true;CheckedWall=($f.Clock.WallTime+$offset);Clock=$f.Clock;Body=$f.Body;FrozenBody=(New-StationaryFrozenBody $f.Body);
        Actual=$f.Actual;RigidbodyPosition=$f.Body.RigidbodyPosition;NativeVelocity=@(0,0,0);MeasuredVelocity=@(0,0,0);ContextMatched=$true;FloorCurrent=$true;Support=$f.Support;
        Overlaps=@();QueriesExecuted=$true;OverlapClear=$true;Permission=$true;WaterDepth=-1;ClockAccepted=$true;ControlActive=$true;ControlBlocked=$false;ControlArrived=$false;UnobservedTerminal=$false}
}
function New-StationaryCombinedGuard($f,[string]$phase,[double]$offset){
    $p=New-StationaryPhysicalGuard $f $phase ($offset-0.002);$n=New-StationaryNative $f.Clock $false 12 $true;$n.StartedWall=$f.Clock.WallTime+$offset-0.0015;$n.CompletedWall=$f.Clock.WallTime+$offset-0.001
    Copy-TraversalFixture @{Phase=$phase;Accepted=$true;CheckedWall=($f.Clock.WallTime+$offset);Clock=$f.Clock;Body=$f.Body;Physical=$p;Native=$n;NativeAccepted=$true;Unchanged=$true;ClockAccepted=$true}
}
function Set-StationaryFrameClock($f,$clock,$previous){
    $f.Schema=2;$f|Add-Member NoteProperty Clock (Copy-TraversalFixture $clock) -Force;$f.Time=$clock.WallTime;$f.Tick=$clock.Sequence
    $f|Add-Member NoteProperty PreviousClock $(if($previous){Copy-TraversalFixture $previous}else{$null}) -Force
    $f|Add-Member NoteProperty WallDt $(if($previous){$clock.WallTime-$previous.WallTime}else{$clock.WallTime-0.5}) -Force
    $f|Add-Member NoteProperty FixedDt 0.0625 -Force;$f.Dt=0.0625
    $f|Add-Member NoteProperty WallTelemetry @{CallbackGap=$f.WallDt;ReadDelay=0.004;MaxWallStall=1.5;NativeMaximumDelta=0.125;NativeCatchupExceeded=$false;State='ON_TIME'} -Force
}
function New-StationaryCheckedTriplet($from,$to,$priorVelocity,[int]$command,$clock,$previous,$nav,$profile,$snapshot=$null,$recovery=$null){
    $dt=0.0625;$velocity=Get-TraversalPhysicsVelocity $to $from $dt;$speed=Get-WorldDistance $velocity @(0,0,0)
    $md=New-TraversalFrame 'MOVE_DECISION' $command $clock.WallTime $from $to 0;Set-StationaryFrameClock $md $clock $previous
    $md.Classification='CLEAR';$md.Profile=Copy-TraversalFixture $profile;$md.Body|Add-Member NoteProperty Velocity $priorVelocity -Force;$md.Dt=$dt;$md.Distance=Get-WorldDistance $from $to;$md.Speed=$speed;$md.Acceleration=(Get-WorldDistance $velocity $priorVelocity)/$dt
    $md.Support.Origin=@($from[0],($from[1]+0.77),$from[2]);$md.Support.Center=@($from[0],($from[1]+0.5),$from[2]);$md.Support.Point=$from;$md.Support.FootY=$from[1];$md.Support.Hits[0].Point=$from
    $md.Navigation=Copy-TraversalFixture $nav;$md.Navigation.PendingTiles=$false;$md.Navigation|Add-Member NoteProperty AdmissionPolicy 'NATIVE_CURRENT_ROUTE_V1' -Force
    $refs=@(foreach($p in $nav.RoutePolys){@{Ref=[string]$p;Valid=$true}})
    $a=Copy-TraversalFixture @{Kind='NATIVE_CURRENT_ROUTE_V1';From=$from;To=$nav.RouteTo;Requested=$to;Sequence=$clock.Sequence;StartedWall=($clock.WallTime+0.001);CompletedWall=($clock.WallTime+0.002);CheckedWall=($clock.WallTime+0.002);
        Mesh=$nav.PlannedMesh;ChangeBefore=$nav.PlannedTileChangeVersion;ChangeAfter=$nav.PlannedTileChangeVersion;DataBefore=$nav.PlannedTileDataVersion;DataAfter=$nav.PlannedTileDataVersion;FilterBefore=$nav.RouteFilter;FilterAfter=$nav.RouteFilter;
        NativeCalculated=$true;ActorCalculated=$true;NativeStatus='PathComplete';ActorStatus='PathComplete';Capacity=256;NativeCorners=@($from,$nav.RouteTo);ActorCorners=@($from,$nav.RouteTo);NativePolys=$refs;ActorPolys=$nav.RoutePolys;RoutePolys=$refs;GlobalPendingBefore=$false;GlobalPendingAfter=$false}
    $md.Navigation|Add-Member NoteProperty Admission $a -Force;$md|Add-Member NoteProperty DecisionPublishedWall ($clock.WallTime+0.003) -Force
    $md|Add-Member NoteProperty IssuedClock (Copy-TraversalFixture $clock) -Force
    foreach($kv in @(@('MotionSession',1),@('RecoveryPolicy','MEASURED_BRAKE_V1'),@('GlobalDeadline',1000),@('WriterCalled',$false),@('PendingDecision',$null),@('UnobservedCommand',$false),@('Permission',$true),@('WaterDepth',-1),@('SupportAccepted',$true),@('OverlapClear',$true),@('LandingPermission',$true),@('LandingWaterDepth',-1),@('LandingSupportAccepted',$true),@('StationaryReplan',$snapshot),@('Recovery',$recovery))){$md|Add-Member NoteProperty $kv[0] $kv[1] -Force}
    $mi=Copy-TraversalFixture $md;$mi.Event='MOVE_ISSUED';$mi.NativeResult='ISSUED';$mi.WriterCalled=$true;$mi|Add-Member NoteProperty Actuations $command -Force;$mi.WallTelemetry.ReadDelay=0.007
    $g=Copy-TraversalFixture @{Kind='POST_SINK_NATIVE_GUARD_V1';Accepted=$true;Error=$null;Sequence=$clock.Sequence;StartedWall=($clock.WallTime+0.004);CheckedWall=($clock.WallTime+0.006);From=$from;Requested=$to;
        MeshBefore=$nav.PlannedMesh;MeshAfter=$nav.PlannedMesh;ChangeBefore=$nav.PlannedTileChangeVersion;ChangeAfter=$nav.PlannedTileChangeVersion;DataBefore=$nav.PlannedTileDataVersion;DataAfter=$nav.PlannedTileDataVersion;FilterBefore=$nav.RouteFilter;FilterAfter=$nav.RouteFilter;
        DefaultBuilt=$true;OnNavMesh=$true;ProfileMatches=$true;BodyValid=$true;ClockAccepted=$true;ControlActive=$true;RoutePolys=$refs;NativePolys=$refs;GlobalPendingBefore=$false;GlobalPendingAfter=$false;
        VelocityPolicy='NATIVE_POST_SINK_VELOCITY_V1';ExpectedVelocity=$priorVelocity;NativeVelocity=$priorVelocity;ExpectedVelocityFinite=$true;NativeVelocityFinite=$true;VelocityError=0;VelocityMatches=$true;VelocityCheckedWall=($clock.WallTime+0.005);
        StationaryBodyRequired=($null -ne $snapshot);StationaryBodyMatched=$(if($snapshot){$true}else{$null});StationaryBody=$(if($snapshot){$snapshot.FrozenBody}else{$null})}
    $mi|Add-Member NoteProperty FinalAdmission $g -Force
    if($snapshot){$mi.StationaryReplan.State='WRITTEN';$mi.StationaryReplan.FirstWriterCommand=$command;$mi.StationaryReplan.CurrentCommand=$command;$mi.StationaryReplan.CurrentActuations=$command;$mi.StationaryReplan.CurrentPending=$true}
    $wc=New-StationaryClock ($clock.Sequence+1) ($clock.WallTime+$dt);$mw=New-TraversalFrame 'MOTION_WITNESS' $command $wc.WallTime $from $to $speed;Set-StationaryFrameClock $mw $wc $clock
    $mw.Classification='CLEAR';$mw.Profile=Copy-TraversalFixture $profile;$mw.Navigation=Copy-TraversalFixture $nav;$mw.Body|Add-Member NoteProperty Velocity $velocity -Force;$mw.Dt=$dt;$mw.Acceleration=$md.Acceleration;$mw.PreviousTime=$clock.WallTime
    foreach($kv in @(@('MotionSession',1),@('RecoveryPolicy','MEASURED_BRAKE_V1'),@('GlobalDeadline',1000),@('ObservedVelocity',$velocity),@('NativeVelocityMatches',$true),@('NativeVelocityError',0),@('IssuedClock',$clock),@('Permission',$true),@('WaterDepth',-1),@('SupportAccepted',$true),@('OverlapClear',$true),@('StationaryReplan',$(if($snapshot){Copy-TraversalFixture $mi.StationaryReplan}else{$null})),@('Recovery',$recovery))){$mw|Add-Member NoteProperty $kv[0] $kv[1] -Force}
    if($snapshot){$mw.StationaryReplan.CurrentPending=$false}
    foreach($f in @($md,$mi,$mw)){
        foreach($c in @($f.Support.Collider,$f.Landing.Collider)+@($f.Support.Hits|ForEach-Object {$_.Collider})+@($f.Landing.Hits|ForEach-Object {$_.Collider})){
            foreach($kv in @(@('EntityType',''),@('Owner',''),@('RigidbodyInstance',$null),@('Kinematic',$null),@('MovingEntity',$false))){$c|Add-Member NoteProperty $kv[0] $kv[1] -Force}
        }
    }
    @($md,$mi,$mw)
}
function New-StationaryBrakePrefix($template,[double]$NativeRouteStart=0.7495){
    $origin=@([single]-0.1078125,0,0);$nav=Copy-TraversalFixture $template.Navigation;$leg=Copy-TraversalFixture $nav.RoutePlan[0]
    $leg.From=$origin;$leg.NativeCorners=@($origin,@(2,0,0));$leg.ActorCorners=$leg.NativeCorners;$nav.RouteFrom=$origin;$nav.Corners=$leg.NativeCorners;$nav.RoutePlan=@($leg)
    $baselineWall=$NativeRouteStart+0.0005
    $b=New-TraversalFrame 'CLOCK_BASELINE' 0 $baselineWall $origin $origin 0;$b.NativeResult='CLOCK_BASELINE';$b.Classification='CLEAR';$b.Profile=Copy-TraversalFixture $template.Profile;$b.Navigation=Copy-TraversalFixture $nav
    $b.Body|Add-Member NoteProperty Velocity @(0,0,0) -Force;$b.Support=$null;$bc=New-StationaryClock 1 $baselineWall;Set-StationaryFrameClock $b $bc $null;$b.WallDt=0.0005;$b.WallTelemetry.CallbackGap=0.0005
    foreach($kv in @(@('MotionSession',1),@('RecoveryPolicy','MEASURED_BRAKE_V1'),@('GlobalDeadline',1000),@('PosePrevious',$origin),@('PosePreviousTime',0.7495),@('ObservedVelocity',@(0,0,0)),@('StationaryReplan',$null))){$b|Add-Member NoteProperty $kv[0] $kv[1] -Force}
    if($PSBoundParameters.ContainsKey('NativeRouteStart')){$b.PosePreviousTime=[double][single]$NativeRouteStart}
    $rows=@($b);$position=$origin;$v=@(0,0,0);$clock=$bc
    for($i=1;$i -le 4;$i++){
        $speed=@(0.1875,0.375,0.5625,0.6)[$i-1];$to=@([single]([single]$position[0]+[single]($speed*0.0625)),0,0)
        if($i -eq 4){$to=@(0,0,0)}
        $issue=if($i -eq 1){New-StationaryClock ($clock.Sequence+1) ($clock.WallTime+0.0625)}else{$clock}
        $previous=if($i -eq 1){$bc}else{$rows[-2].Clock}
        $triplet=@(New-StationaryCheckedTriplet $position $to $v $i $issue $previous $nav $template.Profile)
        $rows+=$triplet;$last=$triplet[-1];$position=$to;$v=$last.Body.Velocity;$clock=$last.Clock
    }
    $old=@(New-RecoveryFrames);$meta=Copy-TraversalFixture $old[1].Recovery;$meta.StartSequence=$clock.Sequence;$meta.StartWall=$clock.WallTime;$meta.StartVelocity=@(for($j=0;$j -lt 3;$j++){[double]$v[$j]});$meta=Copy-TraversalFixture $meta
    $request=Copy-TraversalFixture $last;$request.Event='BRAKE_REQUESTED';$request.Reason='DIAGNOSTIC_PLANNED_REPLAN';$request|Add-Member NoteProperty Recovery $meta -Force;$rows+=,$request
    foreach($oldMd in @($old|Where-Object Event -ceq 'MOVE_DECISION')){
        $recovery=Copy-TraversalFixture $oldMd.Recovery;$recovery.StartSequence=$clock.Sequence-$recovery.Step+1;$recovery.StartWall=$meta.StartWall;$recovery.StartVelocity=$meta.StartVelocity
        $issue=$clock;$previous=$rows[-2].PreviousClock
        $triplet=@(New-StationaryCheckedTriplet $position $oldMd.Requested $v (4+$recovery.Step) $issue $previous $nav $template.Profile $null $recovery)
        foreach($f in $triplet){$f.MotionMode=$oldMd.MotionMode}
        $bi=Copy-TraversalFixture $triplet[1];$bi.Event='BRAKE_ISSUED'
        $rows+=@($triplet[0],$triplet[1],$bi,$triplet[2]);$bw=Copy-TraversalFixture $triplet[2];$bw.Event='BRAKE_WITNESSED';$rows+=,$bw
        $position=$triplet[2].Actual;$v=$triplet[2].Body.Velocity;$clock=$triplet[2].Clock;$last=$triplet[2]
    }
    $frozen=New-StationaryFrozenBody $last.Body
    foreach($f in $rows){if($f.Command -eq $last.Command -and $f.Event -in @('MOTION_WITNESS','BRAKE_WITNESSED')){$f|Add-Member NoteProperty AcceptedBrakeZeroBody (Copy-TraversalFixture $frozen) -Force}}
    $rest=Copy-TraversalFixture $last;$rest.Event='ACTUAL_REST';$rest|Add-Member NoteProperty RestAdmission (Copy-TraversalFixture @{Policy='EXACT_BRAKE_REST_V1';Session=1;Command=$last.Command;Step=$last.Recovery.Step;Attempt=1;
        Clock=$last.Clock;BrakeClock=$request.Clock;Actual=$last.Actual;RigidbodyPosition=$last.Body.RigidbodyPosition;Goal=@(2,0,0);BrakeOrigin=$meta.StartPosition;BrakeVelocity=$meta.StartVelocity;Floor=$last.Recovery.FloorCollider;
        Guard=(New-SeriesRestGuard $last 'REST_ACK');FrozenBody=$frozen}) -Force
    $rows+=,$rest;,$rows
}
function New-StationaryFixture([switch]$AfterBrake,[switch]$NoCommit,[switch]$WithWriter,[double]$NativeRouteStart=0.9995){
    $template=New-EpochBrakeFixture;$base=Copy-TraversalFixture $template.Prior;$base.Event='CLOCK_BASELINE';$base.Command=0;$base.MotionSession=1;$base.NativeResult='CLOCK_BASELINE';$base.Classification='CLEAR'
    $base.From=$base.Actual;$base.Requested=$base.Actual;$base.Body.Velocity=@(0,0,0);$base.Speed=0;$base|Add-Member NoteProperty ObservedVelocity @(0,0,0) -Force
    $base|Add-Member NoteProperty PosePrevious $base.Actual -Force;$base|Add-Member NoteProperty PosePreviousTime 0.5 -Force
    foreach($p in @(@('MaxWallStall',1.5),@('NativeMaximumDelta',0.125),@('NavRadius',0.5),@('NavHeight',1.8),@('NativeAdmissionPolicy','NATIVE_CURRENT_ROUTE_V1'),@('EpochRevalidationPolicy','SAME_COMMITTED_ROUTE_EPOCH_V2'),@('FinalVelocityPolicy','NATIVE_POST_SINK_VELOCITY_V1'),@('StationaryReplanPolicy','MEASURED_STATIONARY_NATIVE_V1'))){$base.Profile|Add-Member NoteProperty $p[0] $p[1] -Force}
    $base.Navigation=Copy-TraversalFixture $template.Transition.Navigation;$base.Navigation.EpochRevalidation=$null
    $leg=Copy-TraversalFixture $base.Navigation.RoutePlan[0];$leg.From=$base.Actual;$leg.NativeCorners=@($base.Actual,@(2,0,0));$leg.ActorCorners=$leg.NativeCorners
    $base.Navigation.RouteFrom=$base.Actual;$base.Navigation.Corners=$leg.NativeCorners;$base.Navigation.RoutePlan=@($leg)
    $base.Navigation.AdmissionTileChangeVersion=$base.Navigation.PlannedTileChangeVersion;$base.Navigation.AdmissionTileDataVersion=$base.Navigation.PlannedTileDataVersion
    $base.Navigation.TileChangeVersion=$base.Navigation.PlannedTileChangeVersion;$base.Navigation.TileDataVersion=$base.Navigation.PlannedTileDataVersion
    $base.Navigation.PendingTiles=$false
    $base|Add-Member NoteProperty Actuations 0 -Force;$base|Add-Member NoteProperty WriterCalled $false -Force;$base|Add-Member NoteProperty PendingDecision $null -Force
    $base|Add-Member NoteProperty UnobservedCommand $false -Force;$base|Add-Member NoteProperty GlobalDeadline 1000 -Force
    $base|Add-Member NoteProperty RecoveryPolicy 'MEASURED_BRAKE_V1' -Force
    foreach($kv in @(@('Permission',$true),@('WaterDepth',-1),@('SupportAccepted',$true),@('OverlapClear',$true))){$base|Add-Member NoteProperty $kv[0] $kv[1] -Force}
    $base.PosePreviousTime=0.9995;$base.PreviousTime=0.9995
    $baselineWall=1
    if($PSBoundParameters.ContainsKey('NativeRouteStart')){$base.PosePreviousTime=[double][single]$NativeRouteStart;$base.PreviousTime=$base.PosePreviousTime;$baselineWall=$NativeRouteStart+0.0005}
    $clock=New-StationaryClock 1 $baselineWall;Set-StationaryFrameClock $base $clock $null;$base.WallDt=0.0005;$base.WallTelemetry.CallbackGap=0.0005;$base|Add-Member NoteProperty StationaryReplan $null -Force
    $baseline=Copy-TraversalFixture $base;$baseline.Support=$null
    $rows=@($baseline);$entry='BASELINE_BEFORE_FIRST_WRITER';$rest=$null
    if($AfterBrake){
        $rows=if($PSBoundParameters.ContainsKey('NativeRouteStart')){New-StationaryBrakePrefix $base -NativeRouteStart $NativeRouteStart}else{New-StationaryBrakePrefix $base};$rest=$rows[-1].RestAdmission
        foreach($f in $rows){$f.Profile|Add-Member NoteProperty StationaryReplanPolicy 'MEASURED_STATIONARY_NATIVE_V1' -Force;$f|Add-Member NoteProperty GlobalDeadline 1000 -Force;$f|Add-Member NoteProperty StationaryReplan $null -Force
            foreach($kv in @(@('Permission',$true),@('WaterDepth',-1),@('SupportAccepted',$true),@('OverlapClear',$true))){$f|Add-Member NoteProperty $kv[0] $kv[1] -Force}}
        $base=Copy-TraversalFixture $rows[-1];$base|Add-Member NoteProperty Actuations $base.Command -Force;$clock=$base.Clock;$entry='ACKNOWLEDGED_BRAKE_REST'
        $zero=@($rows|Where-Object {$_.Event -ceq 'MOTION_WITNESS' -and $_.Speed -eq 0})[-1];$frozen=New-StationaryFrozenBody $zero.Body
        foreach($f in $rows){if($f.Command -eq $zero.Command -and $f.Event -in @('MOTION_WITNESS','BRAKE_WITNESSED','ACTUAL_REST')){$f|Add-Member NoteProperty AcceptedBrakeZeroBody (Copy-TraversalFixture $frozen) -Force}}
        $rest|Add-Member NoteProperty FrozenBody (Copy-TraversalFixture $frozen) -Force
        $rest.Guard|Add-Member NoteProperty AcceptedBrakeZeroBody (Copy-TraversalFixture $frozen) -Force;$rest.Guard|Add-Member NoteProperty CurrentFrozenBody (Copy-TraversalFixture $frozen) -Force
        foreach($kv in @(@('WriterCalled',$false),@('PendingDecision',$null),@('UnobservedCommand',$false))){$base|Add-Member NoteProperty $kv[0] $kv[1] -Force}
        foreach($p in @(@('MaxWallStall',1.5),@('NativeMaximumDelta',0.125),@('FinalVelocityPolicy','NATIVE_POST_SINK_VELOCITY_V1'))){foreach($f in $rows){$f.Profile|Add-Member NoteProperty $p[0] $p[1] -Force};$base.Profile|Add-Member NoteProperty $p[0] $p[1] -Force}
    }
    $entryClock=New-StationaryClock ($clock.Sequence+1) ($clock.WallTime+0.0625)
    if($AfterBrake){$entryClock=Copy-TraversalFixture $clock}
    $original=Copy-TraversalFixture $base.Navigation;$original.Mesh='7';$original.TileChangeVersion=12;$original.TileDataVersion=6;$original.PendingTiles=$true
    $routeStart=if($PSBoundParameters.ContainsKey('NativeRouteStart')){$NativeRouteStart}else{Get-TraversalStationaryNativeDouble $rows[0].PosePreviousTime 'synthetic native route start'}
    $s=Copy-TraversalFixture @{Policy='MEASURED_STATIONARY_NATIVE_V1';Id=$base.MotionSession;Entry=$entry;State='WAITING';Session=$base.MotionSession;Command=$base.Command;
        BaseActuations=$base.Actuations;CurrentCommand=$base.Command;CurrentActuations=$base.Actuations;CurrentPending=$false;RetryBefore=0;RetryAfter=1;
        StartedWall=($entryClock.WallTime+0.0001);RouteStartedWall=$routeStart;RouteDeadline=($routeStart+120);GlobalDeadline=1000;Deadline=($entryClock.WallTime+20.0001);MaxSeconds=20;MinStableSeconds=2;MaxSamples=512;
        Observation=0;Span=0;SpanRestarts=0;EntryClock=$entryClock;BaselineClock=$rows[0].Clock;BaselineBody=$rows[0].Body;BaselineFrozenBody=(New-StationaryFrozenBody $rows[0].Body);
        OriginalBody=$base.Body;FrozenBody=(New-StationaryFrozenBody $base.Body);Actual=$base.Actual;RigidbodyPosition=$base.Body.RigidbodyPosition;Goal=@(2,0,0);
        Floor=$base.Support.Collider;FloorCenter=$base.Support.Collider.BoundsCenter;FloorSize=$base.Support.Collider.BoundsSize;Anchor=$base.Support;OriginalNavigation=$original;
        OriginalBrakeRest=$rest;Ready=$null;Native=$null;LastGuard=$null;Plan=$null;FirstWriterCommand=0;Failure=$null}
    $s.Deadline=[Math]::Min(((Get-TraversalStationaryNativeDouble $s.StartedWall 'synthetic native start')+20),[Math]::Min((Get-TraversalStationaryNativeDouble $s.RouteDeadline 'synthetic native route deadline'),(Get-TraversalStationaryNativeDouble $s.GlobalDeadline 'synthetic native global deadline')))
    $start=Copy-TraversalFixture $base;Set-StationaryFrameClock $start $entryClock $clock
    if($AfterBrake){$start.PreviousClock=$base.PreviousClock;$start.WallDt=$base.WallDt;$start.WallTelemetry.CallbackGap=$base.WallDt}
    $start.Navigation=Copy-TraversalFixture $original;$start.Event='STATIONARY_REPLAN_STARTED';$start.NativeResult='STATIONARY_OBSERVATION'
    $s.LastGuard=New-StationaryPhysicalGuard $start 'ENTRY';$start.StationaryReplan=Copy-TraversalFixture $s;$rows+=,$start
    $first=$null;$firstNative=$null;$previous=$clock;$last=$null
    for($i=0;$i -le 33;$i++){
        $c=New-StationaryClock ($entryClock.Sequence+$i) ($entryClock.WallTime+$i*0.0625);$f=Copy-TraversalFixture $base;Set-StationaryFrameClock $f $c $previous
        if($AfterBrake -and $i -eq 0){$f.PreviousClock=$base.PreviousClock;$f.WallDt=$base.WallDt;$f.WallTelemetry.CallbackGap=$base.WallDt}
        $f.Event='STATIONARY_REPLAN_OBSERVATION';$f.NativeResult='STATIONARY_OBSERVATION';$f.MotionMode='STATIONARY_NATIVE_WAIT';$f.From=$f.Actual;$f.Requested=$f.Actual;$f.ObservedVelocity=@(0,0,0)
        $f.Navigation=Copy-TraversalFixture $original;$f.Navigation.PendingTiles=$i -eq 0
        $s.Observation=$i+1;$s.LastGuard=New-StationaryPhysicalGuard $f;$n=New-StationaryNative $c ($i -eq 0) 12 ($i -gt 1);$s.Native=$n
        if($i -eq 33){$n.CompletedWall=$c.WallTime+0.0021}
        $outcome=if($i -eq 0){'WAIT'}elseif($i -eq 1){'WINDOW_START'}elseif($i -eq 33){'READY'}else{'WINDOW_ADVANCE'}
        if($i -eq 1){$first=$c;$firstNative=Copy-TraversalFixture $n;$s.Span=1}
        if($outcome -ceq 'READY'){$s.State='READY';$s.Ready=Copy-TraversalFixture @{Clock=$c;FirstClock=$first;Observation=$s.Observation;Span=1;SpanRestarts=0;FirstNative=$firstNative;LastNative=$n}}
        $f|Add-Member NoteProperty StationaryObservation @{Outcome=$outcome;Reason=$n.Reason;Native=$n;Guard=$s.LastGuard} -Force
        $f.StationaryReplan=Copy-TraversalFixture $s;$rows+=,$f;$previous=$c;$last=$f
    }
    $ready=$last
    if(-not $NoCommit){
        $commit=Copy-TraversalFixture $ready;$commit.Event='STATIONARY_REPLAN_COMMITTED';$commit.NativeResult='ROUTE_REBOUND';$commit.WallTelemetry.ReadDelay=0.014
        $newNav=Copy-TraversalFixture $base.Navigation;$newLeg=Copy-TraversalFixture $newNav.RoutePlan[0];$newLeg.From=$base.Actual;$newLeg.NativeCorners=@($base.Actual,@(2,0,0));$newLeg.ActorCorners=$newLeg.NativeCorners
        $newLeg.ChangeBefore=12;$newLeg.ChangeAfter=12;$newLeg.DataBefore=6;$newLeg.DataAfter=6;$newLeg.Mesh='7';$newNav.Mesh='7';$newNav.PlannedMesh='7'
        $newNav.RoutePlan=@($newLeg);$newNav.RouteFrom=$base.Actual;$newNav.Corners=$newLeg.NativeCorners;$newNav.EpochRevalidation=$null
        foreach($key in @('PlannedTileChangeVersion','AdmissionTileChangeVersion','TileChangeVersion')){$newNav.$key=12};foreach($key in @('PlannedTileDataVersion','AdmissionTileDataVersion','TileDataVersion')){$newNav.$key=6}
        $s.State='COMMITTED';$s.LastGuard=New-StationaryCombinedGuard $ready 'READY_PRECOMMIT' 0.0105
        $s.Plan=Copy-TraversalFixture @{CallCount=1;NativeQueriesStarted=$true;Phase='COMMITTED_NATIVE';StartedWall=($ready.Clock.WallTime+0.005);CompletedWall=($ready.Clock.WallTime+0.011);Accepted=$true;Guard=$s.LastGuard;Navigation=$newNav}
        $s.Native=New-StationaryNative $ready.Clock $false 12 $true;$s.Native.StartedWall=$ready.Clock.WallTime+0.0115;$s.Native.CompletedWall=$ready.Clock.WallTime+0.012
        $commit.Navigation=$newNav;$commit.StationaryReplan=Copy-TraversalFixture $s;$rows+=,$commit
        if($AfterBrake){$rp=Copy-TraversalFixture $commit;$rp.Event='REPATH_AFTER_REST';$rp|Add-Member NoteProperty RestReplan @{Kind='STATIONARY_PLAN';Accepted=$true;Guard=$s.LastGuard;Time=$s.Plan.CompletedWall} -Force;$rows+=,$rp}
        $rp=Copy-TraversalFixture $commit;$rp.Event='REPATH';$rows+=,$rp
        if($WithWriter){
            $next=New-StationaryClock ($ready.Clock.Sequence+1) ($ready.Clock.WallTime+0.0625);$to=@([single]([single]$base.Actual[0]+[single]0.01171875),$base.Actual[1],$base.Actual[2])
            $rows+=@(New-StationaryCheckedTriplet $base.Actual $to @(0,0,0) ($base.Command+1) $next $ready.Clock $newNav $base.Profile $s)
        }
    }
    [pscustomobject]@{Frames=$rows;Baseline=$rows[0];Started=$start;Ready=$ready;Last=$rows[-1];Snapshot=$s;Base=$base}
}
# OFFLINE_ONLY grouped stationary FSM contracts, never native movement evidence.
$stationaryBase=New-StationaryFixture -WithWriter
Assert-TraversalFrames $stationaryBase.Frames '19' 'synthetic-world';Assert-TraversalRecovery $stationaryBase.Frames;Assert-TraversalEpochTransitions $stationaryBase.Frames
$stationaryBrake=New-StationaryFixture -AfterBrake -WithWriter
Assert-TraversalFrames $stationaryBrake.Frames '19' 'synthetic-world';Assert-TraversalRecovery $stationaryBrake.Frames;Assert-TraversalEpochTransitions $stationaryBrake.Frames
foreach($x in @($stationaryBase,$stationaryBrake)){$roundtrip=Copy-TraversalFixture $x.Frames;Assert-TraversalFrames $roundtrip '19' 'synthetic-world';Assert-TraversalRecovery $roundtrip;Assert-TraversalEpochTransitions $roundtrip}
foreach($case in @(
    @{Name='future Plan start';Change={param($x)foreach($f in $x.Frames){if($f.StationaryReplan.Plan){$f.StationaryReplan.Plan.StartedWall=$f.StationaryReplan.Plan.CompletedWall+100}}}},
    @{Name='frozen radius split from actual capsule';Change={param($x)foreach($f in $x.Frames){$s=$f.StationaryReplan;if($s){$s.FrozenBody.Radius=0.6;$s.BaselineFrozenBody.Radius=0.6;if($s.LastGuard.FrozenBody){$s.LastGuard.FrozenBody.Radius=0.6};if($s.Plan.Guard.Physical){$s.Plan.Guard.Physical.FrozenBody.Radius=0.6}}}}},
    @{Name='READY first clock rebased';Change={param($x)foreach($f in $x.Frames){if($f.StationaryReplan.Ready){$f.StationaryReplan.Ready.FirstClock.WallTime+=100}}}},
    @{Name='snapshot global differs from actual caller global';Change={param($x)foreach($f in $x.Frames){$f.GlobalDeadline=1.5}}},
    @{Name='snapshot goal redirected after actual baseline';Change={param($x)foreach($f in $x.Frames){$s=$f.StationaryReplan;if($s){$s.Goal=@(3,0,0);if($s.Plan){$s.Plan.Navigation.RouteTo=@(3,0,0)}}}}},
    @{Name='stationary start in future';Change={param($x)foreach($f in $x.Frames){$s=$f.StationaryReplan;if($s){$s.StartedWall+=100;$s.Deadline=[Math]::Min($s.StartedWall+20,[Math]::Min($s.RouteDeadline,$s.GlobalDeadline))}}}},
    @{Name='fabricated base native counters';Change={param($x)foreach($f in $x.Frames){$s=$f.StationaryReplan;if($s){$s.BaseActuations=999;$s.CurrentActuations=999}}}},
    @{Name='null measured stationary vector';Change={param($x)$x.Ready.StationaryReplan.LastGuard.MeasuredVelocity=$null}},
    @{Name='actual body native tiny velocity hidden by reported zero';Change={param($x)$x.Ready.StationaryReplan.LastGuard.Body.Velocity=@(0.00001,0,0)}},
    @{Name='native real object continuity false';Change={param($x)$x.Ready.StationaryObservation.Native.SameSpanObject=$false}},
    @{Name='new source policy downgraded';Change={param($x)$x.Frames[-1].Profile.PSObject.Properties.Remove('StationaryReplanPolicy')}},
    @{Name='entire source policy stripped while stationary shapes remain';Change={param($x)foreach($f in $x.Frames){$f.Profile.PSObject.Properties.Remove('StationaryReplanPolicy')}}},
    @{Name='all reported body metadata yaw rebased against actual frame body';Change={param($x)foreach($f in $x.Frames){$s=$f.StationaryReplan;if($s){foreach($body in @($s.BaselineBody,$s.OriginalBody,$s.LastGuard.Body,$s.Plan.Guard.Body,$s.Plan.Guard.Physical.Body)){if($body){$body.Rotation=@(0,0.70710677,0,0.70710677)}};foreach($body in @($s.FrozenBody,$s.BaselineFrozenBody,$s.LastGuard.FrozenBody,$s.Plan.Guard.Physical.FrozenBody)){if($body){$body.Rotation=@(0,0.70710677,0,0.70710677);$body.CapsuleRotation=$body.Rotation}}}}}}
)){$x=New-StationaryFixture -WithWriter;& $case.Change $x;Deny-TraversalFixture {Assert-TraversalStationarySeries $x.Frames} $case.Name}
foreach($case in @(
    @{Name='firstwriter opted out of required exact stationary body';Change={param($x)@($x.Frames|Where-Object Event -ceq 'MOVE_ISSUED')[0].FinalAdmission.StationaryBodyRequired=$false}},
    @{Name='firstwriter altered exact capsule scale';Change={param($x)@($x.Frames|Where-Object Event -ceq 'MOVE_ISSUED')[0].FinalAdmission.StationaryBody.Scale=@(1.00001,1,1)}},
    @{Name='firstwriter substituted a different committed native route';Change={param($x)foreach($f in $x.Frames|Where-Object {$_.Event -in @('MOVE_DECISION','MOVE_ISSUED','MOTION_WITNESS')}){$f.Navigation.PlannedMesh='99';$f.Navigation.Mesh='99';foreach($p in $f.Navigation.RoutePlan){$p.Mesh='99'};if($f.Navigation.Admission){$f.Navigation.Admission.Mesh='99'};if($f.FinalAdmission){$f.FinalAdmission.MeshBefore='99';$f.FinalAdmission.MeshAfter='99'}}}},
    @{Name='retained stationary Plan mutated after commit';Change={param($x)@($x.Frames|Where-Object Event -ceq 'MOVE_DECISION')[0].StationaryReplan.Plan.Navigation.PlannedMesh='99'}},
    @{Name='actual post-Plan native context differs from READY';Change={param($x)@($x.Frames|Where-Object Event -ceq 'STATIONARY_REPLAN_COMMITTED')[0].StationaryReplan.Native.Handle='99'}}
)){$x=New-StationaryFixture -WithWriter;& $case.Change $x;Deny-TraversalFixture {Assert-TraversalFrames $x.Frames '19' 'synthetic-world'} $case.Name}
$x=New-StationaryFixture -AfterBrake
foreach($f in $x.Frames){$s=$f.StationaryReplan;if($s){$s.FrozenBody.Rotation=@(0,0.70710677,0,0.70710677)}}
Deny-TraversalFixture {Assert-TraversalStationarySeries $x.Frames} 'post-zero-MW/REST sink yaw reanchored before ACK entry'
Write-Output 'PASS OFFLINE_ONLY C9 stationary: full checked baseline/physical-brake prefixes, native spans, actual immutable anchors, sole Plan, exact body and firstwriter guards'
$stationaryTerminalProposed=$true
function New-StationaryTerminalFixture([string]$kind='PROBE',[switch]$AfterBrake){
    $x=New-StationaryFixture -AfterBrake:$AfterBrake;$rows=@($x.Frames)
    foreach($row in @($rows|Where-Object Event -cne 'CLOCK_BASELINE')){foreach($p in @(@('Permission',$true),@('WaterDepth',-1),@('SupportAccepted',$true),@('OverlapClear',$true))){$row|Add-Member NoteProperty $p[0] $p[1] -Force}}
    foreach($row in $rows){foreach($p in @(@('MaxWallStall',1.5),@('NativeMaximumDelta',0.125),@('FinalVelocityPolicy','NATIVE_POST_SINK_VELOCITY_V1'))){$row.Profile|Add-Member NoteProperty $p[0] $p[1] -Force}}
    foreach($row in @($rows|Where-Object Event -ceq 'MOVE_ISSUED')){$row|Add-Member NoteProperty WriterCalled $true -Force}
    foreach($row in @($rows|Where-Object Event -ceq 'MOTION_WITNESS')){$mi=@($rows|Where-Object {$_.Event -ceq 'MOVE_ISSUED' -and $_.Command -eq $row.Command -and $_.MotionSession -eq $row.MotionSession}|Select-Object -Last 1);if($mi.Count){$row|Add-Member NoteProperty IssuedClock (Copy-TraversalFixture $mi[0].Clock) -Force;$row|Add-Member NoteProperty NativeVelocityMatches $true -Force}}
    $s=Copy-TraversalFixture $x.Snapshot
    $clock=New-StationaryClock ($x.Last.Clock.Sequence+1) ($x.Last.Clock.WallTime+0.0625)
    $f=Copy-TraversalFixture $x.Last;Set-StationaryFrameClock $f $clock $x.Last.Clock
    $f.Event='BLOCKED';$f.NativeResult='NOT_ISSUED';$f.Command=$s.Command+1;$f.Actuations=$s.BaseActuations
    foreach($p in @(@('WriterCalled',$false),@('PendingDecision',$null),@('UnobservedCommand',$false))){$f|Add-Member NoteProperty $p[0] $p[1] -Force}
    $f.Reason='CLOCK_AFTER_PROBE:CLOCK_STALE';$f.WallTelemetry.ReadDelay=0.22
    $s.State='TERMINAL';$s.Failure=Copy-TraversalFixture @{Reason=$f.Reason;Phase='BLOCK';Time=($clock.WallTime+0.21);Clock=$clock;Actual=$f.Actual;Body=$f.Body}
    $f|Add-Member NoteProperty StationaryReplan $s -Force
    $f|Add-Member NoteProperty NativeAdmissionFailure @{Reason=$f.Reason;CheckedWall=($clock.WallTime+0.21);NativeQueryStarted=$false} -Force
    $intent=$null
    if($kind -cin @('REJECTED','STOP_INTENT')){
        $intent=Copy-TraversalFixture $f;$intent.Event='MOVE_DECISION';$intent.NativeResult='PRECHECKED';$intent.Reason='CLEAR';$intent.MotionMode='BRAKE_HOLD';$intent.Speed=0;$intent.Acceleration=0;$intent.From=$intent.Actual;$intent.Requested=$intent.Actual;$intent.WallTelemetry.ReadDelay=0.006
        $intent.StationaryReplan=Copy-TraversalFixture $x.Snapshot;$intent|Add-Member NoteProperty DecisionPublishedWall ($clock.WallTime+0.005) -Force
        $intent.Navigation|Add-Member NoteProperty Admission @{CompletedWall=($clock.WallTime+0.004)} -Force
        $f.Event='MOVE_REJECTED';$f.Reason='NATIVE_ROUTE_CHANGED_BEFORE_WRITER';$f.StationaryReplan=Copy-TraversalFixture $x.Snapshot
        $f|Add-Member NoteProperty FinalAdmission @{Kind='POST_SINK_NATIVE_GUARD_V1';Accepted=$false;Error=$null;Sequence=$clock.Sequence;StartedWall=($clock.WallTime+0.2);CheckedWall=($clock.WallTime+0.205);From=$f.Actual;Requested=$f.Actual;
            VelocityPolicy='NATIVE_POST_SINK_VELOCITY_V1';ExpectedVelocity=@(0,0,0);NativeVelocity=@(0,0,0);ExpectedVelocityFinite=$true;NativeVelocityFinite=$true;VelocityError=0;VelocityMatches=$true;VelocityCheckedWall=($clock.WallTime+0.201);
            StationaryBodyRequired=$true;StationaryBodyMatched=$true;StationaryBody=$s.FrozenBody} -Force
        $s.Failure.Reason=$f.Reason;$block=Copy-TraversalFixture $f;$block.Event='BLOCKED';$block.StationaryReplan=Copy-TraversalFixture $s;$f.WallTelemetry.ReadDelay=0.207
        if($kind -ceq 'STOP_INTENT'){$f.Event='BLOCKED';$f.NativeResult='STOPPED';$f.Command=$s.Command;$f.WallTelemetry.ReadDelay=0.22;$s.Failure.Phase='STOP';$s.Failure.Reason='OWNER_CANCEL';$f.Reason='OWNER_CANCEL';$f.StationaryReplan=Copy-TraversalFixture $s;$f.PSObject.Properties.Remove('FinalAdmission');$rows+=@($intent,$f)}else{$rows+=@($intent,$f,$block)}
    }elseif($kind -cin @('HEARTBEAT','EARLY_STOP')){
        $rows=@($rows|Where-Object {$_.Event -ceq 'CLOCK_BASELINE' -or $_.Event -ceq 'STATIONARY_REPLAN_STARTED' -or ($_.Event -ceq 'STATIONARY_REPLAN_OBSERVATION' -and $_.StationaryObservation.Outcome -ceq 'WAIT')})
        $s=Copy-TraversalFixture $rows[-1].StationaryReplan;$s.State='TERMINAL';$s.Failure=Copy-TraversalFixture @{Reason='STATIONARY_REPLAN_DEADLINE';Phase='TIMEOUT_HEARTBEAT';Time=($s.Deadline+0.2);Clock=$null;Actual=$f.Actual;Body=$f.Body}
        $f.StationaryReplan=$s;$f.Clock=$null;$f.PreviousClock=$null;$f.WallTelemetry=$null;$f.Time=$s.Failure.Time+0.0001;$f.Command=$s.Command;$f.NativeResult='STOPPED';$f.Reason=$s.Failure.Reason;$rows+=,$f
        if($kind -ceq 'EARLY_STOP'){$s.Failure.Phase='STOP';$s.Failure.Time=$s.StartedWall+10;$s.Failure.Reason='HOME_PROGRESS_TIMEOUT';$f.Time=$s.Failure.Time+0.0001;$f.Reason=$s.Failure.Reason}
    }elseif($kind -ceq 'ENTRY'){
        $rows=@($rows|Where-Object {$_.Event -notlike 'STATIONARY_*' -and $_.Event -notin @('REPATH','REPATH_AFTER_REST')})
        $f=Copy-TraversalFixture $x.Started;$f.Event='BLOCKED';$f.NativeResult='NOT_ISSUED';$f.Reason='STATIONARY_REPLAN_ENTRY_CONTEXT_OR_CLOCK';$f.WallTelemetry.ReadDelay=0.22
        foreach($p in @(@('WriterCalled',$false),@('PendingDecision',$null),@('UnobservedCommand',$false))){$f|Add-Member NoteProperty $p[0] $p[1] -Force}
        $s=Copy-TraversalFixture $x.Started.StationaryReplan;$s.StartedWall=$f.Clock.WallTime+0.2;$s.Deadline=$s.StartedWall+20;$s.State='TERMINAL';$s.LastGuard=New-StationaryPhysicalGuard $f 'ENTRY' 0.21;$s.LastGuard.Accepted=$false;$s.LastGuard.ClockAccepted=$false
        $s.Failure=Copy-TraversalFixture @{Reason=$f.Reason;Phase='BLOCK';Time=($f.Clock.WallTime+0.215);Clock=$f.Clock;Actual=$f.Actual;Body=$f.Body};$f.StationaryReplan=$s;$rows+=,$f
    }elseif($kind -cin @('POST_PLAN','PLAN_REFUSED')){
        $rows=@($rows|Where-Object {$_.Event -notin @('STATIONARY_REPLAN_COMMITTED','REPATH_AFTER_REST','REPATH')});$f.Clock=Copy-TraversalFixture $x.Ready.Clock;$f.PreviousClock=Copy-TraversalFixture $x.Ready.PreviousClock;$f.WallDt=$x.Ready.WallDt;$f.Time=$f.Clock.WallTime;$f.Tick=$x.Ready.Tick;$f.Command=$s.Command
        $f.Reason='STATIONARY_COMMIT_CONTEXT_CHANGED';$s.Failure.Reason=$f.Reason;$s.Failure.Clock=$f.Clock;$s.Failure.Time=$f.Clock.WallTime+0.21;$f.StationaryReplan=$s;$rows+=,$f
        if($kind -ceq 'PLAN_REFUSED'){$f.Reason='STATIONARY_SINGLE_NATIVE_PLAN_REFUSED';$s.Failure.Reason=$f.Reason;$s.Plan.Accepted=$false;$s.Plan.Phase='NATIVE_QUERY';$s.Plan.CompletedWall=$f.Clock.WallTime+0.2;$s.Plan.Guard=New-StationaryCombinedGuard $x.Ready 'READY_PREQUERY' 0.006;$s.LastGuard=$s.Plan.Guard}
    }else{$rows+=,$f}
    $stop=Copy-TraversalFixture $rows[-1];$stop.Event='BLOCKED';$stop.NativeResult='STOPPED';$stop.Clock=$null;$stop.PreviousClock=$null;$stop.WallTelemetry=$null;$stop.Time=$s.Failure.Time+0.1;$stop.Command=$s.Command;$stop.Reason='RESULT_PARTIAL';$rows+=,$stop
    if($kind -cne 'PROBE'){foreach($row in @($rows|Where-Object {$_.Event -in @('MOVE_DECISION','MOVE_REJECTED','BLOCKED')})){$row.PSObject.Properties.Remove('NativeAdmissionFailure')}}
    $stop.PSObject.Properties.Remove('NativeAdmissionFailure')
    $witness=@($rows|Where-Object Event -ceq 'MOTION_WITNESS'|Select-Object -Last 1)[0]
    [pscustomobject]@{Kind=$kind;Frames=$rows;Failure=$f;Witness=$witness;Pending=$intent;Snapshot=$s;Nav=@{Status='PARTIAL';Traversal=@{Frames=$rows;Completed=$false;Scenes=@()}}}
}
$stationaryLatePositive=@((New-StationaryTerminalFixture),(New-StationaryTerminalFixture 'REJECTED'),(New-StationaryTerminalFixture 'HEARTBEAT'),(New-StationaryTerminalFixture 'ENTRY'),(New-StationaryTerminalFixture -AfterBrake),(New-StationaryTerminalFixture 'STOP_INTENT'),(New-StationaryTerminalFixture 'POST_PLAN'),(New-StationaryTerminalFixture 'PLAN_REFUSED'),(New-StationaryTerminalFixture 'ENTRY' -AfterBrake),(New-StationaryTerminalFixture 'EARLY_STOP'))
foreach($case in $stationaryLatePositive){
    try{if($stationaryTerminalProposed){Assert-TraversalStationaryTerminal $case.Failure $case.Witness $case.Pending $case.Frames '19';Assert-TraversalStationaryTerminalResult $case.Nav}
        else{Assert-TraversalTerminalRefusal $case.Failure $case.Witness $case.Pending $case.Frames[-1] $case.Frames '19'}}catch{throw ('Stationary terminal '+$case.Kind+' '+$case.Snapshot.Entry+': '+$_.Exception.Message)}
}
Write-Output ('PASS stationary terminal source shapes='+$stationaryLatePositive.Count)
if(-not $stationaryTerminalProposed){return}
$changed=New-StationaryTerminalFixture;foreach($row in @($changed.Frames|Where-Object {$null -ne $_.StationaryReplan.Failure})){$row.StationaryReplan.Failure.Body.Velocity=@('NaN',0,0);$row.StationaryReplan.Failure.Body.Radius=0.45};Assert-TraversalStationaryTerminal $changed.Failure $changed.Witness $null $changed.Frames '19'
$stationaryDenied=0
foreach($mutation in @(
    {param($x)$x.Snapshot.CurrentPending=$true},
    {param($x)$x.Snapshot.CurrentActuations++},
    {param($x)$x.Snapshot.FirstWriterCommand=$x.Snapshot.Command+1},
    {param($x)$x.Snapshot.Deadline+=1},
    {param($x)$x.Snapshot.Observation=513},
    {param($x)$x.Snapshot.OriginalBody.Velocity=@(0.00001,0,0)},
    {param($x)$x.Frames=@($x.Frames|Where-Object Event -cne 'CLOCK_BASELINE')},
    {param($x)$x.Snapshot.Failure.Time+=1},
    {param($x)$x.Snapshot.Ready.LastNative.SameSpanObject=$false},
    {param($x)$x.Snapshot.Plan.StartedWall=$x.Snapshot.Plan.CompletedWall+100},
    {param($x)foreach($r in @($x.Frames|Where-Object {$null -ne $_.StationaryReplan})){$r.StationaryReplan.FrozenBody.Radius=0.6;$r.StationaryReplan.BaselineFrozenBody.Radius=0.6}},
    {param($x)$x.Frames=@($x.Frames|Where-Object {$_.Event -cne 'STATIONARY_REPLAN_OBSERVATION' -or $_.StationaryObservation.Outcome -cne 'READY'})},
    {param($x)$new=Copy-TraversalFixture $x.Failure;$new.Event='MOVE_ISSUED';$x.Frames=@($x.Frames[0..($x.Frames.Count-2)])+@($new,$x.Frames[-1])},
    {param($x)$new=Copy-TraversalFixture $x.Failure;$new.Event='REPATH';$x.Frames=@($x.Frames[0..($x.Frames.Count-2)])+@($new,$x.Frames[-1])}
)){$x=New-StationaryTerminalFixture;& $mutation $x;Deny-TraversalFixture {Assert-TraversalStationaryTerminal $x.Failure $x.Witness $null $x.Frames '19'} 'invalid stationary no-writer terminal proof';$stationaryDenied++}
foreach($mutation in @({param($x)$x.Pending.WallTelemetry.ReadDelay=0.2},{param($x)$x.Failure.FinalAdmission.Accepted=$true})){$x=New-StationaryTerminalFixture 'REJECTED';& $mutation $x;Deny-TraversalFixture {Assert-TraversalStationaryTerminal $x.Failure $x.Witness $x.Pending $x.Frames '19'} 'late intent or accepted writer disguised as rejection';$stationaryDenied++}
$x=New-StationaryTerminalFixture 'REJECTED';$foreign=Copy-TraversalFixture $x.Pending;Deny-TraversalFixture {Assert-TraversalStationaryTerminal $x.Failure $x.Witness $foreign $x.Frames '19'} 'unrelated pending intent';$stationaryDenied++
$x=New-StationaryTerminalFixture 'ENTRY';$x.Snapshot.LastGuard.Accepted=$true;Deny-TraversalFixture {Assert-TraversalStationaryTerminal $x.Failure $x.Witness $null $x.Frames '19'} 'failed ENTRY invented accepted window';$stationaryDenied++
$x=New-StationaryTerminalFixture 'HEARTBEAT';$x.Snapshot.Failure.Time=$x.Snapshot.Deadline-0.1;Deny-TraversalFixture {Assert-TraversalStationaryTerminal $x.Failure $x.Witness $null $x.Frames '19'} 'heartbeat invented expired deadline';$stationaryDenied++
$x=New-StationaryTerminalFixture 'HEARTBEAT';foreach($r in @($x.Frames|Where-Object {$null -ne $_.StationaryReplan.Failure})){$r.StationaryReplan.Failure.Time+=100};Deny-TraversalFixture {Assert-TraversalStationaryTerminal $x.Failure $x.Witness $null $x.Frames '19'} 'coherent failure moved after actual Stop';Deny-TraversalFixture {Assert-TraversalStationaryTerminalResult $x.Nav} 'coherent result cutoff moved after actual Stop';$stationaryDenied+=2
$x=New-StationaryTerminalFixture -AfterBrake;$x.Frames=@($x.Frames|Where-Object Event -cne 'MOVE_ISSUED');Deny-TraversalFixture {Assert-TraversalStationaryTerminal $x.Failure $x.Witness $null $x.Frames '19'} 'ACK rest borrowed an unissued zero witness';$stationaryDenied++
$history=New-StationaryTerminalFixture;$history.Nav.FirstHome=@{Operations=@(@{Time=1});NativePlacements=@(@{Time=1});Upkeep=@{Historical=$true};Portal=@{Historical=$true}};$history.Nav.Traversal.BuildPlans=@(@{Time=1});$history.Nav.Traversal.DestinationWindows=@(@{Contract=@{Start=1}});Assert-TraversalStationaryTerminalResult $history.Nav
foreach($mutation in @(
    {param($x)$x.Nav.Status='GREEN'},
    {param($x)$x.Nav.Traversal.Completed=$true},
    {param($x)$x.Nav.FirstHome=@{Operations=@(@{Time=$x.Snapshot.Failure.Time+1})}},
    {param($x)$x.Nav.Traversal.BuildPlans=@(@{Time=$x.Failure.Clock.WallTime+0.00000001})},
    {param($x)$x.Nav.Traversal.DestinationWindows=@(@{Contract=@{Start=$x.Failure.Clock.WallTime+0.00000001}})},
    {param($x)$x.Nav.Traversal.Scenes=@(@{Status='PASSED';FramesTo=$x.Frames.Count})}
)){$x=New-StationaryTerminalFixture;& $mutation $x;Deny-TraversalFixture {Assert-TraversalStationaryTerminalResult $x.Nav} 'stationary refusal claimed future physical/product success';$stationaryDenied++}
Write-Output ('PASS stationary terminal grouped negatives='+$stationaryDenied+' changed failure body/native unknown preserved')
# OFFLINE_ONLY: native Double JSON spellings must retain binary64 values in PS5 and PS7.
$stationaryNativeNumbers=ConvertFrom-Json '{"RouteStartedWall":273.18282750345804,"RouteDeadline":393.18282750345804,"StartedWall":274.31337020345808,"Deadline":294.31337020345808,"GlobalDeadline":1168.1309814453125}'
$stationaryNumberReader=if(Get-Command Get-TraversalStationaryNativeDouble -ErrorAction SilentlyContinue){'Get-TraversalStationaryNativeDouble'}else{'Get-TraversalNumber'}
$stationaryRoute=& $stationaryNumberReader $stationaryNativeNumbers.RouteStartedWall 'source Double route start'
$stationaryRouteEnd=& $stationaryNumberReader $stationaryNativeNumbers.RouteDeadline 'source Double route deadline'
$stationaryStart=& $stationaryNumberReader $stationaryNativeNumbers.StartedWall 'source Double start'
$stationaryEnd=& $stationaryNumberReader $stationaryNativeNumbers.Deadline 'source Double deadline'
if($stationaryRouteEnd -ne $stationaryRoute+120 -or $stationaryEnd -ne $stationaryStart+20){throw 'C9 source native Double arithmetic changed during JSON replay'}
foreach($literal in @(
    '{"Start":390.31337020345808,"RouteEnd":393.18282750345804,"Global":1168.1309814453125,"Deadline":393.18282750345804}',
    '{"Start":274.31337020345808,"RouteEnd":393.18282750345804,"Global":280.12345678901232,"Deadline":280.12345678901232}'
)){
    $bounds=ConvertFrom-Json $literal;$begin=& $stationaryNumberReader $bounds.Start 'native start';$routeEnd=& $stationaryNumberReader $bounds.RouteEnd 'native route end'
    $globalEnd=& $stationaryNumberReader $bounds.Global 'native global';$bounded=& $stationaryNumberReader $bounds.Deadline 'native minimum'
    if($bounded -ne [Math]::Min($begin+20,[Math]::Min($routeEnd,$globalEnd))){throw 'C9 native Double route/global minimum changed during JSON replay'}
}
$stationaryClockNumbers=ConvertFrom-Json '{"First":274.30427050736961,"Next":274.36677050736961,"Last":276.30427050736961}'
$stationaryFirst=& $stationaryNumberReader $stationaryClockNumbers.First 'native unscaled span start'
$stationaryNext=& $stationaryNumberReader $stationaryClockNumbers.Next 'native unscaled next'
$stationaryLast=& $stationaryNumberReader $stationaryClockNumbers.Last 'native unscaled span end'
if($stationaryNext-$stationaryFirst -ne 0.0625 -or $stationaryLast-$stationaryFirst -ne 2){throw 'C9 native Double strict fixed/native span changed during JSON replay'}
foreach($value in @($null,$true,'273.18282750345804',@(273.1),[double]::NaN,[double]::PositiveInfinity)){
    Deny-TraversalFixture {& $stationaryNumberReader $value 'invalid native Double'} 'invalid typed C9 Double'
}
foreach($route in @(273.18282750345804,274.31337020345808)){
    $x=New-StationaryFixture -NativeRouteStart $route -WithWriter
    Assert-TraversalFrames $x.Frames '19' 'synthetic-world';Assert-TraversalRecovery $x.Frames;Assert-TraversalEpochTransitions $x.Frames
    $roundtrip=Copy-TraversalFixture $x.Frames
    Assert-TraversalFrames $roundtrip '19' 'synthetic-world';Assert-TraversalRecovery $roundtrip;Assert-TraversalEpochTransitions $roundtrip
}
$x=New-StationaryFixture -AfterBrake -NativeRouteStart 273.18282750345804 -WithWriter
Assert-TraversalFrames $x.Frames '19' 'synthetic-world';Assert-TraversalRecovery $x.Frames;Assert-TraversalEpochTransitions $x.Frames
foreach($case in @(
    @{Name='one binary64 ULP route deadline';Field='RouteDeadline'},
    @{Name='one binary64 ULP stationary deadline';Field='Deadline'},
    @{Name='one binary64 ULP captured global';Field='GlobalDeadline'},
    @{Name='one binary64 ULP stationary start';Field='StartedWall'}
)){
    $x=New-StationaryFixture -NativeRouteStart 273.18282750345804 -WithWriter
    foreach($f in $x.Frames){$s=$f.StationaryReplan;if($s){$v=& $stationaryNumberReader $s.($case.Field) 'mutation source Double';$s.($case.Field)=[BitConverter]::Int64BitsToDouble([BitConverter]::DoubleToInt64Bits($v)+1)}}
    Deny-TraversalFixture {Assert-TraversalStationarySeries $x.Frames} $case.Name
}
$x=New-StationaryFixture -NativeRouteStart 273.18282750345804 -WithWriter
foreach($f in $x.Frames){if($f.StationaryReplan){$f.StationaryReplan.Goal=@(3,0,0)}}
Deny-TraversalFixture {Assert-TraversalStationarySeries $x.Frames} 'source Double correction cannot redirect the actual goal'
Write-Output 'PASS OFFLINE_ONLY C9 native Double: exact JSON arithmetic, full prefixes, repeated JSON replay, strict ULP/goal/type rejection'
if($RecoveryOnly){return}
# OFFLINE_ONLY: current native route certificate is mandatory, never hide global pending.
$ready=New-TraversalFrame 'MOVE_DECISION' 1 1 @(0,0,0) @(0.009,0.002,0) 0
$ready.Schema=2;$ready|Add-Member NoteProperty Clock @{Sequence=41;WallTime=1.0}
$ready.Navigation.PendingTiles=$true
$ready.Navigation|Add-Member NoteProperty AdmissionPolicy 'NATIVE_CURRENT_ROUTE_V1'
$ready.Navigation|Add-Member NoteProperty DefaultBuilt $true
$ready.Navigation|Add-Member NoteProperty RoutePolys @('101')
$certificate=Copy-TraversalFixture @{Kind='NATIVE_CURRENT_ROUTE_V1';From=$ready.From;To=$ready.Navigation.RouteTo;Requested=$ready.Requested;Sequence=41;StartedWall=1.001;CompletedWall=1.002;CheckedWall=1.003;
    Mesh=$ready.Navigation.Mesh;ChangeBefore=1;ChangeAfter=1;DataBefore=1;DataAfter=1;FilterBefore=$false;FilterAfter=$false;
    NativeCalculated=$true;ActorCalculated=$true;NativeStatus='PathComplete';ActorStatus='PathComplete';Capacity=256;
    NativeCorners=$ready.Navigation.Corners;ActorCorners=$ready.Navigation.Corners;NativePolys=@(@{Ref='101';Valid=$true});ActorPolys=@('101');RoutePolys=@(@{Ref='101';Valid=$true});
    GlobalPendingBefore=$true;GlobalPendingAfter=$true}
$ready.Navigation|Add-Member NoteProperty Admission $certificate
$ready.Navigation|Add-Member NoteProperty RouteFilter $false
$ready.Navigation|Add-Member NoteProperty RoutePlan @((Copy-TraversalFixture @{Kind='DEFAULT_NATIVE_PATH_V1';Mesh=$ready.Navigation.Mesh;From=$ready.Navigation.RouteFrom;To=$ready.Navigation.RouteTo;Filter=$false;
    ChangeBefore=1;ChangeAfter=1;DataBefore=1;DataAfter=1;NativeCalculated=$true;ActorCalculated=$true;NativeStatus='PathComplete';ActorStatus='PathComplete';Capacity=256;
    NativeCorners=$ready.Navigation.Corners;ActorCorners=$ready.Navigation.Corners;NativePolys=@('101');ActorPolys=@('101')}))
$ready|Add-Member NoteProperty DecisionPublishedWall 1.0025
Assert-TraversalNavigation $ready -Decision
foreach($mutation in @(
    @{Name='global pending without fresh native proof';Change={param($x)$x.Navigation.Admission=$null}},
    @{Name='stale callback certificate';Change={param($x)$x.Navigation.Admission.Sequence=40}},
    @{Name='nonactual native query origin';Change={param($x)$x.Navigation.Admission.From=@(1,0,0)}},
    @{Name='native invalid poly ref';Change={param($x)$x.Navigation.Admission.NativePolys[0].Valid=$false}},
    @{Name='native mesh epoch changed during check';Change={param($x)$x.Navigation.Admission.DataAfter=2}},
    @{Name='actor/default native path provenance mismatch';Change={param($x)$x.Navigation.Admission.ActorPolys[0]='102'}},
    @{Name='fresh path incomplete';Change={param($x)$x.Navigation.Admission.NativeStatus='PathPartial'}},
    @{Name='changed native door filter';Change={param($x)$x.Navigation.Admission.FilterAfter=$true}},
    @{Name='expired native proof wall budget';Change={param($x)$x.Navigation.Admission.CheckedWall=1.2}},
    @{Name='numeric native success is not a bool';Change={param($x)$x.Navigation.Admission.NativeCalculated=1}},
    @{Name='saturated native poly buffer';Change={param($x)$x.Navigation.Admission.NativePolys=@($x.Navigation.Admission.NativePolys[0])*256;$x.Navigation.Admission.ActorPolys=@('101')*256}},
    @{Name='issued segment deviates from fresh native first leg';Change={param($x)$x.Navigation.Admission.NativeCorners[1]=@(0,0.002,0.009);$x.Navigation.Admission.ActorCorners[1]=@(0,0.002,0.009)}}
)){$x=Copy-TraversalFixture $ready;& $mutation.Change $x;Deny-TraversalFixture {Assert-TraversalNavigation $x -Decision} $mutation.Name}
Write-Output 'PASS OFFLINE_ONLY019 readiness: global pending visible, native current-pose dual path/poly/epoch/filter/segment admission; uncertainty rejected'
if(-not (Get-Command Assert-TraversalFinalIssue -CommandType Function -ErrorAction SilentlyContinue)){throw 'Missing post-sink issue/cancel contract'}
$issue=Copy-TraversalFixture $ready;$issue.Event='MOVE_ISSUED';$issue.NativeResult='ISSUED'
$issue|Add-Member NoteProperty Actuations 1;$issue|Add-Member NoteProperty WriterCalled $true
$issue|Add-Member NoteProperty FinalAdmission (Copy-TraversalFixture @{Kind='POST_SINK_NATIVE_GUARD_V1';Accepted=$true;Error=$null;Sequence=41;StartedWall=1.003;CheckedWall=1.004;
    From=$ready.Actual;Requested=$ready.Requested;MeshBefore=$ready.Navigation.Mesh;MeshAfter=$ready.Navigation.Mesh;ChangeBefore=1;ChangeAfter=1;DataBefore=1;DataAfter=1;
    FilterBefore=$false;FilterAfter=$false;DefaultBuilt=$true;OnNavMesh=$true;ProfileMatches=$true;BodyValid=$true;ClockAccepted=$true;ControlActive=$true;
    RoutePolys=@(@{Ref='101';Valid=$true});NativePolys=@(@{Ref='101';Valid=$true});GlobalPendingBefore=$true;GlobalPendingAfter=$true})
Assert-TraversalFinalIssue $issue $ready 0
$cancelled=Copy-TraversalFixture $issue;$cancelled.Event='MOVE_REJECTED';$cancelled.NativeResult='NOT_ISSUED';$cancelled.WriterCalled=$false;$cancelled.Actuations=0
$cancelled.FinalAdmission.Accepted=$false;$cancelled.FinalAdmission.FilterAfter=$true
Assert-TraversalFinalIssue $cancelled $ready 0 -Rejected
Deny-TraversalFixture {$x=Copy-TraversalFixture $issue;$x.FinalAdmission.DataAfter=2;Assert-TraversalFinalIssue $x $ready 0} 'writer admitted changed epoch after sink'
Deny-TraversalFixture {$x=Copy-TraversalFixture $cancelled;$x.WriterCalled=$true;Assert-TraversalFinalIssue $x $ready 0 -Rejected} 'cancelled intent actually called writer'
if(-not (Get-Command Assert-TraversalNativeRoutePlan -CommandType Function -ErrorAction SilentlyContinue)){throw 'Missing native composite route provenance contract'}
$composite=Copy-TraversalFixture $ready.Navigation
$one=Copy-TraversalFixture $composite.RoutePlan[0];$one.From=@(0,0,0);$one.To=@(1,0,0);$one.NativeCorners=@(@(0,0,0),@(1,0,0));$one.ActorCorners=@(@(0,0,0),@(1,0,0));$one.NativePolys=@('101','102');$one.ActorPolys=@('101','102')
$two=Copy-TraversalFixture $one;$two.From=@(1,0,0);$two.To=@(1,0,1);$two.NativeCorners=@(@(1,0,0),@(1,0,1));$two.ActorCorners=@(@(1,0,0),@(1,0,1));$two.NativePolys=@('102','103');$two.ActorPolys=@('102','103')
$composite.RoutePlan=@($one,$two);$composite.RouteFrom=@(0,0,0);$composite.RouteTo=@(1,0,1);$composite.Corners=@(@(0,0,0),@(1,0,0),@(1,0,1));$composite.RoutePolys=@('101','102','102','103')
Assert-TraversalNativeRoutePlan $composite
Deny-TraversalFixture {$x=Copy-TraversalFixture $composite;$x.RoutePolys=@('101');Assert-TraversalNativeRoutePlan $x} 'composite corners retain old path refs'
Deny-TraversalFixture {$x=Copy-TraversalFixture $composite;$x.RoutePlan[1].NativePolys[0]='104';$x.RoutePlan[1].ActorPolys[0]='104';$x.RoutePolys[2]='104';Assert-TraversalNativeRoutePlan $x} 'native legs have no matching polygon join'
if(-not (Get-Command Assert-TraversalStationaryWindow -CommandType Function -ErrorAction SilentlyContinue)){throw 'Missing bounded stationary-clock window contract'}
$warmBody=Copy-TraversalFixture @{Actor='19';Capsules=@(@{Instance=10;Radius=0.5;Height=1.8;Center=@(0,0.9,0);Direction=1;Scale=@(1,1,1);Up=@(0,1,0);Enabled=$true;Trigger=$false;Layer=17;Rigidbody=11});
    Rigidbody=11;Kinematic=$true;Gravity=$false;DetectCollisions=$true;CollisionMode='Discrete';Colliders=@(10);AgentStopped=$true;AgentUpdatePosition=$false;AgentUpdateRotation=$false}
$window=Copy-TraversalFixture @{WarmupPolicy='STATIONARY_CLOCK_WINDOW_V1';WarmupContract=@{Start=0;Position=@(0,0,0);Body=$warmBody;NativeMaximumDelta=0.125;MaxSeconds=20;MinWindowSeconds=2;MaxSamples=512};WarmupObservations=@();
    Warmup=@{Schema=2;Mode='STATIONARY_READ_ONLY';Start=0;End=2.0625;StableSince=0.0625;Samples=33;Resets=0;MotorResets=0;WindowRestarts=0;Position=@(0,0,0)}}
for($i=0;$i -le 33;$i++){
    $time=$i*0.0625;$delta=if($i -eq 0){0.2}else{0.0625}
    $clock=@{WallTime=$time;FixedTime=$time;FixedUnscaledTime=$time;Delta=$delta;UnscaledDelta=$delta;MaximumDelta=0.125;TimeScale=1;InFixedStep=$true;PhysicsMode='FixedUpdate';Sequence=($i+1);Frame=(300+$i)}
    $outcome=if($i -eq 0){'WAIT'}elseif($i -eq 1){'WINDOW_START'}elseif($i -eq 33){'READY'}else{'WINDOW_ADVANCE'}
    $window.WarmupObservations+=,(Copy-TraversalFixture @{Observation=($i+1);ObservedWall=$time;Clock=$clock;LiveMaximumDelta=0.125;Position=@(0,0,0);Velocity=@(0,0,0);Body=$warmBody;MotorActuations=0;MotorActive=$false;MotorBlocked=$false;Outcome=$outcome})
}
$window|Add-Member NoteProperty WarmupObservationCount 34
$window.Warmup|Add-Member NoteProperty TotalObservations 34
$window.Warmup|Add-Member NoteProperty LastClock (Copy-TraversalFixture $window.WarmupObservations[-1].Clock)
Assert-TraversalStationaryWindow $window '19'
$startupWithGoalPolicy=Copy-TraversalFixture $window
$startupWithGoalPolicy|Add-Member NoteProperty DestinationReadinessPolicy 'NATIVE_NEW_GOAL_READINESS_V1'
Assert-TraversalStationaryWindow $startupWithGoalPolicy '19'
Deny-TraversalFixture {$x=Copy-TraversalFixture $window;$x.WarmupObservations=@($x.WarmupObservations|Select-Object -Skip 1);Assert-TraversalStationaryWindow $x '19'} 'readiness journal omits initial rejected clocksample'
Deny-TraversalFixture {$x=Copy-TraversalFixture $window;$x.Warmup.LastClock.FixedTime-=0.0625;Assert-TraversalStationaryWindow $x '19'} 'ready receipt substitutes another final native clock'
Deny-TraversalFixture {$x=Copy-TraversalFixture $window;$past=New-TraversalFrames;foreach($f in $past){$f.Profile|Add-Member NoteProperty NativeMaximumDelta 0.125};$x|Add-Member NoteProperty Frames $past;$x|Add-Member NoteProperty Actuations 2;Assert-TraversalStationaryWindow $x '19'} 'physical movement predates stationary readiness'
Deny-TraversalFixture {$x=Copy-TraversalFixture $window;$x.WarmupObservations[10].Position[0]=0.002;Assert-TraversalStationaryWindow $x '19'} 'warmup silently rebases a drifting body'
Deny-TraversalFixture {$x=Copy-TraversalFixture $window;$x.WarmupObservations[10].MotorActuations=1;Assert-TraversalStationaryWindow $x '19'} 'readiness observation issued movement'
Deny-TraversalFixture {$x=Copy-TraversalFixture $window;$x.WarmupObservations[-1].ObservedWall=21;Assert-TraversalStationaryWindow $x '19'} 'warmup resets total twenty-second deadline'
Deny-TraversalFixture {$x=Copy-TraversalFixture $window;$x.WarmupObservations[10].Clock.MaximumDelta=0.25;$x.WarmupObservations[10].LiveMaximumDelta=0.25;Assert-TraversalStationaryWindow $x '19'} 'warmup silently accepts changed captured native clock profile'
$slow=Copy-TraversalFixture $window;$slow.WarmupObservations=@($slow.WarmupObservations[1],$slow.WarmupObservations[2],$slow.WarmupObservations[3])
for($i=0;$i -lt 3;$i++){$slow.WarmupObservations[$i].ObservedWall=1+$i;$slow.WarmupObservations[$i].Clock.WallTime=1+$i}
$slow.WarmupObservations[-1].Outcome='READY'
Deny-TraversalFixture {Assert-TraversalStationaryWindow $slow '19'} 'wall-only window lacks two seconds of native physics'
Write-Output 'PASS OFFLINE_ONLY019 stationary window: invalid samples wait without movement, strict native/wall span, immutable body/profile and original total deadline'
# OFFLINE_ONLY: qualified caller clock/intent receipts; no synthetic physical PASS.
function New-DestinationWindowFixture([switch]$PriorRest){
    $copy=Copy-TraversalFixture $window;$base=if($PriorRest){1}else{0};$start=3.0
    foreach($o in $copy.WarmupObservations){
        $o.ObservedWall+=$start;$o.Clock.WallTime+=$start;$o.Clock.FixedTime+=$start;$o.Clock.FixedUnscaledTime+=$start;$o.Clock.Sequence+=100;$o.Clock.Frame+=100;$o.MotorActuations=$base
    }
    $copy.WarmupObservations[0].Clock.Delta=0.0625;$copy.WarmupObservations[0].Clock.UnscaledDelta=0.065741
    $receipt=Copy-TraversalFixture $copy.Warmup;$receipt.Start+=$start;$receipt.End+=$start;$receipt.StableSince+=$start;$receipt.LastClock=Copy-TraversalFixture $copy.WarmupObservations[-1].Clock
    $handoff=Copy-TraversalFixture $receipt.LastClock;$handoff.WallTime+=0.002
    $frames=@();$prior=$null
    if($PriorRest){
        $frames+=,[pscustomobject]@{Event='MOVE_ISSUED';Time=2.4;Command=1;Stage='PRIOR';Clock=@{WallTime=2.4}}
        $priorClock=@{Schema=2;WallTime=2.5;FixedTime=2.5;FixedUnscaledTime=2.5;Delta=0.0625;UnscaledDelta=0.0625;TimeScale=1;MaximumDelta=0.125;Sequence=100;Frame=399;InFixedStep=$true;PhysicsMode='FixedUpdate'}
        $frames+=,[pscustomobject]@{Event='MOTION_WITNESS';NativeResult='OBSERVED';Time=2.5;Command=1;Stage='PRIOR';Speed=0;Actual=@(0,0,0);Body=@{Velocity=@(0,0,0)};Clock=$priorClock}
        $frames+=,[pscustomobject]@{Event='ARRIVED';Time=2.5;Clock=@{WallTime=2.5}}
        $prior=@{Command=1;Stage='PRIOR';Time=2.5;Clock=$priorClock;Actual=@(0,0,0);Speed=0;NativeVelocity=@(0,0,0)}
    }
    $frameClock=Copy-TraversalFixture $handoff;$frameClock|Add-Member NoteProperty Schema 2 -Force
    $frames+=,[pscustomobject]@{Event='CLOCK_BASELINE';Stage='HOME_SITE';Time=$handoff.WallTime;Clock=$frameClock;Actual=@(0,0,0);WallTelemetry=@{ReadDelay=0.0003};Navigation=@{RouteTo=@(4,0,0)}}
    Copy-TraversalFixture @{Actor=@{NetId='19'};Status='PARTIAL';Samples=@(@{Time=0;ActorNetId='19'});FirstHome=@{Schedule=@{SmokeSeconds=900};NativePlacements=@();Operations=@()};Traversal=@{Completed=$false;SequencePolicy='G4_PRIORITY_V1';DestinationPolicy='STATIONARY_DESTINATION_WINDOW_V1';Frames=$frames;
        WarmupContract=$window.WarmupContract;Warmup=$window.Warmup;DestinationWindows=@(@{Id=1;Stage='HOME_SITE';Goal=@(4,0,0);BaseActuations=$base;Outcome='ADMITTED';EndWall=($handoff.WallTime+0.0005);Reason=$null;SetDestinationCalls=1;
            Contract=@{Start=$start;Position=@(0,0,0);Body=$warmBody;NativeMaximumDelta=0.125;MaxSeconds=20;MinWindowSeconds=2;MaxSamples=512;GlobalDeadline=900;Goal=@(4,0,0);Stage='HOME_SITE';BaseActuations=$base;
                IssuedCommands=$base;AcceptedWitnesses=$base;MotorActive=$false;MotorBlocked=$false;MotorArrived=[bool]$PriorRest;Velocity=@(0,0,0);PriorRest=$prior};Observations=$copy.WarmupObservations;ObservationCount=34;Receipt=$receipt;
            Commit=@{StartedWall=($receipt.End+0.0005);CompletedWall=($receipt.End+0.001);Accepted=$true};
            Handoff=@{Accepted=$true;ReadyClock=$receipt.LastClock;Clock=$handoff;CheckedWall=($handoff.WallTime+0.0001);TickCompletedWall=($handoff.WallTime+0.0005);Position=@(0,0,0);Velocity=@(0,0,0);Body=$warmBody;MotorActuations=$base}})}}
}
$destinationFixture=New-DestinationWindowFixture
Assert-TraversalDestinationWindows $destinationFixture
# Typed handoff clocks omit Schema; the actual C frame clock always has Schema2.
$typedClock=Copy-TraversalFixture $destinationFixture.Traversal.DestinationWindows[0].Handoff.Clock
$typedFrame=Copy-TraversalFixture $typedClock;$typedFrame|Add-Member NoteProperty Schema 2 -Force
Assert-TraversalCapturedClockSame $typedFrame $typedClock
foreach($field in @('WallTime','FixedTime','FixedUnscaledTime','Delta','UnscaledDelta','TimeScale','MaximumDelta','Sequence','Frame','InFixedStep','PhysicsMode')){
    $x=Copy-TraversalFixture $typedClock;$x.PSObject.Properties.Remove($field)
    Deny-TraversalFixture {Assert-TraversalCapturedClockSame $typedFrame $x} ('typed capture omitted '+$field)
}
foreach($value in @(1,$null,$true,'2')){
    $x=Copy-TraversalFixture $typedClock;$x|Add-Member NoteProperty Schema $value -Force
    Deny-TraversalFixture {Assert-TraversalCapturedClockSame $typedFrame $x} 'typed capture has invalid explicit schema'
}
$changedCapture=Copy-TraversalFixture $typedClock;$changedCapture.FixedTime+=0.0625
Deny-TraversalFixture {Assert-TraversalCapturedClockSame $typedFrame $changedCapture} 'typed capture changed actual native fixed time'
$missingFrameSchema=Copy-TraversalFixture $typedFrame;$missingFrameSchema.PSObject.Properties.Remove('Schema')
Deny-TraversalFixture {Assert-TraversalCapturedClockSame $missingFrameSchema $typedClock} 'typed adapter cannot erase physical frame schema'
Write-Output 'PASS OFFLINE_ONLY020 captured clocks: typed snapshot/Schema2 frame binding; every native field and physical schema remain mandatory'
$destinationRest=New-DestinationWindowFixture -PriorRest
Assert-TraversalDestinationWindows $destinationRest
$wrongRestClock=Copy-TraversalFixture $destinationRest;$wrongRestClock.Traversal.DestinationWindows[0].Contract.PriorRest.Clock.Sequence++
Deny-TraversalFixture {Assert-TraversalDestinationWindows $wrongRestClock} 'qualification substituted prior actual rest clock'
foreach($case in @(
    @{Name='first mismatched clock admitted rather than WAIT';Change={param($x)$x.Traversal.DestinationWindows[0].Observations[0].Outcome='WINDOW_START'}},
    @{Name='moving motor queued';Change={param($x)$x.Traversal.DestinationWindows[0].Contract.MotorActive=$true}},
    @{Name='tiny nonzero native velocity';Change={param($x)$x.Traversal.DestinationWindows[0].Observations[4].Velocity=@(0.0005,0,0)}},
    @{Name='small unobserved pose rebase';Change={param($x)$x.Traversal.DestinationWindows[0].Observations[4].Position=@(0.0005,0,0)}},
    @{Name='changed original body';Change={param($x)$x.Traversal.DestinationWindows[0].Observations[4].Body.Rigidbody=99}},
    @{Name='repeated SetDestination';Change={param($x)$x.Traversal.DestinationWindows[0].SetDestinationCalls=2}},
    @{Name='stale handoff wall';Change={param($x)$x.Traversal.DestinationWindows[0].Handoff.Clock.WallTime+=0.2}},
    @{Name='native fixed profile changed at handoff';Change={param($x)$x.Traversal.DestinationWindows[0].Handoff.Clock.UnscaledDelta=0.065741}},
    @{Name='handoff precedes real SetDestination return';Change={param($x)$x.Traversal.DestinationWindows[0].Commit.CompletedWall+=0.01}},
    @{Name='handoff passed immutable global deadline';Change={param($x)$x.Traversal.DestinationWindows[0].Contract.GlobalDeadline=$x.Traversal.DestinationWindows[0].Receipt.End+0.0015}},
    @{Name='old Arrived paid native build during qualification';Change={param($x)$x.FirstHome.NativePlacements=@(@{Time=4})}},
    @{Name='readiness without C baseline';Change={param($x)$x.Traversal.Frames=@()}},
    @{Name='two queued goals overlap';Change={param($x)$copy=Copy-TraversalFixture $x.Traversal.DestinationWindows[0];$copy.Id=2;$x.Traversal.DestinationWindows+=,$copy}}
    @{Name='admitted window end differs from actual handoff';Change={param($x)$x.Traversal.DestinationWindows[0].EndWall=3.1}}
    @{Name='fresh wall hid original callback overrun';Change={param($x)$q=$x.Traversal.DestinationWindows[0];$q.Handoff.TickCompletedWall=$q.Receipt.End+0.11;$q.EndWall=$q.Handoff.TickCompletedWall}}
)){
    $x=Copy-TraversalFixture $destinationFixture;& $case.Change $x
    Deny-TraversalFixture {Assert-TraversalDestinationWindows $x} $case.Name
}
$pendingDestination=Copy-TraversalFixture $destinationRest;$pendingDestination.Traversal.Frames=@($pendingDestination.Traversal.Frames|Where-Object Event -ne 'MOTION_WITNESS')
Deny-TraversalFixture {Assert-TraversalDestinationWindows $pendingDestination} 'pending writer cannot start qualification'
$movingDestination=Copy-TraversalFixture $destinationRest;$movingDestination.Traversal.Frames[1].Speed=0.1
Deny-TraversalFixture {Assert-TraversalDestinationWindows $movingDestination} 'previous actual witness is moving'
Write-Output 'PASS OFFLINE_ONLY destination windows: invalid first clock WAIT, measured rest, exact immutable body/pose, real same-callback handoff and phase guards'

$destinationTimeout=Copy-TraversalFixture $destinationFixture;$q=$destinationTimeout.Traversal.DestinationWindows[0]
$destinationTimeout.Traversal.Frames=@(@{Event='BLOCKED';NativeResult='STOPPED';Clock=$null;Time=23.1;Actor='19';UnobservedCommand=$false});$q.Outcome='FATAL';$q.EndWall=23.1;$q.SetDestinationCalls=0;$q.Receipt=$null;$q.Commit=$null;$q.Handoff=$null
$q.Observations=@($q.Observations[0]);$fatal=Copy-TraversalFixture $q.Observations[0];$fatal.Observation=2;$fatal.ObservedWall=23.1;$fatal.Clock=$null;$fatal.Outcome='FATAL';$q.Observations+=,$fatal;$q.ObservationCount=2
Assert-TraversalDestinationWindows $destinationTimeout
Deny-TraversalFixture {$x=Copy-TraversalFixture $destinationTimeout;$x.Traversal.Frames+=,@{Event='MOVE_ISSUED';Time=23.2;Clock=@{WallTime=23.2}};Assert-TraversalDestinationWindows $x} 'fatal destination cannot resume physical progress'
Deny-TraversalFixture {$x=Copy-TraversalFixture $destinationTimeout;$x.Traversal.Completed=$true;Assert-TraversalDestinationWindows $x} 'fatal qualification cannot claim completed traversal'
Deny-TraversalFixture {$x=Copy-TraversalFixture $destinationFixture;$x.Traversal.DestinationWindows[0].Contract.GlobalDeadline=901;Assert-TraversalDestinationWindows $x} 'qualification cannot extend actual original global deadline'
$prematureTimeout=Copy-TraversalFixture $destinationTimeout;$prematureTimeout.Traversal.DestinationWindows[0].Observations[-1].ObservedWall=3.5;$prematureTimeout.Traversal.DestinationWindows[0].EndWall=3.5;$prematureTimeout.Traversal.Frames[0].Time=3.5
Deny-TraversalFixture {Assert-TraversalDestinationWindows $prematureTimeout} 'unexplained fatal masked a valid short window'
$smallDriftStop=Copy-TraversalFixture $destinationTimeout;$smallDriftStop.Traversal.DestinationWindows[0].Observations[-1].ObservedWall=3.5;$smallDriftStop.Traversal.DestinationWindows[0].EndWall=3.5;$smallDriftStop.Traversal.Frames[0].Time=3.5;$smallDriftStop.Traversal.DestinationWindows[0].Observations[-1].Position=@(0.0005,0,0)
Assert-TraversalDestinationWindows $smallDriftStop
$cancelledDestination=Copy-TraversalFixture $destinationTimeout;$q=$cancelledDestination.Traversal.DestinationWindows[0]
$q.Outcome='CANCELLED';$q.EndWall=3.5;$q.Observations=@($q.Observations[0]);$q.ObservationCount=1;$cancelledDestination.Traversal.Frames[0].Time=3.5
Assert-TraversalDestinationWindows $cancelledDestination
Deny-TraversalFixture {$x=Copy-TraversalFixture $cancelledDestination;$x.Status='GREEN';Assert-TraversalDestinationWindows $x} 'cancelled qualification cannot claim GREEN'
Deny-TraversalFixture {$x=Copy-TraversalFixture $cancelledDestination;$x.Traversal.Frames+=,@{Event='PROBE_REFUSED';Time=3.6};Assert-TraversalDestinationWindows $x} 'cancelled qualification cannot resume probes'
$baselineOverrun=Copy-TraversalFixture $destinationFixture;$q=$baselineOverrun.Traversal.DestinationWindows[0]
$q.Outcome='MOTOR_REFUSED';$q.Handoff.Accepted=$false;$q.Handoff.TickCompletedWall=$q.Receipt.End+0.11;$q.EndWall=$q.Handoff.TickCompletedWall
$baselineOverrun.Traversal.Frames+=,@{Event='BLOCKED';NativeResult='STOPPED';Clock=$null;Time=($q.EndWall+0.001);Stage='HOME_SITE';Actor='19';UnobservedCommand=$false}
Assert-TraversalDestinationWindows $baselineOverrun
Write-Output 'PASS OFFLINE_ONLY destination stop: no FixedUpdate deadline and exact tiny-drift refusal retain raw and never grant readiness'
# OFFLINE_ONLY: pending rebuild eligibility, no synthetic navigation credit.
function New-DestinationNativeReadinessFixture {
    $x=New-DestinationWindowFixture -PriorRest;$q=$x.Traversal.DestinationWindows[0];$template=$q.Observations[0]
    $x.Traversal|Add-Member NoteProperty DestinationReadinessPolicy 'NATIVE_NEW_GOAL_READINESS_V1'
    $q.Contract|Add-Member NoteProperty NativeReadinessPolicy 'NATIVE_NEW_GOAL_READINESS_V1'
    $q.Observations=@()
    for($i=0;$i -le 38;$i++){
        $o=Copy-TraversalFixture $template;$time=3+$i*0.0625;$o.Observation=$i+1;$o.ObservedWall=$time
        $o.Clock.WallTime=$time;$o.Clock.FixedTime=$time;$o.Clock.FixedUnscaledTime=$time;$o.Clock.Sequence=101+$i;$o.Clock.Frame=400+$i;$o.Clock.UnscaledDelta=0.0625
        $pending=$i -eq 5;$o.Outcome=if($pending){'WAIT'}elseif($i -in @(0,6)){'WINDOW_START'}elseif($i -eq 38){'READY'}else{'WINDOW_ADVANCE'}
        $reason=if($pending){'NATIVE_TILES_PENDING'}else{$null}
        $o|Add-Member NoteProperty Reasons @($reason|Where-Object {$null -ne $_})
        $o|Add-Member NoteProperty NativeReadiness ([pscustomobject]@{StartedWall=$time;CompletedWall=$time;NavAvailable=$true;DefaultMesh=$true;DefaultBuilt=$true;PendingTiles=$pending;OnNavmesh=$true;Ready=(-not $pending);Reason=$reason})
        $q.Observations+=,$o
    }
    $last=$q.Observations[-1].Clock;$q.ObservationCount=39;$q.Receipt.End=$last.WallTime;$q.Receipt.StableSince=3.375;$q.Receipt.WindowRestarts=1;$q.Receipt.TotalObservations=39;$q.Receipt.LastClock=Copy-TraversalFixture $last
    $q.Commit.StartedWall=$last.WallTime+0.0005;$q.Commit.CompletedWall=$last.WallTime+0.001
    $q.Handoff.ReadyClock=Copy-TraversalFixture $last;$q.Handoff.Clock=Copy-TraversalFixture $last;$q.Handoff.Clock.WallTime+=0.002
    $q.Handoff.CheckedWall=$q.Handoff.Clock.WallTime+0.0001;$q.Handoff.TickCompletedWall=$q.Handoff.Clock.WallTime+0.0005;$q.EndWall=$q.Handoff.TickCompletedWall
    $baseline=$x.Traversal.Frames[-1];$baseline.Clock=Copy-TraversalFixture $q.Handoff.Clock;$baseline.Clock|Add-Member NoteProperty Schema 2;$baseline.Time=$baseline.Clock.WallTime
    $x
}
$nativeGoal=New-DestinationNativeReadinessFixture
Assert-TraversalDestinationWindows $nativeGoal
foreach($case in @(
    @{Name='pending native rebuild counted toward two-second eligibility';Change={param($x)$x.Traversal.DestinationWindows[0].Observations[5].Outcome='WINDOW_ADVANCE'}},
    @{Name='READY despite missing current mesh';Change={param($x)$x.Traversal.DestinationWindows[0].Observations[-1].NativeReadiness.DefaultMesh=$false}},
    @{Name='READY while native tiles still pending';Change={param($x)$x.Traversal.DestinationWindows[0].Observations[-1].NativeReadiness.PendingTiles=$true}},
    @{Name='READY while actor off native mesh';Change={param($x)$x.Traversal.DestinationWindows[0].Observations[-1].NativeReadiness.OnNavmesh=$false}},
    @{Name='unknown pending state invented as READY';Change={param($x)$x.Traversal.DestinationWindows[0].Observations[-1].NativeReadiness.PendingTiles=$null}},
    @{Name='native observation captured after qualification wall';Change={param($x)$x.Traversal.DestinationWindows[0].Observations[-1].NativeReadiness.CompletedWall+=0.01}},
    @{Name='original readiness deadline extended';Change={param($x)$x.Traversal.DestinationWindows[0].Observations[-1].ObservedWall=24}},
    @{Name='new native policy omitted from per-goal contract';Change={param($x)$x.Traversal.DestinationWindows[0].Contract.PSObject.Properties.Remove('NativeReadinessPolicy')}},
    @{Name='sole SetDestination replayed after native race';Change={param($x)$x.Traversal.DestinationWindows[0].SetDestinationCalls=2}}
)){$x=Copy-TraversalFixture $nativeGoal;& $case.Change $x;Deny-TraversalFixture {Assert-TraversalDestinationWindows $x} $case.Name}
Write-Output 'PASS OFFLINE_ONLY020 native goal readiness: pending WAIT resets only eligibility span; two seconds of current mesh/build/no-pending/on-mesh bind the sole native destination'
# OFFLINE_ONLY: JSON may materialize native double timestamps as Decimal in PowerShell5; normalize every endpoint consistently.
$nativeTimestampTypes='{"NativeReadiness":{"StartedWall":274.4569726051588,"CompletedWall":274.45698390515878,"NavAvailable":true,"DefaultMesh":true,"DefaultBuilt":true,"OnNavmesh":true,"Ready":true,"PendingTiles":false,"Reason":null},"Clock":{"WallTime":274.45694260515876},"ObservedWall":274.45698390515878}'|ConvertFrom-Json
if(-not (Test-TraversalDestinationNativeReadiness $nativeTimestampTypes)){throw 'Valid typed native snapshot refused'}
foreach($case in @(
    @{Name='native eligibility really starts before callback';Change={param($o)$o.NativeReadiness.StartedWall=[double]$o.Clock.WallTime-0.001}},
    @{Name='native eligibility really completes before start';Change={param($o)$o.NativeReadiness.CompletedWall=[double]$o.NativeReadiness.StartedWall-0.001}},
    @{Name='native eligibility really completes after observation';Change={param($o)$o.NativeReadiness.CompletedWall=[double]$o.ObservedWall+0.001}}
)){$x=Copy-TraversalFixture $nativeGoal;& $case.Change $x.Traversal.DestinationWindows[0].Observations[-1];Deny-TraversalFixture {Assert-TraversalDestinationWindows $x} $case.Name}
Write-Output 'PASS OFFLINE_ONLY020 native timestamp numeric types: consistent finite doubles, unchanged strict callback envelope and full-window rejection'
# OFFLINE_ONLY query protocol: self may be observed; every other physical overlap still refuses a stand.
function New-FixtureStandAttemptFixture {
    $terrain=[pscustomobject]@{Instance=40;Type='UnityEngine.TerrainCollider';Entity='';Self=$false;enabled=$true;isTrigger=$false;Center=@(0,-1,0);Extents=@(100,1,100)}
    $self=[pscustomobject]@{Instance=10;Type='UnityEngine.CapsuleCollider';Entity='19';Self=$true;enabled=$true;isTrigger=$false;Center=@(0,0.95,-2.8);Extents=@(0.5,0.9,0.5)}
    $fixture=@{FoundationPosition=@(0,0,0);FoundationRotation=@(0,0,0,1);NativeFoundationBounds=@{Center=@(0,0,0);Size=@(3,1,3)};Radius=0.5;Skin=0.02;ExteriorMin=@(-2.02,-0.5,-2.02);ExteriorMax=@(2.02,0.5,2.02);
        WallStand=@(0,0.05,2.8);DetourGoal=@(2.8,0.05,0);DoorStand=@(0,0.05,-2.8);Time=1.25}
    $rows=@();$roles=@('WALL_N','DETOUR','DOORWAY');$points=@($fixture.WallStand,$fixture.DetourGoal,$fixture.DoorStand)
    for($i=0;$i -lt 3;$i++){
        $foot=$points[$i];$point=@($foot[0],0,$foot[2]);$support=[pscustomobject]@{Collider=$terrain;Point=$point;Normal=@(0,1,0);Distance=2}
        $rows+=,[pscustomobject]@{Role=$roles[$i];Offset=1.3;Input=$point;Edge=@($point[0],1.5,$point[2]);StartedWall=(1+$i*0.1);CompletedWall=(1.01+$i*0.1);ActorPosition=$fixture.DoorStand;NativeVelocity=@(0,0,0);Body=$warmBody;
            FoundationPosition=$fixture.FoundationPosition;FoundationRotation=$fixture.FoundationRotation;ExteriorMin=$fixture.ExteriorMin;ExteriorMax=$fixture.ExteriorMax;
            Sampled=$true;SampleExtents=@(0.25,0.5,0.25);NavPoint=$point;Mask=-1;Triggers='Ignore';RayOrigin=@($point[0],2,$point[2]);RayHits=@($support);Support=$support;Foot=$foot;
            Radius=0.5;Height=1.8;A=@($foot[0],($foot[1]+0.5),$foot[2]);B=@($foot[0],($foot[1]+1.3),$foot[2]);WaterDepth=-1;OverlapHits=@($self);OverlapClear=$true;Queries=3;SampleAccepted=$true;Outside=$true;Accepted=$true;Reason='ACCEPTED'}
    }
    $rows[-1].RayHits+=,[pscustomobject]@{Collider=$self;Point=@(0,1.8,-2.8);Normal=@(0,1,0);Distance=0.2}
    $placements=@(foreach($role in @('FOUNDATION','WALL_N','DOORWAY','DOOR')){@{Role=$role;Time=[single]0.5}})
    $payments=@(foreach($kind in @('BUILD_FOUNDATION','UPGRADE_FOUNDATION','BUILD_WALL_N','UPGRADE_WALL_N','BUILD_DOORWAY','UPGRADE_DOORWAY','BUILD_DOOR')){@{Kind=$kind;Time=[single]0.6}})
    Copy-TraversalFixture @{Actor=@{NetId='19'};FirstHome=@{NativePlacements=$placements;Operations=$payments};Traversal=@{WarmupContract=@{Body=$warmBody};FixtureStandPolicy='FULL_BODY_SELF_EXCLUDED_STANDS_V1';FixtureStandAttempts=$rows;Fixture=$fixture}}
}
$fixtureStands=New-FixtureStandAttemptFixture
Assert-TraversalFixtureStandAttempts $fixtureStands
$blockedStands=Copy-TraversalFixture $fixtureStands;$basis=Copy-TraversalFixture $blockedStands.Traversal.Fixture;$basis|Add-Member NoteProperty ActualGeometry $true;$basis|Add-Member NoteProperty Accepted $true
$blockedStands.Traversal|Add-Member NoteProperty BuildPlans @($basis);$blockedStands.Traversal.Fixture=$null;$blockedStands.Traversal.FixtureStandAttempts=@($blockedStands.Traversal.FixtureStandAttempts[0])
$blocked=$blockedStands.Traversal.FixtureStandAttempts[0];$blocked.OverlapHits[0].Entity='100';$blocked.OverlapHits[0].Self=$false;$blocked.OverlapClear=$false;$blocked.SampleAccepted=$false;$blocked.Outside=$null;$blocked.Accepted=$false;$blocked.Reason='CAPSULE_OVERLAP'
Assert-TraversalFixtureStandAttempts $blockedStands
foreach($case in @(
    @{Name='self-inclusive generic ground selected NPC as support';Change={param($x)$x.Traversal.FixtureStandAttempts[-1].Support=$x.Traversal.FixtureStandAttempts[-1].RayHits[-1]}},
    @{Name='foreign physical overlap waived';Change={param($x)$x.Traversal.FixtureStandAttempts[-1].OverlapHits[0].Entity='100';$x.Traversal.FixtureStandAttempts[-1].OverlapHits[0].Self=$false}},
    @{Name='foreign entity relabeled self';Change={param($x)$x.Traversal.FixtureStandAttempts[-1].OverlapHits[0].Entity='100'}},
    @{Name='reduced original capsule';Change={param($x)$x.Traversal.FixtureStandAttempts[-1].Radius=0.45}},
    @{Name='partial collision mask';Change={param($x)$x.Traversal.FixtureStandAttempts[-1].Mask=2}},
    @{Name='fixture uses another admitted stand';Change={param($x)$x.Traversal.Fixture.DoorStand[0]=0.2}},
    @{Name='unbounded repeated query attempts';Change={param($x)$x.Traversal.FixtureStandAttempts=@($x.Traversal.FixtureStandAttempts)*4}}
)){$x=Copy-TraversalFixture $fixtureStands;& $case.Change $x;Deny-TraversalFixture {Assert-TraversalFixtureStandAttempts $x} $case.Name}
Write-Output 'PASS OFFLINE_ONLY020 fixture stand queries: native terrain/full capsule, self-only exclusion, honest collision refusal, exact fixture bindings and nine-attempt bound'
# OFFLINE_ONLY consistency checks for actual native query receipts, not physical execution.
foreach($case in @(
    @{Name='stand ray normal is not a native unit normal';Change={param($x)$a=$x.Traversal.FixtureStandAttempts[-1];$a.Support.Normal=@(0,2,0);$a.RayHits[0].Normal=@(0,2,0)}},
    @{Name='stand ray distance disagrees with vertical hit';Change={param($x)$a=$x.Traversal.FixtureStandAttempts[-1];$a.Support.Distance=1.5;$a.RayHits[0].Distance=1.5}},
    @{Name='stand ray collider has negative native bounds';Change={param($x)$a=$x.Traversal.FixtureStandAttempts[-1];$a.Support.Collider.Extents[0]=-1;$a.RayHits[0].Collider.Extents[0]=-1}},
    @{Name='stand overlap collider has negative native bounds';Change={param($x)$x.Traversal.FixtureStandAttempts[-1].OverlapHits[0].Extents[0]=-1}},
    @{Name='explicit unknown fixture stand policy skips the contract';Change={param($x)$x.Traversal.FixtureStandPolicy='SYNTHETIC_UNKNOWN_POLICY'}}
)){$x=Copy-TraversalFixture $fixtureStands;& $case.Change $x;Deny-TraversalFixture {Assert-TraversalFixtureStandAttempts $x} $case.Name}
Assert-TraversalFixtureStandAttempts ([pscustomobject]@{Traversal=[pscustomobject]@{FixtureStandPolicy=$null}})
Write-Output 'PASS OFFLINE_ONLY020 fixture native geometry: unit normals, actual vertical distance, nonnegative native bounds and explicit policy; legacy absent policy retained'
# OFFLINE_ONLY receipt coherence only: later full-home work is after these hypothetical stand queries.
$later=Copy-TraversalFixture $fixtureStands;$later.FirstHome.NativePlacements+=,[pscustomobject]@{Role='TC';Time=[single]20};$later.FirstHome.Operations+=,[pscustomobject]@{Kind='BUILD_TC';Time=[single]20};$later.FirstHome.Operations+=,[pscustomobject]@{Kind='UPKEEP';Time=[single]21}
Assert-TraversalFixtureStandAttempts $later
$alias=Copy-TraversalFixture $fixtureStands;$alias.FirstHome.NativePlacements[-1].Time=[single]1.00000001;$alias.FirstHome.Operations[-1].Time=[single]1.00000001;$alias.Traversal.Fixture.Time=[single]1.21000000001
$alias.Traversal.FixtureStandAttempts[0].StartedWall=0.99999999;$alias.Traversal.FixtureStandAttempts[-1].CompletedWall=1.21000004
Assert-TraversalFixtureStandAttempts $alias
foreach($case in @(
    @{Name='stand captured another original body';Change={param($x)$x.Traversal.FixtureStandAttempts[0].Body.Rigidbody=999}},
    @{Name='stand candidate input is nonfinite';Change={param($x)$x.Traversal.FixtureStandAttempts[0].Input[0]=[double]::NaN}},
    @{Name='stand actual edge is nonfinite';Change={param($x)$x.Traversal.FixtureStandAttempts[0].Edge[0]=[double]::NaN}},
    @{Name='stand queried before final native placement';Change={param($x)$x.FirstHome.NativePlacements[-1].Time=[single]2}},
    @{Name='stand queried before final native payment';Change={param($x)$x.FirstHome.Operations[-1].Time=[single]2}},
    @{Name='stand queried after actual fixture readiness';Change={param($x)$x.Traversal.Fixture.Time=[single]0.9}},
    @{Name='stand queried without minimal paid native door';Change={param($x)$x.FirstHome.NativePlacements=@($x.FirstHome.NativePlacements|Where-Object Role -cne 'DOOR')}}
)){$x=Copy-TraversalFixture $fixtureStands;& $case.Change $x;Deny-TraversalFixture {Assert-TraversalFixtureStandAttempts $x} $case.Name}
Write-Output 'PASS OFFLINE_ONLY020 fixture stand coherence: original body, finite input/edge, minimal paid native timing, honest partial and later TC retained'
# OFFLINE_ONLY: source-shaped request observations; no synthetic native/physical proof.
function New-SynchronousRebuildFixture([string]$kind='ACCEPTED'){
    $x=New-StationaryFixture -AfterBrake;$frames=@();foreach($f in $x.Frames){$frames+=,$f;if($f.Event -ceq 'MOTION_WITNESS' -and $f.Speed -eq 0){break}}
    $w=$frames[-1];$arrived=Copy-TraversalFixture $w;$arrived.Event='ARRIVED';$frames+=,$arrived
    $b=$w.Body;$warm=Copy-TraversalFixture @{Actor='19';Capsules=@(@{Instance=$b.Instance;Radius=$b.Radius;Height=$b.Height;Center=$b.Center;Direction=$b.Direction;Scale=$b.Scale;Up=@(0,1,0);Enabled=$b.Enabled;Trigger=$b.Trigger;Layer=$b.Layer;Rigidbody=$b.RigidbodyInstance});Rigidbody=$b.RigidbodyInstance;Kinematic=$b.Kinematic;Gravity=$b.Gravity;DetectCollisions=$b.DetectCollisions;CollisionMode=$b.CollisionMode;Colliders=@($b.Instance);AgentStopped=$b.AgentStopped;AgentUpdatePosition=$b.AgentUpdatePosition;AgentUpdateRotation=$b.AgentUpdateRotation}
    $tick=[single]318.5557;$start=[double]$tick+0.01;$call=$start+0.01;$returned=$call+0.05;$end=$returned+0.01;$deadline=[single]($tick+[single]30);$wait=[single]($tick+[single]2)
    if($kind -ceq 'ROUNDED_TICK'){$start=[double]$tick-0.000002;$call=$start+0.01;$returned=$call+0.05;$end=$returned+0.01}
    $count=@($frames|Where-Object Event -ceq 'MOVE_ISSUED').Count
    $place=@{Role='FOUNDATION';Entity='100';NativeCall='Planner.DoBuild(Construction.Target,Construction)';Time=$tick};$op=@{Kind='BUILD_FOUNDATION';EntityId='100';Time=$tick}
    $state=@{Body=$warm;Pose=@{Position=$b.Position;RigidbodyPosition=$b.RigidbodyPosition;Rotation=$b.Rotation};CapsulePosition=$b.Position;CapsuleRotation=$b.Rotation;NativeVelocity=@(0,0,0);MeasuredVelocity=@(0,0,0);MeasuredSpeed=0;Witness=@{Command=$w.Command;Stage=$w.Stage;Clock=$w.Clock;Actual=$w.Actual;Speed=$w.Speed;Body=$w.Body};Active=$false;Blocked=$false;Arrived=$true;QueuedDestination=$false;Navigating=$false;HostActive=$true;Finished=$false;PendingIntent=$false;Phase='BUILD_WAIT';Step=1;Wait=$wait;Deadline=$deadline;GlobalDeadline=[single]900;Actuations=$count;Issued=$count;Accepted=$count;Placements=1;Operations=1;Native=@{StartedWall=$start;CompletedWall=($start+0.001);NavAvailable=$true;DefaultMesh=$true;DefaultBuilt=$true;PendingTiles=$false;OnNavmesh=$true;Ready=$true;Reason=$null};Wall=($start+0.002)}
    $after=Copy-TraversalFixture $state;$after.Native.StartedWall=$returned;$after.Native.CompletedWall=$returned+0.001;$after.Wall=$returned+0.002
    $r=@{Policy='BENCH_SYNC_NATIVE_REQUEST_V1';Event='REBUILD_REQUEST';Step=1;Role='FOUNDATION';Entity='100';Center=@(0,0,0);Size=@(3,1,3);Time=$tick;Wait=$wait;Deadline=$deadline;GlobalDeadline=[single]900;Phase='BUILD_WAIT';RequestedSync=$true;Called=$true;Returned=$true;Accepted=$true;StartedWall=$start;CallStartedWall=$call;CallCompletedWall=$returned;CompletedWall=$end;Before=$state;After=$after;Failure=$null;Owned=@(@{Role='FOUNDATION';Entity='100';Owner='15';Saving=$true;Registered=$true;Center=@(0,0,0);Size=@(3,1,3)})}
    $n=@{Mode='BUILD_SMOKE';Status='PARTIAL';Actor=@{NetId='19';UserId='15'};Samples=@(@{Time=0;ActorNetId='19'});Persistence=@{Saved=$false;Restored=$false};FirstHome=@{DiagnosticOnly=$true;Schedule=@{SmokeSeconds=900};Tiles=@($r);NativePlacements=@($place);Operations=@($op);Phases=@(@{Phase='BUILD';Time=$tick});Navigation=@()};Traversal=@{Completed=$false;Frames=$frames;WarmupContract=@{Body=$warm};BuildPlans=@();DestinationWindows=@();Scenes=@();FixtureTransitions=@();BuildRests=@()}}
    if($kind -ceq 'NOOP'){$r.Before.Native.DefaultBuilt=$false;$r.Before.Native.PendingTiles=$true;$r.Before.Native.Ready=$false;$r.Before.Native.Reason='NATIVE_DEFAULT_NOT_BUILT';$r.After.Native.DefaultBuilt=$false;$r.After.Native.Ready=$false;$r.After.Native.Reason='NATIVE_DEFAULT_NOT_BUILT'}
    if($kind -in @('EXCEPTION','CHANGED','ENTRY')){
        $r.Accepted=$false;$r.Failure=@{Phase='POST_RETURN';Reason='InvalidOperationException: changed observed rest';Time=$end}
        if($kind -ceq 'EXCEPTION'){$r.Returned=$false;$r.CallCompletedWall=$null;$r.After=$null;$r.Failure.Phase='NATIVE_REQUEST'}
        if($kind -ceq 'CHANGED'){$r.After.NativeVelocity=@('NaN',0,0);$r.After.Body.Rigidbody=999}
        if($kind -ceq 'ENTRY'){$r.Called=$false;$r.Returned=$false;$r.Before=$null;$r.After=$null;$r.CallStartedWall=$null;$r.CallCompletedWall=$null;$r.Owned=$null;$r.Failure.Phase='ENTRY'}
        $stop=Copy-TraversalFixture $w;$stop.Event='BLOCKED';$stop.NativeResult='STOPPED';$stop.Clock=$null;$stop.Time=[single]($end+0.01);$stop|Add-Member NoteProperty PendingDecision $null -Force;$stop|Add-Member NoteProperty UnobservedCommand $false -Force;$n.Traversal.Frames+=,$stop
    }
    Copy-TraversalFixture $n
}
$syncBase=New-SynchronousRebuildFixture
foreach($kind in @('ACCEPTED','NOOP','EXCEPTION','CHANGED','ENTRY','ROUNDED_TICK')){Assert-TraversalSynchronousRebuild (New-SynchronousRebuildFixture $kind)}
$syncLegacy=New-SynchronousRebuildFixture;$syncLegacy.FirstHome.Tiles=@(@{Step=1;Event='REBUILD_REQUEST';Before=$false;After=$true;Center=@(0,0,0);Size=@(3,1,3);Time=1},@{Step=1;Event='READINESS';Pending=$false;Deadline=31;Time=3});Assert-TraversalSynchronousRebuild $syncLegacy
Write-Output 'PASS OFFLINE_ONLY020 synchronous native request: six honest outcomes and ordinary legacy shape'
$syncDenied=0
foreach($case in @(
    @{Name='new shape missing policy';Change={param($n)$n.FirstHome.Tiles[0].Policy=$null}},
    @{Name='unknown policy';Change={param($n)$n.FirstHome.Tiles[0].Policy='UNKNOWN'}},
    @{Name='changed original body';Change={param($n)$n.FirstHome.Tiles[0].Before.Body.Rigidbody=999}},
    @{Name='changed witnessed pose';Change={param($n)$n.FirstHome.Tiles[0].Before.Pose.Position[0]+=0.01}},
    @{Name='moving native body';Change={param($n)$n.FirstHome.Tiles[0].After.NativeVelocity[0]=0.01}},
    @{Name='pending writer';Change={param($n)$n.FirstHome.Tiles[0].Before.Issued++}},
    @{Name='missing actual arrival';Change={param($n)$n.Traversal.Frames=@($n.Traversal.Frames|Where-Object Event -cne 'ARRIVED')}},
    @{Name='unpaid native role';Change={param($n)$n.FirstHome.Operations=@()}},
    @{Name='foreign bounds';Change={param($n)$n.FirstHome.Tiles[0].Owned[0].Owner='999'}},
    @{Name='bounds substitution';Change={param($n)$n.FirstHome.Tiles[0].Center[0]=10}},
    @{Name='duplicate rebuild';Change={param($n)$n.FirstHome.Tiles+=,$n.FirstHome.Tiles[0]}},
    @{Name='rebased tile deadline';Change={param($n)$n.FirstHome.Tiles[0].Deadline+=1}},
    @{Name='native Single deadline widened';Change={param($n)$n.FirstHome.Tiles[0].Deadline=[double][single]$n.FirstHome.Tiles[0].Deadline+0.0001}},
    @{Name='global deadline widened';Change={param($n)$n.FirstHome.Tiles[0].GlobalDeadline+=1}},
    @{Name='accepted overrun';Change={param($n)$n.FirstHome.Tiles[0].CompletedWall=$n.FirstHome.Tiles[0].Deadline+1}},
    @{Name='invented return chronology';Change={param($n)$n.FirstHome.Tiles[0].CallCompletedWall=$n.FirstHome.Tiles[0].CallStartedWall-1}},
    @{Name='post-return deadline change';Change={param($n)$n.FirstHome.Tiles[0].After.Deadline+=1}}
    @{Name='invented native readiness';Change={param($n)$n.FirstHome.Tiles[0].Before.Native.PendingTiles=$true}}
)){$n=Copy-TraversalFixture $syncBase;& $case.Change $n;Deny-TraversalFixture {Assert-TraversalSynchronousRebuild $n} $case.Name;$syncDenied++}
Write-Output ('PASS OFFLINE_ONLY020 synchronous native request: '+$syncDenied+' entry/budget/identity negatives')
$syncTerminalDenied=0
foreach($mutation in @(
    {param($n)$n.Status='GREEN'},
    {param($n)$n.Traversal.Completed=$true},
    {param($n)$n.FirstHome.Operations+=,[pscustomobject]@{Kind='BUILD_WALL_N';EntityId='101';Time=[single]400}},
    {param($n)$n.Traversal.BuildPlans=@(@{Time=400})},
    {param($n)$n.Traversal.DestinationWindows=@(@{Contract=@{Start=400}})},
    {param($n)$n.Traversal.Frames+=,(Copy-TraversalFixture $n.Traversal.Frames[-2]);$n.Traversal.Frames[-1].Event='MOVE_DECISION';$n.Traversal.Frames[-1].Clock.WallTime=400},
    {param($n)$n.Traversal.Scenes=@(@{Status='PASSED';EndTime=400})}
)){$n=New-SynchronousRebuildFixture 'EXCEPTION';& $mutation $n;Deny-TraversalFixture {Assert-TraversalSynchronousRebuild $n} 'native rebuild failure future progress';$syncTerminalDenied++}
Write-Output ('PASS OFFLINE_ONLY020 synchronous native request: '+$syncTerminalDenied+' terminal negatives')
# OFFLINE_ONLY: the real initial CRAFT_TOOL append has no Time property.
function New-ActualShapeCraftPrefix {
    $n=New-SynchronousRebuildFixture
    $before=@{Uid='501';Shortname='stones';Amount=2;Condition=0;MaxCondition=0}
    $left=@{Uid='501';Shortname='stones';Amount=1;Condition=0;MaxCondition=0}
    $output=@{Uid='502';Shortname='stonehatchet';Amount=1;Condition=100;MaxCondition=100}
    $cost=@{Shortname='stones';Amount=1}
    $craft=@{Kind='CRAFT_TOOL';Before=@($before);After=@($left,$output);Costs=@($cost);Output=$output;Intent=@{State='SUBMITTED'}}
    $n|Add-Member NoteProperty Recipe ([pscustomobject]@{Ingredients=@($cost)}) -Force
    $n.FirstHome.Operations=@((Copy-TraversalFixture $craft)) + @($n.FirstHome.Operations)
    $n.FirstHome.Tiles[0].Before.Operations++;$n.FirstHome.Tiles[0].After.Operations++
    Copy-TraversalFixture $n
}
$n=New-ActualShapeCraftPrefix
Assert-TraversalSynchronousRebuild $n
foreach($mutation in @(
    {param($n)$n.FirstHome.Operations[0].Kind='GATHER'},
    {param($n)$n.FirstHome.Operations[0].Kind='UNKNOWN'},
    {param($n)$n.FirstHome.Operations=@($n.FirstHome.Operations[1],$n.FirstHome.Operations[0])},
    {param($n)$n.FirstHome.Operations[0]|Add-Member NoteProperty Time 1 -Force},
    {param($n)$n.FirstHome.Operations[1].PSObject.Properties.Remove('Time')},
    {param($n)$n.FirstHome.Operations[0].Costs[0].Amount=2}
)){$x=New-ActualShapeCraftPrefix;& $mutation $x;Deny-TraversalFixture {Assert-TraversalSynchronousRebuild $x} 'source-shaped untimed initial craft misuse'}
Write-Output 'PASS source-shaped initial CRAFT_TOOL has no invented Time; all native home payments stay timed'
$syncSourceHome=[IO.File]::ReadAllText((Join-Path $PSScriptRoot '..\src\home\FirstHome.cs'))
if(([regex]::Matches($syncSourceHome,'RebuildTilesInBounds\(bounds,true\)')).Count -ne 1 -or $syncSourceHome -notmatch 'if\(traversalBench\)HomeRebuildAtRest\(bounds,now,paidRole\)' -or $syncSourceHome -notmatch 'RebuildTilesInBounds\(bounds,false\)' -or $syncSourceHome -notmatch 'dt>1\.5f' -or $syncSourceHome -notmatch 'homeTilesDeadline=now\+30' -or $syncSourceHome -notmatch 'homeWait=now\+2'){throw 'Synchronous rebuild widened existing source scope/time bounds'}
$syncMethod=$syncSourceHome.Substring($syncSourceHome.IndexOf('private void HomeRebuildAtRest('),($syncSourceHome.IndexOf('private bool HomeTick()')-$syncSourceHome.IndexOf('private void HomeRebuildAtRest(')))
if($syncMethod -match 'MovePosition|SetDestination|localMotion\.Tick|linearVelocity\s*=|previousTime\s*=|progressTime\s*=|homeLegTime\s*='){throw 'Synchronous rebuild introduced writer/history reset'}
if($ReadinessOnly){return}
$frames=New-TraversalFrames
Assert-TraversalFrames $frames '19' 'synthetic-world'
# OFFLINE_ONLY regression: observation cannot consume or poison motor state.
if(-not (Get-Command Assert-TraversalProbe -CommandType Function -ErrorAction SilentlyContinue)){throw 'Missing nondestructive traversal probe contract'}
$probe=Copy-TraversalFixture $frames[1]
$probe.Event='PROBE_REFUSED';$probe.NativeResult='PROBE_ONLY';$probe.Reason='READ_ONLY_REFUSED';$probe.Classification='SOLID_BLOCKED';$probe.Actual=$probe.From;$probe.Requested=@(1,0,0)
$probe.Body=Copy-TraversalFixture $frames[0].Body;$probe.Support=Copy-TraversalFixture $frames[0].Support
$probe|Add-Member NoteProperty ControlBefore @{Active=$false;Arrived=$true;Blocked=$false;Pending=$false;Acquiring=$false;UnobservedTerminal=$false;Actuations=2;Retry=0;Command=2;Velocity=@(0,0,0);NativeVelocity=@(0,0,0);Position=$probe.From}
$probe|Add-Member NoteProperty ControlAfter (Copy-TraversalFixture $probe.ControlBefore)
Assert-TraversalProbe $probe '19'
foreach($mutation in @(
    @{Name='read-only refusal poisoned controller';Change={param($x)$x.ControlAfter.Blocked=$true}},
    @{Name='read-only probe during pending motion';Change={param($x)$x.ControlBefore.Pending=$true;$x.ControlAfter.Pending=$true}},
    @{Name='read-only probe issued actuation';Change={param($x)$x.ControlAfter.Actuations=3}}
)){$x=Copy-TraversalFixture $probe;& $mutation.Change $x;Deny-TraversalFixture {Assert-TraversalProbe $x '19'} $mutation.Name}
$motor=[IO.File]::ReadAllText((Join-Path (Split-Path $PSScriptRoot -Parent) 'src\navigation\ObstacleTraversal.cs'))
$probeSource=$motor.Substring($motor.IndexOf('public bool ProbeDisplacement('),$motor.IndexOf('public bool SetDestination(')-$motor.IndexOf('public bool ProbeDisplacement('))
if($probeSource -match '(?<![\w.])(?:Block|Stop)\(' -or $probeSource -notmatch 'active \|\| pending' -or $probeSource -notmatch 'lastVelocity\.sqrMagnitude != 0' -or $probeSource -notmatch 'PROBE_REFUSED') {throw 'Read-only probe still mutates motor lifecycle or lacks stationary guard'}
if($motor -notmatch 'Block\(frame,.*"KINEMATIC_CLIP"' -or $motor -notmatch 'if \(!sweptClear \|\| !endClear' -or $motor -notmatch '"FULL_VOLUME_OR_PERMISSION_BLOCKED"'){throw 'Actual motion lost fail-closed physical admission'}
Write-Output 'PASS OFFLINE_ONLY: nonpoisoning probe snapshots, stationary guard and actual move collision admission'
$exterior=Copy-TraversalFixture @{FoundationPosition=@(0,0,0);FoundationRotation=@(0,0,0,1);NativeFoundationBounds=@{Center=@(0,0,0);Size=@(3,0.3,3)};Skin=0.02;Radius=0.5;ExteriorMin=@(-2.02,-0.15,-2.02);ExteriorMax=@(2.02,0.15,2.02)}
if(-not (Get-Command Assert-TraversalExteriorSegment -CommandType Function -ErrorAction SilentlyContinue)){throw 'Missing native exterior detour contract'}
Assert-TraversalExteriorSegment $exterior @(0,0,2.8) @(2.8,0,2.8)
Deny-TraversalFixture {Assert-TraversalExteriorSegment $exterior @(0,0,2.8) @(2.8,0,0)} 'detour diagonal crosses sealed native footprint'
$undefined=Copy-TraversalFixture $frames
$undefined[1].Overlaps=@([pscustomobject]@{Collider=$undefined[1].Support.Collider;Intersects=$false;Distance=[double]::NaN;Direction=$null;Error=$null;SupportTangent=$true;ActorCollider=10;QueryPosition=$undefined[1].Actual})
$undefined[1].Sweeps[0].Hits=@([pscustomobject]@{Collider=$undefined[1].Support.Collider;Point=@(0,0,0);Normal=@(0,1,0);Distance=0;Blocking=$false;InitialIntersects=$false;InitialDepth=[double]::NaN;InitialDirection=$null;PlaneClearance=0;SupportTangent=$true})
Assert-TraversalFrames $undefined '19' 'synthetic-world'
foreach($mutation in @(
    @{Name='nonplayer actor';Change={param($x)$x[1].Actor='20'}},
    @{Name='wrong world';Change={param($x)$x[1].World='other-world'}},
    @{Name='NaN pose';Change={param($x)$x[1].Actual[0]=[double]::NaN}},
    @{Name='shrunk capsule';Change={param($x)$x[1].Body.Radius=0.3}},
    @{Name='changed body';Change={param($x)$x[1].Body.Instance=12}},
    @{Name='unsafe speed';Change={param($x)$x[1].Speed=100}},
    @{Name='native failure';Change={param($x)$x[1].NativeResult=$false}},
    @{Name='competing writer';Change={param($x)$x[1].Body.AgentUpdatePosition=$true}},
    @{Name='stale native epoch';Change={param($x)$x[0].Navigation.TileChangeVersion=2}},
    @{Name='missing after sweep';Change={param($x)$x[1].Sweeps=@()}},
    @{Name='missing prelanding';Change={param($x)$x[0].Landing=$null}},
    @{Name='unsupported prelanding drop';Change={param($x)$x[0].Landing.FootY=-1}},
    @{Name='support gap';Change={param($x)$x[1].Support.Gap=1}},
    @{Name='support side normal';Change={param($x)$x[1].Support.Normal=@(1,0,0)}},
    @{Name='unsupported landing';Change={param($x)$x[1].Support.Found=$false}},
    @{Name='pre-sweep only witness';Change={param($x)$x[1].Sweeps[0].To=$x[1].From}}
)){$x=Copy-TraversalFixture $frames;& $mutation.Change $x;Deny-TraversalFixture {Assert-TraversalFrames $x '19' 'synthetic-world'} $mutation.Name}
Write-Output 'PASS OFFLINE_ONLY 1: identity/world/body, native result, bounded continuity, actual after sweep and support receipts'
function Set-TraversalClock($f,[double]$wall,[double]$fixed,[int]$sequence){
    $f.Schema=2;$f.Time=$wall
    $f|Add-Member NoteProperty Clock @{Schema=2;WallTime=$wall;FixedTime=$fixed;FixedUnscaledTime=$fixed;Delta=0.05;UnscaledDelta=0.05;TimeScale=1.0;InFixedStep=$true;PhysicsMode='FixedUpdate';Sequence=$sequence;Frame=300} -Force
    $f|Add-Member NoteProperty FixedDt 0.05 -Force;$f|Add-Member NoteProperty WallDt 0.0 -Force
    $f|Add-Member NoteProperty PreviousClock $null -Force
    $f.Body|Add-Member NoteProperty Velocity @(0,0,0) -Force
}
function New-FixedClockFrames {
    $result=@(New-TraversalFrames);$baseline=New-TraversalFrame 'CLOCK_BASELINE' 0 10 @(0,0,0) @(0,0,0) 0
    $baseline.NativeResult='CLOCK_BASELINE';$baseline.Classification='CLEAR';Set-TraversalClock $baseline 10 1 100;$baseline.FixedDt=0
    $baseline|Add-Member NoteProperty PosePrevious @(0,0,0);$baseline|Add-Member NoteProperty PosePreviousTime 9.99;$baseline|Add-Member NoteProperty ObservedVelocity @(0,0,0)
    $walls=@(10.03,10.08,10.08,10.081);$fixed=@(1.05,1.10,1.10,1.15);$sequences=@(101,102,102,103);$priorWall=10.0;$priorVelocity=@(0,0,0);$issued=$null
    $lastCallback=$baseline.Clock;$previousCallback=$null
    for($i=0;$i -lt $result.Count;$i++){
        $f=$result[$i];Set-TraversalClock $f $walls[$i] $fixed[$i] $sequences[$i]
        if($f.Clock.Sequence -ne $lastCallback.Sequence){$previousCallback=$lastCallback;$lastCallback=$f.Clock}
        $f.PreviousClock=Copy-TraversalFixture $previousCallback;$f.WallDt=$walls[$i]-$previousCallback.WallTime;$f.Dt=0.05;$velocity=@(for($j=0;$j -lt 3;$j++){($f.Requested[$j]-$f.From[$j])/0.05})
        $f.Acceleration=(Get-WorldDistance $velocity $priorVelocity)/0.05;$f.Speed=(Get-WorldDistance $f.Requested $f.From)/0.05
        if($f.Event -eq 'MOVE_DECISION'){
            $f.Distance=Get-WorldDistance $f.Requested $f.From;$f.Body.Velocity=$priorVelocity;$issued=$f.Clock;$f.PreviousTime=$priorWall
        }else{$f.Body.Velocity=$velocity;$f.PreviousTime=$issued.WallTime;$priorVelocity=$velocity;$f|Add-Member NoteProperty NativeVelocityMatches $true;$f|Add-Member NoteProperty NativeVelocityError 0.0}
        $f|Add-Member NoteProperty IssuedClock (Copy-TraversalFixture $issued) -Force
        $priorWall=$walls[$i]
    }
    @($baseline)+@($result)
}
$clockFrames=New-FixedClockFrames
Assert-TraversalFrames $clockFrames '19' 'synthetic-world'
$afterWindow=Copy-TraversalFixture $window;$postFrames=Copy-TraversalFixture $clockFrames
foreach($f in $postFrames){
    $f.Profile|Add-Member NoteProperty NativeMaximumDelta 0.125
    foreach($key in @('Clock','PreviousClock','IssuedClock')){if($null -ne $f.$key){$f.$key.FixedTime+=10;$f.$key.FixedUnscaledTime+=10;$f.$key.Frame+=100;$f.$key|Add-Member NoteProperty MaximumDelta 0.125 -Force}}
}
Assert-TraversalFrames $postFrames '19' 'synthetic-world'
$afterWindow|Add-Member NoteProperty Frames $postFrames;$afterWindow|Add-Member NoteProperty Actuations 2
Assert-TraversalStationaryWindow $afterWindow '19'
Deny-TraversalFixture {$x=Copy-TraversalFixture $afterWindow;$x.Frames[0].Actual[0]=0.002;Assert-TraversalStationaryWindow $x '19'} 'first motor baseline silently rebases original warmup pose'
function Set-TraversalNativePolicyFixture($f){
    $f.Profile|Add-Member NoteProperty NativeAdmissionPolicy 'NATIVE_CURRENT_ROUTE_V1' -Force
    $n=$f.Navigation
    $n|Add-Member NoteProperty AdmissionPolicy 'NATIVE_CURRENT_ROUTE_V1' -Force
    $n|Add-Member NoteProperty DefaultBuilt $true -Force
    $n|Add-Member NoteProperty RouteFilter $false -Force
    $n|Add-Member NoteProperty RoutePolys @('101') -Force
    $p=Copy-TraversalFixture $ready.Navigation.RoutePlan[0]
    $p.From=$n.RouteFrom;$p.To=$n.RouteTo;$p.NativeCorners=$n.Corners;$p.ActorCorners=$n.Corners
    $n|Add-Member NoteProperty RoutePlan @($p) -Force
    $a=Copy-TraversalFixture $certificate
    $a.From=$f.Actual;$a.To=$n.RouteTo;$a.Requested=$f.Requested;$a.Sequence=$f.Clock.Sequence
    $a.NativeCorners=@($f.Actual,$n.RouteTo);$a.ActorCorners=@($f.Actual,$n.RouteTo)
    $a.StartedWall=$f.Clock.WallTime+0.001;$a.CompletedWall=$f.Clock.WallTime+0.002;$a.CheckedWall=$a.CompletedWall
    $n|Add-Member NoteProperty Admission $a -Force
    $f|Add-Member NoteProperty DecisionPublishedWall ($f.Clock.WallTime+0.0025) -Force
}
$certified=@();$issued=0;$nativeClockFixture=Copy-TraversalFixture $clockFrames
foreach($f in $nativeClockFixture){
    if($f.Event -ne 'MOVE_DECISION'){$certified+=,$f;continue}
    Set-TraversalNativePolicyFixture $f;$certified+=,$f
    $called=Copy-TraversalFixture $f;$called.Event='MOVE_ISSUED';$called.NativeResult='ISSUED';$issued++
    $called|Add-Member NoteProperty Actuations $issued;$called|Add-Member NoteProperty WriterCalled $true
    $g=Copy-TraversalFixture $issue.FinalAdmission;$g.Sequence=$f.Clock.Sequence;$g.From=$f.Actual;$g.Requested=$f.Requested
    $g.StartedWall=$f.Clock.WallTime+0.003;$g.CheckedWall=$f.Clock.WallTime+0.004
    $called|Add-Member NoteProperty FinalAdmission $g;$certified+=,$called
}
Assert-TraversalFrames $certified '19' 'synthetic-world'
Deny-TraversalFixture {Assert-TraversalFrames @($certified|Where-Object Event -ne 'MOVE_ISSUED') '19' 'synthetic-world'} 'new native witness without an actual issued command'
$rejected=Copy-TraversalFixture $certified[2];$rejected.Event='MOVE_REJECTED';$rejected.NativeResult='NOT_ISSUED';$rejected.WriterCalled=$false;$rejected.Actuations=0
$rejected.FinalAdmission.Accepted=$false;$rejected.FinalAdmission.FilterAfter=$true
$stopped=Copy-TraversalFixture $rejected;$stopped.Event='BLOCKED';$stopped.Classification='UNKNOWN';$stopped.Reason='NATIVE_ROUTE_CHANGED_BEFORE_WRITER'
$cancelledFrames=@($certified[0],$certified[1],$rejected,$stopped)
Assert-TraversalFrames $cancelledFrames '19' 'synthetic-world'
$cancelledComponents=Copy-TraversalFixture @{Status='PARTIAL';Actor=@{NetId='19'};Traversal=@{Frames=$cancelledFrames;Scenes=@();World='synthetic-world';Completed=$false;Actuations=0;
    Components=@(@{Type='UnityEngine.CapsuleCollider';Instance=10;Collider=@{enabled=$true;isTrigger=$false;Scale=@(1,1,1)}},
        @{Type='UnityEngine.Rigidbody';Instance=11},@{Type='NPCPlayerNavigator';Instance=12;Enabled=$false},@{Type='Rust.Ai.Gen2.RustNavMeshAgent';Instance=13;Enabled=$true})}}
Assert-TraversalComponents $cancelledComponents
Write-Output 'PASS OFFLINE_ONLY019 issue protocol: intent, post-sink actual issue and next witness; pre-writer rejection has zero actuation and remains valid PARTIAL'
# OFFLINE_ONLY source profile is immutable across a physical stream; one command cannot opt back into legacy validation.
$velocityCertified=Copy-TraversalFixture $certified;$measuredBeforeIssue=@(0,0,0)
foreach($f in $velocityCertified){
    $f.Profile|Add-Member NoteProperty FinalVelocityPolicy 'NATIVE_POST_SINK_VELOCITY_V1'
    if($f.Event -ceq 'MOVE_ISSUED'){$g=$f.FinalAdmission
        foreach($kv in @(@('VelocityPolicy','NATIVE_POST_SINK_VELOCITY_V1'),@('ExpectedVelocity',$measuredBeforeIssue),@('NativeVelocity',$measuredBeforeIssue),@('ExpectedVelocityFinite',$true),@('NativeVelocityFinite',$true),@('VelocityError',0),@('VelocityMatches',$true),@('VelocityCheckedWall',($g.StartedWall+0.0005)))){$g|Add-Member NoteProperty $kv[0] $kv[1]}
    }
    if($f.Event -ceq 'MOTION_WITNESS'){$measuredBeforeIssue=Get-TraversalPhysicsVelocity $f.Actual $f.From $f.Dt}
}
Assert-TraversalFrames $velocityCertified '19' 'synthetic-world'
foreach($issuedPolicyToo in @($false,$true)){
    $x=Copy-TraversalFixture $velocityCertified;$md=@($x|Where-Object Event -ceq 'MOVE_DECISION')[0];$mi=@($x|Where-Object Event -ceq 'MOVE_ISSUED')[0]
    $md.Profile.PSObject.Properties.Remove('FinalVelocityPolicy');if($issuedPolicyToo){$mi.Profile.PSObject.Properties.Remove('FinalVelocityPolicy')}
    $mi.FinalAdmission.PSObject.Properties.Remove('VelocityPolicy');$mi.FinalAdmission.NativeVelocity=@(0.2,0,0);$mi.FinalAdmission.VelocityError=0.2;$mi.FinalAdmission.VelocityMatches=$false
    Deny-TraversalFixture {Assert-TraversalFrames $x '19' 'synthetic-world'} 'one new-source command opted into historical final-velocity exemption'
}
$velocityCancelled=Copy-TraversalFixture $cancelledFrames;foreach($f in $velocityCancelled){$f.Profile|Add-Member NoteProperty FinalVelocityPolicy 'NATIVE_POST_SINK_VELOCITY_V1'}
$g=$velocityCancelled[2].FinalAdmission|Select-Object Kind,Accepted,Sequence,StartedWall,CheckedWall,From,Requested
$g|Add-Member NoteProperty Error 'DECISION_SINK_REFUSED:Synthetic';$velocityCancelled[2].FinalAdmission=$g;$velocityCancelled[3].FinalAdmission=$g
Assert-TraversalFrames $velocityCancelled '19' 'synthetic-world'
Write-Output 'PASS OFFLINE_ONLY020 source velocity policy: anchored physical stream; uniform legacy/new and truthful no-writer sink cancellation remain valid'
$catchup=Copy-TraversalFixture $clockFrames;$catchup[-1].Clock.WallTime=10.08;$catchup[-1].Time=10.08;$catchup[-1].WallDt=0
Assert-TraversalFrames $catchup '19' 'synthetic-world'
foreach($mutation in @(
    @{Name='missing explicit fixed clock';Change={param($x)$x[2].PSObject.Properties.Remove('Clock')}},
    @{Name='skipped driver fixed update';Change={param($x)$x[2].Clock.Sequence=103}},
    @{Name='fixed time failed to advance';Change={param($x)$x[2].Clock.FixedTime=$x[1].Clock.FixedTime}},
    @{Name='changed issued fixed timestep';Change={param($x)$x[2].Clock.Delta=0.04}},
    @{Name='changed engine time scale';Change={param($x)$x[2].Clock.TimeScale=0.5}},
    @{Name='not a fixed callback';Change={param($x)$x[2].Clock.InFixedStep=$false}},
    @{Name='script-driven physics is unproven';Change={param($x)$x[2].Clock.PhysicsMode='Script'}},
    @{Name='update-driven physics is unproven';Change={param($x)$x[2].Clock.PhysicsMode='Update'}},
    @{Name='wrong issued clock';Change={param($x)$x[2].IssuedClock.Sequence=99}},
    @{Name='unsafe wall gap';Change={param($x)$x[2].Clock.WallTime=10.2;$x[2].Time=10.2}},
    @{Name='wall regressed';Change={param($x)$x[2].Clock.WallTime=10.01;$x[2].Time=10.01}},
    @{Name='wall dt used for physical motion';Change={param($x)$x[4].Dt=0.001}},
    @{Name='false planned decision speed';Change={param($x)$x[1].Speed=0}},
    @{Name='false planned decision acceleration';Change={param($x)$x[1].Acceleration=0}},
    @{Name='native velocity disagrees';Change={param($x)$x[2].Body.Velocity=@(0,0,0)}}
)){$x=Copy-TraversalFixture $clockFrames;& $mutation.Change $x;Deny-TraversalFixture {Assert-TraversalFrames $x '19' 'synthetic-world'} $mutation.Name}
$overAcceleration=@(Copy-TraversalFixture $clockFrames[0])
foreach($index in @(1,2)){
    $template=$clockFrames[$index];$f=New-TraversalFrame $template.Event 1 $template.Time @(0,0,0) @(0.01002,0,0) 0.2004
    $f.Schema=2;$f.Classification='CLEAR'
    foreach($name in @('Clock','PreviousClock','IssuedClock','FixedDt','WallDt')){$f|Add-Member NoteProperty $name $template.$name -Force}
    $f.Dt=0.05;$f.Acceleration=4.008;$f.Distance=0.01002;$f.PreviousTime=$template.PreviousTime;$f.Body|Add-Member NoteProperty Velocity @(0,0,0)
    if($f.Event -eq 'MOVE_DECISION'){$f.Support.Origin=@(0,0.77,0);$f.Support.Center=@(0,0.5,0);$f.Support.Point=@(0,0,0);$f.Support.Hits[0].Point=@(0,0,0)}else{$f.Body.Velocity=@(0.2004,0,0);$f|Add-Member NoteProperty NativeVelocityMatches $true;$f|Add-Member NoteProperty NativeVelocityError 0.0}
    $overAcceleration+=,$f
}
Deny-TraversalFixture {Assert-TraversalFrames $overAcceleration '19' 'synthetic-world'} 'Schema2 acceleration 4.008 exceeds unchanged core limit 4.001'
# Literal native float coordinates, not a tolerance increase: JSON double subtraction
# differs by 3.36e-6 m/s from the original Vector3 float computation.
$from=@(0,5.44947529,-299.999939);$target=@(0,5.441663,-299.999939)
$floatBaseline=New-TraversalFrame 'CLOCK_BASELINE' 0 10 $from $from 0
Set-TraversalClock $floatBaseline 10 1 100;$floatBaseline.Clock.Delta=0.0625;$floatBaseline.Clock.UnscaledDelta=0.0625
$floatBaseline.NativeResult='CLOCK_BASELINE';$floatBaseline.Classification='CLEAR'
$floatBaseline|Add-Member NoteProperty PosePrevious $from;$floatBaseline|Add-Member NoteProperty PosePreviousTime 9.99;$floatBaseline|Add-Member NoteProperty ObservedVelocity @(0,0,0)
$floatFrames=@($floatBaseline);$issued=$null
foreach($event in @('MOVE_DECISION','MOTION_WITNESS')){
    $f=New-TraversalFrame $event 1 $(if($event -eq 'MOVE_DECISION'){10.03}else{10.08}) $from $target 0.125
    Set-TraversalClock $f $f.Time $(if($event -eq 'MOVE_DECISION'){1.0625}else{1.125}) $(if($event -eq 'MOVE_DECISION'){101}else{102})
    $f.Clock.Delta=0.0625;$f.Clock.UnscaledDelta=0.0625;$f.FixedDt=0.0625;$f.Dt=0.0625;$f.Classification='STEP_DOWN';$f.Acceleration=2;$f.Distance=0.0078125
    if($event -eq 'MOVE_DECISION'){
        $f.PreviousClock=$floatBaseline.Clock;$f.WallDt=0.03;$issued=$f.Clock
        $f.Support.Origin=@(0,($from[1]+0.77),$from[2]);$f.Support.Center=@(0,($from[1]+0.5),$from[2]);$f.Support.Point=$from;$f.Support.FootY=$from[1];$f.Support.Hits[0].Point=$from
    }else{$f.PreviousClock=$issued;$f.WallDt=0.05;$f.PreviousTime=10.03;$f.Body.Velocity=@(0,-0.125,0);$f|Add-Member NoteProperty NativeVelocityMatches $true;$f|Add-Member NoteProperty NativeVelocityError 0.0}
    $f|Add-Member NoteProperty IssuedClock $issued;$floatFrames+=,$f
}
Assert-TraversalFrames $floatFrames '19' 'synthetic-world'
#018: independent receipt contracts; these synthetic poses never claim live PhysX.
foreach($gap in @(0.1031844,0.125893,0.1289451)){
    $late=Copy-TraversalFixture $floatFrames
    foreach($f in $late){
        $f.Profile|Add-Member NoteProperty MaxWallStall 1.5
        $f.Profile|Add-Member NoteProperty NativeMaximumDelta 0.125
        $f.Clock|Add-Member NoteProperty MaximumDelta 0.125
        if($null -ne $f.PreviousClock){$f.PreviousClock|Add-Member NoteProperty MaximumDelta 0.125}
        if($null -ne $f.IssuedClock){$f.IssuedClock|Add-Member NoteProperty MaximumDelta 0.125}
    }
    $late[-1].Time=10.03+$gap;$late[-1].Clock.WallTime=$late[-1].Time;$late[-1].WallDt=$gap
    foreach($f in $late){$f|Add-Member NoteProperty WallTelemetry @{CallbackGap=$f.WallDt;ReadDelay=0.0001;MaxWallStall=1.5;NativeMaximumDelta=0.125;NativeCatchupExceeded=($f.WallDt -gt 0.125001);State=$(if($f.WallDt -gt 0.100001){'PHYSICS_CONTIGUOUS_WITH_WALL_LAG'}else{'ON_TIME'})}}
    Assert-TraversalFrames $late '19' 'synthetic-world'
    $catchupLate=Copy-TraversalFixture $late;$catchupLate[-1].Clock.WallTime=10.03;$catchupLate[-1].Time=10.03;$catchupLate[-1].WallDt=0
    $catchupLate[-1].WallTelemetry.CallbackGap=0;$catchupLate[-1].WallTelemetry.State='ON_TIME';$catchupLate[-1].WallTelemetry.NativeCatchupExceeded=$false
    Assert-TraversalFrames $catchupLate '19' 'synthetic-world'
    foreach($mutation in @(
        @{Name='late skipped physics';Change={param($x)$x[-1].Clock.Sequence++}},
        @{Name='late duplicate physics';Change={param($x)$x[-1].Clock.Sequence=$x[1].Clock.Sequence}},
        @{Name='late wrong physics time';Change={param($x)$x[-1].Clock.FixedTime+=0.0625}},
        @{Name='late native velocity';Change={param($x)$x[-1].Body.Velocity=@(0,0,0)}},
        @{Name='late collision';Change={param($x)$x[-1].Overlaps=@(@{Collider=$x[-1].Support.Collider;Intersects=$true;Distance=0.001;Direction=@(1,0,0);Error=$null})}},
        @{Name='late lost support';Change={param($x)$x[-1].Support.Found=$false}},
        @{Name='late changed mode';Change={param($x)$x[-1].Clock.PhysicsMode='Script'}},
        @{Name='late changed time scale';Change={param($x)$x[-1].Clock.TimeScale=0.5}},
        @{Name='late changed watchdog';Change={param($x)$x[-1].Clock.MaximumDelta=1}},
        @{Name='long stall';Change={param($x)$x[-1].Clock.WallTime=11.53001;$x[-1].Time=11.53001;$x[-1].WallDt=1.50001;$x[-1].WallTelemetry.CallbackGap=1.50001}},
        @{Name='slow callback execution';Change={param($x)$x[-1].WallTelemetry.ReadDelay=0.101}},
        @{Name='false wall telemetry';Change={param($x)$x[-1].WallTelemetry.CallbackGap=0.01}},
        @{Name='terminal cannot be witness';Change={param($x)$x[-1].Event='TERMINAL_OBSERVATION';$x[-1].NativeResult='OBSERVED_WALL_LATE'}}
    )){$x=Copy-TraversalFixture $late;& $mutation.Change $x;Deny-TraversalFixture {Assert-TraversalFrames $x '19' 'synthetic-world'} $mutation.Name}
}
Write-Output 'PASS OFFLINE_ONLY018: exact BENCH4/5 lateness with .0625 fixed witness; unsafe late/long/stale/replay rejected'
# OFFLINE_ONLY020: late no-writer STOP is diagnostic evidence, never motion/rest credit.
$refusedPrefix=Copy-TraversalFixture $late
foreach($f in $refusedPrefix){$f|Add-Member NoteProperty RecoveryPolicy 'MEASURED_BRAKE_V1' -Force;$f|Add-Member NoteProperty MotionSession 1 -Force}
$refusal=Copy-TraversalFixture $refusedPrefix[-1]
$refusal.Event='BLOCKED';$refusal.NativeResult='NOT_ISSUED';$refusal.Classification='UNKNOWN';$refusal.Command++
$refusal.Reason='NATIVE_ROUTE_ADMISSION:NATIVE_ROUTE_CHANGED_DURING_CHECK';$refusal.From=$refusal.Actual
$refusal|Add-Member NoteProperty UnobservedCommand $false;$refusal.WallTelemetry.ReadDelay=0.6390147
$finalStop=Copy-TraversalFixture $refusal;$finalStop.Command--;$finalStop.NativeResult='STOPPED';$finalStop.Clock=$null;$finalStop.Reason='RESULT_PARTIAL'
$finalStop.Body.Velocity=@(0,0,0) # A later unclocked snapshot is not an accepted rest witness.
$refusedFrames=@($refusedPrefix)+@($refusal,$finalStop)
Assert-TraversalFrames $refusedFrames '19' 'synthetic-world'
Deny-TraversalFixture {Assert-TraversalTerminalRefusal $refusal $refusedPrefix[-1] @{Command=2} $finalStop $refusedFrames '19'} 'terminal has real pending validator intent'
$refusedResult=Copy-TraversalFixture @{Status='PARTIAL';Traversal=@{Completed=$false;Frames=$refusedFrames}}
Assert-TraversalTerminalResult $refusedResult
foreach($mutation in @(
    @{Name='late decision remains unsafe';Change={param($x)$x[-2].Event='MOVE_DECISION'}},
    @{Name='late issue remains unsafe';Change={param($x)$x[-2].Event='MOVE_ISSUED'}},
    @{Name='late witness remains unsafe';Change={param($x)$x[-2].Event='MOTION_WITNESS'}},
    @{Name='fake terminal native zero';Change={param($x)$x[-2].Body.Velocity=@(0,0,0)}},
    @{Name='terminal has pending command';Change={param($x)$x[-2].UnobservedCommand=$true}},
    @{Name='terminal pending intent';Change={param($x)$x[-2]|Add-Member NoteProperty PendingDecision @{Command=2}}},
    @{Name='terminal changed epoch';Change={param($x)$x[-2].Navigation.TileDataVersion++}},
    @{Name='terminal reordered native sequence';Change={param($x)$x[-2].Clock.Sequence++}},
    @{Name='terminal substituted original body';Change={param($x)$x[-2].Body.Instance++}},
    @{Name='terminal wrong next command';Change={param($x)$x[-2].Command++}},
    @{Name='terminal changed session';Change={param($x)$x[-2].MotionSession++}},
    @{Name='terminal actual pose changed';Change={param($x)$x[-2].Actual[0]+=0.01}},
    @{Name='terminal unbounded delay';Change={param($x)$x[-2].WallTelemetry.ReadDelay=1.6}},
    @{Name='terminal future writer';Change={param($x)$x[-1].Event='MOVE_ISSUED'}},
    @{Name='terminal future arrival';Change={param($x)$x[-1].Event='ARRIVED'}},
    @{Name='terminal future replan';Change={param($x)$x[-1].Event='REPATH_AFTER_REST'}}
)){$x=Copy-TraversalFixture $refusedFrames;& $mutation.Change $x;Deny-TraversalFixture {Assert-TraversalFrames $x '19' 'synthetic-world'} $mutation.Name}
foreach($field in @('Status','Completed')){
    $x=Copy-TraversalFixture $refusedResult;if($field -eq 'Status'){$x.Status='GREEN'}else{$x.Traversal.Completed=$true}
    Deny-TraversalFixture {Assert-TraversalTerminalResult $x} ('terminal cannot claim completed '+$field)
}
$clockRefusal=Copy-TraversalFixture $refusedFrames;$clockRefusal[-2].Reason='CLOCK_AFTER_PROBE:CLOCK_STALE_CALLBACK'
Assert-TraversalFrames $clockRefusal '19' 'synthetic-world'
Write-Output 'PASS OFFLINE_ONLY020 terminal refusal: exact witnessed prefix, no writer/rest/success credit; late physical events and altered context denied'
# Start2 command12: short JSON decimals must restore original Single operands.
$plannedNative=Get-TraversalPhysicsVelocity @(0.07545927,5.37603664,-299.9797) @(0.0452700481,5.37408257,-299.9878) 0.0625
$priorNative=Get-TraversalPhysicsVelocity @(0.0452700481,5.37408257,-299.9878) @(0.02263693,5.372616,-299.9939) 0.0625
Assert-TraversalNear ((Get-WorldDistance $plannedNative $priorNative)/0.0625) 2.00379562 'Start2 command12 native planned acceleration' 0.000001
# Actual command110 stays unsafe, independently of JSON metric repair.
$unsafeNative=Get-TraversalPhysicsVelocity @(5.29136467,5.80301476,-298.582031) @(5.23763275,5.800331,-298.596436) 0.0625
if((Get-WorldDistance $unsafeNative @(0,0,0)) -le [single]([single]0.89+[single]0.001)){throw 'Start2 genuine speed overshoot was hidden'}
$ordered=@(
    @{Kind='OUTDOOR_STEP';Status='PASSED';StartTime=1;EndTime=2},@{Kind='SLOPE_DOWN';Status='PASSED';StartTime=3;EndTime=4},
    @{Kind='SOLID_WALL';Status='BLOCKED';StartTime=5;EndTime=6},@{Kind='DOOR_CLOSED';Status='BLOCKED';StartTime=7;EndTime=8},
    @{Kind='SAFE_DETOUR';Status='PASSED';StartTime=9;EndTime=10},@{Kind='NATIVE_BUILDING_STEP';Status='NOT_PROVEN';StartTime=11;EndTime=12})
Assert-TraversalOutdoorOrder $ordered
Deny-TraversalFixture {Assert-TraversalOutdoorOrder @($ordered[-1])} 'home attempted before outdoor'
Deny-TraversalFixture {Assert-TraversalOutdoorOrder @($ordered[0],$ordered[1],$ordered[3],$ordered[4])} 'detour attempted without solid refusal'
Deny-TraversalFixture {$x=Copy-TraversalFixture $ordered;$x[1].Status='NOT_PROVEN';Assert-TraversalOutdoorOrder $x} 'acquisition cannot unlock negative/home'
$wrongFloat=Copy-TraversalFixture $floatFrames;$wrongFloat[-1].Body.Velocity[1]=-0.12601
Deny-TraversalFixture {Assert-TraversalFrames $wrongFloat '19' 'synthetic-world'} 'native velocity error above .001 remains unsafe'
$wrongNative=Copy-TraversalFixture $floatFrames;$wrongNative[-1].Body.Velocity[1]=-0.123999;$wrongNative[-1].NativeVelocityError=0.001001
Deny-TraversalFixture {Assert-TraversalFrames $wrongNative '19' 'synthetic-world'} 'native float limit cannot be bypassed by JSON double rounding'
Write-Output 'PASS OFFLINE_ONLY clock: fixed issue/witness interval, unequal and catch-up wall intervals, strict native clock and velocity binding'
function Set-AcquisitionFloor($support,$position){
    $support.Origin=@($position[0],($position[1]+0.77),$position[2]);$support.Point=@($position[0],0,$position[2]);$support.Center=@($position[0],0.5,$position[2])
    $support.Distance=$position[1]+0.27;$support.FootY=0;$support.Gap=$position[1];$support.PlaneClearance=$position[1]
    $support.Hits[0].Point=$support.Point;$support.Hits[0].Distance=$support.Distance
    $support.Collider|Add-Member NoteProperty RigidbodyInstance $null -Force;$support.Collider|Add-Member NoteProperty Kinematic $null -Force
    $support.Collider|Add-Member NoteProperty MovingEntity $false -Force;$support.Collider|Add-Member NoteProperty EntityType $null -Force
    $support.Hits[0].Collider=$support.Collider
}
function New-AcquisitionFrames([double]$startGap=0.1) {
    $result=@();$start=@(0,$startGap,0);$position=$start;$previousSpeed=0.0;$time=1.0;$command=0
    $observation=New-TraversalFrame 'FLOOR_ACQUISITION_OBSERVE' 0 $time $start $start 0
    $observation.NativeResult='STATIONARY_OBSERVATION';$observation.Classification='CLEAR';$observation.MotionMode='FLOOR_ACQUISITION';$observation.Sweeps=@()
    $observation|Add-Member NoteProperty PosePrevious $start;$observation|Add-Member NoteProperty PosePreviousTime 0.95;$observation|Add-Member NoteProperty ObservedVelocity @(0,0,0)
    $result+=,$observation
    foreach($speed in @(0.1,0.2,0.2,0.2,0.1,0.0)){
        $command++;$time+=0.1;$target=@(0,($position[1]-$speed*0.1),0)
        foreach($event in @('MOVE_DECISION','MOTION_WITNESS')){
            $f=New-TraversalFrame $event $command $(if($event -eq 'MOVE_DECISION'){$time}else{$time+0.1}) $position $target $speed
            $f.Dt=0.1;$f.PreviousTime=$time;$f.Acceleration=[Math]::Abs($speed-$previousSpeed)/0.1;$f.Classification='CLEAR';$f.MotionMode=if($speed -eq 0){'ACQUISITION_BRAKE_HOLD'}else{'FLOOR_ACQUISITION'}
            $result+=,$f
        }
        $position=$target;$previousSpeed=$speed
    }
    foreach($f in $result){
        Set-AcquisitionFloor $f.Support $f.Actual;Set-AcquisitionFloor $f.Landing $f.Requested
        $f|Add-Member NoteProperty SupportPhase 'FLOOR_ACQUISITION';$f|Add-Member NoteProperty Permission $true;$f|Add-Member NoteProperty WaterDepth (-1.0)
        $f|Add-Member NoteProperty SupportAccepted ($f.Support.Gap -le 0.07);$f|Add-Member NoteProperty OverlapClear $true
        $f|Add-Member NoteProperty LandingPermission $true;$f|Add-Member NoteProperty LandingWaterDepth (-1.0)
        $f|Add-Member NoteProperty LandingSupportAccepted ($f.Landing.Gap -le 0.07)
        $f.Body|Add-Member NoteProperty Velocity @(0,0,0)
        $f|Add-Member NoteProperty Acquisition @{Start=$start;StartTime=1.0;StartGap=$startGap;TotalDrop=($startGap-$f.Actual[1]);FloorId=40;InitialFloorY=0;InitialPoint=@(0,0,0);InitialNormal=@(0,1,0);Remaining=[Math]::Max(0.0,$f.Support.Gap-0.02);RestObservationTime=1.0;RestObservationPose=$start}
    }
    $acquired=Copy-TraversalFixture $result[-1];$acquired.Event='FLOOR_ACQUIRED';$result+=,$acquired
    $result
}
$acquisition=New-AcquisitionFrames
Assert-TraversalFrames $acquisition '19' 'synthetic-world'
$clockAcquisition=Copy-TraversalFixture $acquisition
$acqBaseline=New-TraversalFrame 'CLOCK_BASELINE' 0 0.99 @(0,0.1,0) @(0,0.1,0) 0
$acqBaseline.NativeResult='CLOCK_BASELINE';$acqBaseline.Classification='CLEAR';Set-TraversalClock $acqBaseline 0.99 0.9 90
$acqBaseline.Clock.Delta=0.1;$acqBaseline.Clock.UnscaledDelta=0.1
$acqBaseline|Add-Member NoteProperty PosePrevious @(0,0.1,0);$acqBaseline|Add-Member NoteProperty PosePreviousTime 0.98;$acqBaseline|Add-Member NoteProperty ObservedVelocity @(0,0,0)
$active=$acqBaseline.Clock;$prior=$null;$issued=$null;$priorVelocity=@(0,0,0);$observationClock=$null
foreach($f in $clockAcquisition){
    $physics=[double]$f.Time;$sequence=90+[int][Math]::Round(($physics-0.9)/0.1);$wall=1.0+($sequence-91)*0.001
    Set-TraversalClock $f $wall $physics $sequence;$f.Clock.Delta=0.1;$f.Clock.UnscaledDelta=0.1;$f.FixedDt=0.1
    if($active.Sequence -ne $sequence){$prior=$active;$active=$f.Clock};$f.PreviousClock=Copy-TraversalFixture $prior;$f.WallDt=$wall-$prior.WallTime
    if($f.Event -eq 'FLOOR_ACQUISITION_OBSERVE'){$observationClock=$f.Clock;$f.PosePreviousTime=0.99}
    if($f.Event -eq 'MOVE_DECISION'){$issued=$f.Clock;$f|Add-Member NoteProperty IssuedClock (Copy-TraversalFixture $issued);$f.Body.Velocity=$priorVelocity;$f.Distance=Get-WorldDistance $f.From $f.Requested}
    if($f.Event -in @('MOTION_WITNESS','FLOOR_ACQUIRED')){
        $f.PreviousTime=$issued.WallTime;$f|Add-Member NoteProperty IssuedClock (Copy-TraversalFixture $issued) -Force
        $velocity=@(for($j=0;$j -lt 3;$j++){($f.Actual[$j]-$f.From[$j])/0.1});$f.Body.Velocity=$velocity;$priorVelocity=$velocity
        $f|Add-Member NoteProperty NativeVelocityMatches $true -Force;$f|Add-Member NoteProperty NativeVelocityError 0.0 -Force
    }
    $f.Acquisition|Add-Member NoteProperty RestObservationClock (Copy-TraversalFixture $observationClock)
}
Assert-TraversalFrames (@($acqBaseline)+@($clockAcquisition)) '19' 'synthetic-world'
Deny-TraversalFixture {$x=Copy-TraversalFixture $clockAcquisition;$x[1].Acquisition.RestObservationClock.Sequence=90;Assert-TraversalFrames (@($acqBaseline)+@($x)) '19' 'synthetic-world'} 'acquisition rest native clock changed'
Deny-TraversalFixture {Assert-TraversalFrames (New-AcquisitionFrames 0.21) '19' 'synthetic-world'} 'measured initial native floor gap exceeds MaxDrop'
foreach($mutation in @(
    @{Name='acquisition dynamic floor';Change={param($x)$x[0].Support.Collider.RigidbodyInstance=77}},
    @{Name='acquisition moving door without Rigidbody';Change={param($x)$x[0].Support.Collider.MovingEntity=$true}},
    @{Name='acquisition missing floor';Change={param($x)$x[0].Support.Found=$false}},
    @{Name='acquisition ambiguous floor';Change={param($x)$x[0].Support.Hits+=@($x[0].Support.Hits[0])}},
    @{Name='acquisition changed floor';Change={param($x)$x[2].Support.Collider.Instance=41}},
    @{Name='acquisition excessive drop';Change={param($x)$x[0].Acquisition.StartGap=0.21}},
    @{Name='acquisition lateral motion';Change={param($x)$x[2].Actual[0]=0.01}},
    @{Name='acquisition grew gap';Change={param($x)$x[2].Support.Gap=0.11}},
    @{Name='acquisition penetration';Change={param($x)$x[2].Overlaps=@(@{Collider=$x[2].Support.Collider;Intersects=$true;Distance=0.001;Direction=@(0,1,0);Error=$null;ActorCollider=10;QueryPosition=$x[2].Actual})}},
    @{Name='acquisition permission denied';Change={param($x)$x[1].LandingPermission=$false}},
    @{Name='acquisition water unsafe';Change={param($x)$x[2].WaterDepth=0.151}},
    @{Name='acquisition false native support';Change={param($x)$x[0].SupportAccepted=$true}},
    @{Name='acquisition initial motion';Change={param($x)$x[0].PosePrevious[1]=0.2}},
    @{Name='acquisition false rest';Change={param($x)$x[-1].Speed=0.1}},
    @{Name='acquisition fake height';Change={param($x)$x[-1].Event='STEP_RESOLVED'}},
    @{Name='acquisition ordinary command before floor rest';Change={param($x)$x[-2].SupportPhase='NORMAL'}}
)){$x=Copy-TraversalFixture $acquisition;& $mutation.Change $x;Deny-TraversalFixture {Assert-TraversalFrames $x '19' 'synthetic-world'} $mutation.Name}
$late=Copy-TraversalFixture $acquisition
foreach($f in $late){$f.Time+=10;$f.PreviousTime+=10;$f.Acquisition.StartTime+=10;$f.Acquisition.RestObservationTime+=10;if($f.Event -eq 'FLOOR_ACQUISITION_OBSERVE'){$f.PosePreviousTime+=10}}
Deny-TraversalFixture {Assert-TraversalFrames (@($frames)+@($late)) '19' 'synthetic-world'} 'acquisition after ordinary movement'
$origin=$acquisition[-1].Actual;$target=@(0.009,($origin[1]+0.002),0)
$rebound=New-TraversalFrame 'REPATH' 6 $acquisition[-1].Time $origin $origin 0
$rebound.NativeResult='ROUTE_REBOUND';$rebound.Reason='INITIAL_FLOOR_ACQUISITION_ROUTE_BINDING';$rebound.Classification='CLEAR'
$rebound|Add-Member NoteProperty SupportPhase 'NORMAL'
$ordinary=@()
foreach($event in @('MOVE_DECISION','MOTION_WITNESS')){
    $f=New-TraversalFrame $event 7 $(if($event -eq 'MOVE_DECISION'){1.8}else{1.85}) $origin $target ([Math]::Sqrt(0.000085)/0.05)
    $f.Acceleration=$f.Speed/0.05;$f|Add-Member NoteProperty SupportPhase 'NORMAL'
    if($event -eq 'MOVE_DECISION'){Set-AcquisitionFloor $f.Support $origin}
    $ordinary+=,$f
}
Assert-TraversalFrames (@($acquisition)+@($rebound)+@($ordinary)) '19' 'synthetic-world'
Deny-TraversalFixture {Assert-TraversalFrames (@($acquisition)+@($ordinary)) '19' 'synthetic-world'} 'ordinary movement before actual route rebound'
$acqScene=Copy-TraversalFixture @{Status='PARTIAL';SpawnCount=1;Actor=@{NetId='19';Type='ScientistNPC';Prefab='assets/synthetic/scientist.prefab';IsBasePlayer=$true;IsNpc=$true;HasConnection=$false;NativeBotId=$true};
    Traversal=@{Schema=1;Mode='TRAVERSAL_BENCH';World='synthetic-world';Frames=$acquisition;Actuations=6;Completed=$false;Scenes=@(@{Kind='SLOPE_DOWN';Stage='OUTDOOR';Status='NOT_PROVEN';Reason='SYNTHETIC_ONLY';Start=@(0,0.1,0);End=$origin;StartTime=1;EndTime=1.7;FramesFrom=0;FramesTo=$acquisition.Count})}}
Assert-TraversalSceneResult $acqScene
$acqScene.Traversal.Scenes[0].Status='PASSED'
Deny-TraversalFixture {Assert-TraversalSceneResult $acqScene} 'floor acquisition cannot establish outdoor descent'
Write-Output 'PASS OFFLINE_ONLY acquisition: initial stationary native floor capture, no horizontal/height credit, no ordinary support tolerance change'
# Identical shallow depths cannot distinguish a real step from wall, own foundation side or door hinge.
foreach($kind in @('WALL','OWN_FOUNDATION_SIDE','DOOR_HINGE')){
    foreach($depth in @(0.001,0.011,0.019,0.020)){
        $x=Copy-TraversalFixture $frames
        $c=Copy-TraversalFixture $x[1].Support.Collider;$c.Instance=41;$c.Type='MeshCollider';$c.Entity='100';$c.Prefab='assets/synthetic/solid.prefab'
        $x[1].Overlaps=@([pscustomobject]@{Collider=$c;Intersects=$true;Distance=$depth;Direction=@(1,0,0);Error=$null;SupportTangent=$true;ActorCollider=10;QueryPosition=$x[1].Actual;Kind=$kind;Own=$true})
        Deny-TraversalFixture {Assert-TraversalFrames $x '19' 'synthetic-world'} ($kind+' '+$depth)
    }
}
$x=Copy-TraversalFixture $frames
foreach($w in @($x|Where-Object Event -eq MOTION_WITNESS)){
    $c=Copy-TraversalFixture $w.Support.Collider;$c.Instance=41
    $w.Sweeps[0].Hits=@([pscustomobject]@{Collider=$c;Point=$w.From;Normal=@(1,0,0);Distance=0.001;Blocking=$false;InitialIntersects=$true;InitialDepth=0.011;InitialDirection=@(1,0,0);PlaneClearance=0;SupportTangent=$true})
}
Deny-TraversalFixture {Assert-TraversalFrames $x '19' 'synthetic-world'} 'repeated shallow collisions disguised as support'
$x=Copy-TraversalFixture $frames;$x[1].Support.Point=@(0,0,0);$x[1].Support.Normal=@(0,1,0);$x[1].Support.Center[0]=8
Deny-TraversalFixture {Assert-TraversalFrames $x '19' 'synthetic-world'} 'support from a different landing'
$fake=Copy-TraversalFixture $frames[0];$fake.Event='STEP_RESOLVED'
Deny-TraversalFixture {Assert-TraversalFrames @($fake) '19' 'synthetic-world'} 'flags-only fake resolved step'
$x=Copy-TraversalFixture $frames;$x[1].Event='STEP_RESOLVED'
Deny-TraversalFixture {Assert-TraversalFrames $x '19' 'synthetic-world'} 'predicted pre-sweep replaces actual witness'
$edge=Copy-TraversalFixture $frames[0];$s=$edge.Support;$s.Kind='STEP_EDGE';$s.Normal=@(0.8,0.6,0);$s.Point=@(-0.4,0.2,0)
$s.Hits[0].Normal=$s.Normal;$s.Hits[0].Point=$s.Point
$sourceHit=@{Collider=$s.Collider;Point=@(0,0,0);Normal=@(0,1,0);Distance=0.27}
$topHit=@{Collider=$s.Collider;Point=@(-0.5,0.2,0);Normal=@(0,1,0);Distance=0.07}
$s|Add-Member NoteProperty EdgeSource @{Origin=@(0,0.27,0);Length=0.52;Point=$sourceHit.Point;Normal=$sourceHit.Normal;Distance=0.27;Collider=$s.Collider;Hits=@($sourceHit)}
$s|Add-Member NoteProperty EdgeTop @{Origin=@(-0.5,0.27,0);Length=0.52;Point=$topHit.Point;Normal=$topHit.Normal;Distance=0.07;Collider=$s.Collider;Hits=@($topHit);Direction=@(-1,0,0)}
$edge=Copy-TraversalFixture $edge
# Only the finite edge support receipt is synthetic-positive. This is not a step/motion proof.
Assert-TraversalSupport $edge
foreach($mutation in @(
    @{Name='edge missing top';Change={param($x)$x.Support.EdgeTop=$null}},
    @{Name='edge missing source';Change={param($x)$x.Support.EdgeSource.Hits=@()}},
    @{Name='edge foreign top';Change={param($x)$x.Support.EdgeTop.Collider.Instance=99}},
    @{Name='edge skipped intervening wall';Change={param($x)$h=Copy-TraversalFixture $x.Support.EdgeTop.Hits[0];$h.Point[1]=0.25;$h.Distance=0.02;$h.Normal=@(1,0,0);$x.Support.EdgeTop.Hits=@($h)+$x.Support.EdgeTop.Hits}},
    @{Name='edge vertical wall';Change={param($x)$x.Support.Normal=@(1,0,0)}},
    @{Name='edge arbitrary direction';Change={param($x)$x.Support.EdgeTop.Direction=@(0,1,0)}},
    @{Name='edge unsupported gap';Change={param($x)$x.Support.EdgeSource.Point[1]=-1}},
    @{Name='edge fake top height';Change={param($x)$x.Support.EdgeTop.Point[1]=0.5}}
)){$x=Copy-TraversalFixture $edge;& $mutation.Change $x;Deny-TraversalFixture {Assert-TraversalSupport $x} $mutation.Name}
Write-Output 'PASS OFFLINE_ONLY 2: same 1-20mm wall/own-side/hinge remain blocked, repeated contact and fake step flags rejected'
function New-TraversalEpisode($origin,[double]$time,[int]$command,[string]$stage,[switch]$Down,[switch]$Building,[switch]$Reverse){
    $result=@();$sign=if($Down){-1}else{1};$xsign=if($Reverse){-1}else{1}
    foreach($template in (New-TraversalFrames)){
        $from=@(($origin[0]+$xsign*$template.From[0]),($origin[1]+$sign*$template.From[1]),$origin[2])
        $target=@(($origin[0]+$xsign*$template.Requested[0]),($origin[1]+$sign*$template.Requested[1]),$origin[2])
        $f=New-TraversalFrame $template.Event ($command+$template.Command) ($time+$template.Time) $from $target $template.Speed
        $f.Acceleration=$template.Acceleration;$f.Stage=$stage
        $p=$f.Actual;$f.Support.Origin=@($p[0],($p[1]+0.77),$p[2]);$f.Support.Center=@($p[0],($p[1]+0.5),$p[2]);$f.Support.Point=$p;$f.Support.FootY=$p[1];$f.Support.Hits[0].Point=$p
        if($Down){$f.Classification='STEP_DOWN'}
        if($Building){$f.Support.Collider.Type='MeshCollider';$f.Support.Collider.Entity='100';$f.Support.Collider.Prefab='assets/synthetic/foundation.prefab';$f.Landing.Collider=$f.Support.Collider;$f.Landing.Hits[0].Collider=$f.Support.Collider;$f.Support.Hits[0].Collider=$f.Support.Collider}
        $result+=,$f
    }
    $resolved=Copy-TraversalFixture $result[-1];$resolved.Event='STEP_RESOLVED';$result+=,$resolved
    $position=$result[-1].Actual;$stopTime=$result[-1].Time;$acceleration=$result[-1].Speed/0.1
    foreach($event in @('MOVE_DECISION','MOTION_WITNESS')){
        $f=New-TraversalFrame $event ($command+3) $(if($event -eq 'MOVE_DECISION'){$stopTime}else{$stopTime+0.1}) $position $position 0
        $f.Stage=$stage;$f.Classification='CLEAR';$f.MotionMode='BRAKE_HOLD';$f.Dt=0.1;$f.Acceleration=$acceleration;$f.PreviousTime=$stopTime
        if($Building){$f.Support.Collider.Type='MeshCollider';$f.Support.Collider.Entity='100';$f.Landing.Collider=$f.Support.Collider;$f.Support.Hits[0].Collider=$f.Support.Collider;$f.Landing.Hits[0].Collider=$f.Support.Collider}
        $result+=,$f
    }
    $arrived=Copy-TraversalFixture $result[-1];$arrived.Event='ARRIVED';$result+=,$arrived
    $result
}
function New-TraversalBenchFixture {
    $all=@();$scenes=@();$origin=@(0,0,0)
    $kinds=@('OUTDOOR_STEP','SLOPE_DOWN','NATIVE_BUILDING_STEP')
    for($i=0;$i -lt 3;$i++){
        $episode=@(New-TraversalEpisode $origin ($i*2) ($i*3) $kinds[$i] -Down:($i -eq 1) -Building:($i -eq 2))
        if($i -eq 2){$episode+=@(New-TraversalEpisode $episode[-1].Actual 5 9 'HOME_OUTSIDE' -Down -Building -Reverse)}
        $start=$all.Count;$all+= $episode
        $scenes+=@{Kind=$kinds[$i];Stage=$kinds[$i];Status='PASSED';Reason='SYNTHETIC_ONLY';Start=$origin;End=$episode[-1].Actual;StartTime=$episode[0].Time;EndTime=$episode[-1].Time;FramesFrom=$start;FramesTo=$all.Count}
        $origin=$episode[-1].Actual
    }
    foreach($kind in @('SOLID_WALL','DOOR_CLOSED')){
        $f=New-TraversalFrame 'PHYSICAL_CONTACT' 12 8 $origin $origin 0;$f.Stage=$kind;$f.Classification=if($kind -eq 'DOOR_CLOSED'){'DOOR_CLOSED'}else{'SOLID_BLOCKED'};$f.NativeResult='PROBE_ONLY'
        $f.Requested=@(($origin[0]+0.1),$origin[1],$origin[2]);$f.Sweeps[0].To=$f.Requested;$f.Sweeps[0].Distance=0.1
        $c=Copy-TraversalFixture $f.Support.Collider;$c.Instance=41;$c.Type='MeshCollider';$c.Entity='101';$c.Prefab='assets/synthetic/wall.prefab';$c|Add-Member NoteProperty DoorOpen $(if($kind -eq 'DOOR_CLOSED'){$false}else{$null})
        $f.Sweeps[0].Hits=@([pscustomobject]@{Collider=$c;Point=@(($origin[0]+0.5),($origin[1]+0.5),$origin[2]);Normal=@(-1,0,0);Distance=0.05;Blocking=$true;InitialIntersects=$false;InitialDepth=0;InitialDirection=@(0,0,0);PlaneClearance=0;SupportTangent=$false})
        $start=$all.Count;$all+=,$f;$blocked=Copy-TraversalFixture $f;$blocked.Event='BLOCKED';$all+=,$blocked
        $scenes+=@{Kind=$kind;Stage=$kind;Status='BLOCKED';Reason='SYNTHETIC_ONLY';Start=$origin;End=$origin;StartTime=8;EndTime=8;FramesFrom=$start;FramesTo=$all.Count}
    }
    $closed=@(@{Name='synthetic-hinge';enabled=$true;Center=@(0.0675,0.903,0);Extents=@(0.1,1.1,0.65);Rotation=@(0,0,0,1)})
    $open=@(@{Name='synthetic-hinge';enabled=$true;Center=@(0.5,0.903,0.5);Extents=@(0.65,1.1,0.1);Rotation=@(0,0.7071067811865475,0,0.7071067811865475)})
    foreach($w in @($all|Where-Object {$_.Event -eq 'MOTION_WITNESS' -and $_.Stage -in @('NATIVE_BUILDING_STEP','HOME_OUTSIDE')})){
        $w|Add-Member NoteProperty DoorWitness @{Actor='19';Door='101';Time=$w.Time;Open=$true;Position=@(0.0675,0,0);Colliders=$open}
    }
    Copy-TraversalFixture @{Status='GREEN';SpawnCount=1;Actor=@{NetId='19';Type='ScientistNPC';Prefab='assets/synthetic/scientist.prefab';IsBasePlayer=$true;IsNpc=$true;HasConnection=$false;NativeBotId=$true};
        FirstHome=@{Home=@{Entities=@(@{Role='FOUNDATION';Type='BuildingBlock';NetId='100'},@{Role='DOOR';Type='Door';NetId='101';Position=@(0.0675,0,0);Rotation=@(0,0,0,1)},@{Role='TC';Type='BuildingPrivlidge';NetId='102';Position=@(0.081,0.006,0.5)})};
            Portal=@{DoorNetId='101';Radius=0.5;Height=1.8;LocalCenter=@(0,0.903,0);LocalExtents=@(0.1,1.1,0.65);Scale=@(1,1,1);Center=@(0.0675,0.903,0);Normal=@(1,0,0);Right=@(0,0,1);Up=@(0,1,0);Outside=@(0.054,0,0);Inside=@(0.081,0.006,0);HalfWidth=0.65;HalfHeight=1.1};
            Navigation=@(@{Event='DOOR';Before=$false;After=$true;Requested=$true;Time=4.5;Owner=$true;Authed=$true;LineOfSight=$true;Busy=$false},@{Event='DOOR_COLLIDER';Time=4.6;Changed=$true;Closed=$closed;Open=$open},
                @{Event='CROSSED_IN';Time=5.1;Position=@(0.0675,0.003,0);Open=$true},@{Event='CROSSED_OUT';Time=6.1;Position=@(0.0675,0.003,0);Open=$true},
                @{Event='TC_REACHED';Time=5.3;Position=@(0.081,0.006,0);Range=0.5;LineOfSight=$true},@{Event='DOOR';Before=$true;After=$false;Requested=$false;Time=6.3;Owner=$true;Authed=$true;LineOfSight=$true;Busy=$false})};
        Traversal=@{Schema=1;Mode='TRAVERSAL_BENCH';World='synthetic-world';Frames=$all;Scenes=$scenes;Completed=$true;Actuations=12}}
}
$bench=New-TraversalBenchFixture
$nativeContact=@($bench.Traversal.Frames|Where-Object {$_.Event -eq 'PHYSICAL_CONTACT' -and $_.Stage -eq 'DOOR_CLOSED'})
$h=$nativeContact[0].Sweeps[0].Hits[0]
$targetContact=Copy-TraversalFixture $nativeContact[0]
$targetContact|Add-Member NoteProperty TargetEntity $h.Collider.Entity
Assert-TraversalBlockedContact $targetContact 'DOOR_CLOSED' '19'
$wrongTarget=Copy-TraversalFixture $targetContact;$wrongTarget.TargetEntity='999'
Deny-TraversalFixture {Assert-TraversalBlockedContact $wrongTarget 'DOOR_CLOSED' '19'} 'negative names another intended native target'
# Composite native-plan contract, synthetic only: two physical legs must join at observed rest.
$ep=Copy-TraversalFixture @{Source='OWNED_NATIVE_TEST_FIXTURE';Wall='103';Door='101';Start=@(0,0,2.8);Goal=@(2.8,0,0);Corners=@(@(0,0,2.8),@(2.8,0,2.8),@(2.8,0,0));Status='PathComplete';Length=5.6;DirectLength=[Math]::Sqrt(15.68);
    Legs=@(@{Status='PathComplete';Length=2.8;Corners=@(@(0,0,2.8),@(2.8,0,2.8))},@{Status='PathComplete';Length=2.8;Corners=@(@(2.8,0,2.8),@(2.8,0,0))})}
$ef=Copy-TraversalFixture $exterior
$ef|Add-Member NoteProperty Source 'OWNED_NATIVE_TEST_FIXTURE';$ef|Add-Member NoteProperty Wall '103';$ef|Add-Member NoteProperty Door '101';$ef|Add-Member NoteProperty Foundation '100'
$en=Copy-TraversalFixture @{Actor=@{NetId='19'};FirstHome=@{Home=@{Entities=@(@{Role='FOUNDATION';NetId='100';Position=@(0,0,0);Rotation=@(0,0,0,1)},@{Role='DOOR';NetId='101';Position=@(0,0,-1.5)},@{Role='WALL_N';NetId='103'})}};Traversal=@{Fixture=$ef;Detour=$ep}}
$ec=New-TraversalFrame 'PROBE_REFUSED' 10 9 $ep.Start $ep.Start 0
$ec.Stage='FIXTURE_DIRECT_REFUSAL';$ec.NativeResult='PROBE_ONLY';$ec.Classification='SOLID_BLOCKED';$ec.Requested=@([Math]::Sqrt(2),0,(2.8-[Math]::Sqrt(2)));$ec|Add-Member NoteProperty TargetEntity '103'
$ec.Sweeps[0].To=$ec.Requested;$ec.Sweeps[0].Distance=2
$hc=Copy-TraversalFixture $h.Collider;$hc.Entity='103';$hc.DoorOpen=$null
$ec.Sweeps[0].Hits=@(@{Collider=$hc;Point=@(1.2,0.9,1.5);Normal=@(0,0,1);Distance=1;Blocking=$true;InitialIntersects=$false;InitialDepth=0;InitialDirection=@(0,0,0)})
$ew=@();$last=$ep.Start
foreach($endpoint in @(@(1.4,0,2.8),@(2.8,0,2.8),@(2.8,0,1.4),@(2.8,0,0))){
    $i=$ew.Count;$to=if($i -lt 2){@(2.8,0,2.8)}else{$ep.Goal}
    $ew+=,[pscustomobject]@{From=$last;Actual=$endpoint;Speed=$(if($i%2 -eq 1){0}else{0.8});Navigation=@{RouteTo=$to};
        FixtureDetourWitness=@{Door='101';Open=$false;DoorPosition=@(0,0,-1.5);Foundation='100';LocalPosition=$endpoint;Outside=$true;Plan=$ep}}
    $last=$endpoint
}
$es=[pscustomobject]@{Start=$ep.Start;End=$ep.Goal}
Assert-TraversalExteriorDetour $en $es $ew @($ec)
$badLeg=Copy-TraversalFixture $ew;$badLeg[1].Speed=0.8
Deny-TraversalFixture {Assert-TraversalExteriorDetour $en $es $badLeg @($ec)} 'native exterior leg changed destination before observed rest'
# OFFLINE_ONLY: native read-only aim projection, never physical detour evidence.
$horizontalProbe=[pscustomobject]@{From=@(0,0,0);Requested=@(2,0,0)}
foreach($goal in @(@(4,0,0),@(4,0.7,0),@(4,-0.7,0))){Assert-TraversalDirectProbeAim $horizontalProbe @(0,0,0) $goal}
$aimDenied=0
foreach($case in @(
    @{Requested=@(1.4,0,1.4);Goal=@(4,0.7,0)},
    @{Requested=@(2,0.000001,0);Goal=@(4,0.7,0)},
    @{Requested=@(0,0,0);Goal=@(4,0.7,0)},
    @{Requested=@(2,0,0);Goal=@(0,0.7,0)},
    @{Requested=@(-2,0,0);Goal=@(4,0.7,0)},
    @{Requested=@((2*[Math]::Cos(0.01)),0,(2*[Math]::Sin(0.01)));Goal=@(4,0.7,0)}
)){$probe=[pscustomobject]@{From=@(0,0,0);Requested=$case.Requested};Deny-TraversalFixture {Assert-TraversalDirectProbeAim $probe @(0,0,0) $case.Goal} 'wrong/vertical/zero horizontal aim';$aimDenied++}
Write-Output ('PASS OFFLINE_ONLY direct probe aim: flat/up/down native horizontal projection and '+$aimDenied+' strict azimuth/vertical/zero negatives; full3D route guards unchanged')
$detourBinding=[pscustomobject]@{Door=$h.Collider.Entity;Collider=$h.Collider.Instance;PlanePoint=$h.Point;PlaneNormal=$h.Normal;BoundsCenter=$h.Collider.BoundsCenter;BoundsSize=$h.Collider.BoundsSize}
Assert-TraversalDetourContact $detourBinding $nativeContact
Deny-TraversalFixture {$x=Copy-TraversalFixture $detourBinding;$x.PlanePoint[0]+=1;Assert-TraversalDetourContact $x $nativeContact} 'consistent fabricated detour plane not bound to native negative contact'
# Geometry fixtures intentionally lack an economy ledger and cannot pass the full result gate.
Assert-TraversalSceneResult $bench
Deny-TraversalFixture {Assert-TraversalResult $bench} 'synthetic geometry is not a paid native diagnostic run'
foreach($mutation in @(
    @{Name='nonplayer';Change={param($x)$x.Actor.IsBasePlayer=$false}},
    @{Name='outdoor-only general claim';Change={param($x)$x.Traversal.Scenes=@($x.Traversal.Scenes|Where-Object Kind -ne NATIVE_BUILDING_STEP)}},
    @{Name='no descent';Change={param($x)$x.Traversal.Scenes[1].Status='NOT_PROVEN'}},
    @{Name='scene endpoint fake';Change={param($x)$x.Traversal.Scenes[0].End[1]=1}},
    @{Name='no native building';Change={param($x)$x.FirstHome.Home.Entities=@()}},
    @{Name='closed door is open';Change={param($x)$x.Traversal.Frames[-2].Sweeps[0].Hits[0].Collider.DoorOpen=$true}},
    @{Name='wall only support';Change={param($x)$x.Traversal.Frames[-4].Sweeps[0].Hits[0].Blocking=$false}},
    @{Name='forged scene flags';Change={param($x)$x.Traversal.Frames=@()}},
    @{Name='incomplete actuator count';Change={param($x)$x.Traversal.Actuations=7}},
    @{Name='fake crossed flags';Change={param($x)$x.FirstHome.Navigation=@($x.FirstHome.Navigation|Where-Object Event -ne CROSSED_OUT)}},
    @{Name='narrow native portal';Change={param($x)$x.FirstHome.Portal.LocalExtents[2]=0.4;$x.FirstHome.Portal.HalfWidth=0.4}},
    @{Name='no native hinge movement';Change={param($x)$x.FirstHome.Navigation[1].Open=$x.FirstHome.Navigation[1].Closed}},
    @{Name='closed live door witness';Change={param($x)($x.Traversal.Frames|Where-Object DoorWitness|Select-Object -First 1).DoorWitness.Open=$false}},
    @{Name='no native TC arrival';Change={param($x)$x.FirstHome.Navigation=@($x.FirstHome.Navigation|Where-Object Event -ne TC_REACHED)}},
    @{Name='no native door close';Change={param($x)$x.FirstHome.Navigation=@($x.FirstHome.Navigation|Where-Object {$_.Event -ne 'DOOR' -or $_.Requested})}},
    @{Name='map incomplete';Change={param($x)$x.Traversal.Frames[1]|Add-Member NoteProperty Navigation @{OnNavMesh=$false;PendingTiles=$true;Path='PathPartial'} -Force}}
)){$x=Copy-TraversalFixture $bench;& $mutation.Change $x;Deny-TraversalFixture {Assert-TraversalSceneResult $x} $mutation.Name}
$world=[pscustomobject]@{Kind='PROCEDURAL';Level='Synthetic Map';Seed=17;Size=2000;MapVersion='289';MapSHA256=('A'*64);WipeId='11111111-1111-1111-1111-111111111111'}
$keys=Get-EconomyWorldKeys $world
$partial=Copy-TraversalFixture @{Status='PARTIAL';Mode='BUILD_SMOKE';ManualPositionWrites=0;Persistence=@{Saved=$false;Restored=$false};Conservation=@{EconomicFailure=$false};Harvests=@();Actor=$null;
    FirstHome=@{Schema=1;DiagnosticOnly=$true;SaveReady=$false;NavigationComplete=$false;Fixture=@()};Economy=@{World=$world;WorldKey=$keys.WorldKey};
    Traversal=@{Schema=1;Mode='TRAVERSAL_BENCH';World=$keys.WorldKey;Frames=@();Scenes=@(@{Kind='OUTDOOR_STEP';Status='NOT_PROVEN';Stage='OUTDOOR';Start=@(0,0,0);End=@(0,0,0);StartTime=0;EndTime=0;FramesFrom=0;FramesTo=0});Components=@();Actuations=0;Completed=$false}}
Assert-TraversalResult $partial
$economicPartial=Copy-TraversalFixture $partial
$economicPartial.Actor=Copy-TraversalFixture $bench.Actor
$economicPartial|Add-Member NoteProperty SpawnCount 1
$stock=[pscustomobject]@{Uid='203';Shortname='wood';Amount=10;Condition=0;MaxCondition=0;OwnerNetId='19'}
$economicPartial|Add-Member NoteProperty Recipe @{Ingredients=@()}
$economicPartial|Add-Member NoteProperty StarterKit @()
$economicPartial|Add-Member NoteProperty Inventory @($stock)
$economicPartial.FirstHome|Add-Member NoteProperty Budget @{wood=10}
$economicPartial.FirstHome.Fixture=@([pscustomobject]@{DiagnosticOnly=$true;Source='TEST_FIXTURE_WOOD';Amount=10;Item=$stock})
$economicPartial=Copy-TraversalFixture $economicPartial
Assert-TraversalSmokeBoundary $economicPartial
$unreconciled=Copy-TraversalFixture $economicPartial;$unreconciled.Inventory[0].Amount=133
Deny-TraversalFixture {Assert-TraversalSmokeBoundary $unreconciled} 'partial result inventory differs from final paid ledger'
foreach($mutation in @(
    @{Name='cross-world economy';Change={param($x)$x.Economy.World.Seed=18}},
    @{Name='cross-world frames namespace';Change={param($x)$x.Traversal.World=('B'*64)}},
    @{Name='fixture promoted to natural';Change={param($x)$x.FirstHome.DiagnosticOnly=$false}},
    @{Name='diagnostic restore';Change={param($x)$x.Persistence.Restored=$true}},
    @{Name='diagnostic harvest';Change={param($x)$x.Harvests=@(@{Uid='1'})}},
    @{Name='empty completed partial';Change={param($x)$x.Traversal.Completed=$true}}
)){$x=Copy-TraversalFixture $partial;& $mutation.Change $x;Deny-TraversalFixture {Assert-TraversalResult $x} $mutation.Name}
$inventory=Copy-TraversalFixture $bench
$inventory.Traversal|Add-Member NoteProperty Components @(
    @{Type='UnityEngine.CapsuleCollider';Instance=10;Collider=@{enabled=$true;isTrigger=$false;Scale=@(1,1,1)}},
    @{Type='UnityEngine.Rigidbody';Instance=11},@{Type='NPCPlayerNavigator';Instance=12;Enabled=$false},@{Type='Rust.Ai.Gen2.RustNavMeshAgent';Instance=13;Enabled=$true})
Assert-TraversalComponents $inventory
$refusal=Copy-TraversalFixture $partial
$refusal.Actor=Copy-TraversalFixture $bench.Actor;$refusal|Add-Member NoteProperty SpawnCount 1
$refusal.Traversal.Components=(Copy-TraversalFixture $inventory).Traversal.Components
$blocked=Copy-TraversalFixture $frames[0];$blocked.Event='BLOCKED';$blocked.Classification='UNKNOWN';$blocked.Reason='UNKNOWN_ROUTE_OR_BODY';$blocked.NativeResult='NOT_ISSUED';$blocked.World=$keys.WorldKey
$blocked.Requested=$blocked.Actual;$blocked.Navigation.PendingTiles=$true;$blocked.Navigation.RouteStatus='NOT_CALCULATED';$blocked.Navigation.Corners=@()
$refusal.Traversal.Frames=@($blocked)
Assert-TraversalResult $refusal
$captureRefusal=Copy-TraversalFixture $refusal
$observation=Copy-TraversalFixture $acquisition[0];$observation.World=$keys.WorldKey
$stopped=Copy-TraversalFixture $observation;$stopped.Event='BLOCKED';$stopped.NativeResult='NOT_ISSUED';$stopped.Classification='UNKNOWN';$stopped.Reason='ACQUISITION_FLOOR_CHANGED_BEFORE_COMMAND'
$captureRefusal.Traversal.Frames=@($observation,$stopped)
Assert-TraversalResult $captureRefusal
$clockRefusal=Copy-TraversalFixture $refusal
$clockObservation=Copy-TraversalFixture $clockFrames[0];$clockObservation.World=$keys.WorldKey
$clockStopped=Copy-TraversalFixture $clockObservation;$clockStopped.Event='BLOCKED';$clockStopped.NativeResult='STOPPED';$clockStopped.Classification='UNKNOWN';$clockStopped.Clock=$null;$clockStopped.PreviousClock=$null
$clockRefusal.Traversal.Frames=@($clockObservation,$clockStopped)
Assert-TraversalResult $clockRefusal
foreach($mutation in @(
    @{Name='blocked body changed';Change={param($x)$x.Traversal.Frames[0].Body.Radius=0.3}},
    @{Name='blocked wrong inventory body';Change={param($x)$x.Traversal.Components[0].Instance=99}},
    @{Name='unobserved command is not zero-motion refusal';Change={param($x)$x.Traversal.Frames[0].NativeResult='UNOBSERVED'}},
    @{Name='issued command lacks actual witness';Change={param($x)$x.Traversal.Actuations=1}},
    @{Name='blocked cannot establish completed traversal';Change={param($x)$x.Traversal.Completed=$true}}
)){$x=Copy-TraversalFixture $refusal;& $mutation.Change $x;Deny-TraversalFixture {Assert-TraversalResult $x} $mutation.Name}
foreach($mutation in @({param($x)$x.Traversal.Components[0].Collider.enabled=$false},{param($x)$x.Traversal.Components[1].Instance=99},{param($x)$x.Traversal.Components[2].Enabled=$true})){
    $x=Copy-TraversalFixture $inventory;& $mutation $x;Deny-TraversalFixture {Assert-TraversalComponents $x} 'runtime body inventory replacement'
}
# OFFLINE_ONLY020: component receipt contracts; these cannot establish PhysX/G4.
$buildPlan=Copy-TraversalFixture @{Kind='EXTERIOR_BUILD_PLAN_V1';Label='BUILD_1';PredictedGeometry=$false;ActualGeometry=$true;Accepted=$true;MaxLegs=3;Queries=17;Milliseconds=20;
    FoundationPosition=@(0,0,0);FoundationRotation=@(0,0,0,1);NativeFoundationBounds=@{Center=@(0,0,0);Size=@(3,0.3,3)};Radius=0.5;Skin=0.02;ExteriorMin=@(-2.02,-0.15,-2.02);ExteriorMax=@(2.02,0.15,2.02);
    From=@(0,0,-3);Goal=@(0,0,2.75);Waypoints=@(@(-2.62,0,-2.62),@(-2.62,0,2.62),@(0,0,2.75));Legs=@();Length=0}
$prior=$buildPlan.From
foreach($point in $buildPlan.Waypoints){$length=Get-WorldDistance $prior $point;$buildPlan.Legs+=,[pscustomobject]@{From=$prior;To=$point;Status='PathComplete';Length=$length;Corners=@($prior,$point)};$buildPlan.Length+=$length;$prior=$point}
Assert-TraversalBuildPlan $buildPlan
foreach($case in @(
    @{Name='fourth exterior leg';Change={param($x)$x.Legs+=,$x.Legs[-1];$x.Waypoints+=,$x.Goal}},
    @{Name='native path diagonal cuts foundation';Change={param($x)$x.Legs[1].Corners=@($x.Legs[1].From,@(0,0,0),$x.Legs[1].To)}},
    @{Name='invented waypoint';Change={param($x)$x.Waypoints[0]=@(0,0,0)}},
    @{Name='unbounded native graph queries';Change={param($x)$x.Queries=18}},
    @{Name='unbounded native graph duration';Change={param($x)$x.Milliseconds=501}},
    @{Name='prediction relabelled as actual';Change={param($x)$x.PredictedGeometry=$true}}
)){$x=Copy-TraversalFixture $buildPlan;& $case.Change $x;Deny-TraversalFixture {Assert-TraversalBuildPlan $x} $case.Name}
$buildRows=@();$buildRests=@();$prior=$buildPlan.From
for($i=0;$i -lt 3;$i++){
    $point=$buildPlan.Waypoints[$i];$leg=$i+1;$time=$leg*0.2
    $buildRows+=,[pscustomobject]@{Event='MOVE_ISSUED';Time=($time-0.05);Command=$leg}
    $buildRows+=,[pscustomobject]@{Event='MOTION_WITNESS';Time=$time;Stage=('HOME_BUILD_1_EXTERIOR_'+$leg);From=$prior;Actual=$point;Speed=0;Body=@{Velocity=@(0,0,0)};
        BuildExteriorWitness=@{Stage='BUILD_1';Leg=$leg;Foundation='100';FoundationPosition=@(0,0,0);FoundationRotation=@(0,0,0,1);Outside=$true}}
    $buildRests+=,[pscustomobject]@{Stage='BUILD_1';Leg=$leg;Remaining=(2-$i);Position=$point;NativeVelocity=@(0,0,0);Actuations=$leg;Arrived=$true;Active=$false;Blocked=$false;Time=($time+0.01)};$prior=$point
}
$buildNav=Copy-TraversalFixture @{FirstHome=@{PartialEntities=@(@{Role='FOUNDATION';NetId='100';Position=@(0,0,0);Rotation=@(0,0,0,1)})};Traversal=@{FixturePolicy='MINIMAL_G4_BEFORE_TC_V1';BuildPlans=@($buildPlan);BuildRests=$buildRests;Frames=$buildRows}}
Assert-TraversalBuildRoutes $buildNav
foreach($case in @(
    @{Name='moving waypoint pretends rest';Change={param($x)$x.Traversal.BuildRests[1].NativeVelocity=@(0.1,0,0)}},
    @{Name='small nonzero native velocity is not rest';Change={param($x)$x.Traversal.BuildRests[1].NativeVelocity=@(0.0005,0,0)}},
    @{Name='exterior witness names another foundation';Change={param($x)$x.Traversal.Frames[3].BuildExteriorWitness.Foundation='999'}},
    @{Name='plan and witness shifted away from paid foundation';Change={param($x)$x.Traversal.BuildPlans[0].FoundationPosition=@(0.01,0,0);foreach($f in $x.Traversal.Frames){if($f.BuildExteriorWitness){$f.BuildExteriorWitness.FoundationPosition=@(0.01,0,0)}}}},
    @{Name='missing intermediate rest';Change={param($x)$x.Traversal.BuildRests=@($x.Traversal.BuildRests[0],$x.Traversal.BuildRests[2])}},
    @{Name='next destination precedes rest';Change={param($x)$x.Traversal.BuildRests[0].Time=9}},
    @{Name='foundation changed during leg';Change={param($x)$x.Traversal.Frames[3].BuildExteriorWitness.FoundationPosition=@(1,0,0)}},
    @{Name='predicted plan cannot command actual movement';Change={param($x)$x.Traversal.BuildPlans[0].ActualGeometry=$false;$x.Traversal.BuildPlans[0].PredictedGeometry=$true}}
)){$x=Copy-TraversalFixture $buildNav;& $case.Change $x;Deny-TraversalFixture {Assert-TraversalBuildRoutes $x} $case.Name}
Write-Output 'PASS OFFLINE_ONLY020 exterior build: native corners/footprint/bounds and actual stationary leg joins'

$minimalRows=@();$minimalPlacements=@();$minimalOps=@();$minimalPaid=@{}
foreach($kind in @('CRAFT_TOOL','CRAFT_building.planner','CRAFT_hammer','CRAFT_door.hinged.wood','CRAFT_cupboard.tool')){$minimalPaid[$kind]=$true}
$minimalRoles=@('FOUNDATION','WALL_N','DOORWAY','DOOR')
$doorItem=[pscustomobject]@{Uid='500';Shortname='door.hinged.wood';Amount=1;Condition=0;MaxCondition=0}
$woodItem=[pscustomobject]@{Uid='501';Shortname='wood';Amount=10;Condition=0;MaxCondition=0}
for($i=0;$i -lt $minimalRoles.Count;$i++){
    $role=$minimalRoles[$i];$id=[string](100+$i);$door=$role -ceq 'DOOR';$position=if($role -ceq 'WALL_N'){@(0,0,1.5)}elseif($role -in @('DOORWAY','DOOR')){@(0,0,-1.5)}else{@(0,0,0)}
    $minimalRows+=,[pscustomobject]@{Role=$role;NetId=$id;Type=$(if($door){'Door'}else{'BuildingBlock'});Prefab=('assets/synthetic/'+$role);Owner='15';BuildingId='1';Grade=$(if($door){$null}else{'Wood'});
        Saving=$true;Registered=$true;Support=$true;Health=100;Links=1;Position=$position;Rotation=@(0,0,0,1)}
    $minimalPlacements+=,[pscustomobject]@{Role=$role;Entity=$id;NativeCall='Planner.DoBuild(Construction.Target,Construction)';Parent=$(if($role -ceq 'FOUNDATION'){$null}elseif($door){'102'}else{'100'});
        Socket=$(if($door){'synthetic/doorway-female/1'}elseif($role -ceq 'FOUNDATION'){$null}elseif($role -ceq 'WALL_N'){'synthetic/wall-female/3'}else{'synthetic/wall-female/1'});Before=@($(if($door){$doorItem}else{$woodItem}));After=@()}
    $minimalOps+=,[pscustomobject]@{Kind=('BUILD_'+$role);EntityId=$id;Time=0.5;Before=$minimalPlacements[-1].Before;After=@()};$minimalPaid['BUILD_'+$role]=$true
    if(-not $door){$minimalPaid['UPGRADE_'+$role]=$true;$minimalOps+=,[pscustomobject]@{Kind=('UPGRADE_'+$role);EntityId=$id;Time=0.6}}
}
$minimalStructure=[pscustomobject]@{Owner='15';BuildingId='1';ForeignUnchanged=$true;Entities=$minimalRows}
$minimalNav=Copy-TraversalFixture @{Status='PARTIAL';Actor=@{NetId='19';UserId='15'};FirstHome=@{NativePlacements=$minimalPlacements;Operations=$minimalOps;PartialEntities=$minimalRows;Home=$null;Upkeep=$null;NavigationComplete=$false;Approaches=@()};
    Traversal=@{FixturePolicy='MINIMAL_G4_BEFORE_TC_V1';FixtureForeignUnchanged=$true;Completed=$false;Scenes=@();Fixture=@{Source='OWNED_NATIVE_TEST_FIXTURE';Stage='PAID_MINIMAL_G4';DiagnosticOnly=$true;Structure=$minimalStructure};
        FixtureTransitions=@(@{Event='PAID_MINIMAL_READY';Step=4;NextRole='TC';Time=1;Structure=$minimalStructure;DoorClosed=$true;G4Complete=$false})}}
Assert-TraversalMinimalFixture $minimalNav $minimalPaid
$resumeMinimal=Copy-TraversalFixture $minimalNav
$resumeMinimal.Traversal.Scenes=@(@{Kind='SOLID_WALL';Status='BLOCKED';StartTime=1;EndTime=2},@{Kind='DOOR_CLOSED';Status='BLOCKED';StartTime=2;EndTime=3},@{Kind='SAFE_DETOUR';Status='PASSED';StartTime=3;EndTime=4})
$resumeMinimal.Traversal.FixtureTransitions+=,(Copy-TraversalFixture @{Event='G4_COMPLETE_RESUME_HOME';Step=4;NextRole='TC';Time=4;Structure=$minimalStructure;DoorClosed=$true;G4Complete=$true})
Assert-TraversalMinimalFixture $resumeMinimal $minimalPaid
$missingMinimalPayment=@{};foreach($key in $minimalPaid.Keys){if($key -cne 'UPGRADE_WALL_N'){$missingMinimalPayment[$key]=$true}}
Deny-TraversalFixture {Assert-TraversalMinimalFixture $minimalNav $missingMinimalPayment} 'native Wood wall has no real grade payment'
foreach($case in @(
    @{Name='free/fake placed Door';Change={param($x)$x.FirstHome.NativePlacements[-1].After=@($doorItem)}},
    @{Name='foreign structure';Change={param($x)$x.FirstHome.PartialEntities[1].Owner='999'}},
    @{Name='TC before G4';Change={param($x)$x.Traversal.FixtureTransitions+=,(Copy-TraversalFixture @{Event='G4_COMPLETE_RESUME_HOME';Step=4;NextRole='TC';Time=4;Structure=$minimalStructure;DoorClosed=$true;G4Complete=$true})}},
    @{Name='minimal fixture called full home';Change={param($x)$x.Traversal.Completed=$true}},
    @{Name='G4 flag without native fixture';Change={param($x)$x.Traversal.Fixture=$null}}
)){$x=Copy-TraversalFixture $minimalNav;& $case.Change $x;Deny-TraversalFixture {Assert-TraversalMinimalFixture $x $minimalPaid} $case.Name}
Write-Output 'PASS OFFLINE_ONLY020 minimal fixture: native role/payment bindings, G4-before-TC and no full-home claim from four entities'
# OFFLINE_ONLY component contracts; these synthetic receipts do not prove native payment or movement.
function Set-TraversalFoundationOutputFixture($n){
    if($n.Actor -is [Collections.IDictionary]){$n.Actor['NetId']='19'}else{$n.Actor|Add-Member NoteProperty NetId '19' -Force}
    $row=$n.FirstHome.PartialEntities[0]
    foreach($pair in @(@('Type','BuildingBlock'),@('Prefab','assets/prefabs/building core/foundation/foundation.prefab'),@('BuildingId','99'),@('Grade','Wood'),@('Health',500),@('Stability',1),@('Grounded',$true),@('Support',$true),@('Links',0))){
        if($row -is [Collections.IDictionary]){$row[$pair[0]]=$pair[1]}else{$row|Add-Member NoteProperty $pair[0] $pair[1] -Force}
    }
    $built=Copy-TraversalFixture $row;$costs=@{BUILD_FOUNDATION=@([pscustomobject]@{Shortname='wood';Amount=50});UPGRADE_FOUNDATION=@([pscustomobject]@{Shortname='wood';Amount=200})}
    if($n.Traversal.FoundationAdmission -is [Collections.IDictionary]){$n.Traversal.FoundationAdmission['BuiltFoundation']=$built}else{$n.Traversal.FoundationAdmission|Add-Member NoteProperty BuiltFoundation $built -Force}
    if($n.FirstHome -is [Collections.IDictionary]){$n.FirstHome['GradeCosts']=$costs}else{$n.FirstHome|Add-Member NoteProperty GradeCosts $costs -Force}
    $before=@([pscustomobject]@{Uid='501';Shortname='wood';Amount=500;Condition=0;MaxCondition=0})
    $middle=@([pscustomobject]@{Uid='501';Shortname='wood';Amount=450;Condition=0;MaxCondition=0})
    $after=@([pscustomobject]@{Uid='501';Shortname='wood';Amount=250;Condition=0;MaxCondition=0})
    $n.FirstHome.Operations=@(
        [pscustomobject]@{Kind='BUILD_FOUNDATION';EntityId=$row.NetId;ActorNetId='19';Time=1.21;Before=$before;After=$middle;Costs=$n.FirstHome.GradeCosts.BUILD_FOUNDATION;Output=$null},
        [pscustomobject]@{Kind='UPGRADE_FOUNDATION';EntityId=$row.NetId;ActorNetId='19';Time=1.22;Before=$middle;After=$after;Costs=$n.FirstHome.GradeCosts.UPGRADE_FOUNDATION;Output=$null})
}
function New-FoundationAdmissionFixture {
    $yaw=[Math]::PI/180;$position=@((3*[Math]::Sin($yaw)),0.12,(3*[Math]::Cos($yaw)));$rotation=@(0,[Math]::Sin($yaw/2),0,[Math]::Cos($yaw/2));$eyes=@(0,1.5,0)
    $direction=Get-HomeRelative $position $eyes;$length=Get-WorldDistance $direction @(0,0,0);$direction=@($direction|ForEach-Object{$_/$length})
    $site=@{Position=$position;Rotation=$rotation;HeightRange=1.09;FoundationDepth=2.8;EntryDelta=0.224;OutsideDelta=0.069;NativePreview=$true;
        Water=$false;Topology=0;ForbiddenTopology=16776578;Monument=$false;Road=$false;Foreign=$false;Collision=$false;Permission=$true;Path='PathComplete';
        MonumentOriginDistance=130;MonumentBoundsDistance=10;ForeignDistance=50;RoadDistance=30;PreventBuilding=$false;PrivilegeChecked=$true;PermissionCached=$false;PrivilegeId=$null;
        PathLength=0.1;TravelSeconds=31;DeadlineRemaining=700;PhaseReserve=360}
    $before=Copy-TraversalFixture $site;$before.Rotation=@(0,0,0,1)
    $body=@{Actor='19';Capsules=@(@{Instance=10;Radius=0.5;Height=1.8;Center=@(0,0.9,0);Direction=1;Scale=@(1,1,1);Up=@(0,1,0);Enabled=$true;Trigger=$false;Layer=17;Rigidbody=11});
        Rigidbody=11;Kinematic=$true;Gravity=$false;DetectCollisions=$true;CollisionMode='Discrete';Colliders=@(10);AgentStopped=$true;AgentUpdatePosition=$false;AgentUpdateRotation=$false}
    $clock=@{Schema=2;InFixedStep=$true;PhysicsMode='FixedUpdate';Sequence=100;Frame=100;WallTime=0.9;FixedTime=6.25;FixedUnscaledTime=6.25;Delta=0.0625;UnscaledDelta=0.0625;TimeScale=1;MaximumDelta=0.125}
    $terrain=@{Type='UnityEngine.TerrainCollider';Instance=40;Layer=23;enabled=$true;isTrigger=$false;Self=$false;Center=@(0,-0.5,0);Extents=@(50,0.5,50)}
    $priorTerrain=@{Type='TerrainCollider';Instance=40;Layer=23;Enabled=$true;Trigger=$false;BoundsCenter=@(0,-0.5,0);BoundsSize=@(100,1,100)}
    $rest=@{Event='MOTION_WITNESS';NativeResult='OBSERVED';Command=317;Actor='19';Stage='HOME_SITE';Speed=0;Time=0.9;Actual=@(0,0,0);Clock=$clock;Body=@{Velocity=@(0,0,0)};
        Profile=@{SupportTolerance=0.07};Support=@{Collider=$priorTerrain}}
    $preview=@{Accepted=$true;ValidTarget=$true;ValidPlacements=1;ActorPosition=@(0,0,0);Eyes=$eyes;RayOrigin=$eyes;RayDirection=$direction;Target=$position;Position=$position;Rotation=$rotation}
    $p=@{Policy='ACTUAL_FOUNDATION_READMISSION_V1';Accepted=$true;PrepayAccepted=$true;PreflightAccepted=$true;ReadmissionAccepted=$true;MeasuredRest=$true;ForeignUnchanged=$true;
        NavigationReady=$true;PreviewAccepted=$true;PositionMatched=$true;RotationMatched=$true;PaymentRayMatched=$true;StartedWall=1.0;GateTime=1.1;Reason=$null;
        BeforeSite=$before;AcceptedSite=$site;ActualPosition=@(0,0,0);NativeVelocity=@(0,0,0);Body=$body;LastRestCommand=317;LastRestClock=$clock;LastRestSupport=$rest.Support;
        ActualStand=@{Position=@(0,0,0);NavPoint=@(0,0,0);A=@(0,0.5,0);B=@(0,1.3,0);Sampled=$true;OnNavmesh=$true;Grounded=$true;Clear=$true;WaterDepth=-1;SupportTolerance=0.07;Radius=0.5;Height=1.8;Mask=-1;Triggers='Ignore';Overlaps=@();
            RayHits=@(@{Collider=$terrain;Normal=@(0,1,0);Point=@(0,-0.02,0);Distance=4.02})};
        Preview=$preview;PaymentEyes=$eyes;PaymentTarget=$position;PaymentRayOrigin=$eyes;PaymentRayDirection=$direction;PositionDelta=0;RotationDelta=0;GraphFrom=0;GraphTo=1;
        NativeAttemptTime=1.15;NativeAttemptTarget=$position;BuiltMatched=$true}
    $result=@{Status='PARTIAL';Reason='Continuing native fixture';Actor=@{UserId='19'};Samples=@(@{Time=0});FirstHome=@{Site=$site;Schedule=@{SmokeSeconds=900};
        NativePlacements=@(@{Role='FOUNDATION';NativeCall='Planner.DoBuild(Construction.Target,Construction)';Target=$position;Time=1.2;Entity='100'});
        Operations=@(@{Kind='BUILD_FOUNDATION';Time=1.21});PartialEntities=@(@{Role='FOUNDATION';NetId='100';Owner='19';Saving=$true;Registered=$true;Position=$position;Rotation=$rotation})};
        Traversal=@{Completed=$false;Fixture=$null;FixtureTransitions=@();Scenes=@();DestinationWindows=@();FoundationAdmissionPolicy='ACTUAL_FOUNDATION_READMISSION_V1';FoundationAdmission=$p;Frames=@(@{Event='MOVE_ISSUED';NativeResult='ISSUED';Command=317;Actor='19';Time=0.8375;Clock=@{WallTime=0.8375}},$rest,@{Event='ARRIVED';Command=317;Actor='19';Stage='HOME_SITE';Time=0.9;Clock=$clock});WarmupContract=@{Body=$body};
            BuildPlans=@(@{PredictedGeometry=$true;ActualGeometry=$false;Accepted=$true;Time=1.05;FoundationPosition=$position;FoundationRotation=$rotation})}}
    Set-TraversalFoundationOutputFixture $result
    $result
}
$foundationAdmission=New-FoundationAdmissionFixture
Assert-TraversalFoundationAdmission $foundationAdmission
if((Get-TraversalAdmissionAngle $foundationAdmission.Traversal.FoundationAdmission.BeforeSite.Rotation $foundationAdmission.FirstHome.Site.Rotation) -lt 0.9){throw 'Foundation regression fixture lost its actual-ray yaw change'}
foreach($case in @(
    @{Name='old hinted yaw retained after merely assigning a site';Change={param($x)$x.Traversal.FoundationAdmission.Preview.Rotation=@(0,0,0,1)}},
    @{Name='full fresh admission omitted';Change={param($x)$x.Traversal.FoundationAdmission.ReadmissionAccepted=$false}},
    @{Name='nonzero native velocity';Change={param($x)$x.Traversal.FoundationAdmission.NativeVelocity[0]=0.00001}},
    @{Name='original body changed';Change={param($x)$x.Traversal.FoundationAdmission.Body.Rigidbody=22}},
    @{Name='preview eyes changed independently from payment';Change={param($x)$x.Traversal.FoundationAdmission.Preview.Eyes[0]=0.01}},
    @{Name='preview direction changed independently from payment';Change={param($x)$x.Traversal.FoundationAdmission.Preview.RayDirection[0]+=0.01}},
    @{Name='graph still uses hinted geometry';Change={param($x)$x.Traversal.BuildPlans[0].FoundationRotation=@(0,0,0,1)}},
    @{Name='readmission exceeded half-second budget';Change={param($x)$x.Traversal.FoundationAdmission.GateTime=1.501}},
    @{Name='attempt before actual prepay gate';Change={param($x)$x.Traversal.FoundationAdmission.NativeAttemptTime=1.09}},
    @{Name='attempt native target changed';Change={param($x)$x.Traversal.FoundationAdmission.NativeAttemptTarget[0]+=0.01}},
    @{Name='result before actual native attempt';Change={param($x)$x.FirstHome.NativePlacements[0].Time=1.14}},
    @{Name='payment without immutable prepay acceptance';Change={param($x)$x.Traversal.FoundationAdmission.PrepayAccepted=$false;$x.Traversal.FoundationAdmission.Accepted=$false;$x.Traversal.FoundationAdmission.Reason='FAILED'}}
)){$x=Copy-TraversalFixture $foundationAdmission;& $case.Change $x;Deny-TraversalFixture {Assert-TraversalFoundationAdmission $x} $case.Name}
Write-Output 'PASS OFFLINE_ONLY020 foundation readmission: changed hint requires full fresh native geometry admission; rest/body, exact preview/payment rays, graph and real attempt times bound'
$postpayFoundation=Copy-TraversalFixture $foundationAdmission;$postpayFoundation.Traversal.FoundationAdmission.Accepted=$false;$postpayFoundation.Traversal.FoundationAdmission.Reason='Native Wood upgrade denied after actual placement'
$postpayFoundation.Traversal.FoundationAdmission|Add-Member FailureTime 1.25;$postpayFoundation.Reason='InvalidOperationException: '+$postpayFoundation.Traversal.FoundationAdmission.Reason
$postpayFoundation.FirstHome.Operations=@($postpayFoundation.FirstHome.Operations|Where-Object Kind -ceq 'BUILD_FOUNDATION')
$postpayFoundation.FirstHome.PartialEntities[0].Grade='Twigs';$postpayFoundation.Traversal.FoundationAdmission.BuiltFoundation=$null;$postpayFoundation.Traversal.FoundationAdmission.BuiltMatched=$false
$postpayFoundation.Traversal.Frames+=,[pscustomobject]@{Event='BLOCKED';NativeResult='STOPPED';Clock=$null;Time=[single]1.26;Reason='RESULT_PARTIAL';Body=@{Velocity=@(0,0,0)}}
Assert-TraversalFoundationAdmission $postpayFoundation
$prepayFoundation=Copy-TraversalFixture $postpayFoundation;$prepayFoundation.Traversal.FoundationAdmission.PrepayAccepted=$false;
$prepayFoundation.Traversal.FoundationAdmission.NativeAttemptTime=$null;$prepayFoundation.Traversal.FoundationAdmission.Reason='Full actual site admission denied';$prepayFoundation.FirstHome.NativePlacements=@();$prepayFoundation.FirstHome.Operations=@();$prepayFoundation.FirstHome.PartialEntities=@()
$prepayFoundation.Reason='InvalidOperationException: '+$prepayFoundation.Traversal.FoundationAdmission.Reason
Assert-TraversalFoundationAdmission $prepayFoundation
$changedStandFailure=Copy-TraversalFixture $prepayFoundation;$changedStandFailure.Traversal.FoundationAdmission.NativeVelocity=@(0.1,0,0);$changedStandFailure.Traversal.Frames[-1].Body.Velocity=@(0.1,0,0)
Assert-TraversalFoundationAdmission $changedStandFailure
foreach($case in @(
    @{Name='failed admission called GREEN';Change={param($x)$x.Status='GREEN'}},
    @{Name='failed admission resumed writer';Change={param($x)$x.Traversal.Frames+=,[pscustomobject]@{Event='MOVE_ISSUED';Time=1.27}}},
    @{Name='failed admission began next native role';Change={param($x)$x.FirstHome.NativePlacements+=,[pscustomobject]@{Role='WALL_N';Time=1.24}}},
    @{Name='failed admission created future payment';Change={param($x)$x.FirstHome.Operations+=,[pscustomobject]@{Kind='CRAFT';Time=1.3}}},
    @{Name='failed admission created proven G4 scene';Change={param($x)$x.Traversal.Scenes=@(@{Kind='SAFE_DETOUR';Status='PASSED';EndTime=1.3})}},
    @{Name='failed admission lacks actual no-writer stop';Change={param($x)$x.Traversal.Frames=@($x.Traversal.Frames|Where-Object Event -cne 'BLOCKED')}}
)){$x=Copy-TraversalFixture $postpayFoundation;& $case.Change $x;Deny-TraversalFixture {Assert-TraversalFoundationAdmission $x} $case.Name}
$singleTimeFoundation=Copy-TraversalFixture $foundationAdmission;$singleTimeFoundation.Traversal.FoundationAdmission.NativeAttemptTime=1.2000000001;$singleTimeFoundation.FirstHome.NativePlacements[0].Time=[single]1.2
Assert-TraversalFoundationAdmission $singleTimeFoundation
Write-Output 'PASS OFFLINE_ONLY020 foundation partials: honest terminal refusal, immutable paid prefix, no future writer/build/success and native single-time quantization preserved'
# Accepted=true is the actual completed Wood output, never only prepay permission.
$paidFoundationOutput=Copy-TraversalFixture (New-FoundationAdmissionFixture)
Set-TraversalFoundationOutputFixture $paidFoundationOutput
Assert-TraversalFoundationOutput $paidFoundationOutput $paidFoundationOutput.Traversal.FoundationAdmission
foreach($case in @(
    @{Name='accepted without actual native result';Change={param($x)$x.FirstHome.NativePlacements=@();$x.FirstHome.Operations=@();$x.FirstHome.PartialEntities=@()}},
    @{Name='accepted null native return';Change={param($x)$x.FirstHome.NativePlacements[0].Entity=$null}},
    @{Name='foundation is Door rather than BuildingBlock';Change={param($x)$x.FirstHome.PartialEntities[0].Type='Door'}},
    @{Name='foundation is wrong native prefab';Change={param($x)$x.FirstHome.PartialEntities[0].Prefab='synthetic-other.prefab'}},
    @{Name='accepted Twig before Wood upgrade';Change={param($x)$x.FirstHome.PartialEntities[0].Grade='Twigs'}},
    @{Name='unsupported accepted native foundation';Change={param($x)$x.FirstHome.PartialEntities[0].Stability=0}},
    @{Name='built identity differs from paid result';Change={param($x)$x.Traversal.FoundationAdmission.BuiltFoundation.NetId='999'}},
    @{Name='Wood upgrade has no actual paid operation';Change={param($x)$x.FirstHome.Operations=@($x.FirstHome.Operations|Where-Object Kind -cne 'UPGRADE_FOUNDATION')}},
    @{Name='native payment credited wood';Change={param($x)$x.FirstHome.Operations[1].After[0].Amount=451}},
    @{Name='native upgrade paid for another entity';Change={param($x)$x.FirstHome.Operations[1].EntityId='999'}},
    @{Name='native upgrade price differs from loaded costs';Change={param($x)$x.FirstHome.Operations[1].Costs[0].Amount=199}}
)){$x=Copy-TraversalFixture $paidFoundationOutput;& $case.Change $x;Deny-TraversalFixture {Assert-TraversalFoundationOutput $x $x.Traversal.FoundationAdmission} $case.Name}
$twigPartial=Copy-TraversalFixture $paidFoundationOutput;$twigPartial.Traversal.FoundationAdmission.Accepted=$false
$twigPartial.FirstHome.PartialEntities[0].Grade='Twigs';$twigPartial.FirstHome.Operations=@($twigPartial.FirstHome.Operations|Where-Object Kind -ceq 'BUILD_FOUNDATION')
Assert-TraversalFoundationOutput $twigPartial $twigPartial.Traversal.FoundationAdmission
Write-Output 'PASS OFFLINE_ONLY020 foundation output: accepted native Wood entity, actual build/upgrade UID debits and loaded costs; honest postpay Twig partial retained'
# Actual START4 shape: instant native cachedStability0 is not a support witness.
$instantFoundation=Copy-TraversalFixture (New-FoundationAdmissionFixture)
$instantFoundation.Traversal.FoundationAdmission.BuiltFoundation.Stability=0;$instantFoundation.Traversal.FoundationAdmission.BuiltFoundation.Support=$false
Assert-TraversalFoundationAdmission $instantFoundation
foreach($case in @(
    @{Name='final unsupported foundation remains rejected';Change={param($x)$x.FirstHome.PartialEntities[0].Stability=0;$x.FirstHome.PartialEntities[0].Support=$false}},
    @{Name='instant native support flag contradicts zero cache';Change={param($x)$x.Traversal.FoundationAdmission.BuiltFoundation.Support=$true}},
    @{Name='instant native stability cache is invalid';Change={param($x)$x.Traversal.FoundationAdmission.BuiltFoundation.Stability=-1}}
)){$x=Copy-TraversalFixture $instantFoundation;& $case.Change $x;Deny-TraversalFixture {Assert-TraversalFoundationAdmission $x} $case.Name}
Write-Output 'PASS OFFLINE_ONLY020 native snapshots: immediate zero cache grants no support credit; final native support and all paid identity/geometry/debit guards remain mandatory'
# This group protects actual current query shape and the latest closed rest prefix.
foreach($case in @(
    @{Name='substituted capsule endpoints';Change={param($x)$x.Traversal.FoundationAdmission.ActualStand.A=@(100,100,100)}},
    @{Name='missing full capsule endpoint';Change={param($x)$x.Traversal.FoundationAdmission.ActualStand.B=$null}},
    @{Name='current support disabled trigger';Change={param($x)$x.Traversal.FoundationAdmission.ActualStand.RayHits[0].Collider.enabled=$false;$x.Traversal.FoundationAdmission.ActualStand.RayHits[0].Collider.isTrigger=$true}},
    @{Name='current support negative bounds';Change={param($x)$x.Traversal.FoundationAdmission.ActualStand.RayHits[0].Collider.Extents[1]=-0.5}},
    @{Name='current support bounds changed';Change={param($x)$x.Traversal.FoundationAdmission.ActualStand.RayHits[0].Collider.Center[1]+=0.01}},
    @{Name='nonvertical actual support ray';Change={param($x)$x.Traversal.FoundationAdmission.ActualStand.RayHits[0].Distance=3.9}},
    @{Name='old rest masks latest moving witness';Change={param($x)$w=Copy-TraversalFixture $x.Traversal.Frames[1];$w.Command=318;$w.Speed=0.1;$w.Clock.WallTime=0.95;$w.Time=0.95;$x.Traversal.Frames+=,@{Event='MOVE_ISSUED';Command=318;Actor='19';Clock=@{WallTime=0.925};Time=0.925};$x.Traversal.Frames+=,$w}},
    @{Name='rest followed by pending writer';Change={param($x)$x.Traversal.Frames+=,@{Event='MOVE_ISSUED';Command=318;Actor='19';Clock=@{WallTime=1.01};Time=1.01}}},
    @{Name='rest without actual arrived controller';Change={param($x)$x.Traversal.Frames=@($x.Traversal.Frames|Where-Object Event -cne 'ARRIVED')}},
    @{Name='rest from another actor';Change={param($x)$x.Traversal.Frames[1].Actor='999'}},
    @{Name='double predicted graph occurs after gate';Change={param($x)$x.Traversal.BuildPlans[0].Time=$x.Traversal.FoundationAdmission.GateTime+0.00000001}}
)){$x=Copy-TraversalFixture $foundationAdmission;& $case.Change $x;Deny-TraversalFixture {Assert-TraversalFoundationAdmission $x} $case.Name}
$unpaidEntity=Copy-TraversalFixture $prepayFoundation;$unpaidEntity.FirstHome.PartialEntities=@(Copy-TraversalFixture $foundationAdmission.FirstHome.PartialEntities[0])
Deny-TraversalFixture {Assert-TraversalFoundationAdmission $unpaidEntity} 'failed prepay gate nevertheless contains native entity'
Write-Output 'PASS OFFLINE_ONLY020 foundation current geometry/latest rest: original full capsule, current enabled nontrigger terrain bounds, exact ray, latest arrived zero/writer closure, double graph time and no unpaid entity'
Write-Output 'PASS OFFLINE_ONLY 3: independent scenes, exact native portal/door/TC, components, map/wipe and diagnostic boundaries; synthetic geometry cannot establish live GREEN'
# PreflightOnly also prevents a live start if a selector regression bypasses the early refusal.
$info=New-Object Diagnostics.ProcessStartInfo
$info.FileName=Join-Path $PSHOME 'powershell.exe'
$info.Arguments='-NoProfile -ExecutionPolicy Bypass -File "'+(Join-Path $PSScriptRoot 'Invoke-NavigationProbe.ps1')+'" -TraversalBench -RestoreFrom 00000000000000000000000000000000 -PreflightOnly'
$info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
$process=[Diagnostics.Process]::Start($info)
try{
    $output=$process.StandardOutput.ReadToEnd()+$process.StandardError.ReadToEnd();$process.WaitForExit()
    if($process.ExitCode -eq 0 -or $output -notmatch 'TraversalBench cannot restore or combine scenario selectors'){throw 'TraversalBench restore selector did not fail before runtime initialization'}
}finally{$process.Dispose()}
Write-Output 'PASS OFFLINE_ONLY: TraversalBench restore selector refused before runtime initialization'
