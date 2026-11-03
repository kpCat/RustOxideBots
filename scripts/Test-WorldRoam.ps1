#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'WorldRoamValidation.ps1')

# Synthetic contract inputs only; never reported as live evidence.
$samples = @(0..200 | ForEach-Object {
    [pscustomobject]@{ Time=$_*0.5; Position=@(($_*1.5),5,0); Stage='ROAD' }
})
$transfer = [pscustomobject]@{ Uid='test-item'; Shortname='synthetic'; Amount=3; Kind='CRATE';
    Actor=@(300,5,0); SourcePosition=@(301.8,5,0); Distance=1.8; LineOfSight=$true; SourceBefore=3; SourceAfter=0; DestBefore=0; DestAfter=3 }
$nav = [pscustomobject]@{ Status='GREEN'; Mode='JOURNEY'; Samples=$samples; TotalTraveled=300;
    Backend='RustNavMeshAgent/RustNav'; ActorType='Rust.Ai.Gen2.ScientistNPC2';
    Road=[pscustomobject]@{ Distance=0; EpisodeNet=300; Arrival=@(300,5,0); EpisodeStart=@(0,5,0); Nearest=@(300,5,0); SegmentStart=@(300,5,-5); SegmentEnd=@(300,5,5); PathStatus='PathComplete'; RoadIndex=0; SegmentIndex=1 };
    Parts=[pscustomobject]@{ OPEN_TRAVEL='GREEN'; CRATE='GREEN'; BARREL='GREEN'; INVENTORY='GREEN' };
    Legs=@([pscustomobject]@{ Stage='ROAD'; Status='ARRIVED'; PathStatus='PathComplete'; Start=@(0,5,0); End=@(300,5,0); Target=@(300,5,0); Traveled=300; Net=300 });
    Transfers=@($transfer,([pscustomobject]@{ Uid='test-drop'; Shortname='synthetic'; Amount=1; Kind='BARREL'; Actor=@(300,5,0); SourcePosition=@(301,5,0); Distance=1; LineOfSight=$true; SourceBefore=1; SourceAfter=0; DestBefore=0; DestAfter=1 }));
    Inventory=@([pscustomobject]@{ Uid='test-item'; Shortname='synthetic'; Amount=3 },[pscustomobject]@{ Uid='test-drop'; Shortname='synthetic'; Amount=1 });
    Barrel=[pscustomobject]@{ DestroyedByDamage=$true; Hits=@([pscustomobject]@{ Before=20; After=0; Distance=1.5; LineOfSight=$true; Damage=20 }); Before=@([pscustomobject]@{ Uid='test-drop'; Shortname='synthetic'; Amount=1 }); Drops=@([pscustomobject]@{ Uid='test-drop'; Shortname='synthetic'; Amount=1 }) };
    Conservation=[pscustomobject]@{ Ok=$true; Anomalies=@() }; Persistence=[pscustomobject]@{ Saved=$true }
}
Assert-WorldRoamResult $nav
function Must-Reject([scriptblock]$action) {
    $rejected=$false
    try { & $action } catch { $rejected=$true }
    if (-not $rejected) { throw 'Invalid world receipt accepted' }
}
$nav.Samples[50].Position=@(500,5,0)
Must-Reject { Assert-WorldRoamResult $nav }
$nav.Samples[50].Position=@(75,5,0)
$nav.Road.EpisodeNet=2
Must-Reject { Assert-WorldRoamResult $nav }
$nav.Road.EpisodeNet=300
$nav.Road.Nearest=@(900,5,0)
Must-Reject { Assert-WorldRoamResult $nav }
$nav.Road.Nearest=@(300,5,0)
$originalLegs=$nav.Legs
$nav.Legs=@()
Must-Reject { Assert-WorldRoamResult $nav }
$nav.Legs=$originalLegs
$nav.Road.Arrival=@(75,5,0); $nav.Road.EpisodeNet=75
Must-Reject { Assert-WorldRoamResult $nav }
$nav.Road.Arrival=@(300,5,0); $nav.Road.EpisodeNet=300
Write-Output 'PASS: physical samples and road episode contract reject false progress'

$transfer.SourceAfter=3
Must-Reject { Assert-WorldRoamResult $nav }
$transfer.SourceAfter=0
$transfer.Distance=30
Must-Reject { Assert-WorldRoamResult $nav }
$transfer.Distance=1.8
$nav.Inventory[0].Amount=6
Must-Reject { Assert-WorldRoamResult $nav }
$nav.Inventory[0].Amount=3
Assert-WorldRoamResult $nav
Write-Output 'PASS: UID/amount balance, remote transfer and duplicate amount rejected'

$partial=$nav | ConvertTo-Json -Depth 10 | ConvertFrom-Json
$partial.Status='PARTIAL'; $partial.Transfers=@($partial.Transfers[0]); $partial.Inventory=@($partial.Inventory[0])
Must-Reject { Assert-WorldRoamResult $partial }
$partial.Parts.BARREL='PARTIAL'; $partial.Barrel.Drops=@()
Assert-WorldRoamResult $partial
$nav.Backend='RustNavMeshAgent/Unity'
Must-Reject { Assert-WorldRoamResult $nav }
$nav.Backend='RustNavMeshAgent/RustNav'
Write-Output 'PASS: each GREEN part needs its own native transfer; partial barrel preserves crate inventory'

$resume=$nav | ConvertTo-Json -Depth 10 | ConvertFrom-Json
$initial=@([pscustomobject]@{ Uid='earlier-native'; Shortname='synthetic'; Amount=2 })
$resume | Add-Member InitialInventory $initial
$resume.Inventory=@($resume.Inventory)+@([pscustomobject]@{ Uid='earlier-native'; Shortname='synthetic'; Amount=2 })
$resume.Persistence | Add-Member Restored $true
$resume.Persistence | Add-Member RestoreExpected $initial
$resume.Persistence | Add-Member RestoreActual $initial
Assert-WorldRoamResult $resume
$resume.Inventory[-1].Amount=4
Must-Reject { Assert-WorldRoamResult $resume }
Write-Output 'PASS: resumed journey preserves previous native inventory independently of new loot'

$restart=[pscustomobject]@{ Status='GREEN'; Mode='RESTORE'; Persistence=[pscustomobject]@{ Restored=$true; Expected=$nav.Inventory }; Inventory=$nav.Inventory }
Assert-WorldRoamResult $restart
$restart.Inventory=@([pscustomobject]@{ Uid='wrong'; Shortname='synthetic'; Amount=3 })
Must-Reject { Assert-WorldRoamResult $restart }
Write-Output 'PASS: restart requires exact restored native UID/shortname/amount inventory'

$prior=[pscustomobject]@{ RunId='synthetic-run'; Status='GREEN'; Shutdown='GRACEFUL'; OwnedProcessAbsent=$true; PortsReleased=$true; FirewallRemoved=$true;
    Cache=[pscustomobject]@{ Key='synthetic-key'; Promoted=$true }; Navigation=$nav; WorldInventorySHA256='snapshot-hash' }
$proof=[pscustomobject]@{ RunId='synthetic-run'; CacheKey='synthetic-key'; Generation='synthetic-generation'; SavSHA256='saved-world-hash'; SnapshotSHA256='snapshot-hash' }
Assert-WorldRoamRestoreBinding $prior $proof 'synthetic-key' 'synthetic-generation' 'WARM' 'saved-world-hash' 'snapshot-hash'
Must-Reject { Assert-WorldRoamRestoreBinding $prior $proof 'synthetic-key' 'synthetic-generation' 'WARM' 'older-world-hash' 'snapshot-hash' }
Must-Reject { Assert-WorldRoamRestoreBinding $prior $proof 'synthetic-key' 'synthetic-generation' 'COLD' 'saved-world-hash' 'snapshot-hash' }
$prior.Status='FAILED'
Must-Reject { Assert-WorldRoamRestoreBinding $prior $proof 'synthetic-key' 'synthetic-generation' 'WARM' 'saved-world-hash' 'snapshot-hash' }
Write-Output 'PASS: restore binds inventory to exact saved world and rejects stale/failed timeline'
