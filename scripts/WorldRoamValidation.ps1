#Requires -Version 5.1
# Independently reconstruct receipts. Synthetic tests do not establish live success.
function Assert-WorldRoamRestoreBinding($prior, $proof, [string]$cacheKey, [string]$generation, [string]$state, [string]$savHash, [string]$snapshotHash) {
    if ($prior.RunId -ne $proof.RunId -or $prior.Status -notin @('GREEN','PARTIAL') -or $prior.Shutdown -ne 'GRACEFUL' -or
        -not $prior.OwnedProcessAbsent -or -not $prior.PortsReleased -or -not $prior.FirewallRemoved -or -not $prior.Cache.Promoted -or
        $prior.Cache.Key -ne $cacheKey -or $proof.CacheKey -ne $cacheKey -or $proof.Generation -ne $generation -or $state -ne 'WARM' -or
        $proof.SavSHA256 -ne $savHash -or $proof.SnapshotSHA256 -ne $snapshotHash -or $prior.WorldInventorySHA256 -ne $snapshotHash -or
        $prior.Navigation.Mode -ne 'JOURNEY' -or -not $prior.Navigation.Persistence.Saved -or -not $prior.Navigation.Conservation.Ok) { throw 'Unsafe/stale native inventory restore timeline' }
    Assert-WorldRoamResult $prior.Navigation
}

function Write-WorldRoamSaveProof([string]$runtime, [string]$cacheRoot, [switch]$LockHeld) {
    Assert-ProbePlainTree $runtime
    Assert-ProbePlainPath $cacheRoot
    $lock=$null
    try {
        if (-not $LockHeld) {
            $lock=[IO.File]::Open((Join-Path (Split-Path $cacheRoot -Parent) ('locks\'+(Split-Path $cacheRoot -Leaf)+'.lock')),[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
        }
        $prior=Get-Content (Join-Path $runtime 'result.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $manifest=Get-Content (Join-Path $cacheRoot 'world-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($manifest.Generation -notmatch '^world-[0-9a-f]{32}$' -or $prior.RunId -ne (Split-Path $runtime -Leaf) -or
            [IO.File]::ReadAllText((Join-Path $cacheRoot 'install\rustbots-test.marker')) -ne $prior.RunId) { throw 'Save proof is not the current completed test run' }
        $sav=@($manifest.Files | Where-Object { $_.Name -match '^proceduralmap\.[0-9]+\.[0-9]+\.[0-9]+\.sav$' })
        if ($sav.Count -ne 1) { throw 'Missing saved world for inventory proof' }
        $identity='rustbots_probe_'+$manifest.Key.Substring(0,24)
        $worldSav=Join-Path $cacheRoot ('install\server\'+$identity+'\'+$sav[0].Name)
        $cachedSav=Join-Path $cacheRoot ($manifest.Generation+'\'+$sav[0].Name)
        Assert-ProbePlainPath $worldSav; Assert-ProbePlainPath $cachedSav
        $hash=(Get-FileHash -LiteralPath $worldSav -Algorithm SHA256).Hash
        if ($hash -ne $sav[0].SHA256 -or (Get-FileHash -LiteralPath $cachedSav -Algorithm SHA256).Hash -ne $hash) { throw 'Completed world/cache save hash mismatch' }
        $snapshotHash=(Get-FileHash -LiteralPath (Join-Path $runtime 'inventory.bin') -Algorithm SHA256).Hash
        $proof=[ordered]@{ RunId=$prior.RunId; CacheKey=$manifest.Key; Generation=$manifest.Generation; SavName=$sav[0].Name; SavSHA256=$hash; SnapshotSHA256=$snapshotHash; ObservedUtc=[DateTime]::UtcNow.ToString('o') }
        Assert-WorldRoamRestoreBinding $prior ([pscustomobject]$proof) $manifest.Key $manifest.Generation 'WARM' $hash $snapshotHash
        $path=Join-Path $runtime 'world-proof.json'
        $stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try { $bytes=[Text.Encoding]::UTF8.GetBytes(($proof | ConvertTo-Json)); $stream.Write($bytes,0,$bytes.Length) } finally { $stream.Dispose() }
    } finally { if ($lock) { $lock.Dispose() } }
}

function Get-WorldDistance($a, $b) {
    if (@($a).Count -ne 3 -or @($b).Count -ne 3) { throw 'Invalid world vector' }
    $sum=0.0
    for ($i=0; $i -lt 3; $i++) {
        foreach ($v in @($a[$i],$b[$i])) {
            if ($null -eq $v -or [double]::IsNaN([double]$v) -or [double]::IsInfinity([double]$v)) { throw 'Non-finite world coordinate' }
        }
        $sum += [Math]::Pow(([double]$a[$i]-[double]$b[$i]),2)
    }
    [Math]::Sqrt($sum)
}
function Get-WorldInventoryKey($items) {
    $seen=@{}
    $rows=@(foreach ($item in @($items)) {
        if (-not $item.Uid -or $item.Amount -le 0 -or $seen.ContainsKey([string]$item.Uid)) { throw 'Invalid/duplicate inventory UID' }
        $seen[[string]$item.Uid]=$true
        [string]$item.Uid+'|'+$item.Shortname+'|'+$item.Amount
    })
    ($rows | Sort-Object) -join "`n"
}
function Assert-WorldRoamResult($nav) {
    if ($nav.Status -notin @('GREEN','PARTIAL','BLOCKED','FAILED')) { throw 'Invalid world status' }
    $inventoryKey=Get-WorldInventoryKey $nav.Inventory
    if ($nav.Mode -eq 'RESTORE') {
        if ($nav.Status -eq 'GREEN' -and (-not $nav.Persistence.Restored -or
            $inventoryKey -ne (Get-WorldInventoryKey $nav.Persistence.Expected) -or @($nav.Inventory).Count -eq 0)) {
            throw 'Native inventory restart mismatch'
        }
        return
    }
    if ($nav.Mode -ne 'JOURNEY') { throw 'Unexpected world mode' }
    $initial=@{}
    foreach ($item in @($nav.InitialInventory | Where-Object { $null -ne $_ })) { $initial[[string]$item.Uid]=$item }
    if ($initial.Count) {
        if (-not $nav.Persistence.Restored -or (Get-WorldInventoryKey $nav.InitialInventory) -ne (Get-WorldInventoryKey $nav.Persistence.RestoreExpected) -or
            (Get-WorldInventoryKey $nav.InitialInventory) -ne (Get-WorldInventoryKey $nav.Persistence.RestoreActual)) { throw 'Unproven initial native inventory' }
    }
    $transferred=@{}
    foreach ($t in @($nav.Transfers)) {
        if (-not $t.Uid -or $t.Amount -le 0 -or $t.Distance -gt 2.8 -or $t.Distance -lt 0 -or -not $t.LineOfSight -or
            $t.SourceBefore-$t.SourceAfter -ne $t.Amount -or $t.DestAfter-$t.DestBefore -ne $t.Amount -or
            $t.SourceAfter -ne 0 -or $t.DestBefore -ne 0 -or $transferred.ContainsKey([string]$t.Uid) -or $initial.ContainsKey([string]$t.Uid)) { throw 'Item transfer conservation/reach failed' }
        if ([Math]::Abs((Get-WorldDistance $t.Actor $t.SourcePosition)-$t.Distance) -gt 0.1) { throw 'False transfer distance' }
        $transferred[[string]$t.Uid]=$t
    }
    if ($nav.Conservation.Ok) {
        if (@($nav.Conservation.Anomalies).Count -ne 0 -or @($nav.Inventory).Count -ne $transferred.Count+$initial.Count) { throw 'Conservation anomaly' }
        foreach ($item in @($nav.Inventory)) {
            $t=if ($initial.ContainsKey([string]$item.Uid)) { $initial[[string]$item.Uid] } else { $transferred[[string]$item.Uid] }
            if (-not $t -or $item.Amount -ne $t.Amount -or $item.Shortname -ne $t.Shortname) { throw 'Destination inventory differs from transfers' }
        }
    }
    if ($nav.Parts.OPEN_TRAVEL -eq 'GREEN') {
        if ($nav.Backend -ne 'RustNavMeshAgent/RustNav' -or $nav.ActorType -ne 'Rust.Ai.Gen2.ScientistNPC2') { throw 'World journey requires Gen2/RustNav' }
        $sum=0.0
        $samples=@($nav.Samples)
        if ($samples.Count -lt 2) { throw 'Missing physical samples' }
        for ($i=1; $i -lt $samples.Count; $i++) {
            $dt=[double]$samples[$i].Time-[double]$samples[$i-1].Time
            $step=Get-WorldDistance $samples[$i].Position $samples[$i-1].Position
            if ($dt -le 0 -or $dt -gt 1.5 -or $step -gt 5 -or $step -gt 6*$dt+1) { throw 'Discontinuous world movement' }
            $sum += $step
        }
        if ($sum -lt 250 -or [Math]::Abs($sum-$nav.TotalTraveled) -gt 0.1 -or $nav.Road.EpisodeNet -lt 75 -or
            $nav.Road.Distance -gt 10 -or $nav.Road.PathStatus -ne 'PathComplete' -or $nav.Road.RoadIndex -lt 0 -or $nav.Road.SegmentIndex -lt 0) { throw 'World journey/road thresholds failed' }
        foreach ($leg in @($nav.Legs)) {
            $net=Get-WorldDistance $leg.Start $leg.End
            if ([Math]::Abs($net-$leg.Net) -gt 0.1 -or $leg.Traveled -lt $net-0.1 -or $leg.PathStatus -ne 'PathComplete') { throw 'Inconsistent world leg' }
            if ($leg.Status -eq 'ARRIVED' -and (Get-WorldDistance $leg.Target $leg.End) -gt 1.9) { throw 'False segment arrival' }
        }
        $roadSamples=@($samples | Where-Object Stage -eq 'ROAD')
        $roadLegs=@($nav.Legs | Where-Object Stage -eq 'ROAD')
        if ($roadSamples.Count -lt 2 -or $roadLegs.Count -eq 0) { throw 'Missing road samples/legs' }
        $roadSum=0.0; $leftRoad=$false
        foreach ($s in $samples) {
            if ($s.Stage -ne 'ROAD') { $leftRoad=$true } elseif ($leftRoad) { throw 'Road episode is not continuous' }
        }
        for ($i=1; $i -lt $roadSamples.Count; $i++) { $roadSum += Get-WorldDistance $roadSamples[$i-1].Position $roadSamples[$i].Position }
        $episode=Get-WorldDistance $roadSamples[0].Position $roadSamples[-1].Position
        if ($roadSum -lt 250 -or [Math]::Abs($episode-$nav.Road.EpisodeNet) -gt 0.1 -or
            (Get-WorldDistance $roadSamples[0].Position $nav.Road.EpisodeStart) -gt 0.1 -or
            (Get-WorldDistance $roadSamples[-1].Position $nav.Road.Arrival) -gt 0.1) { throw 'False road episode' }
        $previousEnd=$roadSamples[0].Position; $legSum=0.0
        foreach ($leg in $roadLegs) {
            if ($leg.Status -ne 'ARRIVED' -or (Get-WorldDistance $leg.Start $previousEnd) -gt 0.1) { throw 'Broken road leg chain' }
            $previousEnd=$leg.End; $legSum += $leg.Traveled
        }
        if ((Get-WorldDistance $previousEnd $nav.Road.Arrival) -gt 0.1 -or [Math]::Abs($legSum-$roadSum) -gt 0.1) { throw 'Road legs differ from physical samples' }
        # Reconstruct the actual projection onto the recorded real road segment.
        $a=$nav.Road.SegmentStart; $b=$nav.Road.SegmentEnd; $p=$nav.Road.Arrival
        $null=Get-WorldDistance $a $b
        $den=0.0; $dot=0.0
        for ($i=0; $i -lt 3; $i++) { $delta=$b[$i]-$a[$i]; $den += $delta*$delta; $dot += ($p[$i]-$a[$i])*$delta }
        $t=if ($den -eq 0) { 0.0 } else { [Math]::Max(0.0,[Math]::Min(1.0,[double]($dot/$den))) }
        $q=@(0..2 | ForEach-Object { $a[$_]+($b[$_]-$a[$_])*$t })
        $distance=Get-WorldDistance $p $q
        if ($distance -gt 10 -or [Math]::Abs($distance-$nav.Road.Distance) -gt 0.1 -or (Get-WorldDistance $q $nav.Road.Nearest) -gt 0.1) { throw 'False road geometry/distance' }
    }
    if ($nav.Parts.BARREL -eq 'GREEN') {
        if (-not $nav.Barrel.DestroyedByDamage -or @($nav.Barrel.Hits).Count -eq 0 -or @($nav.Barrel.Drops).Count -eq 0) { throw 'Missing native barrel damage/drop' }
        foreach ($hit in @($nav.Barrel.Hits)) {
            if ($hit.Distance -gt 2.8 -or -not $hit.LineOfSight -or $hit.Before -le $hit.After -or $hit.Damage -le 0) { throw 'False barrel hit' }
        }
        foreach ($t in @($nav.Transfers | Where-Object Kind -eq 'BARREL')) {
            $drop=@($nav.Barrel.Drops | Where-Object { $_.Uid -eq $t.Uid -and $_.Amount -eq $t.Amount -and $_.Shortname -eq $t.Shortname })
            if ($drop.Count -ne 1) { throw 'Barrel pickup not in native drops' }
        }
        if ($nav.Barrel.Hits[-1].After -ne 0 -or (Get-WorldInventoryKey $nav.Barrel.Before) -ne (Get-WorldInventoryKey $nav.Barrel.Drops)) { throw 'Native barrel death/drop mismatch' }
    }
    foreach ($kind in @('CRATE','BARREL')) {
        if ($nav.Parts.$kind -eq 'GREEN' -and @($nav.Transfers | Where-Object Kind -eq $kind).Count -eq 0) { throw 'GREEN part has no native pickup' }
    }
    if ($nav.Status -eq 'GREEN') {
        foreach ($part in @('OPEN_TRAVEL','CRATE','BARREL','INVENTORY')) {
            if ($nav.Parts.$part -ne 'GREEN') { throw 'GREEN world has incomplete part' }
        }
        foreach ($kind in @('CRATE','BARREL')) {
            if (@($nav.Transfers | Where-Object Kind -eq $kind).Count -eq 0) { throw 'Missing native loot class' }
        }
        if (-not $nav.Conservation.Ok -or -not $nav.Persistence.Saved) { throw 'Missing inventory save/conservation' }
    }
}
