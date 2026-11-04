# API_GATE — не угадывать причину NavSample(false)

**Текущий known failure:** 012 smoke3, `HomeBuildStand` after own native TC/auth, before paid Door. `NavSample(p,out foot)` returns false. This is NOT proof that RustNav failed; combined operation = `DefaultNavmesh.SamplePosition` AND `Ground`.

Read / instrument exact installed API and log at least:

- Native `SamplePosition`: input point, XYZ, radius/extents, backend RustNav, returned success and sampled point; `agent.isOnNavMesh`, live `HasPendingTiles`, agent position, current path.
- Downward ray physics: all relevant hit colliders including own foundation/doorway, actual ground normal, terrain height and vertical error; whether erroneous ray hit a building or the NPC itself; water; independent physical floor support when inside building.
- Capsule check: physical overlaps with npc, own blocks, TC, natural and foreign entities; classify rather than discarding all collider hits indiscriminately. Never globally disable colliders.
- Candidate stand relative to native doorway, distance from actual actor, native `CalculatePath` complete/partial, `GetPlayerLockPermission`, `CanBuild`, native planner max range, LOS, correct place surface/socket and `onTerrain` semantics from 012.
- Native rebuild/tile readiness after 6 blocks + TC; whether safe waiting changes `SamplePosition`, and bounded timeout.
- `Door` prefab/socket and `Planner.DoBuild` API; no assumption that door placement will pass just because TC passed. `BuildingPrivlidge` native protection/upkeep methods (`CalculateUpkeepCostAmounts`, `CalculateUpkeepPeriodMinutes`, `GetProtectedMinutes`).

Actual engine signatures/IL from installed DLL only. Static result is not live. If site failed due geometry, change only the necessary site/candidate policy with a quantitative proof; do not increase thresholds just to get GREEN.
