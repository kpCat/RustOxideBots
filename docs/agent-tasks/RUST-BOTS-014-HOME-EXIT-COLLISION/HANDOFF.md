# HANDOFF — проверенные факты на начало 014

## Пути, Git и безопасность

- Репозиторий `D:\Codex\repos\RustOxideBots`, GitHub `https://github.com/kpCat/RustOxideBots`, `master`, публичный SHA **f9c56323d559e27dcf8d303524bd8e7123c5e4bd**; до редактирования сравни local HEAD, tracking и фактический remote, clean tree. SSH в старых заданиях недоступен — Codex использовал временное HTTPS URL rewrite только для команд, не меняя origin config.
- Owner runtime `D:\Codex\repos\RustOxideBots\Server\rustds` ~6+GiB, **3086 owner файлов**, полностью read-only/ignored. Защитить owner world/config/Oxide/plugins/mods/`Run_DS.bat`/`update.bat`; не запускать SteamCMD/updater/owner BAT. `Server/`, `.local/`, `artifacts/` не публикуются.
- Safe autonomous runner `scripts/Invoke-NavigationProbe.ps1 -FirstHomeSmoke -StartupTimeoutSeconds 900`: independent physical fork, TEST_FIXTURE and no promotion to trusted warm cache; Job Object for owned PID, per-exe firewall in/out rules, temporary loopback ports, finally cleanup. `-FirstHome` — NATURAL full run; `-FirstHome -RestoreFrom <runid>` — only after completed paid checkpoint. Check installed syntax/flags before usage, don't invent another command.
- C# 7.3 Oxide compiler / Windows PowerShell 5.1. Read installed DLL/IL, not guessed game method names.

## Реальные результаты 001–013

- 001/003: RustNav movement, natural loot. 004/005: Gen2 accounted gather/craft. 006: `ScientistNPC : BasePlayer` with genuine `PlayerInventory`, `ActiveItem`, `HeldEntity` and RustNav. 007: native resource gathering and paid `SERVER_ACCOUNTED_CRAFT` / held crafted item; historic PARTIAL restore. 008: native inventory/held UID safe RESTORE. 009: `EconomyJournal`, native source depletion replay/NOOP after graceful restart with separate MapKey/WorldKey/WipeId. Crash-atomic and multi-map E2E remain unproved.
- 010: 4 JOURNEY, finally full wood3763/3760 but time budget ended before build. 011: six real native Wood blocks, TC returned null. 012: `onTerrain=socket==null` for TC `Socket_Free_Snappable`; real TC own autoauth/CanBuild; `HomeBuildStand` composite false before door. 013: fixed self-capsule false positive at stand; real Door, upkeep and entry to TC; **exit failed physical capsule check**.
- Verified source commit of 013: `f9c56323d559e27dcf8d303524bd8e7123c5e4bd`, version combined0.3.x. **Live run 013** `16760351f75b4a29a8fc138ffa7f1c08`, test actor142730; native foundation146592, doorway146763, TC146769, Door146777, one buildingID, native paid TEST_FIXTURE. Door opens; upkeeps 1040wood transferred, rate134wood/1440min, protection0→11176.1191min, decay enabled. Physical IN path 1.599467m with `CROSSED_IN`, `TC_REACHED` range1.546368m and LOS. OUT path `PathComplete` 1.457232m planned, then at `Time=381.66626` `HomePhysicalSample` threw because `Clear=false`, `Inside=false`, `DoorOpen=true`. No `CROSSED_OUT`/Door.Close. **Collider identity unknown** (not saved by old code); cannot assume terrain/frame/door collision or broken RustNav. 141 physical samples, 105.319054m total. No native home snapshot, no natural/restore.
- 013 smoke used one of max3 allocated; task ended PARTIAL and does **not** authorize piggybacking more launches into 013. 014 is a separate authorized slice with its own explicit count, not an extension of old chats.

## Read first

`src/home/FirstHome.cs`: `HomePhysicalSample`, `HomeCrossing`, `HomeOpenDoor`, `DoorColliders`, `HomeInterior`, `HomeReadPortal`, `HomeMove`, `HomeArrived`, `HomeTick`, `HomeApproach`, `HomeBuildStand`, `HomeSave`, `HomeRestorePreflight`, `HomeRestoreRebind`.

`src/plugins/RustBotsAvatarSurvival.cs`: actor/agent/physics samples and `Ground`/`NavSample`; `src/economy/EconomyJournal.cs`; `scripts/FirstHomeValidation.ps1`, `Test-FirstHome.ps1`, `Invoke-NavigationProbe.ps1`, `Test-All.ps1`, `Test-PluginCompile.ps1`, `ProbeCache.ps1`, `ProbeFirewall.ps1`, `ProbeSafety.ps1`, `OwnedServerProcess.cs`.

Docs: `docs/agent-tasks/RUST-BOTS-013-DOOR-UPKEEP-HOME-NAV/{RESULT.md,API_DECISION.md}`, 012/011 `RESULT.md`, 009 `RESULT.md` and `AGENTS.md`. Raw 013 logs only ignored `.local/runtime/16760351f75b4a29a8fc138ffa7f1c08/`, if preserved in this local checkout. Read-only audit; never revise raw to manufacture evidence.

## User goals

50–100 lasting, naturally behaving NPCs on arbitrary compatible maps: beach spawn, roads, real loot/gather/tools/craft/gear, paid bases and TC/upkeep, doors/garage/storage/room paths, workbenches/research, sleeping bags/death/respawn/base rebuild, occasional factions/PvP/sieges, Giant Excavator diesel event; optional rigs/cargo. Keep code portable across maps, no hardcoded seed or positions; save persistent personalities separately from wipe-sensitive base/resources later. Focus one bounded playable slice now.
