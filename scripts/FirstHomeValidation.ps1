#Requires -Version 5.1
. (Join-Path $PSScriptRoot 'EconomyValidation.ps1')
function Assert-FirstHomeApproach($a) {
    if(-not $a.Reason -or $a.Reason -notin @('ACCEPTED','NAV_SAMPLE','GROUND_TERRAIN','OWN_FOUNDATION_FLOOR','SLOPE','WATER','CAPSULE_FOREIGN','CAPSULE_OWN_STRUCTURE','PATH_PARTIAL','PENDING_TILES_TIMEOUT','PENDING_TILES','DOOR_LOS','DOOR_RANGE','PERMISSION','TIME_BUDGET')){throw 'Missing/unknown home approach subreason'}
    Assert-AvatarUid $a.ActorNetId
    foreach($field in @('Actor','Candidate')){if(@($a.$field).Count -ne 3){throw 'Missing approach coordinates'};foreach($v in $a.$field){$null=Get-AvatarNumber $v 'approach coordinate'}}
    if($a.Accepted -ne $true){if($a.Reason -eq 'ACCEPTED'){throw 'Rejected candidate labelled accepted'};return}
    if($a.Reason -ne 'ACCEPTED' -or $a.Sampled -ne $true -or $a.Pending -ne $false -or $a.OnNavmesh -ne $true -or
        $a.Surface -notin @('GROUND_TERRAIN','OWN_FOUNDATION_FLOOR') -or $a.CapsuleClear -ne $true -or
        $a.PathCalculated -ne $true -or $a.Path -ne 'PathComplete' -or $a.CanBuild -ne $true -or $a.Los -ne $true){throw 'Unproven physical/native complete approach'}
    foreach($field in @('NavPoint','Foot')){if(@($a.$field).Count -ne 3){throw 'Missing sampled position'};foreach($v in $a.$field){$null=Get-AvatarNumber $v 'sample coordinate'}}
    if([Math]::Abs((Get-AvatarNumber $a.SampleDelta 'nav floor delta')) -gt 0.25 -or
        (Get-AvatarNumber $a.NormalY 'floor normal') -lt 0.85 -or (Get-AvatarNumber $a.WaterDepth 'water depth') -gt 0.15 -or
        (Get-AvatarNumber $a.PathLength 'actual path length') -lt 0 -or
        (Get-AvatarNumber $a.Reach 'placement reach') -gt (Get-AvatarNumber $a.MaxReach 'native placement range')){throw 'Unsafe sampled floor/range/path'}
    if($a.Surface -eq 'OWN_FOUNDATION_FLOOR'){Assert-AvatarUid $a.SurfaceEntity}
    elseif([Math]::Abs((Get-AvatarNumber $a.TerrainDelta 'terrain floor delta')) -gt 0.1){throw 'Nonterrain support claimed as terrain'}
}
function Assert-FirstHomeDoorPlacement($placements,$door,[string]$doorway) {
    $rows=@($placements|Where-Object Role -eq 'DOOR')
    if($rows.Count -ne 1){throw 'Door must have exactly one paid native placement'}
    $p=$rows[0]
    if($p.NativeCall -cne 'Planner.DoBuild(Construction.Target,Construction)' -or $p.Entity -ne $door.NetId -or
        $door.Type -ne 'Door' -or $p.Parent -ne $doorway -or -not $p.Socket -or -not $p.Socket.EndsWith('/doorway-female/1') -or
        $door.Registered -ne $true -or $door.Saving -ne $true -or $door.Support -ne $true -or (Get-AvatarNumber $door.Health 'door health') -le 0){throw 'Fake/unbound native door'}
    Assert-FirstHomePayment ([pscustomobject]@{Before=$p.Before;After=$p.After;Costs=@([pscustomobject]@{Shortname='door.hinged.wood';Amount=1});Output=$null})
}
function Assert-FirstHomeUpkeep($u) {
    $minutes=Get-AvatarNumber $u.MinutesAfter 'native protection';$before=Get-AvatarNumber $u.MinutesBefore 'prior protection';$period=Get-AvatarNumber $u.Period 'native upkeep period'
    if($u.Authed -ne $true -or $u.Privilege -ne $true -or $u.DecayEnabled -ne $true -or $minutes -lt 60 -or $before -ne 0 -or $period -le 0 -or
        @($u.Transferred).Count -eq 0 -or @($u.NativeRate).Count -eq 0){throw 'Unpaid/insufficient native upkeep'}
    foreach($c in $u.NativeRate){if(-not $c.Shortname -or (Get-AvatarNumber $c.Amount 'native upkeep cost') -le 0){throw 'Unknown native upkeep cost'}}
    if((Get-FirstHomeEconomicKey $u.Before) -cne (Get-FirstHomeEconomicKey @(@($u.After)+@($u.TcInventory))) -or
        (Get-FirstHomeEconomicKey $u.Transferred) -cne (Get-FirstHomeEconomicKey $u.TcInventory)){throw 'Upkeep transfer lost/replaced/credited UID'}
}
function Assert-FirstHomeApproaches($h,[string]$actor) {
    $legacy=@($h.Approaches|Where-Object Label -eq 'LEGACY_COMPOSITE')
    foreach($a in $legacy) {
        if($a.Step -ne 7 -or $a.ActorNetId -ne $actor -or $a.Reason -notin @('NAV_SAMPLE','RAY_MISS','RAY_SAMPLE_HEIGHT','RAY_TERRAIN_HEIGHT','SLOPE','WATER','CAPSULE_OVERLAP','ACCEPTED') -or
            $a.Sampled -notin @($true,$false) -or $a.RayHit -notin @($true,$false) -or @($a.Actor).Count -ne 3 -or @($a.Input).Count -ne 3 -or
            ($a.Sampled -and @($a.NavPoint).Count -ne 3)){throw 'Missing/unbound legacy composite subreason'}
        foreach($v in @($a.Actor)+@($a.Input)+@($a.NavPoint)){$null=Get-AvatarNumber $v 'legacy coordinate'}
        $expected=if(-not $a.Sampled){'NAV_SAMPLE'}elseif(-not $a.RayHit){'RAY_MISS'}else{
            $delta=Get-AvatarNumber $a.SampleDelta 'legacy sample delta';$terrain=Get-AvatarNumber $a.TerrainDelta 'legacy terrain delta'
            if(@($a.Normal).Count -ne 3){throw 'Missing legacy ray normal'}
            $normal=Get-AvatarNumber $a.Normal[1] 'legacy normal';$water=Get-AvatarNumber $a.WaterDepth 'legacy water'
            if([Math]::Abs($delta) -gt 1){'RAY_SAMPLE_HEIGHT'}elseif([Math]::Abs($terrain) -gt 0.8){'RAY_TERRAIN_HEIGHT'}elseif($normal -lt 0.85){'SLOPE'}elseif($water -gt 0.15){'WATER'}elseif(@($a.Overlaps).Count){'CAPSULE_OVERLAP'}else{'ACCEPTED'}
        }
        if($a.Reason -ne $expected){throw 'Legacy reason contradicts measured subchecks'}
    }
    foreach($a in @($h.Approaches|Where-Object {$_.Label -ne 'LEGACY_COMPOSITE'})) {
        Assert-FirstHomeApproach $a
        if($a.ActorNetId -ne $actor){throw 'Approach belongs to a different actor'}
    }
    if($h.NavigationComplete -and @($h.Approaches|Where-Object {$_.Step -eq 7 -and $_.Accepted -eq $true}).Count -ne 1 -and -not $h.Restored){throw 'Door has no proven physical placement stand'}
    if($h.NavigationComplete -and -not $h.Restored -and $legacy.Count -ne 1){throw 'Completed smoke/journey has no unique legacy diagnosis'}
}
function Assert-FirstHomeTcAuthorization($a,[string]$actor,[string]$building,$tc) {
    Assert-AvatarUid $a.Actor
    Assert-AvatarUid $actor;Assert-AvatarUid $building
    $prior=@($a.BeforeAuthorized);$after=@($a.AfterAuthorized)
    $automatic=$prior.Count -eq 1 -and $prior[0] -eq $a.Actor
    if($a.Actor -ne $actor -or $a.BuildingId -ne $building -or $tc.Role -ne 'TC' -or $tc.Type -ne 'BuildingPrivlidge' -or
        $a.TcNetId -ne $tc.NetId -or $tc.Owner -ne $actor -or $tc.BuildingId -ne $building -or
        [uint64]$a.Actor -ge 10000000 -or $a.Owner -ne $a.Actor -or $prior.Count -gt 1 -or
        @($prior|Where-Object {$_ -ne $a.Actor}).Count -or $after.Count -ne 1 -or $after[0] -ne $a.Actor -or
        $a.InventoryCount -ne 0 -or $a.Registered -ne $true -or -not $a.BuildingId -or $a.BuildingId -ne $a.ExpectedBuildingId -or
        $a.Authed -ne $true -or $a.CanBuild -ne $true -or $a.NativeAutoauth -ne $automatic -or
        $a.NativeAddCalled -ne (-not $automatic) -or $a.AuthorizationHookAllowed -ne $true){throw 'TC native own authorization/empty inventory/structural binding not proven'}
}
function Assert-FirstHomeTcPlacement($placements) {
    $tc=@($placements|Where-Object Role -eq 'TC')
    if($tc.Count -ne 1){throw 'TC must have exactly one native paid placement'}
    $p=$tc[0];$d=$p.Diagnostic
    if($p.NativeCall -cne 'Planner.DoBuild(Construction.Target,Construction)' -or -not $p.Entity -or
        $d.OnTerrain -ne $true -or $null -ne $d.Socket -or -not $d.Parent -or $d.SurfaceParent -ne $d.Parent -or
        $d.MaleSockets -ne 1 -or $d.NativePreview -ne $true -or $d.NativeLos -ne $true -or
        $d.InsideObject -ne $false -or $d.DeployBlocked -ne $false -or $d.CanBuild -ne $true -or
        $d.HookDenied -ne $false -or $d.Unchanged -ne $true -or $d.LegacyUnchanged -ne $true -or
        (Get-AvatarNumber $d.Reach 'TC reach') -gt (Get-AvatarNumber $d.MaxReach 'TC native reach')){throw 'TC surface/native placement gates were not proven'}
    Assert-FirstHomePayment ([pscustomobject]@{Before=$p.Before;After=$p.After;Costs=@([pscustomobject]@{Shortname='cupboard.tool';Amount=1});Output=$null})
}
function Assert-FirstHomeToolSwitch($switch,[string]$rock,[string]$axe) {
    if($switch.FromUid -ne $axe -or $switch.ToUid -ne $rock -or $rock -eq $axe -or
        (Get-FirstHomeEconomicKey $switch.Before) -cne (Get-FirstHomeEconomicKey $switch.After)){throw 'Tool switch created/repaired/replaced inventory'}
    $from=@($switch.Before|Where-Object Uid -eq $axe);$to=@($switch.Before|Where-Object Uid -eq $rock)
    $wear=Get-AvatarNumber $switch.Wear 'loaded tool wear';$reserve=Get-AvatarNumber $switch.Reserve 'tool wear reserve'
    if($from.Count -ne 1 -or $to.Count -ne 1 -or $from[0].Shortname -ne 'stonehatchet' -or $to[0].Shortname -ne 'rock' -or
        $wear -le 0 -or $reserve -lt 1 -or $from[0].Condition -le 0 -or $from[0].Condition -gt ($wear+$reserve) -or $to[0].Condition -le ($wear+$reserve)){throw 'Broken/unknown/unusable tool switch'}
    $e=$switch.Equipment
    if($e.ActiveUid -ne $rock -or $e.ItemUid -ne $rock -or $e.HeldItemUid -ne $rock -or $e.HeldType -ne 'BaseMelee' -or $e.IsHeld -ne $true -or
        $e.OwnerNetId -ne $e.ActorNetId -or $e.HeldOwnerNetId -ne $e.ActorNetId -or $e.HeldParentNetId -ne $e.ActorNetId){throw 'Tool switch did not select exact owned native held rock'}
}
function Assert-FirstHomeGatherTool($op,$switch,[string]$expected,[string]$rock,[string]$axe,[string]$actor) {
    if($op.Harvest.ToolUid -eq $expected){return $expected}
    if($expected -ne $axe -or $op.Harvest.ToolUid -ne $rock -or $null -eq $switch){throw 'Unreceipted/repeated home tool transition'}
    Assert-FirstHomeToolSwitch $switch $rock $axe
    if($switch.Equipment.ActorNetId -ne $actor -or
        (Get-FirstHomeEconomicKey $switch.Before) -cne (Get-FirstHomeEconomicKey $op.Before)){throw 'Tool switch is not bound to actual actor/economic chain'}
    return $rock
}
function Assert-FirstHomeSite($site) {
    $range=Get-AvatarNumber $site.HeightRange 'footprint height range';$depth=Get-AvatarNumber $site.FoundationDepth 'foundation depth'
    $entry=Get-AvatarNumber $site.EntryDelta 'entrance height';$outside=Get-AvatarNumber $site.OutsideDelta 'approach height'
    if($depth -le 0 -or $range -lt 0 -or $range -gt $depth*0.5 -or [Math]::Abs($entry) -gt 0.25 -or [Math]::Abs($outside) -gt 0.25 -or
        $site.NativePreview -ne $true -or $site.Permission -ne $true -or $site.Path -ne 'PathComplete'){throw 'Unsafe/unpreviewed home foundation or entrance'}
    foreach($field in @('Water','Monument','Road','Foreign','Collision')){if($site.$field -ne $false){throw 'Excluded home site accepted'}}
    if($site.ForbiddenTopology -ne 16776578 -or ((Get-AvatarNumber $site.Topology 'topology') -band 16776578) -ne 0){throw 'Forbidden site topology'}
    if((Get-AvatarNumber $site.MonumentOriginDistance 'monument origin distance') -lt 120 -or
        (Get-AvatarNumber $site.MonumentBoundsDistance 'native monument bounds distance') -lt 6 -or
        (Get-AvatarNumber $site.ForeignDistance 'structural bounds distance') -lt 45 -or
        (Get-AvatarNumber $site.RoadDistance 'road segment distance') -lt 25 -or
        $site.PreventBuilding -ne $false -or $site.PrivilegeChecked -ne $true -or $site.PermissionCached -ne $false -or $null -ne $site.PrivilegeId){throw 'Missing/unsafe native site clearance or privilege witness'}
    $length=Get-AvatarNumber $site.PathLength 'site path length';$seconds=Get-AvatarNumber $site.TravelSeconds 'site travel bound'
    if($length -lt 0 -or $length -gt 800 -or $seconds -lt ($length/3+30) -or $seconds -gt 300){throw 'Site approach exceeds bounded physical travel'}
    $reserve=Get-AvatarNumber $site.PhaseReserve 'remaining home phase reserve';$remaining=Get-AvatarNumber $site.DeadlineRemaining 'remaining gameplay deadline'
    if($reserve -lt 120 -or $remaining -lt ($seconds+$reserve)){throw 'Site cannot fit remaining bounded gameplay'}
}
function Assert-FirstHomeStructure($shelter) {
    if($shelter.Placement -ne 'SERVER_ACCOUNTED_BUILD' -or $shelter.ForeignUnchanged -ne $true){throw 'Unknown placement or foreign mutation'}
    Assert-AvatarUid $shelter.Owner
    $owner=[uint64]$shelter.Owner
    Assert-AvatarUid $shelter.BuildingId
    if($owner -le 0 -or $owner -ge 10000000){throw 'Home owner is not an engine bot identity'}
    $roles=@('FOUNDATION','WALL_N','WALL_E','WALL_W','DOORWAY','ROOF','DOOR','TC')
    $rows=@($shelter.Entities)
    if($rows.Count -ne 8 -or @($rows.NetId|Select-Object -Unique).Count -ne 8 -or (@($rows.Role|Sort-Object) -join ',') -ne (@($roles|Sort-Object) -join ',')){throw 'Incomplete/duplicate home'}
    foreach($row in $rows){
        Assert-AvatarUid $row.NetId
        $expected=if($row.Role -eq 'DOOR'){'Door'}elseif($row.Role -eq 'TC'){'BuildingPrivlidge'}else{'BuildingBlock'}
        if($row.Type -ne $expected -or -not $row.Prefab -or $row.Owner -ne $shelter.Owner -or $row.BuildingId -ne $shelter.BuildingId -or
            $row.Saving -ne $true -or $row.Registered -ne $true -or $row.Support -ne $true -or (Get-AvatarNumber $row.Health 'home health') -le 0){throw 'Invalid native structure/owner/support/save registration'}
        if($expected -eq 'BuildingBlock' -and ($row.Grade -ne 'Wood' -or (Get-AvatarNumber $row.Links 'structural links') -lt 1)){throw 'Missing native structural connections or paid Wood grade'}
        foreach($shape in @(@('Position',3),@('Rotation',4))){
            if(@($row.($shape[0])).Count -ne $shape[1]){throw 'Missing native home geometry'}
            foreach($v in $row.($shape[0])){$null=Get-AvatarNumber $v 'home geometry'}
        }
    }
}
function Assert-FirstHomePayment($payment) {
    $before=@($payment.Before);$after=@($payment.After);$costs=@($payment.Costs)
    if(-not $costs.Count -or @($costs.Shortname|Select-Object -Unique).Count -ne $costs.Count){throw 'Missing/duplicate native costs'}
    foreach($rows in @($before,$after)){
        $seen=@{}
        foreach($row in $rows){
            Assert-AvatarUid $row.Uid;$amount=Get-AvatarNumber $row.Amount 'native amount'
            if(-not $row.Shortname -or $amount -le 0 -or $amount -ne [Math]::Floor($amount) -or $seen.ContainsKey([string]$row.Uid)){throw 'Invalid payment rows'}
            $seen[[string]$row.Uid]=$true
        }
    }
    foreach($cost in $costs){$amount=Get-AvatarNumber $cost.Amount 'cost';if(-not $cost.Shortname -or $amount -le 0 -or $amount -ne [Math]::Floor($amount)){throw 'Invalid loaded cost'}}
    $output=$payment.Output
    foreach($row in $after){
        $old=@($before|Where-Object Uid -eq $row.Uid)
        if($old.Count){if($old[0].Shortname -ne $row.Shortname -or $row.Amount -gt $old[0].Amount -or $old[0].Condition -ne $row.Condition -or $old[0].MaxCondition -ne $row.MaxCondition){throw 'Payment changed native identity/condition or credited an original UID'}}
        elseif($null -eq $output -or $row.Uid -ne $output.Uid -or $row.Shortname -ne $output.Shortname -or $row.Amount -ne $output.Amount){throw 'Unaccounted new payment output'}
    }
    if($null -ne $output){
        Assert-AvatarUid $output.Uid
        if(@($before|Where-Object Uid -eq $output.Uid).Count -or @($after|Where-Object Uid -eq $output.Uid).Count -ne 1){throw 'Output is not one fresh native UID'}
    }
    $names=@(@($before.Shortname)+@($after.Shortname)+@($costs.Shortname)|Sort-Object -Unique)
    foreach($name in $names){
        $b=[double](($before|Where-Object Shortname -eq $name|Measure-Object Amount -Sum).Sum)
        $a=[double](($after|Where-Object Shortname -eq $name|Measure-Object Amount -Sum).Sum)
        $c=[double](($costs|Where-Object Shortname -eq $name|Measure-Object Amount -Sum).Sum)
        $o=if($null -ne $output -and $output.Shortname -eq $name){[double]$output.Amount}else{0}
        if($b-$a+$o -ne $c){throw ('Exact native debit mismatch: '+$name)}
    }
}
function Assert-FirstHomeRestore($source,$restored) {
    Assert-FirstHomeStructure $source.Home;Assert-FirstHomeStructure $restored.Home
    if($source.WorldKey -cne $restored.WorldKey -or $source.ActorId -cne $restored.ActorId -or $source.InventorySHA256 -cne $restored.InventorySHA256){throw 'Home world/logical identity/inventory changed'}
    foreach($expected in $source.Home.Entities){
        $actual=@($restored.Home.Entities|Where-Object Role -eq $expected.Role)
        if($actual.Count -ne 1){throw 'Missing restored home element'}
        foreach($field in @('NetId','Type','Prefab','BuildingId','Grade')){if($expected.$field -cne $actual[0].$field){throw 'Home element was replaced'}}
        foreach($field in @('Position','Rotation')){for($i=0;$i -lt @($expected.$field).Count;$i++){
            if([Math]::Abs([double]$expected.$field[$i]-[double]$actual[0].$field[$i]) -gt 0.001){throw 'Restored home geometry changed'}
        }}
    }
}
function Get-FirstHomeEconomicKey($rows) {
    $seen=@{}
    (@(foreach($row in @($rows)){
        Assert-AvatarUid $row.Uid
        if($seen.ContainsKey([string]$row.Uid)){throw 'Duplicate home item UID'};$seen[[string]$row.Uid]=$true
        foreach($v in @($row.Amount,$row.Condition,$row.MaxCondition)){$null=Get-AvatarNumber $v 'home item'}
        if($row.Amount -le 0 -or $row.Condition -lt 0 -or $row.Condition -gt $row.MaxCondition){throw 'Invalid home item'}
        "$($row.Uid)|$($row.Shortname)|$($row.Amount)|$($row.Condition)|$($row.MaxCondition)"
    })|Sort-Object)-join "`n"
}
function Get-FirstHomeCostKey($costs) { (@($costs|ForEach-Object{"$($_.Shortname)|$($_.Amount)"})|Sort-Object)-join ',' }
function Get-HomeDot($a,$b){$value=0.0;for($i=0;$i -lt 3;$i++){$value+=[double]$a[$i]*[double]$b[$i]};$value}
function Get-HomeRelative($a,$b){@(for($i=0;$i -lt 3;$i++){[double]$a[$i]-[double]$b[$i]})}
function Get-HomeRotated($q,$p){
    $u=@([double]$q[0],[double]$q[1],[double]$q[2]);$w=[double]$q[3]
    $v=@(($u[1]*$p[2]-$u[2]*$p[1]),($u[2]*$p[0]-$u[0]*$p[2]),($u[0]*$p[1]-$u[1]*$p[0]))
    $c=@(($u[1]*$v[2]-$u[2]*$v[1]),($u[2]*$v[0]-$u[0]*$v[2]),($u[0]*$v[1]-$u[1]*$v[0]))
    @(for($i=0;$i -lt 3;$i++){[double]$p[$i]+2*($w*$v[$i]+$c[$i])})
}
function Assert-FirstHomePhysics($p,[switch]$RequireClear) {
    Assert-AvatarUid $p.ActorNetId
    if($p.Schema -ne 2 -or $p.Event -ne 'PHYSICS' -or $p.Radius -ne 0.5 -or $p.Height -ne 1.8 -or
        $p.Clear -notin @($true,$false) -or $p.LegacyClear -notin @($true,$false) -or
        @($p.Overlaps).Count -ne $p.OverlapCount){throw 'Missing actual capsule/overlap evidence'}
    foreach($field in @('Position','CapsuleA','CapsuleB')){
        if(@($p.$field).Count -ne 3){throw 'Missing physical capsule coordinates'}
        foreach($v in $p.$field){$null=Get-AvatarNumber $v 'capsule coordinate'}
    }
    foreach($shape in @(@('CapsuleA',0.5),@('CapsuleB',1.3))){
        $expected=@($p.Position[0],($p.Position[1]+$shape[1]),$p.Position[2])
        if((Get-WorldDistance $expected $p.($shape[0])) -gt 0.001){throw 'Shrunk/displaced proof capsule'}
    }
    $bodies=@($p.NativeCapsules)
    if(-not $bodies.Count -or @($bodies.Instance|Select-Object -Unique).Count -ne $bodies.Count){throw 'Missing native physical body'}
    foreach($body in $bodies){
        if($body.Instance -eq 0 -or $body.Radius -ne 0.5 -or [Math]::Abs((Get-AvatarNumber $body.Height 'native capsule height')-1.8) -gt 0.001 -or
            $body.Direction -ne 1 -or $body.Enabled -ne $true -or $body.Trigger -ne $false -or @($body.Scale).Count -ne 3){throw 'Unverified native/proof body dimensions'}
        foreach($v in $body.Scale){if([Math]::Abs((Get-AvatarNumber $v 'native body scale')-1) -gt 0.001){throw 'Rescaled native body'}}
        foreach($field in @('Center','A','B')){
            if(@($body.$field).Count -ne 3){throw 'Missing actual native capsule geometry'}
            foreach($v in $body.$field){$null=Get-AvatarNumber $v 'native capsule coordinate'}
        }
        if($body.Collider.Entity -ne $p.ActorNetId -or $body.Collider.Self -ne $true -or
            [Math]::Abs((Get-AvatarNumber $body.WorldRadius 'native world radius')-0.5) -gt 0.001 -or
            (Get-WorldDistance $body.A $p.CapsuleA) -gt 0.001 -or (Get-WorldDistance $body.B $p.CapsuleB) -gt 0.001){throw 'Native body is not bound to the actual proof capsule'}
    }
    $legacy=0;$seen=@{}
    foreach($o in @($p.Overlaps)){
        $c=$o.Collider
        if($c.Instance -eq 0 -or $seen.ContainsKey([string]$c.Instance) -or -not $c.Type -or -not $c.Name -or
            $null -eq $c.Layer -or $c.OwnerFlag -notin @('SELF','OWN','FOREIGN','NONE') -or
            $o.Category -notin @('NPC_SELF','TERRAIN','FOUNDATION','DOORWAY','DOOR_OPEN','DOOR_CLOSED','TC','WALL_N','WALL_E','WALL_W','ROOF','ENVIRONMENT','FOREIGN') -or
            $c.enabled -ne $true -or $c.isTrigger -ne $false){throw 'Missing/unknown collider identity or unsafe overlap set'}
        $seen[[string]$c.Instance]=$true
        foreach($field in @('Center','Extents')){
            if(@($c.$field).Count -ne 3){throw 'Missing collider bounds'}
            foreach($v in $c.$field){$null=Get-AvatarNumber $v 'collider bounds'}
        }
        $blocking=$o.Category -notin @('NPC_SELF','FOUNDATION')
        $decision=if($o.Category -eq 'NPC_SELF'){'SELF'}elseif($blocking){'BLOCKING_BODY_CONTACT'}else{'LEGACY_FOUNDATION_EXCLUSION'}
        if($o.LegacyBlocking -ne $blocking -or $o.Decision -ne $decision){throw 'Collider decision contradicts legacy guard'}
        if($blocking){$legacy++}
        if(@($o.Penetrations).Count -ne $bodies.Count){throw 'Missing actual native body penetration measurements'}
        foreach($m in @($o.Penetrations)){
            if($m.ActorCollider -notin $bodies.Instance -or $m.Intersects -notin @($true,$false) -or
                (Get-AvatarNumber $m.Distance 'native penetration') -lt 0 -or @($m.Direction).Count -ne 3){throw 'Invalid native penetration receipt'}
        }
        if($RequireClear -and ($blocking -or $o.Category -eq 'FOUNDATION')){throw 'Body overlap is not proven benign support'}
    }
    $expectedClear=if($null -ne $p.Sweep){@($p.Overlaps|Where-Object Category -ne NPC_SELF).Count -eq 0 -and @($p.Sweep.Hits|Where-Object {$_.Collider.Self -ne $true}).Count -eq 0}else{$p.LegacyClear}
    if($p.LegacyClear -ne ($legacy -eq 0) -or $p.Clear -ne $expectedClear){throw 'Clear contradicts actual overlapping/swept colliders'}
    if($RequireClear -and ($p.Clear -ne $true -or $p.Pending -ne $false -or $p.OnNavmesh -ne $true -or $p.Path -ne 'PathComplete' -or
        $p.Calculated -ne $true -or $p.CalculatedPath -ne 'PathComplete' -or
        ($p.Inside -and $p.OwnedFloor -ne $true))){throw 'Physical support/path not proven'}
    if($RequireClear -and $null -ne $p.Sweep -and @($p.Sweep.Hits|Where-Object {$_.Collider.Self -ne $true}).Count){throw 'Swept body crossed a solid obstacle'}
}
function Test-FirstHomePhysicalSupport($p) {
    $supported=@($p.FloorRays|Where-Object {$_.Collider.Self -ne $true -and
        ($_.Collider.Role -eq 'FOUNDATION' -and $_.Collider.Entity -eq $p.FoundationNetId -and $_.Collider.Own -eq $true -and $_.Collider.OwnerFlag -eq 'OWN' -or $_.Collider.Type -eq 'UnityEngine.TerrainCollider') -and
        $_.Normal[1] -ge 0.85 -and [Math]::Abs($_.FootDelta) -le 0.15}).Count -gt 0
    foreach($ray in $p.FloorRays){
        if(@($ray.Position).Count -ne 3 -or @($ray.Normal).Count -ne 3){throw 'Missing support ray geometry'}
        foreach($v in @($ray.Position)+@($ray.Normal)){$null=Get-AvatarNumber $v 'support ray'}
        $rayDistance=Get-AvatarNumber $ray.distance 'support ray distance'
        if([Math]::Abs(($p.Position[1]-$ray.Position[1])-(Get-AvatarNumber $ray.FootDelta 'actual foot delta')) -gt 0.0001 -or
            [Math]::Abs($ray.Position[0]-$p.Position[0]) -gt 0.0001 -or [Math]::Abs($ray.Position[2]-$p.Position[2]) -gt 0.0001 -or
            [Math]::Abs((Get-HomeDot $ray.Normal $ray.Normal)-1) -gt 0.001 -or $rayDistance -lt 0 -or $rayDistance -gt 0.6 -or
            [Math]::Abs($rayDistance-0.3-$ray.FootDelta) -gt 0.0001){throw 'Fabricated support ray pose/normal/distance'}
    }
    return $supported
}
function Assert-FirstHomeObservation($o) {
    $revision=if($null -eq $o.PolicyRevision){1}else{[int]$o.PolicyRevision}
    if($revision -notin @(1,2)){throw 'Unknown observation revision'}
    if($o.Mode -ne 'OBSERVE_CONTACT_ONLY' -or $o.DiagnosticOnly -ne $true -or
        [Math]::Abs($o.MaxSeconds-0.35) -gt 0.00001 -or [Math]::Abs($o.MaxDistance-0.3) -gt 0.00001 -or
        [Math]::Abs($o.MaxDepth-0.04) -gt 0.00001 -or [Math]::Abs($o.GrowthLimit-0.001) -gt 0.00001 -or
        [Math]::Abs($o.PersistenceSeconds-0.15) -gt 0.00001){throw 'Unknown diagnostic-only stop policy'}
    $frames=@($o.Frames);if(-not $frames.Count -or $frames.Count -gt 100){throw 'Unbounded/empty observation'}
    $travel=0.0;$priorDepth=0.0;$hadLip=$false;$start=$frames[0].Physics;$supportDepths=@{}
    for($i=0;$i -lt $frames.Count;$i++) {
        $f=$frames[$i];$p=$f.Physics;Assert-FirstHomePhysics $p
        if($f.Sequence -ne $i -or $f.Accepted -ne $false -or $p.ActorNetId -ne $start.ActorNetId){throw 'Diagnostic frame accepted or actor changed'}
        foreach($shape in @(@('Previous',3),@('Rotation',4),@('Velocity',3))){
            if(@($p.($shape[0])).Count -ne $shape[1]){throw 'Missing diagnostic pose/velocity/nav evidence'}
            foreach($v in $p.($shape[0])){$null=Get-AvatarNumber $v 'observation vector'}
        }
        if($p.NavSampled -eq $true){if(@($p.NavPosition).Count -ne 3){throw 'Missing actual nav position'};foreach($v in $p.NavPosition){$null=Get-AvatarNumber $v 'native sample'}}
        $prior=if($i){$frames[$i-1].Physics}else{$p}
        $dt=(Get-AvatarNumber $p.Time 'observation time')-(Get-AvatarNumber $prior.Time 'prior observation time')
        $elapsed=$p.Time-$start.Time;$step=Get-WorldDistance $prior.Position $p.Position;$travel+=$step
        if($i -and ($dt -le 0 -or (Get-WorldDistance $prior.Position $p.Previous) -gt 0.0001 -or [Math]::Abs($prior.Time-$p.PosePreviousTime) -gt 0.0001)){throw 'Broken observation continuity'}
        if((Get-WorldDistance $p.Sweep.From $p.Previous) -gt 0.0001 -or (Get-WorldDistance $p.Sweep.To $p.Position) -gt 0.0001 -or
            [Math]::Abs((Get-WorldDistance $p.Previous $p.Position)-(Get-AvatarNumber $p.Sweep.Distance 'native sweep distance')) -gt 0.0001){throw 'False/missing swept trajectory'}
        $depth=0.0;$lip=$false;$bad=$false;$supportGrowth=$false;$depthBound=$false;$entryHeight=$null
        if($revision -eq 2){
            $expectedOrigin=@(for($j=0;$j -lt 3;$j++){$p.Position[$j]+0.6*$p.Portal.Normal[$j]+$(if($j -eq 1){0.6}else{0})})
            if(@($p.EntryFloor.Origin).Count -ne 3 -or (Get-WorldDistance $expectedOrigin $p.EntryFloor.Origin) -gt 0.0001 -or [Math]::Abs($p.EntryFloor.Length-1.2) -gt 0.0001){throw 'Missing/unbound forward floor probe'}
            foreach($ray in @($p.EntryFloor.Rays)){
                if(@($ray.Position).Count -ne 3 -or @($ray.Normal).Count -ne 3){throw 'Missing forward ray geometry'}
                foreach($v in @($ray.Position)+@($ray.Normal)){$null=Get-AvatarNumber $v 'forward floor ray'}
                $distance=Get-AvatarNumber $ray.distance 'forward floor distance'
                if($distance -lt 0 -or $distance -gt 1.2 -or [Math]::Abs($distance-$expectedOrigin[1]+$ray.Position[1]) -gt 0.0001 -or
                    [Math]::Abs($ray.Position[0]-$expectedOrigin[0]) -gt 0.0001 -or [Math]::Abs($ray.Position[2]-$expectedOrigin[2]) -gt 0.0001 -or
                    [Math]::Abs((Get-HomeDot $ray.Normal $ray.Normal)-1) -gt 0.001 -or [Math]::Abs($ray.FootDelta-$p.Position[1]+$ray.Position[1]) -gt 0.0001){throw 'Fabricated forward floor geometry'}
                if($null -eq $entryHeight -and $ray.Collider.Entity -eq $p.FoundationNetId -and $ray.Collider.Own -eq $true -and $ray.Collider.Role -eq 'FOUNDATION' -and $ray.Collider.OwnerFlag -eq 'OWN' -and $ray.Normal[1] -ge 0.85){$entryHeight=$ray.Position[1]}
            }
        }
        foreach($contact in @($p.Overlaps|Where-Object Category -ne NPC_SELF)) {
            if($contact.Category -notin @('FOUNDATION','DOORWAY')){$bad=$true;continue}
            if($contact.Collider.OwnerFlag -ne 'OWN'){$bad=$true}
            foreach($m in $contact.Penetrations) {
                foreach($v in $m.Direction){$null=Get-AvatarNumber $v 'penetration direction'}
                $low=$revision -eq 2 -and $contact.Category -eq 'DOORWAY' -and $null -ne $entryHeight -and $m.Direction[1] -ge 0.1 -and
                    [Math]::Abs((Get-HomeDot $m.Direction $p.Portal.Right)) -le 0.05 -and [Math]::Abs($p.Position[1]+0.5-$m.Direction[1]*(0.5-$m.Distance)-$entryHeight) -le 0.06
                $directionOk=if($revision -eq 2 -and $contact.Category -eq 'DOORWAY'){$low}else{$m.Direction[1] -ge 0.85}
                if($m.Intersects -ne $true -or $m.Error -or -not $directionOk -or ($revision -eq 1 -and $m.Distance -gt $o.MaxDepth)){$bad=$true}
                if($m.Distance -gt $o.MaxDepth){$depthBound=$true}
                if($contact.Category -eq 'DOORWAY'){$lip=$true;$depth=[Math]::Max($depth,$m.Distance)}
                if($contact.Category -eq 'FOUNDATION'){
                    $key=[string]$contact.Collider.Instance
                    if($supportDepths.ContainsKey($key) -and $m.Distance -gt $supportDepths[$key]+$o.GrowthLimit){$supportGrowth=$true}
                    $supportDepths[$key]=if($supportDepths.ContainsKey($key)){[Math]::Min($supportDepths[$key],$m.Distance)}else{$m.Distance}
                }
            }
        }
        $supported=Test-FirstHomePhysicalSupport $p
        $swept=@($p.Sweep.Hits|Where-Object {$_.Collider.Self -ne $true -and -not
            ($_.Collider.Role -in @('DOORWAY','FOUNDATION') -and $_.Collider.Instance -in @($p.Overlaps.Collider.Instance) -and
                (@($_.InitialPenetrations|Where-Object Intersects -eq $true).Count -or
                    ($revision -eq 2 -and $_.Collider.Role -eq 'DOORWAY' -and $null -ne $entryHeight -and $_.Normal[1] -ge 0.1 -and [Math]::Abs((Get-HomeDot $_.Normal $p.Portal.Right)) -le 0.05 -and [Math]::Abs($_.Position[1]-$entryHeight) -le 0.06) -or
                    (($revision -eq 1 -or $_.Collider.Role -eq 'FOUNDATION') -and $_.Normal[1] -ge 0.85 -and $_.Position[1] -le $p.Position[1]+0.05 -and $_.Position[1] -ge $p.Position[1]-0.05)))}).Count -gt 0
        foreach($hit in @($p.Sweep.Hits|Where-Object {$_.Collider.Role -in @('DOORWAY','FOUNDATION') -and @($_.InitialPenetrations).Count})) {
            if(@($hit.InitialPenetrations).Count -ne @($p.NativeCapsules).Count){throw 'Missing swept initial-pose native body queries'}
            foreach($m in $hit.InitialPenetrations) {
                $body=@($p.NativeCapsules|Where-Object Instance -eq $m.ActorCollider)
                if($body.Count -ne 1 -or $m.Error -or $m.Intersects -notin @($true,$false) -or @($m.Direction).Count -ne 3 -or
                    @($m.QueryPosition).Count -ne 3 -or @($m.QueryRotation).Count -ne 4 -or @($body[0].Collider.Position).Count -ne 3 -or @($body[0].Collider.Rotation).Count -ne 4 -or
                    (Get-AvatarNumber $m.Distance 'initial native penetration') -lt 0){throw 'Fabricated initial-overlap exception'}
                foreach($v in @($m.Direction)+@($m.QueryPosition)+@($m.QueryRotation)){$null=Get-AvatarNumber $v 'initial-pose query'}
                $expected=@(for($j=0;$j -lt 3;$j++){$body[0].Collider.Position[$j]+$p.Previous[$j]-$p.Position[$j]})
                if((Get-WorldDistance $expected $m.QueryPosition) -gt 0.0001 -or
                    @((0..3)|Where-Object {[Math]::Abs($m.QueryRotation[$_]-$body[0].Collider.Rotation[$_]) -gt 0.0001}).Count -or
                    $m.Intersects -and [Math]::Abs((Get-HomeDot $m.Direction $m.Direction)-1) -gt 0.001){throw 'Initial-overlap query not bound to measured prior capsule pose'}
            }
        }
        $portal=$p.Portal;$bodyCenter=@($p.Position[0],($p.Position[1]+0.9),$p.Position[2]);$relative=Get-HomeRelative $bodyCenter $portal.Center
        $fits=[Math]::Abs((Get-HomeDot $relative $portal.Right))+0.5 -le $portal.HalfWidth -and [Math]::Abs((Get-HomeDot $relative $portal.Up))+0.9 -le $portal.HalfHeight
        if($revision -eq 2){
            $slabs=@($p.DoorwayColliders);$fits=$slabs.Count -gt 0
            foreach($c in $slabs){
                if($c.Role -ne 'DOORWAY' -or $c.Own -ne $true -or $c.OwnerFlag -ne 'OWN' -or @($c.Mesh.Center).Count -ne 3 -or @($c.Mesh.Extents).Count -ne 3 -or
                    @($c.Position).Count -ne 3 -or @($c.Rotation).Count -ne 4 -or @($c.Scale).Count -ne 3){throw 'Missing actual native doorway mesh slab'}
                foreach($v in @($c.Mesh.Center)+@($c.Mesh.Extents)+@($c.Position)+@($c.Rotation)+@($c.Scale)){$null=Get-AvatarNumber $v 'native slab vector'}
                $offset=Get-HomeRotated $c.Rotation @(for($j=0;$j -lt 3;$j++){$c.Mesh.Center[$j]*$c.Scale[$j]})
                $center=@(for($j=0;$j -lt 3;$j++){$c.Position[$j]+$offset[$j]});$half=0.0
                for($j=0;$j -lt 3;$j++){
                    if($c.Mesh.Extents[$j] -le 0 -or [Math]::Abs($c.Scale[$j]-1) -gt 0.001){throw 'Invalid/rescaled doorway slab'}
                    $axis=@(0,0,0);$axis[$j]=$c.Mesh.Extents[$j]*$c.Scale[$j];$half+=[Math]::Abs((Get-HomeDot (Get-HomeRotated $c.Rotation $axis) $portal.Normal))
                }
                $distance=[Math]::Max(0.0,[Math]::Abs((Get-HomeDot (Get-HomeRelative $p.Position $center) $portal.Normal))-$half)
                if($distance -gt 0.5){continue}
                $reach=[Math]::Sqrt([Math]::Max(0.0,0.25-$distance*$distance))
                if([Math]::Abs((Get-HomeDot $relative $portal.Right))+$reach -gt $portal.HalfWidth -or [Math]::Abs((Get-HomeDot $relative $portal.Up))+0.4+$reach -gt $portal.HalfHeight){$fits=$false}
            }
        }
        $class='OBSERVE_CONTACT_ONLY';$reason=if($i){'CONTACT_OBSERVED'}else{'FIRST_CONTACT'}
        if($p.NavSampled -ne $true -or $p.Pending -ne $false -or $p.OnNavmesh -ne $true -or $p.pathPending -eq $true -or $p.Path -ne 'PathComplete' -or $p.Calculated -ne $true -or $p.CalculatedPath -ne 'PathComplete'){$class='UNSAFE';$reason='NATIVE_PATH'}
        elseif($p.DoorOpen -ne $true -or -not $fits){$class='UNSAFE';$reason='DOOR_OR_APERTURE'}
        elseif(-not $supported){$class='UNSAFE';$reason='NO_SUPPORT'}
        elseif($bad -or $swept){$class='UNSAFE';$reason=if($swept){'SWEPT_OBSTACLE'}else{'NON_THRESHOLD_CONTACT'}}
        elseif($supportGrowth){$class='UNSAFE';$reason='SUPPORT_CONTACT_DEEPENED'}
        elseif([Math]::Sqrt((Get-HomeDot $p.Velocity $p.Velocity)) -gt 6){$class='UNSAFE';$reason='NONPHYSICAL_VELOCITY'}
        elseif(($p.Time-$p.PosePreviousTime) -gt 0.1 -or ($p.Time-$p.PosePreviousTime) -lt 0 -or
            (Get-WorldDistance $p.Previous $p.Position) -gt 6*($p.Time-$p.PosePreviousTime)+0.01 -or $i -and ($dt -gt 0.1 -or $step -gt 6*$dt+0.01)){$class='UNKNOWN';$reason='SAMPLING_GAP'}
        elseif($elapsed -gt $o.MaxSeconds -or $travel -gt $o.MaxDistance){$class='UNSAFE';$reason='OBSERVATION_BOUND'}
        elseif(-not $i -and -not $lip -and @($p.Overlaps|Where-Object Category -eq FOUNDATION).Count -eq 0){$class='UNKNOWN';$reason='NO_MEASURED_THRESHOLD'}
        elseif($i -and $lip -and $hadLip -and $depth -gt $priorDepth+$o.GrowthLimit){
            $clip=$p.Rigidbody.Kinematic -eq $true -and $step -gt 0.001 -and ($p.Position[1]-$prior.Position[1]) -le $o.GrowthLimit
            $class=if($clip){'KINEMATIC_CLIP'}else{'UNSAFE'};$reason=if($clip){'CONTACT_DEEPENED_WITHOUT_STEP'}else{'CONTACT_DEEPENED'}
        }
        elseif($revision -eq 2 -and $depthBound){$class='UNSAFE';$reason='DEPTH_BOUND'}
        elseif($i -and -not $lip -and ($hadLip -or @($p.Overlaps|Where-Object Category -eq FOUNDATION).Count -eq 0)){
            $class='UNKNOWN';$reason='CLEARANCE_REQUIRES_REVIEW'
        }
        elseif($i -and $elapsed -ge $o.PersistenceSeconds){$class=if($travel -le 0.01){'NATIVE_STUCK'}else{'UNSAFE'};$reason='CONTACT_PERSISTS'}
        if($f.Classification -ne $class -or $f.Reason -ne $reason){throw 'Classification contradicts measured native contact evolution'}
        if($i -lt $frames.Count-1 -and $class -ne 'OBSERVE_CONTACT_ONLY'){throw 'Movement continued after diagnostic stop'}
        if($lip){$priorDepth=if($hadLip){[Math]::Min($priorDepth,$depth)}else{$depth};$hadLip=$true}
    }
    if($o.Outcome -ne $class -or $o.Reason -ne $reason -or $class -eq 'OBSERVE_CONTACT_ONLY'){throw 'False/incomplete diagnostic outcome'}
}
function Assert-FirstHomeNavigation($n) {
    $h=$n.FirstHome;$p=$h.Portal;$door=@($h.Home.Entities|Where-Object Role -eq 'DOOR')
    if($null -ne $h.Observation){throw 'Observe-only contact cannot prove physical home navigation'}
    if($door.Count -ne 1 -or $p.DoorNetId -ne $door[0].NetId -or $p.Radius -ne 0.5 -or $p.Height -ne 1.8){throw 'Missing native doorway/capsule dimensions'}
    foreach($field in @('LocalCenter','LocalExtents','Scale','Center','Normal','Right','Up','Outside','Inside')){
        if(@($p.$field).Count -ne 3){throw 'Missing portal vector'};foreach($v in $p.$field){$null=Get-AvatarNumber $v 'portal vector'}
    }
    foreach($v in $p.Scale){if([Math]::Abs($v-1) -gt 0.001){throw 'Unexpected scaled door'}}
    $offset=Get-HomeRotated $door[0].Rotation $p.LocalCenter
    $center=@(for($i=0;$i -lt 3;$i++){$offset[$i]+$door[0].Position[$i]})
    $normal=Get-HomeRotated $door[0].Rotation $(if($p.LocalExtents[0] -le $p.LocalExtents[2]){@(1,0,0)}else{@(0,0,1)})
    $right=Get-HomeRotated $door[0].Rotation $(if($p.LocalExtents[0] -le $p.LocalExtents[2]){@(0,0,1)}else{@(1,0,0)})
    $up=Get-HomeRotated $door[0].Rotation @(0,1,0)
    if((Get-HomeDot $normal (Get-HomeRelative $p.Inside $p.Outside)) -lt 0){$normal=@($normal|ForEach-Object{-$_})}
    $width=if($p.LocalExtents[0] -le $p.LocalExtents[2]){$p.LocalExtents[2]}else{$p.LocalExtents[0]}
    if((Get-WorldDistance $center $p.Center) -gt 0.001 -or (Get-WorldDistance $normal $p.Normal) -gt 0.001 -or (Get-WorldDistance $right $p.Right) -gt 0.001 -or
        (Get-WorldDistance $up $p.Up) -gt 0.001 -or [Math]::Abs($width-$p.HalfWidth) -gt 0.001 -or [Math]::Abs($p.LocalExtents[1]-$p.HalfHeight) -gt 0.001){throw 'Portal does not match native door transform/aperture'}
    foreach($stage in @('INSIDE_TC','OUTSIDE')){
        $issued=@($h.Navigation|Where-Object {$_.Event -eq 'ISSUED' -and $_.Stage -eq $stage})
        if($issued.Count -ne 1 -or $issued[0].Path -ne 'PathComplete'){throw 'Incomplete home native planned path'}
        $start=$issued[0];$arrival=@($h.Navigation|Where-Object {$_.Event -eq 'ARRIVED' -and $_.Time -gt $start.Time}|Select-Object -First 1)
        if($arrival.Count -ne 1 -or (Get-WorldDistance $arrival[0].Position $start.Target) -gt 0.3){throw 'Home path did not physically arrive'}
        $end=$arrival[0];$segment=@($n.Samples|Where-Object {$_.Time -ge $start.Time-0.1 -and $_.Time -le $end.Time+0.001})
        if($segment.Count -lt 2 -or (Get-WorldDistance $segment[0].Position $start.Start) -gt 0.1 -or (Get-WorldDistance $segment[-1].Position $end.Position) -gt 0.1){throw 'Home path not bound to continuous samples'}
        $crossings=@()
        for($j=1;$j -lt $segment.Count;$j++){
            $a=Get-HomeDot (Get-HomeRelative $segment[$j-1].Position $center) $normal;$b=Get-HomeDot (Get-HomeRelative $segment[$j].Position $center) $normal
            $cross=if($stage -eq 'INSIDE_TC'){$a -lt 0 -and $b -ge 0}else{$a -gt 0 -and $b -le 0}
            if($cross){
                $t=[Math]::Abs($a)/([Math]::Abs($a)+[Math]::Abs($b))
                $point=@(for($k=0;$k -lt 3;$k++){$segment[$j-1].Position[$k]+$t*($segment[$j].Position[$k]-$segment[$j-1].Position[$k])})
                $body=@($point[0],($point[1]+0.9),$point[2]);$relative=Get-HomeRelative $body $center
                if([Math]::Abs((Get-HomeDot $relative $right))+0.5 -gt $p.HalfWidth+0.02 -or [Math]::Abs((Get-HomeDot $relative $up))+0.9 -gt $p.HalfHeight+0.02){throw 'Physical capsule missed native doorway aperture'}
                $crossings+=@{Position=$point;Time=$segment[$j].Time}
            }
        }
        $eventName=if($stage -eq 'INSIDE_TC'){'CROSSED_IN'}else{'CROSSED_OUT'};$events=@($h.Navigation|Where-Object Event -eq $eventName)
        if($crossings.Count -ne 1 -or $events.Count -ne 1 -or [Math]::Abs($events[0].Time-$crossings[0].Time) -gt 0.1 -or (Get-WorldDistance $events[0].Position $crossings[0].Position) -gt 0.1){throw 'Portal event is not a measured physical crossing'}
        foreach($sample in $segment|Select-Object -Skip 1){
            $physics=@($h.Navigation|Where-Object {$_.Event -eq 'PHYSICS' -and [Math]::Abs($_.Time-$sample.Time) -lt 0.000001})
            if($physics.Count -ne 1 -or $physics[0].Clear -ne $true -or $physics[0].DoorOpen -ne $true -or (Get-WorldDistance $physics[0].Position $sample.Position) -gt 0.01 -or ($physics[0].Inside -and $physics[0].OwnedFloor -ne $true)){throw 'Home sample lacks actual collider/floor clearance'}
            Assert-FirstHomePhysics $physics[0] -RequireClear
            if($physics[0].ActorNetId -ne $sample.ActorNetId){throw 'Physics belongs to a different actor'}
        }
    }
    $tc=@($h.Navigation|Where-Object Event -eq 'TC_REACHED')
    if($tc.Count -ne 1 -or $tc[0].LineOfSight -ne $true -or $tc[0].Range -gt 2 -or @($n.Samples|Where-Object {[Math]::Abs($_.Time-$tc[0].Time) -lt 0.01 -and (Get-WorldDistance $_.Position $tc[0].Position) -lt 0.01}).Count -ne 1){throw 'TC interaction unbound to physical sample'}
    $collider=@($h.Navigation|Where-Object Event -eq 'DOOR_COLLIDER')
    if($collider.Count -ne 1 -or $collider[0].Changed -ne $true -or ($collider[0].Closed|ConvertTo-Json -Depth 12 -Compress) -ceq ($collider[0].Open|ConvertTo-Json -Depth 12 -Compress)){throw 'Native door collider motion unproven'}
}
function Assert-FirstHomeSources($n) {
    $sources=@($n.Economy.State.Sources)
    if($sources.Count -lt 2 -or @($sources.Incarnation|Select-Object -Unique).Count -ne $sources.Count -or @($sources.SavedUid|Select-Object -Unique).Count -ne $sources.Count){throw 'Missing/duplicate home resource incarnations'}
    foreach($source in $sources){
        $other=@($sources|Where-Object Resource -ne $source.Resource|Select-Object -First 1)
        if($other.Count -ne 1 -or $source.Resource -notin @('wood','stones')){throw 'Incomplete home source categories'}
        # Reuse every 009 per-source disk/geometry/health/pool/neighbor check unchanged.
        # Each source participates in a wood+stone pair; no source or replay is silently omitted.
        $e=$n.Economy|ConvertTo-Json -Depth 30|ConvertFrom-Json
        $e.State.Sources=@($source,$other[0]);$ids=@($e.State.Sources.Incarnation)
        $e.Replays=@($e.Replays|Where-Object {$_.Incarnation -in $ids})
        $view=[pscustomobject]@{Status='GREEN';Mode=$n.Mode;State=$n.State;Harvests=$n.Harvests;Economy=$e}
        Assert-EconomyResult $view
    }
    if($n.Mode -eq 'RESTORE' -and @($n.Economy.Replays).Count -ne 2*$sources.Count){throw 'Unexpected source replay rows'}
}
function Assert-FirstHomeHeldRestore($n) {
    $a=$n.RestoreAudit
    if((Get-AvatarSurvivalContainerKey $a.SourceContainers) -cne (Get-AvatarSurvivalContainerKey $n.Containers)){throw 'Native home containers differ'}
    foreach($c in $a.SourceContainers){if($c.Capacity -le 0 -or $c.Capacity -ne ($n.Containers|Where-Object Role -eq $c.Role).Capacity){throw 'Native home capacity changed'}}
    if($a.Stage -ne 'COMPLETE' -or $a.ParentPasses -ne 2 -or $a.ItemsAfter-$a.ItemsBefore -ne @($n.Inventory).Count){throw 'Incomplete native home load'}
    foreach($field in @('LoadCalled','IncomingAbsent','PreLoadHeldZero','SourceUnchanged','ForeignItemsUnchanged','ForeignEntitiesUnchanged','HeldStable')){if($a.$field -ne $true){throw 'Unsafe native home restore'}}
    foreach($rows in @($a.SourceInventory,$a.NativeBefore,$a.Loaded)){if((Get-AvatarSurvivalKey $rows) -cne (Get-AvatarSurvivalKey $n.Inventory)){throw 'Native home binary/receipt rows differ'}}
    $expected=@($n.Inventory|Where-Object {$_.Role -eq 'BELT' -and $_.Shortname -in @('rock','stonehatchet','building.planner','hammer')}|ForEach-Object Uid|Sort-Object)
    $refs=@($a.TransientRefs);$held=@($a.HeldItems)
    if($expected.Count -ne 4 -or $refs.Count -ne 4 -or $held.Count -ne 4 -or @($refs.SavedHeldNetId|Select-Object -Unique).Count -ne 4 -or @($held.HeldNetId|Select-Object -Unique).Count -ne 4 -or
        (@($refs.ItemUid|Sort-Object)-join ',') -cne ($expected -join ',') -or (@($held.Uid|Sort-Object)-join ',') -cne ($expected -join ',')){throw 'Missing/duplicate home tool held ledger'}
    foreach($ref in $refs){
        Assert-AvatarUid $ref.SavedHeldNetId
        if($ref.Before.NetId -ne $ref.SavedHeldNetId -or ($ref.Before|ConvertTo-Json -Depth 8 -Compress) -cne ($ref.After|ConvertTo-Json -Depth 8 -Compress)){throw 'Saved held alias mutated'}
    }
    foreach($row in $held){
        Assert-AvatarUid $row.HeldNetId
        if($row.HeldNetId -in $refs.SavedHeldNetId -or $row.HeldItemUid -ne $row.Uid -or $row.OwnerNetId -ne $n.Actor.NetId -or $row.ParentNetId -ne $n.Actor.NetId){throw 'Aliased/foreign native home tool held'}
    }
    if(($held|Where-Object Uid -eq $n.State.ProductUid).HeldNetId -ne $n.Equipment.HeldNetId){throw 'Active home axe differs from native load'}
    $samples=@($n.EquipmentSamples)
    if($samples.Count -lt 3 -or $samples[-1].Time-$samples[0].Time -lt 1){throw 'Missing restored held observations'}
    for($j=0;$j -lt $samples.Count;$j++){
        if(($samples[$j].Equipment|ConvertTo-Json -Compress) -cne ($n.Equipment|ConvertTo-Json -Compress) -or ($j -gt 0 -and $samples[$j].Time -le $samples[$j-1].Time)){throw 'Restored native equipment changed'}
    }
}
function Assert-FirstHomeSmokeResult($n) {
    Assert-FirstHomeApproaches $n.FirstHome $n.Actor.NetId
    $h=$n.FirstHome
    if($null -ne $h.Observation){
        Assert-FirstHomeObservation $h.Observation
        $contactTime=$h.Observation.Frames[0].Physics.Time
        if($h.NavigationComplete -or @($h.Navigation|Where-Object {$_.Event -in @('CROSSED_IN','CROSSED_OUT','TC_REACHED') -and $_.Time -ge $contactTime}).Count){throw 'Contact observation leaked into accepted navigation'}
        foreach($frame in $h.Observation.Frames){
            $actual=@($h.Navigation|Where-Object {$_.Event -eq 'PHYSICS' -and $_.Time -eq $frame.Physics.Time})
            if($actual.Count -ne 1 -or ($actual[0]|ConvertTo-Json -Depth 30 -Compress) -cne ($frame.Physics|ConvertTo-Json -Depth 30 -Compress)){throw 'Observation is not bound to actual physics receipts'}
        }
    }
    $watch=@($h.Navigation|Where-Object {$_.Event -eq 'PHYSICS' -and $_.Watch -eq $true})
    for($i=0;$i -lt $watch.Count;$i++) {
        $p=$watch[$i];$dt=$p.Time-$p.PosePreviousTime
        $terminal=$null -ne $h.Observation -and $p.Time -ge $h.Observation.Frames[0].Physics.Time
        if($i -and ($p.PosePreviousTime -ne $watch[$i-1].Time -or (Get-WorldDistance $p.Previous $watch[$i-1].Position) -gt 0.0001)){throw 'Broken high-frequency physical trajectory'}
        if(-not $terminal){
            Assert-FirstHomePhysics $p -RequireClear:$h.NavigationComplete
            if(-not (Test-FirstHomePhysicalSupport $p) -or $p.ActorNetId -ne $n.Actor.NetId -or $p.CalculatedPath -ne 'PathComplete' -or $p.NavSampled -ne $true -or $p.Pending -ne $false -or
                $dt -le 0 -or $dt -gt 0.1 -or (Get-WorldDistance $p.Previous $p.Position) -gt 6*$dt+0.01 -or
                (Get-WorldDistance $p.Sweep.From $p.Previous) -gt 0.0001 -or (Get-WorldDistance $p.Sweep.To $p.Position) -gt 0.0001 -or
                [Math]::Abs((Get-WorldDistance $p.Previous $p.Position)-$p.Sweep.Distance) -gt 0.0001){throw 'Unobserved/unsafe native movement before contact'}
        }
    }
    if($h.NavigationComplete){
        foreach($stage in @('INSIDE_TC','OUTSIDE')){
            $issued=@($h.Navigation|Where-Object {$_.Event -eq 'ISSUED' -and $_.Stage -eq $stage})
            if($issued.Count -ne 1){throw 'Missing physical leg start'}
            $arrived=@($h.Navigation|Where-Object {$_.Event -eq 'ARRIVED' -and $_.Time -gt $issued[0].Time}|Select-Object -First 1)
            $covered=@($watch|Where-Object {$_.Time -gt $issued[0].Time -and $_.Time -le $arrived[0].Time})
            if($arrived.Count -ne 1 -or $covered.Count -lt 2 -or $covered[0].Time-$issued[0].Time -gt 0.1 -or
                $arrived[0].Time-$covered[-1].Time -gt 0.1 -or (Get-WorldDistance $covered[0].Previous $issued[0].Start) -gt 0.01 -or
                (Get-WorldDistance $covered[-1].Position $arrived[0].Position) -gt 0.01){throw 'Incomplete high-frequency physical route coverage'}
        }
    }
    foreach($p in @($h.Navigation|Where-Object Event -eq PHYSICS)){Assert-FirstHomePhysics $p}
    if($n.Mode -ne 'BUILD_SMOKE' -or $h.DiagnosticOnly -ne $true -or $n.Status -notin @('PARTIAL','BLOCKED','FAILED') -or
        $n.Persistence.Saved -or $n.Persistence.Restored -or $h.SaveReady -or @($n.Harvests).Count -or $n.ManualPositionWrites -ne 0){throw 'Diagnostic smoke crossed natural/save boundary'}
    if($n.Conservation.EconomicFailure -and $n.Status -ne 'FAILED'){throw 'Smoke conservation failure cannot pass'}
    if(-not $n.Actor){if($h.NavigationComplete){throw 'Smoke home without actor'};return}
    Assert-AvatarActor $n
    if(-not @($h.Fixture).Count){if($h.NavigationComplete){throw 'Smoke home without fixture ledger'};return}
    $issued=@();$expected=@{}
    foreach($name in $h.Budget.PSObject.Properties.Name){$expected[$name]=[int]$h.Budget.$name}
    foreach($cost in $n.Recipe.Ingredients){$expected[$cost.Shortname]+=[int]$cost.Amount}
    foreach($row in $h.Fixture){
        if($row.DiagnosticOnly -ne $true -or $row.Item.Shortname -notin @('wood','stones') -or
            $row.Source -cne ('TEST_FIXTURE_'+$row.Item.Shortname.ToUpperInvariant()) -or $row.Amount -ne $row.Item.Amount -or
            $row.Item.OwnerNetId -ne $n.Actor.NetId){throw 'Unknown diagnostic fixture provenance'}
        $issued+=@($row.Item)
    }
    $null=Get-FirstHomeEconomicKey $issued
    foreach($name in $expected.Keys){if([int](($issued|Where-Object Shortname -eq $name|Measure-Object Amount -Sum).Sum) -ne $expected[$name]){throw 'Diagnostic fixture budget differs from native loaded cost'}}
    $last=@(@($n.StarterKit)+$issued);$paid=@{}
    foreach($op in $h.Operations){
        if($op.Kind -eq 'GATHER' -or $paid.ContainsKey([string]$op.Kind) -or
            (Get-FirstHomeEconomicKey $last) -cne (Get-FirstHomeEconomicKey $op.Before)){throw 'Smoke duplicate/gather/broken payment chain'}
        Assert-FirstHomePayment $op
        if($op.Kind -eq 'CRAFT_TOOL'){$cost=$n.Recipe.Ingredients}
        elseif($op.Kind -like 'CRAFT_*'){$cost=$h.Recipes.($op.Kind.Substring(6)).Ingredients}
        elseif($op.Kind -in @('BUILD_DOOR','BUILD_TC')){$cost=@([pscustomobject]@{Shortname=$(if($op.Kind -eq 'BUILD_TC'){'cupboard.tool'}else{'door.hinged.wood'});Amount=1})}
        else{$cost=$h.GradeCosts.($op.Kind)}
        if(-not $cost -or (Get-FirstHomeCostKey $cost) -cne (Get-FirstHomeCostKey $op.Costs)){throw 'Smoke payment differs from loaded recipe/grade'}
        $paid[[string]$op.Kind]=$true;$last=$op.After
    }
    if(-not $h.NavigationComplete){return}
    Assert-FirstHomeTcPlacement $h.NativePlacements
    Assert-FirstHomeDoorPlacement $h.NativePlacements @($h.Home.Entities|Where-Object Role -eq 'DOOR')[0] @($h.Home.Entities|Where-Object Role -eq 'DOORWAY')[0].NetId
    Assert-FirstHomeTcAuthorization $h.TcAuthorization $n.Actor.UserId $h.Home.BuildingId @($h.Home.Entities|Where-Object Role -eq 'TC')[0]
    Assert-FirstHomeStructure $h.Home;Assert-FirstHomeSite $h.Site;Assert-FirstHomeNavigation $n
    if($paid.Count -ne 19 -or @($h.NativePlacements).Count -ne 8 -or @($h.NativePlacements|Where-Object {-not $_.Entity}).Count -or
        $h.PendingIntent -or -not $h.CrossedIn -or -not $h.CrossedOut){throw 'Incomplete native build smoke'}
    $u=$h.Upkeep
    Assert-FirstHomeUpkeep $u
    if(-not $u.Authed -or -not $u.Privilege -or $u.MinutesAfter -lt 60 -or
        (Get-FirstHomeEconomicKey $last) -cne (Get-FirstHomeEconomicKey $u.Before) -or
        (Get-FirstHomeEconomicKey $u.Before) -cne (Get-FirstHomeEconomicKey @(@($u.After)+@($u.TcInventory))) -or
        (Get-FirstHomeEconomicKey $u.After) -cne (Get-FirstHomeEconomicKey $n.Inventory)){throw 'Smoke TC debit/auth/upkeep not proven'}
}
function Assert-FirstHomeResult($n) {
    Assert-FirstHomeApproaches $n.FirstHome $n.Actor.NetId
    if($n.Status -notin @('GREEN','PARTIAL','BLOCKED','FAILED')){throw 'Unknown FirstHome status'}
    if($n.Conservation.EconomicFailure -eq $true -and $n.Status -ne 'FAILED'){throw 'Conservation failure cannot pass'}
    $h=$n.FirstHome
    if($h.DiagnosticOnly -or ($null -ne $h.Fixture -and @($h.Fixture).Count)){throw 'TEST_FIXTURE cannot be accepted as natural FirstHome'}
    if($null -eq $h -or $h.Schema -ne 1){throw 'Missing FirstHome receipt'}
    if($n.Status -ne 'GREEN' -and -not $h.SaveReady){return}
    Assert-AvatarActor $n;Assert-AvatarSurvivalRows $n.Inventory $n;Assert-AvatarSurvivalEquipment $n
    Assert-FirstHomeStructure $h.Home
    Assert-FirstHomeSources $n
    if($h.Decay.Enabled -ne $true -or (Get-AvatarNumber $h.Decay.Scale 'decay scale') -le 0 -or (Get-AvatarNumber $h.Decay.WoodDuration 'wood decay duration') -le 0){throw 'Decay/upkeep disabled'}
    $keys=Get-EconomyWorldKeys $n.Economy.World
    if($n.ManualPositionWrites -ne 0 -or $n.Actor.Type -ne 'ScientistNPC' -or $n.Actor.UserId -ne $h.Home.Owner -or
        $n.Normalization.RemovedAbsent -ne $true -or @($n.Normalization.AfterStrip).Count -ne 0 -or $h.PendingIntent -or
        $n.Persistence.Saved -ne $true -or $n.Conservation.Ok -ne $true -or $keys.WorldKey -cne $n.Economy.WorldKey -or
        $h.Snapshot.WorldKey -cne $keys.WorldKey -or $h.Snapshot.ActorId -cne $n.State.ActorId -or $h.Snapshot.Schema -ne 1){throw 'Incomplete world-bound native home'}
    $samples=@($n.Samples);$sum=0.0
    for($i=1;$i -lt $samples.Count;$i++){
        $dt=(Get-AvatarNumber $samples[$i].Time 'time')-(Get-AvatarNumber $samples[$i-1].Time 'time')
        $step=Get-WorldDistance $samples[$i-1].Position $samples[$i].Position
        if($dt -le 0 -or $dt -gt 1.5 -or $step -gt 5 -or $step -gt 6*$dt+1 -or $samples[$i].ActorNetId -ne $n.Actor.NetId){throw 'Discontinuous FirstHome trace'};$sum+=$step
    }
    if($samples.Count -lt 3 -or [Math]::Abs($sum-$n.TotalTraveled) -gt 0.2){throw 'False FirstHome travel total'}
    if($n.Mode -eq 'RESTORE'){
        if(@($n.Harvests).Count -or $null -ne $n.Craft -or @($n.StarterKit).Count -or @($h.Operations).Count -or
            $h.Restored -ne $true -or $n.Persistence.Restored -ne $true -or $h.Rebind.Builds -ne 0 -or $h.Rebind.ItemCredits -ne 0 -or
            $h.Rebind.WorldValidated -ne $true -or $h.Rebind.DiskWitnesses -ne 8 -or $h.Rebind.ForeignAuth -ne $false){throw 'Restore rebuilt/recredited or skipped native witness checks'}
        Assert-FirstHomeRestore $h.Source $h.Snapshot
        Assert-FirstHomeHeldRestore $n
        $audit=$n.RestoreAudit
        foreach($field in @('LoadCalled','IncomingAbsent','PreLoadHeldZero','SourceUnchanged','ForeignItemsUnchanged','ForeignEntitiesUnchanged','HeldStable')){if($audit.$field -ne $true){throw 'Unsafe native home inventory restore'}}
        if($audit.ParentPasses -ne 2 -or $audit.ItemsAfter-$audit.ItemsBefore -ne @($n.Inventory).Count -or
            (Get-FirstHomeEconomicKey $audit.SourceInventory) -cne (Get-FirstHomeEconomicKey $n.Inventory) -or
            (Get-FirstHomeEconomicKey $h.Source.TcInventory) -cne (Get-FirstHomeEconomicKey $h.Snapshot.TcInventory)){throw 'Native home inventory changed on restore'}
    }elseif($n.Mode -eq 'JOURNEY'){
        Assert-FirstHomeTcPlacement $h.NativePlacements
        Assert-FirstHomeDoorPlacement $h.NativePlacements @($h.Home.Entities|Where-Object Role -eq 'DOOR')[0] @($h.Home.Entities|Where-Object Role -eq 'DOORWAY')[0].NetId
        Assert-FirstHomeTcAuthorization $h.TcAuthorization $n.Actor.UserId $h.Home.BuildingId @($h.Home.Entities|Where-Object Role -eq 'TC')[0]
        Assert-FirstHomeSite $h.Site
        if(@($n.StarterKit).Count -ne 1 -or $n.StarterKit[0].Shortname -ne 'rock' -or $n.StarterKit[0].Amount -ne 1){throw 'Free home starter material'}
        $last=$n.StarterKit;$paid=@{};$pools=@{};$gathers=0;$selectedTool=$n.State.ToolUid;$switchUsed=$false;$switches=@($h.ToolSwitches)
        if($switches.Count -gt 1){throw 'Repeated home tool switch'}
        foreach($op in @($h.Operations)){
            Assert-AvatarSurvivalRows $op.Before $n;Assert-AvatarSurvivalRows $op.After $n
            if((Get-FirstHomeEconomicKey $last) -cne (Get-FirstHomeEconomicKey $op.Before)){throw 'Broken home economic UID/condition chain'}
            if($op.Kind -eq 'GATHER'){
                $gathers++;$g=$op.Harvest
                $nextTool=Assert-FirstHomeGatherTool $op $(if($switches.Count){$switches[0]}else{$null}) $selectedTool $n.State.ToolUid $n.State.ProductUid $n.Actor.NetId
                if($nextTool -ne $selectedTool){$switchUsed=$true;$selectedTool=$nextTool}
                foreach($v in @($g.Amount,$g.PoolBefore,$g.PoolAfter,$g.ToolConditionBefore,$g.ToolConditionAfter,$g.Distance)){$null=Get-AvatarNumber $v 'home gather'}
                if($g.Mechanism -ne 'NATIVE_PLAYER_GATHER' -or $g.Provenance -ne 'NATURAL' -or $g.AdapterCredit -ne 0 -or $g.NewDrops -ne 0 -or
                    $g.InitiatorPlayer -ne $true -or $g.WeaponOwned -ne $true -or $g.DidGather -ne $true -or $g.Grounded -ne $true -or $g.LineOfSight -ne $true -or
                    $g.Amount -le 0 -or $g.PoolAfter -le 0 -or $g.PoolBefore-$g.PoolAfter -lt $g.Amount -or $g.ToolConditionBefore -le $g.ToolConditionAfter){throw 'Unpaid/non-native home resources'}
                if($pools.ContainsKey([string]$g.SourceId) -and [Math]::Abs($pools[[string]$g.SourceId]-$g.PoolBefore) -gt 0.001){throw 'Home source pool chain broken'};$pools[[string]$g.SourceId]=$g.PoolAfter
                $tool=@($op.Before|Where-Object Uid -eq $g.ToolUid);$afterTool=@($op.After|Where-Object Uid -eq $g.ToolUid)
                if($tool.Count -ne 1 -or $afterTool.Count -ne 1 -or $tool[0].Condition -ne $g.ToolConditionBefore -or $afterTool[0].Condition -ne $g.ToolConditionAfter -or
                    $g.ToolUid -notin @($n.State.ToolUid,$n.State.ProductUid) -or $afterTool[0].Condition -le 0 -or $tool[0].MaxCondition -ne $afterTool[0].MaxCondition){throw 'Home gather used a different/broken tool UID'}
                foreach($old in @($op.Before|Where-Object {$_.Shortname -in @('rock','stonehatchet') -and $_.Uid -ne $g.ToolUid})){
                    $same=@($op.After|Where-Object Uid -eq $old.Uid)
                    if($same.Count -ne 1 -or $same[0].Condition -ne $old.Condition -or $same[0].MaxCondition -ne $old.MaxCondition){throw 'Gather repaired/mutated inactive tool'}
                }
                foreach($name in @(@($op.Before.Shortname)+@($op.After.Shortname)|Sort-Object -Unique)){
                    $b=[double](($op.Before|Where-Object Shortname -eq $name|Measure-Object Amount -Sum).Sum)
                    $a=[double](($op.After|Where-Object Shortname -eq $name|Measure-Object Amount -Sum).Sum)
                    if($a-$b -ne $(if($name -eq $g.Resource){$g.Amount}else{0})){throw 'Native gather injected other items'}
                }
            }else{
                if($paid.ContainsKey([string]$op.Kind)){throw 'Duplicate home payment/build intent'};$paid[[string]$op.Kind]=$op
                Assert-FirstHomePayment $op
                if($op.Kind -eq 'CRAFT_TOOL'){$expected=$n.Recipe.Ingredients;$selectedTool=$n.State.ProductUid}
                elseif($op.Kind -like 'CRAFT_*'){
                    $name=$op.Kind.Substring(6);$r=$h.Recipes.$name
                    if($null -eq $r -or $r.Known -ne $true -or $r.Allowed -ne $true -or $r.Workbench -ne 0 -or $r.AmountToCreate -ne 1 -or $op.Output.Shortname -ne $name){throw 'Unknown/unpaid native home recipe'};$expected=$r.Ingredients
                }elseif($op.Kind -in @('BUILD_DOOR','BUILD_TC')){
                    $expected=@([pscustomobject]@{Shortname=$(if($op.Kind -eq 'BUILD_DOOR'){'door.hinged.wood'}else{'cupboard.tool'});Amount=1})
                }else{$expected=$h.GradeCosts.($op.Kind);if($null -eq $expected){throw 'Unknown home building cost'}}
                if((Get-FirstHomeCostKey $expected) -cne (Get-FirstHomeCostKey $op.Costs)){throw 'Payment differs from loaded recipe/grade costs'}
                if($op.Kind -match '^(BUILD|UPGRADE)_(.+)$'){
                    $entity=@($h.Home.Entities|Where-Object Role -eq $matches[2]);if($entity.Count -ne 1 -or $entity[0].NetId -ne $op.EntityId){throw 'Paid building entity does not exist'}
                }
            }
            $last=$op.After
        }
        if($paid.Count -ne 19 -or $gathers -ne @($n.Harvests).Count -or $pools.Count -ne @($n.Economy.State.Sources).Count){throw 'Incomplete paid home ledger'}
        if($switches.Count -ne [int]$switchUsed){throw 'Unused/fabricated home tool switch'}
        $u=$h.Upkeep
        if((Get-FirstHomeEconomicKey $last) -cne (Get-FirstHomeEconomicKey $u.Before) -or
            (Get-FirstHomeEconomicKey $u.After) -cne (Get-FirstHomeEconomicKey $n.Inventory) -or
            (Get-FirstHomeEconomicKey $u.Before) -cne (Get-FirstHomeEconomicKey @(@($u.After)+@($u.TcInventory)))){throw 'TC transfer created/lost/replaced an item UID'}
        Assert-FirstHomeUpkeep $u
    }else{throw 'Unknown home mode'}
    if($n.Status -eq 'GREEN'){
        Assert-FirstHomeNavigation $n
        if($h.NavigationComplete -ne $true -or $h.CrossedIn -ne $true -or $h.CrossedOut -ne $true -or
            @($h.Navigation|Where-Object Event -eq 'CROSSED_IN').Count -ne 1 -or @($h.Navigation|Where-Object Event -eq 'CROSSED_OUT').Count -ne 1 -or
            @($h.Navigation|Where-Object {$_.Event -eq 'TC_REACHED' -and $_.LineOfSight -eq $true -and $_.Range -le 2}).Count -ne 1 -or
            @($h.Navigation|Where-Object {$_.Event -eq 'DOOR' -and $_.Before -eq $false -and $_.After -eq $true}).Count -ne 1 -or
            @($h.Navigation|Where-Object {$_.Event -eq 'DOOR' -and $_.After -eq $false -and $_.Requested -eq $false}).Count -ne 1){throw 'Missing physical native door/home navigation'}
    }
}
function Assert-FirstHomeBinding($prior,$proof,[string]$runtime,[string]$key,[string]$generation,[string]$sav,[string]$inv,[string]$actor) {
    Assert-FirstHomeResult $prior.Navigation
    if($prior.Status -notin @('GREEN','PARTIAL') -or $prior.FirstHome -ne $true -or $prior.Navigation.FirstHome.SaveReady -ne $true -or
        $prior.Shutdown -ne 'GRACEFUL' -or $prior.OwnedProcessAbsent -ne $true -or $prior.PortsReleased -ne $true -or $prior.FirewallRemoved -ne $true -or $prior.Cache.Promoted -ne $true -or
        $proof.RunId -ne $prior.RunId -or $prior.Cache.Key -ne $key -or $proof.CacheKey -ne $key -or $proof.Generation -ne $generation -or
        $proof.SavSHA256 -ne $sav -or $proof.SnapshotSHA256 -ne $inv -or $proof.ActorStateSHA256 -ne $actor -or $prior.WorldInventorySHA256 -ne $inv -or $prior.ActorStateSHA256 -ne $actor){throw 'Unsafe/stale home save binding'}
    foreach($entry in @(@('economy.journal','EconomyJournalSHA256'),@('economy.json','EconomyStateSHA256'),@('economy.home.json','HomeSHA256'))){
        $hash=(Get-FileHash -LiteralPath (Join-Path $runtime $entry[0]) -Algorithm SHA256).Hash
        if($hash -cne $proof.($entry[1]) -or $hash -cne $prior.($entry[1])){throw 'Home/economy proof hash mismatch'}
    }
    $journal=@(Read-EconomyJournal (Join-Path $runtime 'economy.journal') $prior.Navigation.Economy.WorldKey $prior.Navigation.State.ActorId $prior.Navigation.Economy.State.RecipeHash)
    $n=$prior.Navigation;$state=Get-Content (Join-Path $runtime 'economy.json') -Raw -Encoding UTF8|ConvertFrom-Json
    if(($state|ConvertTo-Json -Depth 30 -Compress) -cne ($n.Economy.State|ConvertTo-Json -Depth 30 -Compress) -or $n.Economy.JournalSHA256 -cne $proof.EconomyJournalSHA256){throw 'Home economy receipt/file differs'}
    $craft=@($journal|Where-Object {$_.Kind -eq 'CRAFT' -and $_.Stage -eq 'COMMITTED'})
    if($craft.Count -ne 1 -or $craft[0].Intent -ne $n.State.CraftIntent -or $craft[0].Payload.Output.Uid -ne $n.State.ProductUid){throw 'Home tool journal payment missing'}
    $hits=@($journal|Where-Object {$_.Kind -eq 'GATHER' -and $_.Stage -eq 'APPLIED'})
    if($n.Mode -eq 'JOURNEY' -and $hits.Count -ne @($n.Harvests).Count){throw 'Home journal/gather count differs'}
    for($i=0;$n.Mode -eq 'JOURNEY' -and $i -lt $hits.Count;$i++){
        if(($hits[$i].Payload|ConvertTo-Json -Depth 25 -Compress) -cne ($n.Harvests[$i]|ConvertTo-Json -Depth 25 -Compress)){throw 'Home native gather differs from durable journal'}
    }
    foreach($source in $state.Sources){
        $last=@($journal|Where-Object {$_.Kind -eq 'GATHER' -and $_.Stage -eq 'COMMITTED' -and $_.Payload.Source.Incarnation -eq $source.Incarnation}|Select-Object -Last 1)
        if($last.Count -ne 1 -or ($last[0].Payload.Source|ConvertTo-Json -Depth 15 -Compress) -cne ($source|ConvertTo-Json -Depth 15 -Compress)){throw 'Home source depletion differs from immutable journal'}
    }
    $savedHome=Get-Content (Join-Path $runtime 'economy.home.json') -Raw -Encoding UTF8|ConvertFrom-Json
    if(($savedHome|ConvertTo-Json -Depth 25 -Compress) -cne ($n.FirstHome.Snapshot|ConvertTo-Json -Depth 25 -Compress)){throw 'Home snapshot differs from bound receipt'}
}
function Write-FirstHomeSaveProof([string]$runtime,[string]$cacheRoot) {
    $p=Get-Content (Join-Path $runtime 'result.json') -Raw -Encoding UTF8|ConvertFrom-Json
    $m=Get-Content (Join-Path $cacheRoot 'world-manifest.json') -Raw -Encoding UTF8|ConvertFrom-Json
    $sav=@($m.Files|Where-Object Name -match '\.sav$')
    if($sav.Count -ne 1 -or [IO.File]::ReadAllText((Join-Path $cacheRoot 'install\rustbots-test.marker')) -ne $p.RunId){throw 'Not current home save'}
    $actual=(Get-FileHash -LiteralPath (Join-Path $cacheRoot ($m.Generation+'\'+$sav[0].Name)) -Algorithm SHA256).Hash
    if($actual -ne $sav[0].SHA256){throw 'Home saved world differs'}
    $proof=[pscustomobject]@{RunId=$p.RunId;CacheKey=$m.Key;Generation=$m.Generation;SavSHA256=$actual;SnapshotSHA256=$p.WorldInventorySHA256;ActorStateSHA256=$p.ActorStateSHA256;
        EconomyJournalSHA256=$p.EconomyJournalSHA256;EconomyStateSHA256=$p.EconomyStateSHA256;HomeSHA256=$p.HomeSHA256}
    Assert-FirstHomeBinding $p $proof $runtime $m.Key $m.Generation $actual $p.WorldInventorySHA256 $p.ActorStateSHA256
    [IO.File]::WriteAllText((Join-Path $runtime 'world-proof.json'),($proof|ConvertTo-Json -Depth 8),[Text.Encoding]::UTF8)
}
