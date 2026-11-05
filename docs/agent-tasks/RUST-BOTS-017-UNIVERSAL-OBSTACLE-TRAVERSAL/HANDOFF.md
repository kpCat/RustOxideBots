# HANDOFF — подтверждённое состояние проекта

## Git, каталоги и тестовая среда

- Local checkout: `D:\Codex\repos\RustOxideBots` / GitHub `kpCat/RustOxideBots`, branch master. **Baseline b2a1131536297d3e3fb476cd7992fcbad91c72d1**, подтверждён как actual public master в момент подготовки 017. Проверить текущее состояние снова. Не делать reset/rebase/force/stash/clean при изменениях владельца.
- Owner `Server/` целиком ignored/read-only (~3086 files, 6+ GiB). Не запускать owner `Run_DS.bat`, `update.bat`, `loadMod.bat`, SteamCMD, ни Rust/Oxide update/validate. Тестовый runtime в **изолированной физической копии**, собственные Oxide data/plugins/config/identity, никакого writable link в owner, секреты/сырые логи только `.local/` и `artifacts/` ignored.
- Existing runner `scripts/Invoke-NavigationProbe.ps1` и helpers `ProbeCache.ps1`, `ProbeFirewall.ps1`, `ProbeSafety.ps1`, Windows Job Object/OwnedServerProcess.cs, native compile/tests. Codex сам запускает, ждёт readiness, штатно сохраняет/останавливает только собственный процесс. Inbound/outbound firewall lease, cleanup own PIDs/ports/rules/locks/broker. Чужой Rust/Steam процесс блокирует тест; не убивать его.
- C# 7.3 installed Oxide on tested build, PowerShell 5.1. Не выдумывать Rust API: делать native DLL/IL/asset inspection, реальную проверку компиляции. Source code largely `src/plugins/RustBotsAvatarSurvival.cs`, `src/home/FirstHome.cs`, `src/economy/EconomyJournal.cs`.

## Развитие доказательств

- 001, 003: RustNav физически ведёт Gen2 по дороге, природный barrel+native crate fixture, native inventory UIDs.
- 004–005: природная добыча wood/stones, оплаченный stonehatchet, native inventories; 006: настоящий `ScientistNPC : BasePlayer` с PlayerInventory/ActiveItem/HeldEntity и RustNav, ResetPath обнуляет speed, после SetDestination rearm.
- 007: natural native gathering + paid SERVER_ACCOUNTED_CRAFT, native-held output; initial PARTIAL restore. 008: original Item UID/condition and active held safely restored in separate game process.
- 009: world/wipe-scoped resource depletion after graceful restart, replay NOOP, **CRASH_ATOMIC NOT_PROVEN**, custom/multi-map live E2E NOT DONE.
- 010: full 3763/3760 wood farm but time bound blocked home; 011: 6 paid native Wood blocks in TEST_FIXTURE, TC null. 012: TC fixed via free socket onTerrain and actual own-only auth. 013: native paid Door/upkeep 11176min and physical travel up to TC; exit stopped. 014: real own doorway MeshCollider capsule penetration 11.279mm on inbound; 015: horizontal centering at same height does not remove threshold, no live. 016: **two real BUILD_SMOKE**, both PARTIAL/PASSAGE_UNSAFE. Smoke2 native doorway lower edge penetration19.329010mm plus own foundation leading edge0.111729mm, feet **274.341mm below forward foundation top**, terrain underfoot; full calculated nav path, actor Rigidbody **kinematic=true, gravity=false**, no physical step solver established; observer aborted before subsequent frames. These are NOT proof of safe traversal, and the contact after stop remains unknown. Historical outbound013 collider unknown.
- `016` current code `src/home/FirstHome.cs` ~1026 lines contains `HomePhysicalSample`, `HomeObserveContact`, sweep/penetration receipt, `HomeMove`, `HomeTick`, `HomeCrossing`, native paid 1×1 house. `src/plugins/RustBotsAvatarSurvival.cs` ~711 lines contains one `RustNavMeshAgent agent`, `NavSample`, `Ground`, agent SetDestination/reset speed and native gathering/craft. `home` physics is currently tightly coupled to one doorway and cannot be called a universal locomotion system.

## Что делать иначе

Не повторять 017 как серию трёх BUILD_SMOKE с одинаковым 1×1. Выбран **general-purpose traversal core**: отдельный reusable navigation/movement layer shared by outdoor roaming, resource approach and home. Make a live bench that validates outdoor obstacle/slope/step, genuine paid native building foundation+door threshold and invalid wall/closed door, and capture both passes and refusals. `PathComplete` alone does not prove physical collision clearance.

## Цели владельца

50–100 автономных Rust-выживших на разных compatible worlds: пляж, дороги, природный лут/крафт/инвентарь, настоящие базы/TC/upkeep/doors/garage/storages/workbenches/blueprints, native bags/death/respawn, raids/recovery/clans, Giant Excavator diesel. No fake loot or economy. Oil rigs/cargo optional, Semantic Pack at end. User prefers new Codex chat per substantial task, not endless continuation. **Обязательно обсуждать существенные архитектурные развилки с владельцем**, но делать обычную диагностику/тесты самостоятельно.
