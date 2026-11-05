# История и реальные границы

## Repo/protection

- Local `D:\Codex\repos\RustOxideBots`; GitHub `https://github.com/kpCat/RustOxideBots`; branch `master`. Verified SHA on task preparation `628cc8fa1d4e7d874665025dcb42d411d350623e`. Must verify again (not assume). Historical all reports/tasks 001–018 unchanged.
- `Server/` contains private owner runtime `Server\rustds`, earlier owner inventory 3086 files, protected inventory ~2920 (recount). It is ignored, must remain **100% read-only**. No owner BAT (`Run_DS.bat`, `update.bat`), updater, SteamCMD, validate/install/replace Rust/Oxide; no changing owner worlds/maps/identities/conf/plugins. Do not execute owner game process; physically copy installed binaries to isolated private test runtime, no writable links.
- Existing `scripts/Invoke-NavigationProbe.ps1 -TraversalBench` runner, owned-process Windows Job Object, firewall per-exe deny inbound/outbound, private identities/secrets/loopback ports, independent cache copy and `finally` cleanup. Never stop foreign Rust/Steam processes. Logs/secrets/raw `.local/` only.
- C#7.3 installed Oxide, PowerShell5.1; no dependency downloading. Git authorized only for this bounded task: exact paths, normal fast-forward `push origin master` (HTTPS per-command URL override allowed), no force/reset/clean/rebase/stash or broad add. Preserve AGENTS rules and strict UTF-8 Cyrillic.

## Progress verified in GitHub

- 003/004/005: real roaming and natural resource gather, native paid stone-hatchet crafting and UID.
- 006: real ScientistNPC : BasePlayer, PlayerInventory/HeldEntity/ActiveItem and RustNav.
- 008: original native inventory/held Item UID independent restart proof; 009 source-depletion journal after graceful restart; crash atomicity/multi-map NOT_PROVEN.
- 010 natural farm 3763wood but before native home placement, time bound. 011–013: real diagnostic Wood foundation+3 walls+doorway+roof+TC+Door/own TC auth/upkeep ~11176min; one 013 physical IN to TC, OUT failed. 014/016 measured doorway lip and foundation body overlap; do not dismiss them or claim home traversal already works.
- 017 `e3b303b` and `f0a3402`: user explicitly chose **C** shared collision-aware controller `src/navigation/ObstacleTraversal.cs`; `src/navigation/TraversalBench.cs` bench-only; 5 runs: repaired native fixed-step clock/Single cancellation; actual small vertical acquisition but not ordinary movement. No automatic migration of normal routes.
- 018 `628cc8f`: 3 live isolated starts. Third `fa6c6b723fcf453582fe4ef531402f99`: original capsule r0.5/h1.8, actual `FLOOR_ACQUIRED`, 229 ordinary safe native physical witnesses, 11.8060622m true outdoor ascent/descent (net up/down ~0.44m). 237/237 accepted including initial capture. 4 `STEP_RESOLVED` events are **slopes**, NOT discrete obstacle/ledge. Native max speed .89, observed .88922, max acceleration ~2.005 <4, velocity error0. 12 late wall callbacks accepted with correct .0625 physics. All on same map/test slope.
- 018 stopped at **site coverage**: `TraversalOutdoorNegativeBegin` searches existing closed Door (foreign owner) distance <=48m, with nav-sampled opposite stands, approach<=60m and detour<=24m. Candidate absent; G4 negative wall/closed door/detour and G5 paid HOME not started. This was not proof of native movement failure. Do not repeat exact search and burn3 PIDs.

## Code traps verified in public master

- `src/navigation/TraversalBench.cs`: order warmup→outdoor up/down→`TraversalOutdoorNegativeBegin`→`TraversalOutdoorRefusals`→`OUTDOOR_DETOUR`→`HOME_START`; existing door discovery can fail the task before true construction begins.
- `src/navigation/ObstacleTraversal.cs`: `ProbeDisplacement` is nominally read-only physics but on negative result calls `Block(...,"READ_ONLY_REFUSED")`, changing core lifecycle state. Existing `TraversalOutdoorRefusals` attempts multiple sequential negative probes + `IssueTraversal` afterwards. This is an **actual orchestration conflict** (read-only negative probe poisons controller). Separate nondestructive probe/classification from command-admission failure; no collision bypass, no suppressed native contact. Use focused negative fixtures to prove the distinction.
- `HomeTick` `NAV_WAIT` already calls `TraversalWallNegative()`/`TraversalDoorNegative()` before opening native door; those also call `ProbeDisplacement`. They need nonpoisoning refusal semantics.
- `src/home/FirstHome.cs` built-in `HomePlace` uses actual `Planner.DoBuild`, loaded constructions, item costs, native sockets/TC, own permission, support, paid upgrades. Diagnostic `-FirstHomeSmoke` has TEST_FIXTURE materials; **never** qualify fixture as NATURAL or promote cache. Benchmark integration via `EnsureTraversal()` stays opt-in only; previous native routes unchanged.
- `AGENTS.md` requires that all own server starts use isolated full copy and safe cleanup; when third-party owner/foreign entity absent, do not fabricate its owner or fake wall. Use real native paid self-owned fixture and explicitly label `OWNED_NATIVE_TEST_FIXTURE` rather than `FOREIGN_WORLD`.

## Owner's planned later roadmap, OUT OF SCOPE 019

Universal movement is base for crouch/crouch-walk/jump/vault, true home building/restoration, storage/bags, native monuments with local-coordinate profiles, green→blue→red card/fuse puzzles and real loot, Bradley rocket PvE, patrol helicopter/fires/crates, group combat/clans, Giant Excavator, 50–100 persistent bots. Don't implement these before verifying current wall/door/house crossing; preserve long-term goals. Material architecture forks must be presented to owner (with alternatives and recommendation) before altering approved controller C.
