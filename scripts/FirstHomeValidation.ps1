#Requires -Version 5.1
. (Join-Path $PSScriptRoot 'EconomyValidation.ps1')
function Assert-FirstHomeSite($site) {
    $range=Get-AvatarNumber $site.HeightRange 'footprint height range';$depth=Get-AvatarNumber $site.FoundationDepth 'foundation depth'
    $entry=Get-AvatarNumber $site.EntryDelta 'entrance height';$outside=Get-AvatarNumber $site.OutsideDelta 'approach height'
    if($depth -le 0 -or $range -lt 0 -or $range -gt $depth*0.5 -or [Math]::Abs($entry) -gt 0.25 -or [Math]::Abs($outside) -gt 0.25 -or
        $site.NativePreview -ne $true -or $site.Permission -ne $true -or $site.Path -ne 'PathComplete'){throw 'Unsafe/unpreviewed home foundation or entrance'}
    foreach($field in @('Water','Monument','Road','Foreign','Collision')){if($site.$field -ne $false){throw 'Excluded home site accepted'}}
    if($site.ForbiddenTopology -ne 16776578 -or ((Get-AvatarNumber $site.Topology 'topology') -band 16776578) -ne 0){throw 'Forbidden site topology'}
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
function Assert-FirstHomeNavigation($n) {
    $h=$n.FirstHome;$p=$h.Portal;$door=@($h.Home.Entities|Where-Object Role -eq 'DOOR')
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
            $physics=@($h.Navigation|Where-Object {$_.Event -eq 'PHYSICS' -and [Math]::Abs($_.Time-$sample.Time) -lt 0.01})
            if($physics.Count -ne 1 -or $physics[0].Clear -ne $true -or $physics[0].DoorOpen -ne $true -or (Get-WorldDistance $physics[0].Position $sample.Position) -gt 0.01 -or ($physics[0].Inside -and $physics[0].OwnedFloor -ne $true)){throw 'Home sample lacks actual collider/floor clearance'}
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
function Assert-FirstHomeResult($n) {
    if($n.Status -notin @('GREEN','PARTIAL','BLOCKED','FAILED')){throw 'Unknown FirstHome status'}
    if($n.Conservation.EconomicFailure -eq $true -and $n.Status -ne 'FAILED'){throw 'Conservation failure cannot pass'}
    $h=$n.FirstHome
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
        Assert-FirstHomeSite $h.Site
        if(@($n.StarterKit).Count -ne 1 -or $n.StarterKit[0].Shortname -ne 'rock' -or $n.StarterKit[0].Amount -ne 1){throw 'Free home starter material'}
        $last=$n.StarterKit;$paid=@{};$pools=@{};$gathers=0
        foreach($op in @($h.Operations)){
            Assert-AvatarSurvivalRows $op.Before $n;Assert-AvatarSurvivalRows $op.After $n
            if((Get-FirstHomeEconomicKey $last) -cne (Get-FirstHomeEconomicKey $op.Before)){throw 'Broken home economic UID/condition chain'}
            if($op.Kind -eq 'GATHER'){
                $gathers++;$g=$op.Harvest
                foreach($v in @($g.Amount,$g.PoolBefore,$g.PoolAfter,$g.ToolConditionBefore,$g.ToolConditionAfter,$g.Distance)){$null=Get-AvatarNumber $v 'home gather'}
                if($g.Mechanism -ne 'NATIVE_PLAYER_GATHER' -or $g.Provenance -ne 'NATURAL' -or $g.AdapterCredit -ne 0 -or $g.NewDrops -ne 0 -or
                    $g.InitiatorPlayer -ne $true -or $g.WeaponOwned -ne $true -or $g.DidGather -ne $true -or $g.Grounded -ne $true -or $g.LineOfSight -ne $true -or
                    $g.Amount -le 0 -or $g.PoolAfter -le 0 -or $g.PoolBefore-$g.PoolAfter -lt $g.Amount -or $g.ToolConditionBefore -le $g.ToolConditionAfter){throw 'Unpaid/non-native home resources'}
                if($pools.ContainsKey([string]$g.SourceId) -and [Math]::Abs($pools[[string]$g.SourceId]-$g.PoolBefore) -gt 0.001){throw 'Home source pool chain broken'};$pools[[string]$g.SourceId]=$g.PoolAfter
                $tool=@($op.Before|Where-Object Uid -eq $g.ToolUid);$afterTool=@($op.After|Where-Object Uid -eq $g.ToolUid)
                if($tool.Count -ne 1 -or $afterTool.Count -ne 1 -or $tool[0].Condition -ne $g.ToolConditionBefore -or $afterTool[0].Condition -ne $g.ToolConditionAfter){throw 'Home gather used a different tool UID'}
                foreach($name in @(@($op.Before.Shortname)+@($op.After.Shortname)|Sort-Object -Unique)){
                    $b=[double](($op.Before|Where-Object Shortname -eq $name|Measure-Object Amount -Sum).Sum)
                    $a=[double](($op.After|Where-Object Shortname -eq $name|Measure-Object Amount -Sum).Sum)
                    if($a-$b -ne $(if($name -eq $g.Resource){$g.Amount}else{0})){throw 'Native gather injected other items'}
                }
            }else{
                if($paid.ContainsKey([string]$op.Kind)){throw 'Duplicate home payment/build intent'};$paid[[string]$op.Kind]=$op
                Assert-FirstHomePayment $op
                if($op.Kind -eq 'CRAFT_TOOL'){$expected=$n.Recipe.Ingredients}
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
        $u=$h.Upkeep
        if((Get-FirstHomeEconomicKey $last) -cne (Get-FirstHomeEconomicKey $u.Before) -or
            (Get-FirstHomeEconomicKey $u.After) -cne (Get-FirstHomeEconomicKey $n.Inventory) -or
            (Get-FirstHomeEconomicKey $u.Before) -cne (Get-FirstHomeEconomicKey @(@($u.After)+@($u.TcInventory)))){throw 'TC transfer created/lost/replaced an item UID'}
        if($u.Authed -ne $true -or $u.Privilege -ne $true -or (Get-AvatarNumber $u.MinutesAfter 'upkeep minutes') -lt (Get-AvatarNumber $u.Period 'upkeep period') -or $u.MinutesAfter -le $u.MinutesBefore){throw 'Native upkeep/auth not proven'}
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
