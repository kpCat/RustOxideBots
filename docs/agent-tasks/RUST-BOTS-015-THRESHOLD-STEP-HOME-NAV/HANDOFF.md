# Контекст, пути и нерушимые правила

## Git, Windows и владелец

- `https://github.com/kpCat/RustOxideBots`, local `D:\Codex\repos\RustOxideBots`, branch **master**. Базовый commit `ed25505e3e829af563243d242e2c3fc5729027f4`; в начале сравнить `HEAD`, `origin/master`, фактический публичный `refs/heads/master`, `git status`. При расхождении не делать reset/rebase/force/clean.
- Owner runtime: `D:\Codex\repos\RustOxideBots\Server\rustds`; `Server/` целиком read-only, ignored и untracked (последний owner inventory 3086 файлов). Не запускать owner `Run_DS.bat`, `update.bat`, SteamCMD, updater002, не менять мир/мапы/плагины/конфиги/идентичности.
- `AGENTS.md`: новая **физическая** копия тестового runtime без writable link к owner; отделённые Oxide config/data/plugins, ephemeral identity/RCON creds в `.local/`, firewall deny inbound+outbound на test executables, own PID in kill-on-close Windows Job Object; graceful ACK/save+bounded cleanup; НЕ завершать чужие процессы. Smoke fixture world не должен продвигаться в trusted cache. Вся `.local/` и owner данные никогда не попадают в git.
- C# 7.3 Oxide compilation на установленной DLL, Windows PowerShell 5.1, без внешних новых runtime зависимостей. Git authorized only bounded exact-file inspection/commit/ordinary push; no force, broad add, clean/reset/stash.

## Проверенные этапы

- 006: один `ScientistNPC : BasePlayer`, native `PlayerInventory`, `ActiveItem`, `HeldEntity` и физический RustNav; rearm speed после native ResetPath.
- 007: native resource gather, accounted paid craft, native-held output; первоначальный PARTIAL restore.
- 008: original Item UID+condition native inventory/held RESTORE GREEN.
- 009: map/wipe-bound source depletion after graceful restart, journal/APPLY→NOOP; controlled crash atomicity и multi-map gameplay НЕ доказаны.
- 010: долгий NATURAL gather 3763 wood, но поздний TIME_BUDGET остановил дом; 011: шесть real Wood blocks. 012: TC free socket нужен `onTerrain=socket==null`, собственная autoauth; 013: native оплаченная дверь, TC upkeep 11176.1191min, вход до TC, обратный путь остановлен capsule overlap.
- 014: реальное 11.279mm проникновение в собственный порог на *первом входе*, native physics измерена; 013 outbound collider по-прежнему неизвестен. Подробный baseline в `COLLISION_BASELINE.md`.

## Читать реальные source, не копировать старую огромную задачу

- `src/home/FirstHome.cs`: `HomePhysicalSample`, `HomeContact`, `HomeCrossing`, `HomeReadPortal`, `HomeInterior`, `HomeMove`, `HomeArrived`, `HomeTick`, `HomeOpenDoor`, `HomeApproach`, `HomeBuildStand`, `HomeSave`, `HomeRestorePreflight/Rebind`.
- `src/plugins/RustBotsAvatarSurvival.cs`: native actor / agent / physical trajectory / `Ground` / `NavSample`; `src/economy/EconomyJournal.cs` (не менять без острой необходимости).
- `scripts/FirstHomeValidation.ps1`, `Test-FirstHome.ps1`, `Invoke-NavigationProbe.ps1`, `Test-All.ps1`, `Test-PluginCompile.ps1`, `ProbeCache.ps1`, `ProbeFirewall.ps1`, `ProbeSafety.ps1`, `OwnedServerProcess.cs`.
- `docs/agent-tasks/RUST-BOTS-014-HOME-EXIT-COLLISION/{RESULT,API_DECISION}.md`, 013/012/011 result, root `AGENTS.md`, roadmap003.

## Долгосрочная цель (не scope 015)

50–100 автономных выживших на разных Rust картах: пляж, добыча/лут/технологии, натуральные оплаченные дома, TC/upkeep/doors, storage+sorting, sleeping bag+death/respawn, clan/PvP/base repair/raid, Giant Excavator (fuel/start/defend/loot), реальное поведение. Сейчас **одна безопасная дверь** и затем первое восстановление дома. Без произвольных preset координат и фальшивых GREEN.
