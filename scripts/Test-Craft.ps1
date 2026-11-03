#Requires -Version 5.1
$ErrorActionPreference='Stop'
# Reuse the proven gather fixture; this invocation is offline only.
. (Join-Path $PSScriptRoot 'Test-Survival.ps1')
$validation=Join-Path $PSScriptRoot 'CraftValidation.ps1'
if (-not (Test-Path $validation)) { throw 'Craft result validator is required before live' }
. $validation
function New-CraftFixture {
    $n=New-Fixture
    $recipe=[pscustomobject]@{Shortname='fixture.tool';ItemId=-10;AmountToCreate=1;DefaultBlueprint=$true;Known=$true;Workbench=0;UserCraftable=$true;Allowed=$true;NeedsSteamItem=$false;NeedsSteamDLC=$false;RequireUnlockedItem=$false;Time=5;Ingredients=@(
        [pscustomobject]@{Shortname='wood';ItemId=1;Amount=7},[pscustomobject]@{Shortname='stones';ItemId=2;Amount=10})}
    $before=$n.Inventory | ConvertTo-Json | ConvertFrom-Json
    $after=$before | ConvertTo-Json | ConvertFrom-Json
    $after=@($after | Where-Object Shortname -ne 'stones');$after[1].Amount=3
    $output=[pscustomobject]@{Uid='crafted-1';Shortname='fixture.tool';Amount=1;Condition=100;MaxCondition=100}
    $after+=@($output)
    $context=[pscustomobject]@{ActorOwned=$true;Grounded=$true;BenchLevel=0}
    $deny=[pscustomobject]@{Intent='negative';Status='DENIED';Reason='MISSING_INGREDIENTS';Recipe=$recipe;Context=$context;Before=$n.StarterKit;After=$n.StarterKit;PoolBefore='same';PoolAfter='same';Debits=@();Output=$null}
    $paid=[pscustomobject]@{Intent='intent-1';Status='CRAFTED';Reason='PAID';Recipe=$recipe;Context=$context;Before=$before;After=$after;PoolBefore='same';PoolAfter='same';Debits=@(
        [pscustomobject]@{Uid='WOOD-item';Shortname='wood';ItemId=1;Before=10;Consumed=7;After=3},
        [pscustomobject]@{Uid='ORE-item';Shortname='stones';ItemId=2;Before=10;Consumed=10;After=0});Output=$output}
    $replay=[pscustomobject]@{Intent='intent-1';Status='DENIED';Reason='INTENT_ALREADY_USED';Recipe=$recipe;Context=$context;Before=$after;After=$after;PoolBefore='same';PoolAfter='same';Debits=@();Output=$null}
    $n.Mode='CRAFT';$n.Inventory=$after
    $n.ActorState | Add-Member NoteProperty CraftIntent 'intent-1'
    $n.ActorState | Add-Member NoteProperty CraftStatus 'CRAFTED'
    $n.ActorState | Add-Member NoteProperty ProductUid 'crafted-1'
    $n.ActorState | Add-Member NoteProperty Product 'fixture.tool'
    $n | Add-Member NoteProperty Crafting ([pscustomobject]@{Mechanism='SERVER_ACCOUNTED_CRAFT';Recipe=$recipe;Attempts=@($deny,$paid,$replay)})
    return $n
}
$n=New-CraftFixture;Assert-CraftResult $n
$accepted=@()
foreach($fault in @('recipe','selectedRecipe','selectedCost','missing','bench','blueprint','double','interrupted','multiplier','uid','condition','broken','emptyIntent','deniedMutation','deniedReason','fakeNegative')) {
    $n=New-CraftFixture
    switch($fault) {
        recipe {$n.Crafting.Attempts[1].Recipe=$null}
        selectedRecipe {$n.Crafting.Recipe=$null}
        selectedCost {$n.Crafting.Recipe=$n.Crafting.Recipe | ConvertTo-Json -Depth 8 | ConvertFrom-Json;$n.Crafting.Recipe.Ingredients[0].Amount=99}
        missing {$n.Crafting.Attempts[1].Debits[0].Consumed=6}
        bench {$n.Crafting.Attempts[1].Recipe.Workbench=1}
        blueprint {$n.Crafting.Attempts[1].Recipe.Known=$false}
        double {$n.Crafting.Attempts+=@($n.Crafting.Attempts[1])}
        interrupted {$n.Crafting.Attempts[1].Status='IRREVERSIBLE_PARTIAL'}
        multiplier {$n.Crafting.Attempts[1].Output.Amount=2}
        uid {$n.Inventory[2].Uid='different'}
        condition {$n.Inventory[2].Condition=101}
        broken {$n.Inventory[2].Condition=0}
        emptyIntent {$n.ActorState.CraftIntent='';$n.Crafting.Attempts[1].Intent='';$n.Crafting.Attempts[2].Intent=''}
        deniedMutation {$n.Crafting.Attempts[0].After=@($n.Inventory)}
        deniedReason {$n.Crafting.Attempts[0].Reason='WORKBENCH_REQUIRED'}
        fakeNegative {$n.Crafting.Attempts[0].Recipe=$null;$n.Crafting.Attempts[0].Reason='RECIPE_UNAVAILABLE'}
    }
    try {Must-Reject {Assert-CraftResult $n}} catch {$accepted+=$fault;Write-Output ('FAIL FIXTURE: '+$fault)}
}
if($accepted.Count){throw ('Invalid craft fixtures accepted: '+($accepted -join ', '))}
Write-Output 'PASS FIXTURE: recipe gates, exact partial/full UID debit, multiplier, failure, duplicate and condition conservation'
$n=New-CraftFixture;$n.Status='PARTIAL';$n.Persistence.Saved=$false
$n.Crafting.Attempts=@($n.Crafting.Attempts[0],$n.Crafting.Attempts[1]);$n.Crafting.Attempts[1].Status='IRREVERSIBLE_PARTIAL'
$n.Crafting.Attempts[1].Output=$null;$n.Inventory=@($n.Inventory | Where-Object Uid -ne 'crafted-1');$n.Crafting.Attempts[1].After=$n.Inventory
$n.ActorState.CraftStatus='IRREVERSIBLE_PARTIAL';$n.ActorState.ProductUid=$null
Assert-CraftResult $n
Write-Output 'PASS FIXTURE: irreversible paid interruption is PARTIAL with no award/rollback'
$n=New-CraftFixture
$n.Mode='RESTORE';$n.Harvests=@();$n.Crafting.Attempts=@();$n.Persistence=[pscustomobject]@{Restored=$true;Expected=$n.Inventory;ExpectedState=$n.ActorState}
Assert-CraftResult $n
$n.Crafting.Attempts=@([pscustomobject]@{Status='CRAFTED'});Must-Reject {Assert-CraftResult $n}
$n=New-CraftFixture;$n.Mode='RESTORE';$n.Crafting=$null
Must-Reject {Assert-SurvivalScenarioResult $n 'SURVIVAL_CRAFT'}
Write-Output 'PASS FIXTURE: crafted state restores without harvest/craft replay'
