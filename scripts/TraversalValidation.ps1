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
    if($Decision -and (-not $n.OnNavMesh -or ($n.PendingTiles -and -not $fresh) -or $n.PlannedMesh -cne $n.Mesh -or
        $n.PlannedTileChangeVersion -ne $n.TileChangeVersion -or $n.PlannedTileDataVersion -ne $n.TileDataVersion)){throw 'Native route epoch is stale before actuation'}
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
function Assert-TraversalFinalIssue($f,$intent,[int]$priorIssued,[switch]$Rejected){
    $g=$f.FinalAdmission;$a=$intent.Navigation.Admission
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
function Assert-TraversalWallTelemetry($f,$previous){
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
    if($gap -lt 0 -or $gap -gt $limit+0.000001 -or $delay -lt 0 -or $delay -gt $f.Profile.MaxTick+0.000001){throw 'Long wall stall or stale callback execution'}
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
function Assert-TraversalExteriorDetour($nav,$s,$w,$prior){
    $f=$nav.Traversal.Fixture;$p=$nav.Traversal.Detour
    if($f.Source -cne 'OWNED_NATIVE_TEST_FIXTURE' -or $p.Source -cne $f.Source -or $p.Status -cne 'PathComplete' -or
        [string]$p.Wall -cne [string]$f.Wall -or [string]$p.Door -cne [string]$f.Door){throw 'Detour lacks owned native fixture plan binding'}
    $entities=@($nav.FirstHome.Home.Entities);$foundation=@($entities|Where-Object Role -eq 'FOUNDATION');$door=@($entities|Where-Object Role -eq 'DOOR')
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
    $a=Get-HomeRelative $contact[0].Requested $contact[0].From;$b=Get-HomeRelative $p.Goal $p.Start;$al=Get-WorldDistance $a @(0,0,0)
    if($al -le 0 -or (Get-TraversalDot $a $b)/($al*$direct) -lt 0.99999){throw 'Direct refusal is not aimed along actual detour goal line'}
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
    $pending=$null;$pendingIssued=$false;$issuedCount=0;$lastWitness=$null;$baseline=$null;$lastTime=-1.0;$resolved=0;$heightWitnesses=@{};$heightRunKey='';$heightRun=0;$acquisition=$null;$ordinaryIssued=$false
    $activeClock=$null;$previousClock=$null;$clockStartWall=0.0;$clockBaselinePose=$null
    foreach($f in $frames){
        if($f.Schema -notin @(1,2) -or [string]$f.Actor -cne [string]$expectedActor -or [string]$f.World -cne [string]$expectedWorld -or
            [string]::IsNullOrWhiteSpace([string]$f.Stage)){throw 'Traversal actor/world/schema/stage mismatch'}
        $time=Get-TraversalNumber $f.Time 'time';$tick=Get-TraversalNumber $f.Tick 'tick';$command=Get-TraversalNumber $f.Command 'command'
        if($time -lt $lastTime-0.0001 -or $tick -lt 0 -or $tick -ne [Math]::Floor($tick) -or $command -lt 0 -or $command -ne [Math]::Floor($command)){throw 'Invalid traversal chronology'}
        $lastTime=$time
        if($f.Event -in @('PROBE_REFUSED','PROBE_CLEAR')){Assert-TraversalProbe $f $expectedActor}
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
            if($null -ne $f.Profile.MaxWallStall){Assert-TraversalWallTelemetry $f $previousClock}
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
            if($f.Event -ceq 'MOVE_REJECTED'){
                Assert-TraversalFinalIssue $f $pending $issuedCount -Rejected
                $pending=$null;$pendingIssued=$false;continue
            }
            Assert-TraversalFinalIssue $f $pending $issuedCount
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
        $modes=if($isAcquisition){@('FLOOR_ACQUISITION','ACQUISITION_BRAKE_HOLD')}else{@('SUPPORTED_ADVANCE','BRAKE_HOLD')}
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
function Assert-TraversalOutdoorOrder($scenes){
    $proven=@{};$end=0.0
    foreach($s in @($scenes)){
        $start=Get-TraversalNumber $s.StartTime 'ordered scene start';$next=Get-TraversalNumber $s.EndTime 'ordered scene end'
        if($start -lt $end-0.001 -or $next -lt $start){throw 'Outdoor scene order regressed'};$end=$next
        $required=if($s.Kind -eq 'SLOPE_DOWN'){@('OUTDOOR_STEP')}elseif($s.Kind -in @('SOLID_WALL','DOOR_CLOSED')){@('OUTDOOR_STEP','SLOPE_DOWN')}elseif($s.Kind -eq 'SAFE_DETOUR'){@('OUTDOOR_STEP','SLOPE_DOWN','SOLID_WALL','DOOR_CLOSED')}elseif($s.Kind -eq 'NATIVE_BUILDING_STEP'){@('OUTDOOR_STEP','SLOPE_DOWN','SOLID_WALL','DOOR_CLOSED','SAFE_DETOUR')}else{@()}
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
    if($t.Order -in @('OUTDOOR_FIRST','OWNED_NATIVE_TEST_FIXTURE')){Assert-TraversalOutdoorOrder $scenes}
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
        foreach($kind in @('OUTDOOR_STEP','SLOPE_DOWN','NATIVE_BUILDING_STEP','SOLID_WALL','DOOR_CLOSED')){if(-not $passed.ContainsKey($kind)){throw ('GREEN traversal lacks '+$kind)}}
        if($t.Order -in @('OUTDOOR_FIRST','OWNED_NATIVE_TEST_FIXTURE') -and -not $passed.ContainsKey('SAFE_DETOUR')){throw 'Outdoor-first completion lacks actual safe detour'}
        if($t.Order -ceq 'OWNED_NATIVE_TEST_FIXTURE' -and -not @($frames|Where-Object {$_.Stage -like 'HOME_*' -and $_.Event -eq 'MOTION_WITNESS' -and
            $_.Classification -eq 'SMALL_STEP_UP' -and ($_.Support.Kind -eq 'STEP_EDGE' -or $_.Landing.Kind -eq 'STEP_EDGE')}).Count){throw 'Complete fixture traversal lacks an actual discrete native step'}
        if($t.Completed -isnot [bool] -or -not $t.Completed -or $passed.OUTDOOR_STEP.Stage -eq $passed.NATIVE_BUILDING_STEP.Stage){throw 'GREEN traversal lacks separate outdoor/building contexts'}
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
    if(-not $complete -and -not $h.NavigationComplete -and -not $fixtureReady){
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
function Assert-TraversalResult($nav){
    if($nav.Traversal.WarmupPolicy -ceq 'STATIONARY_CLOCK_WINDOW_V1'){Assert-TraversalStationaryWindow $nav.Traversal $nav.Actor.NetId}
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
    Assert-TraversalSceneResult $nav
    if($nav.Traversal.Completed -eq $true -or $nav.Status -eq 'GREEN' -or @($nav.Traversal.Components).Count){Assert-TraversalComponents $nav}
}
