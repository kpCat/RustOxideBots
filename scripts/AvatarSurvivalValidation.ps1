#Requires -Version 5.1
. (Join-Path $PSScriptRoot 'AvatarValidation.ps1')
function Get-AvatarSurvivalKey($rows) {
    (@(foreach($i in @($rows)) {
        Assert-AvatarUid $i.Uid
        foreach($v in @($i.Amount,$i.Condition,$i.MaxCondition,$i.Slot)){ $null=Get-AvatarNumber $v 'inventory' }
        if($i.Amount -le 0 -or $i.Amount -ne [Math]::Floor($i.Amount) -or $i.Condition -lt 0 -or $i.Condition -gt $i.MaxCondition -or $i.Slot -lt 0 -or $i.Role -notin @('MAIN','BELT','WEAR')){throw 'Invalid native item'}
        "$($i.Uid)|$($i.Shortname)|$($i.Amount)|$($i.Condition)|$($i.MaxCondition)|$($i.Role)|$($i.Slot)|$($i.ContainerUid)"
    }) | Sort-Object) -join "`n"
}
function Assert-AvatarSurvivalRows($rows,$n) {
    $null=Get-AvatarSurvivalKey $rows
    if(@($rows.Uid|Select-Object -Unique).Count -ne @($rows).Count){throw 'Duplicate receipt UID'}
    $slots=@{}
    foreach($i in @($rows)) {
        $c=@($n.Containers|Where-Object Role -eq $i.Role);$slot=$i.Role+':'+$i.Slot
        if($c.Count -ne 1 -or $i.OwnerNetId -ne $n.Actor.NetId -or $i.ContainerUid -ne $c[0].Uid -or $slots.ContainsKey($slot)){throw 'Foreign/overlapping receipt item'}
        $slots[$slot]=$true
    }
}
function Assert-AvatarSurvivalEquipment($n) {
    $e=$n.Equipment;$a=[string]$n.Actor.NetId;$uid=[string]$n.State.ProductUid
    Assert-AvatarUid $e.HeldNetId
    if($e.ActorNetId -ne $a -or $e.ActiveUid -ne $uid -or $e.ItemUid -ne $uid -or $e.HeldItemUid -ne $uid -or $e.OwnerNetId -ne $a -or
        $e.HeldOwnerNetId -ne $a -or $e.HeldParentNetId -ne $a -or $e.HeldType -ne 'BaseMelee' -or $e.IsHeld -ne $true -or
        $n.State.ActiveUid -ne $uid -or $n.EquipmentChecks -lt 3){throw 'Crafted native held ownership/selection missing'}
    $product=@($n.Inventory | Where-Object Uid -eq $uid)
    if($product.Count -ne 1 -or $product[0].Shortname -ne 'stonehatchet' -or $product[0].Role -ne 'BELT' -or $product[0].Amount -ne 1 -or $product[0].Condition -le 0){throw 'Crafted UID absent from real belt'}
}
function Assert-AvatarSurvivalResult($n) {
    if($n.Status -notin @('GREEN','PARTIAL','BLOCKED','FAILED')){throw 'Invalid bridge status'}
    if($n.Conservation.EconomicFailure -eq $true -and $n.Status -ne 'FAILED'){throw 'Economic failure cannot be PARTIAL/GREEN'}
    if($n.Status -ne 'GREEN'){return}
    Assert-AvatarActor $n
    if($n.Actor.Type -ne 'ScientistNPC' -or $n.ManualPositionWrites -ne 0 -or $n.State.ActorId -notmatch '^avatar-007-[0-9a-f]{32}$' -or
        $n.State.Goal -ne 'COMPLETE' -or $n.State.CraftStatus -ne 'CRAFTED' -or -not $n.State.CraftIntent -or
        -not $n.Persistence.Saved -or -not $n.Conservation.Ok){throw 'Incomplete avatar survival state'}
    $containers=@($n.Containers)
    if($containers.Count -ne 3 -or @($containers.Role|Select-Object -Unique).Count -ne 3 -or @($containers.Uid|Select-Object -Unique).Count -ne 3){throw 'Invalid PlayerInventory containers'}
    foreach($c in $containers){if($c.OwnerNetId -ne $n.Actor.NetId){throw 'Foreign container'}}
    Assert-AvatarSurvivalRows $n.Inventory $n
    if(@($n.Inventory.Uid|Select-Object -Unique).Count -ne @($n.Inventory).Count){throw 'Duplicate item UID'}
    foreach($i in @($n.Inventory)) {
        $c=@($containers|Where-Object Role -eq $i.Role)
        if($c.Count -ne 1 -or $i.OwnerNetId -ne $n.Actor.NetId -or $i.ContainerUid -ne $c[0].Uid){throw 'Nonowned native inventory'}
    }
    if(@($n.Normalization.AfterStrip).Count -ne 0 -or $n.Normalization.RemovedAbsent -ne $true){throw 'Default loadout leaked into economy'}
    Assert-AvatarSurvivalEquipment $n
    foreach($kind in @('MISSING_UID','FOREIGN_UID','MISSING_INGREDIENTS','RECIPE_UNAVAILABLE','WORKBENCH_REQUIRED','DUPLICATE_INTENT')) {
        if($n.Mode -eq 'RESTORE' -and $kind -notin @('MISSING_UID','FOREIGN_UID')){continue}
        $neg=@($n.Negatives|Where-Object Kind -eq $kind)
        if($neg.Count -ne 1 -or $neg[0].Accepted -ne $false -or $neg[0].Unchanged -ne $true){throw ('Missing/no-op negative '+$kind)}
        if($neg[0].PSObject.Properties['Before'] -and (Get-AvatarSurvivalKey $neg[0].Before) -cne (Get-AvatarSurvivalKey $neg[0].After)){throw 'Denied action changed inventory'}
    }
    if($n.Mode -eq 'RESTORE') {
        if(-not $n.Persistence.Restored -or @($n.Harvests).Count -ne 0 -or $null -ne $n.Craft -or @($n.StarterKit).Count -ne 0){throw 'Restore replayed gameplay'}
        Assert-AvatarSurvivalRestore $n
        return
    }
    if($n.Mode -ne 'JOURNEY' -or @($n.StarterKit).Count -ne 1 -or $n.StarterKit[0].Shortname -ne 'rock' -or $n.StarterKit[0].Uid -ne $n.State.ToolUid){throw 'Unaccounted starter kit'}
    $recipe=$n.Recipe
    if($recipe.Shortname -ne 'stonehatchet' -or $recipe.AmountToCreate -ne 1 -or -not $recipe.Known -or $recipe.Workbench -ne 0 -or @($recipe.Ingredients).Count -ne 2){throw 'Invalid loaded recipe'}
    $balance=@{};foreach($i in $n.StarterKit){$balance[$i.Shortname]=[int]$i.Amount}
    $condition=[double]$n.StarterKit[0].Condition;$last=$n.StarterKit;$pools=@{}
    foreach($h in @($n.Harvests)) {
        Assert-AvatarSurvivalRows $h.Before $n;Assert-AvatarSurvivalRows $h.After $n
        foreach($v in @($h.Amount,$h.PoolBefore,$h.PoolAfter,$h.ToolConditionBefore,$h.ToolConditionAfter,$h.Distance)){$null=Get-AvatarNumber $v 'harvest'}
        if($h.Provenance -ne 'NATURAL' -or $h.Amount -le 0 -or $h.PoolBefore-$h.PoolAfter -lt $h.Amount-0.01 -or $h.PoolAfter -le 0 -or
            $h.ToolConditionBefore -ne $condition -or $h.ToolConditionAfter -ge $condition -or $h.ToolConditionAfter -le 0 -or
            $h.Distance -gt 2.8 -or -not $h.LineOfSight -or -not $h.Grounded -or $h.Resource -notin @('wood','stones')){throw 'Invalid natural debit/tool/reach'}
        if($pools.ContainsKey([string]$h.SourceId) -and [Math]::Abs($pools[[string]$h.SourceId]-$h.PoolBefore) -gt 0.01){throw 'Source pool chain broken'}
        $observed=@($n.Samples|Where-Object {[Math]::Abs($_.Time-$h.Time) -lt 0.1 -and (Get-WorldDistance $_.Position $h.Actor) -lt 0.1})
        if($h.ActorNetId -ne $n.Actor.NetId -or $observed.Count -ne 1 -or $h.NewDrops -ne 0 -or
            [Math]::Abs((Get-WorldDistance $h.Actor $h.SourcePosition)-$h.Distance) -gt 0.05 -or
            @($n.Legs|Where-Object SourceId -eq $h.SourceId).Count -eq 0 -or -not $h.SourcePrefab -or
            ($h.Resource -eq 'wood' -and $h.SourceType -ne 'TreeEntity') -or ($h.Resource -eq 'stones' -and $h.SourceType -ne 'OreResourceEntity')){throw 'Harvest is not on measured natural route'}
        if($h.Mechanism -eq 'NATIVE_PLAYER_GATHER') {
            if(-not $h.InitiatorPlayer -or -not $h.WeaponOwned -or -not $h.DidGather -or $h.AdapterCredit -ne 0){throw 'Fake native gather or double credit'}
        } elseif($h.Mechanism -eq 'SERVER_ACCOUNTED_TOOL') {
            if($h.AdapterCredit -ne $h.Amount -or -not $h.NativeProbeZero -or [Math]::Abs($h.PoolBefore-$h.PoolAfter-$h.Amount) -gt 0.01){throw 'Unverified adapter debit'}
        } else {throw 'Unknown gather mechanism'}
        if((Get-AvatarSurvivalKey $last) -cne (Get-AvatarSurvivalKey $h.Before)){throw 'Inventory harvest chain broken'}
        $toolBefore=@($h.Before|Where-Object Uid -eq $n.State.ToolUid);$toolAfter=@($h.After|Where-Object Uid -eq $n.State.ToolUid)
        if($toolBefore.Count -ne 1 -or $toolAfter.Count -ne 1 -or $toolBefore[0].Condition -ne $h.ToolConditionBefore -or $toolAfter[0].Condition -ne $h.ToolConditionAfter -or
            $toolAfter[0].MaxCondition -ne $n.StarterKit[0].MaxCondition){throw 'Native tool condition receipt differs'}
        $before=@{};foreach($i in @($h.Before)){$before[$i.Shortname]+=$i.Amount}
        $after=@{};foreach($i in @($h.After)){$after[$i.Shortname]+=$i.Amount}
        foreach($name in @('rock','wood','stones')){if([int]$after[$name]-[int]$before[$name] -ne $(if($name -eq $h.Resource){$h.Amount}else{0})){throw 'Unexpected harvest credit'}}
        if(@($h.After|Where-Object {$_.Shortname -notin @('rock','wood','stones')}).Count){throw 'Harvest injected item'}
        $balance[$h.Resource]+=[int]$h.Amount;$condition=[double]$h.ToolConditionAfter;$last=$h.After;$pools[[string]$h.SourceId]=$h.PoolAfter
    }
    if(@($n.Harvests.Resource|Select-Object -Unique).Count -ne 2){throw 'Both natural resources required'}
    $craft=$n.Craft
    Assert-AvatarSurvivalRows $craft.Before $n;Assert-AvatarSurvivalRows $craft.After $n
    $paid=@($craft.After|Where-Object Uid -eq $n.State.ProductUid)
    $held=@($n.Inventory|Where-Object Uid -eq $n.State.ProductUid)
    if($paid.Count -ne 1 -or (Get-AvatarSurvivalKey $paid) -cne (Get-AvatarSurvivalKey @($craft.Output))){throw 'Paid output absent from craft inventory'}
    foreach($field in @('Uid','Shortname','Amount','Condition','MaxCondition','OwnerNetId')){
        if($paid[0].$field -ne $held[0].$field){throw 'Crafted item changed during native belt transfer'}
    }
    if($craft.Mechanism -notin @('NATIVE_PLAYER_CRAFT','SERVER_ACCOUNTED_CRAFT') -or (Get-AvatarSurvivalKey $last) -cne (Get-AvatarSurvivalKey $craft.Before) -or
        $craft.Output.Uid -ne $n.State.ProductUid -or @($craft.Before|Where-Object Uid -eq $craft.Output.Uid).Count -ne 0 -or
        ($craft.Mechanism -eq 'NATIVE_PLAYER_CRAFT' -and (-not $craft.NativeAccepted -or $craft.QueueAfter -ne 0 -or $craft.Elapsed -le 0))){throw 'Craft provenance/queue invalid'}
    foreach($cost in $recipe.Ingredients) {
        $debits=@($craft.Debits|Where-Object Shortname -eq $cost.Shortname)
        if($cost.Amount -le 0 -or ($debits|Measure-Object Consumed -Sum).Sum -ne $cost.Amount){throw 'Recipe payment mismatch'}
        foreach($d in $debits) {
            $b=@($craft.Before|Where-Object Uid -eq $d.Uid);$a=@($craft.After|Where-Object Uid -eq $d.Uid)
            if($b.Count -ne 1 -or $b[0].Role -eq 'WEAR' -or $b[0].Shortname -ne $d.Shortname -or $d.Consumed -le 0 -or
                $b[0].Amount-$(if($a.Count){$a[0].Amount}else{0}) -ne $d.Consumed){throw 'Exact native UID debit invalid'}
        }
        $balance[$cost.Shortname]-=[int]$cost.Amount
    }
    $balance['stonehatchet']=1
    foreach($name in $balance.Keys){if([int]($n.Inventory|Where-Object Shortname -eq $name|Measure-Object Amount -Sum).Sum -ne $balance[$name]){throw 'Final resource balance mismatch'}}
    if(@($n.Inventory|Where-Object {$_.Shortname -notin $balance.Keys}).Count -or ($n.Inventory|Where-Object Uid -eq $n.State.ToolUid).Condition -ne $condition){throw 'Unexplained output/lost tool wear'}
    # Equipment moves only the paid output, preserving all other rows.
    if((Get-AvatarSurvivalKey @($craft.After|Where-Object Uid -ne $n.State.ProductUid)) -cne (Get-AvatarSurvivalKey @($n.Inventory|Where-Object Uid -ne $n.State.ProductUid))){throw 'Postcraft inventory mutation'}
    $sum=0.0;$samples=@($n.Samples)
    for($j=1;$j -lt $samples.Count;$j++) {
        $dt=[double]$samples[$j].Time-$samples[$j-1].Time;$step=Get-WorldDistance $samples[$j].Position $samples[$j-1].Position
        if($dt -le 0 -or $dt -gt 1.5 -or $step -gt 5 -or $step -gt 6*$dt+1){throw 'Discontinuous avatar trace'};$sum+=$step
    }
    foreach($s in $samples){if($s.ActorNetId -ne $n.Actor.NetId){throw 'Foreign actor in physical trace'}}
    if($sum -lt 3 -or [Math]::Abs($sum-$n.TotalTraveled) -gt 0.15 -or @($n.Legs.SourceId|Select-Object -Unique).Count -lt 2){throw 'Missing physical routes to resources'}
    foreach($leg in @($n.Legs)){
        $first=@($samples|Where-Object {[Math]::Abs($_.Time-$leg.StartTime) -lt 0.1 -and (Get-WorldDistance $_.Position $leg.Start) -lt 0.1})
        $lastSample=@($samples|Where-Object {[Math]::Abs($_.Time-$leg.EndTime) -lt 0.1 -and (Get-WorldDistance $_.Position $leg.End) -lt 0.1})
        if($leg.Status -ne 'ARRIVED' -or $leg.Planned -ne 'PathComplete' -or $leg.IssuedSpeed -le 0 -or (Get-WorldDistance $leg.End $leg.Target) -gt 1.05 -or
            $first.Count -ne 1 -or $lastSample.Count -ne 1 -or $leg.EndTime -le $leg.StartTime){throw 'Invalid route/speed rearm'}
    }
}
function Assert-AvatarSurvivalRestart($prior,$now) {
    Assert-AvatarSurvivalResult $now
    # A guarded partial restore is not evidence of mutation or a false GREEN.
    # Preserve its original status/reason; require exact equality only for a GREEN claim.
    if($now.Status -ne 'GREEN'){return}
    if($now.Mode -ne 'RESTORE' -or ($prior.State|ConvertTo-Json -Compress) -cne ($now.State|ConvertTo-Json -Compress) -or
        (Get-AvatarSurvivalKey $prior.Inventory) -cne (Get-AvatarSurvivalKey $now.Inventory)){throw 'Native restart identity/UID/condition/slot mismatch'}
    if((Get-AvatarSurvivalContainerKey $prior.Containers) -cne (Get-AvatarSurvivalContainerKey $now.Containers)){throw 'Native restart containers differ'}
    Assert-AvatarSurvivalRestore $now
}
function Get-AvatarSurvivalContainerKey($containers) {
    if(@($containers).Count -ne 3 -or (@($containers.Role|Sort-Object) -join ',') -cne 'BELT,MAIN,WEAR' -or
        @($containers.Uid|Select-Object -Unique).Count -ne 3){throw 'Incomplete native containers'}
    (@(foreach($c in $containers){Assert-AvatarUid $c.Uid;$c.Role+'|'+$c.Uid})|Sort-Object) -join ','
}
function Assert-AvatarSurvivalRestore($n) {
    $a=$n.RestoreAudit
    if((Get-AvatarSurvivalContainerKey $a.SourceContainers) -cne (Get-AvatarSurvivalContainerKey $n.Containers)){throw 'Loaded native containers differ'}
    foreach($c in $a.SourceContainers) {
        if($c.Capacity -le 0 -or $c.Capacity -ne ($n.Containers|Where-Object Role -eq $c.Role).Capacity){throw 'Loaded container capacity differs'}
    }
    if($a.Stage -ne 'COMPLETE' -or -not $a.LoadCalled -or -not $a.IncomingAbsent -or -not $a.PreLoadHeldZero -or -not $a.SourceUnchanged -or
        -not $a.ForeignItemsUnchanged -or -not $a.ForeignEntitiesUnchanged -or $a.ParentPasses -ne 2 -or -not $a.HeldStable -or
        $a.ItemsAfter-$a.ItemsBefore -ne @($n.Inventory).Count){throw 'Unverified native restore lifecycle/conservation'}
    foreach($rows in @($a.SourceInventory,$a.NativeBefore,$a.Loaded)) {
        if((Get-AvatarSurvivalKey $rows) -cne (Get-AvatarSurvivalKey $n.Inventory)){throw 'Restore ledger differs'}
    }
    $refs=@($a.TransientRefs);$held=@($a.HeldItems)
    $expected=@($n.State.ToolUid,$n.State.ProductUid)|Sort-Object
    if($refs.Count -ne 2 -or @($refs.ItemUid|Select-Object -Unique).Count -ne 2 -or
        @($refs.SavedHeldNetId|Select-Object -Unique).Count -ne 2 -or
        $held.Count -ne 2 -or @($held.HeldNetId|Select-Object -Unique).Count -ne 2 -or
        (@($refs.ItemUid|Sort-Object) -join ',') -cne ($expected -join ',') -or
        (@($held.Uid|Sort-Object) -join ',') -cne ($expected -join ',')){throw 'Incomplete/duplicate native held ledger'}
    foreach($ref in $refs) {
        Assert-AvatarUid $ref.SavedHeldNetId
        if(($ref.Before|ConvertTo-Json -Depth 8 -Compress) -cne ($ref.After|ConvertTo-Json -Depth 8 -Compress) -or
            $ref.Before.NetId -ne $ref.SavedHeldNetId -or @($n.Inventory|Where-Object Uid -eq $ref.ItemUid).Count -ne 1){throw 'Old entity mutated or unbound reference'}
    }
    foreach($h in $held) {
        Assert-AvatarUid $h.HeldNetId
        if($h.HeldNetId -in $refs.SavedHeldNetId -or $h.HeldItemUid -ne $h.Uid -or $h.OwnerNetId -ne $n.Actor.NetId -or
            $h.ParentNetId -ne $n.Actor.NetId -or @($n.Inventory|Where-Object {$_.Uid -eq $h.Uid -and $_.Role -eq 'BELT'}).Count -ne 1){throw 'Stale/foreign/missing native held entity'}
    }
    if(($held|Where-Object Uid -eq $n.State.ProductUid).HeldNetId -ne $n.Equipment.HeldNetId){throw 'Active held differs from loaded product'}
    $samples=@($n.EquipmentSamples)
    if($samples.Count -lt 3 -or $samples[-1].Time-$samples[0].Time -lt 1){throw 'Missing native tick observations'}
    for($j=0;$j -lt $samples.Count;$j++) {
        if(($samples[$j].Equipment|ConvertTo-Json -Compress) -cne ($n.Equipment|ConvertTo-Json -Compress) -or
            ($j -gt 0 -and $samples[$j].Time -le $samples[$j-1].Time)){throw 'Native active/held changed across ticks'}
    }
}
function Assert-AvatarSurvivalBinding($p,$proof,$key,$gen,$state,$sav,$inv,$actor) {
    if($p.Status -ne 'GREEN' -or $p.Shutdown -ne 'GRACEFUL' -or -not $p.OwnedProcessAbsent -or -not $p.PortsReleased -or -not $p.FirewallRemoved -or
        -not $p.Cache.Promoted -or $p.Cache.Key -ne $key -or $proof.RunId -ne $p.RunId -or $proof.CacheKey -ne $key -or
        $proof.Generation -ne $gen -or $state -ne 'WARM' -or $proof.SavSHA256 -ne $sav -or $proof.SnapshotSHA256 -ne $inv -or
        $p.WorldInventorySHA256 -ne $inv -or $proof.ActorStateSHA256 -ne $actor -or $p.ActorStateSHA256 -ne $actor){throw 'Unsafe/stale avatar survival binding'}
}
function Write-AvatarSurvivalSaveProof($runtime,$cacheRoot) {
    Assert-ProbePlainTree $runtime;Assert-ProbePlainPath $cacheRoot
    $p=Get-Content (Join-Path $runtime 'result.json') -Raw -Encoding UTF8|ConvertFrom-Json
    $m=Get-Content (Join-Path $cacheRoot 'world-manifest.json') -Raw -Encoding UTF8|ConvertFrom-Json
    if($p.RunId -ne (Split-Path $runtime -Leaf) -or $m.Generation -notmatch '^world-[0-9a-f]{32}$' -or
        [IO.File]::ReadAllText((Join-Path $cacheRoot 'install\rustbots-test.marker')) -ne $p.RunId){throw 'Not current completed avatar run'}
    Assert-AvatarSurvivalResult $p.Navigation
    $files=@($m.Files|Where-Object {$_.Name -match '^proceduralmap\.[0-9]+\.[0-9]+\.[0-9]+\.sav$'})
    if($files.Count -ne 1){throw 'Missing exact saved world'}
    $file=$files[0];$cached=Join-Path $cacheRoot ($m.Generation+'\'+$file.Name)
    $world=Join-Path $cacheRoot ('install\server\rustbots_probe_'+$m.Key.Substring(0,24)+'\'+$file.Name)
    Assert-ProbePlainPath $cached;Assert-ProbePlainPath $world
    $sav=(Get-FileHash -LiteralPath $cached -Algorithm SHA256).Hash
    if($sav -ne $file.SHA256 -or (Get-FileHash -LiteralPath $world -Algorithm SHA256).Hash -ne $sav){throw 'Saved world differs'}
    $inv=(Get-FileHash -LiteralPath (Join-Path $runtime 'inventory.bin') -Algorithm SHA256).Hash
    $actor=(Get-FileHash -LiteralPath (Join-Path $runtime 'actor-state.json') -Algorithm SHA256).Hash
    $proof=[pscustomobject]@{RunId=$p.RunId;CacheKey=$m.Key;Generation=$m.Generation;SavName=$file.Name;SavSHA256=$sav;SnapshotSHA256=$inv;ActorStateSHA256=$actor}
    Assert-AvatarSurvivalBinding $p $proof $m.Key $m.Generation 'WARM' $sav $inv $actor
    $stream=[IO.File]::Open((Join-Path $runtime 'world-proof.json'),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try{$bytes=[Text.Encoding]::UTF8.GetBytes(($proof|ConvertTo-Json));$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
}
