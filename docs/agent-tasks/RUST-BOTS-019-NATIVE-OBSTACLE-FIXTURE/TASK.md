# TASK019 — real negative geometry, detour and first home through shared controller C

## Objective

Close the genuine missing G4/G5 from 018. Fixed-clock/full-body general controller C has proven **terrain slopes** 11.806m, but the benchmark had no eligible *existing closed door*. Implement safe native-paid wall/door test fixture in the isolated world instead, and perform truthful **refusal + detour + doorway** through the same original ScientistNPC/BasePlayer + full body & RustNav planner.

## 1. Baseline / static gates (before server PID)

- Verify local/tracking/actual GitHub `master` = `628cc8fa1d4e7d874665025dcb42d411d350623e` or analyze divergence without resets. `git status`; read `AGENTS.md`, all 019 docs, 018 `RESULT/API_DECISION`, `src/navigation/ObstacleTraversal.cs`, `TraversalBench.cs`, `src/plugins/RustBotsAvatarSurvival.cs`, `src/home/FirstHome.cs`, runner and strict independent validators. Keep owner protected inventory + historical frozen raw and cache SHA.
- Confirm installed C#7.3/Unity/Oxide/Rust APIs and semantics. No guessed native class/signature, no new third-party code/dependencies. Ensure full original NPC capsule radius0.5/height1.8 and unchanged Rigidbody settings.
- **Fix orchestration bug** where a read-only negative `ProbeDisplacement()` currently calls `Block` and poisons the same controller before the subsequent probe/detour. Read-only geometry probe must report `BLOCKED` with actual collider and no movement **without modifying active control state/pending velocity/repath budget**, if invoked at stationary, no pending command. The **movement command** itself still fail-closes on obstacle. Disambiguate outcomes by event/schema; every negative goes through independent validation. No global `ignore own building` shortcut, no permissive world collider mask.
- Plan real native fixture and static site-preview before live; `src/home/FirstHome.cs` already has native construction and paid TC/door code. Reuse rather than rebuild independent fake building API. No hardcoded map coords/seed, no use of player Steam ID. Record loaded materials + costs. Build-only TEST_FIXTURE explicitly allowed in isolated smoke, never NATURAL.

## 2. Live execution and order (up to3 fresh isolated RustDedicated starts)

**Start1 target**: one contained game start can perform all:

- Native RustNav readiness/actor/capsule/physical-clock/spawn support baseline as 018. Since slope up/down proven, one short real outdoor positive route for regression is enough; don't burn first 10 minutes repeating terrain-only 018 unchanged.
- Discover/validate suitable construction site dynamically via real native preview/terrain/RustNav. Create native paid foundation+wall+doorway+hinged Door with full registered socket and owner proof (or full native 1×1 house if practical within the same run). No unverified prefab spawn/teleport/artificial collider/fixture credit marked NATURAL. Optional actual TC only when native rules require it or full G5.
- At safe stationary stand, call the **nonpoisoning read-only** full-body probe into a measured, clearly identified solid native wall, then native closed Door. Each must reject crossing, no actuation, no false clear. Run a short *real physical movement* around exterior corner if native RustNav route and support permit; prove original NPC stays outside, blocked straight segment and legal detour (>2m where feasible), valid actual motion witnesses.
- If full house exists, native TC auth/upkeep and paid native door, perform actual `OUTSIDE→OPEN→INSIDE_TC→OUTSIDE→CLOSE`, support/sweep/overlaps at raised threshold, real door hinge collider state and no body clipping. If impossible, fail-closed with first culprit and preserve G4 proofs.
- Run all scenes in same PID if safe, with clear independent per-gate statuses and no `GREEN` from a single partial feature. After game exit audit process/ports/firewall/wipes and write raw (ignored only).

**Start2**: Only if first run gave a **specific narrow correctable defect** in native construction, current wall/door probe or blocker, fix offline with independent review+focused RED→GREEN and run targeted changed scenario. OR, if Start1 passed all G4/G5, replicate independently at another physically distinct site/pose. No blind repeat just to hunt a door.

**Start3**: reserve for material distinct defect/alternative geometry/real second-site validation with independent prelive reviewer; never count as retroactive task017/018 budget. If repeated `NO_NATIVE_SITE`, don't run a third identical scan. No fourth. Never use a new live just to fix a validator that can revalidate existing immutable raw offline.

## 3. Full-body physical truth

- Preserve actual physics fixed-step cadence, current max speed (.89 native in018), acceleration<=4, velocity agreement<=.001, exact per-step clock sequence, wall lateness and operational stall 1.5s, no infinite budget. Independent real position witness after each issued `Rigidbody.MovePosition`.
- Native current/landing support, `SphereCast`/capsule sweeps, `OverlapCapsule`, `ComputePenetration`, native ownership, closed/open door colliders and RustNav epochs. No manual transform position or `Warp`, no body scale/radius/height/layer/collision flag changes. No crossing when contact with solid non-support structures. Directional tests must hit **intended named collider**, not an unrelated rock nearby.
- For detached probe: read-only may fail and record physics; no command or actual movement must be issued into blocked volume. For actual move: fail closed. A detour is a **real route around** a finite native obstacle on a walkable surface and actual observed movement, never target through closed house.
- **Discrete step** over real building lip must be supported physically with original capsule if claiming `STEP_UP`. Existing `SLOPE` witnesses from018 cannot be relabeled as step-up. If home lip remains blocked, record partial and do not promote. No normal Avatar/FirstHome product enablement without user agreement.

## 4. Release, review, owner decision

- Safety: never owner `Server/` writes; no SteamCMD/updater/owner BAT; no third-party server process termination; isolate full private physical runtime, own kill-on-close Job/firewall/layered cleanup, original warm cache not promoted. 018 frozen rejected raw and 001–018 remain unchanged.
- `Test-All`/installed C#7.3 combined Oxide compilation, independent source & raw review, focused negative fixture tests, strict UTF-8/NUL scans, separate mojibake/escaped Cyrillic, secrets/private owner values, exact owner/protected SHA/length, zero orphan PIDs, ports, rules, broker/leases/locks. Complete `PLAN.md`, `API_DECISION.md`, `RESULT.md` with explicit proof status per gate; include rejected attempts, run count and exact Git commands.
- Exact-path git stage/commit + ordinary push `origin/master` only; no force/reset/rebase/stash/clean or `git add .`, never stage `Server/`, `.local/`, `artifacts/`. Compare local/tracking/public SHA at finish.
- User prefers discuss **significant architectural choices** before execution. Routine bench fixture and read-only probe repair are within already chosen C. If actual native construction cannot be reused and implementation requires replacing controller, changing NPC class/body, artificial building rules, home schema/ownership or unsafe movement compromise, present 2–3 concrete options with risks and recommendation to owner and await his choice; no unilateral switch.

`GREEN_TRAVERSAL_CORE` only with actual G4/G5 AND discrete building transition if relevant, not just G3 slope. A `PARTIAL/G4_PROVEN_G5_OPEN` is a valid meaningful result; never invent a success status.
