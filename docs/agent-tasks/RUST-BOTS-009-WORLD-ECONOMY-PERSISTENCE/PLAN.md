# 009 — bounded execution plan

Baseline: master / 58d384e23a8200387d2574f935273c3056ab5b0a, verified local, tracking and public HTTPS ref. Only supplied 009 docs were untracked. User explicitly requested autonomous implementation and delivery; no additional approval gate is introduced.

## Design and scope

Reuse native player gather and accounted recipe payment in AvatarSurvival, exact inventory/held restore from 008, existing physical cache, firewall broker and kill-on-close Job Object. No owner Server writes, updater, new engine or provider. C# 7.3 / PowerShell 5.1; no project/dependency changes.

Geometric matching alone cannot distinguish respawn. Use a conservative saved-incarnation gate: exact completed .sav/generation/hash binding, native fromDisk load witness retaining the actual object reference, saved UID plus unique prefab/type/position/rotation/scale, resource definition/start pool and saved health. A killed/replaced object loses its witness. Map-only recreation or missing witness fails closed; never attach old debt to a new respawn. Position tolerance 1 mm, rotation/scale tolerance 0.001; inspect live measurements before claiming success.

Use a small BCL-only EconomyJournal helper with versioned, length-bounded, checksum/hash-chain records, durable Flush(true), exclusive writer, strict state transitions and no automatic retry of any seen intent. PREPARED precedes native gather; APPLIED and COMMITTED follow measured conservation. Accounted craft uses PREPARED, DEBITTING, DEBITED, OUTPUT_CREATED, COMMITTED. Any incomplete transaction is IN_DOUBT on recovery. Checksums detect corruption, not malicious rewriting by an administrator. This is bounded graceful durability, not engine crash atomicity.

Alternatives rejected: netID/coordinate-only debt can charge a respawn; saving inventory alone does not persist pools; a second independent avatar/plugin duplicates proven lifecycle code. No live crash claim is planned: two starts are reserved for JOURNEY and independent RESTORE.

## Ordered work

1. Preserve owner inventory and safety baselines; finish installed IL investigation. Record API_DECISION with UNKNOWNs.
2. RED then GREEN focused journal/source/recovery contracts using the real helper, including torn tail, wrong world/recipe/actor/UID, ambiguous source/respawn, duplicate intent and crash checkpoints. Add an independent economic receipt validator and counterexamples.
3. Integrate WorldEconomy into the existing plugin/runner: durable hit/craft receipts, bound journal proof, conservative source restore and immediate second replay NOOP, unchanged neighbors/items. Keep older flags compatible.
4. Test-All and C#7.3 compile, independent read-only ledger review, then isolated live JOURNEY and RESTORE. Third start only for a specific observed API/engine defect or justified controlled crash; no speculative retries.
5. Audit cleanup, immutable historical evidence, owner SHA inventory, two separate encoding scans, public/secret/scope guard. Write honest RESULT. Exact-path stage/review/commit and ordinary push origin master; verify remote equality.

## Exact public allowlist / bounded exception

Eight supplied docs under this task directory, plus PLAN.md, API_DECISION.md, RESULT.md; src/economy/EconomyJournal.cs; src/plugins/RustBotsAvatarSurvival.cs; scripts/Invoke-NavigationProbe.ps1; scripts/EconomyValidation.ps1; scripts/Test-Economy.ps1; scripts/Test-PluginCompile.ps1; scripts/Test-All.ps1. Total 18 files, one coupled economy artifact family. Raw scripts, logs, snapshots, credentials and owner hashes stay ignored in .local/audit/economy009 and .local/runtime. No older task documents are rewritten.

## Review focus

Source incarnation must be proven before any pool mutation; all source candidates must validate before the first debit. Incomplete journal cannot authorize rewards or crafting. Journal/actor/inventory/world/save proof must agree. Duplicate replay must observe native state rather than trust an in-memory applied flag. Validator must reject fabricated GREEN and preserve honest PARTIAL. No graceful restart claim implies crash-atomicity.

## Observed bounded exception

First live JOURNEY 35d435c481484edd9682260d30d11ac7 ended PARTIAL: a warm natural tree retained low saved health while its native pool reset. Pool-only legacy admission allowed native depletion to reach death before recipe materials. No adapter/reward retry; raw receipts remain unchanged. Installed native gather/damage IL identified the exact cause. v0.1.4 adds conservative capacity admission and records only actually hit sources. Focused real-helper RED -> GREEN and compile verify this correction. This concrete engine-state defect justifies the exceptional third start: remaining JOURNEY + independent RESTORE, never a fourth. The failed journal is not restored or promoted into a successful actor snapshot.
