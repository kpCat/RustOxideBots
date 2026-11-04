# HANDOFF — проверенный контекст и обязательства

## Baseline и источники

- Публичная репка: `https://github.com/kpCat/RustOxideBots`; локальная `D:\Codex\repos\RustOxideBots`; ветка **master**. Последний проверенный GitHub HEAD: **`58d384e23a8200387d2574f935273c3056ab5b0a`** (008 GREEN_RESTORE). Перед изменениями проверить актуальный local HEAD, `origin/master`, фактический удалённый ref и статус. При расхождении не делать reset/force/rebase/clean.
- Private runtime: `Server/rustds`, Oxide plugins/config/data, карты, сохранения, секреты и пользовательские моды. `Server/` (~6,6 ГБ) и `.local/` целиком ignored. Не включать файлы из них в Git. Всё пользовательское сохранять; source собственных плагинов в `src/plugins`.
- `AGENTS.md`: отдельная физическая тестовая установка с собственной identity/конфигами и данными, работающая network-isolation через firewall broker, RustDedicated не elevated, PID/child под Job Object, controlled quit, zero leftovers. Нельзя трогать owner world или процессы, запускать SteamCMD, обновлять Rust/Oxide, вызывать owner BAT.

## Что доказано

- 001: один Gen2 учёный + RustNav; ~92 м, HEAD b4a2c6f. Тестовый runner с корректным launch/shutdown, UAC/firewall helper и кешем RustNav.
- 003: 413,58 м до дороги, NATURAL бочка, native crate fixture, ItemContainer loot; рестарт 6 Item UID, 12 единиц; HEAD 56247c5.
- 004: NATURAL дерево и каменная жила, 20 wood +20 stones из `ResourceDispenser`, серверный инструмент (не native held), native Item UID/condition и restart; HEAD d9147f1. **Resource pools после рестарта НЕ persisted**.
- 005: 200 wood +100 stones → реальный рецепт `stonehatchet`, `SERVER_ACCOUNTED_CRAFT`, exact ingredient debit и restore; HEAD ce25f34. **Crash-atomic гарантий нет**.
- 006: `ScientistNPC : NPCPlayer : BasePlayer`, настоящий `PlayerInventory` и `HeldEntity` на одном NPC +93,7 м RustNav; HEAD 6834429. Native ResetPath обнуляет скорость, её восстанавливают после SetDestination.
- 007: один player-derived NPC нативно добыл 201 wood/107 stones и честно оплатил изготовленный `stonehatchet` UID87251, затем активировал Native Held; restart был PARTIAL на transient held references. HEAD 811220e. Исторический PARTIAL сохранён.
- 008: **GREEN_RESTORE** в независимом запуске. Все четыре исходных native Item UID и логическая личность из 007 восстановлены; stonehatchet **UID87251** активен с новым HeldEntity 89451. Saved held netID 87252 при reload указывал на чужую `IOEntity`; очищается только ephemeral reference в проверенной protobuf-копии до Item.Load, без изменения чужого объекта. HEAD `58d384e23a8200387d2574f935273c3056ab5b0a`. Полный raw evidence 008 в локальной ignored `.local/`.

## Ближайшие файлы-аналоги

`src/plugins/RustBotsAvatarSurvival.cs`, `src/plugins/RustBotsSurvival.cs`, `scripts/Invoke-NavigationProbe.ps1`, `scripts/ProbeCache.ps1`, `scripts/AvatarSurvivalValidation.ps1`, `scripts/AvatarValidation.ps1`, `scripts/Test-AvatarSurvival.ps1`, `scripts/Test-All.ps1`, `scripts/Test-PluginCompile.ps1`, `docs/agent-tasks/RUST-BOTS-007-NATIVE-AVATAR-SURVIVAL-BRIDGE/RESULT.md`, `docs/agent-tasks/RUST-BOTS-008-HELD-RESTORE-LIFECYCLE/RESULT.md`, `API_DECISION.md`, `docs/agent-tasks/RUST-BOTS-005-CRAFTING-RECIPES/RISKS.md`, `docs/agent-tasks/RUST-BOTS-003-WORLD-ROAM-LOOT/LIFE_ROADMAP.md`.

Рекомендуется минимально расширить действующий player-derived сценарий, сохраняя доказанные 007/008 механики; НЕ делать параллельно второй бесплатный avatar и НЕ переписывать всю систему 001–008. Новый узкий persistence/journal helper допускается, если он реально используется.

## Дальняя цель владельца

50–100 постоянных, похожих на игроков Rust ботов: спавн на пляже, дороги/бочки/ящики, добыча, верстаки/blueprints, дома с TC/upkeep, двери/гаражки, сортировка по ящикам, спалки/смерть/возрождение, группы, PvP, рейды и Giant Excavator Pit. Cargo и oil rigs необязательны; Semantic Pack последних этапов. Сейчас НЕ делать дом, клан, PvP или карьер. Каждая следующая задача — отдельный ZIP, **новый чат Codex**, после отчёта независимая проверка ChatGPT через GitHub.
