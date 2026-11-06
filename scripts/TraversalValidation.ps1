#Requires -Version 5.1
# Pure receipt validation. No synthetic receipt proves native collision resolution.
. (Join-Path $PSScriptRoot 'FirstHomeValidation.ps1')
function Get-TraversalNumber($value,[string]$name){Get-AvatarNumber $value ('traversal '+$name)}
function Assert-TraversalNear($actual,$expected,[string]$name,[double]$tolerance=0.001){
    if([Math]::Abs((Get-TraversalNumber $actual $name)-$expected) -gt $tolerance){throw ('Inconsistent traversal '+$name)}
}
function Assert-TraversalVector($value,[int]$count=3){
    if(@($value).Count -ne $count){throw 'Missing traversal vector'}
    foreach($v in $value){$null=Get-TraversalNumber $v 'vector'}
}
function Get-TraversalDot($a,$b){Assert-TraversalVector $a;Assert-TraversalVector $b;[double]$a[0]*$b[0]+[double]$a[1]*$b[1]+[double]$a[2]*$b[2]}
function Assert-TraversalSamePoint($a,$b,[string]$name){
    Assert-TraversalVector $a;Assert-TraversalVector $b
    if((Get-WorldDistance $a $b) -gt 0.001){throw ('Unbound traversal '+$name)}
}
function Assert-TraversalBrakeFloor($c,$r){
    if($c.Instance -ne $r.Floor -or $c.MovingEntity -isnot [bool] -or $c.MovingEntity -or
        $null -eq $c.PSObject.Properties['RigidbodyInstance'] -or $null -ne $c.RigidbodyInstance){throw 'Braking support changed or is not static'}
    foreach($key in @('Instance','Type','Entity','EntityType','Prefab','Owner','Enabled','Trigger','Layer','RigidbodyInstance','Kinematic','MovingEntity')){
        if([string]$c.$key -cne [string]$r.FloorCollider.$key){throw ('Braking original floor fingerprint changed: '+$key)}
    }
    Assert-TraversalSamePoint $c.BoundsCenter $r.FloorCenter 'braking floor bounds'
    Assert-TraversalSamePoint $c.BoundsSize $r.FloorSize 'braking floor size'
}
function Assert-TraversalBrakeCorridor($f,$prior){
    $r=$f.Recovery;$parts=@($r.Corridor);$dt=Get-TraversalNumber $f.Clock.Delta 'braking interval'
    if($dt -le 0 -or $dt -gt 0.1 -or $parts.Count -lt 2 -or $parts.Count -gt 9){throw 'Unbounded/missing braking corridor'}
    $speed=Get-WorldDistance $prior @(0,0,0)
    $required=$speed*$speed/(2*3)+$speed*$dt+$f.Profile.Skin
    Assert-TraversalNear $r.RequiredDistance $required 'required braking envelope'
    $position=$f.From;$velocity=$prior;$length=0.0;$stopped=$false
    for($i=0;$i -lt $parts.Count;$i++){
        $p=$parts[$i]
        Assert-TraversalSamePoint $p.From $position 'projected braking chain'
        Assert-TraversalVector $p.Requested
        $view=[pscustomobject]@{Actual=$p.From;From=$p.From;Requested=$p.Requested;Profile=$f.Profile;
            Body=@{A=@($p.From[0],($p.From[1]+0.5),$p.From[2]);Instance=$f.Body.Instance};Support=$p.Support;
            Overlaps=$p.Overlaps;Sweeps=$p.Sweeps;Landing=$p.Landing;LandingOverlaps=$p.LandingOverlaps;
            Permission=$p.Permission;WaterDepth=$p.WaterDepth;SupportAccepted=$p.SupportAccepted;OverlapClear=$p.OverlapClear;
            LandingPermission=$p.LandingPermission;LandingWaterDepth=$p.LandingWaterDepth;LandingSupportAccepted=$p.LandingSupportAccepted}
        Assert-TraversalSupport $view;Assert-AcquisitionPolicy $view;Assert-TraversalContacts $view
        Assert-TraversalSweeps $view $p.Requested;Assert-TraversalLanding $view
        foreach($s in @($p.Support,$p.Landing)){
            Assert-TraversalBrakeFloor $s.Collider $r
        }
        $length+=Get-WorldDistance $p.From $p.Requested
        if($i -eq $parts.Count-1){
            if($p.Kind -cne 'RESERVE' -or -not $stopped){throw 'Braking corridor lacks supported stopping reserve'}
            $delta=Get-HomeRelative $p.Requested $p.From
            if((Get-TraversalDot $delta $prior) -lt -0.000001){throw 'Braking reserve reversed direction'}
            $reserve=[Math]::Max(0.0,$required-($length-(Get-WorldDistance $p.From $p.Requested)))+0.001
            $expected=@(for($j=0;$j -lt 3;$j++){$p.From[$j]+$prior[$j]/$speed*$reserve})
            Assert-TraversalSamePoint $p.Requested $expected 'braking reserve along measured momentum'
        }else{
            if($p.Kind -cne 'DECELERATION' -or $stopped){throw 'Invalid projected braking phase'}
            Assert-TraversalNear $p.Dt $dt 'projected braking dt' 0.000001
            Assert-TraversalSamePoint $p.PriorVelocity $velocity 'projected measured prior velocity'
            $next=Get-TraversalPhysicsVelocity $p.Requested $p.From $dt
            Assert-TraversalSamePoint $p.Velocity $next 'projected velocity'
            $before=Get-WorldDistance $velocity @(0,0,0);$after=Get-WorldDistance $next @(0,0,0)
            $target=[Math]::Max(0.0,$before-3*$dt)
            $expected=@(for($j=0;$j -lt 3;$j++){$velocity[$j]*$target/$before})
            Assert-TraversalSamePoint $next $expected 'three-dimensional measured deceleration axis'
            if($after -gt $f.Profile.MaxSpeed+0.001 -or $after -ge $before -or
                (Get-WorldDistance $next $velocity)/$dt -gt 4.001 -or (Get-TraversalDot $next $prior) -lt -0.000001){throw ('Unsafe projected braking kinetics: '+$before+' -> '+$after+'; acceleration='+((Get-WorldDistance $next $velocity)/$dt))}
            $velocity=$next;$stopped=$after -eq 0
        }
        $position=$p.Requested
    }
    if(($parts.Count-1)*$dt -gt 1 -or $length+0.001 -lt $required){throw 'Insufficient/unbounded supported braking distance'}
    Assert-TraversalSamePoint $parts[0].Requested $f.Requested 'issued first braking segment'
}
function Assert-TraversalRecovery($frames){
    $enabled=@($frames|Where-Object {$_.RecoveryPolicy -ceq 'MEASURED_BRAKE_V1' -or $null -ne $_.Recovery -or $_.MotionMode -ceq 'ACTUAL_BRAKE'}).Count
    if(-not $enabled){return} # Historical receipts retain their original contract and PARTIAL classification.
    $prior=$null;$state=$null;$intent=$null;$issued=$false;$announced=$false;$witnessed=$null;$rest=$false;$used=@{};$terminal=$false;$baselineSession=0
    foreach($f in @($frames)){
        if($f.Schema -eq 2 -and $f.Event -eq 'CLOCK_BASELINE' -and $f.RecoveryPolicy -ceq 'MEASURED_BRAKE_V1'){
            $session=Get-TraversalNumber $f.MotionSession 'clock-bound motion session'
            if($session -ne $baselineSession+1 -or $null -ne $state -or $null -ne $intent -or $null -ne $prior -and $prior.Speed -ne 0){throw 'New motion session lacks observed rest and next native baseline'}
            if($null -ne $prior){Assert-TraversalSamePoint $f.Actual $prior.Actual 'new session measured rest pose'}
            $baselineSession=$session
        }
        if($f.Schema -eq 2 -and $f.Event -in @('MOVE_DECISION','MOVE_ISSUED','MOTION_WITNESS','BRAKE_REQUESTED') -and
            ($f.RecoveryPolicy -ceq 'MEASURED_BRAKE_V1' -or $null -ne $f.Recovery -or $f.MotionMode -ceq 'ACTUAL_BRAKE') -and $f.MotionSession -ne $baselineSession){throw 'Motion session changed without native stationary baseline'}
        if($terminal -and $f.Event -in @('MOVE_DECISION','MOVE_ISSUED','BRAKE_ISSUED')){throw 'Motion after unsafe braking STOP'}
        if($f.Event -in @('MOVE_DECISION','MOVE_ISSUED','MOTION_WITNESS') -and ($null -ne $f.Recovery -or $f.MotionMode -ceq 'ACTUAL_BRAKE') -and $null -eq $state){throw 'Orphan braking command/witness omitted its lifecycle'}
        if($f.Event -eq 'BRAKE_REQUESTED'){
            $session=Get-TraversalNumber $f.MotionSession 'motion session'
            if($session -lt 1 -or $session -ne [Math]::Floor($session) -or $used.ContainsKey([string]$session) -or $null -ne $state -or $null -eq $prior -or $prior.Speed -le 0){throw 'Recovery lacks one measured moving trigger per destination'}
            $r=$f.Recovery
            if($r.Kind -cne 'MEASURED_BRAKE_V1' -or $r.Session -ne $session -or $r.Session -ne $prior.MotionSession -or $r.Attempt -ne 1 -or $r.Step -ne 0 -or $r.MaxSteps -ne 8 -or $r.MaxSeconds -ne 1 -or $r.Deceleration -ne 3){throw 'Unbounded/replayed braking contract'}
            Assert-TraversalSamePoint $f.Actual $prior.Actual 'braking trigger pose'
            Assert-TraversalSamePoint $r.StartPosition $prior.Actual 'braking original position'
            $v=Get-TraversalPhysicsVelocity $prior.Actual $prior.From $prior.Dt
            Assert-TraversalSamePoint $r.StartVelocity $v 'braking original measured velocity'
            if($f.Clock.Sequence -ne $prior.Clock.Sequence -or $r.StartSequence -ne $prior.Clock.Sequence){throw 'Braking trigger skipped physics callback'}
            Assert-TraversalNear $r.StartWall $f.Clock.WallTime 'braking start wall' 0.000001
            $state=$r;$used[[string]$session]=$true;$rest=$false;$witnessed=$null;continue
        }
        if($f.Event -eq 'BLOCKED_UNSAFE_BRAKING'){
            if($null -ne $intent -or $null -eq $prior -or $prior.Speed -le 0 -or $f.NativeResult -cne 'NOT_ISSUED'){throw 'Unsafe braking STOP invents a command/rest'}
            Assert-TraversalSamePoint $f.Actual $prior.Actual 'unsafe brake actual pose'
            $state=$null;$terminal=$true;continue
        }
        if($f.Event -in @('REPATH','REPATH_AFTER_REST')){
            if($null -ne $prior -and $prior.Speed -gt 0){throw 'Moving REPATH omitted a checked writer or measured brake'}
            if($f.Event -eq 'REPATH_AFTER_REST'){
                if(-not $rest -or $null -ne $intent -or $null -eq $state){throw 'Replan lacks measured braking rest'}
                $state=$null;$rest=$false
            }
            continue
        }
        if($f.Event -eq 'ACTUAL_REST'){
            if($null -eq $state -or $null -ne $intent -or $null -eq $witnessed -or $witnessed.Speed -ne 0 -or $f.Command -ne $witnessed.Command -or
                $f.Clock.Sequence -ne $witnessed.Clock.Sequence -or $f.Clock.WallTime-$state.StartWall -gt 1){throw 'Synthetic/unobserved/late braking rest'}
            Assert-TraversalSamePoint $f.Actual $witnessed.Actual 'actual rest pose'
            Assert-TraversalSamePoint $f.Body.Velocity @(0,0,0) 'actual native rest'
            if((Get-WorldDistance $f.Body.Velocity @(0,0,0)) -ne 0){throw 'Native rest is not zero'}
            Assert-TraversalSupport $f;Assert-TraversalBrakeFloor $f.Support.Collider $state;$rest=$true;continue
        }
        if($f.Event -eq 'BRAKE_WITNESSED'){
            if($null -eq $state -or $null -eq $prior -or $prior.Command -ne $f.Command -or $null -eq $prior.Recovery -or
                $prior.Clock.Sequence -ne $f.Clock.Sequence){throw 'Unbound brake witness'}
            $witnessed=$prior;continue
        }
        if($f.Event -eq 'BRAKE_ISSUED'){
            if($null -eq $intent -or -not $issued -or $announced -or $f.Command -ne $intent.Command){throw 'Unbound/replayed braking writer'}
            $announced=$true;continue
        }
        if($f.Event -eq 'MOVE_ISSUED' -and $null -ne $state){
            if($null -eq $intent -or $issued -or $f.Command -ne $intent.Command){throw 'Brake issued without new checked intent'}
            $issued=$true;continue
        }
        if($f.Event -eq 'MOVE_REJECTED' -and $null -ne $state){$intent=$null;$state=$null;$terminal=$true;continue}
        if($f.Event -eq 'MOVE_DECISION' -and $null -ne $state){
            if($rest -or $null -ne $intent){throw 'Overlapping brake command or motion before replan'}
            $r=$f.Recovery;$step=if($null -eq $witnessed){1}else{[int]$witnessed.Recovery.Step+1}
            if($null -eq $r -or $r.Kind -cne 'MEASURED_BRAKE_V1' -or $r.Step -ne $step -or $step -gt 8 -or
                $r.MaxSteps -ne 8 -or $r.MaxSeconds -ne 1 -or $r.Attempt -ne 1 -or $r.Deceleration -ne 3 -or
                $r.Session -ne $state.Session -or $r.Session -ne $f.MotionSession -or
                $r.StartSequence -ne $state.StartSequence -or $r.StartWall -ne $state.StartWall -or
                $f.Clock.Sequence -ne $state.StartSequence+$step-1 -or $f.Clock.WallTime-$state.StartWall -gt 1){throw 'Changed/exhausted braking state'}
            Assert-TraversalSamePoint $r.StartVelocity $state.StartVelocity 'retained brake velocity'
            Assert-TraversalSamePoint $r.StartPosition $state.StartPosition 'retained brake origin'
            Assert-TraversalBrakeFloor $r.FloorCollider $state
            Assert-TraversalSamePoint $f.From $prior.Actual 'brake command from measured pose'
            $velocity=Get-TraversalPhysicsVelocity $prior.Actual $prior.From $prior.Dt
            Assert-TraversalSamePoint $f.Body.Velocity $velocity 'brake native prior velocity'
            if($f.Body.Instance -ne $prior.Body.Instance -or $f.Body.RigidbodyInstance -ne $prior.Body.RigidbodyInstance -or
                $f.Navigation.PlannedMesh -cne $prior.Navigation.PlannedMesh -or $f.Navigation.PlannedTileChangeVersion -ne $prior.Navigation.PlannedTileChangeVersion -or
                $f.Navigation.PlannedTileDataVersion -ne $prior.Navigation.PlannedTileDataVersion){throw 'Brake body/route epoch changed'}
            Assert-TraversalBrakeCorridor $f $velocity
            $intent=$f;$issued=$false;$announced=$false;continue
        }
        if($f.Event -eq 'MOTION_WITNESS'){
            if($null -ne $state){
                if($null -eq $intent -or -not $issued -or -not $announced -or $f.Command -ne $intent.Command -or
                    $f.NativeResult -cne 'OBSERVED' -or $f.Clock.Sequence -ne $intent.Clock.Sequence+1 -or $f.Recovery.Step -ne $intent.Recovery.Step){throw 'Missing/out of sequence actual brake witness'}
                Assert-TraversalSamePoint $f.Actual $intent.Requested 'brake actual endpoint'
                Assert-TraversalSamePoint $f.From $intent.From 'brake actual origin'
                Assert-TraversalNear ($f.Clock.FixedTime-$intent.Clock.FixedTime) $intent.Clock.Delta 'brake physical witness horizon' 0.000001
                $v=Get-TraversalPhysicsVelocity $f.Actual $f.From $f.Dt
                $previous=Get-TraversalPhysicsVelocity $prior.Actual $prior.From $prior.Dt
                $speed=Get-WorldDistance $v @(0,0,0);$oldSpeed=Get-WorldDistance $previous @(0,0,0)
                if($speed -ge $oldSpeed -or (Get-WorldDistance $v $previous)/$f.Dt -gt 4.001 -or (Get-TraversalDot $v $previous) -lt -0.000001){throw 'Brake did not physically decelerate within bounds'}
                Assert-TraversalNear $f.Speed $speed 'measured braking speed'
                Assert-TraversalSamePoint $f.Body.Velocity $v 'measured native braking velocity'
                Assert-TraversalBrakeFloor $f.Support.Collider $state
                $intent=$null;$issued=$false;$announced=$false
            }
            $prior=$f
        }
        if($f.Event -eq 'BLOCKED'){$state=$null;$intent=$null;$terminal=$true}
    }
    if($null -ne $state -or $null -ne $intent){throw 'Incomplete braking recovery/rest/replan evidence'}
}
function Assert-TraversalCollider($c){
    $instance=Get-TraversalNumber $c.Instance 'collider instance';$layer=Get-TraversalNumber $c.Layer 'collider layer'
    if($instance -eq 0 -or $instance -ne [Math]::Floor($instance) -or [string]::IsNullOrWhiteSpace([string]$c.Type) -or
        $c.Enabled -isnot [bool] -or -not $c.Enabled -or $c.Trigger -isnot [bool] -or $c.Trigger -or $layer -lt 0 -or $layer -gt 31){throw 'Invalid native traversal collider'}
    Assert-TraversalVector $c.BoundsCenter;Assert-TraversalVector $c.BoundsSize
    foreach($v in $c.BoundsSize){if($v -lt 0){throw 'Invalid traversal collider bounds'}}
}
function Assert-TraversalProfile($p){
    foreach($name in @('MaxStep','MaxDrop','MaxSlope','MaxSpeed','MaxAcceleration','MaxTick','Skin','SupportTolerance','NavClimb','NavSlope','NativeStepCeiling')){
        if((Get-TraversalNumber $p.$name $name) -le 0){throw ('Invalid traversal policy '+$name)}
    }
    Assert-TraversalNear $p.MaxStep ([Math]::Min(0.5,[Math]::Min($p.NavClimb,$p.NativeStepCeiling))) 'step policy'
    Assert-TraversalNear $p.MaxDrop $p.MaxStep 'drop policy'
    Assert-TraversalNear $p.MaxSlope ([Math]::Min(60,$p.NavSlope)) 'slope policy'
    if($p.MaxSpeed -gt 1.2){throw 'Unbounded traversal speed policy'}
    Assert-TraversalNear $p.MaxAcceleration 4 'acceleration policy';Assert-TraversalNear $p.MaxTick 0.1 'tick policy'
    if($p.Skin -gt 0.05){throw 'Unbounded traversal skin'}
    Assert-TraversalNear $p.SupportTolerance ($p.Skin+0.05) 'support policy'
}
function Assert-TraversalBody($f,$expectedActor){
    $b=$f.Body;$p=$f.Actual
    foreach($name in @('Instance','RigidbodyInstance')){if((Get-TraversalNumber $b.$name $name) -eq 0){throw 'Missing native traversal body'}}
    if([string]$b.Actor -cne [string]$expectedActor -or $b.Direction -ne 1 -or $b.Enabled -isnot [bool] -or -not $b.Enabled -or
        $b.Trigger -isnot [bool] -or $b.Trigger -or $b.Kinematic -isnot [bool] -or $b.Gravity -isnot [bool] -or $b.DetectCollisions -isnot [bool] -or -not $b.DetectCollisions -or
        [string]::IsNullOrWhiteSpace([string]$b.CollisionMode) -or $b.AgentStopped -isnot [bool] -or -not $b.AgentStopped -or
        $b.AgentUpdatePosition -isnot [bool] -or $b.AgentUpdatePosition -or $b.AgentUpdateRotation -isnot [bool] -or $b.AgentUpdateRotation){throw 'Unbound body or competing native motion writer'}
    Assert-TraversalNear $b.Radius 0.5 'original radius';Assert-TraversalNear $b.WorldRadius 0.5 'original world radius';Assert-TraversalNear $b.Height 1.8 'original height'
    $layer=Get-TraversalNumber $b.Layer 'original body layer';if($layer -lt 0 -or $layer -gt 31 -or $layer -ne [Math]::Floor($layer)){throw 'Invalid original body collision layer'}
    Assert-TraversalSamePoint $b.Center @(0,0.9,0) 'original center';Assert-TraversalSamePoint $b.Scale @(1,1,1) 'original scale'
    Assert-TraversalSamePoint $b.Position $p 'body pose';Assert-TraversalSamePoint $b.RigidbodyPosition $p 'rigidbody pose'
    Assert-TraversalSamePoint $b.A @($p[0],($p[1]+0.5),$p[2]) 'lower sphere';Assert-TraversalSamePoint $b.B @($p[0],($p[1]+1.3),$p[2]) 'upper sphere'
    Assert-TraversalVector $b.Rotation 4
    $norm=0.0;foreach($v in $b.Rotation){$norm+=$v*$v};Assert-TraversalNear $norm 1 'body quaternion'
    if($b.Rotation[0]*$b.Rotation[0]+$b.Rotation[2]*$b.Rotation[2] -gt 0.00001){throw 'Tilted native body'}
}
function Assert-TraversalRay($ray,$origin,[double]$length,[double]$cosine,[switch]$First,[switch]$Source,[double]$footY){
    Assert-TraversalSamePoint $ray.Origin $origin 'edge ray origin';Assert-TraversalNear $ray.Length $length 'edge ray length'
    $last=-1.0;$selected=$null
    foreach($h in @($ray.Hits)){
        Assert-TraversalCollider $h.Collider;Assert-TraversalVector $h.Point;Assert-TraversalVector $h.Normal
        Assert-TraversalNear (Get-TraversalDot $h.Normal $h.Normal) 1 'edge ray normal'
        $distance=Get-TraversalNumber $h.Distance 'edge ray distance'
        if($distance -lt 0 -or $distance -gt $length -or $distance -lt $last){throw 'Invalid/unsorted edge native ray hits'}
        Assert-TraversalSamePoint $h.Point @($origin[0],($origin[1]-$distance),$origin[2]) 'edge ray native point'
        if($null -eq $selected -and ($First -or ($h.Normal[1] -ge $cosine -and (-not $Source -or $h.Point[1] -le $footY+0.001)))){$selected=$h}
        $last=$distance
    }
    if($null -eq $selected){throw 'Missing actual source/top edge ray hit'}
    Assert-TraversalSamePoint $ray.Point $selected.Point 'selected edge ray point';Assert-TraversalSamePoint $ray.Normal $selected.Normal 'selected edge ray normal'
    Assert-TraversalNear $ray.Distance $selected.Distance 'selected edge ray distance'
    if($ray.Collider.Instance -ne $selected.Collider.Instance){throw 'Edge ray selected another collider'}
    if($ray.Normal[1] -lt $cosine){throw 'Vertical wall cannot be a walkable edge top'}
}
function Assert-TraversalEdge($f){
    $s=$f.Support;$p=$f.Profile;$position=$f.Actual;$top=$s.EdgeTop;$source=$s.EdgeSource
    if($s.Normal[1] -le 0){throw 'Vertical wall cannot be a supported step edge'}
    Assert-TraversalVector $top.Direction
    Assert-TraversalNear (Get-TraversalDot $top.Direction $top.Direction) 1 'edge direction'
    Assert-TraversalNear $top.Direction[1] 0 'edge horizontal direction'
    $lift=$p.MaxStep+$p.Skin+0.05;$length=$p.MaxStep+$p.MaxDrop+$p.Skin+0.1;$cosine=[Math]::Cos($p.MaxSlope*[Math]::PI/180)
    Assert-TraversalRay $source @($position[0],($position[1]+$lift),$position[2]) $length $cosine -Source -footY $position[1]
    $topOrigin=@(($position[0]+$top.Direction[0]*0.5),($position[1]+$lift),($position[2]+$top.Direction[2]*0.5))
    Assert-TraversalRay $top $topOrigin $length $cosine -First
    if($top.Collider.Instance -ne $s.Collider.Instance -or $top.Point[1] -le $source.Point[1] -or
        $top.Point[1]-$source.Point[1] -gt $p.MaxStep+0.001 -or $position[1]-$source.Point[1] -gt $p.MaxDrop+$p.SupportTolerance){throw 'Wall/unsupported rise cannot be a step edge'}
    Assert-TraversalNear $top.Point[1] $s.Point[1] 'edge contact/top height'
}
function Assert-TraversalSupport($f,[switch]$Candidate){
    $s=$f.Support;$p=$f.Profile;$a=$f.Body.A
    if($s.Found -isnot [bool] -or -not $s.Found){throw 'Unsupported actual traversal pose'}
    Assert-TraversalCollider $s.Collider
    foreach($name in @('Origin','Point','Normal','Center')){Assert-TraversalVector $s.$name}
    Assert-TraversalNear (Get-TraversalDot $s.Normal $s.Normal) 1 'support unit normal'
    if($s.Kind -notin @('SURFACE','STEP_EDGE')){throw 'Unknown native support geometry'}
    if($s.Kind -eq 'STEP_EDGE'){Assert-TraversalEdge $f}
    elseif($s.Normal[1] -lt [Math]::Cos($p.MaxSlope*[Math]::PI/180)){throw 'Support slope exceeds policy'}
    Assert-TraversalNear $s.Radius 0.5 'support sphere radius'
    Assert-TraversalSamePoint $s.Origin @($a[0],($a[1]+$p.MaxStep+$p.Skin+0.05),$a[2]) 'support origin'
    Assert-TraversalNear $s.Length ($p.MaxStep+$p.MaxDrop+2*$p.Skin+0.1) 'support cast length'
    $distance=Get-TraversalNumber $s.Distance 'support distance'
    if($distance -lt 0 -or $distance -gt $s.Length){throw 'Invalid support cast distance'}
    Assert-TraversalSamePoint $s.Center @($s.Origin[0],($s.Origin[1]-$distance),$s.Origin[2]) 'support center'
    $radial=@(($s.Center[0]-$s.Point[0]),($s.Center[1]-$s.Point[1]),($s.Center[2]-$s.Point[2]))
    Assert-TraversalSamePoint $radial @(($s.Normal[0]*0.5),($s.Normal[1]*0.5),($s.Normal[2]*0.5)) 'sphere contact point'
    Assert-TraversalNear $s.FootY ($s.Center[1]-0.5) 'support foot height'
    Assert-TraversalNear $s.Gap ($a[1]-$s.Center[1]) 'support gap'
    $offset=@(($a[0]-$s.Point[0]),($a[1]-$s.Point[1]),($a[2]-$s.Point[2]))
    Assert-TraversalNear $s.PlaneClearance ((Get-TraversalDot $offset $s.Normal)-0.5) 'support plane clearance'
    $matching=@($s.Hits|Where-Object {$_.Collider.Instance -eq $s.Collider.Instance -and [Math]::Abs($_.Distance-$s.Distance) -le 0.001 -and (Get-WorldDistance $_.Point $s.Point) -le 0.001 -and (Get-WorldDistance $_.Normal $s.Normal) -le 0.001})
    if($matching.Count -ne 1){throw 'Chosen support is absent from actual native cast hits'}
    if(-not $Candidate -and ($s.Gap -lt -0.001 -or $s.Gap -gt $p.SupportTolerance -or $s.PlaneClearance -lt -0.001)){throw 'Unsupported gap/drop or intersecting support plane'}
}
function Assert-TraversalLanding($f,[switch]$Acquisition){
    $probe=$f.Requested;$a=@($probe[0],($probe[1]+0.5),$probe[2]);$s=$f.Landing
    Assert-TraversalSupport ([pscustomobject]@{Actual=$probe;Body=@{A=$a};Profile=$f.Profile;Support=$s}) -Candidate
    $gap=$f.Requested[1]-$s.FootY;$requestA=@($f.Requested[0],($f.Requested[1]+0.5),$f.Requested[2])
    $offset=@(($requestA[0]-$s.Point[0]),($requestA[1]-$s.Point[1]),($requestA[2]-$s.Point[2]));$plane=(Get-TraversalDot $offset $s.Normal)-0.5
    $limit=if($Acquisition){$f.Profile.MaxDrop}else{$f.Profile.SupportTolerance}
    if($gap -lt -0.001 -or $gap -gt $limit -or $plane -lt -0.001){throw 'Unsupported requested landing'}
    if($null -ne $f.PSObject.Properties['LandingPermission']){
        if($f.LandingPermission -isnot [bool] -or -not $f.LandingPermission -or (Get-TraversalNumber $f.LandingWaterDepth 'native landing water depth') -gt 0.15){throw 'Unsafe native landing permission/water'}
        $accepted=$gap -ge -0.001 -and $gap -le $f.Profile.SupportTolerance -and $plane -ge -0.001
        if($f.LandingSupportAccepted -isnot [bool] -or $f.LandingSupportAccepted -ne $accepted){throw 'False native ordinary landing support acceptance'}
    }
    Assert-TraversalContacts ([pscustomobject]@{Actual=$f.Requested;Body=$f.Body;Support=@{Collider=$s.Collider;PlaneClearance=$plane};Overlaps=$f.LandingOverlaps})
}
function Assert-AcquisitionSurface($support,$position,$profile){
    $a=@($position[0],($position[1]+0.5),$position[2])
    Assert-TraversalSupport ([pscustomobject]@{Actual=$position;Body=@{A=$a};Profile=$profile;Support=$support}) -Candidate
    if($support.Kind -cne 'SURFACE' -or @($support.Hits).Count -ne 1 -or
        $null -eq $support.Collider.PSObject.Properties['RigidbodyInstance'] -or $null -ne $support.Collider.RigidbodyInstance -or
        $support.Collider.MovingEntity -isnot [bool] -or $support.Collider.MovingEntity -or
        $support.Gap -lt $profile.Skin-0.001 -or $support.Gap -gt $profile.MaxDrop -or $support.PlaneClearance -lt 0){throw 'Acquisition requires one static unambiguous nearby native floor'}
}
function Assert-AcquisitionPolicy($f){
    if($f.Permission -isnot [bool] -or -not $f.Permission -or (Get-TraversalNumber $f.WaterDepth 'acquisition water depth') -gt 0.15){throw 'Unsafe acquisition native permission/water'}
    $expected=$f.Support.Gap -ge -0.001 -and $f.Support.Gap -le $f.Profile.SupportTolerance -and $f.Support.PlaneClearance -ge -0.001
    if($f.SupportAccepted -isnot [bool] -or $f.SupportAccepted -ne $expected -or $f.OverlapClear -isnot [bool] -or -not $f.OverlapClear){throw 'Acquisition falsified ordinary support/contact acceptance'}
}
function Assert-AcquisitionBinding($f,$state,[switch]$Landing){
    $m=$f.Acquisition;$s=if($Landing){$f.Landing}else{$f.Support};$position=if($Landing){$f.Requested}else{$f.Actual}
    Assert-AcquisitionSurface $s $position $f.Profile
    Assert-TraversalSamePoint $m.Start $state.Start 'acquisition original pose';Assert-TraversalNear $m.StartTime $state.Time 'acquisition start time'
    Assert-TraversalNear $m.StartGap $state.Gap 'acquisition start gap';Assert-TraversalNear $m.RestObservationTime $state.Time 'acquisition observed rest time'
    if($f.Schema -eq 2){Assert-TraversalClockSame $m.RestObservationClock $state.ObservationClock}
    Assert-TraversalSamePoint $m.RestObservationPose $state.Start 'acquisition observed rest pose'
    Assert-TraversalNear $m.InitialFloorY $state.FloorY 'acquisition initial floor height';Assert-TraversalSamePoint $m.InitialNormal $state.Normal 'acquisition initial floor normal'
    Assert-TraversalSamePoint $m.InitialPoint $state.Point 'acquisition initial floor point'
    Assert-TraversalNear $m.TotalDrop ($state.Start[1]-$f.Actual[1]) 'acquisition actual cumulative drop'
    Assert-TraversalNear $m.Remaining ([Math]::Max(0.0,$f.Support.Gap-$f.Profile.Skin)) 'acquisition remaining gap'
    Assert-TraversalNear $position[0] $state.Start[0] 'acquisition unchanged X' 0.0001;Assert-TraversalNear $position[2] $state.Start[2] 'acquisition unchanged Z' 0.0001
    if($m.FloorId -ne $state.FloorId -or $s.Collider.Instance -ne $state.FloorId -or $s.Collider.Type -cne $state.Collider.Type -or
        $s.Collider.Entity -cne $state.Collider.Entity -or $s.Collider.Prefab -cne $state.Collider.Prefab -or $s.Collider.Layer -ne $state.Collider.Layer){throw 'Acquisition floor identity changed'}
    Assert-TraversalSamePoint $s.Point $state.Point 'acquisition fixed floor point';Assert-TraversalSamePoint $s.Normal $state.Normal 'acquisition fixed floor normal'
    Assert-TraversalSamePoint $s.Collider.BoundsCenter $state.Collider.BoundsCenter 'acquisition static floor bounds';Assert-TraversalSamePoint $s.Collider.BoundsSize $state.Collider.BoundsSize 'acquisition static floor size'
    Assert-TraversalNear $s.FootY $state.FloorY 'acquisition fixed floor height'
    $drop=$state.Start[1]-$position[1]
    if($drop -lt -0.0001 -or $drop -gt $f.Profile.MaxDrop -or $s.Gap -gt $state.LastGap+0.001){throw 'Acquisition exceeded cumulative drop or grew floor gap'}
    if($Landing -and ($f.LandingPermission -isnot [bool] -or -not $f.LandingPermission -or (Get-TraversalNumber $f.LandingWaterDepth 'acquisition landing water depth') -gt 0.15)){throw 'Unsafe acquisition landing native permission/water'}
    if($Landing){
        $accepted=$s.Gap -ge -0.001 -and $s.Gap -le $f.Profile.SupportTolerance -and $s.PlaneClearance -ge -0.001
        if($f.LandingSupportAccepted -isnot [bool] -or $f.LandingSupportAccepted -ne $accepted){throw 'Acquisition falsified ordinary landing support acceptance'}
    }
}
function Assert-TraversalSweeps($f,$target){
    $sweeps=@($f.Sweeps)
    if(-not $sweeps.Count -or $sweeps.Count -gt 3){throw 'Missing/unbounded full-body traversal sweep'}
    $from=$f.From
    foreach($s in $sweeps){
        Assert-TraversalSamePoint $s.From $from 'sweep chain'
        Assert-TraversalVector $s.To
        Assert-TraversalSamePoint $s.A @($from[0],($from[1]+0.5),$from[2]) 'swept lower sphere'
        Assert-TraversalSamePoint $s.B @($from[0],($from[1]+1.3),$from[2]) 'swept upper sphere'
        Assert-TraversalNear $s.Radius 0.5 'swept radius'
        if($s.Mask -ne -1 -or $s.Triggers -cne 'Ignore'){throw 'Incomplete swept collision filter'}
        Assert-TraversalNear $s.Distance (Get-WorldDistance $s.From $s.To) 'sweep distance'
        foreach($hit in @($s.Hits)){
            Assert-TraversalCollider $hit.Collider;Assert-TraversalVector $hit.Point;Assert-TraversalVector $hit.Normal
            Assert-TraversalNear (Get-TraversalDot $hit.Normal $hit.Normal) 1 'sweep hit normal'
            $d=Get-TraversalNumber $hit.Distance 'sweep hit distance'
            if($d -lt 0 -or $d -gt $s.Distance+0.001 -or $hit.Blocking -isnot [bool] -or $hit.Blocking -or
                $hit.InitialIntersects -isnot [bool] -or $hit.InitialIntersects){throw 'Solid obstacle in accepted swept movement'}
            # ComputePenetration false leaves out-distance/direction undefined.
            # A nonblocking hit needs geometric support evidence, not an ownership/depth flag.
            $edgeNormal=$f.Support.Kind -eq 'STEP_EDGE' -and (Get-WorldDistance $hit.Normal $f.Support.Normal) -le 0.001
            if($hit.Collider.Instance -ne $f.Support.Collider.Instance -or (-not $edgeNormal -and $hit.Normal[1] -lt [Math]::Cos($f.Profile.MaxSlope*[Math]::PI/180))){
                throw 'Wall/door/side contact disguised as support sweep'
            }
            $plane=@(($s.A[0]-$hit.Point[0]),($s.A[1]-$hit.Point[1]),($s.A[2]-$hit.Point[2]))
            $clearance=(Get-TraversalDot $plane $hit.Normal)-0.5
            Assert-TraversalNear $hit.PlaneClearance $clearance 'initial sweep plane'
            $delta=@(($s.To[0]-$s.From[0]),($s.To[1]-$s.From[1]),($s.To[2]-$s.From[2]))
            if($d -gt 0.001 -or [Math]::Abs($clearance) -gt 0.001 -or (Get-TraversalDot $delta $hit.Normal) -lt -0.00001){throw 'Non-tangent support hit in accepted sweep'}
        }
        $from=$s.To
    }
    Assert-TraversalSamePoint $from $target 'actual sweep endpoint'
}
function Assert-TraversalContacts($f){
    $seen=@{}
    foreach($o in @($f.Overlaps)){
        Assert-TraversalCollider $o.Collider
        if($seen.ContainsKey([string]$o.Collider.Instance) -or $o.Intersects -isnot [bool] -or -not [string]::IsNullOrEmpty([string]$o.Error)){throw 'Invalid/failed native penetration query'}
        $seen[[string]$o.Collider.Instance]=$true
        # No shallow-wall, foundation-owner or hinge exception. An intersection remains unproven.
        if($o.Intersects){throw 'Actual body intersects native geometry'}
        # When false, depth/direction carry no geometric meaning; support and exact query binding remain mandatory.
        if($o.ActorCollider -ne $f.Body.Instance -or $o.Collider.Instance -ne $f.Support.Collider.Instance -or [Math]::Abs($f.Support.PlaneClearance) -gt 0.001){throw 'Non-tangent or unbound overlap'}
        Assert-TraversalSamePoint $o.QueryPosition $f.Actual 'penetration query pose'
    }
}
function Assert-TraversalExactArray($a,$b,[string]$name){
    if(($a|ConvertTo-Json -Depth 30 -Compress) -cne ($b|ConvertTo-Json -Depth 30 -Compress)){throw ('Changed immutable epoch proof '+$name)}
}
function Assert-TraversalEpochSeriesHeader($f,$prior){
    $r=$f.EpochRevalidation
    if($f.Profile.EpochRevalidationPolicy -cne 'SAME_COMMITTED_ROUTE_EPOCH_V2' -or $r.Kind -cne 'SAME_COMMITTED_ROUTE_EPOCH_V2' -or
        $r.Ordinal -lt 1 -or $r.Ordinal -gt 8 -or $r.Ordinal -ne [Math]::Floor($r.Ordinal) -or $r.Attempt -ne $r.Ordinal -or $r.MaxAttempts -ne 8 -or
        $r.BeforeStep -lt 0 -or $r.BeforeStep -ge 8 -or $r.BeforeStep -ne [Math]::Floor($r.BeforeStep) -or $r.NextStep -ne $r.BeforeStep+1 -or
        $r.Ordinal -gt $r.BeforeStep+1 -or $r.PreviousOrdinal -ne $r.Ordinal-1 -or $r.StartsBrake -isnot [bool] -or $r.RecoveryAttempt -ne 1){throw 'Invalid bounded epoch series ordinal/original recovery context'}
    foreach($name in @('PreviousProof','Journal','EpochProofJournal')){if($null -ne $r.PSObject.Properties[$name]){throw 'Recursive epoch history is forbidden'}}
    foreach($key in @('ControlActive','ControlBlocked','ControlArrived','UnobservedTerminal')){if($r.$key -isnot [bool]){throw 'Missing actual proof control state'}}
    if(-not $r.ControlActive -or $r.ControlBlocked -or $r.ControlArrived -or $r.UnobservedTerminal){throw 'Cancelled controller sealed another epoch proof'}
    Assert-TraversalClock $r.BrakeClock $f.Profile
    if($r.Clock.Sequence -ne $r.BrakeClock.Sequence+$r.BeforeStep -or $f.Recovery.Step -ne $r.BeforeStep -or $f.Recovery.Attempt -ne 1 -or
        $f.Recovery.StartSequence -ne $r.BrakeClock.Sequence){throw 'Epoch refresh reset or skipped original brake steps'}
    Assert-TraversalNear (Get-TraversalNumber $f.Recovery.StartWall 'original recovery wall') (Get-TraversalNumber $r.BrakeClock.WallTime 'original brake clock') 'fixed original brake start' 0
    Assert-TraversalExactPoint $r.BrakeOrigin $f.Recovery.StartPosition 'unchanged brake origin';Assert-TraversalExactPoint $r.BrakeVelocity $f.Recovery.StartVelocity 'unchanged original momentum'
    $elapsed=(Get-TraversalNumber $r.Clock.WallTime 'current proof clock')-(Get-TraversalNumber $r.BrakeClock.WallTime 'original brake wall')
    $fixed=(Get-TraversalNumber $r.Clock.FixedTime 'current proof fixed')-(Get-TraversalNumber $r.BrakeClock.FixedTime 'original brake fixed')
    if($elapsed -lt 0 -or $elapsed -gt 1 -or $fixed -lt 0 -or $fixed+(@($r.Corridor).Count-1)*(Get-TraversalNumber $r.Clock.Delta 'projection interval') -gt 1 -or @($r.Corridor).Count-1 -gt 8-$r.BeforeStep){throw 'Remaining projection extended original brake budget'}
    if($r.StartsBrake){
        if($r.Ordinal -ne 1 -or $r.BeforeStep -ne 0){throw 'Epoch series began a second recovery'}
        Assert-TraversalClockSame $r.BrakeClock $r.Clock;Assert-TraversalExactPoint $r.BrakeOrigin $r.Actual 'initial brake actual origin';Assert-TraversalExactPoint $r.BrakeVelocity $r.Velocity 'initial measured velocity'
    }elseif($r.BeforeStep -lt 1 -or $null -eq $prior.Recovery -or $prior.Recovery.Step -ne $r.BeforeStep -or $prior.MotionMode -notin @('ACTUAL_BRAKE','BRAKE_HOLD')){throw 'Refresh is not attached to an accepted brake witness'}
    if($r.PreviousOrdinal -eq 0 -and ($r.PreviousCommand -ne 0 -or $r.PreviousSequence -ne 0 -or (Get-TraversalNumber $r.PreviousCompletedWall 'initial link time') -ne 0 -or
        $r.PreviousAdmissionChange -ne $r.OldChange -or $r.PreviousAdmissionData -ne $r.OldData)){throw 'First proof invented a previous admission'}
}
function Assert-TraversalRestGuard($g,$f,$rest,[string]$phase){
    if($g.Policy -cne 'EXACT_BRAKE_REST_V1' -or $g.Phase -cne $phase -or $g.Accepted -isnot [bool] -or -not $g.Accepted -or $g.Session -ne $f.MotionSession -or $g.Command -ne $f.Command -or $g.Step -ne $f.Recovery.Step){throw 'Missing current exact-rest admission guard'}
    foreach($key in @('BodyValid','ContextMatched','QueriesExecuted','FloorCurrent','OverlapClear','Permission','ClockAccepted','Unchanged','ControlActive')){if($g.$key -isnot [bool] -or -not $g.$key){throw 'Current rest context is unknown or invalid'}}
    foreach($key in @('ControlBlocked','ControlArrived','UnobservedTerminal')){if($g.$key -isnot [bool] -or $g.$key){throw 'Terminal controller nevertheless committed a rest replan'}}
    if((Get-TraversalNumber $g.WaterDepth 'current exact-rest water depth') -gt 0.15){throw 'Unsafe current exact-rest water depth'}
    Assert-TraversalClockSame $g.Clock $f.Clock
    $wall=Get-TraversalNumber $g.CheckedWall 'actual rest guard wall';$clock=Get-TraversalNumber $f.Clock.WallTime 'original rest callback wall'
    if($wall -lt $clock -or $wall-$clock -gt 0.10000001){throw 'Rest replan refreshed or overran original callback'}
    Assert-TraversalExactPoint $g.Actual $rest.Actual 'unchanged rest actor pose';Assert-TraversalExactPoint $g.RigidbodyPosition $rest.RigidbodyPosition 'unchanged native body position'
    Assert-TraversalExactPoint $g.NativeVelocity @(0,0,0) 'native exact zero';Assert-TraversalExactPoint $g.MeasuredVelocity @(0,0,0) 'measured exact zero'
    $view=[pscustomobject]@{Actual=$g.Actual;From=$g.Actual;Body=$f.Body;Profile=$f.Profile;Support=$g.Support;Overlaps=$g.Overlaps;OverlapClear=$g.OverlapClear;Permission=$g.Permission;WaterDepth=$g.WaterDepth;Mask=-1;Triggers='Ignore'}
    Assert-TraversalSupport $view;Assert-TraversalContacts $view;Assert-TraversalBrakeFloor $g.Support.Collider $f.Recovery
}
function Assert-TraversalEpochSeries($frames){
    $prior=$null;$pending=$false;$terminal=$false;$nodes=@{};$routeStarts=@{}
    foreach($f in @($frames)){
        if($f.Profile.EpochRevalidationPolicy -cne 'SAME_COMMITTED_ROUTE_EPOCH_V2'){throw 'Epoch series source policy was stripped or mixed with historical rows'}
        $key=[string]$f.MotionSession
        if($terminal -and $f.Event -in @('CLOCK_BASELINE','MOVE_DECISION','MOVE_ISSUED','MOTION_WITNESS','BRAKE_REQUESTED','BRAKE_ISSUED','BRAKE_WITNESSED','ACTUAL_REST','REPATH_AFTER_REST','REPATH','ARRIVED','NATIVE_ROUTE_EPOCH_REVALIDATED')){throw 'Epoch series resumed after terminal cancellation/refusal'}
        if($nodes.ContainsKey($key) -and $nodes[$key].State -ceq 'FAILED_REPATH' -and $f.Event -notin @('BLOCKED','BLOCKED_UNSAFE_BRAKING','MOVE_REJECTED')){throw 'Failed ordinary rest sidepath resumed instead of terminal refusal'}
        if($f.Event -ceq 'CLOCK_BASELINE'){$routeStarts[$key]=$f.PosePreviousTime}
        if($f.Event -ceq 'NATIVE_ROUTE_EPOCH_REVALIDATED'){
            if($pending){throw 'Epoch recertified an unobserved native writer'}
            Assert-TraversalEpochProof $f $prior;$r=$f.EpochRevalidation
            if(-not $routeStarts.ContainsKey($key) -or [single]$r.RouteStartedWall -ne [single]$routeStarts[$key]){throw 'Epoch series reset destination deadline'}
            if(-not $nodes.ContainsKey($key)){
                if(-not $r.StartsBrake){throw 'First proof during ordinary brake omitted the original request'}
                $nodes[$key]=@{State='WAIT_REQUEST';Start=$f.Recovery;Clock=$r.BrakeClock;Last=$null;Ordinal=0;ProofSequence=0;Rest=$null}
            }
            $node=$nodes[$key]
            if($node.State -notin @('WAIT_REQUEST','BRAKING') -or ($node.Ordinal -gt 0 -and $r.StartsBrake) -or $r.Ordinal -ne $node.Ordinal+1 -or $r.Ordinal -gt 8 -or $r.Clock.Sequence -le $node.ProofSequence){throw 'Replayed/skipped epoch proof or second brake start'}
            Assert-TraversalClockSame $r.BrakeClock $node.Clock
            Assert-TraversalExactPoint $r.BrakeOrigin $node.Start.StartPosition 'original series brake origin';Assert-TraversalExactPoint $r.BrakeVelocity $node.Start.StartVelocity 'original series velocity'
            Assert-TraversalBrakeFloor $r.Floor $node.Start
            if($node.Last){
                $p=$node.Last
                if($r.PreviousOrdinal -ne $p.Ordinal -or $r.PreviousCommand -ne $p.Command -or $r.PreviousSequence -ne $p.Clock.Sequence -or
                    (Get-TraversalNumber $r.PreviousCompletedWall 'previous seal link') -ne (Get-TraversalNumber $p.CompletedWall 'previous recorded seal') -or
                    $r.PreviousAdmissionChange -ne $p.NewChange -or $r.PreviousAdmissionData -ne $p.NewData){throw 'Epoch series previous-proof binding changed'}
                foreach($field in @('CommittedPlan','CommittedPolys','CommittedCorners','From','Goal','OldChange','OldData','OriginalIndex','Filter','Mesh')){Assert-TraversalExactArray $r.$field $p.$field ('original committed '+$field)}
            }
            $node.Last=$r;$node.Ordinal=$r.Ordinal;$node.ProofSequence=$r.Clock.Sequence
            if(-not $r.StartsBrake){$node.State='BRAKING'}
        }
        $r=$f.Navigation.EpochRevalidation
        if($null -ne $r -and $nodes.ContainsKey($key) -and $nodes[$key].State -ceq 'DONE'){throw 'Completed rest replan reused a brake-only native proof'}
        if($null -ne $f.EpochRevalidation -and $f.EpochRevalidation.Accepted -eq $true){Assert-TraversalExactArray $f.EpochRevalidation $r 'published current ordinal'}
        if($null -ne $r){
            if(-not $nodes.ContainsKey($key) -or $null -eq $nodes[$key].Last){throw 'Current series proof was never observed'}
            Assert-TraversalExactArray $r $nodes[$key].Last 'immutable latest ordinal';$admitted=Get-TraversalAdmissionEpoch $f
            if($f.Event -in @('MOVE_DECISION','MOVE_ISSUED') -and ($admitted[0] -ne $f.Navigation.TileChangeVersion -or $admitted[1] -ne $f.Navigation.TileDataVersion)){throw 'Writer retained stale series admission'}
        }elseif($null -ne $f.Navigation.AdmissionTileChangeVersion -or $null -ne $f.Navigation.AdmissionTileDataVersion){$null=Get-TraversalAdmissionEpoch $f}
        if($f.Event -ceq 'BRAKE_REQUESTED'){
            if(-not $nodes.ContainsKey($key)){$nodes[$key]=@{State='BRAKING';Start=$f.Recovery;Clock=$f.Clock;Last=$null;Ordinal=0;ProofSequence=0;Rest=$null}}
            elseif($nodes[$key].State -cne 'WAIT_REQUEST'){throw 'Epoch refresh emitted a second brake request'}
            $node=$nodes[$key];Assert-TraversalClockSame $f.Clock $node.Clock
            if($f.Recovery.Step -ne 0 -or $f.Recovery.Attempt -ne 1 -or $f.Recovery.StartSequence -ne $node.Clock.Sequence){throw 'Epoch series reset original request context'};$node.State='BRAKING'
        }
        if($nodes.ContainsKey($key)){
            $node=$nodes[$key]
            if($f.Event -in @('BLOCKED','BLOCKED_UNSAFE_BRAKING','MOVE_REJECTED')){$node.State='TERMINAL';$terminal=$true}
            elseif($f.Event -in @('MOVE_DECISION','MOVE_ISSUED','MOTION_WITNESS') -and $node.State -ceq 'BRAKING'){
                if($f.MotionMode -notin @('ACTUAL_BRAKE','BRAKE_HOLD') -or $null -eq $f.Recovery){throw 'Series admission licensed ordinary motion'}
                foreach($field in @('StartSequence','StartWall','StartPosition','StartVelocity','Attempt','Floor','FloorCenter','FloorSize','FloorCollider','MaxSteps','MaxSeconds','Deceleration')){Assert-TraversalExactArray $f.Recovery.$field $node.Start.$field ('original brake '+$field)}
                if($node.Last -and $null -eq $r){throw 'Moving brake lost current series admission'}
            }elseif($f.Event -ceq 'ACTUAL_REST'){
                if($node.State -cne 'BRAKING' -or $pending -or $null -eq $prior -or $prior.Command -ne $f.Command -or $prior.Speed -ne 0 -or $prior.Recovery.Step -ne $f.Recovery.Step){throw 'Zero acknowledgement omitted its accepted brake witness'}
                Assert-TraversalExactPoint $prior.Body.Velocity @(0,0,0) 'witnessed native zero';Assert-TraversalExactPoint $f.Actual $prior.Actual 'witnessed rest pose'
                $a=$f.RestAdmission;if($a.Policy -cne 'EXACT_BRAKE_REST_V1' -or $a.Step -ne $f.Recovery.Step -or $a.Attempt -ne 1 -or $a.Command -ne $f.Command -or $a.Session -ne $f.MotionSession){throw 'Missing exact rest acknowledgement'}
                Assert-TraversalClockSame $a.Clock $f.Clock;Assert-TraversalClockSame $a.BrakeClock $node.Clock
                Assert-TraversalExactPoint $a.Actual $prior.Actual 'original zero actor pose';Assert-TraversalExactPoint $a.RigidbodyPosition $prior.Body.RigidbodyPosition 'original zero native body position'
                Assert-TraversalExactPoint $a.Goal $prior.Navigation.RouteTo 'original post-rest destination';Assert-TraversalExactArray $a.Floor $node.Start.FloorCollider 'original acknowledged static floor'
                Assert-TraversalExactPoint $a.BrakeOrigin $node.Start.StartPosition 'original acknowledged brake origin';Assert-TraversalExactPoint $a.BrakeVelocity $node.Start.StartVelocity 'original acknowledged momentum'
                foreach($field in @('StartSequence','StartWall','StartPosition','StartVelocity','Attempt','Floor','FloorCenter','FloorSize','FloorCollider','MaxSteps','MaxSeconds','Deceleration')){Assert-TraversalExactArray $f.Recovery.$field $node.Start.$field ('acknowledged original brake '+$field)}
                $elapsed=(Get-TraversalNumber $f.Clock.WallTime 'rest wall')-(Get-TraversalNumber $node.Clock.WallTime 'original brake wall')
                $fixed=(Get-TraversalNumber $f.Clock.FixedTime 'rest fixed')-(Get-TraversalNumber $node.Clock.FixedTime 'original brake fixed')
                if($f.Recovery.Step -gt 8 -or $f.Recovery.Step -lt 1 -or $elapsed -lt 0 -or $elapsed -gt 1 -or $fixed -lt 0 -or $fixed -gt 1 -or $f.Clock.Sequence -ne $node.Clock.Sequence+$f.Recovery.Step){throw 'Exact rest exceeded original brake budget'}
                Assert-TraversalRestGuard $a.Guard $f $a 'REST_ACK';$node.Rest=$a;$node.State='REST'
            }elseif($f.Event -ceq 'REPATH_AFTER_REST'){
                if($node.State -cne 'REST' -or $null -ne $r -or $f.RestReplan.Accepted -ne $true){throw 'Series replan predates measured rest or retained old admission'}
                $kind=$f.RestReplan.Kind
                if($kind -ceq 'STATIONARY_PLAN' -and $f.Profile.StationaryReplanPolicy -ceq 'MEASURED_STATIONARY_NATIVE_V1'){
                    $s=$f.StationaryReplan
                    if($s.Entry -cne 'ACKNOWLEDGED_BRAKE_REST' -or $s.State -cne 'COMMITTED' -or $s.Plan.Accepted -ne $true){throw 'Delayed rest Plan omitted its explicit stationary admission'}
                    Assert-TraversalExactArray $s.OriginalBrakeRest $node.Rest 'original on-time physical rest before stationary eligibility'
                    Assert-TraversalExactArray $s.Plan.Navigation $f.Navigation 'sole delayed stationary native Plan'
                    $node.State='DONE';continue
                }
                if($kind -notin @('PLAN','OBSTACLE') -or ($node.Ordinal -gt 0 -and $kind -cne 'PLAN')){throw 'Epoch rest used a sidepath instead of fresh strict Plan'}
                Assert-TraversalRestGuard $f.RestReplan.Guard $f $node.Rest $(if($kind -ceq 'PLAN'){'REST_PLAN_PRECOMMIT'}else{'REST_OBSTACLE_PRECOMMIT'})
                $replanWall=Get-TraversalNumber $f.RestReplan.Time 'actual guarded replan time';$callbackWall=Get-TraversalNumber $f.Clock.WallTime 'original replan callback'
                if($replanWall -lt (Get-TraversalNumber $f.RestReplan.Guard.CheckedWall 'actual post-query rest guard') -or $replanWall-$callbackWall -gt 0.1){throw 'Native replan predates its guard or exceeds its original callback'}
                if($null -ne $f.WallTelemetry -and $replanWall -gt $callbackWall+(Get-TraversalNumber $f.WallTelemetry.ReadDelay 'actual replan emission delay')){throw 'Native replan timestamp follows its actual emission'}
                Assert-TraversalNativeRoutePlan $f.Navigation;Assert-TraversalExactPoint $f.Navigation.RouteFrom $f.Actual 'post-rest actual plan start';Assert-TraversalExactPoint $f.Navigation.RouteTo $node.Rest.Goal 'post-rest original goal';$node.State='DONE'
            }elseif($f.Event -ceq 'REPATH' -and $node.State -ceq 'REST' -and $node.Ordinal -eq 0 -and $f.RestReplan.Kind -ceq 'OBSTACLE' -and $f.RestReplan.Accepted -is [bool] -and -not $f.RestReplan.Accepted){
                $failed=Get-TraversalNumber $f.RestReplan.Time 'failed ordinary rest sidepath time';$start=Get-TraversalNumber $node.Rest.Guard.CheckedWall 'prior exact rest acknowledgement'
                if($failed -lt $start -or $pending -or $f.WriterCalled -eq $true){throw 'Failed sidepath invented progress or preceded exact rest'};$node.State='FAILED_REPATH'
            }elseif($node.State -ceq 'WAIT_REQUEST' -and $f.Event -cne 'NATIVE_ROUTE_EPOCH_REVALIDATED'){throw 'Initial epoch proof omitted its immediate sole request'}
            elseif($node.State -ceq 'REST' -and $f.Event -in @('MOVE_DECISION','MOVE_ISSUED','MOTION_WITNESS','BRAKE_REQUESTED','REPATH','ARRIVED')){throw 'Rest resumed without guarded native replan'}
        }
        if($f.Event -in @('BLOCKED','BLOCKED_UNSAFE_BRAKING','MOVE_REJECTED')){$terminal=$true}
        if($f.Event -ceq 'MOVE_DECISION'){$pending=$true}
        if($f.Event -in @('MOTION_WITNESS','MOVE_REJECTED','BLOCKED')){$pending=$false}
        if($f.Event -ceq 'MOTION_WITNESS' -and $f.NativeResult -ceq 'OBSERVED'){$prior=$f}
    }
    if(@($nodes.Values|Where-Object {$_.State -in @('WAIT_REQUEST','BRAKING','REST','FAILED_REPATH')}).Count){throw 'Incomplete epoch series brake/rest/replan lifecycle'}
}
function Assert-TraversalLateRestRefusal($f,$witness,$pending,$frames,$expectedActor){
    # Only a diagnostic suffix is admitted here; the ordinary prefix was already independently replayed.
    $frames=@($frames);$wi=-1;$fi=-1
    if($f.Schema -ne 2 -or $f.Event -cnotin @('BLOCKED','REPATH') -or (Get-TraversalNumber $f.WallTelemetry.ReadDelay 'late rest diagnostic delay') -le (Get-TraversalNumber $f.Profile.MaxTick 'unchanged physical callback limit')+0.000001){throw 'Not a late V2 no-actuation diagnostic'}
    for($i=0;$i -lt $frames.Count;$i++){if([object]::ReferenceEquals($frames[$i],$witness)){$wi=$i};if([object]::ReferenceEquals($frames[$i],$f)){$fi=$i}}
    if($null -ne $pending -or $wi -lt 0 -or $fi -le $wi -or $witness.Schema -ne 2 -or $witness.Event -cne 'MOTION_WITNESS' -or $witness.NativeResult -cne 'OBSERVED' -or
        $witness.Profile.EpochRevalidationPolicy -cne 'SAME_COMMITTED_ROUTE_EPOCH_V2' -or $witness.RecoveryPolicy -cne 'MEASURED_BRAKE_V1' -or
        $witness.MotionMode -cnotin @('ACTUAL_BRAKE','BRAKE_HOLD') -or [string]$witness.Actor -cne [string]$expectedActor -or (Get-TraversalNumber $witness.Speed 'zero brake witness speed') -ne 0){throw 'Late rest lacks its accepted V2 zero brake witness'}
    Assert-TraversalProfile $witness.Profile;Assert-TraversalBody $witness $expectedActor;Assert-TraversalSupport $witness;Assert-TraversalContacts $witness;Assert-AcquisitionPolicy $witness
    Assert-TraversalClock $witness.Clock $witness.Profile;Assert-TraversalWallTelemetry $witness $witness.PreviousClock
    $casts=Get-TraversalNumber $witness.Casts 'accepted zero query count';if($casts -lt 1 -or $casts -gt 64 -or $casts -ne [Math]::Floor($casts)){throw 'Zero brake witness exceeds original physical query budget'}
    Assert-TraversalNear $witness.Dt $witness.Clock.Delta 'zero brake native interval' 0.000001
    $velocity=Get-TraversalPhysicsVelocity $witness.Actual $witness.From (Get-TraversalNumber $witness.Dt 'zero brake interval')
    Assert-TraversalVector $witness.Body.Velocity
    if(@($velocity|Where-Object {$_ -ne 0}).Count -or @($witness.Body.Velocity|Where-Object {$_ -ne 0}).Count -or $witness.NativeVelocityMatches -isnot [bool] -or -not $witness.NativeVelocityMatches){throw 'Late rest replaced actual/native nonzero motion with a fake zero'}
    $r=$witness.Recovery;$step=Get-TraversalNumber $r.Step 'zero brake step';$start=Get-TraversalNumber $r.StartWall 'original brake wall';$wall=Get-TraversalNumber $witness.Clock.WallTime 'zero brake callback'
    if($r.Kind -cne 'MEASURED_BRAKE_V1' -or $r.Session -ne $witness.MotionSession -or $r.Attempt -ne 1 -or $step -lt 1 -or $step -gt 8 -or $step -ne [Math]::Floor($step) -or
        $r.MaxSteps -ne 8 -or $r.MaxSeconds -ne 1 -or $r.Deceleration -ne 3 -or $witness.Clock.Sequence -ne $r.StartSequence+$step -or $wall -lt $start -or $wall-$start -gt 1){throw 'Late rest reset/exhausted the original brake context'}
    Assert-TraversalBrakeFloor $witness.Support.Collider $r
    $before=@($frames[0..$wi]);$intent=@($before|Where-Object {$_.Event -ceq 'MOVE_DECISION' -and $_.MotionSession -eq $witness.MotionSession -and $_.Command -eq $witness.Command})
    $issue=@($before|Where-Object {$_.Event -ceq 'MOVE_ISSUED' -and $_.MotionSession -eq $witness.MotionSession -and $_.Command -eq $witness.Command})
    $request=@($before|Where-Object {$_.Event -ceq 'BRAKE_REQUESTED' -and $_.MotionSession -eq $witness.MotionSession})
    if($intent.Count -ne 1 -or $issue.Count -ne 1 -or $request.Count -ne 1 -or $intent[0].NativeResult -cne 'PRECHECKED' -or $issue[0].NativeResult -cne 'ISSUED' -or $issue[0].WriterCalled -isnot [bool] -or -not $issue[0].WriterCalled -or
        $intent[0].MotionMode -cnotin @('ACTUAL_BRAKE','BRAKE_HOLD') -or $issue[0].MotionMode -cne $witness.MotionMode -or $issue[0].Recovery.Step -ne $step -or $issue[0].Clock.Sequence+1 -ne $witness.Clock.Sequence){throw 'Late rest has no matching real brake intent/issue lineage'}
    Assert-TraversalClockSame $witness.IssuedClock $issue[0].Clock;Assert-TraversalSamePoint $issue[0].Requested $witness.Actual 'zero brake issued endpoint'
    Assert-TraversalSamePoint $issue[0].From $witness.From 'zero brake issued origin';Assert-TraversalNear ($witness.Clock.FixedTime-$issue[0].Clock.FixedTime) $issue[0].Clock.Delta 'zero brake actual fixed interval' 0.000001
    if($request[0].Recovery.StartSequence -ne $r.StartSequence -or [double]$request[0].Recovery.StartWall -ne $start){throw 'Late rest borrowed another recovery start'}
    foreach($key in @('StartPosition','StartVelocity','Floor','FloorCollider','FloorCenter','FloorSize')){Assert-TraversalExactArray $r.$key $request[0].Recovery.$key ('original zero brake '+$key)}
    Assert-TraversalNear ($witness.Clock.FixedTime-$request[0].Clock.FixedTime) ($step*$witness.Clock.Delta) 'original zero brake fixed horizon' 0.000001
    $firstBlock=-1;$firstFailure=-1;$failures=@();$restCount=0;$failedRepath=$false
    for($i=$wi+1;$i -lt $frames.Count;$i++){
        $b=$frames[$i]
        foreach($key in @('WriterCalled','UnobservedCommand')){if($null -ne $b.$key -and $b.$key -isnot [bool]){throw 'Untyped terminal no-writer state'}}
        if($b.MotionSession -ne $witness.MotionSession -or $b.Stage -cne $witness.Stage -or [string]$b.Actor -cne [string]$expectedActor -or $b.World -cne $witness.World -or $b.Command -ne $witness.Command -or
            $b.WriterCalled -eq $true -or $b.UnobservedCommand -eq $true -or $null -ne $b.PendingDecision -or ($null -ne $b.Actuations -and $b.Actuations -ne $issue[0].Actuations)){throw 'Late rest suffix changed actor/session/command or actuated'}
        Assert-TraversalExactArray $b.Profile $witness.Profile 'late-rest original source profile'
        if($b.Event -ceq 'REPATH' -and $null -ne $b.RestReplan -and $b.RestReplan.Kind -ceq 'OBSTACLE' -and $b.RestReplan.Accepted -is [bool] -and -not $b.RestReplan.Accepted){
            if($firstFailure -ge 0 -or $restCount -ne 1 -or $b.NativeResult -cne 'OBSERVED'){throw 'Late failed side-path diagnostic has no earlier real rest or replayed after failure'}
            Assert-TraversalClockSame $b.Clock $witness.Clock;Assert-TraversalClockSame $b.PreviousClock $witness.PreviousClock
            foreach($key in @('RoutePlan','RouteFrom','RouteTo','RoutePolys','Corners','PlannedMesh','PlannedTileChangeVersion','PlannedTileDataVersion')){Assert-TraversalExactArray $b.Navigation.$key $witness.Navigation.$key ('failed side-path committed '+$key)}
            $firstFailure=$i;$failedRepath=$true;$failures+=,$b
        }elseif($b.Event -ceq 'BLOCKED'){
            if($firstBlock -lt 0){$firstBlock=$i}
            if($firstFailure -lt 0){$firstFailure=$i}
            if($i -eq $frames.Count-1){if($b.NativeResult -cne 'STOPPED' -or $null -ne $b.Clock){throw 'Late rest lacks its final unclocked no-actuation STOPPED'};continue}
            if($b.NativeResult -cnotin @('NOT_ISSUED','STOPPED') -or $null -eq $b.Clock){throw 'Late rest suffix is not a source no-writer refusal'}
            Assert-TraversalClockSame $b.Clock $witness.Clock;Assert-TraversalClockSame $b.PreviousClock $witness.PreviousClock
            if($b.Tick -ne $witness.Tick){throw 'Late rest moved to another controller callback'}
            foreach($key in @('RoutePlan','RouteFrom','RouteTo','RoutePolys','Corners','PlannedMesh','PlannedTileChangeVersion','PlannedTileDataVersion')){Assert-TraversalExactArray $b.Navigation.$key $witness.Navigation.$key ('late-rest committed '+$key)}
            if($b.NativeResult -ceq 'NOT_ISSUED'){$failures+=,$b}
        }else{
            if($firstFailure -ge 0 -or $b.Event -cnotin @('BRAKE_WITNESSED','ACTUAL_REST')){throw 'Late rest contains future intent/writer/witness/repath/arrival or replay'}
            Assert-TraversalClockSame $b.Clock $witness.Clock;Assert-TraversalWallTelemetry $b $b.PreviousClock
            if($b.Event -ceq 'ACTUAL_REST'){$restCount++;if($restCount -gt 1 -or $b.RestAdmission.Policy -cne 'EXACT_BRAKE_REST_V1' -or $b.RestAdmission.Guard.Accepted -ne $true){throw 'Late rest invented earlier rest credit'}}
        }
    }
    if($firstBlock -lt 0 -or $fi -lt $firstFailure -or -not $failures.Count){throw 'Arbitrary late block has no actual failed REST operation'}
    $evidence=$false
    foreach($b in $failures){
        $plan=$b.RestReplan;$g=if($null -ne $b.RestReplanGuard){$b.RestReplanGuard}else{$plan.Guard}
        if($g.Policy -cne 'EXACT_BRAKE_REST_V1' -or $g.Accepted -isnot [bool] -or $g.Phase -cnotin @('REST_ACK','AFTER_REST_SINK','REST_PLAN_PRECOMMIT','REST_PLAN_REFUSED','REST_OBSTACLE_PRECOMMIT','REST_OBSTACLE_REFUSED') -or
            $g.Session -ne $witness.MotionSession -or $g.Command -ne $witness.Command -or $g.Step -ne $step){throw 'Missing source failed-rest guard phase/lineage'}
        Assert-TraversalClockSame $g.Clock $witness.Clock
        $checked=Get-TraversalNumber $g.CheckedWall 'actual failed rest guard';$delay=Get-TraversalNumber $b.WallTelemetry.ReadDelay 'actual rest refusal read delay';$time=$checked
        if($checked -lt $wall -or $checked -gt $wall+$delay+0.000001){throw 'Failed rest guard time is outside its recorded callback'}
        if($null -ne $plan){
            if($plan.Kind -cnotin @('PLAN','OBSTACLE') -or $plan.Accepted -isnot [bool] -or $plan.Accepted){throw 'Late native rest Plan claimed success'}
            $time=Get-TraversalNumber $plan.Time 'actual failed native rest Plan time';if($time -lt $checked -or $time -gt $wall+$delay+0.000001){throw 'Failed native Plan time is unbound'}
            if($b.Event -ceq 'REPATH' -and $time-$wall -le [double]$witness.Profile.MaxTick){throw 'Late failed side-path has no actual late native query time'}
        }elseif($g.Accepted){throw 'Successful rest guard cannot alone explain a late refusal'}
        if($g.Accepted){
            if($restCount -ne 1 -or $checked-$wall -gt [double]$witness.Profile.MaxTick){throw 'Failed native Plan borrowed a late/unobserved successful rest guard'}
            foreach($key in @('BodyValid','ContextMatched','ClockAccepted','Unchanged','QueriesExecuted','FloorCurrent','OverlapClear','Permission')){if($g.$key -isnot [bool] -or -not $g.$key){throw 'Successful historical rest guard is contradictory'}}
            if((Get-TraversalNumber $g.WaterDepth 'successful historical rest water') -gt 0.15){throw 'Successful historical rest guard exceeds native water limit'}
            if($g.ControlActive -isnot [bool] -or -not $g.ControlActive){throw 'Successful historical rest guard was inactive'}
            foreach($key in @('ControlBlocked','ControlArrived','UnobservedTerminal')){if($g.$key -isnot [bool] -or $g.$key){throw 'Successful historical rest guard was cancelled'}}
            Assert-TraversalVector $g.NativeVelocity;Assert-TraversalVector $g.MeasuredVelocity
            Assert-TraversalSamePoint $g.Actual $witness.Actual 'successful historical rest pose';Assert-TraversalSamePoint $g.RigidbodyPosition $witness.Body.RigidbodyPosition 'successful historical rigid pose'
            foreach($v in @($g.NativeVelocity)+@($g.MeasuredVelocity)){$value=Get-TraversalNumber $v 'historical exact rest velocity';if($value -ne 0){throw 'Successful historical rest guard is not native/measured zero'}}
        }
        if($b.Event -cne 'REPATH' -and $b.Reason -cnotin @('BRAKE_REST_CONTEXT_UNCERTAIN','BRAKE_REST_CHANGED_AFTER_SINK','BRAKE_REST_NATIVE_REPLAN_INVALID','BRAKE_REST_CHANGED_DURING_NATIVE_REPATH') -and ($null -eq $plan -or $plan.Kind -cne 'OBSTACLE' -or $b.Reason -notmatch ':(NATIVE_REPATH_CONTEXT_UNKNOWN|BOUNDED_REPATH_EXHAUSTED)$')){throw 'Arbitrary block reason borrowed rest metadata'}
        if($time-$wall -gt [double]$witness.Profile.MaxTick){$evidence=$true}
    }
    if(-not $evidence){throw 'Late rest lacks an actual late failed guard/native Plan read'}
    # The current failure body/native state may have changed; it grants no new physical/rest credit.
    $view=[ordered]@{};foreach($p in $f.PSObject.Properties){$view[$p.Name]=$p.Value};$view.Event='BLOCKED';$view.NativeResult='NOT_ISSUED'
    Assert-TraversalWallTelemetry ([pscustomobject]$view) $witness.PreviousClock -NoActuationTerminal
}
function Assert-TraversalLateRestResult($nav){
    $frames=@($nav.Traversal.Frames);$late=-1
    for($i=0;$i -lt $frames.Count;$i++){$f=$frames[$i];$failedRoute=$f.Event -ceq 'REPATH' -and $f.RestReplan.Kind -ceq 'OBSTACLE' -and $f.RestReplan.Accepted -eq $false;if($f.Profile.EpochRevalidationPolicy -ceq 'SAME_COMMITTED_ROUTE_EPOCH_V2' -and ($f.Event -ceq 'BLOCKED' -or $failedRoute) -and $null -ne $f.Clock -and [double]$f.WallTelemetry.ReadDelay -gt [double]$f.Profile.MaxTick+0.000001){$late=$i;break}}
    if($late -lt 0){return}
    if($nav.Status -cne 'PARTIAL' -or $nav.Traversal.Completed -eq $true){throw 'Late rest refusal cannot complete or claim GREEN'}
    foreach($s in @($nav.Traversal.Scenes|Where-Object Status -ceq 'PASSED')){$end=Get-TraversalNumber $s.FramesTo 'historical scene end before late failure';if($end -lt 0 -or $end -ne [Math]::Floor($end) -or $end -gt $late){throw 'Scene success follows a late no-actuation rest failure'}}
    $cutoff=Get-TraversalNumber $frames[$late].Clock.WallTime 'late zero-brake callback cutoff'
    # These source receipts use native Single time. Untimed final snapshots grant no new progress here.
    foreach($a in @($nav.FirstHome.NativePlacements)+@($nav.FirstHome.Operations)+@($nav.Traversal.FixtureTransitions)+@($nav.Traversal.Fixture)+@($nav.FirstHome.Navigation)+@($nav.FirstHome.Phases)+@($nav.Traversal.BuildRests)+@($nav.Traversal.Detour)){
        if($null -ne $a -and [single](Get-TraversalNumber $a.Time 'native progress before late refusal') -gt [single]$cutoff){throw 'Late rest refusal advanced native payment/build/fixture/home progress'}
    }
    foreach($a in @($nav.Traversal.BuildPlans)){
        if($null -ne $a -and (Get-TraversalNumber $a.Time 'native Double graph time before late refusal') -gt $cutoff){throw 'Late rest refusal created a new exterior build graph'}
    }
    foreach($w in @($nav.Traversal.DestinationWindows)){
        if($null -ne $w -and (Get-TraversalNumber $w.Contract.Start 'native Double destination start before late refusal') -ge $cutoff){throw 'Late rest refusal queued a new destination'}
    }
}
function Get-TraversalStationaryNativeDouble($value,[string]$name){
    $number=Get-TraversalNumber $value $name
    # PS5 JSON Decimal-to-Double casts can move a native binary64 timestamp by one ULP.
    if($value -is [decimal]){return [double]::Parse($value.ToString([Globalization.CultureInfo]::InvariantCulture),[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture)}
    $number
}
function Assert-TraversalStationaryBody($a,$b){
    if($null -eq $a -or $null -eq $b){throw 'Missing exact stationary typed body'}
    foreach($k in @('Position','RigidbodyPosition','CapsulePosition','Scale','Center','A','B')){Assert-TraversalExactPoint $a.$k $b.$k ('stationary '+$k)}
    foreach($k in @('Rotation','CapsuleRotation')){Assert-TraversalVector $a.$k 4;Assert-TraversalVector $b.$k 4;for($j=0;$j -lt 4;$j++){if($a.$k[$j] -ne $b.$k[$j]){throw 'Stationary exact rotation changed'}}}
    foreach($k in @('Radius','Height','Capsule','Rigidbody','Direction','Layer')){if((Get-TraversalNumber $a.$k $k) -ne (Get-TraversalNumber $b.$k $k)){throw ('Stationary typed body changed '+$k)}}
    foreach($k in @('Enabled','Trigger','Kinematic','Gravity','Detect','AgentStopped','AgentPosition','AgentRotation')){if($a.$k -isnot [bool] -or $b.$k -isnot [bool] -or $a.$k -ne $b.$k){throw ('Stationary exact native configuration changed '+$k)}}
    if([string]$a.CollisionMode -cne [string]$b.CollisionMode){throw 'Stationary collision mode changed'}
}
function Assert-TraversalStationaryActualBody($a,$f){
    foreach($k in @('Position','RigidbodyPosition','Scale','Center','A','B')){Assert-TraversalExactPoint $a.$k $f.$k ('actual frozen '+$k)}
    foreach($k in @('Radius','Height','Direction','Layer')){if((Get-TraversalNumber $a.$k $k) -ne (Get-TraversalNumber $f.$k $k)){throw 'Actual body differs from declared frozen geometry'}}
    foreach($pair in @(@('Instance','Capsule'),@('RigidbodyInstance','Rigidbody'),@('Enabled','Enabled'),@('Trigger','Trigger'),@('Kinematic','Kinematic'),@('Gravity','Gravity'),@('DetectCollisions','Detect'),@('CollisionMode','CollisionMode'),@('AgentStopped','AgentStopped'),@('AgentUpdatePosition','AgentPosition'),@('AgentUpdateRotation','AgentRotation'))){if([string]$a.($pair[0]) -cne [string]$f.($pair[1])){throw ('Actual frozen native configuration differs '+$pair[0])}}
    Assert-TraversalVector $a.Rotation 4;Assert-TraversalVector $f.Rotation 4
    for($i=0;$i -lt 4;$i++){if($a.Rotation[$i] -ne $f.Rotation[$i]){throw 'Actual frozen actor rotation differs'}}
    Assert-TraversalExactPoint $f.CapsulePosition $f.Position 'same original root capsule position'
    for($i=0;$i -lt 4;$i++){if($f.CapsuleRotation[$i] -ne $f.Rotation[$i]){throw 'Original root capsule rotation differs from actual actor'}}
}
function Assert-TraversalStationaryAnchors($f,$frames,$expectedActor){
    $frames=@($frames);$s=$f.StationaryReplan;$entry=$null;$baseline=$null;$route=$null;$rest=$null;$zero=$null;$issued=0;$nativeCommand=0
    foreach($row in $frames){
        if($row.MotionSession -eq $s.Session -and $row.Event -ceq 'CLOCK_BASELINE'){$baseline=$row;$route=$row.Navigation}
        if($row.MotionSession -eq $s.Session -and $row.Event -in @('REPATH','REPATH_AFTER_REST') -and $null -eq $row.StationaryReplan){$route=$row.Navigation}
        if($row.Event -ceq 'MOTION_WITNESS' -and $row.NativeResult -ceq 'OBSERVED' -and $row.Speed -eq 0){$zero=$row}
        if($row.Event -ceq 'ACTUAL_REST'){$rest=$row}
        if($null -ne $row.StationaryReplan -and $row.StationaryReplan.Id -eq $s.Id -and $row.MotionSession -eq $s.Session){$entry=$row;break}
        if($row.Event -ceq 'MOVE_ISSUED'){$issued++;$nativeCommand=$row.Command}
    }
    if($null -eq $entry -or $null -eq $baseline -or $null -eq $route -or [string]$f.Actor -cne [string]$expectedActor){throw 'Stationary lineage lacks actual baseline/entry prefix'}
    $a=$entry.StationaryReplan
    foreach($k in @('Policy','Id','Entry','Session','Command','BaseActuations','RetryBefore','RetryAfter','StartedWall','RouteStartedWall','RouteDeadline','GlobalDeadline','Deadline','MaxSeconds','MinStableSeconds','MaxSamples','EntryClock','BaselineClock','BaselineBody','BaselineFrozenBody','FrozenBody','Actual','RigidbodyPosition','Goal','Floor','FloorCenter','FloorSize','Anchor','OriginalNavigation','OriginalBrakeRest')){Assert-TraversalExactArray $s.$k $a.$k ('actual stationary captured '+$k)}
    Assert-TraversalClockSame $a.EntryClock $entry.Clock;Assert-TraversalClockSame $a.BaselineClock $baseline.Clock
    if((Get-TraversalNumber $a.BaseActuations 'entry actual base count') -ne $issued -or (Get-TraversalNumber $a.Command 'entry actual command') -ne $nativeCommand){throw 'Stationary entry base counters are not the actual native prefix'}
    $global=Get-TraversalStationaryNativeDouble $a.GlobalDeadline 'entry global';$start=Get-TraversalStationaryNativeDouble $a.StartedWall 'entry start';$routeStart=Get-TraversalStationaryNativeDouble $a.RouteStartedWall 'entry original route clock';$clock=Get-TraversalStationaryNativeDouble $entry.Clock.WallTime 'entry actual callback'
    if($global -ne (Get-TraversalStationaryNativeDouble $baseline.GlobalDeadline 'actual baseline global') -or $global -ne (Get-TraversalStationaryNativeDouble $entry.GlobalDeadline 'actual entry global') -or $global -ne (Get-TraversalStationaryNativeDouble $f.GlobalDeadline 'actual current global') -or
        $start -lt $clock -or $start -gt (Get-TraversalStationaryNativeDouble $a.LastGuard.CheckedWall 'actual ENTRY guard time') -or [single]$routeStart -ne [single]$baseline.PosePreviousTime -or
        (Get-TraversalStationaryNativeDouble $a.RouteDeadline 'original route deadline') -ne $routeStart+120 -or (Get-TraversalStationaryNativeDouble $a.Deadline 'actual bounded deadline') -ne [Math]::Min(($start+20),[Math]::Min(($routeStart+120),$global))){throw 'Stationary actual global/start/route deadline anchor changed'}
    Assert-TraversalExactPoint $a.Goal $baseline.Navigation.RouteTo 'actual captured baseline goal';Assert-TraversalExactPoint $a.Goal $route.RouteTo 'actual captured latest goal'
    foreach($k in @('RouteFrom','RouteTo','RoutePolys','RoutePlan','Corners','PlannedMesh','PlannedTileChangeVersion','PlannedTileDataVersion','RouteFilter')){Assert-TraversalExactArray $a.OriginalNavigation.$k $route.$k ('actual committed route '+$k);Assert-TraversalExactArray $a.OriginalNavigation.$k $entry.Navigation.$k ('actual entry route '+$k)}
    Assert-TraversalExactArray $a.BaselineBody $baseline.Body 'reported baseline body against actual baseline row'
    Assert-TraversalStationaryActualBody $a.BaselineBody $a.BaselineFrozenBody;Assert-TraversalStationaryActualBody $baseline.Body $a.BaselineFrozenBody
    if($a.Entry -ceq 'BASELINE_BEFORE_FIRST_WRITER'){
        Assert-TraversalStationaryBody $a.FrozenBody $a.BaselineFrozenBody
        if($a.Command -ne $baseline.Command){throw 'Baseline stationary entry issued a writer first'}
    }elseif($a.Entry -ceq 'ACKNOWLEDGED_BRAKE_REST'){
        if($null -eq $zero -or $null -eq $rest -or $zero.Command -ne $a.Command -or $rest.Command -ne $a.Command){throw 'Stationary physical rest lineage missing'}
        Assert-TraversalExactArray $a.OriginalBrakeRest $rest.RestAdmission 'actual original rest acknowledgement'
        Assert-TraversalStationaryActualBody $zero.Body $zero.AcceptedBrakeZeroBody
        Assert-TraversalStationaryBody $a.FrozenBody $zero.AcceptedBrakeZeroBody;Assert-TraversalStationaryBody $a.OriginalBrakeRest.FrozenBody $zero.AcceptedBrakeZeroBody
    }else{throw 'Unknown stationary actual entry'}
    if($entry.Event -ceq 'STATIONARY_REPLAN_STARTED'){
        if($a.LastGuard.Accepted -ne $true -or $a.LastGuard.Phase -cne 'ENTRY'){throw 'Published stationary start lacks accepted actual ENTRY guard'}
        Assert-TraversalStationaryActualBody $a.OriginalBody $a.FrozenBody
    }elseif($entry.Event -cne 'BLOCKED' -or $a.LastGuard.Phase -cne 'ENTRY' -or $a.LastGuard.Accepted -ne $false -or $a.State -cne 'TERMINAL'){throw 'Unpublished stationary entry lacks explicit rejected ENTRY terminal'}
}
function Assert-TraversalStationaryPhysical($g,$f,$s){
    if($null -eq $g -or $g.Accepted -isnot [bool] -or -not $g.Accepted){throw 'Missing passed stationary physical guard'}
    foreach($k in @('ContextMatched','FloorCurrent','QueriesExecuted','OverlapClear','Permission','ClockAccepted','ControlActive')){if($g.$k -isnot [bool] -or -not $g.$k){throw ('Invalid stationary physical '+$k)}}
    foreach($k in @('ControlBlocked','ControlArrived','UnobservedTerminal')){if($g.$k -isnot [bool] -or $g.$k){throw 'Cancelled stationary physical guard'}}
    Assert-TraversalClockSame $g.Clock $f.Clock;Assert-TraversalProfile $f.Profile
    $wall=Get-TraversalStationaryNativeDouble $g.CheckedWall 'stationary physical guard';$clock=Get-TraversalStationaryNativeDouble $f.Clock.WallTime 'stationary physical callback'
    if($wall -lt $clock -or $wall -lt (Get-TraversalStationaryNativeDouble $s.StartedWall 'actual stationary start') -or $wall-$clock -gt 0.1 -or $wall -gt (Get-TraversalStationaryNativeDouble $s.Deadline 'stationary original deadline')){throw 'Stationary physical guard overran original clock/deadline'}
    Assert-TraversalStationaryBody $g.FrozenBody $s.FrozenBody;Assert-TraversalStationaryActualBody $g.Body $g.FrozenBody;Assert-TraversalStationaryActualBody $f.Body $s.FrozenBody;Assert-TraversalBody ([pscustomobject]@{Body=$g.Body;Actual=$s.Actual}) $f.Actor
    Assert-TraversalVector $g.NativeVelocity;Assert-TraversalVector $g.MeasuredVelocity;Assert-TraversalVector $g.Body.Velocity
    Assert-TraversalExactPoint $g.NativeVelocity $g.Body.Velocity 'same actual native stationary velocity'
    foreach($v in @($g.NativeVelocity)+@($g.MeasuredVelocity)){if((Get-TraversalNumber $v 'actual stationary zero') -ne 0){throw 'Stationary current native/measured velocity is nonzero'}}
    Assert-TraversalExactPoint $g.Actual $s.Actual 'stationary immutable pose';Assert-TraversalExactPoint $g.RigidbodyPosition $s.RigidbodyPosition 'stationary immutable native pose'
    if((Get-TraversalNumber $g.WaterDepth 'current stationary water') -gt 0.15){throw 'Unsafe current stationary water'}
    $view=[pscustomobject]@{Body=$g.Body;Profile=$f.Profile;Actual=$g.Actual;From=$g.Actual;Support=$g.Support;Overlaps=$g.Overlaps;OverlapClear=$g.OverlapClear;Mask=-1;Triggers='Ignore'}
    Assert-TraversalSupport $view;Assert-TraversalContacts $view
    $floor=[pscustomobject]@{Floor=$s.Floor.Instance;FloorCollider=$s.Floor;FloorCenter=$s.FloorCenter;FloorSize=$s.FloorSize}
    Assert-TraversalBrakeFloor $g.Support.Collider $floor;Assert-TraversalExactPoint $g.Support.Point $s.Anchor.Point 'stationary original support point';Assert-TraversalExactPoint $g.Support.Normal $s.Anchor.Normal 'stationary original support normal'
}
function Assert-TraversalStationaryNative($n,$clock){
    if($null -eq $n -or $n.Ready -isnot [bool] -or $n.ComparedToSpan -isnot [bool]){throw 'Missing actual stationary native observation'}
    $start=Get-TraversalStationaryNativeDouble $n.StartedWall 'stationary native start';$end=Get-TraversalStationaryNativeDouble $n.CompletedWall 'stationary native completion';$wall=Get-TraversalStationaryNativeDouble $clock.WallTime 'stationary native callback'
    if($start -lt $wall -or $end -lt $start -or $end-$wall -gt 0.1){throw 'Stationary native observation refreshed/staled callback'}
    if($n.Ready){
        foreach($k in @('Available','DefaultMesh','Built','OnMesh','ProfileMatched','FilterMatched')){if($n.$k -isnot [bool] -or -not $n.$k){throw ('Unready native fact licensed stationary Plan '+$k)}}
        if($n.PendingTiles -isnot [bool] -or $n.PendingTiles -or [string]::IsNullOrWhiteSpace([string]$n.Handle)){throw 'Pending/unknown stationary native ready'}
        foreach($k in @('Change','Data')){$v=Get-TraversalNumber $n.$k ('stationary '+$k);if($v -lt 0 -or $v -ne [Math]::Floor($v)){throw 'Invalid actual stationary native epoch'}}
    }
    if($n.ComparedToSpan -and $n.SameSpanObject -isnot [bool]){throw 'Native object continuity inferred from a handle'}
}
function Test-TraversalStationarySameNative($a,$b){
    $a.Ready -and $a.ComparedToSpan -and $a.SameSpanObject -eq $true -and [string]$a.Handle -ceq [string]$b.Handle -and $a.Change -eq $b.Change -and $a.Data -eq $b.Data
}
function Assert-TraversalStationaryCombinedGuard($g,$f,$s){
    if($g.Accepted -isnot [bool] -or -not $g.Accepted -or $g.NativeAccepted -ne $true -or $g.Unchanged -ne $true -or $g.ClockAccepted -ne $true){throw 'Missing current stationary post-query admission'}
    Assert-TraversalClockSame $g.Clock $f.Clock;Assert-TraversalStationaryPhysical $g.Physical $f $s;Assert-TraversalStationaryNative $g.Native $f.Clock
    if(-not (Test-TraversalStationarySameNative $g.Native $s.Ready.FirstNative)){throw 'Stationary native context changed after READY/query'}
    $time=Get-TraversalStationaryNativeDouble $g.CheckedWall 'stationary combined guard';$wall=Get-TraversalStationaryNativeDouble $f.Clock.WallTime 'stationary combined callback'
    if($time -lt (Get-TraversalStationaryNativeDouble $g.Native.CompletedWall 'actual post-query native end') -or $time-$wall -gt 0.1 -or $time -gt (Get-TraversalStationaryNativeDouble $s.Deadline 'stationary original deadline')){throw 'Stationary post-query guard overran callback/deadline'}
}
function Assert-TraversalStationarySeries($frames){
    $frames=@($frames);if(-not @($frames|Where-Object {$null -ne $_.Profile.StationaryReplanPolicy -or $null -ne $_.StationaryReplan -or $_.Event -like 'STATIONARY_REPLAN_*' -or $_.RestReplan.Kind -ceq 'STATIONARY_PLAN'}).Count){return}
    $nodes=@{};$baseline=@{};$lastRoute=@{};$zero=$null;$rest=$null;$terminal=$false;$nativeCount=0;$nativeCommand=0;$nativePending=$false
    foreach($f in $frames){
        if($f.Profile.StationaryReplanPolicy -cne 'MEASURED_STATIONARY_NATIVE_V1'){throw 'Stationary source policy stripped/changed'}
        if($terminal -and $f.Event -notin @('BLOCKED','MOVE_REJECTED')){throw 'Stationary refusal resumed progress'}
        $key=[string]$f.MotionSession
        if($f.Event -ceq 'MOVE_ISSUED'){$nativeCount++;$nativeCommand=$f.Command;$nativePending=$true}
        if($f.Event -ceq 'MOTION_WITNESS'){$nativePending=$false}
        if($f.Event -ceq 'CLOCK_BASELINE'){$baseline[$key]=$f;$lastRoute[$key]=$f.Navigation}
        if($f.Event -in @('REPATH','REPATH_AFTER_REST') -and $null -eq $f.StationaryReplan){$lastRoute[$key]=$f.Navigation}
        if($f.Event -ceq 'MOTION_WITNESS' -and $f.NativeResult -ceq 'OBSERVED' -and $f.Speed -eq 0){$zero=$f}
        if($f.Event -ceq 'ACTUAL_REST'){$rest=$f}
        $s=$f.StationaryReplan;if($null -eq $s){continue}
        if($s.Policy -cne 'MEASURED_STATIONARY_NATIVE_V1' -or $s.Session -ne $f.MotionSession -or $s.Id -ne $f.MotionSession -or $s.MaxSeconds -ne 20 -or $s.MinStableSeconds -ne 2 -or $s.MaxSamples -ne 512 -or $s.RetryBefore -ne 0 -or $s.RetryAfter -ne 1){throw 'Invalid explicit stationary bounded contract'}
        Assert-TraversalStationaryAnchors $f $frames $f.Actor
        if($s.State -ceq 'TERMINAL'){
            Assert-TraversalStationaryTerminal $f $zero $null $frames $f.Actor;$terminal=$true;continue
        }
        if((Get-TraversalNumber $s.CurrentActuations 'actual native stationary count') -ne $nativeCount -or (Get-TraversalNumber $s.CurrentCommand 'actual native stationary command') -ne $nativeCommand -or
            $s.CurrentPending -isnot [bool] -or $s.CurrentPending -ne $nativePending){throw 'Stationary snapshot disagrees with actual writer/witness prefix'}
        if(-not $nodes.ContainsKey($key)){
            if($f.Event -cne 'STATIONARY_REPLAN_STARTED' -or $s.Observation -ne 0 -or -not $baseline.ContainsKey($key)){throw 'Stationary eligibility omitted its actual entry'}
            if((Get-TraversalStationaryNativeDouble $s.GlobalDeadline 'stationary global') -ne (Get-TraversalStationaryNativeDouble $f.GlobalDeadline 'actual entry global') -or
                (Get-TraversalStationaryNativeDouble $s.GlobalDeadline 'stationary global') -ne (Get-TraversalStationaryNativeDouble $baseline[$key].GlobalDeadline 'actual baseline global')){throw 'Stationary snapshot rewrote actual global deadline'}
            Assert-TraversalExactPoint $s.Goal $baseline[$key].Navigation.RouteTo 'actual original baseline goal';Assert-TraversalExactPoint $s.Goal $lastRoute[$key].RouteTo 'actual current goal'
            foreach($k in @('RouteFrom','RouteTo','RoutePolys','RoutePlan','Corners','PlannedMesh','PlannedTileChangeVersion','PlannedTileDataVersion','RouteFilter')){
                Assert-TraversalExactArray $s.OriginalNavigation.$k $lastRoute[$key].$k ('actual original committed '+$k)
                Assert-TraversalExactArray $s.OriginalNavigation.$k $f.Navigation.$k ('actual entry committed '+$k)
            }
            if($s.State -cne 'WAITING' -or $s.CurrentPending -isnot [bool] -or $s.CurrentPending -or $s.CurrentCommand -ne $s.Command -or $s.CurrentActuations -ne $s.BaseActuations){throw 'Stationary entry rewrote native control/counters'}
            if($s.BaseActuations -ne $nativeCount -or $s.Command -ne $nativeCommand){throw 'Stationary base counters differ from actual native prefix'}
            if($s.Entry -ceq 'BASELINE_BEFORE_FIRST_WRITER'){
                $b=$baseline[$key];Assert-TraversalClockSame $s.BaselineClock $b.Clock;Assert-TraversalStationaryBody $s.FrozenBody $s.BaselineFrozenBody
                if($s.Command -ne $b.Command -or @($frames|Where-Object {$_.MotionSession -eq $s.Session -and $_.Event -ceq 'MOVE_ISSUED' -and $_.Tick -le $f.Tick}).Count){throw 'Baseline entry already issued a native writer'}
            }elseif($s.Entry -ceq 'ACKNOWLEDGED_BRAKE_REST'){
                if($null -eq $zero -or $null -eq $rest -or $zero.Command -ne $s.Command -or $rest.Command -ne $s.Command -or $zero.MotionSession -ne $s.Session){throw 'Stationary ACK omitted real accepted brake zero'}
                Assert-TraversalExactArray $s.OriginalBrakeRest $rest.RestAdmission 'actual stationary original rest'
                Assert-TraversalStationaryBody $s.FrozenBody $zero.AcceptedBrakeZeroBody;Assert-TraversalStationaryBody $s.OriginalBrakeRest.FrozenBody $zero.AcceptedBrakeZeroBody
            }else{throw 'Unknown stationary entry lineage'}
            $start=Get-TraversalStationaryNativeDouble $s.StartedWall 'stationary start';$route=Get-TraversalStationaryNativeDouble $s.RouteStartedWall 'stationary route start';$global=Get-TraversalStationaryNativeDouble $s.GlobalDeadline 'stationary global deadline'
            if($start -lt (Get-TraversalStationaryNativeDouble $s.EntryClock.WallTime 'actual entry callback') -or $start -gt (Get-TraversalStationaryNativeDouble $s.LastGuard.CheckedWall 'actual entry guard') -or
                [single]$route -ne [single]$baseline[$key].PosePreviousTime -or (Get-TraversalStationaryNativeDouble $s.RouteDeadline 'original route deadline') -ne $route+120 -or $global -le $start -or
                (Get-TraversalStationaryNativeDouble $s.Deadline 'original stationary deadline') -ne [Math]::Min(($start+20),[Math]::Min(($route+120),$global))){throw 'Stationary eligibility refreshed original deadlines'}
            Assert-TraversalStationaryActualBody $s.BaselineBody $s.BaselineFrozenBody;Assert-TraversalStationaryActualBody $s.OriginalBody $s.FrozenBody
            Assert-TraversalClockSame $s.EntryClock $f.Clock;Assert-TraversalStationaryPhysical $s.LastGuard $f $s
            $nodes[$key]=@{Original=$s;LastClock=$f.Clock;Count=0;First=$null;FirstClock=$null;Span=0;Restarts=0;Ready=$false;ReadyReceipt=$null;Committed=$false;PlanReceipt=$null;NativeReceipt=$null;CommittedNavigation=$null;Written=$false;FirstWriter=0;FirstWitness=$false};continue
        }
        $node=$nodes[$key]
        if((Get-TraversalStationaryNativeDouble $f.GlobalDeadline 'actual immutable global') -ne (Get-TraversalStationaryNativeDouble $s.GlobalDeadline 'captured global')){throw 'Stationary actual frame global deadline changed'}
        foreach($k in @('Policy','Id','Entry','Session','Command','BaseActuations','RetryBefore','RetryAfter','StartedWall','RouteStartedWall','RouteDeadline','GlobalDeadline','Deadline','MaxSeconds','MinStableSeconds','MaxSamples','EntryClock','BaselineClock','BaselineBody','BaselineFrozenBody','OriginalBody','FrozenBody','Actual','RigidbodyPosition','Goal','Floor','FloorCenter','FloorSize','Anchor','OriginalNavigation','OriginalBrakeRest')){Assert-TraversalExactArray $s.$k $node.Original.$k ('immutable stationary '+$k)}
        if($node.Committed){
            Assert-TraversalExactArray $s.Ready $node.ReadyReceipt 'retained actual stationary READY'
            Assert-TraversalExactArray $s.Plan $node.PlanReceipt 'retained sole stationary native Plan'
            Assert-TraversalExactArray $s.Native $node.NativeReceipt 'retained actual post-Plan native observation'
            if(-not $node.FirstWitness -and $f.Event -in @('MOVE_DECISION','MOVE_ISSUED','MOTION_WITNESS')){
                foreach($k in @('RouteFrom','RouteTo','RoutePolys','RoutePlan','Corners','PlannedMesh','PlannedTileChangeVersion','PlannedTileDataVersion','RouteFilter')){Assert-TraversalExactArray $f.Navigation.$k $node.CommittedNavigation.$k ('first stationary writer committed '+$k)}
            }
        }
        if($f.Event -ceq 'STATIONARY_REPLAN_OBSERVATION'){
            if($node.Ready -or $node.Committed -or $s.CurrentPending -ne $false -or $s.CurrentActuations -ne $s.BaseActuations -or $f.WriterCalled -ne $false){throw 'Overlapping/repeated stationary observation or hidden writer'}
            $c=$f.Clock;$before=$node.LastClock
            if($node.Count -gt 0 -and ($c.Sequence -ne $before.Sequence+1 -or (Get-TraversalStationaryNativeDouble $c.FixedTime 'stationary fixed')-(Get-TraversalStationaryNativeDouble $before.FixedTime 'prior fixed') -ne $before.Delta -or
                (Get-TraversalStationaryNativeDouble $c.FixedUnscaledTime 'stationary unscaled')-(Get-TraversalStationaryNativeDouble $before.FixedUnscaledTime 'prior unscaled') -ne $before.UnscaledDelta)){throw 'Stationary callback/physics continuity reset'}
            if($node.Count -eq 0){Assert-TraversalClockSame $c $s.EntryClock}
            $node.Count++;if($s.Observation -ne $node.Count -or $node.Count -gt 512){throw 'Stationary observation count reset/exhausted'}
            Assert-TraversalStationaryPhysical $s.LastGuard $f $s;$n=$f.StationaryObservation.Native;Assert-TraversalStationaryNative $n $c
            $changed=$null -ne $node.First -and -not (Test-TraversalStationarySameNative $n $node.First)
            $expected='WAIT'
            if(-not $n.Ready -or $changed){if($node.First){$node.Restarts++};$node.First=$null;$node.FirstClock=$null}
            else{if($null -eq $node.First){$node.First=$n;$node.FirstClock=$c;$node.Span++;$expected='WINDOW_START'}else{$expected='WINDOW_ADVANCE'}
                if((Get-TraversalStationaryNativeDouble $c.WallTime 'span end')-(Get-TraversalStationaryNativeDouble $node.FirstClock.WallTime 'span start') -ge 2 -and
                    (Get-TraversalStationaryNativeDouble $c.FixedTime 'span fixed end')-(Get-TraversalStationaryNativeDouble $node.FirstClock.FixedTime 'span fixed start') -ge 2 -and
                    (Get-TraversalStationaryNativeDouble $c.FixedUnscaledTime 'span unscaled end')-(Get-TraversalStationaryNativeDouble $node.FirstClock.FixedUnscaledTime 'span unscaled start') -ge 2 -and
                    (Get-TraversalStationaryNativeDouble $n.CompletedWall 'native span end')-(Get-TraversalStationaryNativeDouble $node.First.CompletedWall 'native span start') -ge 2){$expected='READY';$node.Ready=$true}}
            if($f.StationaryObservation.Outcome -cne $expected -or $s.Span -ne $node.Span -or $s.SpanRestarts -ne $node.Restarts){throw 'Stationary readiness/span outcome fabricated'}
            if($s.State -cne $(if($expected -ceq 'READY'){'READY'}else{'WAITING'}) -or $s.CurrentCommand -ne $s.Command){throw 'Stationary observation invented controller state/native command'}
            if($expected -ceq 'READY'){
                Assert-TraversalClockSame $s.Ready.Clock $c;Assert-TraversalClockSame $s.Ready.FirstClock $node.FirstClock
                Assert-TraversalExactArray $s.Ready.FirstNative $node.First 'independently replayed first native readiness';Assert-TraversalExactArray $s.Ready.LastNative $n 'independently replayed last native readiness'
                if($s.Ready.Observation -ne $node.Count -or $s.Ready.Span -ne $node.Span -or $s.Ready.SpanRestarts -ne $node.Restarts){throw 'Stationary READY receipt rebased replayed counters'};$node.ReadyReceipt=$s.Ready
            }elseif($null -ne $s.Ready){throw 'Stationary READY receipt preceded actual eligibility'}
            $node.LastClock=$c
        }elseif($f.Event -ceq 'STATIONARY_REPLAN_COMMITTED'){
            if(-not $node.Ready -or $node.Committed -or $s.Plan.CallCount -ne 1 -or $s.Plan.NativeQueriesStarted -ne $true -or $s.Plan.Accepted -ne $true -or $s.State -cne 'COMMITTED'){throw 'Stationary Plan omitted eligibility or repeated native commit'}
            Assert-TraversalExactArray $s.Ready $node.ReadyReceipt 'actual stationary READY receipt retained to Plan'
            Assert-TraversalClockSame $f.Clock $node.LastClock;Assert-TraversalStationaryCombinedGuard $s.Plan.Guard $f $s
            $begin=Get-TraversalStationaryNativeDouble $s.Plan.StartedWall 'actual stationary Plan start';$end=Get-TraversalStationaryNativeDouble $s.Plan.CompletedWall 'actual stationary Plan end';$wall=Get-TraversalStationaryNativeDouble $f.Clock.WallTime 'actual READY callback'
            if($s.Plan.Phase -cne 'COMMITTED_NATIVE' -or $begin -lt $wall -or $begin -gt (Get-TraversalStationaryNativeDouble $s.Plan.Guard.Physical.CheckedWall 'actual postquery physical guard') -or
                $end -lt (Get-TraversalStationaryNativeDouble $s.Plan.Guard.CheckedWall 'postquery guard') -or $end -lt $begin -or $end-$wall -gt 0.1 -or $end -gt (Get-TraversalStationaryNativeDouble $s.Deadline 'original deadline')){throw 'Stationary Plan refreshed callback/deadline or query order'}
            Assert-TraversalNativeRoutePlan $s.Plan.Navigation;Assert-TraversalExactPoint $s.Plan.Navigation.RouteFrom $s.Actual 'fresh actual stationary Plan origin';Assert-TraversalExactPoint $s.Plan.Navigation.RouteTo $s.Goal 'original stationary goal'
            if([string]$s.Plan.Navigation.PlannedMesh -cne [string]$node.First.Handle -or $s.Plan.Navigation.PlannedTileChangeVersion -ne $node.First.Change -or $s.Plan.Navigation.PlannedTileDataVersion -ne $node.First.Data -or $s.Plan.Navigation.RouteFilter -ne $s.OriginalNavigation.RouteFilter){throw 'Stationary Plan changed admitted native context/filter'}
            Assert-TraversalStationaryNative $s.Native $f.Clock
            if(-not (Test-TraversalStationarySameNative $s.Native $node.First) -or (Get-TraversalStationaryNativeDouble $s.Native.StartedWall 'post-Plan native start') -lt $end -or
                (Get-TraversalStationaryNativeDouble $s.Native.CompletedWall 'post-Plan native end') -gt $wall+(Get-TraversalStationaryNativeDouble $f.WallTelemetry.ReadDelay 'actual commit emission')){throw 'Post-Plan actual native observation is stale/different/unbound'}
            Assert-TraversalExactArray $s.Plan.Navigation $f.Navigation 'actual committed stationary navigation';$node.Committed=$true;$node.PlanReceipt=$s.Plan;$node.NativeReceipt=$s.Native;$node.CommittedNavigation=$s.Plan.Navigation
        }elseif($f.Event -in @('MOVE_DECISION','MOVE_ISSUED','REPATH','REPATH_AFTER_REST','ARRIVED')){
            if(-not $node.Committed){throw 'Stationary eligibility fabricated progress before its sole fresh Plan'}
            if($f.Event -ceq 'MOVE_ISSUED' -and -not $node.Written){
                if($f.FinalAdmission.StationaryBodyRequired -isnot [bool] -or -not $f.FinalAdmission.StationaryBodyRequired -or $f.FinalAdmission.StationaryBodyMatched -ne $true){throw 'First stationary writer opted out of exact body guard'}
                Assert-TraversalStationaryBody $f.FinalAdmission.StationaryBody $s.FrozenBody;$node.Written=$true;$node.FirstWriter=$f.Command
            }
        }
        if($node.Written -and $f.Event -ceq 'MOTION_WITNESS' -and $f.Command -eq $node.FirstWriter){$node.FirstWitness=$true}
    }
    if(-not $terminal -and @($nodes.Values|Where-Object {-not $_.Committed}).Count){throw 'Incomplete stationary eligibility/native Plan lifecycle'}
}
function Assert-TraversalStationaryTerminal($f,$witness,$pending,$frames,$expectedActor){
    $frames=@($frames);$fi=-1;for($i=0;$i -lt $frames.Count;$i++){if([object]::ReferenceEquals($frames[$i],$f)){$fi=$i;break}}
    $s=$f.StationaryReplan
    if($fi -lt 0 -or $f.Event -cnotin @('BLOCKED','MOVE_REJECTED') -or $f.Schema -ne 2 -or $f.Profile.StationaryReplanPolicy -cne 'MEASURED_STATIONARY_NATIVE_V1' -or
        $s.Policy -cne 'MEASURED_STATIONARY_NATIVE_V1' -or $s.Id -ne $f.MotionSession -or $s.Session -ne $f.MotionSession -or $s.Entry -cnotin @('BASELINE_BEFORE_FIRST_WRITER','ACKNOWLEDGED_BRAKE_REST') -or
        $s.FirstWriterCommand -ne 0 -or $s.CurrentPending -isnot [bool] -or $s.CurrentPending -or $s.CurrentCommand -ne $s.Command -or $s.CurrentActuations -ne $s.BaseActuations){throw 'Unbound stationary no-writer terminal context'}
    Assert-TraversalStationaryAnchors $f $frames $expectedActor
    foreach($key in @('Id','Session','Command','BaseActuations','CurrentCommand','CurrentActuations','FirstWriterCommand','RetryBefore','RetryAfter','Observation','Span','SpanRestarts')){$n=Get-TraversalNumber $s.$key ('stationary terminal '+$key);if($n -lt 0 -or $n -ne [Math]::Floor($n)){throw 'Invalid stationary terminal ordinal/counter'}}
    if($s.RetryBefore -ne 0 -or $s.RetryAfter -ne 1 -or $s.MaxSeconds -ne 20 -or $s.MinStableSeconds -ne 2 -or $s.MaxSamples -ne 512 -or $s.Observation -gt 512){throw 'Stationary terminal reset or extended an original budget'}
    $start=Get-TraversalStationaryNativeDouble $s.StartedWall 'stationary immutable start';$route=Get-TraversalStationaryNativeDouble $s.RouteStartedWall 'stationary original route start'
    $routeEnd=Get-TraversalStationaryNativeDouble $s.RouteDeadline 'stationary original route deadline';$global=Get-TraversalStationaryNativeDouble $s.GlobalDeadline 'stationary original global deadline';$deadline=Get-TraversalStationaryNativeDouble $s.Deadline 'stationary immutable deadline'
    Assert-TraversalClock $s.EntryClock $f.Profile;$entryWall=Get-TraversalStationaryNativeDouble $s.EntryClock.WallTime 'stationary entry callback'
    if($route -lt 0 -or $route -gt $entryWall -or $start -lt $entryWall -or $routeEnd -ne $route+120 -or $global -lt $route -or $deadline -ne [Math]::Min($start+20,[Math]::Min($routeEnd,$global))){throw 'Changed stationary original time envelope'}
    $terminal=@();for($i=0;$i -lt $frames.Count;$i++){$b=$frames[$i];if($b.MotionSession -eq $s.Session -and $b.StationaryReplan.Id -eq $s.Id -and $null -ne $b.StationaryReplan.Failure){$terminal+=,[pscustomobject]@{Index=$i;Frame=$b}}}
    if(-not $terminal.Count){throw 'Stationary terminal lacks its actual source failure'}
    $first=$terminal[0];$failure=$first.Frame.StationaryReplan.Failure;$failedAt=Get-TraversalStationaryNativeDouble $failure.Time 'stationary actual failure time'
    if($fi -lt $first.Index -and ($f.Event -cne 'MOVE_REJECTED' -or $fi -ne $first.Index-1)){throw 'Stationary refusal borrowed a future unrelated failure'}
    if($first.Frame.Event -cne 'BLOCKED' -or $first.Frame.StationaryReplan.State -cne 'TERMINAL' -or $failure.Phase -cnotin @('BLOCK','STOP','TIMEOUT_HEARTBEAT') -or [string]::IsNullOrWhiteSpace([string]$failure.Reason) -or $failedAt -lt $start){throw 'Missing actual stationary failure phase/time'}
    if([string]$first.Frame.Reason -cne [string]$failure.Reason){throw 'Stationary first terminal lost its actual source failure reason'}
    if($null -eq $failure.Clock){
        if([single]$failedAt -gt [single](Get-TraversalNumber $first.Frame.Time 'actual unclocked stationary failure emission')){throw 'Stationary failure time exceeds its actual unclocked Stop'}
    }else{
        Assert-TraversalClockSame $first.Frame.Clock $failure.Clock;$failureWall=Get-TraversalStationaryNativeDouble $first.Frame.Clock.WallTime 'actual stationary failure callback';$failureDelay=Get-TraversalStationaryNativeDouble $first.Frame.WallTelemetry.ReadDelay 'actual stationary failure emission delay'
        if($failedAt -lt $failureWall -or $failedAt-$failureWall -gt $failureDelay){throw 'Stationary actual failure time exceeds its own emission'}
        $failureView=[ordered]@{};foreach($p in $first.Frame.PSObject.Properties){$failureView[$p.Name]=$p.Value};$failureView.Event='BLOCKED';$failureView.NativeResult='NOT_ISSUED';Assert-TraversalWallTelemetry ([pscustomobject]$failureView) $first.Frame.PreviousClock -NoActuationTerminal
    }
    if($failure.Phase -ceq 'TIMEOUT_HEARTBEAT' -and ($null -ne $failure.Clock -or $failedAt -le $deadline)){throw 'Heartbeat invented a fixed callback or unexpired deadline'}
    $started=@();$bases=@();$rests=@()
    for($i=0;$i -le $first.Index;$i++){$b=$frames[$i];if($b.MotionSession -ne $s.Session){continue};if($b.Event -ceq 'STATIONARY_REPLAN_STARTED'){$started+=,[pscustomobject]@{Index=$i;Frame=$b}};if($b.Event -ceq 'CLOCK_BASELINE'){$bases+=,[pscustomobject]@{Index=$i;Frame=$b}};if($b.Event -ceq 'ACTUAL_REST' -and $b.Command -eq $s.Command){$rests+=,[pscustomobject]@{Index=$i;Frame=$b}}}
    $entry=$null;$lineage=-1
    if($started.Count -eq 1){$entry=$started[0].Frame;Assert-TraversalClockSame $entry.Clock $s.EntryClock;if($start-$entryWall -gt (Get-TraversalNumber $f.Profile.MaxTick 'original callback limit')){throw 'Accepted stationary entry was already late'}}
    elseif($started.Count -eq 0 -and $first.Frame.StationaryReplan.LastGuard.Phase -ceq 'ENTRY' -and $first.Frame.StationaryReplan.LastGuard.Accepted -is [bool] -and -not $first.Frame.StationaryReplan.LastGuard.Accepted){
        $entry=$first.Frame;$g=$first.Frame.StationaryReplan.LastGuard;Assert-TraversalClockSame $g.Clock $s.EntryClock
        $checked=Get-TraversalStationaryNativeDouble $g.CheckedWall 'actual rejected ENTRY guard';if($checked -lt $start -or $checked -gt $failedAt -or $s.Observation -ne 0 -or $null -ne $s.Ready -or $null -ne $s.Plan){throw 'Failed ENTRY invented an accepted window/plan'}
    }else{throw 'Stationary terminal has no unique entry or actual rejected ENTRY guard'}
    if($s.Entry -ceq 'BASELINE_BEFORE_FIRST_WRITER'){
        if($bases.Count -ne 1 -or $null -ne $s.OriginalBrakeRest){throw 'Stationary baseline borrowed a brake or repeated baseline'}
        $b=$bases[0].Frame;$lineage=$bases[0].Index;Assert-TraversalClockSame $s.BaselineClock $b.Clock
        Assert-TraversalExactArray $s.BaselineBody $b.Body 'stationary actual baseline body';Assert-TraversalExactArray $s.BaselineFrozenBody $s.FrozenBody 'stationary baseline frozen body'
        if($b.Command -ne $s.Command -or $b.Actuations -ne $s.BaseActuations -or $b.NativeResult -cne 'CLOCK_BASELINE'){throw 'Stationary baseline changed its command counter'}
        Assert-TraversalBody $b $expectedActor;Assert-TraversalExactPoint $b.Actual $s.Actual 'stationary original baseline pose';Assert-TraversalExactPoint $b.Body.Velocity @(0,0,0) 'stationary baseline native zero';Assert-TraversalExactPoint $b.ObservedVelocity @(0,0,0) 'stationary baseline observed zero'
    }else{
        if($rests.Count -ne 1 -or $null -eq $witness -or $witness.Event -cne 'MOTION_WITNESS' -or $witness.NativeResult -cne 'OBSERVED' -or $witness.MotionSession -ne $s.Session -or $witness.Command -ne $s.Command -or $witness.MotionMode -cnotin @('ACTUAL_BRAKE','BRAKE_HOLD') -or (Get-TraversalNumber $witness.Speed 'acknowledged brake speed') -ne 0){throw 'Stationary wait lacks its original physical zero-brake lineage'}
        $r=$rests[0].Frame;$lineage=$rests[0].Index;Assert-TraversalExactArray $s.OriginalBrakeRest $r.RestAdmission 'stationary original accepted rest receipt';Assert-TraversalClockSame $r.Clock $s.EntryClock
        Assert-TraversalExactArray $s.OriginalBrakeRest.FrozenBody $s.FrozenBody 'stationary accepted zero body before sink'
        Assert-TraversalExactArray $witness.AcceptedBrakeZeroBody $s.FrozenBody 'stationary original pre-sink zero witness body'
        Assert-TraversalStationaryActualBody $witness.Body $witness.AcceptedBrakeZeroBody
        $wi=-1;for($i=0;$i -lt $rests[0].Index;$i++){if([object]::ReferenceEquals($frames[$i],$witness)){$wi=$i;break}};if($wi -lt 0){throw 'Stationary rest borrowed an external witness'}
        Assert-TraversalClockSame $witness.Clock $r.Clock
        $intent=@($frames[0..$wi]|Where-Object {$_.Event -ceq 'MOVE_DECISION' -and $_.MotionSession -eq $s.Session -and $_.Command -eq $s.Command})
        $issue=@($frames[0..$wi]|Where-Object {$_.Event -ceq 'MOVE_ISSUED' -and $_.MotionSession -eq $s.Session -and $_.Command -eq $s.Command})
        if($intent.Count -ne 1 -or $issue.Count -ne 1 -or $intent[0].NativeResult -cne 'PRECHECKED' -or $issue[0].NativeResult -cne 'ISSUED' -or $issue[0].WriterCalled -isnot [bool] -or -not $issue[0].WriterCalled -or $issue[0].Clock.Sequence+1 -ne $witness.Clock.Sequence){throw 'Stationary brake rest lost its actual intent/issue lineage'}
        Assert-TraversalClockSame $witness.IssuedClock $issue[0].Clock;Assert-TraversalClock $witness.Clock $witness.Profile
        Assert-TraversalBody $witness $expectedActor;Assert-TraversalSupport $witness;Assert-TraversalContacts $witness;Assert-AcquisitionPolicy $witness
        $casts=Get-TraversalNumber $witness.Casts 'physical zero witness queries';if($casts -lt 1 -or $casts -gt 64 -or $casts -ne [Math]::Floor($casts) -or $witness.NativeVelocityMatches -isnot [bool] -or -not $witness.NativeVelocityMatches){throw 'Stationary brake witness exceeded physical budget or contradicted native velocity'}
        $br=$witness.Recovery;$step=Get-TraversalNumber $br.Step 'original brake step';$bw=Get-TraversalStationaryNativeDouble $br.StartWall 'original brake start';$ww=Get-TraversalStationaryNativeDouble $witness.Clock.WallTime 'original zero witness callback'
        if($br.Kind -cne 'MEASURED_BRAKE_V1' -or $br.Attempt -ne 1 -or $br.MaxSteps -ne 8 -or $br.MaxSeconds -ne 1 -or $br.Deceleration -ne 3 -or $step -lt 1 -or $step -gt 8 -or $step -ne [Math]::Floor($step) -or $witness.Clock.Sequence -ne $br.StartSequence+$step -or $ww -lt $bw -or $ww-$bw -gt 1){throw 'Stationary wait extended physical brake limits'}
        Assert-TraversalExactPoint (Get-TraversalPhysicsVelocity $witness.Actual $witness.From $witness.Dt) @(0,0,0) 'stationary actual brake delta';Assert-TraversalExactPoint $witness.Body.Velocity @(0,0,0) 'stationary measured native zero'
        Assert-TraversalRestGuard $r.RestAdmission.Guard $r ([pscustomobject]@{Actual=$r.Actual;RigidbodyPosition=$r.Body.RigidbodyPosition}) 'REST_ACK'
    }
    $view=[pscustomobject]@{Body=$s.OriginalBody;Actual=$s.Actual;From=$s.Actual;Profile=$f.Profile;Support=$s.Anchor;Overlaps=$entry.Overlaps;Mask=-1;Triggers='Ignore';Permission=$entry.Permission;WaterDepth=$entry.WaterDepth;SupportAccepted=$entry.SupportAccepted;OverlapClear=$entry.OverlapClear}
    Assert-TraversalBody $view $expectedActor;Assert-TraversalSupport $view;Assert-TraversalContacts $view;Assert-AcquisitionPolicy $view
    foreach($key in @('Position','RigidbodyPosition','Scale','Center','A','B')){Assert-TraversalExactPoint $s.FrozenBody.$key $s.OriginalBody.$key ('stationary frozen '+$key)}
    Assert-TraversalExactPoint $s.FrozenBody.CapsulePosition $s.OriginalBody.Position 'stationary original capsule transform'
    foreach($key in @('Rotation','CapsuleRotation')){Assert-TraversalVector $s.FrozenBody.$key 4;for($j=0;$j -lt 4;$j++){if($s.FrozenBody.$key[$j] -ne $s.OriginalBody.Rotation[$j]){throw 'Stationary frozen rotation changed'}}}
    foreach($pair in @(@('Radius','Radius'),@('Height','Height'),@('Capsule','Instance'),@('Rigidbody','RigidbodyInstance'),@('Direction','Direction'),@('Layer','Layer'),@('Enabled','Enabled'),@('Trigger','Trigger'),@('Kinematic','Kinematic'),@('Gravity','Gravity'),@('Detect','DetectCollisions'),@('CollisionMode','CollisionMode'),@('AgentStopped','AgentStopped'),@('AgentPosition','AgentUpdatePosition'),@('AgentRotation','AgentUpdateRotation'))){if([string]$s.FrozenBody.($pair[0]) -cne [string]$s.OriginalBody.($pair[1])){throw 'Stationary original frozen body/writer tuple changed'}}
    Assert-TraversalExactPoint $s.OriginalBody.Velocity @(0,0,0) 'stationary original native zero';Assert-TraversalExactPoint $s.OriginalBody.RigidbodyPosition $s.RigidbodyPosition 'stationary original rigid pose'
    Assert-TraversalBrakeFloor $s.Anchor.Collider ([pscustomobject]@{Floor=$s.Floor.Instance;FloorCollider=$s.Floor;FloorCenter=$s.FloorCenter;FloorSize=$s.FloorSize})
    if($null -ne $s.Plan){
        $p=$s.Plan;$ps=Get-TraversalStationaryNativeDouble $p.StartedWall 'stationary sole Plan start';$pe=Get-TraversalStationaryNativeDouble $p.CompletedWall 'stationary sole Plan end'
        if($p.CallCount -ne 1 -or $p.Accepted -isnot [bool] -or $p.NativeQueriesStarted -isnot [bool] -or $null -eq $s.Ready -or $ps -gt $pe -or $pe -gt $failedAt){throw 'Stationary terminal invented/repeated an unbound Plan'}
        if($p.Accepted){
            if(-not $p.NativeQueriesStarted -or $p.Phase -cne 'COMMITTED_NATIVE' -or $p.Guard.Phase -cne 'READY_PRECOMMIT'){throw 'Stationary accepted Plan never completed its real native queries'}
            foreach($key in @('Accepted','NativeAccepted','Unchanged','ClockAccepted')){if($p.Guard.$key -isnot [bool] -or -not $p.Guard.$key){throw 'Stationary retained successful Plan guard is contradictory'}}
            Assert-TraversalClockSame $p.Guard.Clock $s.Ready.Clock;if((Get-TraversalStationaryNativeDouble $p.Guard.CheckedWall 'stationary successful Plan guard') -gt $pe){throw 'Stationary accepted Plan precedes its current guard'}
        }
        $readyRows=@($frames[0..$first.Index]|Where-Object {$_.MotionSession -eq $s.Session -and $_.Event -ceq 'STATIONARY_REPLAN_OBSERVATION' -and $_.StationaryObservation.Outcome -ceq 'READY'})
        if($readyRows.Count -ne 1){throw 'Stationary Plan lacks its actual unique qualifying observation'}
        Assert-TraversalExactArray $s.Ready $readyRows[0].StationaryReplan.Ready 'stationary actual qualifying receipt';Assert-TraversalClockSame $s.Ready.Clock $readyRows[0].Clock
        Assert-TraversalExactArray $s.Ready.LastNative $readyRows[0].StationaryObservation.Native 'stationary actual last eligible native observation'
        $firstRows=@($frames[0..$first.Index]|Where-Object {$_.MotionSession -eq $s.Session -and $_.Event -ceq 'STATIONARY_REPLAN_OBSERVATION' -and $_.StationaryObservation.Outcome -ceq 'WINDOW_START' -and $_.Clock.Sequence -eq $s.Ready.FirstClock.Sequence})
        if($firstRows.Count -ne 1){throw 'Stationary Plan lacks its actual native span start'}
        Assert-TraversalClockSame $s.Ready.FirstClock $firstRows[0].Clock;Assert-TraversalExactArray $s.Ready.FirstNative $firstRows[0].StationaryObservation.Native 'stationary actual first eligible native observation'
        $rc=$s.Ready.Clock;$fc=$s.Ready.FirstClock;Assert-TraversalClock $rc $f.Profile;Assert-TraversalClock $fc $f.Profile
        foreach($key in @('WallTime','FixedTime','FixedUnscaledTime')){if((Get-TraversalStationaryNativeDouble $rc.$key 'stationary qualifying clock')-(Get-TraversalStationaryNativeDouble $fc.$key 'stationary span start clock') -lt 2){throw 'Stationary Plan borrowed an incomplete native span'}}
        if($ps -lt (Get-TraversalStationaryNativeDouble $rc.WallTime 'stationary ready callback') -or $ps -gt $deadline){throw 'Stationary Plan started outside its original ready window'}
        if($ps -lt (Get-TraversalStationaryNativeDouble $s.Ready.LastNative.CompletedWall 'stationary qualifying query end') -or ($p.Accepted -and $pe-(Get-TraversalStationaryNativeDouble $rc.WallTime 'stationary successful Plan callback') -gt (Get-TraversalNumber $f.Profile.MaxTick 'unchanged Plan callback limit'))){throw 'Stationary Plan lost native observation order or accepted a late query'}
        foreach($n in @($s.Ready.FirstNative,$s.Ready.LastNative)){foreach($key in @('Available','DefaultMesh','Built','OnMesh','ProfileMatched','FilterMatched','Ready')){if($n.$key -isnot [bool] -or -not $n.$key){throw 'Stationary Plan borrowed an ineligible native span'}};if($n.PendingTiles -isnot [bool] -or $n.PendingTiles -or [string]::IsNullOrWhiteSpace([string]$n.Handle) -or [string]$n.Handle -ceq '0'){throw 'Stationary native span is pending/unknown'}}
        if($s.Ready.LastNative.SameSpanObject -isnot [bool] -or -not $s.Ready.LastNative.SameSpanObject -or $s.Ready.FirstNative.Handle -cne $s.Ready.LastNative.Handle -or $s.Ready.FirstNative.Change -ne $s.Ready.LastNative.Change -or $s.Ready.FirstNative.Data -ne $s.Ready.LastNative.Data -or
            (Get-TraversalStationaryNativeDouble $s.Ready.LastNative.CompletedWall 'last eligible native completion')-(Get-TraversalStationaryNativeDouble $s.Ready.FirstNative.CompletedWall 'first eligible native completion') -lt 2){throw 'Stationary native span changed object/epoch or native time'}
    }
    $md=@();$mr=@();$commits=@($frames[0..$first.Index]|Where-Object {$_.MotionSession -eq $s.Session -and $_.Event -ceq 'STATIONARY_REPLAN_COMMITTED'})
    if($commits.Count -gt 1 -or ($commits.Count -eq 1 -and ($null -eq $s.Plan -or -not $s.Plan.Accepted))){throw 'Stationary terminal lost or repeated its committed Plan'}
    if($commits.Count){Assert-TraversalExactArray $commits[0].StationaryReplan.Plan $s.Plan 'stationary retained actual Plan';Assert-TraversalWallTelemetry $commits[0] $commits[0].PreviousClock}
    for($i=$lineage+1;$i -lt $frames.Count;$i++){
        $b=$frames[$i];if($b.MotionSession -ne $s.Session -or [string]$b.Actor -cne [string]$expectedActor -or $b.World -cne $f.World -or $b.Stage -cne $f.Stage){throw 'Stationary terminal changed actor/session/stage'}
        Assert-TraversalExactArray $b.Profile $f.Profile 'stationary immutable source profile'
        foreach($key in @('WriterCalled','UnobservedCommand')){if($null -ne $b.$key -and $b.$key -isnot [bool]){throw 'Untyped stationary no-writer terminal state'}}
        if($b.Command -ne $s.Command -and $b.Command -ne $s.Command+1){throw 'Stationary terminal changed actual/candidate command'}
        if($b.WriterCalled -eq $true -or $b.UnobservedCommand -eq $true -or $null -ne $b.PendingDecision -or $b.Event -in @('MOVE_ISSUED','MOTION_WITNESS','ARRIVED') -or ($null -ne $b.Actuations -and $b.Actuations -ne $s.BaseActuations)){throw 'Stationary refusal issued or credited motion'}
        if($b.Event -ceq 'MOVE_DECISION'){$md+=,$b;if($i -ge $first.Index){throw 'Stationary terminal published a future intent'}}
        if($b.Event -ceq 'MOVE_REJECTED'){$mr+=,$b}
        if($i -ge $first.Index -and $b.Event -cne 'BLOCKED'){throw 'Stationary failure resumed observation/rest/repath/success'}
        if($i -ge $first.Index){foreach($key in @('State','CurrentCommand','CurrentActuations','CurrentPending','Observation','Span','SpanRestarts','Ready','Native','LastGuard','Plan','FirstWriterCommand','Failure')){Assert-TraversalExactArray $b.StationaryReplan.$key $first.Frame.StationaryReplan.$key ('stationary terminal retained '+$key)}}
        if($i -ge $first.Index){
            if($b.NativeResult -cnotin @('NOT_ISSUED','STOPPED') -or ($null -eq $b.Clock -and $b.NativeResult -cne 'STOPPED')){throw 'Stationary terminal suffix has an impossible native outcome'}
            if($null -ne $b.Clock){Assert-TraversalClockSame $b.Clock $failure.Clock}
        }
        if($null -ne $b.StationaryReplan){foreach($key in @('Policy','Id','Entry','Session','Command','BaseActuations','RetryBefore','RetryAfter','StartedWall','RouteStartedWall','RouteDeadline','GlobalDeadline','Deadline','EntryClock','BaselineClock','BaselineBody','BaselineFrozenBody','OriginalBody','FrozenBody','Actual','RigidbodyPosition','Goal','Floor','FloorCenter','FloorSize','Anchor','OriginalNavigation','OriginalBrakeRest')){Assert-TraversalExactArray $b.StationaryReplan.$key $s.$key ('stationary immutable terminal '+$key)};if($b.StationaryReplan.CurrentPending -isnot [bool] -or $b.StationaryReplan.CurrentPending -or (Get-TraversalNumber $b.StationaryReplan.CurrentCommand 'stationary current command') -ne $s.Command -or (Get-TraversalNumber $b.StationaryReplan.CurrentActuations 'stationary current actuations') -ne $s.BaseActuations -or $b.StationaryReplan.FirstWriterCommand -ne 0){throw 'Stationary terminal lost no-writer state'}}
    }
    if($md.Count -gt 1 -or $mr.Count -gt 1){throw 'Stationary terminal replayed first candidate admission'}
    if($md.Count){
        $m=$md[0];if($m.Command -ne $s.Command+1 -or $m.NativeResult -cne 'PRECHECKED' -or $null -eq $s.Plan -or -not $s.Plan.Accepted -or $commits.Count -ne 1){throw 'Stationary intent lacks its sole committed Plan'}
        Assert-TraversalWallTelemetry $m $m.PreviousClock;Assert-TraversalClockSame $m.Clock $failure.Clock
        if($null -ne $pending -and -not [object]::ReferenceEquals($pending,$m)){throw 'Stationary terminal borrowed another pending intent'}
        if($mr.Count){Assert-TraversalFinalIssue $mr[0] $m ([int]$s.BaseActuations) -Rejected -ExpectedVelocity @(0,0,0)}
        elseif($failure.Phase -cne 'STOP'){throw 'Stationary intent has no rejected guard or actual sink Stop'}
    }elseif($null -ne $pending -or $f.Event -ceq 'MOVE_REJECTED'){throw 'Stationary terminal has no matching unissued intent'}
    if($null -eq $failure.Clock){
        if($null -ne $f.Clock -or $f.Event -cne 'BLOCKED' -or $f.NativeResult -cne 'STOPPED' -or $failure.Phase -cnotin @('STOP','TIMEOUT_HEARTBEAT')){throw 'Unclocked stationary failure invented a physical callback'}
    }elseif($null -ne $f.Clock){
        Assert-TraversalClockSame $f.Clock $failure.Clock;$wall=Get-TraversalStationaryNativeDouble $f.Clock.WallTime 'stationary failed callback';$delay=Get-TraversalStationaryNativeDouble $f.WallTelemetry.ReadDelay 'stationary failed callback read delay'
        $operationAt=if($f.Event -ceq 'MOVE_REJECTED'){Get-TraversalStationaryNativeDouble $f.FinalAdmission.CheckedWall 'actual rejected native guard'}else{$failedAt}
        if($operationAt -lt $wall -or $operationAt-$wall -gt $delay -or $operationAt -gt $failedAt){throw 'Stationary rejected operation time is outside its own emission'}
        if($f.NativeResult -cnotin @('NOT_ISSUED','STOPPED') -or $f.WriterCalled -eq $true){throw 'Stationary terminal is not a source no-writer refusal'}
        $copy=[ordered]@{};foreach($p in $f.PSObject.Properties){$copy[$p.Name]=$p.Value};$copy.Event='BLOCKED';$copy.NativeResult='NOT_ISSUED';Assert-TraversalWallTelemetry ([pscustomobject]$copy) $f.PreviousClock -NoActuationTerminal
    }
    $stop=$frames[-1];if($stop.Event -cne 'BLOCKED' -or $stop.NativeResult -cne 'STOPPED' -or $null -ne $stop.Clock -or $stop.Command -ne $s.Command){throw 'Stationary terminal lacks final unclocked no-writer Stop'}
}
function Assert-TraversalStationaryTerminalResult($nav){
    $frames=@($nav.Traversal.Frames);$index=-1;$failure=$null
    for($i=0;$i -lt $frames.Count;$i++){if($frames[$i].Profile.StationaryReplanPolicy -ceq 'MEASURED_STATIONARY_NATIVE_V1' -and $null -ne $frames[$i].StationaryReplan.Failure -and $frames[$i].StationaryReplan.FirstWriterCommand -eq 0){$index=$i;$failure=$frames[$i].StationaryReplan.Failure;break}}
    if($index -lt 0){return};if($nav.Status -cne 'PARTIAL' -or $nav.Traversal.Completed -eq $true){throw 'Stationary no-writer terminal cannot claim success'}
    $cutoff=if($null -ne $failure.Clock){Assert-TraversalClockSame $failure.Clock $frames[$index].Clock;Get-TraversalStationaryNativeDouble $failure.Clock.WallTime 'stationary terminal callback cutoff'}else{$at=Get-TraversalStationaryNativeDouble $failure.Time 'stationary unclocked terminal cutoff';if([single]$at -gt [single](Get-TraversalNumber $frames[$index].Time 'actual unclocked terminal emission')){throw 'Stationary result cutoff moved beyond actual Stop'};$at}
    foreach($a in @($nav.FirstHome.NativePlacements)+@($nav.FirstHome.Operations)+@($nav.Traversal.FixtureTransitions)+@($nav.Traversal.Fixture)+@($nav.FirstHome.Navigation)+@($nav.FirstHome.Phases)+@($nav.Traversal.BuildRests)+@($nav.Traversal.Detour)){if($null -ne $a -and [single](Get-TraversalNumber $a.Time 'native progress before stationary refusal') -gt [single]$cutoff){throw 'Stationary refusal advanced native progress'}}
    foreach($a in @($nav.Traversal.BuildPlans)){if($null -ne $a -and (Get-TraversalStationaryNativeDouble $a.Time 'native Double graph before stationary refusal') -gt $cutoff){throw 'Stationary refusal created another build graph'}}
    foreach($w in @($nav.Traversal.DestinationWindows)){if($null -ne $w -and (Get-TraversalStationaryNativeDouble $w.Contract.Start 'native Double goal before stationary refusal') -ge $cutoff){throw 'Stationary refusal queued another goal'}}
    foreach($scene in @($nav.Traversal.Scenes|Where-Object Status -ceq 'PASSED')){$end=Get-TraversalNumber $scene.FramesTo 'stationary terminal scene end';if($end -lt 0 -or $end -ne [Math]::Floor($end) -or $end -gt $index){throw 'Stationary refusal credited a later scene'}}
}
function Get-TraversalAdmissionEpoch($f){
    $n=$f.Navigation;$r=$n.EpochRevalidation
    if($null -eq $n.AdmissionTileChangeVersion -and $null -eq $n.AdmissionTileDataVersion){if($null -ne $r){throw 'Epoch proof omitted its linked admission epoch'};return @($n.PlannedTileChangeVersion,$n.PlannedTileDataVersion)}
    $change=Get-TraversalNumber $n.AdmissionTileChangeVersion 'effective admission change';$data=Get-TraversalNumber $n.AdmissionTileDataVersion 'effective admission data'
    if($change -lt 0 -or $data -lt 0 -or $change -ne [Math]::Floor($change) -or $data -ne [Math]::Floor($data)){throw 'Invalid effective admission epoch'}
    if($null -eq $r){if($change -ne $n.PlannedTileChangeVersion -or $data -ne $n.PlannedTileDataVersion){throw 'Counter-only native epoch refresh'};return @($change,$data)}
    $kind=if($f.Profile.EpochRevalidationPolicy -ceq 'SAME_COMMITTED_ROUTE_EPOCH_V2'){'SAME_COMMITTED_ROUTE_EPOCH_V2'}else{'SAME_COMMITTED_ROUTE_EPOCH_V1'}
    if($null -ne $f.Profile.EpochRevalidationPolicy -and $f.Profile.EpochRevalidationPolicy -cne 'SAME_COMMITTED_ROUTE_EPOCH_V2'){throw 'Unknown source epoch policy'}
    if($r.Kind -cne $kind -or $r.Accepted -ne $true -or $r.Session -ne $f.MotionSession -or $r.Actor -cne $f.Actor -or $r.World -cne $f.World -or
        $r.OldChange -ne $n.PlannedTileChangeVersion -or $r.OldData -ne $n.PlannedTileDataVersion -or $r.NewChange -ne $change -or $r.NewData -ne $data -or
        $r.Mesh -cne $n.PlannedMesh -or $r.Filter -ne $n.RouteFilter){throw 'Unbound separate same-route admission proof'}
    foreach($pair in @(@('CommittedPlan','RoutePlan'),@('CommittedPolys','RoutePolys'),@('CommittedCorners','Corners'),@('From','RouteFrom'),@('Goal','RouteTo'))){Assert-TraversalExactArray $r.($pair[0]) $n.($pair[1]) $pair[0]}
    @($change,$data)
}
function Assert-TraversalEpochProof($f,$prior){
    $r=$f.EpochRevalidation;$n=$f.Navigation
    if($r.Kind -ceq 'SAME_COMMITTED_ROUTE_EPOCH_V2'){Assert-TraversalEpochSeriesHeader $f $prior}
    Assert-TraversalExactArray $r $n.EpochRevalidation 'top/current epoch proof'
    if($null -eq $r -or $r.Accepted -isnot [bool] -or -not $r.Accepted -or $r.Phase -cne 'SEALED_BRAKE_ONLY' -or $f.Event -cne 'NATIVE_ROUTE_EPOCH_REVALIDATED' -or
        $f.NativeResult -cne 'REVALIDATED' -or $f.WriterCalled -eq $true -or $f.UnobservedCommand -eq $true -or $null -ne $f.PendingDecision -or
        ($r.Kind -cne 'SAME_COMMITTED_ROUTE_EPOCH_V2' -and ($r.Attempt -ne 1 -or $r.MaxAttempts -ne 1)) -or $null -eq $prior -or $prior.Event -cne 'MOTION_WITNESS' -or $prior.NativeResult -cne 'OBSERVED' -or $prior.Speed -le 0 -or
        $r.Command -ne $prior.Command -or $f.Command -ne $prior.Command -or $r.Session -ne $prior.MotionSession -or $f.MotionSession -ne $prior.MotionSession){throw 'Epoch proof lacks its single accepted moving witness/no-writer context'}
    $null=Get-TraversalAdmissionEpoch $f
    Assert-TraversalClock $r.Clock $f.Profile;Assert-TraversalClockSame $r.Clock $prior.Clock;Assert-TraversalClockSame $f.Clock $prior.Clock
    $start=Get-TraversalNumber $r.StartedWall 'epoch proof start';$native=Get-TraversalNumber $r.NativeCompletedWall 'epoch native completion';$end=Get-TraversalNumber $r.CompletedWall 'epoch full proof completion'
    $clockWall=Get-TraversalNumber $r.Clock.WallTime 'original epoch callback';$routeWall=Get-TraversalNumber $r.RouteStartedWall 'original route clock'
    if($start -lt $clockWall -or $native -lt $start -or $end -lt $native -or $end-$clockWall -gt 0.10000001 -or $routeWall -gt $clockWall -or $clockWall-$routeWall -gt 120){throw 'Epoch proof refreshed/overran original callback or route deadline'}
    foreach($key in @('OriginalObjectMatched','CurrentObjectMatched','GlobalPendingBefore','GlobalPendingAfterNative','GlobalPendingAtSeal')){if($r.$key -isnot [bool]){throw 'Missing actual native epoch observation'}}
    if(-not $r.OriginalObjectMatched -or -not $r.CurrentObjectMatched){throw 'Epoch proof changed the real mesh object'}
    Assert-TraversalExactPoint $r.Actual $prior.Actual 'epoch actual witness';Assert-TraversalExactPoint $f.Actual $prior.Actual 'epoch transition pose'
    Assert-TraversalExactArray $r.Body $prior.Body 'native body at epoch trigger';Assert-TraversalExactPoint $r.NativeVelocity $prior.Body.Velocity 'native velocity retained'
    $velocity=Get-TraversalPhysicsVelocity $prior.Actual $prior.From $prior.Dt;Assert-TraversalSamePoint $r.Velocity $velocity 'measured 3D epoch momentum'
    Assert-TraversalBody $f $f.Actor;Assert-TraversalSupport $f;Assert-TraversalContacts $f
    foreach($field in @('RoutePlan','RoutePolys','Corners','RouteFrom','RouteTo','PlannedTileChangeVersion','PlannedTileDataVersion','PlannedMesh','RouteFilter')){Assert-TraversalExactArray $n.$field $prior.Navigation.$field ('committed '+$field)}
    Assert-TraversalNativeRoutePlan $n
    if(@($r.CommittedPlan).Count -ne 1 -or $r.OriginalIndex -lt 1 -or $r.OriginalIndex -ge @($r.CommittedCorners).Count){throw 'Epoch proof is composite or has another current corner'}
    foreach($build in @($r.BuildBefore,$r.BuildAfter)){
        foreach($pair in @(@('Climb','NavClimb'),@('Slope','NavSlope'),@('Radius','NavRadius'),@('Height','NavHeight'))){Assert-TraversalNear $build.($pair[0]) $f.Profile.($pair[1]) 'unchanged native epoch profile' 0}
    }
    foreach($pair in @(@($r.OriginalQuery,$r.From,$r.CommittedPolys,$r.CommittedCorners),@($r.CurrentQuery,$r.Actual,$r.CurrentQuery.NativePolys,$r.CurrentQuery.NativeCorners))){
        $view=[pscustomobject]@{RoutePlan=@($pair[0]);PlannedMesh=$r.Mesh;RouteFilter=$r.Filter;PlannedTileChangeVersion=$r.NewChange;PlannedTileDataVersion=$r.NewData;
            RouteFrom=$pair[1];RouteTo=$r.Goal;RoutePolys=$pair[2];Corners=$pair[3]}
        Assert-TraversalNativeRoutePlan $view
    }
    Assert-TraversalExactArray $r.OriginalQuery.NativePolys $r.CommittedPolys 'requeried original polygon sequence'
    Assert-TraversalExactArray $r.OriginalQuery.NativeCorners $r.CommittedCorners 'requeried original corner geometry'
    $suffix=Get-TraversalNumber $r.CurrentSuffix 'current committed suffix';$old=@($r.CommittedPolys);$fresh=@($r.CurrentQuery.NativePolys)
    if($suffix -lt 0 -or $suffix -ne [Math]::Floor($suffix) -or $suffix+$fresh.Count -ne $old.Count){throw 'Epoch current native path is not the original ordered suffix'}
    Assert-TraversalExactArray @($old|Select-Object -Skip $suffix) $fresh 'current ordered polygon suffix'
    Assert-TraversalExactArray @($r.CommittedCorners|Select-Object -Skip $r.OriginalIndex) @($r.CurrentQuery.NativeCorners|Select-Object -Skip 1) 'current committed remaining corners'
    foreach($pair in @(@('OldRefsBefore',$old),@('OldRefsAfter',$old),@('CurrentRefsBefore',$fresh),@('CurrentRefsAfter',$fresh))){
        $refs=@($r.($pair[0]));if($refs.Count -ne @($pair[1]).Count){throw 'Epoch proof omitted current public-ref validity'}
        for($j=0;$j -lt $refs.Count;$j++){if($refs[$j].Valid -isnot [bool] -or -not $refs[$j].Valid -or [string]$refs[$j].Ref -cne [string]$pair[1][$j]){throw 'Epoch old/fresh public ref is invalid or substituted'}}
    }
    $floor=[pscustomobject]@{Floor=$r.Floor.Instance;FloorCollider=$r.Floor;FloorCenter=$r.FloorCenter;FloorSize=$r.FloorSize;Corridor=$r.Corridor;RequiredDistance=$r.RequiredDistance}
    Assert-TraversalExactArray $r.Anchor $prior.Support 'original actual support anchor';Assert-TraversalBrakeFloor $r.Anchor.Collider $floor
    $parts=@($r.Corridor);$points=@($r.CorridorPoints)
    if($points.Count -ne $parts.Count+1){throw 'Epoch native coverage omitted physical brake/reserve endpoints'}
    Assert-TraversalExactPoint $points[0] $r.Actual 'physical brake original origin'
    for($j=0;$j -lt $parts.Count;$j++){Assert-TraversalExactPoint $points[$j] $parts[$j].From 'unmodified3D corridor join';Assert-TraversalExactPoint $points[$j+1] $parts[$j].Requested 'unmodified3D physical brake endpoint'}
    $brake=[pscustomobject]@{From=$r.Actual;Requested=$parts[0].Requested;Clock=$r.Clock;Profile=$f.Profile;Body=$f.Body;Recovery=$floor}
    Assert-TraversalBrakeCorridor $brake $r.Velocity
    $leg=Get-HomeRelative $r.CurrentQuery.NativeCorners[1] $r.Actual;$leg[1]=0;$length=Get-WorldDistance $leg @(0,0,0)
    if($length -le 0.001){throw 'Epoch corridor has no native first-leg extent'}
    foreach($point in $points){$delta=Get-HomeRelative $point $r.Actual;$delta[1]=0;$along=(Get-TraversalDot $delta $leg)/$length;$lateral=@(for($j=0;$j -lt 3;$j++){$delta[$j]-$leg[$j]*$along/$length})
        if($along -lt -0.001 -or $along -gt $length+0.001 -or (Get-WorldDistance $lateral @(0,0,0)) -gt 0.001){throw 'Physical brake/reserve leaves the fresh committed native first leg'}}
}
function Assert-TraversalEpochTransitions($frames){
    Assert-TraversalStationarySeries $frames
    if(@($frames|Where-Object {$null -ne $_.Profile.EpochRevalidationPolicy}).Count){Assert-TraversalEpochSeries $frames;return}
    $prior=$null;$pending=$false;$proved=@{};$proofRows=@{};$starts=@{};$phases=@{};$terminal=$false
    foreach($f in @($frames)){
        $key=[string]$f.MotionSession
        if($terminal -and $f.Event -in @('CLOCK_BASELINE','MOVE_DECISION','MOVE_ISSUED','MOTION_WITNESS','BRAKE_REQUESTED','BRAKE_ISSUED','BRAKE_WITNESSED','ACTUAL_REST','REPATH_AFTER_REST','REPATH','ARRIVED','NATIVE_ROUTE_EPOCH_REVALIDATED')){throw 'Epoch brake resumed control after terminal refusal'}
        if($f.Event -ceq 'CLOCK_BASELINE'){$starts[$key]=$f.PosePreviousTime}
        if($f.Event -ceq 'NATIVE_ROUTE_EPOCH_REVALIDATED'){
            if($pending -or $proved.ContainsKey($key)){throw 'Epoch proof replayed or refreshed a pending writer'}
            Assert-TraversalEpochProof $f $prior
            if(-not $starts.ContainsKey($key) -or [single]$f.EpochRevalidation.RouteStartedWall -ne [single]$starts[$key]){throw 'Epoch proof reset its original destination clock'}
            $proved[$key]=$f.EpochRevalidation|ConvertTo-Json -Depth 60 -Compress;$proofRows[$key]=$f.EpochRevalidation;$phases[$key]='WAIT_BRAKE'
        }
        $r=$f.Navigation.EpochRevalidation
        if($null -ne $f.EpochRevalidation -and $f.EpochRevalidation.Accepted -eq $true){Assert-TraversalExactArray $f.EpochRevalidation $r 'published top/current admission proof'}
        if($null -ne $r){
            if(-not $proved.ContainsKey($key) -or ($r|ConvertTo-Json -Depth 60 -Compress) -cne $proved[$key]){throw 'Current admission has an unobserved/mutated epoch proof'}
            $admitted=Get-TraversalAdmissionEpoch $f
            if($f.Event -in @('MOVE_DECISION','MOVE_ISSUED') -and ($admitted[0] -ne $f.Navigation.TileChangeVersion -or $admitted[1] -ne $f.Navigation.TileDataVersion)){throw 'Mid-brake epoch changed without terminal refusal'}
        }elseif($null -ne $f.Navigation.AdmissionTileChangeVersion -or $null -ne $f.Navigation.AdmissionTileDataVersion){$null=Get-TraversalAdmissionEpoch $f}
        if($phases.ContainsKey($key) -and $f.Event -cne 'NATIVE_ROUTE_EPOCH_REVALIDATED'){
            $phase=$phases[$key]
            if($phase -in @('WAIT_BRAKE','BRAKING','REST') -and $f.Event -in @('BLOCKED','BLOCKED_UNSAFE_BRAKING','MOVE_REJECTED')){$phases[$key]='TERMINAL';$terminal=$true}
            elseif($phase -ceq 'WAIT_BRAKE'){
                $p=$proofRows[$key]
                if($f.Event -cne 'BRAKE_REQUESTED' -or $null -eq $r -or $f.Command -ne $p.Command -or $f.Recovery.Kind -cne 'MEASURED_BRAKE_V1' -or
                    $f.Recovery.Session -ne $p.Session -or $f.Recovery.StartSequence -ne $p.Clock.Sequence -or $f.Recovery.StartWall -ne $p.Clock.WallTime){throw 'Accepted epoch proof omitted its immediate measured brake lifecycle'}
                Assert-TraversalClockSame $f.Clock $p.Clock;$phases[$key]='BRAKING'
            }elseif($phase -ceq 'BRAKING'){
                if($f.Event -in @('MOVE_DECISION','MOVE_ISSUED','MOTION_WITNESS') -and ($null -eq $r -or $f.MotionMode -notin @('ACTUAL_BRAKE','BRAKE_HOLD') -or $f.Recovery.Kind -cne 'MEASURED_BRAKE_V1')){throw 'Epoch admission licensed ordinary/unbound movement'}
                if($f.Event -ceq 'ACTUAL_REST'){if($null -eq $r){throw 'Epoch brake rest lost its immutable admission'};$phases[$key]='REST'}
                elseif($f.Event -in @('BRAKE_REQUESTED','REPATH','REPATH_AFTER_REST','ARRIVED')){throw 'Epoch brake advanced before measured recovery rest'}
            }elseif($phase -ceq 'REST'){
                if($f.Event -ceq 'REPATH_AFTER_REST'){
                    if($null -ne $r){throw 'Post-rest native replan retained old epoch admission'}
                    Assert-TraversalNativeRoutePlan $f.Navigation;Assert-TraversalExactPoint $f.Navigation.RouteFrom $f.Actual 'actual post-rest native plan origin'
                    Assert-TraversalExactPoint $f.Navigation.RouteTo $proofRows[$key].Goal 'original post-rest native plan goal';$phases[$key]='DONE'
                }
                elseif($f.Event -in @('MOVE_DECISION','MOVE_ISSUED','MOTION_WITNESS','BRAKE_REQUESTED','ACTUAL_REST','REPATH','ARRIVED')){throw 'Epoch brake resumed before its actual post-rest replan'}
            }elseif($phase -ceq 'DONE' -and $null -ne $r){throw 'Completed epoch brake reused stale admission'}
        }
        if($f.Event -ceq 'MOVE_DECISION'){$pending=$true}
        if($f.Event -in @('MOTION_WITNESS','MOVE_REJECTED','BLOCKED')){$pending=$false}
        if($f.Event -ceq 'MOTION_WITNESS' -and $f.NativeResult -ceq 'OBSERVED'){$prior=$f}
    }
    if(@($phases.Values|Where-Object {$_ -in @('WAIT_BRAKE','BRAKING','REST')}).Count){throw 'Epoch admission omitted its terminal or complete brake lifecycle'}
}
function Assert-TraversalFinalVelocity($g,$intent,$expected,[switch]$Rejected){
    $policy=$intent.Profile.FinalVelocityPolicy
    if($null -eq $policy){if($null -ne $g.VelocityPolicy){throw 'Final velocity policy detached from original source profile'};return}
    if($policy -cne 'NATIVE_POST_SINK_VELOCITY_V1'){throw 'Unknown final velocity admission policy'}
    if($g.Error -like 'DECISION_SINK_REFUSED:*'){
        if(-not $Rejected -or $g.Accepted -ne $false -or $null -ne $g.VelocityPolicy -or $null -ne $g.NativeVelocity){throw 'Sink cancellation invented a native velocity check'};return
    }
    if($g.VelocityPolicy -cne $policy -or $g.ExpectedVelocityFinite -isnot [bool] -or -not $g.ExpectedVelocityFinite -or $g.VelocityMatches -isnot [bool]){throw 'Missing mandatory native post-sink velocity contract'}
    Assert-TraversalVector $g.ExpectedVelocity;Assert-TraversalVector $expected
    for($j=0;$j -lt 3;$j++){if([single]$g.ExpectedVelocity[$j] -ne [single]$expected[$j]){throw 'Final guard replaced the last measured velocity with a requested/fake zero vector'}}
    if($g.Error -like 'NATIVE_EXCEPTION:*'){
        if(-not $Rejected -or $g.Accepted -ne $false -or $null -ne $g.NativeVelocity -or $null -ne $g.NativeVelocityFinite -or $null -ne $g.VelocityError -or $null -ne $g.VelocityCheckedWall -or $g.VelocityMatches){throw 'Native exception fabricated a velocity observation'};return
    }
    $checked=Get-TraversalNumber $g.VelocityCheckedWall 'actual post-sink velocity check'
    if($checked -lt $g.StartedWall -or $checked -gt $g.CheckedWall -or $g.NativeVelocityFinite -isnot [bool] -or @($g.NativeVelocity).Count -ne 3){throw 'Post-sink native velocity has no actual bound read'}
    $finite=$true
    foreach($v in @($g.NativeVelocity)){
        try{$null=Get-TraversalNumber $v 'native post-sink velocity'}catch{
            if([string]$v -cnotin @('NaN','Infinity','-Infinity')){throw 'Invalid native velocity diagnostic representation'};$finite=$false
        }
    }
    if($g.NativeVelocityFinite -ne $finite){throw 'Native velocity finite flag concealed an invalid component'}
    if(-not $finite){if(-not $Rejected -or $g.Accepted -ne $false -or $null -ne $g.VelocityError -or $g.VelocityMatches){throw 'Nonfinite native velocity was issued or granted a fake error'};return}
    $error=Get-TraversalNumber $g.VelocityError 'post-sink native velocity error'
    $delta=@(for($j=0;$j -lt 3;$j++){[single]([single]$g.NativeVelocity[$j]-[single]$g.ExpectedVelocity[$j])})
    $squares=@($delta|ForEach-Object {[single]($_*$_)});$sum=[single]([single]($squares[0]+$squares[1])+$squares[2]);$derived=[single][Math]::Sqrt($sum)
    Assert-TraversalNear $error $derived 'actual post-sink velocity error' 0.000001
    $matches=$derived -le [single]0.001
    if($g.VelocityMatches -ne $matches -or ($g.Accepted -and -not $matches) -or (-not $Rejected -and -not $matches)){throw 'Post-sink changed native velocity nevertheless reached writer'}
}
function Assert-TraversalNavigation($f,[switch]$Decision){
    $n=$f.Navigation
    if($n.OnNavMesh -isnot [bool] -or $n.PendingTiles -isnot [bool] -or $n.RouteStatus -cne 'PathComplete'){
        throw 'Invalidated map or incomplete native route'
    }
    foreach($name in @('PlannedTileChangeVersion','PlannedTileDataVersion','TileChangeVersion','TileDataVersion')){
        $v=Get-TraversalNumber $n.$name 'native tile version';if($v -lt 0 -or $v -ne [Math]::Floor($v)){throw 'Invalid native map version'}
    }
    if([string]::IsNullOrWhiteSpace([string]$n.PlannedMesh) -or [string]::IsNullOrWhiteSpace([string]$n.Mesh)){throw 'Missing actual native navmesh identity'}
    $fresh=$f.Event -ceq 'MOVE_DECISION' -and ($n.AdmissionPolicy -ceq 'NATIVE_CURRENT_ROUTE_V1' -or $f.Profile.NativeAdmissionPolicy -ceq 'NATIVE_CURRENT_ROUTE_V1')
    $admitted=Get-TraversalAdmissionEpoch $f
    if($Decision -and (-not $n.OnNavMesh -or ($n.PendingTiles -and -not $fresh) -or $n.PlannedMesh -cne $n.Mesh -or
        $admitted[0] -ne $n.TileChangeVersion -or $admitted[1] -ne $n.TileDataVersion)){throw 'Native route epoch is stale before actuation'}
    Assert-TraversalVector $n.RouteFrom;Assert-TraversalVector $n.RouteTo
    $corners=@($n.Corners);if($corners.Count -lt 2 -or $corners.Count -gt 4096){throw 'Missing/unbounded actual native path corners'}
    foreach($c in $corners){Assert-TraversalVector $c}
    if((Get-WorldDistance $corners[0] $n.RouteFrom) -gt 0.5 -or (Get-WorldDistance $corners[-1] $n.RouteTo) -gt 0.5){throw 'Native path corners are not bound to planned actual start/destination'}
    if($Decision -and $fresh){Assert-TraversalNativeAdmission $f}
}
function Assert-TraversalNativeAdmission($f){
    $n=$f.Navigation;$a=$n.Admission
    Assert-TraversalNativeRoutePlan $n
    if($n.AdmissionPolicy -cne 'NATIVE_CURRENT_ROUTE_V1' -or $a.Kind -cne 'NATIVE_CURRENT_ROUTE_V1' -or
        $n.DefaultBuilt -isnot [bool] -or -not $n.DefaultBuilt -or $a.NativeCalculated -isnot [bool] -or $a.ActorCalculated -isnot [bool] -or $a.NativeCalculated -ne $true -or $a.ActorCalculated -ne $true -or
        $a.NativeStatus -cne 'PathComplete' -or $a.ActorStatus -cne 'PathComplete' -or [string]$a.Mesh -cne [string]$n.Mesh){throw 'Missing actual native current-route admission'}
    foreach($key in @('GlobalPendingBefore','GlobalPendingAfter','FilterBefore','FilterAfter')){if($a.$key -isnot [bool]){throw 'Missing native queue/filter observations'}}
    if($a.FilterBefore -ne $a.FilterAfter -or $a.FilterBefore -ne $n.RouteFilter){throw 'Native route filter changed during check'}
    foreach($key in @('ChangeBefore','ChangeAfter')){Assert-TraversalNear $a.$key $n.TileChangeVersion 'native certificate change epoch' 0}
    foreach($key in @('DataBefore','DataAfter')){Assert-TraversalNear $a.$key $n.TileDataVersion 'native certificate data epoch' 0}
    $sequence=Get-TraversalNumber $a.Sequence 'native route check sequence'
    if($f.Schema -ne 2 -or $sequence -lt 1 -or $sequence -ne [Math]::Floor($sequence) -or $sequence -ne $f.Clock.Sequence){throw 'Native route admission belongs to another callback'}
    $start=Get-TraversalNumber $a.StartedWall 'native query start';$end=Get-TraversalNumber $a.CompletedWall 'native query completion';$checked=Get-TraversalNumber $a.CheckedWall 'native query final check'
    if($start -lt $f.Clock.WallTime -or $end -lt $start -or $checked -lt $end -or $checked-$f.Clock.WallTime -gt $f.Profile.MaxTick){throw 'Stale native current-route query'}
    Assert-TraversalSamePoint $a.From $f.Actual 'native query exact actual pose';Assert-TraversalSamePoint $a.To $n.RouteTo 'native query actual destination'
    Assert-TraversalSamePoint $a.Requested $f.Requested 'native query issued segment'
    Assert-TraversalNear $a.Capacity 256 'installed native path capacity' 0
    $polys=@($a.NativePolys);$actorPolys=@($a.ActorPolys);$old=@($a.RoutePolys);$routePolys=@($n.RoutePolys)
    if($polys.Count -lt 1 -or $polys.Count -ge 256 -or $actorPolys.Count -ne $polys.Count -or $old.Count -lt 1 -or $old.Count -ge 256 -or $routePolys.Count -ne $old.Count){throw 'Empty/saturated or unbound native path refs'}
    for($i=0;$i -lt $polys.Count;$i++){
        Assert-AvatarUid $polys[$i].Ref
        $null=[uint64]$polys[$i].Ref
        if($polys[$i].Valid -isnot [bool] -or -not $polys[$i].Valid -or [string]$polys[$i].Ref -cne [string]$actorPolys[$i]){throw 'Invalid native poly or actor/default provenance mismatch'}
    }
    for($i=0;$i -lt $old.Count;$i++){
        Assert-AvatarUid $old[$i].Ref
        $null=[uint64]$old[$i].Ref
        if($old[$i].Valid -isnot [bool] -or -not $old[$i].Valid -or [string]$old[$i].Ref -cne [string]$routePolys[$i]){throw 'Original committed route poly no longer valid'}
    }
    $corners=@($a.NativeCorners);$actorCorners=@($a.ActorCorners)
    if($corners.Count -lt 2 -or $corners.Count -ge 256 -or $corners.Count -ne $actorCorners.Count){throw 'Missing/saturated native current-route corners'}
    for($i=0;$i -lt $corners.Count;$i++){Assert-TraversalSamePoint $corners[$i] $actorCorners[$i] 'default/actor native corner'}
    if((Get-WorldDistance $corners[0] $a.From) -gt 0.5 -or (Get-WorldDistance $corners[-1] $a.To) -gt 0.5){throw 'Fresh native endpoints are not bound to actual query'}
    $delta=Get-HomeRelative $a.Requested $a.From;$delta[1]=0
    $leg=Get-HomeRelative $corners[1] $a.From;$leg[1]=0
    $distance=Get-WorldDistance $delta @(0,0,0);$legLength=Get-WorldDistance $leg @(0,0,0)
    if($distance -gt 0.001){
        if($legLength -le 0.001){throw 'Issued movement has no fresh native first leg'}
        $along=(Get-TraversalDot $delta $leg)/$legLength
        $lateral=@(for($j=0;$j -lt 3;$j++){$delta[$j]-$leg[$j]*$along/$legLength})
        if($along -lt -0.001 -or $along -gt $legLength+0.001 -or (Get-WorldDistance $lateral @(0,0,0)) -gt 0.001){throw 'Issued segment deviates from fresh native first leg'}
    }
}
function Assert-TraversalNativeRoutePlan($n){
    $legs=@($n.RoutePlan)
    if($legs.Count -lt 1 -or $legs.Count -gt 2 -or $n.RouteFilter -isnot [bool]){throw 'Missing bounded exact-mesh native plan provenance'}
    $joinedCorners=@();$joinedPolys=@();$previous=$null
    foreach($p in $legs){
        if($p.Kind -cne 'DEFAULT_NATIVE_PATH_V1' -or [string]$p.Mesh -cne [string]$n.PlannedMesh -or $p.Filter -isnot [bool] -or $p.Filter -ne $n.RouteFilter -or
            $p.NativeCalculated -isnot [bool] -or -not $p.NativeCalculated -or $p.ActorCalculated -isnot [bool] -or -not $p.ActorCalculated -or
            $p.NativeStatus -cne 'PathComplete' -or $p.ActorStatus -cne 'PathComplete'){throw 'Unverified native route leg'}
        Assert-TraversalNear $p.Capacity 256 'native plan path capacity' 0
        foreach($key in @('ChangeBefore','ChangeAfter')){Assert-TraversalNear $p.$key $n.PlannedTileChangeVersion 'native plan change epoch' 0}
        foreach($key in @('DataBefore','DataAfter')){Assert-TraversalNear $p.$key $n.PlannedTileDataVersion 'native plan data epoch' 0}
        $refs=@($p.NativePolys);$actor=@($p.ActorPolys);$corners=@($p.NativeCorners);$actorCorners=@($p.ActorCorners)
        if($refs.Count -lt 1 -or $refs.Count -ge 256 -or $actor.Count -ne $refs.Count -or $corners.Count -lt 2 -or $corners.Count -ge 256 -or $actorCorners.Count -ne $corners.Count){throw 'Empty/saturated native plan leg'}
        for($i=0;$i -lt $refs.Count;$i++){Assert-AvatarUid $refs[$i];$null=[uint64]$refs[$i];if([string]$refs[$i] -cne [string]$actor[$i]){throw 'Native plan actor/default poly mismatch'}}
        for($i=0;$i -lt $corners.Count;$i++){Assert-TraversalSamePoint $corners[$i] $actorCorners[$i] 'native plan actor/default corner'}
        Assert-TraversalVector $p.From;Assert-TraversalVector $p.To
        if((Get-WorldDistance $corners[0] $p.From) -gt 0.5 -or (Get-WorldDistance $corners[-1] $p.To) -gt 0.5){throw 'Native plan leg has another query endpoint'}
        if($null -ne $previous){
            Assert-TraversalSamePoint $previous.To $p.From 'native plan query join'
            Assert-TraversalSamePoint $joinedCorners[-1] $corners[0] 'native plan corner join'
            if([string]$joinedPolys[-1] -cne [string]$refs[0]){throw 'Native composite polygon join is not established'}
            $joinedCorners+=@($corners|Select-Object -Skip 1)
        }else{$joinedCorners=$corners}
        $joinedPolys+=$refs;$previous=$p
    }
    if($joinedPolys.Count -ge 256 -or $joinedCorners.Count -ge 256 -or $joinedPolys.Count -ne @($n.RoutePolys).Count -or $joinedCorners.Count -ne @($n.Corners).Count){throw 'Composite route arrays do not match native leg provenance'}
    for($i=0;$i -lt $joinedPolys.Count;$i++){if([string]$joinedPolys[$i] -cne [string]$n.RoutePolys[$i]){throw 'Route carries polygon refs from another plan'}}
    for($i=0;$i -lt $joinedCorners.Count;$i++){Assert-TraversalSamePoint $joinedCorners[$i] $n.Corners[$i] 'merged native route corner'}
    Assert-TraversalSamePoint $legs[0].From $n.RouteFrom 'native plan original start';Assert-TraversalSamePoint $legs[-1].To $n.RouteTo 'native plan final destination'
}
function Assert-TraversalFinalIssue($f,$intent,[int]$priorIssued,[switch]$Rejected,$ExpectedVelocity=$null){
    $g=$f.FinalAdmission;$a=$intent.Navigation.Admission
    Assert-TraversalFinalVelocity $g $intent $ExpectedVelocity -Rejected:$Rejected
    if($null -eq $intent -or $g.Kind -cne 'POST_SINK_NATIVE_GUARD_V1' -or $g.Accepted -isnot [bool] -or
        $f.Command -ne $intent.Command -or $f.Stage -cne $intent.Stage -or [string]$f.Actor -cne [string]$intent.Actor -or [string]$f.World -cne [string]$intent.World){throw 'Unbound post-sink native issue/rejection receipt'}
    Assert-TraversalSamePoint $f.From $intent.From 'issue/rejection original intent';Assert-TraversalSamePoint $f.Actual $intent.Actual 'issue/rejection actual pose'
    Assert-TraversalSamePoint $f.Requested $intent.Requested 'issue/rejection request'
    Assert-TraversalSamePoint $g.From $intent.Actual 'post-sink measured body pose';Assert-TraversalSamePoint $g.Requested $intent.Requested 'post-sink requested pose'
    Assert-TraversalNear $g.Sequence $intent.Clock.Sequence 'post-sink native callback' 0
    $start=Get-TraversalNumber $g.StartedWall 'post-sink guard start';$end=Get-TraversalNumber $g.CheckedWall 'post-sink guard finish'
    $published=Get-TraversalNumber $intent.DecisionPublishedWall 'intent sink publication time'
    if($published -lt $a.CompletedWall -or $start -lt $published -or $end -lt $start){throw 'Native final guard precedes its decision sink'}
    if($f.WriterCalled -isnot [bool]){throw 'Missing actual native writer call outcome'}
    if($Rejected){
        if($f.Event -cne 'MOVE_REJECTED' -or $f.NativeResult -cne 'NOT_ISSUED' -or $f.WriterCalled -or $g.Accepted -or $f.Actuations -ne $priorIssued){throw 'Rejected intent issued or credited a native command'}
        return
    }
    if($f.Event -cne 'MOVE_ISSUED' -or $f.NativeResult -cne 'ISSUED' -or -not $f.WriterCalled -or -not $g.Accepted -or
        -not [string]::IsNullOrEmpty([string]$g.Error) -or $f.Actuations -ne $priorIssued+1 -or $end-$intent.Clock.WallTime -gt $intent.Profile.MaxTick){throw 'Native writer lacks a fresh successful post-sink guard'}
    foreach($key in @('DefaultBuilt','OnNavMesh','ProfileMatches','BodyValid','ClockAccepted','ControlActive')){if($g.$key -isnot [bool] -or -not $g.$key){throw ('Unsafe final native issue state: '+$key)}}
    foreach($key in @('FilterBefore','FilterAfter','GlobalPendingBefore','GlobalPendingAfter')){if($g.$key -isnot [bool]){throw 'Missing final native filter/queue telemetry'}}
    if($g.FilterBefore -ne $a.FilterBefore -or $g.FilterAfter -ne $a.FilterAfter -or [string]$g.MeshBefore -cne [string]$a.Mesh -or [string]$g.MeshAfter -cne [string]$a.Mesh){throw 'Native mesh/filter changed after decision sink'}
    foreach($key in @('ChangeBefore','ChangeAfter')){Assert-TraversalNear $g.$key $a.ChangeAfter 'post-sink change epoch' 0}
    foreach($key in @('DataBefore','DataAfter')){Assert-TraversalNear $g.$key $a.DataAfter 'post-sink data epoch' 0}
    foreach($key in @('RoutePolys','NativePolys')){
        $rows=@($g.$key);$before=@($a.$key)
        if($rows.Count -ne $before.Count){throw 'Final native poly set changed'}
        for($i=0;$i -lt $rows.Count;$i++){if([string]$rows[$i].Ref -cne [string]$before[$i].Ref -or $rows[$i].Valid -isnot [bool] -or -not $rows[$i].Valid){throw 'Final native polygon became invalid'}}
    }
}
function Test-TraversalDestinationNativeReadiness($o){
    $s=$o.NativeReadiness
    if($null -eq $s){throw 'New-goal eligibility lacks actual native readiness observation'}
    foreach($key in @('NavAvailable','DefaultMesh','DefaultBuilt','OnNavmesh','Ready')){if($s.$key -isnot [bool]){throw ('Missing typed native goal readiness '+$key)}}
    if(($s.NavAvailable -and $s.PendingTiles -isnot [bool]) -or (-not $s.NavAvailable -and $null -ne $s.PendingTiles)){throw 'Missing/forged native pending-tiles observation'}
    $started=Get-TraversalNumber $s.StartedWall 'native goal observation start';$completed=Get-TraversalNumber $s.CompletedWall 'native goal observation end'
    $clockWall=Get-TraversalNumber $o.Clock.WallTime 'native goal callback wall';$observed=Get-TraversalNumber $o.ObservedWall 'native goal observed wall'
    if($started -lt $clockWall -or $completed -lt $started -or $completed -gt $observed){throw 'Native goal eligibility is not bound to its real fixed callback'}
    $reason=if(-not $s.NavAvailable){'NATIVE_NAV_UNAVAILABLE'}elseif(-not $s.DefaultMesh){'NATIVE_DEFAULT_MESH_UNAVAILABLE'}elseif(-not $s.DefaultBuilt){'NATIVE_DEFAULT_NOT_BUILT'}elseif($s.PendingTiles -ne $false){'NATIVE_TILES_PENDING'}elseif(-not $s.OnNavmesh){'NATIVE_ACTOR_NOT_ON_NAVMESH'}else{$null}
    if($s.Ready -ne ($null -eq $reason) -or [string]$s.Reason -cne [string]$reason){throw 'Native new-goal readiness flags/reason conceal an ineligible mesh'}
    if(-not $s.Ready -and $reason -cnotin @($o.Reasons)){throw 'Ineligible native observation lost its WAIT reason'}
    [bool]$s.Ready
}
function Assert-TraversalStationaryWindow($t,$actor){
    $contract=$t.WarmupContract;$observations=@($t.WarmupObservations);$receipt=$t.Warmup
    $needsProof=$t.Completed -eq $true -or $t.Actuations -gt 0 -or @($t.Scenes|Where-Object Status -eq 'PASSED').Count -gt 0
    if($null -eq $contract -and -not $observations.Count){if($needsProof){throw 'Movement began without native stationary-clock readiness'};return}
    if($t.WarmupPolicy -cne 'STATIONARY_CLOCK_WINDOW_V1' -or $null -eq $contract -or -not $observations.Count -or $observations.Count -gt 512){throw 'Missing/bounded native stationary observations'}
    if($t.WarmupObservationCount -ne $observations.Count){throw 'Incomplete native readiness observation journal'}
    Assert-TraversalNear $contract.MaxSeconds 20 'original warmup deadline' 0;Assert-TraversalNear $contract.MinWindowSeconds 2 'native readiness span' 0;Assert-TraversalNear $contract.MaxSamples 512 'warmup observation budget' 0
    $start=Get-TraversalNumber $contract.Start 'warmup original start';Assert-TraversalVector $contract.Position
    $maximum=Get-TraversalNumber $contract.NativeMaximumDelta 'captured immutable native simulation profile'
    if($start -lt 0 -or $maximum -le 0){throw 'Invalid captured warmup clock profile'}
    $body=$contract.Body;$caps=@($body.Capsules)
    foreach($key in @('Kinematic','Gravity','DetectCollisions','AgentStopped','AgentUpdatePosition','AgentUpdateRotation')){if($body.$key -isnot [bool]){throw 'Missing typed warmup body flags'}}
    if([string]$body.Actor -cne [string]$actor -or $caps.Count -ne 1 -or @($body.Colliders).Count -ne 1 -or $body.Colliders[0] -ne $caps[0].Instance -or
        $caps[0].Rigidbody -ne $body.Rigidbody -or $caps[0].Enabled -ne $true -or $caps[0].Trigger -ne $false -or $caps[0].Direction -ne 1 -or
        $body.DetectCollisions -ne $true -or $body.AgentStopped -ne $true -or $body.AgentUpdatePosition -ne $false -or $body.AgentUpdateRotation -ne $false){throw 'Warmup original body/writer configuration unproven'}
    Assert-TraversalNear $caps[0].Radius 0.5 'warmup full radius';Assert-TraversalNear $caps[0].Height 1.8 'warmup full height'
    Assert-TraversalSamePoint $caps[0].Center @(0,0.9,0) 'warmup original capsule center';Assert-TraversalSamePoint $caps[0].Scale @(1,1,1) 'warmup original scale'
    Assert-TraversalSamePoint $caps[0].Up @(0,1,0) 'warmup original upright body'
    $bodyKey=$body|ConvertTo-Json -Depth 15 -Compress;$previous=$null;$first=$null;$samples=0;$restarts=0;$ready=$false;$lastObserved=$start
    for($i=0;$i -lt $observations.Count;$i++){
        $o=$observations[$i];$clock=$o.Clock;$fatal=$false
        if($o.Observation -ne $i+1){throw 'Readiness observation ordinal missing/replayed'}
        try{
            $observed=Get-TraversalNumber $o.ObservedWall 'warmup independent observation wall';Assert-TraversalVector $o.Position;Assert-TraversalVector $o.Velocity
            if($observed -lt $start -or $observed -lt $lastObserved -or $observed-$start -gt 20 -or $i -ge 511 -or
                (Get-WorldDistance $o.Position $contract.Position) -gt 0.001 -or (Get-WorldDistance $o.Velocity @(0,0,0)) -ne 0 -or
                ($o.Body|ConvertTo-Json -Depth 15 -Compress) -cne $bodyKey -or $o.MotorActuations -ne 0 -or
                $o.MotorActive -isnot [bool] -or $o.MotorActive -or $o.MotorBlocked -isnot [bool] -or $o.MotorBlocked){$fatal=$true}
            $lastObserved=$observed
        }catch{$fatal=$true}
        if($fatal){
            if($o.Outcome -cne 'FATAL' -or $i -ne $observations.Count-1 -or $null -ne $receipt -or $needsProof){throw 'Warmup ignored a body/motor/deadline violation'}
            return
        }
        $valid=$true
        try{
            foreach($key in @('WallTime','FixedTime','FixedUnscaledTime','Delta','UnscaledDelta','MaximumDelta','TimeScale','Sequence','Frame')){$null=Get-TraversalNumber $clock.$key ('warmup '+$key)}
            $live=Get-TraversalNumber $o.LiveMaximumDelta 'live native maximum'
            if($clock.WallTime -lt $start -or $clock.WallTime -gt $observed -or $observed-$clock.WallTime -gt 0.1 -or $clock.FixedTime -lt 0 -or $clock.FixedUnscaledTime -lt 0 -or
                $clock.Sequence -le 0 -or $clock.Sequence -ne [Math]::Floor($clock.Sequence) -or $clock.Frame -lt 0 -or $clock.Frame -ne [Math]::Floor($clock.Frame) -or
                $clock.InFixedStep -isnot [bool] -or -not $clock.InFixedStep -or $clock.PhysicsMode -cne 'FixedUpdate' -or $clock.TimeScale -ne 1 -or
                $clock.Delta -le 0 -or $clock.Delta -gt 0.1 -or $clock.UnscaledDelta -ne $clock.Delta -or $clock.MaximumDelta -lt $clock.Delta -or
                $clock.MaximumDelta -ne $maximum -or $clock.MaximumDelta -ne $live){$valid=$false}
        }catch{$valid=$false}
        if($valid -and $null -ne $previous){
            $gap=$clock.WallTime-$previous.WallTime
            if($gap -lt 0 -or $gap -gt 1.500001 -or $clock.MaximumDelta -ne $previous.MaximumDelta -or $clock.Sequence -ne $previous.Sequence+1 -or $clock.Frame -lt $previous.Frame -or
                $clock.Delta -ne $previous.Delta -or [Math]::Abs($clock.FixedTime-$previous.FixedTime-$previous.Delta) -gt 0.000001 -or
                [Math]::Abs($clock.FixedUnscaledTime-$previous.FixedUnscaledTime-$previous.UnscaledDelta) -gt 0.000001){$valid=$false}
        }
        if($t.WarmupContract.NativeReadinessPolicy -ceq 'NATIVE_NEW_GOAL_READINESS_V1' -and -not (Test-TraversalDestinationNativeReadiness $o)){$valid=$false}
        if(-not $valid){
            if($o.Outcome -cne 'WAIT'){throw 'Invalid native clocksample accepted into readiness window'}
            if($null -ne $previous){$restarts++};$previous=$null;$first=$null;$samples=0;continue
        }
        $outcome=if($null -eq $previous){'WINDOW_START'}else{'WINDOW_ADVANCE'}
        if($null -eq $first){$first=$clock};$previous=$clock;$samples++
        if($clock.WallTime-$first.WallTime -ge 2 -and $clock.FixedTime-$first.FixedTime -ge 2 -and $clock.FixedUnscaledTime-$first.FixedUnscaledTime -ge 2){$outcome='READY';$ready=$true}
        if($o.Outcome -cne $outcome -or ($ready -and $i -ne $observations.Count-1)){throw 'Stationary readiness was declared before a complete native window'}
    }
    if(-not $ready){if($null -ne $receipt -or $needsProof){throw 'Stationary clock readiness is incomplete'};return}
    if($null -eq $receipt -or $receipt.Schema -ne 2 -or $receipt.Mode -cne 'STATIONARY_READ_ONLY' -or $receipt.Samples -ne $samples -or $receipt.TotalObservations -ne $observations.Count -or
        $receipt.Resets -ne 0 -or $receipt.MotorResets -ne 0 -or $receipt.WindowRestarts -ne $restarts){throw 'Warmup receipt conceals controller resets or clock window restarts'}
    Assert-TraversalNear $receipt.Start $start 'immutable total warmup start' 0.000001
    Assert-TraversalNear $receipt.StableSince $first.WallTime 'actual native stable-window anchor' 0.000001
    Assert-TraversalNear $receipt.End $previous.WallTime 'actual native ready time' 0.000001
    Assert-TraversalSamePoint $receipt.Position $contract.Position 'warmup never changes original pose'
    foreach($key in @('WallTime','FixedTime','FixedUnscaledTime','Delta','UnscaledDelta','TimeScale','MaximumDelta','Sequence','Frame')){Assert-TraversalNear $receipt.LastClock.$key $previous.$key ('last actual warmup clock '+$key) 0.000001}
    if($receipt.LastClock.InFixedStep -isnot [bool] -or $receipt.LastClock.InFixedStep -ne $previous.InFixedStep -or $receipt.LastClock.PhysicsMode -cne $previous.PhysicsMode){throw 'Ready receipt substituted final native clock flags'}
    $firstBaseline=$null
    foreach($f in @($t.Frames)){
        if($null -eq $f.Profile){continue}
        Assert-TraversalNear $f.Profile.NativeMaximumDelta $maximum 'warmup/controller native profile binding' 0.000001
        if([string]$f.Actor -cne [string]$actor -or $f.Body.Instance -ne $caps[0].Instance -or $f.Body.RigidbodyInstance -ne $body.Rigidbody){throw 'Warmup actor/body differs from physical controller'}
        if([single](Get-TraversalNumber $f.Time 'post-readiness frame time') -lt [single]$receipt.End){throw 'Physical frame predates stationary readiness'}
        if($f.Event -in @('CLOCK_BASELINE','MOVE_DECISION','MOVE_ISSUED','MOTION_WITNESS') -and ($f.Schema -ne 2 -or $null -eq $f.Clock)){throw 'Post-readiness physical event lacks native clocks'}
        if($null -ne $f.Clock){
            Assert-TraversalNear $f.Clock.MaximumDelta $maximum 'post-readiness native maximum binding' 0.000001
            if($f.Clock.Sequence -le $previous.Sequence -or $f.Clock.Frame -lt $previous.Frame -or $f.Clock.WallTime -lt $previous.WallTime -or $f.Clock.FixedTime -le $previous.FixedTime -or $f.Clock.FixedUnscaledTime -le $previous.FixedUnscaledTime){throw 'Physical native callback does not follow the accepted readiness anchor'}
            if($f.Event -ceq 'CLOCK_BASELINE' -and $null -eq $firstBaseline){
                Assert-TraversalSamePoint $f.Actual $contract.Position 'first motor baseline remains at original stationary pose';$firstBaseline=$f
            }
        }
    }
    if($needsProof -and $null -eq $firstBaseline){throw 'Movement has no original-pose native baseline after readiness'}
}
function Assert-TraversalBlockedContact($f,[string]$kind,$actor){
    foreach($name in @('From','Requested','Actual')){Assert-TraversalVector $f.$name}
    Assert-TraversalBody $f $actor;Assert-TraversalProfile $f.Profile;Assert-TraversalSupport $f
    Assert-TraversalSamePoint $f.From $f.Actual 'read-only negative pose'
    if((Get-WorldDistance $f.From $f.Requested) -gt 2.001 -or $f.Mask -ne -1 -or $f.Triggers -cne 'Ignore' -or $f.NativeResult -cne 'PROBE_ONLY'){throw 'Negative scene is not a bounded read-only native probe'}
    $found=$false;$from=$f.From
    foreach($s in @($f.Sweeps)){
        Assert-TraversalSamePoint $s.From $from 'negative sweep chain';Assert-TraversalVector $s.To
        Assert-TraversalSamePoint $s.A @($from[0],($from[1]+0.5),$from[2]) 'negative lower sphere'
        Assert-TraversalSamePoint $s.B @($from[0],($from[1]+1.3),$from[2]) 'negative upper sphere'
        Assert-TraversalNear $s.Radius 0.5 'negative sweep radius';Assert-TraversalNear $s.Distance (Get-WorldDistance $s.From $s.To) 'negative sweep length'
        if($s.Mask -ne -1 -or $s.Triggers -cne 'Ignore'){throw 'Incomplete negative collision filter'}
        foreach($hit in @($s.Hits)){
            Assert-TraversalCollider $hit.Collider;Assert-TraversalVector $hit.Point;Assert-TraversalVector $hit.Normal
            Assert-TraversalNear (Get-TraversalDot $hit.Normal $hit.Normal) 1 'negative normal'
            $distance=Get-TraversalNumber $hit.Distance 'negative hit distance'
            if($distance -lt 0 -or $distance -gt $s.Distance+0.001 -or $hit.InitialIntersects -isnot [bool] -or $hit.Blocking -isnot [bool]){throw 'Invalid negative native hit'}
            if($hit.InitialIntersects){
                if((Get-TraversalNumber $hit.InitialDepth 'negative initial depth') -le 0){throw 'Invalid actual penetration depth'}
                Assert-TraversalVector $hit.InitialDirection;Assert-TraversalNear (Get-TraversalDot $hit.InitialDirection $hit.InitialDirection) 1 'negative penetration direction'
            }
            if($hit.Blocking -and [Math]::Abs($hit.Normal[1]) -lt [Math]::Cos($f.Profile.MaxSlope*[Math]::PI/180)){
                $target=[string]::IsNullOrEmpty([string]$f.TargetEntity) -or [string]$hit.Collider.Entity -ceq [string]$f.TargetEntity
                if($target -and $kind -eq 'DOOR_CLOSED' -and $hit.Collider.DoorOpen -is [bool] -and -not $hit.Collider.DoorOpen){$found=$true}
                if($target -and $kind -eq 'SOLID_WALL' -and $null -eq $hit.Collider.DoorOpen){$found=$true}
            }
        }
        $from=$s.To
    }
    Assert-TraversalSamePoint $from $f.Requested 'negative sweep endpoint'
    if(-not $found){throw ('Negative scene lacks actual native '+$kind+' collision')}
}
function Assert-TraversalClock($clock,$profile){
    if($clock.Schema -ne 2 -or $clock.InFixedStep -isnot [bool] -or -not $clock.InFixedStep -or $clock.PhysicsMode -cne 'FixedUpdate'){throw 'Missing explicit native fixed-step traversal clock'}
    foreach($name in @('WallTime','FixedTime','FixedUnscaledTime','Delta','UnscaledDelta','TimeScale','Sequence','Frame')){$null=Get-TraversalNumber $clock.$name ('clock '+$name)}
    if($clock.WallTime -lt 0 -or $clock.FixedTime -lt 0 -or $clock.FixedUnscaledTime -lt 0 -or
        $clock.Delta -le 0 -or $clock.Delta -gt $profile.MaxTick -or $clock.UnscaledDelta -le 0 -or $clock.UnscaledDelta -gt $profile.MaxTick -or
        $clock.TimeScale -ne 1 -or $clock.Sequence -lt 1 -or $clock.Sequence -ne [Math]::Floor($clock.Sequence) -or $clock.Frame -lt 0 -or $clock.Frame -ne [Math]::Floor($clock.Frame)){throw 'Invalid native fixed-step clock or changed time scale'}
    Assert-TraversalNear $clock.Delta ($clock.UnscaledDelta*$clock.TimeScale) 'fixed/scaled delta relation' 0.000001
}
function Assert-TraversalClockSame($actual,$expected){
    if($null -eq $actual -or $null -eq $expected){throw 'Missing bound native clock snapshot'}
    foreach($name in @('Schema','InFixedStep','PhysicsMode','Sequence','Frame','Delta','UnscaledDelta','TimeScale')){
        if($actual.$name -cne $expected.$name){throw ('Native clock snapshot changed '+$name)}
    }
    foreach($name in @('WallTime','FixedTime','FixedUnscaledTime')){Assert-TraversalNear $actual.$name $expected.$name ('bound clock '+$name) 0.000001}
    if($null -ne $actual.MaximumDelta -or $null -ne $expected.MaximumDelta){Assert-TraversalNear $actual.MaximumDelta $expected.MaximumDelta 'immutable native watchdog' 0.000001}
}
function Assert-TraversalTerminalRefusal($f,$witness,$pending,$stop,$frames,$actor){
    if($null -ne $pending -or $null -eq $witness -or $witness.NativeResult -cne 'OBSERVED' -or $witness.Speed -le 0 -or
        $f.Schema -ne 2 -or $f.Event -cne 'BLOCKED' -or $f.NativeResult -cne 'NOT_ISSUED' -or $f.Classification -cne 'UNKNOWN' -or
        ($f.Reason -notlike 'NATIVE_ROUTE_ADMISSION:*' -and $f.Reason -notlike 'CLOCK_AFTER_PROBE:*') -or
        $f.RecoveryPolicy -cne 'MEASURED_BRAKE_V1' -or $f.MotionSession -lt 1 -or $f.MotionSession -ne $witness.MotionSession -or
        $f.Command -ne $witness.Command+1 -or $f.UnobservedCommand -isnot [bool] -or $f.UnobservedCommand -or
        $null -ne $f.PendingDecision -or $f.WriterCalled -eq $true -or $f.Stage -cne $witness.Stage -or $f.Tick -ne $witness.Tick){throw 'Unbound terminal pre-writer refusal'}
    if($null -eq $stop -or $stop.Event -cne 'BLOCKED' -or $stop.NativeResult -cne 'STOPPED' -or $stop.Command -ne $witness.Command -or
        $stop.UnobservedCommand -eq $true -or $stop.WriterCalled -eq $true -or $null -ne $stop.PendingDecision -or $null -ne $stop.Clock -or
        $stop.MotionSession -ne $witness.MotionSession -or $stop.Stage -cne $witness.Stage){throw 'Terminal refusal lacks its sole no-actuation stop'}
    if(@($frames|Where-Object {$_.Command -eq $f.Command -and $_.Event -in @('MOVE_DECISION','MOVE_ISSUED','MOTION_WITNESS','BRAKE_ISSUED','ARRIVED','REPATH','REPATH_AFTER_REST','ACTUAL_REST')}).Count){throw 'Refused terminal command has motion or success credit'}
    Assert-TraversalBody $f $actor;Assert-TraversalBody $stop $actor;Assert-TraversalProfile $f.Profile
    Assert-TraversalSupport $f;Assert-TraversalContacts $f
    Assert-TraversalClockSame $f.Clock $witness.Clock;Assert-TraversalClockSame $f.PreviousClock $witness.PreviousClock
    foreach($key in @('Actual','Profile')){
        $expected=$witness.$key|ConvertTo-Json -Depth 30 -Compress
        if(($f.$key|ConvertTo-Json -Depth 30 -Compress) -cne $expected -or ($stop.$key|ConvertTo-Json -Depth 30 -Compress) -cne $expected){throw ('Terminal refusal changed witnessed '+$key)}
    }
    if(($f.Body|ConvertTo-Json -Depth 30 -Compress) -cne ($witness.Body|ConvertTo-Json -Depth 30 -Compress)){throw 'Terminal refusal changed witnessed body/native velocity'}
    foreach($key in @($witness.Body.PSObject.Properties.Name|Where-Object {$_ -cne 'Velocity'})){
        if(($stop.Body.$key|ConvertTo-Json -Depth 30 -Compress) -cne ($witness.Body.$key|ConvertTo-Json -Depth 30 -Compress)){throw ('Final unclocked stop changed original body '+$key)}
    }
    Assert-TraversalVector $stop.Body.Velocity # Unclocked native snapshot grants no rest/deceleration credit.
    foreach($key in @('OnNavMesh','PendingTiles','RouteStatus','AdmissionPolicy','DefaultBuilt','RoutePolys','RouteFilter','RoutePlan','RouteFrom','RouteTo','Corners','PlannedTileChangeVersion','PlannedTileDataVersion','TileChangeVersion','TileDataVersion','PlannedMesh','Mesh')){
        $expected=$witness.Navigation.$key|ConvertTo-Json -Depth 30 -Compress
        if(($f.Navigation.$key|ConvertTo-Json -Depth 30 -Compress) -cne $expected -or ($stop.Navigation.$key|ConvertTo-Json -Depth 30 -Compress) -cne $expected){throw ('Terminal refusal changed native route '+$key)}
    }
    if((Get-WorldDistance $f.Body.Velocity @(0,0,0)) -le 0){throw 'Terminal refusal invented native rest'}
}
function Assert-TraversalTerminalResult($nav){
    if(($nav.Status -ceq 'GREEN' -or $nav.Traversal.Completed -eq $true) -and
        @($nav.Traversal.Frames|Where-Object {$_.Event -ceq 'BLOCKED' -and $_.NativeResult -ceq 'NOT_ISSUED' -and $_.WallTelemetry.ReadDelay -gt $_.Profile.MaxTick+0.000001}).Count){throw 'Completed traversal contains terminal no-actuation refusal'}
}
function Assert-TraversalWallTelemetry($f,$previous,[switch]$NoActuationTerminal){
    $limit=Get-TraversalNumber $f.Profile.MaxWallStall 'native maximumDeltaTime watchdog'
    if($limit -lt $f.Clock.Delta -or $limit -gt 120){throw 'Invalid native wall watchdog'}
    $native=if($null -ne $f.Profile.NativeMaximumDelta){Get-TraversalNumber $f.Profile.NativeMaximumDelta 'native simulation catch-up cap'}else{$limit}
    if($native -lt $f.Clock.Delta){throw 'Invalid native maximum physics delta'}
    if($null -ne $f.Profile.NativeMaximumDelta){Assert-TraversalNear $limit 1.5 'existing event-loop watchdog policy' 0.000001}
    Assert-TraversalNear $f.Clock.MaximumDelta $native 'captured native simulation cap' 0.000001
    if($null -ne $previous){Assert-TraversalNear $previous.MaximumDelta $native 'unchanged native simulation cap' 0.000001}
    $w=$f.WallTelemetry
    $gap=Get-TraversalNumber $w.CallbackGap 'wall callback gap';$delay=Get-TraversalNumber $w.ReadDelay 'wall read delay'
    Assert-TraversalNear $w.MaxWallStall $limit 'wall telemetry watchdog' 0.000001
    Assert-TraversalNear $gap $f.WallDt 'wall telemetry interval' 0.000001
    if($null -ne $f.Profile.NativeMaximumDelta){
        Assert-TraversalNear $w.NativeMaximumDelta $native 'wall telemetry native catch-up cap' 0.000001
        if($w.NativeCatchupExceeded -isnot [bool] -or $w.NativeCatchupExceeded -ne ($gap -gt $native+0.000001)){throw 'False native catch-up wall comparison'}
    }
    if($gap -lt 0 -or $gap -gt $limit+0.000001 -or $delay -lt 0 -or $delay -gt $limit+0.000001 -or
        ($delay -gt $f.Profile.MaxTick+0.000001 -and (-not $NoActuationTerminal -or $f.Event -cne 'BLOCKED' -or $f.NativeResult -cne 'NOT_ISSUED'))){throw 'Long wall stall or stale callback execution'}
    $state=if($gap -gt $f.Profile.MaxTick+0.000001){'PHYSICS_CONTIGUOUS_WITH_WALL_LAG'}else{'ON_TIME'}
    if($w.State -cne $state){throw 'False wall/physics classification'}
}
function Assert-TraversalNativeVelocity($body,$expected){
    Assert-TraversalVector $body.Velocity
    $error=Get-WorldDistance $body.Velocity $expected
    if($error -gt 0.001){throw 'Native Rigidbody velocity disagrees with physical fixed-step displacement'}
    return $error
}
function Assert-TraversalProbe($f,$actor){
    if($f.Event -notin @('PROBE_REFUSED','PROBE_CLEAR') -or $f.NativeResult -cne 'PROBE_ONLY'){throw 'Not an executed detached probe'}
    Assert-TraversalBody $f $actor;Assert-TraversalProfile $f.Profile;Assert-TraversalSupport $f
    Assert-TraversalSamePoint $f.From $f.Actual 'detached probe zero actual displacement'
    Assert-TraversalContacts $f
    $a=$f.ControlBefore;$b=$f.ControlAfter
    if($null -eq $a -or $null -eq $b -or ($a|ConvertTo-Json -Depth 30 -Compress) -cne ($b|ConvertTo-Json -Depth 30 -Compress)){throw 'Probe changed motor control state'}
    foreach($key in @('Active','Pending','Acquiring','UnobservedTerminal')){if($a.$key -isnot [bool] -or $a.$key){throw 'Probe was not detached from active motion'}}
    foreach($key in @('Arrived','Blocked')){if($a.$key -isnot [bool]){throw 'Missing probe lifecycle snapshot'}}
    foreach($key in @('Velocity','NativeVelocity')){Assert-TraversalVector $a.$key;if((Get-WorldDistance $a.$key @(0,0,0)) -ne 0){throw 'Probe body was not stationary'}}
    Assert-TraversalSamePoint $a.Position $f.Actual 'probe snapshot actual pose'
    foreach($key in @('Actuations','Retry','Command')){if((Get-TraversalNumber $a.$key $key) -lt 0){throw 'Invalid probe control counters'}}
    if($f.Event -eq 'PROBE_REFUSED' -and $f.Reason -cne 'READ_ONLY_REFUSED'){throw 'Refusal lacks observational reason'}
}
function Get-TraversalFixtureLocal($fixture,$position){
    Assert-TraversalVector $fixture.FoundationPosition;Assert-TraversalVector $fixture.FoundationRotation 4;Assert-TraversalVector $position
    $q=$fixture.FoundationRotation;$norm=0.0;foreach($v in $q){$norm+=$v*$v};Assert-TraversalNear $norm 1 'fixture rotation norm'
    Get-HomeRotated @(-$q[0],-$q[1],-$q[2],$q[3]) (Get-HomeRelative $position $fixture.FoundationPosition)
}
function Assert-TraversalExteriorSegment($fixture,$from,$to){
    Assert-TraversalVector $fixture.NativeFoundationBounds.Center;Assert-TraversalVector $fixture.NativeFoundationBounds.Size
    Assert-TraversalNear $fixture.Radius 0.5 'fixture original radius'
    $skin=Get-TraversalNumber $fixture.Skin 'fixture skin';if($skin -le 0 -or $skin -gt 0.05){throw 'Invalid native fixture skin'}
    $min=@();$max=@()
    for($j=0;$j -lt 3;$j++){
        $size=Get-TraversalNumber $fixture.NativeFoundationBounds.Size[$j] 'native foundation dimension';if($size -le 0){throw 'Missing native footprint dimensions'}
        $margin=if($j -eq 1){0}else{0.5+$skin}
        $min+=($fixture.NativeFoundationBounds.Center[$j]-$size*0.5-$margin);$max+=($fixture.NativeFoundationBounds.Center[$j]+$size*0.5+$margin)
    }
    Assert-TraversalSamePoint $fixture.ExteriorMin $min 'native expanded exterior min';Assert-TraversalSamePoint $fixture.ExteriorMax $max 'native expanded exterior max'
    $a=Get-TraversalFixtureLocal $fixture $from;$b=Get-TraversalFixtureLocal $fixture $to
    if(-not (($a[0] -le $min[0] -and $b[0] -le $min[0]) -or ($a[0] -ge $max[0] -and $b[0] -ge $max[0]) -or
        ($a[2] -le $min[2] -and $b[2] -le $min[2]) -or ($a[2] -ge $max[2] -and $b[2] -ge $max[2]))){throw 'Route segment enters expanded sealed fixture footprint'}
}
function Assert-TraversalDirectProbeAim($probe,$start,$goal){
    Assert-TraversalVector $probe.From;Assert-TraversalVector $probe.Requested;Assert-TraversalVector $start;Assert-TraversalVector $goal
    $a=Get-HomeRelative $probe.Requested $probe.From;$b=Get-HomeRelative $goal $start
    if($a[1] -ne 0){throw 'Direct refusal probe has a vertical displacement absent from native source'}
    # The native read-only probe projects its aim horizontally. Route geometry
    # and actual movement retain their independent full3D validation.
    $b[1]=0
    $al=Get-WorldDistance $a @(0,0,0);$bl=Get-WorldDistance $b @(0,0,0)
    if($al -le 0 -or $bl -le 0 -or (Get-TraversalDot $a $b)/($al*$bl) -lt 0.99999){throw 'Direct refusal is not aimed along actual horizontal detour goal line'}
}
function Assert-TraversalExteriorDetour($nav,$s,$w,$prior){
    $f=$nav.Traversal.Fixture;$p=$nav.Traversal.Detour
    if($f.Source -cne 'OWNED_NATIVE_TEST_FIXTURE' -or $p.Source -cne $f.Source -or $p.Status -cne 'PathComplete' -or
        [string]$p.Wall -cne [string]$f.Wall -or [string]$p.Door -cne [string]$f.Door){throw 'Detour lacks owned native fixture plan binding'}
    $entities=if($nav.Traversal.FixturePolicy -ceq 'MINIMAL_G4_BEFORE_TC_V1'){@($nav.FirstHome.PartialEntities)}else{@($nav.FirstHome.Home.Entities)}
    $foundation=@($entities|Where-Object Role -eq 'FOUNDATION');$door=@($entities|Where-Object Role -eq 'DOOR')
    if($foundation.Count -ne 1 -or $door.Count -ne 1 -or [string]$foundation[0].NetId -cne [string]$f.Foundation -or
        [string]$door[0].NetId -cne [string]$f.Door -or -not @($entities|Where-Object { $_.Role -like 'WALL_*' -and [string]$_.NetId -ceq [string]$f.Wall }).Count){throw 'Detour fixture entities do not exist in native paid structure'}
    Assert-TraversalSamePoint $f.FoundationPosition $foundation[0].Position 'fixture foundation position'
    Assert-TraversalVector $foundation[0].Rotation 4
    for($j=0;$j -lt 4;$j++){Assert-TraversalNear $f.FoundationRotation[$j] $foundation[0].Rotation[$j] 'fixture foundation rotation'}
    Assert-TraversalSamePoint $p.Start $s.Start 'detour plan actual start'
    $direct=Get-WorldDistance $p.Start $p.Goal;Assert-TraversalNear $p.DirectLength $direct 'detour measured direct distance'
    $corners=@($p.Corners);if($corners.Count -lt 3 -or $corners.Count -gt 4096){throw 'Detour has no actual alternate corners'}
    if((Get-WorldDistance $corners[0] $p.Start) -gt 0.5){throw 'Detour path has another actual origin'}
    if((Get-WorldDistance $corners[-1] $p.Goal) -gt 0.5){throw 'Detour path has another destination'}
    $length=0.0;for($i=1;$i -lt $corners.Count;$i++){$length+=Get-WorldDistance $corners[$i-1] $corners[$i];Assert-TraversalExteriorSegment $f $corners[$i-1] $corners[$i]}
    Assert-TraversalNear $p.Length $length 'native alternate path length' 0.01
    if($length -gt 24 -or $length -le $direct+0.1){throw 'Detour is not a bounded longer alternate route'}
    $legs=@($p.Legs);if($legs.Count -lt 1 -or $legs.Count -gt 2){throw 'Missing bounded native detour legs'}
    $joined=@();$sum=0.0
    foreach($leg in $legs){
        $lc=@($leg.Corners);if($leg.Status -cne 'PathComplete' -or $lc.Count -lt 2){throw 'Incomplete native detour leg'}
        $ll=0.0;for($i=1;$i -lt $lc.Count;$i++){$ll+=Get-WorldDistance $lc[$i-1] $lc[$i];Assert-TraversalExteriorSegment $f $lc[$i-1] $lc[$i]}
        Assert-TraversalNear $leg.Length $ll 'native leg length' 0.01;$sum+=$ll
        if($joined.Count){Assert-TraversalSamePoint $joined[-1] $lc[0] 'native preview leg join';$joined+=@($lc|Select-Object -Skip 1)}else{$joined=$lc}
    }
    Assert-TraversalNear $sum $p.Length 'native summed leg length' 0.01
    if($joined.Count -ne $corners.Count){throw 'Composite detour substituted corners'}
    for($i=0;$i -lt $joined.Count;$i++){Assert-TraversalSamePoint $joined[$i] $corners[$i] 'native composite corner'}
    $contact=@($prior|Where-Object {$_.Event -eq 'PROBE_REFUSED' -and $_.Stage -ceq 'FIXTURE_DIRECT_REFUSAL' -and [string]$_.TargetEntity -ceq [string]$f.Wall}|Select-Object -Last 1)
    if($contact.Count -ne 1){throw 'Detour lacks target-wall direct refusal'}
    Assert-TraversalBlockedContact $contact[0] 'SOLID_WALL' $nav.Actor.NetId
    Assert-TraversalSamePoint $contact[0].From $p.Start 'direct refusal at same actual detour start'
    Assert-TraversalDirectProbeAim $contact[0] $p.Start $p.Goal
    $travel=0.0;$groups=@();$current=@();$routeTo=$null
    foreach($row in $w){
        $d=$row.FixtureDetourWitness
        if($d.Open -isnot [bool] -or $d.Open -or $d.Outside -ne $true -or [string]$d.Door -cne [string]$f.Door -or [string]$d.Foundation -cne [string]$f.Foundation -or
            ($d.Plan|ConvertTo-Json -Depth 12 -Compress) -cne ($p|ConvertTo-Json -Depth 12 -Compress)){throw 'Detour native closed Door/fixture witness changed'}
        Assert-TraversalSamePoint $d.DoorPosition $door[0].Position 'detour native door pose'
        Assert-TraversalSamePoint $d.LocalPosition (Get-TraversalFixtureLocal $f $row.Actual) 'independent exterior local position'
        Assert-TraversalExteriorSegment $f $row.From $row.Actual
        $encoded=$row.Navigation.RouteTo|ConvertTo-Json -Compress
        if($null -ne $routeTo -and $routeTo -cne $encoded){$groups+=,@($current);$current=@()};$routeTo=$encoded;$current+=,$row
        $travel+=Get-WorldDistance $row.From $row.Actual
    }
    if($current.Count){$groups+=,@($current)}
    if($groups.Count -ne $legs.Count){throw 'Observed detour legs differ from native plan'}
    for($i=0;$i -lt $groups.Count;$i++){
        $g=@($groups[$i]);$lc=@($legs[$i].Corners)
        if($g.Count -lt 2 -or $g[-1].Speed -ne 0 -or (Get-WorldDistance $g[-1].Actual $lc[-1]) -gt 0.3 -or
            (Get-WorldDistance $g[0].Navigation.RouteTo $lc[-1]) -gt 0.5 -or (Get-WorldDistance $g[0].From $lc[0]) -gt 0.5){throw 'Detour leg lacks bound physical start/arrival/rest'}
        if($i -gt 0){Assert-TraversalSamePoint $groups[$i-1][-1].Actual $g[0].From 'observed stationary detour leg join'}
    }
    if($travel -le 2 -or $travel -le $direct+0.1 -or $w[-1].Speed -ne 0 -or (Get-WorldDistance $s.End $p.Goal) -gt 0.3){throw 'Detour lacks real supported alternate travel and rest'}
}
function Get-TraversalPhysicsVelocity($to,$from,[double]$dt){
    # Native Vector3 stores coordinates, subtraction and division as Singles.
    # Restore those operands; JSON's short decimal spellings are not exact reals.
    Assert-TraversalVector $to;Assert-TraversalVector $from
    if($dt -le 0){throw 'Nonpositive native physics velocity interval'}
    @(for($j=0;$j -lt 3;$j++){[single]([single]([single]$to[$j]-[single]$from[$j])/[single]$dt)})
}
function Assert-TraversalFrames($frames,$expectedActor,$expectedWorld){
    Assert-AvatarUid $expectedActor
    if([string]::IsNullOrWhiteSpace([string]$expectedWorld)){throw 'Missing traversal world binding'}
    $frames=@($frames);if(-not $frames.Count -or $frames.Count -gt 16384){throw 'Missing/unbounded traversal frames'}
    $finalVelocityPolicy=$frames[0].Profile.FinalVelocityPolicy
    if($null -ne $finalVelocityPolicy -and $finalVelocityPolicy -cne 'NATIVE_POST_SINK_VELOCITY_V1'){throw 'Unknown original source final velocity policy'}
    Assert-TraversalEpochTransitions $frames
    $pending=$null;$pendingIssued=$false;$issuedCount=0;$lastWitness=$null;$baseline=$null;$lastTime=-1.0;$resolved=0;$heightWitnesses=@{};$heightRunKey='';$heightRun=0;$acquisition=$null;$ordinaryIssued=$false
    $activeClock=$null;$previousClock=$null;$clockStartWall=0.0;$clockBaselinePose=$null;$frameIndex=-1
    foreach($f in $frames){
        if($f.Profile.FinalVelocityPolicy -cne $finalVelocityPolicy){throw 'Physical frame downgraded/changed the original source final velocity policy'}
        $frameIndex++
        if($f.Schema -notin @(1,2) -or [string]$f.Actor -cne [string]$expectedActor -or [string]$f.World -cne [string]$expectedWorld -or
            [string]::IsNullOrWhiteSpace([string]$f.Stage)){throw 'Traversal actor/world/schema/stage mismatch'}
        $time=Get-TraversalNumber $f.Time 'time';$tick=Get-TraversalNumber $f.Tick 'tick';$command=Get-TraversalNumber $f.Command 'command'
        if($time -lt $lastTime-0.0001 -or $tick -lt 0 -or $tick -ne [Math]::Floor($tick) -or $command -lt 0 -or $command -ne [Math]::Floor($command)){throw 'Invalid traversal chronology'}
        $lastTime=$time
        if($f.Event -in @('PROBE_REFUSED','PROBE_CLEAR')){Assert-TraversalProbe $f $expectedActor}
        $stationaryTerminalChecked=$false
        if($f.Profile.StationaryReplanPolicy -ceq 'MEASURED_STATIONARY_NATIVE_V1' -and $null -ne $f.StationaryReplan -and $f.StationaryReplan.FirstWriterCommand -eq 0 -and $f.Event -in @('BLOCKED','MOVE_REJECTED')){
            Assert-TraversalStationaryTerminal $f $lastWitness $pending $frames $expectedActor
            $stationaryTerminalChecked=$true
            if($f.Event -ceq 'BLOCKED' -and $null -ne $pending){$pending=$null;$pendingIssued=$false}
        }
        $fixedProtocol=$f.Schema -eq 2
        if($fixedProtocol -and $null -ne $f.Clock){
            Assert-TraversalClock $f.Clock $f.Profile
            if([single]$time -ne [single]$f.Clock.WallTime){throw 'Legacy timestamp is not the native wall-clock alias'}
            if($f.Event -eq 'CLOCK_BASELINE'){
                if($null -ne $pending -or $null -ne $f.PreviousClock -or $f.NativeResult -cne 'CLOCK_BASELINE' -or $f.Classification -cne 'CLEAR' -or
                    ($null -ne $lastWitness -and $lastWitness.Speed -ne 0)){throw 'Fixed clock baseline cannot erase actual motion'}
                Assert-TraversalProfile $f.Profile;Assert-TraversalBody $f $expectedActor;Assert-TraversalSamePoint $f.Actual $f.From 'clock baseline stationary origin';Assert-TraversalSamePoint $f.Actual $f.Requested 'clock baseline no command'
                Assert-TraversalSamePoint $f.PosePrevious $f.Actual 'clock baseline original pose';Assert-TraversalVector $f.ObservedVelocity
                if((Get-WorldDistance $f.ObservedVelocity @(0,0,0)) -ne 0 -or (Assert-TraversalNativeVelocity $f.Body @(0,0,0)) -ne 0){throw 'Fixed clock baseline is not actual native rest'}
                if($null -ne $lastWitness){Assert-TraversalSamePoint $f.Actual $lastWitness.Actual 'clock baseline physical continuity'}
                $clockStartWall=Get-TraversalNumber $f.PosePreviousTime 'clock baseline destination wall time'
                if($clockStartWall -gt $f.Clock.WallTime -or $f.Clock.WallTime-$clockStartWall -gt 120){throw 'Invalid native clock baseline deadline'}
                if($null -ne $f.Profile.MaxWallStall){Assert-TraversalWallTelemetry $f $null}
                $activeClock=$f.Clock;$previousClock=$null;$clockBaselinePose=$f.Actual
                continue
            }
            if($null -eq $activeClock){throw 'Fixed-step proof lacks its native stationary clock baseline'}
            if($f.Clock.Sequence -eq $activeClock.Sequence){Assert-TraversalClockSame $f.Clock $activeClock}
            else{
                if($f.Clock.Sequence -ne $activeClock.Sequence+1 -or $f.Clock.Frame -lt $activeClock.Frame -or
                    $f.Clock.Delta -ne $activeClock.Delta -or $f.Clock.UnscaledDelta -ne $activeClock.UnscaledDelta -or $f.Clock.TimeScale -ne $activeClock.TimeScale){throw 'Skipped or changed native fixed-step callback'}
                Assert-TraversalNear ($f.Clock.FixedTime-$activeClock.FixedTime) $activeClock.Delta 'consecutive native fixed time' 0.000001
                Assert-TraversalNear ($f.Clock.FixedUnscaledTime-$activeClock.FixedUnscaledTime) $activeClock.UnscaledDelta 'consecutive native unscaled fixed time' 0.000001
                $wallGap=$f.Clock.WallTime-$activeClock.WallTime
                $wallLimit=if($null -ne $f.Profile.MaxWallStall){$f.Profile.MaxWallStall}else{$f.Profile.MaxTick}
                if($wallGap -lt 0 -or $wallGap -gt $wallLimit+0.000001){throw 'Native wall clock regressed or exceeded independent safety gap'}
                $previousClock=$activeClock;$activeClock=$f.Clock
            }
            Assert-TraversalClockSame $f.PreviousClock $previousClock
            Assert-TraversalNear $f.WallDt ($f.Clock.WallTime-$previousClock.WallTime) 'independent callback wall interval' 0.000001
            if($f.Clock.WallTime-$clockStartWall -gt 120){throw 'Native wall deadline exceeded'}
            if($null -ne $f.Profile.MaxWallStall -and -not $stationaryTerminalChecked){
                $terminalRefusal=$f.Event -ceq 'BLOCKED' -and $f.WallTelemetry.ReadDelay -gt $f.Profile.MaxTick+0.000001
                $failedRestRoute=$f.Event -ceq 'REPATH' -and $f.RestReplan.Kind -ceq 'OBSTACLE' -and $f.RestReplan.Accepted -is [bool] -and -not $f.RestReplan.Accepted
                $lateRest=$f.Profile.EpochRevalidationPolicy -ceq 'SAME_COMMITTED_ROUTE_EPOCH_V2' -and ($terminalRefusal -or ($failedRestRoute -and $f.WallTelemetry.ReadDelay -gt $f.Profile.MaxTick+0.000001)) -and
                    $null -ne $lastWitness -and $lastWitness.Speed -eq 0 -and $lastWitness.MotionMode -in @('ACTUAL_BRAKE','BRAKE_HOLD')
                if($lateRest){Assert-TraversalLateRestRefusal $f $lastWitness $pending $frames $expectedActor}
                else{
                    if($terminalRefusal){
                        if($frameIndex -ne $frames.Count-2){throw 'Late refusal is not the terminal no-actuation pair'}
                        Assert-TraversalTerminalRefusal $f $lastWitness $pending $frames[$frameIndex+1] $frames $expectedActor
                    }
                    Assert-TraversalWallTelemetry $f $previousClock -NoActuationTerminal:$terminalRefusal
                }
            }
        }elseif($fixedProtocol -and $f.Event -in @('CLOCK_BASELINE','MOVE_DECISION','MOVE_ISSUED','MOVE_REJECTED','MOTION_WITNESS','FLOOR_ACQUISITION_OBSERVE','FLOOR_ACQUIRED','STEP_RESOLVED','ARRIVED','REPATH')){throw 'Physical proof is missing its explicit native fixed clock'}
        $phase=if($null -eq $f.SupportPhase){'NORMAL'}else{[string]$f.SupportPhase}
        if($phase -notin @('NORMAL','FLOOR_ACQUISITION')){throw 'Unknown native support phase'}
        $isAcquisition=$phase -eq 'FLOOR_ACQUISITION'
        if($f.Event -eq 'FLOOR_ACQUISITION_OBSERVE'){
            if(-not $isAcquisition -or $ordinaryIssued -or $null -ne $lastWitness -or $null -ne $pending -or $null -ne $acquisition -or $command -ne 0 -or
                $f.NativeResult -cne 'STATIONARY_OBSERVATION' -or $f.Classification -cne 'CLEAR'){throw 'Floor acquisition is restricted to the initial stationary native pose'}
            Assert-TraversalProfile $f.Profile;Assert-TraversalBody $f $expectedActor;Assert-TraversalNavigation $f -Decision
            Assert-AcquisitionSurface $f.Support $f.Actual $f.Profile;Assert-TraversalContacts $f;Assert-AcquisitionPolicy $f
            Assert-TraversalSamePoint $f.From $f.Actual 'initial floor observation origin';Assert-TraversalSamePoint $f.Requested $f.Actual 'initial floor observation no command'
            Assert-TraversalSamePoint $f.PosePrevious $f.Actual 'initial observed stationary pose';Assert-TraversalVector $f.ObservedVelocity;Assert-TraversalVector $f.Body.Velocity
            $restDt=if($fixedProtocol){Get-TraversalNumber $f.FixedDt 'initial stationary fixed observation interval'}else{$time-(Get-TraversalNumber $f.PosePreviousTime 'initial stationary observation time')}
            if($restDt -le 0 -or $restDt -gt $f.Profile.MaxTick -or (Get-WorldDistance $f.PosePrevious $f.Actual) -ne 0 -or
                (Get-WorldDistance $f.ObservedVelocity @(0,0,0)) -ne 0 -or (Get-WorldDistance $f.Body.Velocity @(0,0,0)) -ne 0 -or
                $f.Support.Gap -le $f.Profile.SupportTolerance){throw 'Acquisition lacks an actual initial stationary interval or needs no capture'}
            $acquisition=@{Start=$f.Actual;Time=$time;Gap=$f.Support.Gap;FloorY=$f.Support.FootY;FloorId=$f.Support.Collider.Instance;Point=$f.Support.Point;Normal=$f.Support.Normal;Collider=$f.Support.Collider;LastGap=$f.Support.Gap;Acquired=$false;RouteRebound=$false;ObservationClock=$f.Clock}
            Assert-AcquisitionBinding $f $acquisition
            $baseline=@($f.Body.Instance,$f.Body.RigidbodyInstance,$f.Body.Kinematic,$f.Body.Gravity,$f.Body.CollisionMode,$f.Body.Layer,$f.Body.DetectCollisions) -join '|'
            continue
        }
        if($f.Event -eq 'FLOOR_ACQUIRED'){
            if(-not $isAcquisition -or $null -eq $acquisition -or $acquisition.Acquired -or $null -ne $pending -or $null -eq $lastWitness -or
                $lastWitness.MotionMode -cne 'ACQUISITION_BRAKE_HOLD' -or $lastWitness.Speed -ne 0 -or $lastWitness.Command -ne $command -or
                [Math]::Abs($lastWitness.Time-$time) -gt 0.0001 -or $f.NativeResult -cne 'OBSERVED' -or $f.MotionMode -cne 'ACQUISITION_BRAKE_HOLD' -or
                $f.Classification -cne 'CLEAR' -or (Get-TraversalNumber $f.Speed 'acquisition rest speed') -ne 0 -or (Get-TraversalNumber $f.Distance 'acquisition rest distance') -ne 0){throw 'Floor acquired flag lacks observed native floor rest'}
            Assert-TraversalSamePoint $f.Actual $lastWitness.Actual 'observed acquired pose';Assert-TraversalBody $f $expectedActor
            Assert-TraversalSupport $f;Assert-TraversalContacts $f;Assert-AcquisitionPolicy $f;Assert-AcquisitionBinding $f $acquisition
            if($f.Support.Gap -gt $f.Profile.Skin+0.001 -or -not $f.SupportAccepted){throw 'Floor acquisition ended before normal supported skin rest'}
            $acquisition.Acquired=$true;continue
        }
        if($f.Event -eq 'REPATH' -and $f.Reason -ceq 'INITIAL_FLOOR_ACQUISITION_ROUTE_BINDING'){
            if($isAcquisition -or $null -eq $acquisition -or -not $acquisition.Acquired -or $acquisition.RouteRebound -or $ordinaryIssued -or
                $f.NativeResult -cne 'ROUTE_REBOUND' -or $null -ne $pending -or $null -eq $lastWitness -or $lastWitness.Speed -ne 0){throw 'Initial floor route binding lacks acquired native rest'}
            Assert-TraversalSamePoint $f.Actual $lastWitness.Actual 'acquired actual route rebound';Assert-TraversalSamePoint $f.Navigation.RouteFrom $f.Actual 'acquired native route actual origin'
            Assert-TraversalNavigation $f -Decision;$acquisition.RouteRebound=$true;continue
        }
        if($f.Event -eq 'STEP_RESOLVED'){
            $key=[string]$f.Stage+'|'+[string]$f.Classification
            if($key -cne $heightRunKey -or $heightRun -lt 2 -or $null -ne $pending -or $null -eq $lastWitness -or
                $lastWitness.Command -ne $command -or [Math]::Abs($lastWitness.Time-$time) -gt 0.001){throw 'Flags-only or predicted STEP_RESOLVED'}
            $resolved++;continue
        }
        if($f.Event -eq 'ARRIVED'){
            if($null -ne $pending -or $null -eq $lastWitness -or $lastWitness.Speed -ne 0 -or $lastWitness.Command -ne $command -or [Math]::Abs($lastWitness.Time-$time) -gt 0.001){throw 'Arrival lacks observed native rest'}
            Assert-TraversalSamePoint $f.Actual $lastWitness.Actual 'actual arrived rest';Assert-TraversalNavigation $f -Decision
            continue
        }
        if($f.Event -in @('MOVE_ISSUED','MOVE_REJECTED')){
            if($null -eq $pending -or $pendingIssued -or $pending.Navigation.AdmissionPolicy -cne 'NATIVE_CURRENT_ROUTE_V1'){throw 'Native issue/rejection has no new-policy intent'}
            Assert-TraversalClockSame $f.Clock $pending.Clock
            $expectedVelocity=if($null -eq $lastWitness){@(0,0,0)}else{Get-TraversalPhysicsVelocity $lastWitness.Actual $lastWitness.From $lastWitness.Dt}
            if($f.Event -ceq 'MOVE_REJECTED'){
                Assert-TraversalFinalIssue $f $pending $issuedCount -Rejected -ExpectedVelocity $expectedVelocity
                $pending=$null;$pendingIssued=$false;continue
            }
            Assert-TraversalFinalIssue $f $pending $issuedCount -ExpectedVelocity $expectedVelocity
            $issuedCount++;$pendingIssued=$true;continue
        }
        if($f.Event -notin @('MOVE_DECISION','MOTION_WITNESS')){continue}
        if($isAcquisition -and ($null -eq $acquisition -or $acquisition.Acquired)){throw 'Acquisition command lacks its one initial stationary observation'}
        if(-not $isAcquisition -and $null -ne $acquisition -and -not $acquisition.Acquired){throw 'Ordinary movement before observed floor acquisition rest'}
        if(-not $isAcquisition -and $null -ne $acquisition -and -not $acquisition.RouteRebound){throw 'Ordinary movement before acquired actual route binding'}
        foreach($name in @('From','Requested','Actual')){Assert-TraversalVector $f.$name}
        if($f.Mask -ne -1 -or $f.Triggers -cne 'Ignore'){throw 'Incomplete overlap collision filter'}
        Assert-TraversalProfile $f.Profile;Assert-TraversalBody $f $expectedActor
        if($isAcquisition){Assert-AcquisitionBinding $f $acquisition;Assert-AcquisitionPolicy $f}else{
            Assert-TraversalSupport $f
            if($null -ne $f.PSObject.Properties['Permission']){Assert-AcquisitionPolicy $f}
        }
        Assert-TraversalContacts $f;Assert-TraversalNavigation $f
        $casts=Get-TraversalNumber $f.Casts 'cast count';$ms=Get-TraversalNumber $f.QueryMilliseconds 'query milliseconds'
        if($casts -lt 1 -or $casts -gt 64 -or $casts -ne [Math]::Floor($casts) -or $ms -lt 0){throw 'Missing/unbounded native query instrumentation'}
        $bodyKey=@($f.Body.Instance,$f.Body.RigidbodyInstance,$f.Body.Kinematic,$f.Body.Gravity,$f.Body.CollisionMode,$f.Body.Layer,$f.Body.DetectCollisions) -join '|'
        if($null -eq $baseline){$baseline=$bodyKey}elseif($baseline -cne $bodyKey){throw 'Original native body configuration changed'}
        if($f.Classification -notin @('CLEAR','SMALL_STEP_UP','STEP_DOWN','SLOPE') -or $f.Actuator -cne 'Rigidbody.MovePosition'){throw 'Unsafe/unrecognized movement classification or actuator'}
        if($isAcquisition -and ($f.Classification -cne 'CLEAR' -or $f.MotionMode -notin @('FLOOR_ACQUISITION','ACQUISITION_BRAKE_HOLD'))){throw 'Floor acquisition cannot claim ordinary height traversal'}
        if($f.Event -eq 'MOVE_DECISION'){
            if($null -ne $pending -or $f.NativeResult -cne 'PRECHECKED'){throw 'Overlapping or failed native movement command'}
            Assert-TraversalSamePoint $f.Actual $f.From 'decision actual pose';Assert-TraversalSweeps $f $f.Requested
            Assert-TraversalLanding $f -Acquisition:$isAcquisition
            if($isAcquisition){
                Assert-AcquisitionBinding $f $acquisition -Landing
                $later=if($fixedProtocol){$f.Clock.Sequence -gt $acquisition.ObservationClock.Sequence}else{$time -gt $acquisition.Time}
                if(-not $later -or $f.Requested[1] -gt $f.Actual[1]+0.0001){throw 'Acquisition must descend after actual stationary observation'}
                if($null -eq $lastWitness){Assert-TraversalSamePoint $f.From $acquisition.Start 'first acquisition command continuous observed start'}
            }else{$ordinaryIssued=$true}
            Assert-TraversalNavigation $f -Decision
            if($f.Classification -ne 'CLEAR'){
                $dy=[double]$f.Requested[1]-$f.From[1];$floorChange=[double]$f.Landing.FootY-$f.Support.FootY
                if([Math]::Abs($dy) -le 0.001 -or [Math]::Abs($floorChange) -le 0.001 -or $dy*$floorChange -le 0){throw 'Settling or unchanged support cannot establish height traversal'}
            }
            if($null -ne $lastWitness){
                Assert-TraversalSamePoint $f.From $lastWitness.Actual 'continuous command pose'
                if($command -le $lastWitness.Command){throw 'Replayed native movement command'}
                if($f.Stage -cne $lastWitness.Stage -and $lastWitness.Speed -gt 0){throw 'Stage transition reset measured native velocity without rest'}
            }
            if($fixedProtocol){
                Assert-TraversalClockSame $f.IssuedClock $f.Clock
                $plannedDt=[double]$f.Clock.Delta;Assert-TraversalNear $f.Dt $plannedDt 'planned physics interval' 0.000001;Assert-TraversalNear $f.FixedDt $plannedDt 'planned double physics interval' 0.000001
                $plannedVelocity=Get-TraversalPhysicsVelocity $f.Requested $f.From $plannedDt
                $prior=if($null -ne $lastWitness){Get-TraversalPhysicsVelocity $lastWitness.Actual $lastWitness.From $lastWitness.Dt}else{@(0,0,0)}
                if($null -eq $lastWitness){Assert-TraversalSamePoint $f.From $clockBaselinePose 'initial fixed command baseline pose'}
                $null=Assert-TraversalNativeVelocity $f.Body $prior
                $plannedSpeed=Get-WorldDistance $plannedVelocity @(0,0,0);$plannedAcceleration=(Get-WorldDistance $plannedVelocity $prior)/$plannedDt
                Assert-TraversalNear $f.Distance (Get-WorldDistance $f.From $f.Requested) 'planned displacement';Assert-TraversalNear $f.Speed $plannedSpeed 'planned speed';Assert-TraversalNear $f.Acceleration $plannedAcceleration 'planned acceleration' 0.001
                if($plannedSpeed -gt $f.Profile.MaxSpeed+0.001 -or $plannedAcceleration -gt $f.Profile.MaxAcceleration+0.001){throw 'Unsafe planned physics speed/acceleration'}
            }
            $pending=$f;$pendingIssued=$f.Navigation.AdmissionPolicy -cne 'NATIVE_CURRENT_ROUTE_V1'
            if($pendingIssued){$issuedCount++} # Legacy records predate explicit native issue events.
            continue
        }
        if($null -eq $pending -or -not $pendingIssued -or $command -ne $pending.Command -or $f.Stage -cne $pending.Stage -or $f.Classification -cne $pending.Classification -or $f.NativeResult -cne 'OBSERVED' -or
            $f.SupportPhase -cne $pending.SupportPhase -or $f.MotionMode -cne $pending.MotionMode -or $f.Schema -ne $pending.Schema){throw 'Unbound/failed native after-pose witness'}
        Assert-TraversalSamePoint $f.From $pending.From 'witness origin';Assert-TraversalSamePoint $f.Requested $pending.Requested 'witness request'
        Assert-TraversalSamePoint $f.Actual $f.Requested 'observed actuator target';Assert-TraversalSweeps $f $f.Actual
        if($fixedProtocol){
            Assert-TraversalClockSame $f.IssuedClock $pending.Clock
            $dt=[double]$f.Clock.FixedTime-$pending.Clock.FixedTime
            if($f.Clock.Sequence -ne $pending.Clock.Sequence+1){throw 'Command was not observed in the next native fixed step'}
            Assert-TraversalNear $dt $pending.Clock.Delta 'issued future physical interval' 0.000001
            Assert-TraversalNear $f.FixedDt $dt 'actual double fixed interval' 0.000001;Assert-TraversalNear $f.Dt $dt 'actual physics interval' 0.000001
            if([single](Get-TraversalNumber $f.PreviousTime 'previous issue wall alias') -ne [single]$pending.Clock.WallTime){throw 'Witness previous wall timestamp does not bind the issued command'}
        }else{$dt=$time-$pending.Time;Assert-TraversalNear $f.PreviousTime $pending.Time 'previous actual time';Assert-TraversalNear $f.Dt $dt 'actual dt'}
        if($dt -le 0 -or $dt -gt $f.Profile.MaxTick+0.001){throw 'Unbounded actuation interval'}
        $distance=Get-WorldDistance $f.From $f.Actual
        $velocity=if($fixedProtocol){Get-TraversalPhysicsVelocity $f.Actual $f.From $dt}else{@(for($j=0;$j -lt 3;$j++){($f.Actual[$j]-$f.From[$j])/$dt})}
        $speed=if($fixedProtocol){Get-WorldDistance $velocity @(0,0,0)}else{$distance/$dt}
        Assert-TraversalNear $f.Distance $distance 'actual displacement';Assert-TraversalNear $f.Speed $speed 'actual speed'
        if($fixedProtocol){
            # Keep the independent physical .001 m/s gate. The reported native
            # error itself comes from Vector3 float arithmetic, whose inputs
            # must be restored after JSON parsed the short decimals as doubles.
            $null=Assert-TraversalNativeVelocity $f.Body $velocity
            $nativeVelocity=$velocity
            $nativeError=Get-WorldDistance $f.Body.Velocity $nativeVelocity
            if($nativeError -gt 0.001){throw 'Native float velocity error exceeds the unchanged physical limit'}
            if($f.NativeVelocityMatches -isnot [bool] -or -not $f.NativeVelocityMatches){throw 'Native physics velocity mismatch was not accepted'}
            Assert-TraversalNear $f.NativeVelocityError $nativeError 'native fixed-step velocity error' 0.000001
        }
        $priorVelocity=if($null -eq $lastWitness){@(0,0,0)}elseif($fixedProtocol){Get-TraversalPhysicsVelocity $lastWitness.Actual $lastWitness.From $lastWitness.Dt}else{@(for($j=0;$j -lt 3;$j++){($lastWitness.Actual[$j]-$lastWitness.From[$j])/$lastWitness.Dt})}
        $acceleration=(Get-WorldDistance $velocity $priorVelocity)/$dt;$accelerationTolerance=if($fixedProtocol){0.001}else{0.01}
        Assert-TraversalNear $f.Acceleration $acceleration 'actual acceleration' $accelerationTolerance
        if($speed -gt $f.Profile.MaxSpeed+0.001 -or $acceleration -gt $f.Profile.MaxAcceleration+$accelerationTolerance){throw 'Unsafe actual speed/acceleration'}
        $dy=[double]$f.Actual[1]-$f.From[1]
        $modes=if($isAcquisition){@('FLOOR_ACQUISITION','ACQUISITION_BRAKE_HOLD')}else{@('SUPPORTED_ADVANCE','BRAKE_HOLD','ACTUAL_BRAKE')}
        if($f.MotionMode -notin $modes -or ($f.MotionMode -in @('BRAKE_HOLD','ACQUISITION_BRAKE_HOLD') -and ($distance -gt 0.00001 -or $speed -gt 0.00001 -or $f.Classification -ne 'CLEAR'))){throw 'Invalid native braking/advance receipt'}
        if($isAcquisition){if($dy -gt 0.0001){throw 'Acquisition moved upward'};$acquisition.LastGap=$f.Support.Gap}
        if($dy -gt $f.Profile.MaxStep+0.001 -or -$dy -gt $f.Profile.MaxDrop+0.001){throw 'Unsafe actual step/drop'}
        if($f.Classification -eq 'SMALL_STEP_UP' -and $dy -le 0 -or $f.Classification -eq 'STEP_DOWN' -and $dy -ge 0){throw 'Claimed vertical motion contradicts actual height'}
        if([Math]::Abs($dy) -gt 0.001 -and $f.Classification -ne 'CLEAR'){
            $key=[string]$f.Stage+'|'+[string]$f.Classification
            if($heightRunKey -cne $key){$heightRunKey=$key;$heightRun=0};$heightRun++
        }else{$heightRunKey='';$heightRun=0}
        $lastWitness=$f;$pending=$null;$pendingIssued=$false
    }
    if($null -ne $pending){throw 'Unobserved native actuation command'}
    if($null -eq $lastWitness -and -not @($frames|Where-Object Event -eq 'BLOCKED').Count){throw 'No actual movement or blocked evidence'}
    Assert-TraversalRecovery $frames
}
function Assert-TraversalPortal($nav,$witnesses){
    $h=$nav.FirstHome;$p=$h.Portal;$door=@($h.Home.Entities|Where-Object Role -eq 'DOOR')
    if($door.Count -ne 1 -or $p.DoorNetId -ne $door[0].NetId){throw 'Missing same-native-door traversal portal'}
    Assert-TraversalNear $p.Radius 0.5 'portal body radius';Assert-TraversalNear $p.Height 1.8 'portal body height'
    foreach($name in @('LocalCenter','LocalExtents','Scale','Center','Normal','Right','Up','Outside','Inside')){Assert-TraversalVector $p.$name}
    Assert-TraversalSamePoint $p.Scale @(1,1,1) 'native door scale'
    Assert-TraversalVector $door[0].Position;Assert-TraversalVector $door[0].Rotation 4
    $offset=Get-HomeRotated $door[0].Rotation $p.LocalCenter;$center=@(for($j=0;$j -lt 3;$j++){$door[0].Position[$j]+$offset[$j]})
    $thinX=$p.LocalExtents[0] -le $p.LocalExtents[2]
    $normal=Get-HomeRotated $door[0].Rotation $(if($thinX){@(1,0,0)}else{@(0,0,1)})
    $right=Get-HomeRotated $door[0].Rotation $(if($thinX){@(0,0,1)}else{@(1,0,0)})
    $up=Get-HomeRotated $door[0].Rotation @(0,1,0)
    if((Get-HomeDot $normal (Get-HomeRelative $p.Inside $p.Outside)) -lt 0){$normal=@($normal|ForEach-Object{-$_})}
    Assert-TraversalSamePoint $p.Center $center 'native portal center';Assert-TraversalSamePoint $p.Normal $normal 'native portal normal';Assert-TraversalSamePoint $p.Right $right 'native portal right';Assert-TraversalSamePoint $p.Up $up 'native portal up'
    Assert-TraversalNear $p.HalfWidth $(if($thinX){$p.LocalExtents[2]}else{$p.LocalExtents[0]}) 'native aperture width';Assert-TraversalNear $p.HalfHeight $p.LocalExtents[1] 'native aperture height'
    $crossings=@()
    foreach($w in @($witnesses)){
        $d=$w.DoorWitness
        if([string]$d.Actor -cne [string]$nav.Actor.NetId -or [string]$d.Door -cne [string]$p.DoorNetId -or $d.Open -isnot [bool] -or -not $d.Open){throw 'Missing fresh same-actor native open-door witness'}
        Assert-TraversalNear $d.Time $w.Time 'native door witness time' 0.0001;Assert-TraversalSamePoint $d.Position $door[0].Position 'native door witness pose'
        if(-not @($d.Colliders).Count){throw 'Missing native door collider witnesses'}
        foreach($c in @($d.Colliders)){
            Assert-TraversalVector $c.Center;Assert-TraversalVector $c.Extents;Assert-TraversalVector $c.Rotation 4
            if([string]::IsNullOrWhiteSpace([string]$c.Name) -or $c.enabled -isnot [bool]){throw 'Invalid actual door collider witness'}
        }
        $a=Get-HomeDot (Get-HomeRelative $w.From $center) $normal;$b=Get-HomeDot (Get-HomeRelative $w.Actual $center) $normal
        if(($a -lt 0 -and $b -ge 0) -or ($a -gt 0 -and $b -le 0)){
            $fraction=[Math]::Abs($a)/([Math]::Abs($a)+[Math]::Abs($b))
            $point=@(for($j=0;$j -lt 3;$j++){$w.From[$j]+$fraction*($w.Actual[$j]-$w.From[$j])})
            $relative=Get-HomeRelative @($point[0],($point[1]+0.9),$point[2]) $center
            if([Math]::Abs((Get-HomeDot $relative $right))+0.5 -gt $p.HalfWidth+0.001 -or [Math]::Abs((Get-HomeDot $relative $up))+0.9 -gt $p.HalfHeight+0.001){throw 'High-frequency original capsule missed native doorway aperture'}
            $event=if($a -lt 0){'CROSSED_IN'}else{'CROSSED_OUT'}
            $native=@($h.Navigation|Where-Object {$_.Event -eq $event -and $_.Open -is [bool] -and $_.Open -and [Math]::Abs($_.Time-$w.Time) -le 0.0001 -and (Get-WorldDistance $_.Position $point) -le 0.001})
            if($native.Count -ne 1){throw 'Native open-door event is not bound to high-frequency physical crossing'}
            $crossings+=@{Event=$event;Time=$w.Time;Start=$w.PreviousTime}
        }
    }
    if($crossings.Count -ne 2 -or $crossings[0].Event -ne 'CROSSED_IN' -or $crossings[1].Event -ne 'CROSSED_OUT'){throw 'Native building requires actual doorway in and out'}
    $tc=@($h.Home.Entities|Where-Object Role -eq 'TC');$reached=@($h.Navigation|Where-Object Event -eq 'TC_REACHED')
    if($tc.Count -ne 1 -or $reached.Count -ne 1 -or $reached[0].LineOfSight -isnot [bool] -or -not $reached[0].LineOfSight -or
        $reached[0].Time -lt $crossings[0].Time -or $reached[0].Time -gt $crossings[1].Time){throw 'Missing native TC arrival between doorway in and out'}
    Assert-TraversalVector $tc[0].Position;Assert-TraversalVector $reached[0].Position
    $range=Get-TraversalNumber $reached[0].Range 'native TC interaction range';Assert-TraversalNear $range (Get-WorldDistance $reached[0].Position $tc[0].Position) 'actual native TC range'
    $rest=@($witnesses|Where-Object {$_.Speed -eq 0 -and $_.Time -le $reached[0].Time -and $reached[0].Time-$_.Time -le 0.6 -and (Get-WorldDistance $_.Actual $reached[0].Position) -le 0.001})
    if($range -gt 2 -or $range -lt 0 -or -not $rest.Count){throw 'TC arrival is not bound to measured native rest/range'}
    $opening=@($h.Navigation|Where-Object {$_.Event -eq 'DOOR' -and $_.Before -is [bool] -and -not $_.Before -and $_.After -is [bool] -and $_.After -and $_.Requested -is [bool] -and $_.Requested -and $_.Time -le $crossings[0].Start -and $_.Owner -eq $true -and $_.Authed -eq $true -and $_.LineOfSight -eq $true -and $_.Busy -eq $false})
    if($opening.Count -ne 1){throw 'Missing authenticated native opening before traversal'}
    if(@($h.Navigation|Where-Object {$_.Event -eq 'DOOR' -and $_.After -eq $false -and $_.Time -ge $opening[0].Time -and $_.Time -le $crossings[1].Time}).Count){throw 'Native door closed during passage'}
    $closing=@($h.Navigation|Where-Object {$_.Event -eq 'DOOR' -and $_.Before -eq $true -and $_.After -eq $false -and $_.Requested -eq $false -and
        $_.Time -ge $crossings[1].Time -and $_.Owner -eq $true -and $_.Authed -eq $true -and $_.LineOfSight -eq $true -and $_.Busy -eq $false})
    if($closing.Count -ne 1){throw 'Missing authenticated native door close after actual exit'}
    $hinge=@($h.Navigation|Where-Object {$_.Event -eq 'DOOR_COLLIDER' -and $_.Time -ge $opening[0].Time -and $_.Time -le $crossings[0].Start})
    if($hinge.Count -ne 1 -or @($hinge[0].Closed).Count -eq 0 -or @($hinge[0].Closed).Count -ne @($hinge[0].Open).Count){throw 'Missing actual native hinge collider arrays'}
    $changed=$false
    for($j=0;$j -lt @($hinge[0].Closed).Count;$j++){
        $closed=$hinge[0].Closed[$j];$open=$hinge[0].Open[$j]
        foreach($row in @($closed,$open)){Assert-TraversalVector $row.Center;Assert-TraversalVector $row.Extents;Assert-TraversalVector $row.Rotation 4;if([string]::IsNullOrWhiteSpace([string]$row.Name)){throw 'Missing hinge native collider identity'}}
        if($closed.Name -cne $open.Name){throw 'Native door collider set was replaced'}
        $angle=0.0;for($k=0;$k -lt 4;$k++){$angle+=[Math]::Abs($closed.Rotation[$k]-$open.Rotation[$k])}
        if((Get-WorldDistance $closed.Center $open.Center) -gt 0.001 -or $angle -gt 0.001){$changed=$true}
    }
    if(-not $changed){throw 'Native door hinge motion is not measured'}
}
function Assert-TraversalDetourContact($d,$frames){
    $matched=$false
    foreach($f in @($frames|Where-Object {$_.Event -eq 'PHYSICAL_CONTACT' -and $_.Classification -eq 'DOOR_CLOSED'})){
        foreach($s in @($f.Sweeps)){foreach($h in @($s.Hits)){
            if($h.Blocking -eq $true -and $h.Collider.DoorOpen -is [bool] -and -not $h.Collider.DoorOpen -and
                [string]$h.Collider.Entity -ceq [string]$d.Door -and $h.Collider.Instance -eq $d.Collider){
                Assert-TraversalSamePoint $d.PlanePoint $h.Point 'detour measured door contact'
                Assert-TraversalSamePoint $d.PlaneNormal $h.Normal 'detour measured door normal'
                Assert-TraversalSamePoint $d.BoundsCenter $h.Collider.BoundsCenter 'detour measured door bounds'
                Assert-TraversalSamePoint $d.BoundsSize $h.Collider.BoundsSize 'detour measured door size'
                $matched=$true
            }
        }}
    }
    if(-not $matched){throw 'Detour plane/volume lacks preceding native closed-door contact binding'}
}
function Assert-TraversalOutdoorOrder($scenes,[switch]$G4Priority){
    $proven=@{};$end=0.0
    foreach($s in @($scenes)){
        $start=Get-TraversalNumber $s.StartTime 'ordered scene start';$next=Get-TraversalNumber $s.EndTime 'ordered scene end'
        if($start -lt $end-0.001 -or $next -lt $start){throw 'Outdoor scene order regressed'};$end=$next
        $required=if($s.Kind -eq 'SLOPE_DOWN'){@('OUTDOOR_STEP')}elseif($s.Kind -in @('SOLID_WALL','DOOR_CLOSED')){@('OUTDOOR_STEP','SLOPE_DOWN')}elseif($s.Kind -eq 'SAFE_DETOUR'){@('OUTDOOR_STEP','SLOPE_DOWN','SOLID_WALL','DOOR_CLOSED')}elseif($s.Kind -eq 'NATIVE_BUILDING_STEP'){@('OUTDOOR_STEP','SLOPE_DOWN','SOLID_WALL','DOOR_CLOSED','SAFE_DETOUR')}else{@()}
        if($G4Priority){
            if($s.Kind -in @('SOLID_WALL','DOOR_CLOSED')){$required=@()}
            elseif($s.Kind -ceq 'SAFE_DETOUR'){$required=@('SOLID_WALL','DOOR_CLOSED')}
            elseif($s.Kind -ceq 'NATIVE_BUILDING_STEP'){$required=@('SOLID_WALL','DOOR_CLOSED','SAFE_DETOUR')}
        }
        foreach($kind in $required){if(-not $proven.ContainsKey($kind)){throw ('Outdoor-first prerequisite missing: '+$kind)}}
        if($s.Status -eq 'PASSED' -or ($s.Status -eq 'BLOCKED' -and $s.Kind -in @('SOLID_WALL','DOOR_CLOSED'))){$proven[$s.Kind]=$true}
    }
}
function Assert-TraversalSceneResult($nav){
    $t=$nav.Traversal
    if($t.Schema -ne 1 -or $t.Mode -cne 'TRAVERSAL_BENCH' -or $nav.Status -notin @('GREEN','PARTIAL','BLOCKED','FAILED')){throw 'Missing traversal bench result'}
    if($t.Completed -isnot [bool]){throw 'Missing traversal completion state'}
    if(@($t.Frames).Count){Assert-AvatarActor $nav;Assert-TraversalFrames $t.Frames $nav.Actor.NetId $t.World}
    elseif($nav.Status -eq 'GREEN' -or $t.Completed -eq $true -or $t.Actuations -ne 0){throw 'Complete traversal has no native frames'}
    $frames=@($t.Frames);$scenes=@($t.Scenes);$passed=@{}
    if($t.Order -in @('OUTDOOR_FIRST','OWNED_NATIVE_TEST_FIXTURE')){Assert-TraversalOutdoorOrder $scenes -G4Priority:($t.SequencePolicy -ceq 'G4_PRIORITY_V1')}
    $actuations=Get-TraversalNumber $t.Actuations 'actuation count'
    if($actuations -ne @($frames|Where-Object Event -eq 'MOTION_WITNESS').Count){throw 'Unobserved or unaccounted native actuation'}
    foreach($s in $scenes){
        $from=Get-TraversalNumber $s.FramesFrom 'scene first index';$to=Get-TraversalNumber $s.FramesTo 'scene exclusive end index'
        if($from -lt 0 -or $to -gt $frames.Count -or $to -lt $from -or ($to -eq $from -and $s.Status -ne 'NOT_PROVEN') -or $from -ne [Math]::Floor($from) -or $to -ne [Math]::Floor($to) -or
            $s.Kind -notin @('OUTDOOR_STEP','SLOPE_DOWN','NATIVE_BUILDING_STEP','SOLID_WALL','DOOR_CLOSED','SAFE_DETOUR') -or $s.Status -notin @('PASSED','BLOCKED','NOT_PROVEN')){throw 'Invalid traversal scene boundary/status'}
        Assert-TraversalVector $s.Start;Assert-TraversalVector $s.End
        $startTime=Get-TraversalNumber $s.StartTime 'scene start time';$endTime=Get-TraversalNumber $s.EndTime 'scene end time'
        if($startTime -lt 0 -or $endTime -lt $startTime){throw 'Invalid traversal scene time boundaries'}
        if($s.Status -eq 'NOT_PROVEN'){continue}
        $slice=@($frames[$from..($to-1)]);$allWitnesses=@($slice|Where-Object Event -eq 'MOTION_WITNESS')
        $w=@($allWitnesses|Where-Object {$_.SupportPhase -ne 'FLOOR_ACQUISITION'})
        if($slice[0].Time -lt $startTime-0.001 -or $slice[-1].Time -gt $endTime+0.001){throw 'Scene frames are outside actual scene times'}
        if($s.Status -eq 'PASSED'){
            if($s.Kind -in @('SOLID_WALL','DOOR_CLOSED') -or $w.Count -lt 2){throw 'Missing distinct physical scene witnesses'}
            Assert-TraversalSamePoint $s.Start $allWitnesses[0].From 'scene actual start';Assert-TraversalSamePoint $s.End $allWitnesses[-1].Actual 'scene actual end'
            if($s.Kind -eq 'SAFE_DETOUR'){
                if($t.Order -ceq 'OWNED_NATIVE_TEST_FIXTURE'){
                    Assert-TraversalExteriorDetour $nav $s $w @($frames|Select-Object -First $from)
                    $passed[$s.Kind]=$s;continue
                }
                if((Get-WorldDistance $s.Start $s.End) -lt 1 -or $w[-1].Speed -ne 0){throw 'Detour lacks actual distance and observed rest'}
                $door=$null
                $binding=$null
                foreach($f in $w){
                    $d=$f.DetourDoorWitness;Assert-AvatarUid $d.Door;if($d.Open -isnot [bool] -or $d.Open){throw 'Detour lacks closed-door native witness'}
                    foreach($key in @('Position','PlanePoint','PlaneNormal','BoundsCenter','BoundsSize')){Assert-TraversalVector $d.$key}
                    Assert-TraversalNear (Get-TraversalDot $d.PlaneNormal $d.PlaneNormal) 1 'detour native plane normal'
                    if([Math]::Abs($d.PlaneNormal[1]) -ge 0.1){throw 'Detour plane is not a measured door side'}
                    $encoded=$d|ConvertTo-Json -Compress -Depth 8
                    if($null -ne $binding -and $encoded -cne $binding){throw 'Detour door plane/volume changed'};$binding=$encoded
                    if($null -ne $door -and $door -cne $d.Door){throw 'Detour door changed'};$door=$d.Door
                }
                Assert-TraversalDetourContact $d @($frames|Select-Object -First $from)
                $a=@(for($i=0;$i -lt 3;$i++){$s.Start[$i]-$d.BoundsCenter[$i]});$b=@(for($i=0;$i -lt 3;$i++){$s.End[$i]-$d.BoundsCenter[$i]})
                $near=Get-TraversalDot $a $d.PlaneNormal;$far=Get-TraversalDot $b $d.PlaneNormal
                $extent=0.0;for($i=0;$i -lt 3;$i++){$extent+=[Math]::Abs($d.PlaneNormal[$i])*$d.BoundsSize[$i]*0.5}
                if($near*$far -ge 0 -or [Math]::Abs($near) -lt 0.5+$extent -or [Math]::Abs($far) -lt 0.5+$extent){throw 'Detour did not reach opposite sides of actual closed-door volume'}
                $passed[$s.Kind]=$s;continue
            }
            $dy=[double]$s.End[1]-$s.Start[1]
            $height=@($w|Where-Object {if($s.Kind -eq 'SLOPE_DOWN'){[double]$_.Actual[1]-$_.From[1] -lt -0.001}else{[double]$_.Actual[1]-$_.From[1] -gt 0.001}})
            if(($s.Kind -eq 'SLOPE_DOWN' -and $dy -ge -0.001) -or $height.Count -lt 2 -or
                -not @($slice|Where-Object Event -eq 'STEP_RESOLVED').Count){throw 'Scene flags lack measured up/down transition'}
            if($s.Kind -in @('OUTDOOR_STEP','SLOPE_DOWN') -and -not @($height|Where-Object {$_.Support.Collider.Type -match '(^|\.)TerrainCollider$'}).Count){throw 'Outdoor scene lacks actual native terrain support'}
            if($s.Kind -eq 'NATIVE_BUILDING_STEP'){
                $foundation=@($nav.FirstHome.Home.Entities|Where-Object {$_.Role -eq 'FOUNDATION' -and $_.Type -eq 'BuildingBlock'})
                if(-not $foundation.Count -or -not @($height|Where-Object {$_.Support.Collider.Entity -in $foundation.NetId}).Count){throw 'Building scene lacks actual native foundation support'}
                if(@($w|Where-Object {[double]$_.Actual[1]-$_.From[1] -lt -0.001}).Count -lt 2){throw 'Native building lacks actual supported descent'}
                Assert-TraversalPortal $nav $w
            }
            $passed[$s.Kind]=$s
        }
        if($s.Status -eq 'BLOCKED' -and $s.Kind -in @('SOLID_WALL','DOOR_CLOSED')){
            $blocked=@($slice|Where-Object {$_.Event -in @('BLOCKED','PROBE_REFUSED') -and $_.Classification -in @('SOLID_BLOCKED','DOOR_CLOSED')})
            if(-not $blocked.Count -or [string]::IsNullOrWhiteSpace([string]$s.Reason)){throw 'Wall/closed-door flag lacks actual blocking receipt'}
            $contact=@($slice|Where-Object Event -eq 'PHYSICAL_CONTACT')
            if(-not $contact.Count){throw 'Blocked scene lacks native collision measurement'}
            Assert-TraversalSamePoint $s.Start $s.End 'negative scene actual pose'
            foreach($c in $contact){
                if($c.Stage -cne $s.Stage){throw 'Negative contact belongs to another scene'}
                Assert-TraversalSamePoint $s.Start $c.Actual 'negative scene contact pose'
                Assert-TraversalBlockedContact $c $s.Kind $nav.Actor.NetId
                if($t.Order -ceq 'OWNED_NATIVE_TEST_FIXTURE'){
                    Assert-TraversalProbe $blocked[0] $nav.Actor.NetId
                    $expected=if($s.Kind -eq 'DOOR_CLOSED'){$t.Fixture.Door}else{$t.Fixture.Wall}
                    if([string]::IsNullOrEmpty([string]$expected) -or [string]$c.TargetEntity -cne [string]$expected){throw 'Fixture refusal names another native target'}
                }
            }
            $passed[$s.Kind]=$s
        }
    }
    if($nav.Status -eq 'GREEN' -or $t.Completed -eq $true){
        $requiredKinds=if($t.SequencePolicy -ceq 'G4_PRIORITY_V1' -and $nav.Status -cne 'GREEN'){@('NATIVE_BUILDING_STEP','SOLID_WALL','DOOR_CLOSED')}else{@('OUTDOOR_STEP','SLOPE_DOWN','NATIVE_BUILDING_STEP','SOLID_WALL','DOOR_CLOSED')}
        foreach($kind in $requiredKinds){if(-not $passed.ContainsKey($kind)){throw ('GREEN traversal lacks '+$kind)}}
        if($t.Order -in @('OUTDOOR_FIRST','OWNED_NATIVE_TEST_FIXTURE') -and -not $passed.ContainsKey('SAFE_DETOUR')){throw 'Outdoor-first completion lacks actual safe detour'}
        if($t.Order -ceq 'OWNED_NATIVE_TEST_FIXTURE' -and -not @($frames|Where-Object {$_.Stage -like 'HOME_*' -and $_.Event -eq 'MOTION_WITNESS' -and
            $_.Classification -eq 'SMALL_STEP_UP' -and ($_.Support.Kind -eq 'STEP_EDGE' -or $_.Landing.Kind -eq 'STEP_EDGE')}).Count){throw 'Complete fixture traversal lacks an actual discrete native step'}
        if($t.Completed -isnot [bool] -or -not $t.Completed -or ($passed.ContainsKey('OUTDOOR_STEP') -and $passed.OUTDOOR_STEP.Stage -eq $passed.NATIVE_BUILDING_STEP.Stage)){throw 'GREEN traversal lacks separate outdoor/building contexts'}
    }
}
function Assert-TraversalBuildPlan($p){
    if($p.Kind -cne 'EXTERIOR_BUILD_PLAN_V1' -or $p.PredictedGeometry -isnot [bool] -or $p.ActualGeometry -isnot [bool] -or
        $p.PredictedGeometry -eq $p.ActualGeometry -or $p.Accepted -isnot [bool] -or $p.MaxLegs -ne 3){throw 'Missing bounded predicted/actual exterior build plan'}
    Assert-TraversalVector $p.From;Assert-TraversalVector $p.Goal
    $queries=Get-TraversalNumber $p.Queries 'build native path queries';$ms=Get-TraversalNumber $p.Milliseconds 'build planner duration'
    if($queries -lt 1 -or $queries -gt 17 -or $queries -ne [Math]::Floor($queries) -or $ms -lt 0 -or $ms -gt 500){throw 'Unbounded build planner work'}
    if(-not $p.Accepted){if(@($p.Legs).Count -or @($p.Waypoints).Count){throw 'Rejected build plan retained executable legs'};return}
    $legs=@($p.Legs);if($legs.Count -lt 1 -or $legs.Count -gt 3 -or @($p.Waypoints).Count -ne $legs.Count){throw 'Missing/excess exterior build legs'}
    $prior=$p.From;$total=0.0
    for($i=0;$i -lt $legs.Count;$i++){
        $leg=$legs[$i];$corners=@($leg.Corners)
        if($leg.Status -cne 'PathComplete' -or $corners.Count -lt 2 -or $corners.Count -ge 256){throw 'Incomplete/saturated native build path'}
        Assert-TraversalSamePoint $leg.From $prior 'native build leg join';Assert-TraversalSamePoint $leg.To $p.Waypoints[$i] 'native build waypoint'
        if((Get-WorldDistance $leg.From $corners[0]) -gt 0.5 -or (Get-WorldDistance $leg.To $corners[-1]) -gt 0.5){throw 'Build path has another query origin/goal'}
        Assert-TraversalExteriorSegment $p $leg.From $corners[0];Assert-TraversalExteriorSegment $p $corners[-1] $leg.To
        $length=0.0
        for($j=1;$j -lt $corners.Count;$j++){$length+=Get-WorldDistance $corners[$j-1] $corners[$j];Assert-TraversalExteriorSegment $p $corners[$j-1] $corners[$j]}
        Assert-TraversalNear $leg.Length $length 'native build leg length' 0.01
        if($length -gt 24){throw 'Unbounded native build leg'};$total+=$length;$prior=$leg.To
    }
    Assert-TraversalSamePoint $prior $p.Goal 'build final goal';Assert-TraversalNear $p.Length $total 'summed native build length' 0.01
    if($total -gt 24){throw 'Unbounded exterior build route'}
}
function Assert-TraversalBuildRoutes($n){
    $t=$n.Traversal;if($t.FixturePolicy -cne 'MINIMAL_G4_BEFORE_TC_V1'){return}
    $actual=@{}
    foreach($p in @($t.BuildPlans)){
        Assert-TraversalBuildPlan $p
        if($p.ActualGeometry -and $p.Accepted){if($actual.ContainsKey([string]$p.Label)){throw 'Replayed exterior build stage'};$actual[[string]$p.Label]=$p}
    }
    $foundation=@($n.FirstHome.PartialEntities|Where-Object Role -ceq 'FOUNDATION')
    if($actual.Count -and $foundation.Count -ne 1){throw 'Actual build plan lacks the paid native foundation'}
    foreach($p in $actual.Values){
        Assert-TraversalSamePoint $p.FoundationPosition $foundation[0].Position 'actual paid foundation pose'
        Assert-TraversalVector $foundation[0].Rotation 4
        for($j=0;$j -lt 4;$j++){Assert-TraversalNear $p.FoundationRotation[$j] $foundation[0].Rotation[$j] 'actual paid foundation rotation'}
    }
    $motions=@($t.Frames|Where-Object {$_.Event -in @('MOVE_DECISION','MOTION_WITNESS') -and $_.Stage -match '^HOME_(BUILD_|FIXTURE_)'})
    foreach($f in $motions){
        $b=$f.BuildExteriorWitness
        if($null -eq $b -or -not $actual.ContainsKey([string]$b.Stage) -or [string]$b.Foundation -cne [string]$foundation[0].NetId -or $b.Leg -lt 1 -or $b.Leg -gt 3 -or $b.Leg -ne [Math]::Floor($b.Leg) -or
            $f.Stage -cne ('HOME_'+$b.Stage+'_EXTERIOR_'+$b.Leg)){throw 'Build motion lacks its actual exterior leg binding'}
        $p=$actual[[string]$b.Stage];if($b.Leg -gt @($p.Legs).Count){throw 'Build motion exceeded planned legs'}
        Assert-TraversalSamePoint $b.FoundationPosition $p.FoundationPosition 'build original foundation position'
        Assert-TraversalVector $b.FoundationRotation 4;for($j=0;$j -lt 4;$j++){Assert-TraversalNear $b.FoundationRotation[$j] $p.FoundationRotation[$j] 'build foundation rotation'}
        $endpoint=if($f.Event -ceq 'MOVE_DECISION'){$f.Requested}else{$f.Actual};$outside=$true
        try{Assert-TraversalExteriorSegment $p $f.From $endpoint}catch{$outside=$false}
        if($b.Outside -isnot [bool] -or $b.Outside -ne $outside){throw 'Build footprint flag contradicts actual segment'}
        if(-not $outside -and ($f.Event -ne 'MOVE_DECISION' -or -not @($t.Frames|Where-Object {$_.Event -eq 'MOVE_REJECTED' -and $_.Command -eq $f.Command -and $_.WriterCalled -eq $false}).Count)){
            throw 'Issued/observed build motion entered the foundation footprint'
        }
    }
    foreach($stage in $actual.Keys){
        $p=$actual[$stage];$rests=@($t.BuildRests|Where-Object Stage -ceq $stage);$prior=$p.From
        if($rests.Count -gt @($p.Legs).Count){throw 'Too many exterior waypoint rests'}
        for($i=0;$i -lt $rests.Count;$i++){
            $r=$rests[$i];$leg=$i+1;$group=@($motions|Where-Object {$_.Event -eq 'MOTION_WITNESS' -and $_.BuildExteriorWitness.Stage -ceq $stage -and $_.BuildExteriorWitness.Leg -eq $leg})
            if(-not $group.Count -or $r.Leg -ne $leg -or $r.Remaining -ne @($p.Legs).Count-$leg -or $r.Arrived -ne $true -or $r.Active -ne $false -or $r.Blocked -ne $false -or
                $group[-1].Speed -ne 0 -or $r.Time -lt $group[-1].Time -or $r.Time-$group[-1].Time -gt 1.5){throw 'Exterior build waypoint lacks ordered actual rest'}
            Assert-TraversalSamePoint $r.NativeVelocity @(0,0,0) 'native build rest velocity';Assert-TraversalSamePoint $group[-1].Body.Velocity @(0,0,0) 'measured build rest velocity'
            if((Get-WorldDistance $r.NativeVelocity @(0,0,0)) -ne 0 -or (Get-WorldDistance $group[-1].Body.Velocity @(0,0,0)) -ne 0){throw 'Exterior build rest retained nonzero native velocity'}
            Assert-TraversalSamePoint $r.Position $group[-1].Actual 'actual build waypoint rest';Assert-TraversalSamePoint $group[0].From $prior 'actual exterior leg start'
            if((Get-WorldDistance $r.Position $p.Waypoints[$i]) -gt 0.3){throw 'Build rest missed actual waypoint'}
            $issued=@($t.Frames|Where-Object {$_.Event -eq 'MOVE_ISSUED' -and $_.Time -le $group[-1].Time}).Count
            if($r.Actuations -ne $issued){throw 'Build rest counter differs from native issues'}
            $prior=$r.Position
        }
        foreach($f in @($motions|Where-Object {$_.BuildExteriorWitness.Stage -ceq $stage -and $_.BuildExteriorWitness.Leg -gt 1})){
            $before=@($rests|Where-Object {$_.Leg -eq $f.BuildExteriorWitness.Leg-1 -and $_.Time -le $f.Time})
            if($before.Count -ne 1){throw 'Next exterior build leg started before observed rest'}
        }
    }
}
function Assert-TraversalFixtureRows($s,$actor){
    if($s.Owner -cne [string]$actor -or $s.ForeignUnchanged -ne $true){throw 'Fixture has foreign ownership/changes'}
    Assert-AvatarUid $s.BuildingId;$seen=@{};$ids=@{}
    foreach($row in @($s.Entities)){
        Assert-AvatarUid $row.NetId
        if($seen.ContainsKey([string]$row.Role) -or $ids.ContainsKey([string]$row.NetId)){throw 'Duplicate native fixture role/entity'};$seen[[string]$row.Role]=$true;$ids[[string]$row.NetId]=$true
        $type=if($row.Role -eq 'DOOR'){'Door'}elseif($row.Role -eq 'TC'){'BuildingPrivlidge'}else{'BuildingBlock'}
        if($row.Role -notin @('FOUNDATION','WALL_N','DOORWAY','DOOR','TC','WALL_E','WALL_W','ROOF') -or $row.Type -cne $type -or -not $row.Prefab -or
            $row.Owner -cne $s.Owner -or $row.BuildingId -cne $s.BuildingId -or $row.Registered -ne $true -or $row.Saving -ne $true -or $row.Support -ne $true -or
            (Get-TraversalNumber $row.Health 'fixture health') -le 0 -or ($type -eq 'BuildingBlock' -and ($row.Grade -cne 'Wood' -or $row.Links -lt 1))){throw 'Invalid native paid fixture structure'}
        Assert-TraversalVector $row.Position;Assert-TraversalVector $row.Rotation 4
    }
}
function Assert-TraversalMinimalFixture($n,$paid){
    $t=$n.Traversal;$h=$n.FirstHome;if($t.FixturePolicy -cne 'MINIMAL_G4_BEFORE_TC_V1'){return}
    $order=@('FOUNDATION','WALL_N','DOORWAY','DOOR','TC','WALL_E','WALL_W','ROOF')
    $placed=@($h.NativePlacements);$ops=@($h.Operations|Where-Object {$_.Kind -like 'BUILD_*'})
    if($placed.Count -ne $ops.Count -or $placed.Count -gt 8){throw 'Native fixture placement/payment count differs'}
    for($i=0;$i -lt $placed.Count;$i++){
        if($placed[$i].Role -cne $order[$i] -or $ops[$i].Kind -cne ('BUILD_'+$order[$i]) -or $placed[$i].Entity -cne $ops[$i].EntityId -or
            $placed[$i].NativeCall -cne 'Planner.DoBuild(Construction.Target,Construction)'){throw 'Native fixture role/order/entity payment is unbound'}
    }
    foreach($a in @($h.Approaches)){if($a.Label -ceq 'LEGACY_COMPOSITE' -or $a.Step -lt 1 -or $a.Step -gt 7 -or $a.ActorNetId -cne $n.Actor.NetId){throw 'New bench approach used historical step semantics'};Assert-FirstHomeApproach $a}
    $f=$t.Fixture;$events=@($t.FixtureTransitions)
    if($null -eq $f){
        if($events.Count -or $placed.Count -gt 4 -or $h.Home -or $h.Upkeep -or $h.NavigationComplete -or $t.Completed -or $n.Status -eq 'GREEN' -or
            @($t.Scenes|Where-Object {$_.Kind -in @('SOLID_WALL','DOOR_CLOSED','SAFE_DETOUR','NATIVE_BUILDING_STEP') -and $_.Status -ne 'NOT_PROVEN'}).Count){throw 'G4/full home claimed before paid minimal native fixture'}
        return
    }
    if($t.FixtureForeignUnchanged -ne $true -or $f.Source -cne 'OWNED_NATIVE_TEST_FIXTURE' -or $f.Stage -cne 'PAID_MINIMAL_G4' -or $f.DiagnosticOnly -ne $true -or
        (@($f.Structure.Entities.Role|Sort-Object) -join ',') -cne 'DOOR,DOORWAY,FOUNDATION,WALL_N'){throw 'Missing exact minimal G4 native roles'}
    Assert-TraversalFixtureRows $f.Structure $n.Actor.UserId
    foreach($kind in @('CRAFT_TOOL','CRAFT_building.planner','CRAFT_hammer','CRAFT_door.hinged.wood','CRAFT_cupboard.tool','BUILD_FOUNDATION','UPGRADE_FOUNDATION','BUILD_WALL_N','UPGRADE_WALL_N','BUILD_DOORWAY','UPGRADE_DOORWAY','BUILD_DOOR')){
        if(-not $paid.ContainsKey($kind)){throw ('Minimal fixture lacks real native payment '+$kind)}
    }
    $final=[pscustomobject]@{Owner=$f.Structure.Owner;BuildingId=$f.Structure.BuildingId;ForeignUnchanged=$f.Structure.ForeignUnchanged;Entities=@($h.PartialEntities)}
    Assert-TraversalFixtureRows $final $n.Actor.UserId
    if(@($final.Entities).Count -ne $placed.Count){throw 'Paid native placement disappeared from partial structure'}
    foreach($row in $final.Entities){
        $p=@($placed|Where-Object Role -ceq $row.Role)
        if($p.Count -ne 1 -or $p[0].Entity -cne $row.NetId -or -not $paid.ContainsKey('BUILD_'+$row.Role) -or ($row.Type -eq 'BuildingBlock' -and -not $paid.ContainsKey('UPGRADE_'+$row.Role))){throw 'Native fixture row has no exact paid placement/grade'}
        $op=@($h.Operations|Where-Object Kind -ceq ('BUILD_'+$row.Role))[0]
        if((Get-FirstHomeEconomicKey $p[0].Before) -cne (Get-FirstHomeEconomicKey $op.Before) -or (Get-FirstHomeEconomicKey $p[0].After) -cne (Get-FirstHomeEconomicKey $op.After)){throw 'Native placement UID debit differs from paid operation'}
        if($row.Type -ceq 'BuildingBlock'){
            $up=@($h.Operations|Where-Object Kind -ceq ('UPGRADE_'+$row.Role))
            if($up.Count -ne 1 -or $up[0].EntityId -cne $row.NetId){throw 'Wood grade payment belongs to another native block'}
        }
        if($row.Role -eq 'FOUNDATION'){if($p[0].Parent -or $p[0].Socket){throw 'Foundation did not use actual terrain'}}
        else{
            $parent=if($row.Role -eq 'DOOR'){'DOORWAY'}elseif($row.Role -eq 'ROOF'){'WALL_N'}else{'FOUNDATION'}
            if($p[0].Parent -cne [string](@($final.Entities|Where-Object Role -ceq $parent)[0].NetId)){throw 'Fixture native parent does not match placed structure'}
        }
        if($row.Role -in @('WALL_N','WALL_E','WALL_W','DOORWAY')){
            $suffix=if($row.Role -ceq 'WALL_N'){3}elseif($row.Role -ceq 'WALL_E'){4}elseif($row.Role -ceq 'WALL_W'){2}else{1}
            if(-not $p[0].Socket -or -not $p[0].Socket.EndsWith('/wall-female/'+$suffix)){throw 'Fixture wall role names another native socket'}
        }
    }
    foreach($row in $f.Structure.Entities){
        $same=@($final.Entities|Where-Object Role -ceq $row.Role)
        if($same.Count -ne 1 -or $same[0].NetId -cne $row.NetId){throw 'Minimal native fixture body was replaced'}
        Assert-TraversalSamePoint $row.Position $same[0].Position 'minimal fixture native geometry'
        for($j=0;$j -lt 4;$j++){Assert-TraversalNear $row.Rotation[$j] $same[0].Rotation[$j] 'minimal fixture native rotation'}
    }
    $door=@($final.Entities|Where-Object Role -ceq 'DOOR')[0];$doorway=@($final.Entities|Where-Object Role -ceq 'DOORWAY')[0]
    Assert-FirstHomeDoorPlacement $placed $door $doorway.NetId
    $ready=@($events|Where-Object Event -ceq 'PAID_MINIMAL_READY');$resume=@($events|Where-Object Event -ceq 'G4_COMPLETE_RESUME_HOME');$full=@($events|Where-Object Event -ceq 'FULL_HOME_READY')
    if($events.Count -ne $ready.Count+$resume.Count+$full.Count -or $ready.Count -ne 1 -or $resume.Count -gt 1 -or $full.Count -gt 1 -or
        $ready[0].Step -ne 4 -or $ready[0].NextRole -cne 'TC' -or $ready[0].DoorClosed -ne $true -or $ready[0].G4Complete -ne $false){throw 'Missing/forged minimal native boundary transition'}
    foreach($e in @($ready)+@($resume)){
        if((@($e.Structure.Entities.NetId|Sort-Object) -join ',') -cne (@($f.Structure.Entities.NetId|Sort-Object) -join ',')){throw 'G4 boundary names another paid fixture'}
        Assert-TraversalFixtureRows $e.Structure $n.Actor.UserId
    }
    if($resume.Count){
        $r=$resume[0]
        if($r.Step -ne 4 -or $r.NextRole -cne 'TC' -or $r.G4Complete -ne $true -or $r.DoorClosed -ne $true -or $r.Time -lt $ready[0].Time){throw 'Invalid G4 resume boundary'}
        foreach($kind in @('SOLID_WALL','DOOR_CLOSED','SAFE_DETOUR')){
            $status=if($kind -ceq 'SAFE_DETOUR'){'PASSED'}else{'BLOCKED'}
            if(-not @($t.Scenes|Where-Object {$_.Kind -ceq $kind -and $_.Status -ceq $status -and $_.EndTime -le $r.Time -and $_.StartTime -ge $ready[0].Time}).Count){throw 'TC resumed before real G4 wall/Door/detour scenes'}
        }
    }
    $tc=@($final.Entities|Where-Object Role -ceq 'TC')
    if($tc.Count){
        if($resume.Count -ne 1 -or @($ops|Where-Object {$_.Kind -ceq 'BUILD_TC' -and $_.Time -ge $resume[0].Time}).Count -ne 1){throw 'TC native build preceded G4 completion'}
        Assert-FirstHomeTcPlacement $placed;Assert-FirstHomeTcAuthorization $h.TcAuthorization $n.Actor.UserId $final.BuildingId $tc[0]
    }
    if($h.Home){Assert-FirstHomeStructure $h.Home}
    if($full.Count -or $h.NavigationComplete -or $t.Completed -or $n.Status -eq 'GREEN'){
        if($full.Count -ne 1 -or $resume.Count -ne 1 -or $full[0].Step -ne 8 -or $full[0].NextRole -cne 'HOME_IN_OUT' -or $full[0].G4Complete -ne $true -or $full[0].DoorClosed -ne $true -or
            $full[0].Time -lt $resume[0].Time -or $null -eq $h.Home -or $null -eq $h.Upkeep -or $paid.Count -ne 19){throw 'Full home claimed from minimal G4 fixture'}
        Assert-FirstHomeStructure $full[0].Structure;Assert-FirstHomeUpkeep $h.Upkeep
    }
}
function Assert-TraversalSmokeBoundary($n){
    $h=$n.FirstHome;$complete=$n.Traversal.Completed -eq $true -or $n.Status -eq 'GREEN'
    if($n.Mode -cne 'BUILD_SMOKE' -or $h.Schema -ne 1 -or $h.DiagnosticOnly -isnot [bool] -or -not $h.DiagnosticOnly -or
        $n.Persistence.Saved -ne $false -or $n.Persistence.Restored -ne $false -or $h.SaveReady -ne $false -or
        @($n.Harvests).Count -or (Get-TraversalNumber $n.ManualPositionWrites 'manual position writes') -ne 0){throw 'Traversal diagnostic crossed natural/save boundary'}
    if($n.Conservation.EconomicFailure -and $n.Status -ne 'FAILED'){throw 'Traversal conservation failure cannot pass'}
    if(-not $n.Actor){if($complete -or $h.NavigationComplete){throw 'Complete traversal home without native actor'};return}
    Assert-AvatarActor $n
    if(-not @($h.Fixture).Count){if($complete -or $h.NavigationComplete){throw 'Complete traversal home without diagnostic fixture ledger'};return}
    $issued=@();$expected=@{}
    foreach($name in $h.Budget.PSObject.Properties.Name){$expected[$name]=[int]$h.Budget.$name}
    foreach($cost in $n.Recipe.Ingredients){$expected[$cost.Shortname]+=[int]$cost.Amount}
    foreach($row in $h.Fixture){
        if($row.DiagnosticOnly -ne $true -or $row.Item.Shortname -notin @('wood','stones') -or
            $row.Source -cne ('TEST_FIXTURE_'+$row.Item.Shortname.ToUpperInvariant()) -or $row.Amount -ne $row.Item.Amount -or $row.Item.OwnerNetId -ne $n.Actor.NetId){throw 'Unknown traversal diagnostic fixture provenance'}
        $issued+=@($row.Item)
    }
    $null=Get-FirstHomeEconomicKey $issued
    foreach($name in $expected.Keys){if([int](($issued|Where-Object Shortname -eq $name|Measure-Object Amount -Sum).Sum) -ne $expected[$name]){throw 'Traversal fixture budget differs from loaded native cost'}}
    $last=@(@($n.StarterKit)+$issued);$paid=@{}
    foreach($op in $h.Operations){
        if($op.Kind -eq 'GATHER' -or $paid.ContainsKey([string]$op.Kind) -or (Get-FirstHomeEconomicKey $last) -cne (Get-FirstHomeEconomicKey $op.Before)){throw 'Traversal duplicate/gather/broken native payment chain'}
        Assert-FirstHomePayment $op
        if($op.Kind -eq 'CRAFT_TOOL'){$cost=$n.Recipe.Ingredients}
        elseif($op.Kind -like 'CRAFT_*'){$cost=$h.Recipes.($op.Kind.Substring(6)).Ingredients}
        elseif($op.Kind -in @('BUILD_DOOR','BUILD_TC')){$cost=@([pscustomobject]@{Shortname=$(if($op.Kind -eq 'BUILD_TC'){'cupboard.tool'}else{'door.hinged.wood'});Amount=1})}
        else{$cost=$h.GradeCosts.($op.Kind)}
        if(-not $cost -or (Get-FirstHomeCostKey $cost) -cne (Get-FirstHomeCostKey $op.Costs)){throw 'Traversal payment differs from loaded recipe/grade'}
        $paid[[string]$op.Kind]=$true;$last=$op.After
    }
    $fixtureReady=$n.Traversal.Order -ceq 'OWNED_NATIVE_TEST_FIXTURE' -and $null -ne $n.Traversal.Fixture
    $minimalPolicy=$n.Traversal.FixturePolicy -ceq 'MINIMAL_G4_BEFORE_TC_V1'
    if($minimalPolicy){Assert-TraversalMinimalFixture $n $paid}
    $fullReady=$minimalPolicy -and $null -ne $h.Home -and $null -ne $h.Upkeep
    if(-not $complete -and -not $h.NavigationComplete -and (-not $fixtureReady -or ($minimalPolicy -and -not $fullReady))){
        if($h.PendingIntent){throw 'Partial traversal has an unreconciled native payment intent'}
        $expectedInventory=$last
        if($null -ne $h.Upkeep){
            $u=$h.Upkeep;Assert-FirstHomeUpkeep $u
            if((Get-FirstHomeEconomicKey $last) -cne (Get-FirstHomeEconomicKey $u.Before) -or
                (Get-FirstHomeEconomicKey $u.Before) -cne (Get-FirstHomeEconomicKey @(@($u.After)+@($u.TcInventory)))){throw 'Partial traversal TC transfer differs from paid ledger'}
            $expectedInventory=$u.After
        }
        if((Get-FirstHomeEconomicKey $expectedInventory) -cne (Get-FirstHomeEconomicKey $n.Inventory)){throw 'Partial traversal final inventory differs from paid ledger'}
        return
    }
    Assert-FirstHomeTcPlacement $h.NativePlacements
    Assert-FirstHomeDoorPlacement $h.NativePlacements @($h.Home.Entities|Where-Object Role -eq 'DOOR')[0] @($h.Home.Entities|Where-Object Role -eq 'DOORWAY')[0].NetId
    Assert-FirstHomeTcAuthorization $h.TcAuthorization $n.Actor.UserId $h.Home.BuildingId @($h.Home.Entities|Where-Object Role -eq 'TC')[0]
    Assert-FirstHomeStructure $h.Home;Assert-FirstHomeSite $h.Site
    if($paid.Count -ne 19 -or @($h.NativePlacements).Count -ne 8 -or @($h.NativePlacements|Where-Object {-not $_.Entity}).Count -or $h.PendingIntent){throw 'Incomplete native paid traversal fixture'}
    $u=$h.Upkeep;Assert-FirstHomeUpkeep $u
    if(-not $u.Authed -or -not $u.Privilege -or $u.MinutesAfter -lt 60 -or
        (Get-FirstHomeEconomicKey $last) -cne (Get-FirstHomeEconomicKey $u.Before) -or
        (Get-FirstHomeEconomicKey $u.Before) -cne (Get-FirstHomeEconomicKey @(@($u.After)+@($u.TcInventory))) -or
        (Get-FirstHomeEconomicKey $u.After) -cne (Get-FirstHomeEconomicKey $n.Inventory)){throw 'Traversal TC debit/auth/upkeep conservation unproven'}
}
function Assert-TraversalComponents($nav){
    $rows=@($nav.Traversal.Components);$frames=@($nav.Traversal.Frames|Where-Object Event -eq 'MOTION_WITNESS')
    # An initial route refusal has no actuation to witness. Its actual blocked
    # bodies still bind the inventory; this branch cannot prove traversal.
    if(-not $frames.Count -and $nav.Status -ne 'GREEN' -and $nav.Traversal.Completed -eq $false -and
        -not @($nav.Traversal.Scenes|Where-Object Status -eq 'PASSED').Count -and
        (Get-TraversalNumber $nav.Traversal.Actuations 'actuation count') -eq 0){
        $native=@($nav.Traversal.Frames|Where-Object {$_.Profile.NativeAdmissionPolicy -ceq 'NATIVE_CURRENT_ROUTE_V1'}).Count -gt 0
        $allowed=@('BLOCKED','FLOOR_ACQUISITION_OBSERVE','CLOCK_BASELINE')
        if($native){
            # A prechecked intent is not a writer call. Its explicit rejection
            # must validate before a zero-actuation result can use these rows.
            Assert-TraversalFrames $nav.Traversal.Frames $nav.Actor.NetId $nav.Traversal.World
            $allowed+=@('MOVE_DECISION','MOVE_REJECTED','OBSTACLE_PROBE','PHYSICAL_CONTACT')
        }
        $frames=@($nav.Traversal.Frames|Where-Object {$_.Event -in $allowed})
        if($frames.Count -ne @($nav.Traversal.Frames).Count){throw 'Zero-motion refusal contains unobserved native commands'}
        $configuration=$null
        foreach($f in $frames){
            $notIssued=$f.NativeResult -in @('NOT_ISSUED','STOPPED') -or ($f.Event -eq 'FLOOR_ACQUISITION_OBSERVE' -and $f.NativeResult -ceq 'STATIONARY_OBSERVATION')
            if($f.Event -eq 'CLOCK_BASELINE' -and $f.NativeResult -ceq 'CLOCK_BASELINE'){$notIssued=$true}
            if($native -and $f.Event -ceq 'MOVE_DECISION' -and $f.NativeResult -ceq 'PRECHECKED'){$notIssued=$true}
            if(-not $notIssued -or $f.UnobservedCommand -eq $true){throw 'Unobserved native command is not a zero-motion refusal'}
            Assert-TraversalBody $f $nav.Actor.NetId
            Assert-TraversalSamePoint $f.From $f.Actual 'blocked no-actuation origin'
            if(-not $native){Assert-TraversalSamePoint $f.Requested $f.Actual 'blocked no-actuation request'}
            Assert-TraversalSamePoint $frames[0].Actual $f.Actual 'blocked no-actuation continuity'
            $key=@($f.Body.Instance,$f.Body.RigidbodyInstance,$f.Body.Kinematic,$f.Body.Gravity,$f.Body.CollisionMode,$f.Body.Layer,$f.Body.DetectCollisions) -join '|'
            if($null -eq $configuration){$configuration=$key}elseif($configuration -cne $key){throw 'Native body changed during zero-motion refusal'}
        }
    }
    if($rows.Count -lt 4 -or @($rows.Instance|Select-Object -Unique).Count -ne $rows.Count -or -not $frames.Count){throw 'Missing full original runtime component inventory'}
    foreach($row in $rows){if((Get-TraversalNumber $row.Instance 'component instance') -eq 0 -or [string]::IsNullOrWhiteSpace([string]$row.Type)){throw 'Invalid runtime component inventory'}}
    $capsules=@($rows|Where-Object {$_.Type -match '(^|\.)CapsuleCollider$' -and $_.Collider.enabled -eq $true -and $_.Collider.isTrigger -eq $false})
    $rigid=@($rows|Where-Object {$_.Type -match '(^|\.)Rigidbody$' -and $_.Instance -eq $frames[0].Body.RigidbodyInstance});$navigator=@($rows|Where-Object {$_.Type -match '(^|\.)NPCPlayerNavigator$'})
    if($capsules.Count -ne 1 -or $rigid.Count -ne 1 -or $navigator.Count -ne 1 -or $navigator[0].Enabled -isnot [bool] -or $navigator[0].Enabled){throw 'Original capsule/Rigidbody or disabled native navigator unproven'}
    if($capsules[0].Collider.enabled -ne $true -or $capsules[0].Collider.isTrigger -ne $false){throw 'Runtime original capsule disabled or trigger'}
    Assert-TraversalSamePoint $capsules[0].Collider.Scale @(1,1,1) 'runtime capsule scale'
    if(@($rows|Where-Object {$null -ne $_.Collider -and $_.Collider.enabled -eq $true -and $_.Collider.isTrigger -eq $false -and $_.Instance -ne $capsules[0].Instance}).Count){throw 'Unmodelled active original body collider in runtime inventory'}
    foreach($f in $frames){if($f.Body.Instance -ne $capsules[0].Instance -or $f.Body.RigidbodyInstance -ne $rigid[0].Instance){throw 'Runtime body differs from full component inventory'}}
}
function Assert-TraversalCapturedClockSame($frameClock,$capture){
    if((Get-TraversalNumber $frameClock.Schema 'physical frame clock schema') -ne 2 -or $null -eq $capture){throw 'Missing physical frame/native captured clock'}
    $schema=$capture.PSObject.Properties['Schema']
    if($null -ne $schema -and (Get-TraversalNumber $schema.Value 'explicit capture schema') -ne 2){throw 'Unexpected explicit native capture schema'}
    # TraversalClock is a typed native snapshot without the ClockRow schema tag.
    # Add only the representation tag to a derived view; never alter raw clocks.
    $view=[ordered]@{Schema=2}
    foreach($key in @('WallTime','FixedTime','FixedUnscaledTime','Delta','UnscaledDelta','TimeScale','MaximumDelta','Sequence','Frame')){
        $view[$key]=Get-TraversalNumber $capture.$key ('captured native '+$key)
    }
    if($capture.InFixedStep -isnot [bool] -or $capture.PhysicsMode -isnot [string]){throw 'Missing native capture clock flags'}
    $view.InFixedStep=$capture.InFixedStep;$view.PhysicsMode=$capture.PhysicsMode
    Assert-TraversalClockSame $frameClock ([pscustomobject]$view)
}
function Assert-TraversalExactPoint($a,$b,[string]$name){
    Assert-TraversalVector $a;Assert-TraversalVector $b
    for($j=0;$j -lt 3;$j++){if($a[$j] -ne $b[$j]){throw ('Changed exact stationary '+$name)}}
}
function Assert-TraversalDestinationTerminal($n,$w){
    if($n.Status -ceq 'GREEN' -or $n.Traversal.Completed -eq $true){throw 'Terminal destination qualification cannot claim completed traversal'}
    $start=[double]$w.Contract.Start;$end=[double]$w.EndWall
    $forbidden=@('MOVE_DECISION','MOVE_ISSUED','MOTION_WITNESS','ARRIVED','REPATH','REPATH_AFTER_REST','ACTUAL_REST','BRAKE_ISSUED','BRAKE_WITNESSED','PROBE_CLEAR','PROBE_REFUSED')
    foreach($f in @($n.Traversal.Frames)){
        $wall=if($null -ne $f.Clock){$f.Clock.WallTime}else{$f.Time}
        if($null -ne $wall -and $wall -gt $start -and $f.Event -in $forbidden){throw 'Terminal destination qualification resumed physical/probe/success progress'}
    }
    foreach($a in @($n.FirstHome.NativePlacements)+@($n.FirstHome.Operations)+@($n.Traversal.FixtureTransitions)){
        if($null -ne $a -and $null -ne $a.Time -and $a.Time -gt $start+0.001){throw 'Terminal destination qualification advanced payment/build/fixture'}
    }
    if(@($n.Traversal.Scenes|Where-Object {$_.Status -in @('PASSED','BLOCKED') -and $_.EndTime -gt $start+0.001}).Count){throw 'Terminal destination qualification created a proven scene'}
    $stops=@($n.Traversal.Frames|Where-Object {$_.Event -ceq 'BLOCKED' -and $_.NativeResult -ceq 'STOPPED' -and $null -eq $_.Clock -and
        [single]$_.Time -ge [single]$end -and $_.UnobservedCommand -ne $true -and $null -eq $_.PendingDecision})
    if(-not $stops.Count){throw 'Terminal destination qualification lacks its actual unclocked no-writer stop'}
}
function Assert-TraversalDestinationWindows($n){
    $t=$n.Traversal
    if($t.SequencePolicy -ceq 'G4_PRIORITY_V1' -and $t.DestinationPolicy -cne 'STATIONARY_DESTINATION_WINDOW_V1'){throw 'G4 priority lacks stationary destination qualification'}
    if($t.DestinationPolicy -cne 'STATIONARY_DESTINATION_WINDOW_V1'){return}
    $native=$t.DestinationReadinessPolicy
    if($null -ne $native -and $native -cne 'NATIVE_NEW_GOAL_READINESS_V1'){throw 'Unknown native new-goal eligibility policy'}
    $windows=@($t.DestinationWindows);$frames=@($t.Frames);$bound=@{};$priorEnd=0.0
    if($windows.Count -gt 64){throw 'Unbounded destination qualifications'}
    if($windows.Count){
        $initial=@($n.Samples)[0]
        if($n.FirstHome.Schedule.SmokeSeconds -ne 900 -or [string]$initial.ActorNetId -cne [string]$n.Actor.NetId){throw 'Destination qualification lacks its original caller deadline anchor'}
        $originalGlobal=[double][single]([single](Get-TraversalNumber $initial.Time 'original spawn sample time')+[single]900)
    }
    for($index=0;$index -lt $windows.Count;$index++){
        $w=$windows[$index];$c=$w.Contract;$base=Get-TraversalNumber $w.BaseActuations 'qualification base actuation count'
        if(($native -ceq 'NATIVE_NEW_GOAL_READINESS_V1' -and $c.NativeReadinessPolicy -cne $native) -or ($null -eq $native -and $null -ne $c.NativeReadinessPolicy)){throw 'Destination eligibility policy was omitted/downgraded'}
        $start=Get-TraversalNumber $c.Start 'qualification immutable start';$end=Get-TraversalNumber $w.EndWall 'qualification terminal wall'
        $global=[double][single](Get-TraversalNumber $c.GlobalDeadline 'original global deadline');$maximum=$c.NativeMaximumDelta
        if($global -ne $originalGlobal){throw 'Destination qualification extended the original native caller deadline'}
        if($w.Id -ne $index+1 -or $base -lt 0 -or $base -ne [Math]::Floor($base) -or $start -lt $priorEnd -or $end -lt $start -or $global -lt $start -or
            $c.MaxSeconds -ne 20 -or $c.MinWindowSeconds -ne 2 -or $c.MaxSamples -ne 512 -or $c.BaseActuations -ne $base -or $c.IssuedCommands -ne $base -or $c.AcceptedWitnesses -ne $base -or
            $c.MotorActive -isnot [bool] -or $c.MotorActive -or $c.MotorBlocked -isnot [bool] -or $c.MotorBlocked -or $c.MotorArrived -isnot [bool] -or
            [string]::IsNullOrWhiteSpace([string]$w.Stage) -or $w.Stage -cne $c.Stage){throw 'Invalid/repeated/moving destination request'}
        $priorEnd=$end;Assert-TraversalExactPoint $c.Velocity @(0,0,0) 'request native velocity';Assert-TraversalExactPoint $w.Goal $c.Goal 'queued goal'
        if($w.Outcome -cne 'ADMITTED' -and $index -ne $windows.Count-1){throw 'Destination qualification resumed after a terminal refusal/cancellation'}
        foreach($advance in @($n.FirstHome.NativePlacements)+@($n.FirstHome.Operations)+@($t.FixtureTransitions)){
            if($null -ne $advance -and $null -ne $advance.Time -and $advance.Time -gt $start+0.001 -and $advance.Time -lt $end-0.001){throw 'Old Arrived advanced payment/build/fixture while a destination remained queued'}
        }
        if(($c.Body|ConvertTo-Json -Depth 15 -Compress) -cne ($t.WarmupContract.Body|ConvertTo-Json -Depth 15 -Compress) -or $maximum -ne $t.WarmupContract.NativeMaximumDelta){throw 'Qualification captured another original body/profile'}
        $before=@($frames|Where-Object {$null -ne $_.Clock -and $_.Clock.WallTime -le $start})
        $issued=@($before|Where-Object Event -ceq 'MOVE_ISSUED');$witnesses=@($before|Where-Object {$_.Event -ceq 'MOTION_WITNESS' -and $_.NativeResult -ceq 'OBSERVED'})
        if($issued.Count -ne $base -or $witnesses.Count -ne $base){throw 'Qualification began with a pending/unobserved native writer'}
        $life=@($before|Where-Object {$_.Event -in @('CLOCK_BASELINE','ARRIVED','BLOCKED')}|Select-Object -Last 1)
        if($life.Count -and $life[0].Event -cne 'ARRIVED'){throw 'Destination queued while prior controller session was active/blocked'}
        if($base -eq 0){
            if($null -ne $c.PriorRest -or $start -lt $t.Warmup.End){throw 'Initial queued route predates stationary startup'}
            Assert-TraversalExactPoint $c.Position $t.WarmupContract.Position 'initial queued original pose'
        }else{
            $rest=$witnesses[-1]
            if($c.MotorArrived -ne $true -or $rest.Speed -ne 0 -or $null -eq $c.PriorRest -or $c.PriorRest.Command -ne $rest.Command -or $c.PriorRest.Stage -cne $rest.Stage){throw 'Moving destination was qualified without observed rest'}
            Assert-TraversalExactPoint $c.Position $rest.Actual 'prior measured rest pose';Assert-TraversalExactPoint $c.PriorRest.Actual $rest.Actual 'referenced prior rest'
            Assert-TraversalExactPoint $rest.Body.Velocity @(0,0,0) 'prior witnessed native rest';Assert-TraversalExactPoint $c.PriorRest.NativeVelocity $rest.Body.Velocity 'referenced native rest'
            Assert-TraversalNear $c.PriorRest.Time $rest.Time 'prior measured rest time' 0.000001
            Assert-TraversalNear $c.PriorRest.Speed 0 'prior measured rest speed' 0
            Assert-TraversalClockSame $c.PriorRest.Clock $rest.Clock
        }
        $observations=@($w.Observations);$normalized=@();$fatal=$false
        if($w.ObservationCount -ne $observations.Count -or $observations.Count -gt 512){throw 'Qualification journal omitted native observations'}
        for($i=0;$i -lt $observations.Count;$i++){
            $o=$observations[$i];$bad=$false
            try{
                $wall=Get-TraversalNumber $o.ObservedWall 'independent qualification observation'
                Assert-TraversalExactPoint $o.Position $c.Position 'qualification pose';Assert-TraversalExactPoint $o.Velocity @(0,0,0) 'qualification native velocity'
                if($o.Observation -ne $i+1 -or $wall -lt $start -or $wall-$start -gt 20 -or $wall -gt $global -or $i -ge 511 -or
                    $o.MotorActuations -ne $base -or $o.MotorActive -isnot [bool] -or $o.MotorActive -or $o.MotorBlocked -isnot [bool] -or $o.MotorBlocked -or
                    ($o.Body|ConvertTo-Json -Depth 15 -Compress) -cne ($c.Body|ConvertTo-Json -Depth 15 -Compress)){$bad=$true}
            }catch{$bad=$true}
            if($bad){
                if($o.Outcome -cne 'FATAL' -or $w.Outcome -cne 'FATAL' -or $i -ne $observations.Count-1 -or $null -ne $w.Receipt -or $w.SetDestinationCalls -ne 0){throw 'Qualification ignored its body/motor/deadline violation'}
                $fatal=$true;break
            }
            if($o.Outcome -ceq 'FATAL'){throw 'Qualification declared an unexplained FATAL'}
            # Derived validator view only: never mutate the source observation.
            $copy=[ordered]@{};foreach($property in $o.PSObject.Properties){$copy[$property.Name]=$property.Value};$copy.MotorActuations=$o.MotorActuations-$base
            $normalized+=,[pscustomobject]$copy
        }
        if($normalized.Count){
            $view=[pscustomobject]@{WarmupPolicy='STATIONARY_CLOCK_WINDOW_V1';DestinationReadinessPolicy=$native;WarmupContract=$c;WarmupObservations=$normalized;WarmupObservationCount=$normalized.Count;
                Warmup=$w.Receipt;Frames=@();Actuations=0;Completed=$false;Scenes=@()}
            Assert-TraversalStationaryWindow $view $n.Actor.NetId
        }elseif($null -ne $w.Receipt){throw 'Empty qualification declared readiness'}
        if($w.Outcome -in @('FATAL','CANCELLED')){
            if(($w.Outcome -ceq 'FATAL' -and -not $fatal) -or $w.SetDestinationCalls -ne 0 -or $null -ne $w.Commit -or $null -ne $w.Handoff -or $null -ne $w.Receipt){throw 'Unready qualification invoked the motor'}
            if($observations.Count -and $end -lt $observations[-1].ObservedWall){throw 'Qualification terminal wall predates its last observation'}
            if($w.Outcome -ceq 'FATAL'){Assert-TraversalNear $end $observations[-1].ObservedWall 'actual fatal qualification wall' 0.000001}
            Assert-TraversalDestinationTerminal $n $w
            continue
        }
        if($w.Outcome -notin @('ADMITTED','MOTOR_REFUSED','REJECTED') -or $null -eq $w.Receipt -or $w.SetDestinationCalls -ne 1 -or
            $w.Commit.Accepted -isnot [bool] -or $w.Commit.StartedWall -lt $w.Receipt.End -or $w.Commit.CompletedWall -lt $w.Commit.StartedWall -or $w.Handoff.Accepted -isnot [bool]){throw 'Qualification committed early, replayed or omitted its native handoff'}
        $h=$w.Handoff;$ready=$w.Receipt.LastClock;$clock=$h.Clock
        $checked=Get-TraversalNumber $h.CheckedWall 'actual final handoff check wall'
        if($checked -lt $clock.WallTime -or $checked -lt $w.Commit.CompletedWall){throw 'Destination final check predates native handoff/Plan completion'}
        $tickDone=if($null -ne $h.TickCompletedWall){Get-TraversalNumber $h.TickCompletedWall 'actual baseline completion wall'}else{$null}
        if($null -ne $tickDone -and $tickDone -lt $checked){throw 'Destination baseline completed before its actual invocation'}
        Assert-TraversalNear $end $(if($null -ne $tickDone){$tickDone}else{$checked}) 'actual destination terminal wall' 0.000001
        if($w.Outcome -ceq 'REJECTED'){
            if($h.Accepted -ne $false -or $null -ne $tickDone){throw 'Rejected pre-baseline qualification actuated anyway'}
            Assert-TraversalDestinationTerminal $n $w
            continue
        }
        if($null -eq $tickDone -or $w.Commit.Accepted -ne $true -or $clock.WallTime -lt $w.Commit.CompletedWall -or $h.MotorActuations -ne $base){throw 'Missing or actuating destination baseline invocation'}
        if($w.Outcome -ceq 'ADMITTED' -and ($h.Accepted -ne $true -or $checked-$ready.WallTime -lt 0 -or $tickDone-$ready.WallTime -gt 0.1 -or
            $tickDone -gt $start+20 -or $tickDone -gt $global)){throw 'Stale/moving destination handoff admitted'}
        foreach($key in @('Sequence','Frame','FixedTime','FixedUnscaledTime','Delta','UnscaledDelta','TimeScale','MaximumDelta','InFixedStep','PhysicsMode')){
            if($clock.$key -cne $ready.$key -or $h.ReadyClock.$key -cne $ready.$key){throw 'Native fixed clock changed across same-callback handoff'}
        }
        if($h.ReadyClock.WallTime -ne $ready.WallTime){throw 'Handoff substituted the last qualified sample'}
        Assert-TraversalExactPoint $h.Position $c.Position 'handoff pose';Assert-TraversalExactPoint $h.Velocity @(0,0,0) 'handoff native rest'
        if(($h.Body|ConvertTo-Json -Depth 15 -Compress) -cne ($c.Body|ConvertTo-Json -Depth 15 -Compress)){throw 'Handoff changed original body'}
        $baseline=@($frames|Where-Object {$_.Event -ceq 'CLOCK_BASELINE' -and $_.Stage -ceq $w.Stage -and $_.Clock.Sequence -eq $clock.Sequence -and $_.Clock.WallTime -eq $clock.WallTime})
        if($w.Outcome -ceq 'MOTOR_REFUSED'){
            if($h.Accepted -ne $false){throw 'Refused baseline retained successful handoff credit'}
            if(-not @($frames|Where-Object {$_.Event -ceq 'BLOCKED' -and $_.Stage -ceq $w.Stage -and $_.Time -ge $clock.WallTime-0.001}).Count){throw 'Motor refusal lacks its actual stop'}
            Assert-TraversalDestinationTerminal $n $w
        }elseif($baseline.Count -ne 1){throw 'Ready destination lacks the actual same-callback C baseline'}
        if($baseline.Count){
            Assert-TraversalCapturedClockSame $baseline[0].Clock $clock
            if($w.Outcome -ceq 'ADMITTED'){
                $delay=Get-TraversalNumber $baseline[0].WallTelemetry.ReadDelay 'qualified baseline read delay'
                if($delay -lt 0 -or $clock.WallTime+$delay -gt $tickDone+0.000001 -or $clock.WallTime-$ready.WallTime+$delay -gt 0.100001){throw 'Fresh wall recapture hid an over-budget original callback'}
            }
            Assert-TraversalExactPoint $baseline[0].Actual $c.Position 'qualified C baseline pose';Assert-TraversalExactPoint $baseline[0].Navigation.RouteTo $w.Goal 'qualified native destination'
            $key=[string]$baseline[0].Clock.Sequence+'|'+[string]$baseline[0].Stage
            if($bound.ContainsKey($key)){throw 'Native baseline reused by two destination intents'};$bound[$key]=$true
        }
        if(@($frames|Where-Object {$_.Event -ceq 'MOVE_ISSUED' -and $_.Clock.WallTime -gt $start -and $_.Clock.WallTime -le $clock.WallTime}).Count){throw 'Queued qualification issued motion before handoff baseline'}
    }
    foreach($baseline in @($frames|Where-Object Event -ceq 'CLOCK_BASELINE')){
        $key=[string]$baseline.Clock.Sequence+'|'+[string]$baseline.Stage
        if(-not $bound.ContainsKey($key)){throw 'Motor route began without its own stationary qualification'}
    }
}
function Get-TraversalAdmissionAngle($a,$b){
    Assert-TraversalVector $a 4;Assert-TraversalVector $b 4;$dot=0.0;$aa=0.0;$bb=0.0
    for($j=0;$j -lt 4;$j++){$dot+=$a[$j]*$b[$j];$aa+=$a[$j]*$a[$j];$bb+=$b[$j]*$b[$j]}
    if([Math]::Abs($aa-1) -gt 0.001 -or [Math]::Abs($bb-1) -gt 0.001){throw 'Invalid foundation native quaternion'}
    2*[Math]::Acos([Math]::Min(1.0,[Math]::Abs($dot)/[Math]::Sqrt($aa*$bb)))*180/[Math]::PI
}
function Assert-TraversalFoundationAdmissionTerminal($n,$p){
    if($n.Status -notin @('PARTIAL','BLOCKED','FAILED') -or $n.Traversal.Completed -eq $true -or $n.FirstHome.Home -or $n.FirstHome.Upkeep -or $n.FirstHome.NavigationComplete -or $n.Traversal.Fixture -or @($n.Traversal.FixtureTransitions).Count){throw 'Failed foundation admission claimed home/G4/success progress'}
    $start=Get-TraversalNumber $p.StartedWall 'failed admission start';$end=Get-TraversalNumber $p.FailureTime 'failed admission end'
    if($end -lt $start -or [string]::IsNullOrWhiteSpace([string]$p.Reason) -or -not ([string]$n.Reason).EndsWith([string]$p.Reason,[StringComparison]::Ordinal)){throw 'Failed foundation admission lost its actual terminal reason/time'}
    foreach($f in @($n.Traversal.Frames)){
        $wall=if($null -ne $f.Clock){$f.Clock.WallTime}else{$f.Time}
        if($null -ne $wall -and $wall -gt $start -and $f.Event -cne 'BLOCKED'){throw 'Failed foundation admission resumed control/probe/success progress'}
    }
    foreach($w in @($n.Traversal.DestinationWindows)){if($w.Contract.Start -ge $start){throw 'Failed foundation admission queued a new goal'}}
    foreach($a in @($n.FirstHome.NativePlacements)+@($n.FirstHome.Operations)+@($n.Traversal.BuildPlans)){
        if($null -ne $a -and $null -ne $a.Time -and [single]$a.Time -gt [single]$end){throw 'Failed foundation admission advanced native build/payment/graph after failure'}
    }
    if(@($n.FirstHome.NativePlacements|Where-Object Role -cne 'FOUNDATION').Count -or @($n.FirstHome.PartialEntities|Where-Object Role -cne 'FOUNDATION').Count -or
        @($n.FirstHome.Operations|Where-Object {$_.Kind -match '^(BUILD_|UPGRADE_)' -and $_.Kind -notin @('BUILD_FOUNDATION','UPGRADE_FOUNDATION')}).Count){throw 'Failed foundation admission continued a later paid home role'}
    if(@($n.Traversal.Scenes|Where-Object {$_.Status -in @('PASSED','BLOCKED') -and $_.EndTime -gt $start}).Count){throw 'Failed foundation admission created a proven scene'}
    $stops=@($n.Traversal.Frames|Where-Object {$_.Event -ceq 'BLOCKED' -and $_.NativeResult -ceq 'STOPPED' -and $null -eq $_.Clock -and [single]$_.Time -ge [single]$end -and
        $_.UnobservedCommand -ne $true -and $_.WriterCalled -ne $true -and $null -eq $_.PendingDecision -and $_.Reason -ceq ('RESULT_'+$n.Status)})
    if($stops.Count -ne 1){throw 'Failed foundation admission lacks its actual sole unclocked no-writer stop'}
    # A refusal can be caused by changed native pose/body/velocity; this snapshot grants no rest credit.
    Assert-TraversalVector $stops[0].Body.Velocity
}
function Assert-TraversalFoundationOutput($n,$p){
    if(-not $p.Accepted){return} # A genuine postpay Twig/upgrade failure remains a terminal PARTIAL.
    $places=@($n.FirstHome.NativePlacements|Where-Object Role -ceq 'FOUNDATION')
    if($places.Count -ne 1 -or -not $places[0].Entity){throw 'Accepted foundation has no sole successful native output'}
    $place=$places[0];Assert-AvatarUid $place.Entity
    $rows=@($n.FirstHome.PartialEntities|Where-Object Role -ceq 'FOUNDATION');$built=$p.BuiltFoundation
    if($rows.Count -ne 1 -or $null -eq $built){throw 'Accepted foundation lacks actual/built native entity receipts'}
    $row=$rows[0]
    foreach($r in @($row,$built)){
        Assert-AvatarUid $r.NetId;Assert-AvatarUid $r.BuildingId
        if($r.Role -cne 'FOUNDATION' -or $r.NetId -cne $place.Entity -or $r.Type -cne 'BuildingBlock' -or
            $r.Prefab -cne 'assets/prefabs/building core/foundation/foundation.prefab' -or $r.Owner -cne [string]$n.Actor.UserId -or
            $r.Grade -cne 'Wood' -or $r.Saving -ne $true -or $r.Registered -ne $true -or $r.Grounded -ne $true -or
            (Get-TraversalNumber $r.Health 'accepted foundation health') -le 0){throw 'Accepted native output is not an owned Wood foundation'}
        if((Get-WorldDistance $r.Position $p.AcceptedSite.Position) -gt 0.05 -or (Get-TraversalAdmissionAngle $r.Rotation $p.AcceptedSite.Rotation) -gt 0.05){throw 'Accepted native foundation differs from admitted geometry'}
    }
    # Immediate HomeRow cache is diagnostic; only the final native row proves support.
    $initialStability=Get-TraversalNumber $built.Stability 'instant native stability cache'
    if($initialStability -lt 0 -or $built.Support -isnot [bool] -or $built.Support -ne ($initialStability -gt 0)){throw 'Instant native stability/support cache is inconsistent'}
    if($row.Support -isnot [bool] -or -not $row.Support -or (Get-TraversalNumber $row.Stability 'final native foundation stability') -le 0){throw 'Final accepted native foundation is unsupported'}
    foreach($key in @('NetId','Type','Prefab','Owner','BuildingId','Grade')){if($row.$key -cne $built.$key){throw 'Built and final foundation identity changed'}}
    $prior=$null;$priorTime=[single]$place.Time
    foreach($kind in @('BUILD_FOUNDATION','UPGRADE_FOUNDATION')){
        $ops=@($n.FirstHome.Operations|Where-Object Kind -ceq $kind)
        if($ops.Count -ne 1){throw ('Accepted foundation lacks exact paid '+$kind)}
        $op=$ops[0];$loaded=$n.FirstHome.GradeCosts.$kind
        if($op.EntityId -cne $place.Entity -or [string]$op.ActorNetId -cne [string]$n.Actor.NetId -or $null -ne $op.Output -or
            -not @($loaded).Count -or (Get-FirstHomeCostKey $op.Costs) -cne (Get-FirstHomeCostKey $loaded) -or
            [single](Get-TraversalNumber $op.Time 'foundation payment time') -lt $priorTime){throw 'Accepted foundation payment is not bound to native entity/actor/loaded costs/time'}
        Assert-FirstHomePayment $op
        if($null -ne $prior -and (Get-FirstHomeEconomicKey $prior) -cne (Get-FirstHomeEconomicKey $op.Before)){throw 'Foundation build/upgrade UID debit chain differs'}
        $prior=$op.After;$priorTime=[single]$op.Time
    }
}
# OFFLINE_ONLY receipt bindings; no synthetic query proves Unity support.
function Assert-TraversalFoundationRestPrefix($n,$p){
    $start=Get-TraversalNumber $p.StartedWall 'foundation prefix start';$gate=Get-TraversalNumber $p.GateTime 'foundation prefix gate'
    $prefix=@($n.Traversal.Frames|Where-Object {$wall=if($null -ne $_.Clock){$_.Clock.WallTime}else{$_.Time};$null -ne $wall -and $wall -le $gate})
    $witnesses=@($prefix|Where-Object {$_.Event -ceq 'MOTION_WITNESS' -and $_.NativeResult -ceq 'OBSERVED'})
    $issued=@($prefix|Where-Object Event -ceq 'MOVE_ISSUED')
    if(-not $witnesses.Count -or $issued.Count -ne $witnesses.Count){throw 'Foundation admission has an unwitnessed writer'}
    $rest=$witnesses[-1];$lastIssue=$issued[-1]
    if($rest.Command -ne $p.LastRestCommand -or $lastIssue.Command -ne $rest.Command -or $rest.Clock.WallTime -gt $start -or
        [string]$rest.Actor -cne [string]$n.Actor.NetId -or [string]$lastIssue.Actor -cne [string]$n.Actor.NetId){throw 'Foundation admission did not bind latest original-actor rest'}
    $state=@($prefix|Where-Object {$_.Event -in @('CLOCK_BASELINE','ARRIVED','BLOCKED')})
    if(-not $state.Count -or $state[-1].Event -cne 'ARRIVED' -or $state[-1].Command -ne $rest.Command -or $state[-1].Stage -cne 'HOME_SITE' -or
        [string]$state[-1].Actor -cne [string]$n.Actor.NetId){throw 'Foundation admission is not the latest arrived closed controller'}
    $afterRest=$false
    foreach($f in $prefix){
        if([object]::ReferenceEquals($f,$rest)){$afterRest=$true;continue}
        if($afterRest -and $f.Event -in @('MOVE_DECISION','MOVE_ISSUED','MOTION_WITNESS','CLOCK_BASELINE','REPATH')){throw 'Foundation admission resumed a writer after referenced rest'}
    }
    Assert-TraversalClockSame $state[-1].Clock $rest.Clock
    if(($p.LastRestSupport|ConvertTo-Json -Depth 15 -Compress) -cne ($rest.Support|ConvertTo-Json -Depth 15 -Compress)){throw 'Foundation admission support is not latest witness support'}
    $rest
}
function Assert-TraversalFoundationStandGeometry($s,$rest){
    Assert-TraversalVector $s.Position
    Assert-TraversalSamePoint $s.A @($s.Position[0],($s.Position[1]+0.5),$s.Position[2]) 'actual stand full lower capsule'
    Assert-TraversalSamePoint $s.B @($s.Position[0],($s.Position[1]+1.3),$s.Position[2]) 'actual stand full upper capsule'
    Assert-TraversalVector $s.NavPoint
    $prior=$rest.Support.Collider;$matched=$false
    foreach($h in @($s.RayHits)){
        Assert-TraversalVector $h.Point;Assert-TraversalVector $h.Normal
        $distance=Get-TraversalNumber $h.Distance 'actual vertical support distance'
        if($distance -lt 0 -or $distance -gt 8 -or [Math]::Abs((Get-TraversalDot $h.Normal $h.Normal)-1) -gt 0.002){throw 'Actual stand ray has invalid normal/distance'}
        Assert-TraversalSamePoint $h.Point @($s.Position[0],($s.Position[1]+4-$distance),$s.Position[2]) 'actual stand vertical support ray'
        $c=$h.Collider;Assert-TraversalVector $c.Center;Assert-TraversalVector $c.Extents
        if($c.enabled -isnot [bool] -or -not $c.enabled -or $c.isTrigger -isnot [bool] -or $c.isTrigger -or $c.Self -isnot [bool] -or $c.Self -or
            @($c.Extents|Where-Object {$_ -lt 0}).Count){throw 'Actual stand query used invalid/disabled/self/trigger collider'}
        if($c.Type -match '(^|\.)TerrainCollider$' -and $c.Instance -eq $prior.Instance -and $h.Normal[1] -ge 0.85 -and [Math]::Abs($h.Point[1]-$s.Position[1]) -le $s.SupportTolerance){
            if($c.Layer -ne $prior.Layer -or $prior.Enabled -ne $true -or $prior.Trigger -ne $false){throw 'Current terrain fingerprint changed'}
            Assert-TraversalSamePoint $c.Center $prior.BoundsCenter 'current terrain bounds center'
            Assert-TraversalVector $prior.BoundsSize
            Assert-TraversalSamePoint $c.Extents @(($prior.BoundsSize[0]/2),($prior.BoundsSize[1]/2),($prior.BoundsSize[2]/2)) 'current terrain bounds extents'
            $matched=$true
        }
    }
    if(-not $matched){throw 'Actual stand lacks current geometric binding to accepted support'}
}
function Assert-TraversalFoundationAdmission($n){
    $t=$n.Traversal;if($t.FoundationAdmissionPolicy -cne 'ACTUAL_FOUNDATION_READMISSION_V1'){return}
    $p=$t.FoundationAdmission;$placements=@($n.FirstHome.NativePlacements|Where-Object Role -ceq 'FOUNDATION')
    $paid=@($n.FirstHome.Operations|Where-Object {$_.Kind -in @('BUILD_FOUNDATION','UPGRADE_FOUNDATION')})
    if($null -eq $p){if($placements.Count -or $paid.Count -or @($n.FirstHome.PartialEntities).Count){throw 'Foundation paid without actual admission'};return}
    if($p.Policy -cne 'ACTUAL_FOUNDATION_READMISSION_V1' -or $p.Accepted -isnot [bool] -or $p.PrepayAccepted -isnot [bool]){throw 'Missing actual foundation gate protocol'}
    if(-not $p.Accepted){Assert-TraversalFoundationAdmissionTerminal $n $p}
    if(-not $p.PrepayAccepted){
        if($p.Accepted -or $placements.Count -or $paid.Count -or @($n.FirstHome.PartialEntities).Count -or $null -ne $p.NativeAttemptTime -or [string]::IsNullOrWhiteSpace([string]$p.Reason)){throw 'Failed foundation prepay gate nevertheless applied native output'}
        return
    }
    if($p.ReadmissionAccepted -ne $true -or $p.PreflightAccepted -ne $true -or $p.MeasuredRest -ne $true -or $p.ForeignUnchanged -ne $true -or $p.NavigationReady -ne $true -or
        $p.PreviewAccepted -ne $true -or $p.PositionMatched -ne $true -or $p.RotationMatched -ne $true -or $p.PaymentRayMatched -ne $true){throw 'Foundation bypassed full actual site/rest/geometry admission'}
    $start=Get-TraversalNumber $p.StartedWall 'foundation admission start';$gate=Get-TraversalNumber $p.GateTime 'foundation final prepay time'
    $globalDeadline=[single]([single]$n.Samples[0].Time+[single]$n.FirstHome.Schedule.SmokeSeconds)
    if($n.FirstHome.Schedule.SmokeSeconds -ne 900 -or $gate -lt $start -or $gate-$start -gt 0.5 -or $gate -gt $globalDeadline){throw 'Foundation admission exceeded original time budgets'}
    $attempt=$null
    if($null -ne $p.NativeAttemptTime){
        $attempt=Get-TraversalNumber $p.NativeAttemptTime 'native foundation attempt time'
        if($attempt -lt $gate -or $attempt -gt $globalDeadline){throw 'Foundation native attempt preceded actual gate or exceeded original deadline'}
        Assert-TraversalExactPoint $p.NativeAttemptTarget $p.PaymentTarget 'actual native attempt target'
    }elseif($p.Accepted -or $placements.Count -or $paid.Count){throw 'Actual foundation output has no native attempt stamp'}
    $rest=@(Assert-TraversalFoundationRestPrefix $n $p)
    if($rest.Count -ne 1 -or $rest[0].Speed -ne 0 -or $start -lt $rest[0].Time){throw 'Foundation admission began while moving/unwitnessed'}
    Assert-TraversalClockSame $p.LastRestClock $rest[0].Clock
    Assert-TraversalExactPoint $p.ActualPosition $rest[0].Actual 'foundation actual rest pose';Assert-TraversalExactPoint $p.NativeVelocity @(0,0,0) 'foundation native rest'
    Assert-TraversalExactPoint $rest[0].Body.Velocity @(0,0,0) 'foundation prior native zero'
    if(($p.Body|ConvertTo-Json -Depth 15 -Compress) -cne ($t.WarmupContract.Body|ConvertTo-Json -Depth 15 -Compress)){throw 'Foundation changed original native body'}
    $s=$p.ActualStand
    if($s.Sampled -ne $true -or $s.OnNavmesh -ne $true -or $s.Grounded -ne $true -or $s.Clear -ne $true -or @($s.Overlaps).Count -or $s.Mask -ne -1 -or $s.Triggers -cne 'Ignore' -or
        (Get-TraversalNumber $s.WaterDepth 'actual stand water') -gt 0.15){throw 'Actual foundation stand lacks current support/full capsule clearance'}
    Assert-TraversalExactPoint $s.Position $p.ActualPosition 'unsnapped actual stand';Assert-TraversalNear $s.Radius 0.5 'foundation original radius';Assert-TraversalNear $s.Height 1.8 'foundation original height'
    Assert-TraversalNear $s.SupportTolerance $rest[0].Profile.SupportTolerance 'unchanged stand support tolerance'
    Assert-TraversalFoundationStandGeometry $s $rest[0]
    $ground=@($s.RayHits|Where-Object {$_.Collider.Type -match '(^|\.)TerrainCollider$' -and $_.Collider.Instance -eq $rest[0].Support.Collider.Instance -and $_.Normal[1] -ge 0.85 -and [Math]::Abs($_.Point[1]-$s.Position[1]) -le $s.SupportTolerance})
    if(-not $ground.Count){throw 'Foundation current terrain differs from supported actual rest'}
    Assert-FirstHomeSite $p.AcceptedSite
    if(($p.AcceptedSite|ConvertTo-Json -Depth 15 -Compress) -cne ($n.FirstHome.Site|ConvertTo-Json -Depth 15 -Compress)){throw 'Foundation admission references another site'}
    $preview=$p.Preview
    if($preview.Accepted -ne $true -or $preview.ValidTarget -ne $true -or $preview.ValidPlacements -ne 1){throw 'Foundation native preview was not unique/valid'}
    Assert-TraversalExactPoint $preview.ActorPosition $p.ActualPosition 'preview uses actual actor'
    Assert-TraversalExactPoint $preview.Eyes $preview.RayOrigin 'native preview eyes/ray';Assert-TraversalExactPoint $preview.Eyes $p.PaymentEyes 'same successful preview eyes'
    Assert-TraversalExactPoint $preview.RayOrigin $p.PaymentRayOrigin 'same preview/payment ray origin';Assert-TraversalExactPoint $preview.RayDirection $p.PaymentRayDirection 'same preview/payment ray direction'
    Assert-TraversalExactPoint $preview.Target $p.PaymentTarget 'same preview/payment target';Assert-TraversalExactPoint $p.PaymentTarget $p.AcceptedSite.Position 'admitted native target'
    $direction=Get-HomeRelative $p.PaymentTarget $p.PaymentEyes;$length=Get-WorldDistance $direction @(0,0,0)
    if($length -le 0){throw 'Foundation ray has no actual direction'}
    Assert-TraversalSamePoint $p.PaymentRayDirection @(($direction[0]/$length),($direction[1]/$length),($direction[2]/$length)) 'actual eyes to foundation target'
    $distance=Get-WorldDistance $preview.Position $p.AcceptedSite.Position;$angle=Get-TraversalAdmissionAngle $preview.Rotation $p.AcceptedSite.Rotation
    if($distance -gt 0.05 -or $angle -gt 0.05 -or (Get-TraversalNumber $p.PositionDelta 'preview position delta') -gt 0.05 -or (Get-TraversalNumber $p.RotationDelta 'preview rotation delta') -gt 0.05){throw 'Foundation preview changed beyond original .05 bounds'}
    $from=Get-TraversalNumber $p.GraphFrom 'foundation graph first';$to=Get-TraversalNumber $p.GraphTo 'foundation graph end';$plans=@($t.BuildPlans)
    if($from -lt 0 -or $to -le $from -or $to -gt $plans.Count -or $from -ne [Math]::Floor($from) -or $to -ne [Math]::Floor($to)){throw 'Foundation has no bounded refreshed exterior graph'}
    foreach($g in @($plans[$from..($to-1)])){
        if($g.PredictedGeometry -ne $true -or $g.ActualGeometry -ne $false -or $g.Accepted -ne $true -or $g.Time -lt $start -or $g.Time -gt $gate){throw 'Foundation graph is stale/not a future actual-preview prediction'}
        Assert-TraversalSamePoint $g.FoundationPosition $preview.Position 'foundation predicted graph pose'
        if((Get-TraversalAdmissionAngle $g.FoundationRotation $preview.Rotation) -gt 0.05){throw 'Foundation graph retained old stand yaw'}
    }
    if($placements.Count -gt 1){throw 'Foundation paid native placement replayed'}
    foreach($place in $placements){
        if($place.NativeCall -cne 'Planner.DoBuild(Construction.Target,Construction)' -or [single]$place.Time -lt [single]$attempt){throw 'Foundation placement preceded its actual admitted native attempt'}
        Assert-TraversalExactPoint $place.Target $p.PaymentTarget 'paid native foundation target'
        if($place.Entity){
            $row=@($n.FirstHome.PartialEntities|Where-Object {$_.Role -ceq 'FOUNDATION' -and $_.NetId -ceq $place.Entity})
            if($row.Count -ne 1 -or $row[0].Owner -cne [string]$n.Actor.UserId -or $row[0].Saving -ne $true -or $row[0].Registered -ne $true){throw 'Actual paid foundation is not the owned registered native body'}
            if($p.Accepted -and ((Get-WorldDistance $row[0].Position $p.AcceptedSite.Position) -gt 0.05 -or (Get-TraversalAdmissionAngle $row[0].Rotation $p.AcceptedSite.Rotation) -gt 0.05 -or $p.BuiltMatched -ne $true)){throw 'Successful foundation differs from actual admitted preview'}
        }
    }
    foreach($op in $paid){if([single]$op.Time -lt [single]$attempt){throw 'Foundation payment preceded its actual native attempt'}}
    Assert-TraversalFoundationOutput $n $p
    if(-not $p.Accepted -and [string]::IsNullOrWhiteSpace([string]$p.Reason)){throw 'Postpay partial foundation lost its failure reason'}
}
function Assert-TraversalFixtureStandAttempts($n){
    $t=$n.Traversal;$policy=$t.FixtureStandPolicy
    if($null -ne $policy -and $policy -cne 'FULL_BODY_SELF_EXCLUDED_STANDS_V1'){throw 'Unknown fixture stand query policy'}
    if($policy -cne 'FULL_BODY_SELF_EXCLUDED_STANDS_V1'){return}
    $rows=@($t.FixtureStandAttempts);if($rows.Count -gt 9 -or ($t.Fixture -and -not $rows.Count)){throw 'Missing/unbounded actual fixture stand attempts'}
    if(-not $rows.Count){return}
    if([string]$n.Actor.NetId -cne [string]$t.WarmupContract.Body.Actor){throw 'Fixture self identity differs from original native actor'}
    $minimalRoles=@('FOUNDATION','WALL_N','DOORWAY','DOOR');$minimalKinds=@('BUILD_FOUNDATION','UPGRADE_FOUNDATION','BUILD_WALL_N','UPGRADE_WALL_N','BUILD_DOORWAY','UPGRADE_DOORWAY','BUILD_DOOR')
    $placements=@($n.FirstHome.NativePlacements|Where-Object {$_.Role -cin $minimalRoles});$payments=@($n.FirstHome.Operations|Where-Object {$_.Kind -cin $minimalKinds})
    if($placements.Count -ne 4 -or @($placements.Role|Sort-Object -Unique).Count -ne 4 -or $payments.Count -ne 7 -or @($payments.Kind|Sort-Object -Unique).Count -ne 7){throw 'Stand queries lack the four actually placed/paid minimal native roles'}
    $paidUntil=0.0;foreach($native in @($placements)+@($payments)){$at=Get-TraversalNumber $native.Time 'stand minimal native paid time';if($at -lt 0){throw 'Negative native fixture time'};$paidUntil=[Math]::Max($paidUntil,[single]$at)}
    $fixtureTime=if($t.Fixture){Get-TraversalNumber $t.Fixture.Time 'actual fixture readiness time'}else{$null}
    $bodyKey=$t.WarmupContract.Body|ConvertTo-Json -Depth 15 -Compress
    $basis=if($t.Fixture){$t.Fixture}else{@($t.BuildPlans|Where-Object {$_.ActualGeometry -and $_.Accepted})[-1]}
    if($null -eq $basis){throw 'Fixture stand lacks actual native foundation footprint'}
    $roles=@('WALL_N','DETOUR','DOORWAY');$role=0;$trial=0;$previous=0.0;$accepted=@{}
    foreach($a in $rows){
        if($accepted.ContainsKey($roles[$role])){$role++;$trial=0}
        if($role -ge 3 -or $a.Role -cne $roles[$role] -or $trial -ge 3){throw 'Fixture stand query roles/retries replayed'}
        Assert-TraversalNear $a.Offset @(1.3,1.5,1.1)[$trial] 'bounded fixture stand offset' 0.000001;$trial++
        $started=Get-TraversalNumber $a.StartedWall 'stand actual query start';$end=Get-TraversalNumber $a.CompletedWall 'stand actual query end'
        if($started -lt $previous -or $end -lt $started -or $a.Sampled -isnot [bool] -or $a.SampleAccepted -isnot [bool] -or $a.Accepted -isnot [bool] -or $a.Mask -ne -1 -or $a.Triggers -cne 'Ignore'){throw 'Unbound fixture stand query protocol'};$previous=$end
        if(($a.Body|ConvertTo-Json -Depth 15 -Compress) -cne $bodyKey){throw 'Fixture stand query changed the original native body'}
        Assert-TraversalVector $a.Input;Assert-TraversalVector $a.Edge
        if([single]$started -lt $paidUntil -or ($null -ne $fixtureTime -and [single]$end -gt [single]$fixtureTime)){throw 'Fixture stand query is outside actual minimal paid/ready native time'}
        Assert-TraversalSamePoint $a.SampleExtents @(0.25,0.5,0.25) 'fixture bounded native sample'
        Assert-TraversalVector $a.ActorPosition;Assert-TraversalVector $a.NativeVelocity
        foreach($field in @('FoundationPosition','ExteriorMin','ExteriorMax')){Assert-TraversalSamePoint $a.$field $basis.$field ('stand actual footprint '+$field)}
        Assert-TraversalVector $a.FoundationRotation 4;for($j=0;$j -lt 4;$j++){Assert-TraversalNear $a.FoundationRotation[$j] $basis.FoundationRotation[$j] 'stand actual foundation rotation'}
        if(-not $a.Sampled){if($a.Queries -ne 1 -or $a.Reason -cne 'NAV_SAMPLE' -or $a.SampleAccepted -or $a.Accepted -or $null -ne $a.Outside -or $null -ne $a.RayHits -or $null -ne $a.Support -or $null -ne $a.OverlapHits){throw 'Failed native stand sample granted a later gate'};continue}
        Assert-TraversalVector $a.NavPoint;Assert-TraversalSamePoint $a.RayOrigin @($a.NavPoint[0],($a.NavPoint[1]+2),$a.NavPoint[2]) 'stand terrain ray origin'
        $ground=@()
        foreach($hit in @($a.RayHits)){
            $c=$hit.Collider;Assert-TraversalVector $hit.Point;Assert-TraversalVector $hit.Normal;Assert-TraversalVector $c.Center;Assert-TraversalVector $c.Extents;$distance=Get-TraversalNumber $hit.Distance 'stand actual ray distance'
            if($c.Self -isnot [bool] -or $c.enabled -ne $true -or $c.isTrigger -ne $false -or $distance -lt 0 -or $distance -gt 4 -or @($c.Extents|Where-Object {$_ -lt 0}).Count -or $c.Self -ne ([string]$c.Entity -ceq [string]$n.Actor.NetId)){throw 'Fixture stand ray excluded another actor or fabricated a collider'}
            if([Math]::Abs((Get-TraversalDot $hit.Normal $hit.Normal)-1) -gt 0.002){throw 'Fixture stand ray normal is not a native unit vector'}
            Assert-TraversalSamePoint $hit.Point @($a.RayOrigin[0],($a.RayOrigin[1]-$distance),$a.RayOrigin[2]) 'stand actual vertical ray hit'
            if(-not $c.Self -and $c.Type -match '(^|\.)TerrainCollider$' -and $hit.Normal[1] -ge 0.85 -and [Math]::Abs($hit.Point[1]-$a.NavPoint[1]) -le 0.25){$ground+=,$hit}
        }
        if(-not $ground.Count){if($a.Queries -ne 2 -or $a.Reason -cne 'TERRAIN_SUPPORT' -or $a.SampleAccepted -or $a.Accepted -or $null -ne $a.Outside -or $null -ne $a.Support -or $null -ne $a.OverlapHits){throw 'Unsupported stand granted physical clearance'};continue}
        $support=@($ground|Sort-Object Distance)[0]
        if(($support|ConvertTo-Json -Depth 20 -Compress) -cne ($a.Support|ConvertTo-Json -Depth 20 -Compress)){throw 'Stand selected another ray/support collider'}
        Assert-TraversalSamePoint $a.Foot @($support.Point[0],($support.Point[1]+0.05),$support.Point[2]) 'stand supported foot'
        Assert-TraversalNear $a.Radius 0.5 'stand original full radius';Assert-TraversalNear $a.Height 1.8 'stand original full height'
        Assert-TraversalSamePoint $a.A @($a.Foot[0],($a.Foot[1]+0.5),$a.Foot[2]) 'stand original capsule A';Assert-TraversalSamePoint $a.B @($a.Foot[0],($a.Foot[1]+1.3),$a.Foot[2]) 'stand original capsule B'
        $water=Get-TraversalNumber $a.WaterDepth 'stand actual water depth'
        if($water -gt 0.15){if($a.Queries -ne 2 -or $a.Reason -cne 'WATER' -or $a.SampleAccepted -or $a.Accepted -or $null -ne $a.Outside -or $null -ne $a.OverlapHits -or $null -ne $a.OverlapClear){throw 'Water-unsafe stand granted capsule clearance'};continue}
        $clear=$true
        if('OverlapHits' -cnotin @($a.PSObject.Properties.Name)){throw 'Missing actual full-capsule query output'}
        foreach($c in @($a.OverlapHits)){
            Assert-TraversalVector $c.Center;Assert-TraversalVector $c.Extents
            if($c.Self -isnot [bool] -or $c.enabled -ne $true -or $c.isTrigger -ne $false -or @($c.Extents|Where-Object {$_ -lt 0}).Count -or $c.Self -ne ([string]$c.Entity -ceq [string]$n.Actor.NetId)){throw 'Stand overlap excluded another actor/entity'}
            if(-not $c.Self){$clear=$false}
        }
        if($a.Queries -ne 3 -or $a.OverlapClear -isnot [bool] -or $a.OverlapClear -ne $clear -or $a.SampleAccepted -ne $clear){throw 'Fixture stand omitted a full-body collision'}
        if(-not $clear){if($a.Reason -cne 'CAPSULE_OVERLAP' -or $a.Accepted -or $null -ne $a.Outside){throw 'Overlapping fixture stand granted exterior credit'};continue}
        $outside=$true;try{Assert-TraversalExteriorSegment $basis $a.Foot $a.Foot}catch{$outside=$false}
        $reason=if($outside){'ACCEPTED'}else{'FOUNDATION_EXTERIOR'}
        if($a.Outside -isnot [bool] -or $a.Outside -ne $outside -or $a.Accepted -ne $outside -or $a.Reason -cne $reason){throw 'Fixture stand bypassed original expanded foundation footprint'}
        if($outside){$accepted[$a.Role]=$a.Foot}
    }
    if($t.Fixture){
        foreach($binding in @(@('WALL_N','WallStand'),@('DETOUR','DetourGoal'),@('DOORWAY','DoorStand'))){
            if(-not $accepted.ContainsKey($binding[0])){throw 'Fixture exists without all three actual supported stands'}
            Assert-TraversalSamePoint $t.Fixture.($binding[1]) $accepted[$binding[0]] 'fixture uses admitted stand'
        }
    }
}
# OFFLINE_ONLY: native synchronous request-return is not tile/path/physical success.
function Assert-TraversalRebuildRest($s,$r,$n){
    if($null -eq $s){throw 'Missing native rebuild rest observation'}
    foreach($key in @('Active','Blocked','QueuedDestination','Navigating','Finished','PendingIntent')){if($s.$key -isnot [bool] -or $s.$key){throw 'Native rebuild crossed active/terminal/pending state'}}
    foreach($key in @('Arrived','HostActive')){if($s.$key -isnot [bool] -or -not $s.$key){throw 'Native rebuild lacks inactive actual arrival'}}
    $wall=Get-TraversalStationaryNativeDouble $s.Wall 'native rebuild rest time'
    if($s.Phase -cne $r.Phase -or $s.Step -ne $r.Step -or [single](Get-TraversalNumber $s.Wait 'rebuild wait') -ne [single]$r.Wait -or [single](Get-TraversalNumber $s.Deadline 'rebuild tile deadline') -ne [single]$r.Deadline -or [single](Get-TraversalNumber $s.GlobalDeadline 'rebuild global deadline') -ne [single]$r.GlobalDeadline){throw 'Native rebuild rebased phase/deadline/step'}
    foreach($key in @('NativeVelocity','MeasuredVelocity')){Assert-TraversalExactPoint $s.$key @(0,0,0) 'native rebuild exact rest'}
    if((Get-TraversalNumber $s.MeasuredSpeed 'rebuild measured speed') -ne 0){throw 'Native rebuild fabricated measured rest'}
    if(($s.Body|ConvertTo-Json -Depth 15 -Compress) -cne ($n.Traversal.WarmupContract.Body|ConvertTo-Json -Depth 15 -Compress)){throw 'Native rebuild changed original warmup body'}
    $rows=@($n.Traversal.Frames|Where-Object {$null -ne $_.Clock -and (Get-TraversalStationaryNativeDouble $_.Clock.WallTime 'rebuild prefix clock') -le $wall})
    $w=@($rows|Where-Object Event -ceq 'MOTION_WITNESS')[-1]
    if($null -eq $w -or $w.NativeResult -cne 'OBSERVED' -or (Get-TraversalNumber $w.Speed 'rebuild accepted rest speed') -ne 0 -or $s.Witness.Command -ne $w.Command -or $s.Witness.Stage -cne $w.Stage -or
        ($s.Witness.Clock|ConvertTo-Json -Depth 8 -Compress) -cne ($w.Clock|ConvertTo-Json -Depth 8 -Compress) -or ($s.Witness.Body|ConvertTo-Json -Depth 15 -Compress) -cne ($w.Body|ConvertTo-Json -Depth 15 -Compress)){throw 'Native rebuild rest is not latest actual witness'}
    Assert-TraversalBody $w $n.Actor.NetId
    $arrived=@($rows|Where-Object {$_.Event -ceq 'ARRIVED' -and $_.Command -eq $w.Command -and $_.Stage -ceq $w.Stage -and $_.MotionSession -eq $w.MotionSession -and $_.Speed -eq 0})
    if(-not $arrived.Count){throw 'Native rebuild lacks the actual inactive arrival event'}
    Assert-TraversalExactPoint $arrived[-1].Actual $w.Actual 'native rebuild actual arrival'
    Assert-TraversalExactPoint $s.Witness.Actual $w.Actual 'native rebuild witness pose'
    if((Get-TraversalNumber $s.Witness.Speed 'rebuild witness speed') -ne 0){throw 'Native rebuild changed historical witness speed'}
    foreach($key in @('Position','RigidbodyPosition')){Assert-TraversalExactPoint $s.Pose.$key $w.Body.$key 'native rebuild actual pose'}
    Assert-TraversalExactPoint $s.CapsulePosition $s.Pose.Position 'native rebuild original root capsule'
    foreach($q in @($s.Pose.Rotation,$s.CapsuleRotation)){Assert-TraversalVector $q 4;for($j=0;$j -lt 4;$j++){if($q[$j] -ne $w.Body.Rotation[$j]){throw 'Native rebuild rotated original body'}}}
    $issued=@($rows|Where-Object Event -ceq 'MOVE_ISSUED').Count;$accepted=@($rows|Where-Object Event -ceq 'MOTION_WITNESS').Count
    if($issued -ne $accepted -or $s.Issued -ne $issued -or $s.Accepted -ne $accepted -or $s.Actuations -ne $issued -or $s.Placements -ne $r.Step){throw 'Native rebuild has pending/orphan writer or paid counter'}
    $placements=@($n.FirstHome.NativePlacements|Where-Object {[single](Get-TraversalNumber $_.Time 'paid prefix time') -le [single]$wall})
    $ops=@();$timedSeen=$false;$initialCraftSeen=$false
    foreach($op in @($n.FirstHome.Operations)){
        if($op.Kind -ceq 'CRAFT_TOOL'){
            if($timedSeen -or $initialCraftSeen -or $null -ne $op.PSObject.Properties['Time']){throw 'Native rebuild moved or retimed the initial native craft'}
            Assert-FirstHomePayment $op
            if((Get-FirstHomeCostKey $op.Costs) -cne (Get-FirstHomeCostKey $n.Recipe.Ingredients)){throw 'Initial rebuild craft differs from loaded native recipe'}
            $initialCraftSeen=$true;$ops+=,$op
        }else{
            $timedSeen=$true
            $at=Get-TraversalNumber $op.Time 'operation prefix time'
            if([single]$at -le [single]$wall){$ops+=,$op}
        }
    }
    if($s.Placements -ne $placements.Count -or $s.Operations -ne $ops.Count){throw 'Native rebuild counters differ from actual paid prefix'}
    $native=$s.Native
    if($null -eq $native -or (Get-TraversalStationaryNativeDouble $native.StartedWall 'rebuild native start') -gt (Get-TraversalStationaryNativeDouble $native.CompletedWall 'rebuild native end') -or (Get-TraversalStationaryNativeDouble $native.CompletedWall 'rebuild native end') -gt $wall){throw 'Native rebuild native observation chronology changed'}
    foreach($key in @('NavAvailable','DefaultMesh','DefaultBuilt','OnNavmesh','Ready')){if($native.$key -isnot [bool]){throw 'Untyped native rebuild readiness observation'}}
    if(($native.NavAvailable -and $native.PendingTiles -isnot [bool]) -or (-not $native.NavAvailable -and $null -ne $native.PendingTiles)){throw 'Native rebuild invented pending observation'}
    $reason=if(-not $native.NavAvailable){'NATIVE_NAV_UNAVAILABLE'}elseif(-not $native.DefaultMesh){'NATIVE_DEFAULT_MESH_UNAVAILABLE'}elseif(-not $native.DefaultBuilt){'NATIVE_DEFAULT_NOT_BUILT'}elseif($native.PendingTiles -ne $false){'NATIVE_TILES_PENDING'}elseif(-not $native.OnNavmesh){'NATIVE_ACTOR_NOT_ON_NAVMESH'}else{$null}
    if($native.Ready -ne ($null -eq $reason) -or [string]$native.Reason -cne [string]$reason){throw 'Native rebuild observation invented readiness'}
}
function Assert-TraversalSynchronousRebuild($n){
    $tiles=@($n.FirstHome.Tiles);$seen=@{};$last=0.0;$order=@('FOUNDATION','WALL_N','DOORWAY','DOOR','TC','WALL_E','WALL_W','ROOF')
    foreach($r in $tiles){
        $new=$null -ne $r.Policy -or $null -ne $r.RequestedSync -or $null -ne $r.Called -or $null -ne $r.Returned -or $null -ne $r.Accepted -or $null -ne $r.Role -or $null -ne $r.Entity -or $null -ne $r.Phase -or $null -ne $r.StartedWall -or $null -ne $r.CallStartedWall -or $null -ne $r.CallCompletedWall -or $null -ne $r.CompletedWall -or $null -ne $r.Failure -or $null -ne $r.Owned -or ($null -ne $r.Before -and $r.Before -isnot [bool]) -or ($null -ne $r.After -and $r.After -isnot [bool])
        if(-not $new){continue}
        if($r.Policy -cne 'BENCH_SYNC_NATIVE_REQUEST_V1' -or $r.Event -cne 'REBUILD_REQUEST' -or $r.RequestedSync -ne $true -or $r.RequestedSync -isnot [bool] -or $n.Mode -cne 'BUILD_SMOKE' -or $n.FirstHome.DiagnosticOnly -ne $true -or $n.Persistence.Saved -ne $false -or $n.Persistence.Restored -ne $false){throw 'Unknown/downgraded native rebuild diagnostic policy'}
        foreach($key in @('Called','Returned','Accepted')){if($r.$key -isnot [bool]){throw 'Untyped native rebuild outcome'}}
        $tick=[single](Get-TraversalNumber $r.Time 'original build tick');$end=Get-TraversalStationaryNativeDouble $r.CompletedWall 'rebuild completion';$start=Get-TraversalStationaryNativeDouble $r.StartedWall 'rebuild start'
        $global=[single]([single](Get-TraversalNumber @($n.Samples)[0].Time 'original spawn time')+[single]900)
        if($n.FirstHome.Schedule.SmokeSeconds -ne 900 -or [string]@($n.Samples)[0].ActorNetId -cne [string]$n.Actor.NetId -or [single]$r.GlobalDeadline -ne $global -or [single](Get-TraversalNumber $r.Deadline 'original tile deadline') -ne [single]($tick+[single]30) -or
            [single]$start -lt $tick -or $end -lt $start -or $start -lt $last -or $r.Step -lt 1 -or $r.Step -gt 8 -or $seen.ContainsKey([string]$r.Step) -or $r.Role -cne $order[$r.Step-1]){throw 'Native rebuild changed original deadline/order'}
        $last=$end;$seen[[string]$r.Step]=$true
        if($r.Phase -notin @('BUILD_WAIT','FIXTURE','VERIFY') -or ($r.Phase -ceq 'BUILD_WAIT' -and [single](Get-TraversalNumber $r.Wait 'original minimum wait') -ne [single]($tick+[single]2)) -or -not @($n.FirstHome.Phases|Where-Object {$_.Phase -ceq 'BUILD' -and [single]$_.Time -eq $tick}).Count){throw 'Native rebuild lost original BUILD phase/minimum wait'}
        $place=@($n.FirstHome.NativePlacements|Where-Object Role -ceq $r.Role);$paid=@($n.FirstHome.Operations|Where-Object Kind -ceq ('BUILD_'+$r.Role))
        if($place.Count -ne 1 -or $paid.Count -ne 1 -or $place[0].Entity -cne $r.Entity -or $paid[0].EntityId -cne $r.Entity -or $place[0].NativeCall -cne 'Planner.DoBuild(Construction.Target,Construction)' -or [single]$place[0].Time -gt [single]$start -or [single]$paid[0].Time -gt [single]$start){throw 'Native rebuild is not bound to real native payment/entity'}
        if($r.Called){
            $call=Get-TraversalStationaryNativeDouble $r.CallStartedWall 'native request start'
            if($call -lt $start -or $call -gt $end -or $call -gt [double][single]$r.Deadline -or $call -gt [double]$global){throw 'Native rebuild called outside original bounds'}
            Assert-TraversalRebuildRest $r.Before $r $n
            if((Get-TraversalStationaryNativeDouble $r.Before.Wall 'entry rest time') -gt $call){throw 'Native rebuild entry occurred after request'}
            $owned=@($r.Owned);$ids=@{};$min=@([double]::PositiveInfinity,[double]::PositiveInfinity,[double]::PositiveInfinity);$max=@([double]::NegativeInfinity,[double]::NegativeInfinity,[double]::NegativeInfinity)
            if($owned.Count -ne $r.Step){throw 'Native rebuild omitted paid owned bounds'}
            foreach($o in $owned){$p=@($n.FirstHome.NativePlacements|Where-Object Role -ceq $o.Role);if($p.Count -ne 1 -or $p[0].Entity -cne $o.Entity -or $o.Owner -cne $n.Actor.UserId -or $o.Saving -ne $true -or $o.Registered -ne $true -or $ids.ContainsKey([string]$o.Role) -or [single]$p[0].Time -gt [single]$call){throw 'Native rebuild bounds include foreign/unpaid/duplicate entity'};$ids[[string]$o.Role]=$true;Assert-TraversalVector $o.Center;Assert-TraversalVector $o.Size
                for($j=0;$j -lt 3;$j++){if($o.Size[$j] -lt 0){throw 'Native rebuild negative owned bounds'};$min[$j]=[Math]::Min($min[$j],([double]$o.Center[$j]-[double]$o.Size[$j]/2));$max[$j]=[Math]::Max($max[$j],([double]$o.Center[$j]+[double]$o.Size[$j]/2))}}
            $center=@();$size=@();for($j=0;$j -lt 3;$j++){$center+=($min[$j]+$max[$j])/2;$size+=$max[$j]-$min[$j]}
            Assert-TraversalSamePoint $r.Center $center 'native rebuild actual owned bounds';Assert-TraversalSamePoint $r.Size $size 'native rebuild actual owned size'
        }elseif($r.Returned -or $null -ne $r.CallStartedWall -or $null -ne $r.CallCompletedWall){throw 'Native rebuild invented a native request'}
        if($r.Returned){$returned=Get-TraversalStationaryNativeDouble $r.CallCompletedWall 'native request return';if($returned -lt $call -or $returned -gt $end){throw 'Native rebuild return chronology changed'}}elseif($null -ne $r.CallCompletedWall){throw 'Native rebuild invented return time'}
        if($r.Accepted){
            if(-not $r.Called -or -not $r.Returned -or $null -ne $r.Failure -or $end -gt [double][single]$r.Deadline -or $end -gt [double]$global){throw 'Native rebuild accepted failed/late request'}
            Assert-TraversalRebuildRest $r.After $r $n
            if((Get-TraversalStationaryNativeDouble $r.After.Wall 'post rest time') -lt $returned -or (Get-TraversalStationaryNativeDouble $r.After.Wall 'post rest time') -gt $end -or $r.Before.Operations -ne $r.After.Operations){throw 'Native rebuild changed post-return chronology/counters'}
        }else{
            if($null -eq $r.Failure -or -not $r.Failure.Reason -or $r.Failure.Phase -notin @('ENTRY','NATIVE_REQUEST','POST_RETURN') -or (Get-TraversalStationaryNativeDouble $r.Failure.Time 'rebuild failure time') -ne $end -or $n.Status -ceq 'GREEN' -or $n.Traversal.Completed){throw 'Native rebuild refusal claimed success/unknown failure'}
            if(($r.Failure.Phase -ceq 'ENTRY' -and $r.Called) -or ($r.Failure.Phase -ceq 'NATIVE_REQUEST' -and (-not $r.Called -or $r.Returned)) -or ($r.Failure.Phase -ceq 'POST_RETURN' -and -not $r.Returned)){throw 'Native rebuild failure phase contradicted actual call'}
            if(-not @($n.Traversal.Frames|Where-Object {$_.Event -ceq 'BLOCKED' -and $_.NativeResult -ceq 'STOPPED' -and $null -eq $_.Clock -and $null -eq $_.PendingDecision -and $_.UnobservedCommand -ne $true -and [single]$_.Time -ge [single]$end}).Count){throw 'Native rebuild failure lacks actual terminal no-writer stop'}
            foreach($a in @($n.FirstHome.NativePlacements)+@($n.FirstHome.Operations)+@($n.FirstHome.Phases)+@($n.FirstHome.Navigation)+@($n.Traversal.FixtureTransitions)+@($n.Traversal.BuildRests)+@($n.Traversal.Fixture)+@($n.Traversal.Detour)){if($null -ne $a -and $null -ne $a.Time -and [single](Get-TraversalNumber $a.Time 'post rebuild native progress') -gt [single]$end){throw 'Native rebuild refusal advanced native progress'}}
            foreach($a in @($n.Traversal.BuildPlans)){if((Get-TraversalStationaryNativeDouble $a.Time 'post rebuild plan') -gt $end){throw 'Native rebuild refusal advanced build plan'}}
            foreach($w in @($n.Traversal.DestinationWindows)){if((Get-TraversalStationaryNativeDouble $w.Contract.Start 'post rebuild goal') -gt $end){throw 'Native rebuild refusal queued new destination'}}
            foreach($scene in @($n.Traversal.Scenes)){if($scene.Status -in @('PASSED','BLOCKED') -and (Get-TraversalNumber $scene.EndTime 'post rebuild scene') -gt $end){throw 'Native rebuild refusal granted scene credit'}}
        }
        foreach($f in @($n.Traversal.Frames)){
            if($f.Event -in @('BLOCKED')){continue};$time=if($null -ne $f.Clock){Get-TraversalStationaryNativeDouble $f.Clock.WallTime 'rebuild motion clock'}else{Get-TraversalNumber $f.Time 'rebuild motion time'}
            if($time -gt $start -and (($time -le $end) -or -not $r.Accepted)){throw 'Native rebuild overlapped/resumed physical progress'}
        }
        foreach($w in @($n.Traversal.DestinationWindows)){$time=Get-TraversalStationaryNativeDouble $w.Contract.Start 'rebuild queued goal';if($time -ge $start -and $time -le $end){throw 'Native rebuild overlapped new destination'}}
    }
}
function Assert-TraversalResult($nav){
    Assert-TraversalSynchronousRebuild $nav
    Assert-TraversalTerminalResult $nav
    Assert-TraversalLateRestResult $nav
    Assert-TraversalStationaryTerminalResult $nav
    if($nav.Traversal.WarmupPolicy -ceq 'STATIONARY_CLOCK_WINDOW_V1'){Assert-TraversalStationaryWindow $nav.Traversal $nav.Actor.NetId}
    Assert-TraversalDestinationWindows $nav
    if($nav.Traversal.ReadinessPolicy -ceq 'NATIVE_CURRENT_ROUTE_V1'){
        foreach($f in @($nav.Traversal.Frames|Where-Object Event -eq 'MOVE_DECISION')){
            if($f.Profile.NativeAdmissionPolicy -cne $nav.Traversal.ReadinessPolicy -or $f.Navigation.AdmissionPolicy -cne $nav.Traversal.ReadinessPolicy){throw 'Native readiness certificate policy missing from a new command'}
        }
    }
    if($nav.Status -eq 'GREEN' -or $nav.Traversal.Completed -eq $true -or @($nav.Traversal.Scenes|Where-Object Status -eq 'PASSED').Count){
        $motion=@($nav.Traversal.Frames|Where-Object {$_.Event -in @('MOVE_DECISION','MOTION_WITNESS')})
        if(-not $motion.Count -or @($motion|Where-Object {$_.Schema -ne 2 -or $null -eq $_.Clock}).Count){throw 'New physical traversal success requires the explicit native fixed-clock protocol'}
    }
    $keys=Get-EconomyWorldKeys $nav.Economy.World
    if($nav.Traversal.World -cne $keys.WorldKey -or $nav.Economy.WorldKey -cne $keys.WorldKey){throw 'Traversal world does not match native economy map/wipe identity'}
    Assert-TraversalSmokeBoundary $nav
    Assert-TraversalFoundationAdmission $nav
    Assert-TraversalBuildRoutes $nav
    Assert-TraversalFixtureStandAttempts $nav
    Assert-TraversalSceneResult $nav
    if($nav.Traversal.Completed -eq $true -or $nav.Status -eq 'GREEN' -or @($nav.Traversal.Components).Count){Assert-TraversalComponents $nav}
}
