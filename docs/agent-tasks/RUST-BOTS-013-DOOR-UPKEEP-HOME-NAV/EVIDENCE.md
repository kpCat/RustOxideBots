# EVIDENCE — что сохранять и проверять

## Raw, только ignored `.local/`

Every run: immutable `server.log`, `result.json`, `plugin-result.json`, combined plugin source snapshot and SHA; native Rust/Oxide/protocol, run ID, actual PID, start/stop, original protected server SHA inventory, owned firewall/job/ports/leases/locks receipts; test-root only. Never include private IP/Steam identity/password/owner config in public output.

## Nav approach decision

For rejected and accepted stand candidates log: `homeStep`, `homePhase`, npc/current position, site/foundation/doorway transforms and relative offset, `Candidate`, `RustNav SamplePosition input/success/position`, pending tiles, ray hit entity/type/layer/normal and terrain delta, foundation floor witness, water depth, capsule overlaps/clearance, complete path/length, LOS and placement range, candidate rank/decision and first concrete blocker. Claim UNKNOWN only when truly unobserved and explain missing probe.

## Smoke

`TEST_FIXTURE_WOOD/STONES` amount and UID upfront, counted paid native ingredients and building blocks, each `Planner.DoBuild` call/return, grade upgrades, all eight structures real group+owner+saveList. TC own authorization, native upkeep item movement source/destination; before/after protection minutes; Door prefab and paid UID; open/close/real colliders; continuous physical RustNav and aperture crossing/collision. Smoke never promotes cache; fixture never enters NATURAL or RESTORE.

## Conditional NATURAL & RESTORE

Different run clean test world and 1 actor; natural resource provenance, pool depletion/replay and Item UID ledger, tool condition and applied recipe; origin WorldKey/MapKey/WipeId, artifact generation/SHA. Home/TC/door receipts in true native world and completed world save. Independent restore with same world and building witnesses, original PlayerInventory item UIDs+condition, verified TC auth/upkeep and home crossing with zero duplicate actions. No RESTORE unless valid completed home save.

## Report

A matrix distinguishing STATIC_IL, OFFLINE_FIXTURE, LIVE_SMOKE, LIVE_NATURAL, LIVE_RESTORE, NOT_PROVEN. Full truth about original 012 partials and what changed. Final Test-All exit and installed compile, two text scans, security and clean Git/remote proofs. Include raw file locations without committing them.
