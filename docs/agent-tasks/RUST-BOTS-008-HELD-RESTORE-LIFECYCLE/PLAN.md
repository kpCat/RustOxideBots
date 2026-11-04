# RUST-BOTS-008 implementation plan

Goal: restore the original 007 logical actor and native inventory, including crafted Item UID 87251, in an independent isolated process.

Architecture: retain the existing single Oxide plugin and runner. Validate immutable binary/state/world receipts first; discard only verified ephemeral held references in the deserialized copy; native Load and native parent lifecycle recreate held entities. Never resolve an old held reference into the restored Item.

Spec: TASK.md, API_GATE.md, ACCEPTANCE.md, EVIDENCE.md, HANDOFF.md, RISKS.md.

Constraints: C# 7.3, PowerShell 5.1, installed DLLs only; owner Server read-only; no updates; no kit/harvest/craft replay; at most two starts, third only for a demonstrated corrected defect. User explicitly authorized autonomous execution on master and exact-path commit/push, so no intermediate approval gate or worktree is introduced.

Read pass: root AGENTS/README, all 008 inputs, 006/007 API/results, 007 risk register, AvatarSurvival/AvatarProbe, runner/cache/safety/firewall, receipt validators/tests and installed metadata/IL. No ancestor/nested AGENTS, project files or code-map/pattern files found. Reuse existing native activation, receipt validation and safety runner. No UI or dependencies change.

Bounded scope: three existing code files (plugin, validator, focused tests), three new 008 reports (this plan, API_DECISION, RESULT), one appended 007 result link. Include the eight supplied 008 task documents in the exact delivery allowlist. This task-document package is the bounded exception to the 8–10 file limit; no independent subsystem is added.

Review focus: stale network aliases must never reach Item.Load; globally existing incoming Item UIDs fail closed; corrupted roles/slots/condition and duplicate IDs fail before native mutation; repeated native parent lifecycle must not duplicate held entities; partial restore must retain its real status and clean up its owned objects.

- [x] Baseline: local HEAD, origin/master and public HTTPS master are 811220edbcbed8ffcaca804306e66cf6f40d1de6. SSH unavailable; use HTTPS without changing remote configuration.
- [x] Verify source snapshot/state and exact cached generation/save hashes; preserve raw 007 results. Source 007 is still compatible, so prefer one RESTORE start, no new JOURNEY.
- [x] Record installed IL decision and read-only wire audit, with owner baseline.
- [x] Add focused RED fixtures for restart receipt, alias isolation, missing held and item conservation; retain corrupt binding/UID/slot/owner/no-replay fixtures.
- [x] Implement minimal validated-copy cleanup with before/after collision receipts, native Load/ownership/UID checks, per-item ledger and repeated held observations. Run focused tests and Test-All before live.
- [x] Run existing isolated headless RESTORE; independently validate source → process → native inventory/active/held and safe shutdown. One start, run 2b10b4d7c99b4bad93a00bf6dc3fd630, GREEN native restore; no retries.
- [x] Write factual RESULT; verify owner hashes, processes, ports, firewall, leases, locks, separate encoding scans, public scope/secrets. Append 008 link to historical PARTIAL 007.
Delivery: exact allowlist/diff review, exact-path commit and ordinary fast-forward push are the final actions. Their completed SHA/remote/clean-tree receipt is recorded after this plan is committed in ignored `.local/audit/avatar008/delivery.json` and the final response.

Progress and raw evidence: ignored `.local/audit/avatar008/`. STATIC_IL and OFFLINE_FIXTURE are not live proof. Historical collision type remains UNKNOWN until a new process records it.
