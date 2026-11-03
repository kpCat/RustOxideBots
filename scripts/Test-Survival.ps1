#Requires -Version 5.1
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'WorldRoamValidation.ps1')
. (Join-Path $PSScriptRoot 'SurvivalValidation.ps1')
# FIXTURE contract inputs only: these are not Rust/live evidence.
function New-Fixture {
    $kit=@([pscustomobject]@{ Uid='rock-1'; Shortname='rock'; Amount=1; Condition=100; MaxCondition=100 })
    $hits=@(foreach ($kind in @('WOOD','ORE')) {
        [pscustomobject]@{ Transaction=$kind+'-1'; Kind=$kind; Provenance='NATURAL'; SourceId=$kind+'-source';
            Resource=$(if ($kind -eq 'WOOD') {'wood'} else {'stones'}); PoolBefore=100; PoolAfter=90; FractionBefore=1; FractionAfter=0.9;
            HealthBefore=100; HealthAfter=95; Damage=5; Amount=10; Uid=$kind+'-item';
            ToolUid='rock-1'; ToolConditionBefore=100; ToolConditionAfter=95; ToolHasCondition=$true; ToolCost=5;
            Time=5; Distance=2; LineOfSight=$true; Grounded=$true; PathStatus='PathComplete'; Actor=@(10,5,0); SourcePosition=@(12,5,0) }
    })
    $hits[1].ToolConditionBefore=95;$hits[1].ToolConditionAfter=90
    $items=@([pscustomobject]@{Uid='rock-1';Shortname='rock';Amount=1;Condition=90;MaxCondition=100})+@(foreach($h in $hits){ [pscustomobject]@{Uid=$h.Uid;Shortname=$h.Resource;Amount=$h.Amount;Condition=0;MaxCondition=0} })
    $state=[pscustomobject]@{ActorId='survivor-fixture';Goal='CARRY_SAVE';ToolUid='rock-1';Completed=@('WOOD','ORE');Rejected=@()}
    [pscustomobject]@{Status='GREEN';Mode='GATHER';ActorType='Rust.Ai.Gen2.ScientistNPC2';Backend='RustNavMeshAgent/RustNav';
        ToolMode='SERVER_ACCOUNTED_TOOL';NativeEquipment='NOT_NATIVE_EQUIPPED';ActorState=$state;StarterKit=$kit;Inventory=$items;
        Parts=[pscustomobject]@{WOOD='GREEN';ORE='GREEN';TOOLS='GREEN';NAVIGATION='GREEN'};
        Harvests=$hits;Sources=@(foreach($h in $hits){[pscustomobject]@{Id=$h.SourceId;Kind=$h.Kind;Provenance='NATURAL';Type='fixture-type';Prefab='fixture-prefab';Position=$h.SourcePosition;NativeProbe=[pscustomobject]@{PoolBefore=100;PoolAfter=100;HealthBefore=105;HealthAfter=100;NewDrops=0;InitiatorPlayer=$false}}});
        Samples=@([pscustomobject]@{Time=1;Position=@(0,5,0)},[pscustomobject]@{Time=2;Position=@(3,5,0)},[pscustomobject]@{Time=3;Position=@(6,5,0)},[pscustomobject]@{Time=4;Position=@(9,5,0)},[pscustomobject]@{Time=5;Position=@(10,5,0)});TotalTraveled=10;
        Legs=@([pscustomobject]@{Status='ARRIVED';PathStatus='PathComplete';Start=@(0,5,0);End=@(10,5,0);Target=@(10,5,0);Traveled=10;Net=10});
        Conservation=[pscustomobject]@{Ok=$true;Anomalies=@()};Persistence=[pscustomobject]@{Saved=$true;Restored=$false} }
}
function Must-Reject([scriptblock]$action) {
    $rejected=$false;try { & $action }catch {$rejected=$true}
    if(-not $rejected){throw 'Invalid survival fixture accepted'}
}
$n=New-Fixture
Assert-SurvivalResult $n
foreach($field in @('PoolAfter','Amount','Uid','Distance','LineOfSight','Grounded','ToolUid','ToolConditionAfter','Provenance')) {
    $n=New-Fixture
    switch($field) {
        PoolAfter {$n.Harvests[0].PoolAfter=100}
        Amount {$n.Harvests[0].Amount=20}
        Uid {$n.Harvests[1].Uid=$n.Harvests[0].Uid}
        Distance {$n.Harvests[0].Distance=30}
        LineOfSight {$n.Harvests[0].LineOfSight=$false}
        Grounded {$n.Harvests[0].Grounded=$false}
        ToolUid {$n.Harvests[0].ToolUid='missing'}
        ToolConditionAfter {$n.Harvests[0].ToolConditionAfter=101}
        Provenance {$n.Harvests[0].Provenance='FIXTURE'}
    }
    Must-Reject {Assert-SurvivalResult $n}
}
$n=New-Fixture;$n.NativeEquipment='NATIVE_EQUIPPED';Must-Reject {Assert-SurvivalResult $n}
$n=New-Fixture;$n.Sources[0].NativeProbe.NewDrops=1;Must-Reject {Assert-SurvivalResult $n}
$n=New-Fixture;$n.Harvests[0].Actor=@(100,5,0);$n.Harvests[0].SourcePosition=@(102,5,0);$n.Sources[0].Position=@(102,5,0)
Must-Reject {Assert-SurvivalResult $n}
Write-Output 'PASS FIXTURE: source debit, UID, range/LOS/ground, tool and honest adapter contracts'
$n=New-Fixture;$n.Samples[2].Position=@(600,5,0);Must-Reject {Assert-SurvivalResult $n}
$n=New-Fixture;$n.Legs[0].PathStatus='PathPartial';Must-Reject {Assert-SurvivalResult $n}
$n=New-Fixture;$n.Status='PARTIAL';$n.Parts.WOOD='PARTIAL';$n.Parts.ORE='PARTIAL';$n.Harvests=@();$n.Inventory=$n.StarterKit
Assert-SurvivalResult $n
Write-Output 'PASS FIXTURE: false movement rejected; honest no-yield partial accepted'
$n=New-Fixture
$prior=[pscustomobject]@{RunId='fixture';Status='GREEN';Shutdown='GRACEFUL';OwnedProcessAbsent=$true;PortsReleased=$true;FirewallRemoved=$true;Cache=[pscustomobject]@{Key='key';Promoted=$true};Navigation=$n;WorldInventorySHA256='inventory-hash';ActorStateSHA256='state-hash'}
$proof=[pscustomobject]@{RunId='fixture';CacheKey='key';Generation='generation';SavSHA256='save-hash';SnapshotSHA256='inventory-hash';ActorStateSHA256='state-hash'}
Assert-SurvivalRestoreBinding $prior $proof 'key' 'generation' 'WARM' 'save-hash' 'inventory-hash' 'state-hash'
Must-Reject {Assert-SurvivalRestoreBinding $prior $proof 'key' 'generation' 'WARM' 'stale-save' 'inventory-hash' 'state-hash'}
Must-Reject {Assert-SurvivalRestoreBinding $prior $proof 'key' 'generation' 'WARM' 'save-hash' 'corrupt' 'state-hash'}
Must-Reject {Assert-SurvivalRestoreBinding $prior $proof 'key' 'generation' 'WARM' 'save-hash' 'inventory-hash' 'corrupt'}
$prior.Shutdown='FORCED_OWNED_JOB';Must-Reject {Assert-SurvivalRestoreBinding $prior $proof 'key' 'generation' 'WARM' 'save-hash' 'inventory-hash' 'state-hash'}
$r=[pscustomobject]@{Status='GREEN';Mode='RESTORE';Inventory=$n.Inventory;ActorState=$n.ActorState;StarterKit=$n.StarterKit;ToolMode=$n.ToolMode;NativeEquipment=$n.NativeEquipment;Persistence=[pscustomobject]@{Restored=$true;Expected=$n.Inventory;ExpectedState=$n.ActorState}}
Assert-SurvivalResult $r
$r.ActorState=$r.ActorState | ConvertTo-Json | ConvertFrom-Json;$r.ActorState.ToolUid='wrong';Must-Reject {Assert-SurvivalResult $r}
Write-Output 'PASS FIXTURE: exact saved world, corrupt snapshots and actor/tool restart identity checked'

# Native Gen2 FSM has its own work queue; Unity enabled=false does not stop it.
$source=Get-Content (Join-Path $PSScriptRoot '..\src\plugins\RustBotsSurvival.cs') -Raw
if($source -notmatch 'fsm\.SetFsmActive\(false\)' -or $source -match 'fsm\.enabled\s*=') {throw 'Survival must stop the native FSM scheduler, not only the Unity component'}
Write-Output 'PASS STATIC: native Gen2 scheduler is explicitly deactivated'
