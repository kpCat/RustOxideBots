# EVIDENCE — independently verifiable raw/live evidence

## Baseline and installed capabilities

Report actual public+local Git HEAD, installed `Assembly-CSharp`/Unity/RustNav/Oxide DLL SHA and exact methods/IL relevant to movement, input physics/CharacterController/kinematic and terrain support; C#7.3 + PS5.1 versions, source hashes (including compiled combined plugin). No guessed method from outdated Rust wiki.

## Every physical scene

- `Mode`, unique test run ID, scene kind (`OUTDOOR_STEP`, `SLOPE_DOWN`, `NATIVE_BUILDING_STEP`, `SOLID_WALL`, `DOOR_CLOSED`, `REPATH`), chosen actual world geometry, dynamic sampling, no hardcoded XYZ; actor/netId, native full body radius/height/capsule components and unchanged scale/physics.
- `ObstacleProbe`: native queries/colliders layers/prefabs/owner+instance ids, full capsule sweep/cast/overlaps/penetration, support at foot/forward/landing, step candidate height and surface normal, slope, clearance, door open/close/rights, nav tile readiness and path status.
- `Movement`: timestamps, actual positions/yaw/native velocity/path corners, delta-Y, supported foot and obstacle edge, penetration before/after, evidence actual movement did not clip/tunnel/move through solid, bounded retry/stuck outcomes. Independent validator checks actual data rather than flags, rejects PathComplete-only PASS or impossible sampling gaps.
- `Decision`: `CLEAR`, `STEP_UP`, `STEP_DOWN`, `SLOPE`, `REPATH`, `BLOCKED`, `UNKNOWN`, actual reason, cooldown/retry counts, no false door/foreign permission. For negative wall test show NPC never crossed wall even if nav plan pointed through it; blocked is a valid PASS for that negative case.
- `Perf`: number of casts/overlap calls per simulated second per agent, local nav recalcs, CPU time/query if native measurable, allocations estimate if measurable, no unbounded per-tick broad scans. No invented performance 100-bot claims.

## Smoke construction only

Native Planner, real BuildingBlock/door/TC entity group/owner/grade/support, Item UID/amount exact payment from clearly marked TEST_FIXTURE. If step/ramp is added as diagnostic construction, use installed native costs and register extra element; don't fabricate a ramp mesh. No fixture cache promotion and no counting as natural survival.

## Test/safety/delivery

Test-All exit/actual native plugin load, independent negative fixtures, user architecture approval if applicable, source review with P1/P2 open blockers; full owner `Server/` SHA+count before/after and protected history/cache, zero owned Rust/Steam/helper PID/TCP/UDP/firewall/rules/leases/locks. Raw only ignored `.local/`/`artifacts/`; sanitized public RESULT. UTF-8/NUL and **separate mojibake / escaped Cyrillic** scans, secrets/IDs/private paths guard. Exact path `git add -- ...`, diff, ordinary push/master SHA comparison, no Server/.local artifacts.
