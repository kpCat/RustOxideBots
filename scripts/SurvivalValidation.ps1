#Requires -Version 5.1
# Independent accounting/physical evidence checks; fixtures are never live proof.
function Get-SurvivalStateKey($state) {
    if (-not $state.ActorId -or -not $state.ToolUid -or -not $state.Goal) {throw 'Incomplete survivor state'}
    @($state.ActorId,$state.Goal,$state.ToolUid,(@($state.Completed)-join ','),(@($state.Rejected)-join ',')) -join '|'
}
function Get-SurvivalInventoryKey($items) {
    $null=Get-WorldInventoryKey $items
    (@($items | ForEach-Object { $_.Uid+'|'+$_.Shortname+'|'+$_.Amount+'|'+([double]$_.Condition).ToString('R',[Globalization.CultureInfo]::InvariantCulture)+'|'+([double]$_.MaxCondition).ToString('R',[Globalization.CultureInfo]::InvariantCulture) }) | Sort-Object) -join "`n"
}
function Assert-SurvivalResult($n) {
    if ($n.Status -notin @('GREEN','PARTIAL','BLOCKED','FAILED')) {throw 'Invalid survival status'}
    $key=Get-SurvivalInventoryKey $n.Inventory
    # An early honest blocker may have no actor or kit yet.
    if ($n.Status -eq 'BLOCKED' -and @($n.Harvests).Count -eq 0 -and @($n.Inventory).Count -eq 0) {return}
    $stateKey=Get-SurvivalStateKey $n.ActorState
    if ($n.ToolMode -ne 'SERVER_ACCOUNTED_TOOL' -or $n.NativeEquipment -ne 'NOT_NATIVE_EQUIPPED') {throw 'Unsupported/native equipment mislabel'}
    $kit=@($n.StarterKit)
    if ($kit.Count -ne 1 -or $kit[0].Shortname -ne 'rock' -or $kit[0].Amount -ne 1 -or $kit[0].Uid -ne $n.ActorState.ToolUid) {throw 'Invalid explicit starter kit'}
    if ($n.Mode -eq 'RESTORE') {
        if ($n.Status -eq 'GREEN' -and (-not $n.Persistence.Restored -or $key -ne (Get-SurvivalInventoryKey $n.Persistence.Expected) -or
            $stateKey -ne (Get-SurvivalStateKey $n.Persistence.ExpectedState))) {throw 'Survivor native snapshot/state restore mismatch'}
        return
    }
    if ($n.Mode -ne 'GATHER') {throw 'Unexpected survival mode'}
    $earned=@{};$transactions=@{};$pools=@{};$toolCondition=$null
    foreach ($h in @($n.Harvests)) {
        foreach($v in @($h.PoolBefore,$h.PoolAfter,$h.FractionBefore,$h.FractionAfter,$h.Amount,$h.Distance,$h.ToolCost,$h.ToolConditionBefore,$h.ToolConditionAfter)) {
            if($null -eq $v -or [double]::IsNaN([double]$v) -or [double]::IsInfinity([double]$v)){throw 'Non-finite harvest value'}
        }
        if (-not $h.Transaction -or $transactions.ContainsKey([string]$h.Transaction) -or -not $h.Uid -or $earned.ContainsKey([string]$h.Uid) -or
            $h.Uid -eq $kit[0].Uid -or $h.Amount -le 0 -or [Math]::Floor($h.Amount) -ne $h.Amount -or $h.PoolAfter -lt 1 -or
            [Math]::Abs(($h.PoolBefore-$h.PoolAfter)-$h.Amount) -gt 0.001 -or $h.FractionAfter -ge $h.FractionBefore -or
            $h.HealthAfter -gt $h.HealthBefore -or $h.Distance -lt 0 -or $h.Distance -gt 2.8 -or -not $h.LineOfSight -or -not $h.Grounded -or
            $h.PathStatus -ne 'PathComplete' -or $h.ToolUid -ne $n.ActorState.ToolUid -or $h.ToolCost -lt 0 -or
            $h.ToolConditionBefore -lt $h.ToolConditionAfter -or ($h.ToolHasCondition -and ($h.ToolConditionBefore -le 0 -or $h.ToolConditionAfter -le 0 -or $h.ToolConditionBefore-$h.ToolConditionAfter -le 0))) {throw 'Harvest debit/tool/reach contract failed'}
        if($null -ne $toolCondition -and [Math]::Abs($toolCondition-$h.ToolConditionBefore) -gt 0.001){throw 'Broken tool condition chain'}
        $toolCondition=$h.ToolConditionAfter
        if([Math]::Abs((Get-WorldDistance $h.Actor $h.SourcePosition)-$h.Distance) -gt 0.1){throw 'False harvest distance'}
        $atAction=@($n.Samples | Where-Object {[Math]::Abs($_.Time-$h.Time) -lt 0.001})
        if($atAction.Count -ne 1 -or (Get-WorldDistance $atAction[0].Position $h.Actor) -gt 0.1){throw 'Harvest actor is not on measured physical route'}
        $source=@($n.Sources | Where-Object Id -eq $h.SourceId)
        if($source.Count -ne 1 -or -not $source[0].Prefab -or -not $source[0].Type -or $source[0].Kind -ne $h.Kind -or
            $source[0].Provenance -ne $h.Provenance -or (Get-WorldDistance $source[0].Position $h.SourcePosition) -gt 0.1){throw 'Unproven source identity'}
        if($source[0].NativeProbe.NewDrops -ne 0 -or $source[0].NativeProbe.InitiatorPlayer -or
            [Math]::Abs($source[0].NativeProbe.PoolBefore-$source[0].NativeProbe.PoolAfter) -gt 0.001){throw 'Adapter could double-award native yield'}
        if ($pools.ContainsKey([string]$h.SourceId) -and [Math]::Abs($pools[[string]$h.SourceId]-$h.PoolBefore) -gt 0.001) {throw 'Broken source pool chain'}
        if ($h.Kind -notin @('WOOD','ORE') -or ($h.Kind -eq 'WOOD' -and $h.Resource -ne 'wood') -or ($h.Kind -eq 'ORE' -and $h.Resource -notin @('stones','metal.ore','sulfur.ore'))) {throw 'Wrong resource for need'}
        if ($n.Parts.($h.Kind) -eq 'GREEN' -and $h.Provenance -ne 'NATURAL') {throw 'Fixture cannot prove natural harvest'}
        $pools[[string]$h.SourceId]=$h.PoolAfter;$transactions[[string]$h.Transaction]=$true;$earned[[string]$h.Uid]=$h
    }
    if ($n.Conservation.Ok) {
        if (@($n.Conservation.Anomalies).Count -ne 0 -or @($n.Inventory).Count -ne 1+$earned.Count) {throw 'Unexplained inventory credit'}
        foreach($i in @($n.Inventory)) {
            $expected=if($i.Uid -eq $kit[0].Uid){$kit[0]}else{$earned[[string]$i.Uid]}
            $name=if($i.Uid -eq $kit[0].Uid){$expected.Shortname}else{$expected.Resource}
            if(-not $expected -or $i.Shortname -ne $name -or $i.Amount -ne $expected.Amount){throw 'Inventory differs from source debit'}
            if($i.Uid -eq $kit[0].Uid -and $null -ne $toolCondition -and [Math]::Abs($i.Condition-$toolCondition) -gt 0.001){throw 'Final tool condition differs from actions'}
        }
    }
    if ($n.Parts.NAVIGATION -eq 'GREEN') {
        if ($n.Backend -ne 'RustNavMeshAgent/RustNav' -or $n.ActorType -ne 'Rust.Ai.Gen2.ScientistNPC2') {throw 'Unexpected actor/navigation'}
        $samples=@($n.Samples);$sum=0.0
        if($samples.Count -lt 2 -or @($n.Legs).Count -eq 0){throw 'Missing physical movement'}
        for($i=1;$i -lt $samples.Count;$i++) {
            $dt=$samples[$i].Time-$samples[$i-1].Time;$step=Get-WorldDistance $samples[$i].Position $samples[$i-1].Position
            if($dt -le 0 -or $dt -gt 1.5 -or $step -gt 5 -or $step -gt 6*$dt+1){throw 'Discontinuous gather movement'}
            $sum+=$step
        }
        if($sum -lt 3 -or [Math]::Abs($sum-$n.TotalTraveled) -gt 0.1){throw 'False gather distance'}
        $end=$samples[0].Position;$legSum=0.0
        foreach($leg in @($n.Legs)) {
            if($leg.Status -ne 'ARRIVED' -or $leg.PathStatus -ne 'PathComplete' -or (Get-WorldDistance $leg.Start $end) -gt 0.1 -or
                (Get-WorldDistance $leg.End $leg.Target) -gt 0.65 -or [Math]::Abs((Get-WorldDistance $leg.Start $leg.End)-$leg.Net) -gt 0.1 -or $leg.Traveled -lt $leg.Net-0.1){throw 'Invalid complete-path leg'}
            $end=$leg.End;$legSum+=$leg.Traveled
        }
        if([Math]::Abs($legSum-$sum) -gt 0.15){throw 'Legs differ from physical samples'}
    }
    foreach($kind in @('WOOD','ORE')) {
        if($n.Parts.$kind -eq 'GREEN' -and @($n.Harvests | Where-Object Kind -eq $kind).Count -eq 0){throw 'Missing natural harvest category'}
    }
    if($n.Status -eq 'GREEN') {
        foreach($part in @('WOOD','ORE','TOOLS','NAVIGATION')){if($n.Parts.$part -ne 'GREEN'){throw 'GREEN survival has incomplete part'}}
        if(-not $n.Conservation.Ok -or -not $n.Persistence.Saved){throw 'Missing conservation/native snapshot'}
    }
}
function Assert-SurvivalRestoreBinding($prior,$proof,[string]$cacheKey,[string]$generation,[string]$state,[string]$savHash,[string]$snapshotHash,[string]$actorHash) {
    if ($prior.RunId -ne $proof.RunId -or $prior.Status -notin @('GREEN','PARTIAL') -or $prior.Shutdown -ne 'GRACEFUL' -or
        -not $prior.OwnedProcessAbsent -or -not $prior.PortsReleased -or -not $prior.FirewallRemoved -or -not $prior.Cache.Promoted -or
        $prior.Cache.Key -ne $cacheKey -or $proof.CacheKey -ne $cacheKey -or $proof.Generation -ne $generation -or $state -ne 'WARM' -or
        $proof.SavSHA256 -ne $savHash -or $proof.SnapshotSHA256 -ne $snapshotHash -or $prior.WorldInventorySHA256 -ne $snapshotHash -or
        $proof.ActorStateSHA256 -ne $actorHash -or $prior.ActorStateSHA256 -ne $actorHash -or
        $prior.Navigation.Mode -ne 'GATHER' -or -not $prior.Navigation.Persistence.Saved -or -not $prior.Navigation.Conservation.Ok){throw 'Unsafe/stale survival restore timeline'}
    Assert-SurvivalResult $prior.Navigation
}
function Write-SurvivalSaveProof([string]$runtime,[string]$cacheRoot) {
    Assert-ProbePlainTree $runtime;Assert-ProbePlainPath $cacheRoot
    $prior=Get-Content (Join-Path $runtime 'result.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $manifest=Get-Content (Join-Path $cacheRoot 'world-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if($manifest.Generation -notmatch '^world-[0-9a-f]{32}$' -or $prior.RunId -ne (Split-Path $runtime -Leaf) -or
        [IO.File]::ReadAllText((Join-Path $cacheRoot 'install\rustbots-test.marker')) -ne $prior.RunId){throw 'Not current completed survival run'}
    $sav=@($manifest.Files | Where-Object {$_.Name -match '^proceduralmap\.[0-9]+\.[0-9]+\.[0-9]+\.sav$'})
    if($sav.Count -ne 1){throw 'Missing exact saved world'}
    $cached=Join-Path $cacheRoot ($manifest.Generation+'\'+$sav[0].Name)
    $world=Join-Path $cacheRoot ('install\server\rustbots_probe_'+$manifest.Key.Substring(0,24)+'\'+$sav[0].Name)
    Assert-ProbePlainPath $cached;Assert-ProbePlainPath $world
    $hash=(Get-FileHash -LiteralPath $cached -Algorithm SHA256).Hash
    if($hash -ne $sav[0].SHA256 -or (Get-FileHash -LiteralPath $world -Algorithm SHA256).Hash -ne $hash){throw 'Completed world hash differs'}
    $ih=(Get-FileHash -LiteralPath (Join-Path $runtime 'inventory.bin') -Algorithm SHA256).Hash
    $ah=(Get-FileHash -LiteralPath (Join-Path $runtime 'actor-state.json') -Algorithm SHA256).Hash
    $proof=[pscustomobject]@{RunId=$prior.RunId;CacheKey=$manifest.Key;Generation=$manifest.Generation;SavName=$sav[0].Name;SavSHA256=$hash;SnapshotSHA256=$ih;ActorStateSHA256=$ah}
    Assert-SurvivalRestoreBinding $prior $proof $manifest.Key $manifest.Generation 'WARM' $hash $ih $ah
    $path=Join-Path $runtime 'world-proof.json'
    $stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try{$bytes=[Text.Encoding]::UTF8.GetBytes(($proof|ConvertTo-Json));$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
}
