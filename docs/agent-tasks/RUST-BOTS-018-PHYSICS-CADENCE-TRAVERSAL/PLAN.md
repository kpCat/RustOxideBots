# Physics cadence and traversal implementation plan

**Goal:** execute TASK018 within the owner's selected controller C and at most three new isolated live starts.
**Architecture:** original ScientistNPC/BasePlayer, original capsule/Rigidbody/inventory, RustNav planner, one checked MovePosition writer. Candidate remains bench-only.
**Tech stack:** installed Rust/Oxide/Unity, C# 7.3, PowerShell 5.1; no project/dependency changes.
**Spec:** TASK.md, CLOCK_DESIGN.md, GATES.md, ACCEPTANCE.md and EXECUTION_PLAN.md in this directory.

## Read-first and baseline

Local HEAD and actual GitHub master are f0a3402901d204133981744fd8502e8cb7d0418f; upstream origin/master. SSH read was network denied; GitHub connector confirmed the actual commit. Only the supplied task018 directory was initially untracked. Root AGENTS/README, all ten supplied018 files,017 RESULT/API_DECISION, both navigation modules, linked spawn/home code, runner/compiler/validators/tests and prior audit scripts read. No ancestor AGENTS, project files, code-map or separate pattern files found.

Reuse the normal TickCore pending-command witness, immutable native fixed-clock receipts, acquisition observed braking hold, native geometry probes, existing physical runner/Job Object/firewall and ignored audit scripts. Historical017 rejected commands stay rejected.

## Scope and constraints

Public implementation allowlist: src/navigation/ObstacleTraversal.cs, src/navigation/TraversalBench.cs, scripts/TraversalValidation.ps1, scripts/Test-Traversal.ps1; src/plugins/RustBotsAvatarSurvival.cs only for pre/post-spawn support diagnostics, and scripts/Invoke-NavigationProbe.ps1 only if runner evidence requires it. New deliverables are this PLAN.md, API_DECISION.md, RESULT.md. The ten supplied018 documents are preserved byte-for-byte and included as task inputs in delivery. This is a bounded exception above ten public paths, entirely one traversal artifact family; no unrelated cleanup.

Server/ and historical source/docs/raw/trusted cache are read-only. No SteamCMD/updater/owner BAT, foreign process termination, physics settings, body dimensions, transform/Warp, fabricated step/rest or default promotion. Preserve MaxTick=.1 physics horizon, speed1.2 ceiling, acceleration4, native velocity.001, full sweeps/support/permissions and120s route deadline,6000 lifetime tick/16384 evidence/64 query budgets. Overall existing bench deadline remains bounded.

## Work and verification

- [x] Freeze owner/protected/native/cache baselines and verify process/port/firewall prerequisites.
- [x] RED: exact017 gaps .1031844/.125893 with actual fixture delta.0625, catch-up, skip/duplicate/changed native clock, late invalid velocity/collision/support and long stall/deadline.
- [x] Separate callback wall lateness from physics continuity; preserve the .1 read-at-tick freshness cap and full native witness. Initial native maximumDeltaTime wall watchdog was disproven by Start1. Ruling after independent raw/design review: keep native cap as immutable metadata and reuse existing1.5s caller trace operational watchdog, without treating it as physical safety proof. Regression uses actual cap.125 and new gap.1289451. Never terminal credit.
- [x] Record point-ray/full-body support at spawn and binding; preserve real FLOOR_ACQUISITION and observed zero-velocity rest. No reposition after creation.
- [x] Reorder bench: outdoor ascent and independent descent first, then genuine pre-home wall/closed-door refusal and safe bounded detour, then paid native home in/out. Missing safe real geometry is explicit PARTIAL, never skipped success.
- [x] Run focused tests, installed combined C#7.3 compile and Test-All; independent implementation prelive review.
- [x] Start1: fresh physical isolated root, frozen source/raw. Four acquisition witnesses; no complete rest/outdoor. The .1289451 wall stop at native cap.125 was a measured policy defect, not a physics/collision failure. Cleanup and protected/owner hashes verified.
- [x] Start2 tested the measured wall-policy repair after regression/review. Native FLOOR_ACQUIRED/rest and5.448m ordinary uphill motion proven; a recoverable command110 Single cancellation speed overshoot stopped correctly. Raw preserved. New numeric repair and unchanged-limit Single reconstruction validated; third start targets completion beyond this measured failure.
- [x] Start3 tested the measured numeric repair after independent review. All237 native commands observed safely; initial floor/rest and11.806m ordinary outdoor up/down proven. No eligible bounded closed-door/detour site was found; G4/G5 remain NOT_PROVEN and home was not started. All3 starts used; no fourth PID.
- [x] Final source/raw independent review, receipt validation and owner/protected/native/cache/cleanup audits completed; full matrices are in RESULT/API_DECISION. Final public encoding/secret scans run on the exact delivery files.
- Exact-path stage/commit and ordinary origin/master push are the authorized delivery operation; final SHA/clean-tree verification is recorded in the final chat and ignored delivery.json. No force/history operations.
- [ ] Product continuation: actual solid/foreign/closed-door refusal, safe detour and paid home in/out. Requires a suitable physical scene and new explicit live authorization; not started in this exhausted018 budget.

## Review focus and uncertainty

Delayed callback is neither an automatic physical rejection nor acceptance. Catch-up retains the next real fixed-step native pose/velocity witness. No baseline/goal may erase pending movement or nonzero velocity. Floor acquisition does not count as outdoor down. Real terrain slope up/down is now proven; closed-door detour, discrete ledge stepping and original home portal remain NOT_PROVEN. Outdoor negative geometry cannot depend on an unfinished house; warmup is diagnostic only.

Independent read-only baseline review confirmed the017 clock root cause and warned about replanning with nonzero velocity; the existing unobserved-hold stop is preserved. No owner architecture decision is needed for these routine corrections inside C.
