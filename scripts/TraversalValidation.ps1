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
    if($Decision -and (-not $n.OnNavMesh -or $n.PendingTiles -or $n.PlannedMesh -cne $n.Mesh -or
        $n.PlannedTileChangeVersion -ne $n.TileChangeVersion -or $n.PlannedTileDataVersion -ne $n.TileDataVersion)){throw 'Native route epoch is stale before actuation'}
    Assert-TraversalVector $n.RouteFrom;Assert-TraversalVector $n.RouteTo
    $corners=@($n.Corners);if($corners.Count -lt 2 -or $corners.Count -gt 4096){throw 'Missing/unbounded actual native path corners'}
    foreach($c in $corners){Assert-TraversalVector $c}
    if((Get-WorldDistance $corners[0] $n.RouteFrom) -gt 0.5 -or (Get-WorldDistance $corners[-1] $n.RouteTo) -gt 0.5){throw 'Native path corners are not bound to planned actual start/destination'}
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
                if($kind -eq 'DOOR_CLOSED' -and $hit.Collider.DoorOpen -is [bool] -and -not $hit.Collider.DoorOpen){$found=$true}
                if($kind -eq 'SOLID_WALL' -and $null -eq $hit.Collider.DoorOpen){$found=$true}
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
}
function Assert-TraversalNativeVelocity($body,$expected){
    Assert-TraversalVector $body.Velocity
    $error=Get-WorldDistance $body.Velocity $expected
    if($error -gt 0.001){throw 'Native Rigidbody velocity disagrees with physical fixed-step displacement'}
    return $error
}
function Assert-TraversalFrames($frames,$expectedActor,$expectedWorld){
    Assert-AvatarUid $expectedActor
    if([string]::IsNullOrWhiteSpace([string]$expectedWorld)){throw 'Missing traversal world binding'}
    $frames=@($frames);if(-not $frames.Count -or $frames.Count -gt 16384){throw 'Missing/unbounded traversal frames'}
    $pending=$null;$lastWitness=$null;$baseline=$null;$lastTime=-1.0;$resolved=0;$heightWitnesses=@{};$heightRunKey='';$heightRun=0;$acquisition=$null;$ordinaryIssued=$false
    $activeClock=$null;$previousClock=$null;$clockStartWall=0.0;$clockBaselinePose=$null
    foreach($f in $frames){
        if($f.Schema -notin @(1,2) -or [string]$f.Actor -cne [string]$expectedActor -or [string]$f.World -cne [string]$expectedWorld -or
            [string]::IsNullOrWhiteSpace([string]$f.Stage)){throw 'Traversal actor/world/schema/stage mismatch'}
        $time=Get-TraversalNumber $f.Time 'time';$tick=Get-TraversalNumber $f.Tick 'tick';$command=Get-TraversalNumber $f.Command 'command'
        if($time -lt $lastTime-0.0001 -or $tick -lt 0 -or $tick -ne [Math]::Floor($tick) -or $command -lt 0 -or $command -ne [Math]::Floor($command)){throw 'Invalid traversal chronology'}
        $lastTime=$time
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
                if($wallGap -lt 0 -or $wallGap -gt $f.Profile.MaxTick+0.000001){throw 'Native wall clock regressed or exceeded independent safety gap'}
                $previousClock=$activeClock;$activeClock=$f.Clock
            }
            Assert-TraversalClockSame $f.PreviousClock $previousClock
            Assert-TraversalNear $f.WallDt ($f.Clock.WallTime-$previousClock.WallTime) 'independent callback wall interval' 0.000001
            if($f.Clock.WallTime-$clockStartWall -gt 120){throw 'Native wall deadline exceeded'}
        }elseif($fixedProtocol -and $f.Event -in @('CLOCK_BASELINE','MOVE_DECISION','MOTION_WITNESS','FLOOR_ACQUISITION_OBSERVE','FLOOR_ACQUIRED','STEP_RESOLVED','ARRIVED','REPATH')){throw 'Physical proof is missing its explicit native fixed clock'}
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
                $plannedVelocity=@(for($j=0;$j -lt 3;$j++){($f.Requested[$j]-$f.From[$j])/$plannedDt})
                $prior=if($null -ne $lastWitness){@(for($j=0;$j -lt 3;$j++){($lastWitness.Actual[$j]-$lastWitness.From[$j])/$lastWitness.Dt})}else{@(0,0,0)}
                if($null -eq $lastWitness){Assert-TraversalSamePoint $f.From $clockBaselinePose 'initial fixed command baseline pose'}
                $null=Assert-TraversalNativeVelocity $f.Body $prior
                $plannedSpeed=Get-WorldDistance $plannedVelocity @(0,0,0);$plannedAcceleration=(Get-WorldDistance $plannedVelocity $prior)/$plannedDt
                Assert-TraversalNear $f.Distance (Get-WorldDistance $f.From $f.Requested) 'planned displacement';Assert-TraversalNear $f.Speed $plannedSpeed 'planned speed';Assert-TraversalNear $f.Acceleration $plannedAcceleration 'planned acceleration' 0.001
                if($plannedSpeed -gt $f.Profile.MaxSpeed+0.001 -or $plannedAcceleration -gt $f.Profile.MaxAcceleration+0.001){throw 'Unsafe planned physics speed/acceleration'}
            }
            $pending=$f;continue
        }
        if($null -eq $pending -or $command -ne $pending.Command -or $f.Stage -cne $pending.Stage -or $f.Classification -cne $pending.Classification -or $f.NativeResult -cne 'OBSERVED' -or
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
        $distance=Get-WorldDistance $f.From $f.Actual;$speed=$distance/$dt
        Assert-TraversalNear $f.Distance $distance 'actual displacement';Assert-TraversalNear $f.Speed $speed 'actual speed'
        $velocity=@(for($j=0;$j -lt 3;$j++){($f.Actual[$j]-$f.From[$j])/$dt})
        if($fixedProtocol){
            # Keep the independent physical .001 m/s gate. The reported native
            # error itself comes from Vector3 float arithmetic, whose inputs
            # must be restored after JSON parsed the short decimals as doubles.
            $null=Assert-TraversalNativeVelocity $f.Body $velocity
            $nativeVelocity=@(for($j=0;$j -lt 3;$j++){[single]([single]([single]$f.Actual[$j]-[single]$f.From[$j])/[single]$dt)})
            $nativeError=Get-WorldDistance $f.Body.Velocity $nativeVelocity
            if($nativeError -gt 0.001){throw 'Native float velocity error exceeds the unchanged physical limit'}
            if($f.NativeVelocityMatches -isnot [bool] -or -not $f.NativeVelocityMatches){throw 'Native physics velocity mismatch was not accepted'}
            Assert-TraversalNear $f.NativeVelocityError $nativeError 'native fixed-step velocity error' 0.000001
        }
        $priorVelocity=if($null -ne $lastWitness){@(for($j=0;$j -lt 3;$j++){($lastWitness.Actual[$j]-$lastWitness.From[$j])/$lastWitness.Dt})}else{@(0,0,0)}
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
        $lastWitness=$f;$pending=$null
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
function Assert-TraversalSceneResult($nav){
    $t=$nav.Traversal
    if($t.Schema -ne 1 -or $t.Mode -cne 'TRAVERSAL_BENCH' -or $nav.Status -notin @('GREEN','PARTIAL','BLOCKED','FAILED')){throw 'Missing traversal bench result'}
    if($t.Completed -isnot [bool]){throw 'Missing traversal completion state'}
    if(@($t.Frames).Count){Assert-AvatarActor $nav;Assert-TraversalFrames $t.Frames $nav.Actor.NetId $t.World}
    elseif($nav.Status -eq 'GREEN' -or $t.Completed -eq $true -or $t.Actuations -ne 0){throw 'Complete traversal has no native frames'}
    $frames=@($t.Frames);$scenes=@($t.Scenes);$passed=@{}
    $actuations=Get-TraversalNumber $t.Actuations 'actuation count'
    if($actuations -ne @($frames|Where-Object Event -eq 'MOTION_WITNESS').Count){throw 'Unobserved or unaccounted native actuation'}
    foreach($s in $scenes){
        $from=Get-TraversalNumber $s.FramesFrom 'scene first index';$to=Get-TraversalNumber $s.FramesTo 'scene exclusive end index'
        if($from -lt 0 -or $to -gt $frames.Count -or $to -lt $from -or ($to -eq $from -and $s.Status -ne 'NOT_PROVEN') -or $from -ne [Math]::Floor($from) -or $to -ne [Math]::Floor($to) -or
            $s.Kind -notin @('OUTDOOR_STEP','SLOPE_DOWN','NATIVE_BUILDING_STEP','SOLID_WALL','DOOR_CLOSED') -or $s.Status -notin @('PASSED','BLOCKED','NOT_PROVEN')){throw 'Invalid traversal scene boundary/status'}
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
            $blocked=@($slice|Where-Object {$_.Event -eq 'BLOCKED' -and $_.Classification -in @('SOLID_BLOCKED','DOOR_CLOSED')})
            if(-not $blocked.Count -or [string]::IsNullOrWhiteSpace([string]$s.Reason)){throw 'Wall/closed-door flag lacks actual blocking receipt'}
            $contact=@($slice|Where-Object Event -eq 'PHYSICAL_CONTACT')
            if(-not $contact.Count){throw 'Blocked scene lacks native collision measurement'}
            Assert-TraversalSamePoint $s.Start $s.End 'negative scene actual pose'
            foreach($c in $contact){
                if($c.Stage -cne $s.Stage){throw 'Negative contact belongs to another scene'}
                Assert-TraversalSamePoint $s.Start $c.Actual 'negative scene contact pose'
                Assert-TraversalBlockedContact $c $s.Kind $nav.Actor.NetId
            }
            $passed[$s.Kind]=$s
        }
    }
    if($nav.Status -eq 'GREEN' -or $t.Completed -eq $true){
        foreach($kind in @('OUTDOOR_STEP','SLOPE_DOWN','NATIVE_BUILDING_STEP','SOLID_WALL','DOOR_CLOSED')){if(-not $passed.ContainsKey($kind)){throw ('GREEN traversal lacks '+$kind)}}
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
    if(-not $complete -and -not $h.NavigationComplete){return}
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
        $frames=@($nav.Traversal.Frames|Where-Object {$_.Event -in @('BLOCKED','FLOOR_ACQUISITION_OBSERVE','CLOCK_BASELINE')})
        if($frames.Count -ne @($nav.Traversal.Frames).Count){throw 'Zero-motion refusal contains unobserved native commands'}
        $configuration=$null
        foreach($f in $frames){
            $notIssued=$f.NativeResult -in @('NOT_ISSUED','STOPPED') -or ($f.Event -eq 'FLOOR_ACQUISITION_OBSERVE' -and $f.NativeResult -ceq 'STATIONARY_OBSERVATION')
            if($f.Event -eq 'CLOCK_BASELINE' -and $f.NativeResult -ceq 'CLOCK_BASELINE'){$notIssued=$true}
            if(-not $notIssued -or $f.UnobservedCommand -eq $true){throw 'Unobserved native command is not a zero-motion refusal'}
            Assert-TraversalBody $f $nav.Actor.NetId
            Assert-TraversalSamePoint $f.From $f.Actual 'blocked no-actuation origin'
            Assert-TraversalSamePoint $f.Requested $f.Actual 'blocked no-actuation request'
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
