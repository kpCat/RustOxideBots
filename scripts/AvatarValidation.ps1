#Requires -Version 5.1
# Reconstruct receipts independently. Synthetic inputs never establish live success.
. (Join-Path $PSScriptRoot 'WorldRoamValidation.ps1')

function Get-AvatarNumber($value,[string]$name) {
    if ($null -eq $value -or $value -is [bool] -or $value -is [string] -or $value -is [array]) { throw ('Missing/non-numeric avatar '+$name) }
    $number=[double]$value
    if ([double]::IsNaN($number) -or [double]::IsInfinity($number)) { throw ('Non-finite avatar '+$name) }
    $number
}
function Assert-AvatarUid($uid) {
    if ([string]$uid -notmatch '^[1-9][0-9]*$') { throw 'Missing/invalid native UID or network ID' }
}
function Get-AvatarInventoryKey($items,$owner,$containers,[switch]$AllowUnowned) {
    $seen=@{}
    $rows=@(foreach($item in @($items)) {
        if ($null -eq $item) { throw 'Missing native inventory row' }
        Assert-AvatarUid $item.Uid
        if (-not $AllowUnowned -or $null -ne $item.OwnerNetId) { Assert-AvatarUid $item.OwnerNetId }
        Assert-AvatarUid $item.ContainerUid
        $amount=Get-AvatarNumber $item.Amount 'item amount'
        $condition=Get-AvatarNumber $item.Condition 'item condition'
        $max=Get-AvatarNumber $item.MaxCondition 'item max condition'
        if ($seen.ContainsKey([string]$item.Uid) -or $amount -le 0 -or $amount -ne [Math]::Floor($amount) -or
            [string]$item.Shortname -notmatch '^[a-z0-9_.]+$' -or $condition -lt 0 -or $max -lt 0 -or $condition -gt $max -or
            ($null -ne $owner -and [string]$item.OwnerNetId -ne [string]$owner) -or
            ($null -ne $containers -and [string]$item.ContainerUid -notin $containers)) { throw 'Invalid/duplicate/foreign inventory row' }
        $seen[[string]$item.Uid]=$true
        [string]$item.Uid+'|'+$item.Shortname+'|'+$amount.ToString('R',[Globalization.CultureInfo]::InvariantCulture)+'|'+
            $condition.ToString('R',[Globalization.CultureInfo]::InvariantCulture)+'|'+$max.ToString('R',[Globalization.CultureInfo]::InvariantCulture)+'|'+$item.ContainerUid+'|'+$item.OwnerNetId
    })
    ($rows | Sort-Object) -join "`n"
}
function Assert-AvatarActor($nav) {
    $a=$nav.Actor
    Assert-AvatarUid $a.NetId
    if ($a.IsBasePlayer -isnot [bool] -or -not $a.IsBasePlayer -or $a.IsNpc -isnot [bool] -or -not $a.IsNpc -or
        $a.HasConnection -isnot [bool] -or $a.HasConnection -or $a.NativeBotId -isnot [bool] -or -not $a.NativeBotId -or
        [string]::IsNullOrWhiteSpace([string]$a.Type) -or $a.Type -match '(ScientistNPC2|BaseNPC2)$' -or
        [string]$a.Prefab -notmatch '^assets/.+\.prefab$' -or
        (Get-AvatarNumber $nav.SpawnCount 'spawn count') -ne 1) { throw 'Unproven single player-derived native NPC' }
}
function Assert-AvatarInventory($nav) {
    $inv=$nav.Inventory;$actor=[string]$nav.Actor.NetId
    if ($inv.Component -ne 'PlayerInventory' -or [string]$inv.ActorNetId -ne $actor -or $null -eq $inv.Before -or $null -eq $inv.After) { throw 'Missing same-actor PlayerInventory receipt' }
    $containers=@(foreach($name in @('Main','Belt','Wear')) {
        Assert-AvatarUid $inv.$name.Uid
        if ([string]$inv.$name.OwnerNetId -ne $actor) { throw 'Foreign PlayerInventory container' }
        [string]$inv.$name.Uid
    })
    if (@($containers|Select-Object -Unique).Count -ne 3) { throw 'Native inventory containers are not distinct' }
    $null=Get-AvatarInventoryKey $inv.Before $actor $containers
    $after=Get-AvatarInventoryKey $inv.After $actor $containers
    $fixture=$nav.Fixture
    if ($fixture.Kind -ne 'TEST_FIXTURE' -or (Get-AvatarNumber $fixture.Created 'fixture count') -ne 1 -or
        $fixture.Item.Shortname -ne 'rock' -or (Get-AvatarNumber $fixture.Item.Amount 'fixture amount') -ne 1 -or
        [string]$fixture.Item.ContainerUid -ne [string]$inv.Belt.Uid) { throw 'Missing single native belt rock TEST_FIXTURE' }
    $null=Get-AvatarInventoryKey @($fixture.Item) $actor $containers
    if (@($inv.Before | Where-Object { [string]$_.Uid -eq [string]$fixture.Item.Uid }).Count -ne 0 -or
        $after -cne (Get-AvatarInventoryKey (@($inv.Before)+@($fixture.Item)) $actor $containers)) { throw 'PlayerInventory must preserve defaults plus exactly one fixture' }
}
function Assert-AvatarEquipment($equipment,$nav) {
    $actor=[string]$nav.Actor.NetId;$uid=[string]$nav.Fixture.Item.Uid
    Assert-AvatarUid $equipment.HeldNetId
    if ([string]$equipment.ActorNetId -ne $actor -or [string]$equipment.RequestedUid -ne $uid -or
        [string]$equipment.ActiveUid -ne $uid -or [string]$equipment.ItemUid -ne $uid -or
        [string]$equipment.ContainerUid -ne [string]$nav.Inventory.Belt.Uid -or [string]$equipment.OwnerNetId -ne $actor -or
        [string]$equipment.HeldOwnerNetId -ne $actor -or [string]$equipment.HeldParentNetId -ne $actor -or
        [string]::IsNullOrWhiteSpace([string]$equipment.HeldType) -or [string]$equipment.HeldPrefab -notmatch '^assets/.+\.prefab$' -or
        $equipment.IsHeld -isnot [bool] -or -not $equipment.IsHeld) { throw 'Missing native same-UID active/held ownership proof' }
}
function Assert-AvatarNegative($nav) {
    $negative=@($nav.Negative)
    if ($negative.Count -ne 2 -or @($negative|Where-Object Kind -eq 'MISSING').Count -ne 1 -or
        @($negative|Where-Object Kind -eq 'FOREIGN').Count -ne 1) { throw 'Missing native activation guard classes' }
    $actor=[string]$nav.Actor.NetId;$uid=[string]$nav.Fixture.Item.Uid
    $containers=@([string]$nav.Inventory.Main.Uid,[string]$nav.Inventory.Belt.Uid,[string]$nav.Inventory.Wear.Uid)
    $key=Get-AvatarInventoryKey $nav.Inventory.After $actor $containers
    $requested=@{}
    foreach($n in $negative) {
        Assert-AvatarUid $n.RequestedUid
        if ($n.Mechanism -ne 'GUARD_BEFORE_NATIVE_UPDATE_UID' -or $n.Lookup -ne 'NATIVE_BELT_UID' -or
            $n.NativeApiCalled -isnot [bool] -or $n.NativeApiCalled -or
            $null -eq $n.PSObject.Properties['LookupItemUid'] -or $null -ne $n.LookupItemUid -or
            ($n.Kind -eq 'MISSING' -and ($n.MissingUidAbsentGlobally -isnot [bool] -or -not $n.MissingUidAbsentGlobally)) -or
            $requested.ContainsKey([string]$n.RequestedUid) -or
            @($nav.Inventory.After|Where-Object { [string]$_.Uid -eq [string]$n.RequestedUid }).Count -ne 0 -or
            $n.FoundInBelt -isnot [bool] -or $n.FoundInBelt -or $n.Accepted -isnot [bool] -or $n.Accepted -or
            [string]$n.BeforeActiveUid -ne $uid -or [string]$n.AfterActiveUid -ne $uid -or
            (Get-AvatarInventoryKey $n.Before $actor $containers) -cne $key -or (Get-AvatarInventoryKey $n.After $actor $containers) -cne $key) { throw 'Unsafe missing/foreign UID activation or inventory mutation' }
        $requested[[string]$n.RequestedUid]=$true
        if ($n.Kind -eq 'FOREIGN') {
            if ([string]$n.ForeignOwnerNetId -notmatch '^(container:)?[1-9][0-9]*$' -or [string]$n.ForeignOwnerNetId -eq $actor -or
                $n.ForeignBefore -isnot [string] -or [string]::IsNullOrWhiteSpace($n.ForeignBefore) -or
                $n.ForeignAfter -isnot [string] -or $n.ForeignBefore -cne $n.ForeignAfter) { throw 'Missing/changed native foreign item receipt' }
            $foreign=$n.ForeignBefore|ConvertFrom-Json
            if ($foreign -is [array] -or $null -eq $foreign -or [string]$foreign.Uid -ne [string]$n.RequestedUid -or
                [string]$foreign.OwnerNetId -eq $actor) { throw 'Foreign UID/owner does not match native item' }
            $null=Get-AvatarInventoryKey @($foreign) $null $null -AllowUnowned
            if ([string]$n.ForeignOwnerNetId -match '^container:([1-9][0-9]*)$') {
                if ([string]$foreign.ContainerUid -ne $Matches[1] -or $null -ne $foreign.OwnerNetId) { throw 'Foreign container ownership does not match item' }
            } elseif ([string]$foreign.OwnerNetId -ne [string]$n.ForeignOwnerNetId) { throw 'Foreign player ownership does not match item' }
        }
    }
}
function Assert-AvatarNavigation($nav) {
    if ($nav.Backend -ne 'RustNavMeshAgent/RustNav' -or $nav.Actor.Agent -ne 'Rust.Ai.Gen2.RustNavMeshAgent' -or
        (Get-AvatarNumber $nav.ManualPositionWrites 'manual position writes') -ne 0) { throw 'Avatar navigation requires RustNav without manual position writes' }
    Assert-AvatarEquipment $nav.EquipmentFinal $nav
    if ([string]$nav.EquipmentFinal.HeldNetId -ne [string]$nav.Equipment.HeldNetId) { throw 'Native held entity changed across travel' }
    $samples=@($nav.Samples);$actor=[string]$nav.Actor.NetId;$uid=[string]$nav.Fixture.Item.Uid;$held=[string]$nav.Equipment.HeldNetId
    if ($samples.Count -lt 2) { throw 'Missing continuous physical avatar samples' }
    $sum=0.0;$times=@();$cumulative=@(0.0)
    for($i=0;$i -lt $samples.Count;$i++) {
        $s=$samples[$i];$time=Get-AvatarNumber $s.Time 'sample time';$remaining=Get-AvatarNumber $s.Remaining 'sample remaining'
        $null=Get-WorldDistance $s.Position $s.Position
        if ($time -lt 0 -or [string]$s.ActorNetId -ne $actor -or [string]$s.ActiveUid -ne $uid -or
            [string]$s.HeldNetId -ne $held -or [string]$s.HeldOwnerNetId -ne $actor) { throw 'Sample actor/active/held continuity failed' }
        if ($s.PathStatus -notin @('PathComplete','PathInvalid') -or $s.HasPath -isnot [bool] -or $remaining -lt 0 -or
            ($i -eq 0 -and ($s.PathStatus -ne 'PathComplete' -or -not $s.HasPath))) { throw 'Missing/invalid native sample path state' }
        if ($i -gt 0) {
            $dt=$time-$times[-1];$step=Get-WorldDistance $samples[$i-1].Position $s.Position
            if ($dt -le 0 -or $dt -gt 1.5 -or $step -gt 5 -or $step -gt 6*$dt+1) { throw 'Discontinuous avatar physical movement' }
            $sum+=$step;$cumulative+=,$sum
        }
        $times+=,$time
    }
    $total=Get-AvatarNumber $nav.TotalTraveled 'total traveled'
    $legs=@($nav.Legs);$completed=Get-AvatarNumber $nav.CompletedLegs 'completed legs'
    if ($sum -lt 60 -or [Math]::Abs($sum-$total) -gt 0.1 -or $legs.Count -lt 2 -or $completed -ne $legs.Count) { throw 'Avatar navigation distance/count threshold failed' }
    $previousIndex=0;$legSum=0.0;$maxNet=0.0;$legNumber=0
    foreach($leg in $legs) {
        $legNumber++
        $startTime=Get-AvatarNumber $leg.StartTime 'leg start time';$endTime=Get-AvatarNumber $leg.EndTime 'leg end time'
        $startIndexes=@(0..($times.Count-1)|Where-Object { [Math]::Abs($times[$_]-$startTime) -le 0.001 })
        $endIndexes=@(0..($times.Count-1)|Where-Object { [Math]::Abs($times[$_]-$endTime) -le 0.001 })
        if ($startIndexes.Count -ne 1 -or $endIndexes.Count -ne 1) { throw 'Leg times do not match physical sample boundaries' }
        $startIndex=$startIndexes[0];$endIndex=$endIndexes[0]
        $net=Get-WorldDistance $leg.Start $leg.End
        $actual=$cumulative[$endIndex]-$cumulative[$startIndex]
        $declared=Get-AvatarNumber $leg.Traveled 'leg traveled';$declaredNet=Get-AvatarNumber $leg.Net 'leg net'
        $stuck=Get-AvatarNumber $leg.Stuck 'leg stuck';$repath=Get-AvatarNumber $leg.Repath 'leg repath'
        $plannedLength=Get-AvatarNumber $leg.PlannedPathLength 'planned path length'
        $stopping=Get-AvatarNumber $leg.StoppingDistance 'native stopping distance'
        $arrivalRemaining=Get-AvatarNumber $leg.ArrivalRemaining 'arrival remaining'
        $endSample=$samples[$endIndex];$arrivalDistance=Get-WorldDistance $leg.Target $leg.End
        $completeArrival=$leg.PathStatus -eq 'PathComplete' -and $leg.ArrivalHasPath -eq $true
        $consumedArrival=$leg.PathStatus -eq 'PathInvalid' -and $leg.ArrivalHasPath -eq $false -and
            $arrivalRemaining -le 0.01 -and $arrivalDistance -le $stopping+0.05 -and $stuck -eq 0 -and $repath -eq 0
        if ([string]$leg.ActorNetId -ne $actor -or (Get-AvatarNumber $leg.Leg 'leg number') -ne $legNumber -or
            $leg.Status -ne 'ARRIVED' -or $leg.PlannedPathStatus -ne 'PathComplete' -or $leg.IssuedPathStatus -ne 'PathComplete' -or
            $plannedLength -lt 28 -or $stopping -ne 1 -or $leg.ArrivalHasPath -isnot [bool] -or $arrivalRemaining -lt 0 -or
            (-not $completeArrival -and -not $consumedArrival) -or $leg.PathStatus -ne $endSample.PathStatus -or
            $leg.ArrivalHasPath -ne $endSample.HasPath -or $arrivalRemaining -ne [double]$endSample.Remaining -or
            $startIndex -ne $previousIndex -or $endIndex-$startIndex -lt 2 -or $endTime-$startTime -gt 70 -or
            (Get-WorldDistance $leg.Start $samples[$startIndex].Position) -gt 0.1 -or (Get-WorldDistance $leg.End $samples[$endIndex].Position) -gt 0.1 -or
            $arrivalDistance -gt 1.8 -or [Math]::Abs($net-$declaredNet) -gt 0.1 -or [Math]::Abs($actual-$declared) -gt 0.1 -or
            $declared -lt $net-0.1 -or $stuck -lt 0 -or $stuck -gt 1 -or $stuck -ne [Math]::Floor($stuck) -or
            $repath -lt 0 -or $repath -gt 1 -or $repath -ne [Math]::Floor($repath)) { throw 'False avatar path/arrival/leg chain receipt' }
        for($j=$startIndex+1;$j -lt $endIndex;$j++) {
            if ($samples[$j].PathStatus -ne 'PathComplete' -or -not $samples[$j].HasPath) { throw 'Avatar lost its complete native path before arrival' }
        }
        $previousIndex=$endIndex;$legSum+=$actual;$maxNet=[Math]::Max($maxNet,$net)
    }
    if ($previousIndex -ne $samples.Count-1 -or $maxNet -lt 20 -or [Math]::Abs($legSum-$sum) -gt 0.1) { throw 'Avatar legs do not account for physical journey' }
}
function Assert-AvatarResult($nav) {
    if ($nav.Status -notin @('GREEN','PARTIAL','BLOCKED')) { throw 'Invalid avatar status' }
    if ($null -ne $nav.Persistence -and $nav.Persistence -ne 'NOT_VERIFIED') { throw 'Avatar persistence is not verified by this probe' }
    $green=@()
    foreach($name in @('AVATAR','NAV','PLAYER_INVENTORY','HELD_ITEM','NEGATIVE')) {
        $part=$nav.Parts.$name
        if ($null -ne $part -and $part -notin @('GREEN','PARTIAL','NOT_VERIFIED')) { throw 'Invalid avatar part status' }
        if ($part -eq 'GREEN') { $green+=,$name }
        if ($nav.Status -eq 'GREEN' -and $part -ne 'GREEN') { throw 'GREEN avatar has an incomplete critical gate' }
    }
    if ($nav.Status -eq 'GREEN' -and $nav.Persistence -ne 'NOT_VERIFIED') { throw 'Missing explicit avatar persistence limitation' }
    if ($green.Count -eq 0) { return }
    Assert-AvatarActor $nav
    if (@($green|Where-Object {$_ -in @('NAV','PLAYER_INVENTORY','HELD_ITEM','NEGATIVE')}).Count) { Assert-AvatarInventory $nav }
    if (@($green|Where-Object {$_ -in @('NAV','HELD_ITEM','NEGATIVE')}).Count) { Assert-AvatarEquipment $nav.Equipment $nav }
    if ($green -contains 'NEGATIVE') { Assert-AvatarNegative $nav }
    if ($green -contains 'NAV') { Assert-AvatarNavigation $nav }
}
function Assert-AvatarSafety($report) {
    if ($report.Status -ne 'GREEN') { return }
    $pidValue=Get-AvatarNumber $report.ServerPid 'server PID'
    $exitCode=Get-AvatarNumber $report.ServerExitCode 'server exit code'
    if ($report.Shutdown -ne 'GRACEFUL' -or $report.OwnedProcessAbsent -isnot [bool] -or -not $report.OwnedProcessAbsent -or
        $report.PortsReleased -isnot [bool] -or -not $report.PortsReleased -or $report.FirewallRemoved -isnot [bool] -or -not $report.FirewallRemoved -or
        $report.AvatarCompletedSave -isnot [bool] -or -not $report.AvatarCompletedSave -or
        $pidValue -le 0 -or $pidValue -ne [Math]::Floor($pidValue) -or $exitCode -notin @(0,-1)) { throw 'GREEN avatar requires verified graceful owned-process and firewall cleanup' }
}
