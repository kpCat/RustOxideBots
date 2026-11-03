# RUST-BOTS-004 — автономная добыча дерева/руды и контракт инструментов

**Статус постановки:** NOT STARTED. **Исполнитель:** Codex в новом чате, High. **Репозиторий:** `D:\Codex\repos\RustOxideBots` / public GitHub `kpCat/RustOxideBots` / `master`. **Pinned baseline:** `56247c53eecb3632c8619436d69220db5e815090`. **Главный приоритет:** реальный прогресс игровой механики при контролируемой стоимости E2E.

## 0. Желательный исход

Один автономный человекоподобный NPC самостоятельно определяет недостаток дерева и камня/руды, находит на *реально сгенерированной тестовой карте* естественный природный объект подходящего типа, добирается до него на RustNav без телепортации, использует реальный предмет-инструмент (или явно классифицированный server adapter), корректно снижает запас/состояние природного источника, переносит результат добычи в собственный native ItemContainer, а после полного перезапуска сервера восстанавливает те же предметы/UID без дублирования. **Физическую добычу и бухгалтерию проверять отдельно от анимации/экипировки.**

Задача состоит из одного укрупнённого E2E с безопасной диагностикой, а не из множества несвязанных микроподзадач. Не делать сейчас постройку домов, сложный крафт/tech tree, PvP, корабли, нефтянки, кланы и масштабирование; они зависят от доказанного фундаментального слоя.

## 1. Обязательный API-gate ДО затратного live запуска

1. Прочитай `AGENTS.md`, актуальные 001/003, локальный установленный API Rust/Oxide. Исследуй реальные сигнатуры/IL в **локальных** `Assembly-CSharp.dll` и прочих установленных DLL, не переносить неподтверждённые методы из интернет-образцов. Конкретно: `ScientistNPC2`, `NPCPlayer`, `BasePlayer`, `PlayerInventory`, `ItemContainer`, `Item`, `HeldEntity`, `BaseMelee`, `HitInfo`, `TreeEntity`, ore/resource entities, `ResourceDispenser`, native attack/gather/drop, item durability, RustNav и сохранение.
2. Зафиксируй доступные конкретные prefab/type и механизмы убыли source resource и появления output item; не угадывай, что `OnAttacked` с initiator=NPC выдаст добычу точно как игроку. На каком этапе проверяется `BasePlayer`? Чем отличается настоящий native gather от ручного начисления?
3. Реши интерфейс `ISurvivorActor`/`IEquipmentAdapter`/`IHarvestAction` или близкий компактный вариант: отделить identity/инвентарь/цели от конкретного класса `ScientistNPC2`, чтобы позже при необходимости сменить актёра на BasePlayer-derived без полного переписывания. Не добавляй пустую абстракцию ради объёма: интерфейсы должны обслуживать исполняемый код.
4. Сделай небольшой `API_DECISION.md` с таблицей возможностей `Gen2 BaseNPC2` и `NPCPlayer/BasePlayer` (доказано сигнатурой/IL, tested live, unknown). Запрет на фальшивую Steam identity или подмену имён настоящих игроков.

## 2. Поведение: не статический сценарий выдачи предметов

- Пилот: **один NPC**; стабильная личность для теста, owned inventory и цели по принципу «есть недостаток дерева/камня — выбрать подходящий реальный узел»; без жёсткого маршрута и заданных координат деревьев/рудников. Минимальный planner `NeedResource → Discover → Navigate → Harvest → Verify → Carry/Save`, с bounded retry на недоступные цели и памятью недавно отвергнутых/истощённых узлов. Допускается детерминированный seed для воспроизводимого теста.
- Не создавать специальное дерево/рудную жилу в качестве доказательства **natural gathering**. Полный GREEN требует live `NATURAL` source для **двух категорий**: дерево (wood) и хотя бы один ore/stone node (stone/metal/sulfur). Fixture допускается только для диагностического PARTIAL, provenance обязательно в receipts.
- Обнаружение целей через реально существующие world entities и reachable `RustNav` complete paths. Подход на допустимую дистанцию, grounded/clearance/LOS, bounded ожидание, timeout и recovery; никаких `MovePosition`, teleport или порчи производительной навигации 001/003.
- Инструмент: разрешён **только явно описанный начальный kit** уровня обычного бомжа (например, stone/rock и torch, если реально допустимы установленным API). Записать, какие реальные `Item` и UID при спавне выдаются этому одному тестовому боту и почему это стандартное начальное снаряжение, а не добыча. Не создавать кирку из воздуха, если её не скрафтили/не добыли. Отдельно проверить, может ли `ScientistNPC2` держать/показывать/использовать tool и/или боевое оружие через нативные API; если нельзя — явно `NOT_NATIVE_EQUIPPED` и план перехода к другой модели actor, без фальшивого GREEN в части экипировки.
- Взятый в инвентарь предмет **не равен экипированному**. Если инструмент не надет нативно, разрешён только явно маркированный **SERVER_ACCOUNTED_TOOL** с проверкой доступности инструмента, range/LOS, ограниченного урона, стоимости/износа, если применимо. Этот режим не выдавать за реальные player animations или native melee. Любая выдача добычи через `ItemManager.Create...` должна быть объяснена debit из фактического источника, проверена по его native pool и защищена от двойного начисления.
- Предпочитать серверный native harvest pipeline, если он действительно работает для данного actor. **Нельзя** мгновенно `Kill()` ресурсную сущность и объявить, что NPC «фармил»; нельзя просто `GiveItem` без уменьшения источника. Не снимать ресурсы из чужих сундуков/TC или owner мира.

## 3. Учёт источника и инвентаря

Для каждого дерева/ore-node зафиксировать:

- Конкретный runtime type/prefab, ID объекта в тестовом мире, `NATURAL`/`FIXTURE`, координату, реальную дистанцию и маршрут; состояние resource/health/dispenser до и после, число реальных ударов и recovery, если применимо.
- Доказательство: `available resource` или health/remaining уменьшается; конкретный механизм native/resource-adapter; `Item`-output с UID/shortname/amount, delta owned inventory; отсутствие второго начисления от native drop и adapter. Изначальный starter kit учитывать отдельно.
- Не использовать предметы из будущего, hidden bonuses, подмену native drops и free resource injections. Если нельзя надёжно уменьшить реальный source pool при честном output — это `BLOCKED` для добычи, а не оправдание для обхода.
- Разбить статусы минимум на `WOOD`, `ORE`, `TOOLS`, `PERSISTENCE`, `NAVIGATION`, `SAFETY`. В summary различать `NATIVE_PLAYER_EQUIVALENT`, `NATIVE_NPC_DAMAGE_WITH_YIELD`, `SERVER_ACCOUNTED_TOOL`, `UNVERIFIED`. Нельзя назвать механикой живого игрока простой перенос `Item` в контейнер.
- Сохранить/восстановить **не только инвентарь, но и тестовый идентификатор персонажа и состояние его целей/инструмента**, если это уже реализуемо без огромной архитектуры. Привязка snapshot к точному завершённому test world generation/.sav/hash обязательна по аналогии с 003; отсутствие успешного restart означает PERSISTENCE=PARTIAL.

## 4. Реализация

- Лучше создать `src/plugins/RustBotsSurvival.cs` (или другое явно обоснованное имя) и маленькие общие компоненты, чем безразмерно копировать 003. Существующие 001/003 сохраняются рабочими. Работать на C# синтаксисе, который поддерживает установленный Oxide.Compiler (в 003 C# 7.3). Ни Harmony/патча Rust, ни запуска обновления в scope нет.
- Перенести в новый тестовый сценарий **только необходимые** безопасные части existing world roam: startup/actor/navigator/owned inventory, native item transfer/persistence, результаты, а не весь скрипт. Не выдумывать API — проверить IL и compile.
- Адаптировать runner минимально, например новым ключом `-SurvivalGather` / отдельным mode; оставить исходные флаги 001 и 003 работоспособными, fixture tests не выдавать за live. Использовать существующие warm `.local/probe-cache`, независимые Oxide/config/data, свои временные порты, firewall block и Job Object, текущий UAC helper. Игровой сервер запускает/закрывает **сам Codex**, не пользователь.
- Ограничить live-циклы: целевой бюджет **до 2**, при доказанном техническом дефекте — **максимум 3** controlled live launches. Сначала offline compile/API gate, потом живой запуск; рестарт для persistence вторым запуском. Если реальный блокер — завершить с диагностикой, не строить бесконечные цепочки починок.
- Следить за производительностью: resource discovery не сканирует все сущности на каждом tick, выбирает кандидатов с bounded rate/distance и планирует следующее действие по событию, а не 100-кратному polling. Не включать 50–100 NPC сейчас.

## 5. Безопасность и Git

- `Server/` включая 6,6 ГБ, owner `oxide/plugins/config/data`, карты, cache, сохранения, скрипты обновления и приватные секреты остаются untracked/ignored/read-only. Не запускать `Run_DS.bat`, `update.bat`, SteamCMD, task 002. Не чистить owner mods. На isolated test server не копировать owner writable data, создавайте тестовые подпапки с new test identity.
- Никаких редактирований `AGENTS.md` без необходимости; если меняешь правила — обоснуй. Нельзя удалять старый `RESULT` или менять вывод 003 задним числом.
- При чужом RustDedicated или SteamCMD процесс не запускать второй; не убивать чужие PID; cleanup только своего owned Job и временных правил firewall, подтвердить 0 своих PID/ports/rules/lease. Возможный UAC не отменяет изоляцию; никакого широго отключения защиты.
- Запрет на публикацию `Server/`, `artifacts/`, `.local/` и секретов; проверить `git check-ignore` и `git ls-files -- Server/`. Git: проверить origin/master, exact-path staging после обзора diff, коммит(ы) и обычный fast-forward `push origin master` без force/rebase/reset/clean/stash, рабочее дерево чистое. В текущей задаче **пользователь явно разрешает commit и push** для собственных проверенных файлов 004.
- Проверить отдельно mojibake (кракозябры) и escaped Cyrillic в изменённых текстовых файлах; не переписывать русские строки в Unicode-escape. Нет нужды включать или отключать сеть ради загрузки compiler/MapCache.

## 6. Финальный результат

В `docs/agent-tasks/RUST-BOTS-004-HARVEST-TOOLS/RESULT.md` обязательно: полный verification matrix из ACCEPTANCE; версии runtime, конкретный actor/prefab и статус gear, настоящий source provenance, маршруты, physical displacement, урон и изменение source pool, UID/amount переходы, before/after и after-restart; raw receipt path в ignored `.local`, live run count/time/failure reasons; outcome GREEN/PARTIAL/BLOCKED; owner hash preservation; processes/ports/firewall cleanup; change allowlist; commit SHA + remote receipt (если SHA самого финального commit неизвестен во время формирования RESULT, отдельный ignored receipt + финальный ответ). Подтверждения без локального Rust процесса помечать offline/fixture, а не live.

Начать с gameplay и API, не переключаться на updater 002 и десятки новых вспомогательных скриптов. Следующее после 004 — реальные рецепты/крафт/верстаки, затем base/TC и жизненный цикл — только когда фундамент доступен.
