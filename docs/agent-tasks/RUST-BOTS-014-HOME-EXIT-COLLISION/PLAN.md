# Home exit collision — implementation plan

> Execution: superpowers:executing-plans, inline implementation; independent read-only reviews before live and delivery.

Goal: identify every real overlap at the rejected outbound tick, retain the original guard, and correct only a measured defect.

Architecture: extend the existing FirstHome receipt and validator. Reuse HomeCollider, HomeInterior/HomeApproach rays, HomeMove and the isolated runner. No new runtime layer, dependencies, collider mutation or owner writes. C# 7.3 / Windows PowerShell 5.1; installed DLL metadata is the API authority.

Spec: TASK.md, API_GATE.md, GATES.md, ACCEPTANCE.md, EXECUTION_PLAN.md, EVIDENCE.md, HANDOFF.md, RISKS.md in this directory.

## Exact public allowlist

Product files (three):

- `src/home/FirstHome.cs`
- `scripts/FirstHomeValidation.ps1`
- `scripts/Test-FirstHome.ps1`

Task documents (thirteen), all under `docs/agent-tasks/RUST-BOTS-014-HOME-EXIT-COLLISION/`:

- `TASK.md`, `README.md`, `GOAL.txt`, `HANDOFF.md`, `API_GATE.md`, `GATES.md`, `ACCEPTANCE.md`, `EXECUTION_PLAN.md`, `EVIDENCE.md`, `RISKS.md` (supplied, preserve contents).
- `PLAN.md`, `API_DECISION.md`, `RESULT.md` (new evidence reports).

Bounded exception: 16 public paths because the supplied task document family has ten files. Runtime edits remain limited to the three coupled source/validator/test files. Private audit scripts, raw IL, hashes, reviews and logs only under ignored `.local/audit/home014/` and new isolated runtime roots. AGENTS, avatar/economy, runner, history 001–013 and shared trusted cache remain unchanged. Any necessary expansion requires an explicit bounded rationale before editing.

## Read-first / baseline

Read root AGENTS/README, the entire task package, FirstHome and nearest avatar navigation, validator/test, installed compiler, runner/cache/firewall/safety/Job Object patterns, 013 RESULT/API_DECISION and the final raw PHYSICS samples. No parent AGENTS, separate code-map/pattern files or csproj/props/targets found. Local/tracking/public master = `f9c56323d559e27dcf8d303524bd8e7123c5e4bd`; only the supplied task package was initially untracked. SSH and sandbox HTTPS failed; read-only HTTPS remote check succeeded with approved network access. No persistent remote configuration change.

## Steps and gates

- [x] G0: read-first and three-way baseline. Capture fresh SHA/length inventories of owner, protected public sources, historical raw reports/evidence and trusted world cache before edits/live. Never replace historical baselines.
- [x] G1: inspect actual installed Physics/Collider/CapsuleCollider/BasePlayer/door/RustNav signatures and IL. Save raw private; document STATIC_IL versus UNKNOWN.
- [x] RED: focused fixture rejects missing overlap evidence; existing fabricated crossing and new collider/native geometry/actual path negatives. No pre-authorized terrain exception. Independent review added two focused RED→GREEN binding cases.
- [x] GREEN: unfiltered pre-throw overlap/floor/native-body/penetration/nav/door receipts and candidate separation implemented. Legacy acceptance guard retained. Installed compile, full Test-All, prelive safety/privacy/integrity and independent G1 review completed.
- [x] G2 attempted: one existing-runner smoke508c7d34b98149d49498d25e99efd495, full paid structure/TC/door/upkeep, PARTIAL on first inbound movement; exact doorway threshold contact identified. Graceful quit and cleanup completed. Full passage/close did not pass.
- [ ] If SMOKE_1 fails: inspect its first rejecting collider receipt. UNKNOWN means stop PARTIAL. Only a conclusive narrow defect permits a focused RED→GREEN correction, independent review and one SMOKE_2. After SMOKE_2 stop; NATURAL/RESTORE budget is unavailable.
- [ ] G3/G4 only if the first smoke fully succeeds: new natural `-FirstHome` (2100s plugin / 2400s runner), then independent `-FirstHome -RestoreFrom <completed-natural-run>`. Require complete native world/save/item/home binding; no fixture promotion, replay or free rebuild.
- [ ] G5: final Test-All and installed compiler, independent evidence/security review, exact scope/diff, owner/history/cache comparisons, zero owned processes/ports/rules/open leases/occupied locks, separate mojibake and escaped Cyrillic checks. Write factual RESULT, exact-path stage/commit and ordinary `push origin master`; verify public SHA and clean tree.

Maximum live launches: smoke1 + natural + restore (3), or smoke1 + corrected smoke2 (2). Preflight with no game PID is counted separately. No new goal/slice or speculative attempts.

Actual G2 stop: no safe runtime correction established; independent review recommends no SMOKE_2. G3/G4 not admitted. Final G5 delivery evidence is recorded in RESULT.md and ignored delivery.json; no product/manual gate is self-declared passed.

## Review focus

Unknown or unsupported native shape/API must fail closed. Support rays alone do not establish an unobstructed body. No blanket terrain/foundation/own-object exclusion. Native capsule geometry and aperture margin must be measured without resizing. A preliminary geometric crossing never becomes accepted before physical validation. A complete planned path never substitutes for actual movement. Preserve PARTIAL 010–013; never reconstruct missing collider identities as historical fact.
