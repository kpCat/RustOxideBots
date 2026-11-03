# RUST-BOTS-001 v2 implementation plan

> Execute inline using superpowers:executing-plans. TASK.md is the approved specification and execution request.

**Goal:** safe local bootstrap, BAT hardening and truthful navigation evidence, then exact-path commit and push master.
**Architecture:** existing Rust/Oxide installation is read-only except the two explicitly permitted BAT files and their backups. Copy runtime into a separate ignored test installation, with no links and no owner configuration/plugins/saves. Use local installed DLL metadata as API authority.
**Tech stack:** Windows PowerShell 5.1+, batch, installed Rust/Oxide C# API; .NET SDK only for bounded metadata inspection where required.
**Spec:** TASK.md, BAT_AUDIT.md, GOAL.txt, HANDOFF.md, ACCEPTANCE.md, EVIDENCE.md.

## Global constraints

- No SteamCMD/update/validate, game client, wipe, owner config/world/plugin changes, or foreign process termination.
- Work only in the existing checkout on master, as explicitly requested; no worktree or branch creation.
- All Server/, logs, runtime secrets and raw evidence ignored. Publish only sanitized source/docs/scripts.
- Fail closed before live startup unless process ownership, writable directory isolation and network isolation are proven.
- One or two full server starts at most; bounded attempts and shutdown in finally.
- Bounded scope exception: more than ten files including the supplied task package, ignore/rules/readme, BAT templates/tests, runner and diagnostic source. All serve this single bootstrap vertical.

## Review focus

- Wrong cwd and paths containing spaces: BAT fixture executed from another directory.
- Clean/nonzero exit and unexpected restart: counted stub process, bounded timeout and propagated exit.
- Missing updater prerequisites: stub-only denial before any SteamCMD call; actual updater never invoked.
- Shared writable directories or foreign processes: runner preflight fails before launch.
- Exceptions/timeouts: process handle retained, graceful stop then bounded owned-process termination and port check.

## Tasks

- [x] 1. Baseline, ignore isolation, local API/map/log/plugin inventory. Record missing files/tools and auth limits.
- [x] 2. Write focused BAT regression fixtures first, observe missing implementation failure; implement templates, run tests; backup and preserve exact local game invocation while hardening BATs.
- [x] 3. Implement isolated runner and plugin against inspected installed API. Verify static PowerShell and safety paths; live run only after isolation gate. Record actual readiness/navigation/shutdown or precise blocker.
- [x] 4. Review evidence, verify owner hashes, sanitize RESULT/README/AGENTS, run focused checks and two encoding scans.
- [x] 5. Verify exact staged paths and secrets, commit, ordinary push origin master, compare remote SHA and final status. Implementation push confirmed; owner addendum/design and publication receipt delivered in a separate exact-path documentation follow-up.

## Initial findings

Baseline master/HEAD: daa38dbfad1716db3978c90d1870f8c3064c1a4d; only README tracked. Supplied docs and Server initially untracked. No AGENTS.md above/in root, no project code-map/pattern/csproj/props/targets. Existing local analogues: Run_DS.bat, update.bat, PrefabSniffer.cs, TimeOfDay.cs. Do not publish third-party plugin source.

Initial external process inventory (CIM outside sandbox): no RustDedicated/RustClient/Rust/SteamCMD. Windows firewall profiles enabled. SSH origin authentication failed with publickey; do not alter remote or bypass authentication.

## Execution ledger

- Ruling: execute the supplied detailed TASK in place on master without another design approval/worktree — explicit owner execution request governs; no architecture/stack replacement.
- Tasks 1–2: ignore checks passed; 397 owner files fingerprinted locally. Two BAT originals backed up and hashes verified; argument string retained. Focused fixtures observed RED for missing implementation then passed. No real BAT/SteamCMD execution.
- Task 3: preflight BLOCKED before game process/copy because administrator rights absent; disabled firewall capability probe also denied by Windows. Do not relax network isolation. Zero full server starts and zero spawned game NPCs.
- Offline plugin compile initially exposed duplicate Newtonsoft types; installed CSharpPluginLoader blacklist inspected, compile references corrected to follow it. C# 7.3 compile then passed. This is not live Oxide proof.
- Independent read-only review found linked-source checks, writable-log sharing, unassigned suspended-process window, discontinuous/double-counted telemetry, predictable BAT temporary file. All addressed in one bounded repair pass. Added focused log/junction/metrics and hardener regression fixtures; protected unrelated temporary file failed before repair and passed after it. Job assignment now atomic at CreateProcess via Windows 10+ job-list attribute; exception and abrupt controller termination tests passed.
- Ruling: keep updater fail-closed even with a ZIP present — compatible backup/restore is unverified and this task prohibits an update. No actual updater call path is supplied.
- Initial ruling: deploy diagnostic source only to a new test installation after preflight. Superseded in part by the owner's later explicit request for an owner working copy: add our inert plugin to Server/rustds/oxide/plugins without overwriting anything. Live tests still require a separate writable install and never use this owner copy.
- Ruling: use existing Git Credential Manager account with a command-scoped HTTPS URL mapping if SSH fails; remote configuration remains unchanged and push stays ordinary fast-forward to origin/master.
- Task 4: full focused suite passed; 397 owner hashes unchanged and no added/deleted protected paths. All 26 public files passed separate mojibake/escaped-Cyrillic and owner-value/credential scans. Final Rust/SteamCMD process count and test TCP/UDP endpoint counts were zero. Firewall enumeration denied by Windows and recorded as NOT_VERIFIED; no firewall creation succeeded.
- Owner addendum: full update automation and selective sanitized config export are substantial additional scope; preserve their requirements/design in RUST-BOTS-002-SAFE-RUST-OXIDE-UPDATE/TASK.md, do not implement/run them during 001. Added one explicitly authorized inert working-copy plugin under Server/; its SHA matches source, existing 397 owner files remain unchanged. Final public allowlist expands to 27 files for the requested next-task design.
- Task 5 implementation receipt: commit 01b325e95c5cb216e25917259efd8559d2d445a4 pushed normally from daa38db to origin/master; ls-remote matched. Git automatically ran maintenance during commit; it completed without manual cleanup/history operations. The addendum changes only AGENTS/README/PLAN/RESULT and the 002 design document. Final documentation delivery SHA is reported in the chat and ignored local receipt because a versioned file cannot embed its own commit hash.

## Resumed live-navigation repair, 03.11.2026

- Owner supplied actual isolated run fc3ce0bee5e14e958e30289ad61929c8: plugin0.1 compiled/loaded, RustNav active, zero spawn after 169 rejected candidates, graceful ACK/save/exit. Read its actual server.log/result and current plugin/runner/safety/tests; reuse installed metadata inspector and owned Job Object.
- Bounded scope exception: 12 public files (plugin, runner, safety, cache/firewall helpers, focused tests and README/PLAN/RESULT). No BAT/update/002 work or owner-world/config edits. The existing inert own-plugin working copy may be refreshed after backing up the exact old source.
- Installed DLL proves IsDefaultNavmeshBuilt requires numBuiltTiles == tiles.Length and default-agent binding also requires this. Manual run saved thousands of pending tiles. Wait for actual RustNav completion; emit tile progress, rejection reason counters/examples, grounded capsule checks and complete departure paths, prefer normal Scientist2.
- First agent-owned E2E 88436ae68e38489dbc15252303353fc2: normal Windows token, PID37284, live Oxide/plugin0.2, three ARRIVED legs, 92.20833 m. Raw coordinate reconstruction independently matched 92.20832 m. Stuck/repath 0. Native quit ACK/save complete, PID/ports absent; external lease later closed and its exact rules removed. Original result.json retained, with separate closed.json cleanup receipt.
- Read-only review fixes: full physical runtime inventory and staging promotion; ordinal host-independent cache key (PS5/7 underscore/dot culture ordering reproduced RED then fixed); firewall reservation closes verify/start/removal race; broker-start failure cleanup no longer claims removal without proof. Focused regression suite passed.
- Installed ConVar.Global.quit calls ServerMgr.Shutdown then Process.Kill; observed exit -1 after complete save is expected for this DLL. Cache promotion requires ACK + completed nav/world save + absence, with explicit 0/-1 exit handling; no failure messages are suppressed.
- Second agent-owned E2E b0bd803ae7854a309af9f8ed000731da passed corrected default one-command delegation/full cache: 92.2068253 m, three ARRIVED legs, zero stuck/repath, normal Windows runner token, graceful ACK/save/exit -1, cache promoted and independently restored, ports/processes/rules all zero. Complete raw-sample reconstruction matched. Source/compiled test/owner working-copy hashes match after a verified old-source backup. All 397 existing owner hashes remain unchanged.
- Final verification: focused suite including actual child PowerShell UTF-8 stdout passed. Steam manifest build26139947 and live protocol2635.289.1/Oxide2.0.7839 confirmed; no third full game start needed. Final publication uses only the 12-file allowlist in RESULT, without 002 or Server/.
- Deferred minor: historical test state/evidence archives and cache generations are retained locally for diagnosis and consume disk over time; no broad cleanup is mixed into this task.
- Goal 002 remains DESIGN ONLY / NOT STARTED.
