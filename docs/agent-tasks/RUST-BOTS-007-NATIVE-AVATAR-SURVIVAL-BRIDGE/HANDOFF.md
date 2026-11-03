# HANDOFF — факты, которые нельзя потерять при новом диалоге

## Постоянные пользовательские требования

Соло RustDedicated с приватной настройкой под пользователя. Цель проекта — 50–100 автономных «игроков», начинающих бомжами на пляже, добывающих/крафтящих/лутящих ресурсы, строящих базы с TC и upkeep, ящиками, дверями и гаражками, использующих спалки и respawn после смерти; при потере TC честно перестраиваются; союзы/кланы, PvP, оборона, рейды, дорожные RT, карточки, Giant Excavator Pit/дизель/защита. Карго/нефтянки OPTIONAL, Semantic Pack — заключительный этап. Ники и постоянная логическая identity нужны; не подделывать Steam ID и не выдавать бота за реальные аккаунты.

Для каждого задания: отдельный ZIP → отдельный НОВЫЙ чат Codex → /goal → отчет Codex → сверка ChatGPT **с публичным GitHub кодом**. Не тратить лимиты на повторную инфраструктуру или бессмысленные 20 игровых запусков.

## Подтверждённые результаты

| Этап | Подтверждено по опубликованному коду/отчету | Не подтверждено |
|---|---|---|
| 001 `b4a2c6f...` | ScientistNPC2/RustNav 92.2068 м, 3 пути; isolated test runner, per-exe firewall, owned Job, проверенный warm cache | Игроковый inventory |
| 003 `56247c5...` | 413.583 м, native barrel drops, crate **fixture**; owned ItemContainer, restart 6 UID/12 единиц | PlayerInventory, native attack |
| 004 `d9147f1...` | natural tree+ore, wood20+stones20, native pool decrement и износ rock, restart inventory/state | source pool persistence, native equipped |
| 005 `ce25f34...` | native stonehatchet recipe (200 wood+100 stones), accounted craft / UID 65008, restart в owned ItemContainer | нативная queue/экипировка/перенос UID между различными мирами |
| 006 `6834429b...` | ScientistNPC : HumanNPC : NPCPlayer : BasePlayer; player inventory main/belt/wear, real active rock/HeldEntity; 93.69549 м 3 пути; native ResetPath speed=0 fix | persistence, harvest/craft on same BasePlayer actor, client animation |

Официальный результат и конкретные границы 006: `docs/agent-tasks/RUST-BOTS-006-PLAYER-AVATAR-GATE/RESULT.md`, `API_DECISION.md`, `DECISION.md`. Оригинальный код `src/plugins/RustBotsAvatarProbe.cs`; актуальный accounted economy `src/plugins/RustBotsSurvival.cs`; runner `scripts/Invoke-NavigationProbe.ps1`; validators `scripts/AvatarValidation.ps1`, `SurvivalValidation.ps1`, `CraftValidation.ps1`; старые тесты **не менять без необходимости**.

## Установленная локальная среда

- Repo: `D:\Codex\repos\RustOxideBots`; public Git: `https://github.com/kpCat/RustOxideBots`; target `master`.
- Owner runtime `Server/rustds`, source: `Server/rustds/oxide/plugins`, configs `Server/rustds/oxide/config`, data и worlds полностью приватны, `Server/` строго ignored.
- Ранее проверенные Rust protocol `2635.289.1`, Oxide.Rust `2.0.7839`, RustNav, installed DLL. Версии проверять локально заново перед использованием, не предполагать совпадение.
- Самостоятельный headless runner: `scripts/Invoke-NavigationProbe.ps1`, `ProbeCache.ps1`, `ProbeFirewall.ps1`, `OwnedServerProcess.cs`. Тестовый физический install, отдельные writable Oxide/cfg, проверенная identity/map/save, блокирующий firewall через broker и непривилегированный RustDedicated. Предшественники имеют заметный startup ~260+ секунд; использовать warm cache.
- Нельзя запускать owner `Run_DS.bat`, `update.bat`, SteamCMD, производить Rust/Oxide update; задание 002 по безопасному updater остаётся DESIGN ONLY.
- Все предыдущие plugins 001/003/004/005/006 и `AGENTS.md` должны остаться рабочими. Игровые результаты 005 в **другом тестовом мире** не дают права бесплатно выдавать созданный тогда `stonehatchet UID 65008` новому боту — в 007 нужен новый фактически оплаченный продукт/UID.

## Ключевое предупреждение

006 default ScientistNPC loadout включает оружие/медикаменты/костюм. В 007 это **не старт бомжа**: нормализуй только собственный тестовый actor до честного starter kit или явно пометь невозможность; не засчитывай предметы штатного боевого NPC как собственную добычу. Actor netID/native botID различаются между рестартами, а логическая identity должна сохраняться; такое восстановление — **reconstructed logical avatar**, не непрерывная живая Steam-сессия.
