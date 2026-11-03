# Player avatar gate — implementation plan

**Spec:** TASK.md, API_GATE.md, ACCEPTANCE.md. Execute autonomously in the existing master checkout as explicitly requested. No additional design approval or new worktree. One bounded experiment, no production migration.

**Architecture:** separate inert RustBotsAvatarProbe; reuse 001 physical navigation geometry and existing isolated runner/job/firewall/cache. Independent PowerShell receipt validator. Preserve all three existing plugins byte for byte. No IBotAvatar abstraction is needed by this experiment.

**Constraints:** installed Rust/Oxide only; C# 7.3 / Windows PowerShell 5.1; no Harmony, updates, fake Steam identity, client RPC, post-spawn coordinate writes or combat. Server is read-only. Raw evidence and audit helpers only in ignored .local. At most two live starts unless a third is justified by a concrete observed defect.

## Exact public scope (bounded exception: 18 files)

Eight supplied 006 documents: TASK.md, API_GATE.md, ACCEPTANCE.md, EVIDENCE.md, HANDOFF.md, RISKS_AND_NEXT.md, README.md, GOAL.txt. New 006 PLAN.md, API_DECISION.md, DECISION.md, RESULT.md. New src/plugins/RustBotsAvatarProbe.cs, scripts/AvatarValidation.ps1, scripts/Test-Avatar.ps1. Modify scripts/Invoke-NavigationProbe.ps1, scripts/Test-PluginCompile.ps1, scripts/Test-All.ps1. No other public paths.

## Tasks and verification

- [x] STATIC: verify baseline and owner fingerprint; inspect installed metadata/IL and manifest. Record native lifecycle, connection/ownership gates, exact prefab candidates and live plan in API_DECISION before starting a server.
- [x] OFFLINE RED → GREEN: implement Assert-AvatarResult and Assert-AvatarSafety with focused fixtures. Reject false actor/item/container/held ownership, absent held entity, missing/foreign activation, duplicate fixture, zero travel, warp, broken path/actor continuity and failed shutdown. Fixtures are validator inputs, never native equip evidence.
- [x] OFFLINE: implement one-actor avatar probe and mutually exclusive -PlayerAvatar runner mode. Existing scenarios remain unchanged. Emit raw samples and receipts for discovery, actor, inventory, fixture, native activation, negatives and per-leg movement. Use actual APIs confirmed by installed IL. Run installed-DLL compile and full Test-All before live.
- [x] LIVE: preflight; one isolated headless process with verified deny rules and owned job. Discover manifest candidate, spawn once, equip native TEST_FIXTURE rock and drive RustNav. At least three dynamically selected ~32 m legs (acceptance requires two and 60 m). Record exact failure if blocked. Native held evidence must remain valid throughout travel. Graceful quit and verified cleanup in finally.
- [x] Optional second LIVE: only for a concrete observed defect or bounded persistence proof. If persistence is omitted, explicitly NOT_VERIFIED; never imply native entity continuity.
- [ ] DELIVERY: independent read-only review, final offline suite, full owner hash comparison, process/port/firewall/lease audit, two separate Cyrillic scans, secret/scope guard. RESULT and DECISION distinguish STATIC, OFFLINE_FIXTURE, LIVE, NOT_VERIFIED. Exact-path commit then ordinary push origin master; final SHA and remote receipt after commit.

## Review focus

Same actor across inventory/equipment/navigation; native ownership versus arbitrary container; valid UID versus forged active state; sample reconstruction versus declared totals; fail-closed cleanup; absence of client evidence for visuals; no source updates/owner mutations. Native UpdateActiveItem alone may accept an absent UID, so guard policy and raw engine behavior must be distinguished.

## Progress and rulings

Baseline local HEAD/cached origin/master and actual HTTPS remote master match ce25f3482468a2be48a4896275657dc59b28e9e5. SSH key unavailable; temporary HTTPS mapping works without changing origin. Initial untracked content is only supplied 006 package. Baseline Test-All passed. Ancestor AGENTS and public project/code-map/pattern files absent.

Ruling: task explicitly requests autonomous execution and master delivery; use supplied task as design approval and retain existing checkout. No general skill scaffold or extra infrastructure is necessary.

Prelive review: fixed zone sleep/wake reactivation by unregistering only the probe brain; fixed false graceful-exit acceptance by requiring native ACK/save. Full stable Test-All passed before first live. Source 0.1.0 was snapshotted for run ada3c026240f4f84acf5d3516c2d3c2d.

Ruling: missing UID in source 0.1.0 was only a label accompanying a null Item guard, not an actual UID lookup. Preserve first raw report; require shared native ItemId lookup for final NEGATIVE gate. Version 0.1.1 implements the verified public API. A second live start is justified to validate this concrete defect; it does not prove persistence.

First live ended PARTIAL: two targets reached, 62.4408932 m, then third-leg stall after 0.043604 m; one repath failed. Second raw arrival was PathInvalid after a complete moving path, not retained PathComplete. Native inventory/held remained valid. Shutdown GRACEFUL and external cleanup audit passed.

Ruling: a proposed stop at the written two-leg acceptance minimum was superseded by exact IL diagnosis. Native arrival ResetPath clears path and desiredSpeed; SetDestination does not restore speed. Restore the original three-leg second-run regression, reset speed per destination/repath, and record actual speed/path state. Validator distinguishes complete planned/issued path from raw terminal state, admitting consumed PathInvalid only at the native arrival tolerance after uninterrupted complete moving samples, without stuck/repath. First raw failed result remains immutable. This corrects a concrete lifecycle defect rather than lowering physical thresholds.

All implementation and live tasks complete: second run 1f413b585dde4380ac361dc3c965c9af passed actual 93.6954901486 m/3 legs, native inventory and held on actor 73508, real UID guards, zero stuck/repath, speed before third 0 → issued 3. Independent live audit and final Test-All passed. Graceful ACK/save and external cleanup zero; 3086 owner files unchanged. No persistence or third live. Final exact-path delivery remains the last step.
