# HANDOFF — verified context, not wishes

## Paths / platform / access

- Local checkout `D:\Codex\repos\RustOxideBots`, remote `kpCat/RustOxideBots`, branch `master`, verified GitHub head `673810c885520524471c179ece79b6bd932b34a5` on task handoff. Recheck before work, don't reset/rebase/force/clean/stash or overwrite foreign changes.
- Private installed Rust/Oxide: `D:\Codex\repos\RustOxideBots\Server\rustds`, ~3086 protected files. `Server/` ignored and read-only. `Run_DS.bat`, `update.bat`, SteamCMD, updater task002 not to run. Existing warm physical cache and isolated `scripts/Invoke-NavigationProbe.ps1` runner. `-FirstHomeSmoke` is diagnostic with test-fixture materials on a physically separate no-promotion world; `-FirstHome` is paid natural; `-FirstHome -RestoreFrom <runid>` conditional. Read current param signatures, don't guess.
- Runtime C#7.3 installed Oxide, PS5.1, strict Job Object (own PID), firewall in/out, loopback ports, no link to mutable owner, no foreign process kills. Raw and secrets only ignored `.local/`.

## Verified stages

- 006 real ScientistNPC : BasePlayer, genuine PlayerInventory/ActiveItem/HeldEntity plus RustNav 93.695m.
- 007 native NATURAL gather 201wood+107stones, paid accounted stonehatchet, native held; initial restart partial.
- 008 inventory/held same exact Item UID restored in independent RustDedicated, GREEN_RESTORE.
- 009 world+wipe-bound journal, natural source depletion and replay NOOP after graceful restart; controlled crash-atomic and multi-map live still NOT_PROVEN.
- 010/011: dynamic site and native 6 Wood blocks; full natural 3763/3760 wood in 010 but time guard; 011 diagnostic fixture blocks and TC null.
- 012: TC free-surface `onTerrain=socket==null`, real BuildingPrivlidge+own autoauth+TC.CanBuild.
- 013: native paid Door and TC upkeep 11176.1191min, physical IN and TC reached; OUT `OverlapCapsule` failed without collider evidence.
- 014: native MeshCollider own doorway threshold at first IN, real capsule r0.5/h1.8, penetration 0.0112793455m; near upward MTD; doorway lip ~0.0309m above recorded feet; open door hinge not in overlap; floor 0.0022568m above foot. Guard stopped immediately; older 013 OUT collider remains UNKNOWN.
- 015: documentation-only commit (no runtime code changed), `live0/3`, G1 HOLD. Centerline and +/-25mm preserve ~11.279mm penetration at **recorded** Y; RustNav Tick uses corridor/kinematic transform, native full-body step solver not proven; HumanNPC.IsOnGround always true, not proof of physical support. It did NOT prove engine cannot traverse safely, but did not authorize arbitrary manual Y lift, baseOffset hack, smaller body or disabling colliders.

## Installed files to inspect

- `src/home/FirstHome.cs`: HomePhysicalSample, HomeContact, HomeCrossing, HomeMove, HomeArrived, HomeInterior, HomeReadPortal, HomeOpenDoor, HomeBuildStep, HomeCheckSite, HomeSave, HomeRestorePreflight/Rebind.
- `src/plugins/RustBotsAvatarSurvival.cs`: original NavSample/Ground, native RustNav/actor/held, journal Restore; `src/economy/EconomyJournal.cs` (preserve).
- `scripts/FirstHomeValidation.ps1`, `scripts/Test-FirstHome.ps1`, `scripts/Test-All.ps1`, `scripts/Test-PluginCompile.ps1`, `scripts/Invoke-NavigationProbe.ps1`, safety/cache/firewall/OwnedServerProcess.
- Task docs 014 and 015 `RESULT.md`+`API_DECISION.md`. `AGENTS.md`, 009 and 013 results. Read raw `.local/runtime/<run-id>` only if present and unchanged.

## Endgame (do not forget)

50–100 autonomous survivors on arbitrary Rust map: beach, natural loot/gather/craft, build/TC/upkeep/home, storage/sorting/workbench/research, sleeping bags/death/respawn/after-raid rebuild, clans/PvP/home defense, Giant Excavator diesel, optional cargo/rig, Semantic Pack late. Current one-slice objective is real house passage + restart, NOT mass NPC.
