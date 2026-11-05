#Requires -Version 5.1
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
$frames=New-TraversalFrames
Assert-TraversalFrames $frames '19' 'synthetic-world'
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
