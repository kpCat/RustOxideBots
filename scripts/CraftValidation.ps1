#Requires -Version 5.1
# Independent receipt reconciliation, never a substitute for live runtime evidence.
function Assert-CraftRecipe($r) {
    if (-not $r -or -not $r.Shortname -or -not $r.ItemId -or $r.AmountToCreate -le 0 -or
        [Math]::Floor($r.AmountToCreate) -ne $r.AmountToCreate -or @($r.Ingredients).Count -eq 0 -or $null -eq $r.Workbench -or
        $r.Workbench -lt 0 -or [Math]::Floor($r.Workbench) -ne $r.Workbench -or $null -eq $r.Time -or
        [double]::IsNaN($r.Time) -or [double]::IsInfinity($r.Time) -or $r.Time -lt 0) {throw 'Missing/invalid actual recipe'}
    $ids=@{};$names=@{}
    foreach($c in @($r.Ingredients)) {
        if(-not $c.Shortname -or -not $c.ItemId -or $ids.ContainsKey([string]$c.ItemId) -or $names.ContainsKey([string]$c.Shortname) -or
            $null -eq $c.Amount -or [double]::IsNaN($c.Amount) -or [double]::IsInfinity($c.Amount) -or $c.Amount -le 0 -or [Math]::Floor($c.Amount) -ne $c.Amount){throw 'Invalid recipe cost'}
        $ids[[string]$c.ItemId]=$true;$names[[string]$c.Shortname]=$true
    }
}
function Get-CraftRecipeKey($r) {
    Assert-CraftRecipe $r
    @($r.Shortname,$r.ItemId,$r.AmountToCreate,$r.Workbench,$r.DefaultBlueprint,$r.Known,$r.UserCraftable,$r.Allowed,
        $r.NeedsSteamItem,$r.NeedsSteamDLC,$r.RequireUnlockedItem,$r.Time,(@($r.Ingredients | ForEach-Object {$_.Shortname+':'+$_.ItemId+':'+$_.Amount} | Sort-Object)-join ',')) -join '|'
}
function Assert-SurvivalScenarioResult($n,[string]$scenario) {
    if($scenario -eq 'SURVIVAL_CRAFT'){Assert-CraftResult $n}
    elseif($scenario -eq 'SURVIVAL_GATHER' -and -not $n.Crafting){Assert-SurvivalResult $n}
    else{throw 'Survival scenario/report mismatch'}
}
function Assert-CraftResult($n) {
    if($n.Crafting.Mechanism -ne 'SERVER_ACCOUNTED_CRAFT'){throw 'Unsupported craft mechanism'}
    $null=Get-SurvivalInventoryKey $n.Inventory
    if($n.Status -eq 'BLOCKED' -and @($n.Inventory).Count -eq 0){return}
    if($n.Mode -eq 'RESTORE') {
        if($n.Status -eq 'GREEN') {
            Assert-CraftRecipe $n.Crafting.Recipe
            if(-not $n.Persistence.Restored -or (Get-SurvivalInventoryKey $n.Inventory) -ne (Get-SurvivalInventoryKey $n.Persistence.Expected) -or
                (Get-SurvivalStateKey $n.ActorState) -ne (Get-SurvivalStateKey $n.Persistence.ExpectedState) -or $n.ActorState.CraftStatus -ne 'CRAFTED' -or
                -not $n.ActorState.CraftIntent -or @($n.Crafting.Attempts).Count -ne 0 -or @($n.Harvests).Count -ne 0){throw 'Craft restore changed/replayed completion'}
            $output=@($n.Inventory | Where-Object Uid -eq $n.ActorState.ProductUid)
            if($output.Count -ne 1 -or $output[0].Shortname -ne $n.ActorState.Product -or $output[0].Shortname -ne $n.Crafting.Recipe.Shortname -or
                $output[0].Amount -ne $n.Crafting.Recipe.AmountToCreate){throw 'Crafted item missing after restore'}
        }
        return
    }
    if($n.Mode -ne 'CRAFT'){throw 'Unexpected crafting mode'}
    if($n.Status -eq 'GREEN'){Assert-CraftRecipe $n.Crafting.Recipe}
    $paid=@($n.Crafting.Attempts | Where-Object {$_.Status -in @('CRAFTED','IRREVERSIBLE_PARTIAL')})
    if($paid.Count -gt 1){throw 'Multiple irreversible craft attempts'}
    $success=@($paid | Where-Object Status -eq 'CRAFTED')
    $negative=0;$replay=0;$seenPaid=$false
    foreach($a in @($n.Crafting.Attempts)) {
        $beforeKey=Get-SurvivalInventoryKey $a.Before;$afterKey=Get-SurvivalInventoryKey $a.After
        if(-not $a.PoolBefore -or $a.PoolBefore -ne $a.PoolAfter){throw 'Craft changed source pools'}
        if($a.Status -eq 'DENIED') {
            if($beforeKey -ne $afterKey -or @($a.Debits).Count -ne 0 -or $a.Output){throw 'Denied attempt mutated property'}
            switch($a.Reason) {
                MISSING_INGREDIENTS {
                    Assert-CraftRecipe $a.Recipe
                    $missing=@($a.Recipe.Ingredients | Where-Object {
                        $cost=$_; $sum=(@($a.Before | Where-Object Shortname -eq $cost.Shortname) | Measure-Object Amount -Sum).Sum
                        $sum -lt $cost.Amount
                    })
                    if($missing.Count -eq 0){throw 'Fake missing-ingredient denial'}
                    $negative++
                }
                BLUEPRINT_UNKNOWN {Assert-CraftRecipe $a.Recipe;if($a.Recipe.Known){throw 'Fake blueprint denial'};$negative++}
                WORKBENCH_REQUIRED {Assert-CraftRecipe $a.Recipe;if($a.Recipe.Workbench -le $a.Context.BenchLevel){throw 'Fake bench denial'};$negative++}
                INTENT_ALREADY_USED {
                    if(-not $seenPaid -or $a.Intent -ne $paid[0].Intent -or $beforeKey -ne (Get-SurvivalInventoryKey $paid[0].After)){throw 'Unproven duplicate intent denial'}
                    $replay++
                }
                RECIPE_UNAVAILABLE {if($a.Recipe){throw 'Fake unavailable recipe denial'}}
                UNSUPPORTED_RECIPE_POLICY {
                    Assert-CraftRecipe $a.Recipe
                    if($a.Recipe.UserCraftable -and $a.Recipe.Allowed -and -not $a.Recipe.NeedsSteamItem -and -not $a.Recipe.NeedsSteamDLC -and -not $a.Recipe.RequireUnlockedItem){throw 'Fake unsupported policy denial'}
                }
                INVALID_ACTOR_CONTEXT {if($a.Context.ActorOwned -and $a.Context.Grounded){throw 'Fake actor context denial'}}
                default {throw 'Unverified denial reason'}
            }
            continue
        }
        if($a.Status -notin @('CRAFTED','IRREVERSIBLE_PARTIAL')){throw 'Unknown craft attempt status'}
        $seenPaid=$true;Assert-CraftRecipe $a.Recipe
        $r=$a.Recipe
        if((Get-CraftRecipeKey $r) -ne (Get-CraftRecipeKey $n.Crafting.Recipe)){throw 'Selected and paid recipe differ'}
        if(-not $r.DefaultBlueprint -or -not $r.Known -or -not $r.UserCraftable -or -not $r.Allowed -or $r.NeedsSteamItem -or
            $r.NeedsSteamDLC -or $r.RequireUnlockedItem -or $r.Workbench -ne 0 -or -not $a.Context.ActorOwned -or -not $a.Context.Grounded){throw 'Craft bypassed recipe/context gate'}
        $rows=@{};$used=@{};$totals=@{}
        foreach($i in @($a.Before)){$rows[[string]$i.Uid]=$i | ConvertTo-Json | ConvertFrom-Json}
        foreach($d in @($a.Debits)) {
            $cost=@($r.Ingredients | Where-Object {$_.ItemId -eq $d.ItemId -and $_.Shortname -eq $d.Shortname})
            $item=$rows[[string]$d.Uid]
            if($cost.Count -ne 1 -or -not $item -or $used.ContainsKey([string]$d.Uid) -or $item.Shortname -ne $d.Shortname -or
                $item.Amount -ne $d.Before -or $d.Consumed -le 0 -or [Math]::Floor($d.Consumed) -ne $d.Consumed -or
                $d.After -lt 0 -or $d.Before-$d.Consumed -ne $d.After){throw 'Wrong/double native UID debit'}
            $used[[string]$d.Uid]=$true;$totals[[string]$d.ItemId]+=$d.Consumed
            if($d.After -eq 0){$rows.Remove([string]$d.Uid)}else{$item.Amount=$d.After}
        }
        if($a.Status -eq 'CRAFTED') {
            foreach($cost in @($r.Ingredients)){if($totals[[string]$cost.ItemId] -ne $cost.Amount){throw 'Craft cost not paid exactly'}}
            $out=$a.Output
            $null=Get-SurvivalInventoryKey @($out)
            if(-not $out.Uid -or @($a.Before | Where-Object Uid -eq $out.Uid).Count -ne 0 -or $out.Shortname -ne $r.Shortname -or
                $out.Amount -ne $r.AmountToCreate -or ($out.MaxCondition -gt 0 -and $out.Condition -le 0)){throw 'Invalid crafted output/multiplier/UID'}
            $rows[[string]$out.Uid]=$out
        } elseif($a.Output -or $n.Status -eq 'GREEN'){throw 'Interrupted craft cannot be GREEN'}
        if((Get-SurvivalInventoryKey @($rows.Values)) -ne $afterKey){throw 'Craft inventory conservation mismatch'}
    }
    if($n.Status -eq 'GREEN') {
        if($success.Count -ne 1 -or $negative -lt 1 -or $replay -ne 1 -or $n.ActorState.CraftStatus -ne 'CRAFTED' -or -not $n.ActorState.CraftIntent -or
            $n.ActorState.CraftIntent -ne $success[0].Intent -or $n.ActorState.ProductUid -ne $success[0].Output.Uid -or
            $n.ActorState.Product -ne $success[0].Recipe.Shortname -or (Get-SurvivalInventoryKey $n.Inventory) -ne (Get-SurvivalInventoryKey $success[0].After)) {throw 'Incomplete craft/denial/idempotence evidence'}
    }
    # Validate original natural inputs and physical navigation using the unchanged 004 ledger.
    $g=$n | ConvertTo-Json -Depth 32 | ConvertFrom-Json
    $g.Crafting=$null;$g.Mode='GATHER'
    if($paid.Count -eq 1){$g.Inventory=$paid[0].Before}
    Assert-SurvivalResult $g
}
