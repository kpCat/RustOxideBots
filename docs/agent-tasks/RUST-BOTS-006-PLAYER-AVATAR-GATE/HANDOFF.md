# HANDOFF — что новому Codex известно до старта

**Репозиторий**: `D:\Codex\repos\RustOxideBots`; публичный `https://github.com/kpCat/RustOxideBots`; ветка `master`. Базовый SHA, независимо сверенный через GitHub при подготовке: `ce25f3482468a2be48a4896275657dc59b28e9e5`. Обновления должны делаться только обычным push `origin master`, с exact-path add; не переписывать историю.

**Среда**: `Server/rustds` содержит установленный Rust+Oxide, 6+ ГБ; `Server/` целиком ignored; owner специально настроил соло плагины/конфиги/мир. Существующий тестовый runner создаёт физически отдельный RustDedicated без admin, временные per-program firewall block правила через helper и Job Object kill-on-close; использует warm карту/кеш. Никаких ручных команд владельца и запусков обычного owner сервера.

**001**: Gen2 ScientistNPC2/RustNav — 92,2068 м, 3 complete legs, zero stuck/repath; `b4a2c6f...`. **003**: outdoor 413,58 м, natural barrel, native crate fixture, owned ItemContainer, восстановление 6 UID/12 штук; `56247c5...`. **004**: 71,65 м, 20 wood/20 stones natural pool debit, condition starter rock, восстановление 7 UID/41 единицы; `d9147f1...`. **005**: `200 wood +100 stones` natural debit, `SERVER_ACCOUNTED_CRAFT` stonehatchet UID 65008, нативные `UseItem` debits и новый item, no replay; full independent restart; `ce25f34...`.

**Известный блокер модели**: работающий `ScientistNPC2 : BaseNPC2` не является BasePlayer. Owned ItemContainer не дает нативных PlayerInventory/оружия/брони/крафта. 004/005 IL показывает player ownership gates. У `NPCPlayer : BasePlayer` есть RustNav agent API, но его реальная работоспособность на конкретном server prefab не доказана. ЭТО И ЕСТЬ СУТЬ 006. Не ломать проверенный Gen2.

**Исходники read-first**: `src/plugins/RustBotsSurvival.cs` (005), `RustBotsWorldRoam.cs` (003), `RustBotsNavigationProbe.cs` (001); `scripts/Invoke-NavigationProbe.ps1`, `ProbeCache.ps1`, `ProbeFirewall.ps1`, `OwnedServerProcess.cs`, validators, `Test-All.ps1`. `docs/agent-tasks/RUST-BOTS-004-HARVEST-TOOLS/API_DECISION.md`, `...005.../API_DECISION.md` и `RESULT.md`. Корневой AGENTS.md обязателен.

**Долгосрочная цель**: 50–100 постоянных автономных выживших в соло-Rust: пляж, дороги, бочки/ящики, фарм, инструменты, одежда/оружие, рецепты/верстаки/blueprint, базы/TC/upkeep, двери/гаражки, ящики и сортировка, спалки/respawn, переселение после рейда, PvP/кланы/засады, некоторые РТ/карточки и Giant Excavator Pit (дизель, выбор ресурсов, оборона, конкуренция групп). Oil rigs/cargo — необязательные; Semantic Pack почти в конце. Детальный `LIFE_ROADMAP.md` уже в 003.

**Критическая задолженность**: native tree/ore resource pools в 004/005 могут восстанавливаться после restart — перед production-экономикой нужен durable depletion ledger + crash recovery, а текущий крафт не crash-atomic. Задача 002 про updater остаётся DESIGN ONLY и в 006 не запускается.
