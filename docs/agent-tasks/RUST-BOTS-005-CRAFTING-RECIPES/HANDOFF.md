# HANDOFF — подтверждённый контекст и правила

## Repository, baseline и защита владельца

- `https://github.com/kpCat/RustOxideBots`, `D:\Codex\repos\RustOxideBots`, ветка `master`. Последний **проверенный через GitHub** SHA до постановки 005: `d9147f18a6e4671cb76d3c042e9d85f2f2f18639`. Если актуальный HEAD отличается, изучить историю/изменения, **не reset/rebase/force/clean**. Вся `Server/` исключена из Git, приватна, 6+ ГБ; в ней владелец хранит соло-мир, Oxide и настроенные моды.
- В `AGENTS.md` обязательны read-only owner assets, отдельный test install/identity/Oxide writable data, per-executable firewall block, Job Object owned-child lifetime, controlled quit+cleanup, secrets в ignored `.local/`, exact-path git stage.
- Не использовать owner `Run_DS.bat`, `update.bat`, SteamCMD; не начинать задачу 002 Safe Rust+Oxide Update. Не обновлять сервер/моды, не стирать owner конфиги, сейвы, кеш.

## Verified predecessors / границы

- `001`, implementation `b4a2c6f...`: `ScientistNPC2` Gen2 + RustNav, 3 настоящих движения, 92.21 м; тестовый сервер/кеш и firewall-helper; тесты запускает Codex самостоятельно.
- `003`, final `56247c53...`: 413.58 м перемещения, естественная бочка, обычный native crate **fixture**, перенос native items и restart restore 6 UID/12 шт. Дополнительные 9 шт. третьим restart не проверялись.
- `004`, final `d9147f18...`, implementation `1ca21bdf...`: реальная добыча **20 wood + 20 stones** из природных `TreeEntity`/`OreResourceEntity`, source pools 375→355 и 750→730; 71.65 м, native owned `ItemContainer`; one rock tool UID + condition; после restart все 7 UID/41 шт., actor ID и цели восстановлены. **Механизм SERVER_ACCOUNTED_TOOL**, не `BasePlayer` и не native equipped HeldEntity; поля resource pool между restart **не сохранены**, это отдельный риск. Первый live 004 был PARTIAL из-за FSM, потом фикс `SetFsmActive(false)`.
- Actor `ScientistNPC2 : BaseNPC2`, не `BasePlayer`. В `docs/agent-tasks/RUST-BOTS-004-HARVEST-TOOLS/API_DECISION.md` статический/IL вывод: обычный native gather/PlayerInventory/crafting привязан к `BasePlayer`. Подмена Steam identity запрещена.

## Read-first code

`src/plugins/RustBotsSurvival.cs` (около 370 строк; имеет actor/state, resource discovery, verified pool-debit/award, inventory snapshots); `scripts/Invoke-NavigationProbe.ps1` (флаг `-SurvivalGather`), `scripts/SurvivalValidation.ps1`, `scripts/Test-Survival.ps1`, `scripts/Test-All.ps1`, `scripts/Test-PluginCompile.ps1`, `ProbeCache/ProbeFirewall/OwnedServerProcess` — уже есть. **Не копировать всю 004 в новый монолит без необходимости.** Желательно развить текущий Survival plugin с изолированным режимом `CRAFT` и отдельной проверкой старого режима.

## Цель владельца — НЕ scope одного этапа

50–100 постоянных игроковоподобных ботов: спавн на пляже, фарм, лут, технологии/верстаки, TC, дома/двери/гаражки/сортировка/упкеп, спалки/смерть/возрождение и перестройка после рейдов, кланы/PvP, отдельные РТ/карточки, Giant Excavator Pit с дизелем/ресурсами/защитой. Oil rigs/cargo optional, Semantic Pack в конце. Подробности уже в `docs/agent-tasks/RUST-BOTS-003-WORLD-ROAM-LOOT/LIFE_ROADMAP.md`. Следующим шагом нужны честный крафт и проверка реальных игровых gates; не начинать дом/кланы/карьер в 005.

Ценность — проверяемый игровой прогресс при минимальном расходе лимитов, новый чат Codex для каждой задачи, детальные проверяемые receipts и последующая отдельная сверка ChatGPT с GitHub master.
