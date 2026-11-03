# HANDOFF — подтверждённые исходные факты и рамки

## GitHub-база

- Публичный репозиторий `https://github.com/kpCat/RustOxideBots`, `master`.
- Начальная контрольная версия задачи: **56247c53eecb3632c8619436d69220db5e815090**, финальный delivery RUST-BOTS-003. Перед записью проверить локальный HEAD, удалённый master, status; при изменениях не выполнять reset/force, согласовать безопасную стратегию с фактическим состоянием.
- Опубликованный 003 implementation commit: `f94bb92544a8df235403004a44099fb13da0bf89`.
- `AGENTS.md` требует приватности `Server/` и owner данных, отдельного isolated runtime, принадлежащих процессу Job Object, firewall deny для тестовой копии, ограниченного quit/cleanup, no broad git add.

## Что действительно достигнуто

- `001`: Gen2 `ScientistNPC2` + `RustNavMeshAgent` физически прошёл 3 отрезка, **92,2068 м**, native NavMesh, no warp. Основной блокер спавна устранён ожиданием полного построения RustNav. Появились reusable warm world/cache + безопасная автоматическая изоляция.
- `003`: Test-only `src/plugins/RustBotsWorldRoam.cs` в live E2E с 1 NPC физически прошёл **413,583 м** (включая ~315 м к дороге); реальные damage+drop из naturally spawned barrel и перенос содержимого обычного `crate_normal_2.prefab`, **который был создан fixture**; live восстановление 6 UID/12 единиц после рестарта; итоговые 10 UID/21 единица ещё раз не восстанавливались третьим запуском. Два живых запуска подтверждены отчётными raw receipts, не собственным независимым запуском ChatGPT.
- 003 native owned `ItemContainer`: `ServerInitialize(null, 48)`, `GiveUID()`, `entityOwner=npc`; перенос `item.MoveToContainer` с UID/amount conservation; сериализация `ItemContainer.Save` и `Load`. **Это НЕ PlayerInventory**. У 003 нет нативной экипировки, взмаха инструментом, крафта и игроковой identity/Steam session.
- Barrel damage в 003 — proximity `LootContainer.OnAttacked(HitInfo)` от NPC, а не анимированная атака реально экипированным инструментом. Не переименовывать это в player-equivalent hit.

## Файлы-аналоги

- `src/plugins/RustBotsWorldRoam.cs` — outdoor route/loot/persistence, ~730 строк. Не раздувать его без ограничений; отдельный survival plugin или аккуратно извлечённые общие классы предпочтительнее монолитной мутации.
- `src/plugins/RustBotsNavigationProbe.cs` — независимая навигационная probe 001.
- `scripts/Invoke-NavigationProbe.ps1`, `ProbeCache.ps1`, `ProbeFirewall.ps1`, `ProbeSafety.ps1`, `OwnedServerProcess.cs`, `WorldRoamValidation.ps1`, `Test-All.ps1`, `Test-PluginCompile.ps1` — готовый автономный E2E стенд.
- `docs/agent-tasks/RUST-BOTS-003-WORLD-ROAM-LOOT/RESULT.md`, `API_FEASIBILITY.md`, `LIFE_ROADMAP.md` — read-first. Будущие user requirements оттуда сохраняются неизменно.
- Задача `002` (safe Rust+Oxide updater) зарезервирована как DESIGN ONLY. В рамках 004 не выполнять и не запускать SteamCMD/обновление.

## Пользовательская цель

Один соло-сервер, в итоге около **50–100 постоянных автономных ботов**, как живые Rust-игроки: пляж, фарм, крафт, технологии, собственные базы и TC, спалки/смерть/respawn, группы и оборона, рейды. Giant Excavator как желаемый поздний этап; oil rigs/cargo — необязательные; Semantic Pack почти в конце. **004 проверяет фундамент добычи, а не реализует всё.**
