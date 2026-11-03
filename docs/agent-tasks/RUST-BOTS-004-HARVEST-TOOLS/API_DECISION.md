# API decision 004 — установленный Rust/Oxide, 03.11.2026

**Решение до live gate:** сохранить доказанный в 001/003 `Rust.Ai.Gen2.ScientistNPC2` и RustNav; добычу реализовать как **SERVER_ACCOUNTED_TOOL**, начальный kit — один настоящий `rock`. Native equipment для этого actor — **NOT_NATIVE_EQUIPPED / LIVE UNKNOWN**. Проверка установленного IL исключает предположение, что Gen2 автоматически получает player-native yield. Сам документ не является live-доказательством 004 и не присваивает GREEN.

## Источники и границы проверки

Read-first: корневой `AGENTS.md`, `README.md`, 004 `TASK.md`, `GATES.md`, `HANDOFF.md`, `ACCEPTANCE.md`, 003 `API_FEASIBILITY.md` и результаты 001/003; `scripts/Inspect-RustApi.cs`, `scripts/Test-PluginCompile.ps1`, релевантные участки обеих существующих navigation/world-roam probes. Аналоги: metadata-only inspector, manifest/prefab discovery и owned `ItemContainer` из 003, выбор RustNav actor из 001. Дополнительные ancestor AGENTS, публичные csproj/props/targets, code-map/pattern-файлы не найдены. Изменение этого исследования ограничено данным документом; runtime/API scope остаётся C# 7.3 без Harmony, обновления DLL, фальшивой Steam identity или подмены настоящих игроков.

Метаданные и IL прочитаны существующим .NET 10 file-based инструментом, **без загрузки или исполнения игровых DLL**, командой следующего вида с отдельными bounded regex:

```powershell
dotnet run --file scripts/Inspect-RustApi.cs -p:PublishAot=false -p:NuGetAudit=false -- Server/rustds/RustDedicated_Data/Managed/Assembly-CSharp.dll '<type-regex>' '<method-regex>'
```

Raw evidence остаётся ignored: `.local/api-harvest004-signatures.txt`, `-resource-il.txt`, `-tool-il.txt`, `-actor-il.txt`, `-pipeline-il.txt`, `-final-gate-il.txt`, `-contracts.txt`, `-versions.txt` с общим префиксом `api-harvest004`. DLL, raw dumps, owner конфиги и секреты не входят в публичный artifact. Git-команды, сервер, updater и SteamCMD в этом исследовании не запускались; `Server/` только читался.

| DLL | File/Product version | SHA-256 |
|---|---|---|
| Assembly-CSharp.dll | 0.0.0.0 / 0.0.0.0 | `04FB89520F18A1920C1B1A350B82DD24A4258F31D97B82496971A9CC7A49DCB7` |
| Oxide.Rust.dll | 2.0.7839.0 / 2.0.7839+aa85087dbf8ae6129d0c28da7680915f3ff56895 | `2128121E34B55BB1550D43E62842B87EA3720059F13DC84F97D8C7DD465C3423` |
| Rust.Data.dll | 0.0.0.0 / 0.0.0.0 | `1D62BAEF9B339F0416E6529618365C1ECAD01791A833E77E76EB6C8464406104` |
| UnityEngine.CoreModule.dll | 0.0.0.0 / 0.0.0.0 | `6B971445185B5F71834C4BCCD7CEAA6264CFB27841E8EA8364FCD15188E246E9` |

Версии выше — фактический PE VersionInfo, а не вывод о текущем Steam release. Rust protocol/buildid из 003 здесь заново не проверялся; точную DLL однозначно фиксирует hash.

## A/D: actor, экипировка и будущая смена модели

| Возможность | Gen2 ScientistNPC2 / BaseNPC2 | NPCPlayer / BasePlayer | Уровень доказательства |
|---|---|---|---|
| Наследование | `ScientistNPC2 : BaseNPC2 : BaseCombatEntity`; не BasePlayer | `NPCPlayer : BasePlayer : BaseCombatEntity` | STATIC signatures |
| Player identity/inventory | Нет PlayerInventory в этом классе; owned ItemContainer — отдельный контракт | `BasePlayer.inventory : PlayerInventory`, `svActiveItemID : ItemId` | STATIC; отсутствие подмены identity обязательно |
| Native tool owner | `BaseEntity.ToPlayer()` возвращает null; Gen2 не переопределяет | `BasePlayer.ToPlayer()` возвращает this | IL |
| Экипировка | Штатный player-owner путь не обслуживает Gen2; контейнер не является экипировкой | `UpdateActiveItem(ItemId)`, `GetHeldEntity()`, `GetActiveItem()`; `NPCPlayer.EquipWeapon(bool)` | STATIC/IL; визуальный результат 004 UNKNOWN |
| Native melee | `BaseMelee.ServerUse` без owner player возвращается | `NPCPlayer.MeleeAttack()` вызывает held `BaseMelee.ServerUse(...)` | IL; это само по себе ещё не tool gather |
| RustNav | Совместимость prefab доказана 001/003, 004 требует собственный live receipt | **Есть** public `NPCPlayer.NavAgent : RustNavMeshAgent`, `LegacyNavigation : bool`; `BaseNavigator` также знает RustNav | STATIC; конкретный NPCPlayer prefab/live controls UNKNOWN |
| Native yield | Отсечён player validity gate в ResourceDispenser | BasePlayer проходит типовой gate, последующие предпосылки ещё нужны | IL; live harvesting 004 UNKNOWN |
| Crafting | Owned ItemContainer не создаёт PlayerInventory/ItemCrafter автоматически | PlayerInventory.crafting, PlayerBlueprints, native queue/recipes | STATIC/IL; реализация за рамками 004 |

Подтверждённый исторический prefab 003: `Assets/Rust.Ai/Agents/NPCPlayer/HumanNPC/Scientist/Gen2/Scientist2.prefab`, runtime `Rust.Ai.Gen2.ScientistNPC2`. В 004 его снова следует выбирать через установленный `GameManifest.Current.entities` → `FindPrefab` → `GetComponent<ScientistNPC2>` и `GetComponent<RustNavMeshAgent>`, затем писать фактический prefab/type. У NPCPlayer наличие RustNav-поля не доказывает готовность любого prefab к переключению; сохранение Gen2 в 004 минимизирует риск навигации, но не объявляет будущую player-derived модель невозможной.

`HeldEntity.GetOwnerPlayer()` сначала принимает `forcedOwner : BasePlayer`, иначе вызывает `GetParentEntity().ToPlayer()` и требует живого BasePlayer. `TryGetOwnerPlayer(out BasePlayer)` делегирует этому методу. `HeldEntity.SetupHeldEntity(Item)` записывает item UID и вызывает owner initialization. `ItemModEntity.OnParentChanged(Item)` при `playerOnlyEntity=true` и отсутствии `Item.GetOwnerPlayer()` уничтожает held entity; `ParentToPlayer` ищет именно `ItemContainer.GetOwnerPlayer()`. `HeldEntity.SetHeld(bool)` действительно меняет флаги/visibility/network state, но один такой вызов не создаёт player owner, player inventory, native анимацию Gen2 и рабочий melee.

В исполняемом коде достаточно компактного actor contract (identity, entity, owned inventory, goals), equipment contract (реальный rock UID и прочитанный профиль/износ) и harvest action. Эти адаптеры должны обслуживать planner и учёт; пустые интерфейсы и новая общая infrastructure здесь не нужны. Future player avatar bridge может заменить actor/equipment без замены planner или conservation rules.

## B: почему NPC damage не равен native gather

Проверены `TreeEntity : ResourceEntity`, `OreResourceEntity : StagedResourceEntity : ResourceEntity`, где `ResourceEntity : BaseEntity`, **не BaseCombatEntity**. Публичны `ResourceEntity.health`, `startHealth`, `Health()`, `MaxHealth()`, `OnAttacked(HitInfo)`; dispenser является отдельным component (`resourceDispenser` в ResourceEntity protected), получать его следует обычным `GetComponent<ResourceDispenser>()`.

Последовательность native player tool gather:

1. `BaseMelee.PlayerAttack(RPCMessage)` после проверок вызывает `DoAttackShared(HitInfo)`.
2. `DoAttackShared` вызывает `GetAttackStats`; в override `BaseMelee.GetAttackStats` добавляет реальный `damageTypes` и ставит `CanGather = gathering.Any()`, затем вызывает `HitEntity.OnAttacked` и condition update.
3. `TreeEntity`/`OreResourceEntity.OnAttacked` могут менять `gatherScale` для hotspot. `ResourceEntity.OnAttacked` после server/isKilled/Oxide damage-hook gate передаёт hit в `ResourceDispenser.OnResourceDispenserAttacked` → `DoGather(hit,null)`.
4. `DoGather` требует `CanGather && !DidGather`. При настоящем `Weapon is BaseMelee` берёт `GatherPropertyEntry`, учитывает `gatherDamage`, `destroyFraction`, `conditionLost`, снижает condition и ставит `DidGather`. Без BaseMelee использует `damageTypes.Total()` и destroy coefficient 0,5.
5. `HitInfo.InitiatorPlayer` вызывает `Initiator.ToPlayer()`. `DoGather` передаёт его в **private `GiveResources(BasePlayer,float,float,AttackEntity)`**. На `IL_0000..0008` проверяется `BaseNetworkableEx.IsValid(player)` и выполняется ранний return при null. Публичный `GiveResourcesForDamage(BasePlayer,float,float,AttackEntity)` имеет тот же validity gate и не является обходом для Gen2.
6. Для настоящего BasePlayer private `GiveResourceFromItem` сначала вычитает из `ItemAmount.amount` базовый debit и destruction waste (`IL_0088..00A9`), затем создаёт Item (`IL_011E..012A`), проходит `OnDispenserGather`/ownership/analytics и выдаёт его `BaseEntity.GiveItem`. Есть отдельные бонусы/модификаторы, hooks, finish bonus и дробное округление. Это объясняет, почему собственный adapter output нельзя начислять поверх native gather.

`BaseMelee.ServerUse(HeldEntityServerUseParams)` на `IL_0012..0022` возвращается без owner BasePlayer. Даже у NPCPlayer `ServerUse_Strike` создаёт generic damage `HitInfo`, не вызывает `GetAttackStats` и не присваивает ему `Weapon`/`CanGather`. Поэтому наличие NPCPlayer.MeleeAttack не доказывает native tool gathering/player-equivalent behavior; для будущего перехода нужен отдельный рабочий attack/gather path и live-проверка.

Для исходного Gen2 damage experiment нужен настоящий natural source, bounded удар и before/after health/pool/inventory. При `Weapon=null` и `CanGather=true` dispenser не выдаёт Gen2 предметы: null-player gate, без заявлений о live до измерения. Само уменьшение health ещё не доказывает уменьшение `containedItems`.

## C: минимальный SERVER_ACCOUNTED_TOOL с native pool debit

Подтверждённые публичные contracts:

```text
ResourceDispenser.containedItems : List<ItemAmount>
ResourceDispenser.fractionRemaining : float
ResourceDispenser.gatherType : ResourceDispenser.GatherType
ResourceDispenser.DestroyFraction(float) : void
ResourceDispenser.UpdateRemainingCategories() : void
ResourceDispenser.CountAllItems() : void
ItemAmount.itemDef : ItemDefinition
ItemAmount.amount / startAmount : float
ItemAmount.itemid : int
BaseMelee.GetGatherInfoFromIndex(ResourceDispenser.GatherType) : ResourceDispenser.GatherPropertyEntry
ResourceDispenser.GatherPropertyEntry.gatherDamage / destroyFraction / conditionLost : float
ItemManager.CreateByName(string,int,ulong) : Item
Item.MoveToContainer(ItemContainer,int,bool,bool,BasePlayer,bool) : bool
Item.LoseCondition(float) : void
```

**Не угадывать по имени:** `DestroyFraction(x)` в установленном IL вычитает **x / categoriesRemaining единиц** из каждой положительной `ItemAmount.amount` (`IL_0016..0033`), затем `UpdateVars` пересчитывает fraction и число категорий. Это не множитель оставшегося пула, не процент и не выдача предметов. Метод не делает clamp до нуля. При ровно **одной** положительной категории и целочисленном `q < amount` он уменьшает настоящий pool ровно на q. Многоресурсный/дробный/пустой pool должен быть отвергнут этим минимальным adapter, а не пропорционально превращён в один выбранный item.

Предлагаемая транзакция выполняется синхронно на server thread без yield/callback между debit и transfer:

1. Проверить owned rock UID/amount/condition, фактический profile, cooldown, natural source type/ID/world binding, range/LOS, ровно одну положительную wood или stones category, конечные положительные amount/startAmount/fraction. Зафиксировать весь pool, inventory UID/amount и health. `q` ограничить реальным gather profile, недостатком ресурсов и `floor(amount)-1`, сохраняя source непустым. Никаких finish/hotspot бонусов и повышающих серверных gather multipliers.
2. При необходимости выполнить bounded native health-only hit, проверить результат и отсутствие pool/output delta. **До debit** ошибка или несовпадение останавливает действие.
3. Вызвать `DestroyFraction(q)`, проверить `poolBefore - poolAfter == q`, уменьшение fraction и неизменность других entries. Только затем `ItemManager.CreateByName(shortname,q,0)` и `MoveToContainer(owned,-1,false)` с отключённым stacking. Проверить новый UID, item type, amount и ровно `inventoryAfter - inventoryBefore == q`.
4. Учитывать `conditionLost` через настоящий rock Item, если `hasCondition`; записывать actual condition before/after. Исчезнувший/broken tool или отсутствие ожидаемого condition debit при применимом износе останавливает дальнейшие действия.
5. При ошибке не выдавать повторный item. Удалить ещё не перенесённый pending output; pool rollback допустим только при доказанно неизменном destination и исходном source entry. Восстановить поле `ItemAmount.amount` до собственного before, вызвать `UpdateRemainingCategories()`, затем `DestroyFraction(0)` для пересчёта fraction. Порядок важен: stale нулевой categoriesRemaining даёт 0/0 и NaN даже с нулевым аргументом. При изменившемся destination, неоднозначном native output или неизвестном rollback результате — fail closed, сохранить диагностические receipts и не повторять credit. Не возвращать pool, если output уже оказался в inventory.

Точный порядок condition/accounting receipt и обработки исключений должен быть проверен реализацией; рекомендация не утверждает crash-atomic транзакцию с дисковым журналом. Не считать заранее созданный Item добычей: новый resource output в нормальном пути создаётся только после проверенного source debit.

Для health-only `HitInfo`: `Initiator=ownedNpc`, `HitEntity=source`, `Weapon=null`, `WeaponPrefab=null`, **CanGather=false**, **DidGather=false**, `gatherScale=0`, реальные `PointStart/PointEnd/HitPositionWorld`. Native rock damage можно получить через `rockPrefab.GetAttackStats(hit)` и затем **сбросить CanGather=false**; `Rust.DamageTypeList.ScaleAll(float)` публичен для ограничения суммы до profile/health budget. Не вызывать `DoAttackShared`, повторно включающий CanGather. `DoGather` возвращается на `IL_000E..001E`; ResourceEntity после этого применяет `baseProtection.Scale(damageTypes,1)` и снижает health (`IL_0048..0080`). **UseProtection=false не отключает эту конкретную protection ветвь.** Tree с CanGather=false сразу делегирует ResourceEntity; Ore с gatherScale=0 пропускает hotspot ветвь, но перед base call может вернуть gatherScale=1 — CanGather всё равно остаётся false. Реальное снижение health зависит от live protection; нулевой health delta не заменяет проверенный pool debit и не даёт права обходить protection.

Не добивать/не Kill source ради результата; минимальному учёту достаточно частичной добычи. `DestroyFraction` не создаёт Item, health-only удар не запускает gather; эти два свойства обеспечивают один debit/один adapter output. Дополнительно receipts должны показать отсутствие новых native drops/чужих UID; обнаруженный второй output — ошибка, а не повод его зачесть.

## Начальный kit и реальные tool definitions

`PlayerInventory.GiveDefaultItems()` в обычной ветви установленного IL выдаёт `rock` (`IL_003F..004A`) и `torch` (`IL_004F..005A`). Есть отдельная game-mode loadout ветвь и сезонные добавки; adapter 004 вправе взять только **rock ×1, skin 0** как явно описанный минимальный subset стандартного kit. Это отдельный starter receipt с реальным UID, а не wood/stone yield, не крафт и не скрытая кирка.

`ItemModEntity.entityPrefab : GameObjectRef` публичен. Читать фактический rock `ItemDefinition`/`GetComponent<ItemModEntity>()`, искать его `entityPrefab.resourcePath` через native `FindPrefab`, читать `BaseMelee` component и `GetGatherInfoFromIndex`. Для чтения definition не нужно создавать/Spawn ещё один world tool. `gathering` имеет Tree/Ore/Flesh entries. Значения rock maxDistance/gatherDamage/destroyFraction/conditionLost, `Item.hasCondition`, maxCondition и actual held entity у 004 должны попасть в live receipt; значения asset-полей не извлекаются из одной сигнатуры и здесь не выдуманы.

`Item.hasCondition` проверяет `info.condition.enabled && info.condition.max > 0`. `Item.LoseCondition` имеет early return для отсутствующей condition, статического флага `disablecondition` и перехвата `IOnLoseCondition`, затем уменьшает native condition. Поэтому вызов без actual condition delta не доказывает износ; item без condition требует честного `NOT_APPLICABLE`, а не искусственно придуманной durability. `BaseMelee.LoseCondition` разрешает owner Item через player-oriented held path; Gen2 adapter использует свой настоящий Item напрямую.

## Сохранение и E: будущий native crafting

Переиспользуется 003: `ItemContainer.ServerInitialize(Item,int)`, `GiveUID()`, `entityOwner=ownedNpc`, native `Save(bool,bool)`/`Load(ProtoBuf.ItemContainer)` и exact test-world generation/.sav SHA binding. Восстановление должно включать rock/resource UID и amount, stable synthetic character ID, goals и память отвергнутых/посещённых source IDs. Live restart 004 ещё обязателен; успешный 003 не засчитывается автоматически.

**Source pool persistence не подтверждена:** ResourceEntity.Save/Load сохраняет/читает `ProtoBuf.BaseResource.health`; StagedResourceEntity добавляет stage и при disk/server Load явно сбрасывает health=startHealth/stage=0. У ResourceDispenser в установленном type вообще нет Save/Load, а `containedItems` не сериализуется ResourceEntity.Save. Нельзя заявлять сохранение exact resource pool через restart по одному .sav hash. Минимальный 004 может восстановить inventory/goals и избегать уже обработанных source IDs с prefab/position/world binding; постоянный source ledger и его безопасное применение — отдельная реализация/валидация. Before/after native pool debit текущего запуска при этом проверяется непосредственно.

Для 005 существуют `PlayerInventory.crafting : ItemCrafter`, `ItemCrafter.owner : BasePlayer`, containers/queue, `CanCraft(ItemBlueprint,int,bool)`, `CraftItem(ItemBlueprint,BasePlayer,InstanceData,int,int,Item,bool,int)`, `FinishCrafting`, Save/Load очереди. ItemBlueprint содержит ingredients, userCraftable/defaultBlueprint, time, amountToCreate, workbenchLevelRequired, `GetIngredients()` и `GetWorkbenchLevel()`. `PlayerBlueprints.CanCraft(int,int,BasePlayer)` проверяет currentCraftLevel против GetWorkbenchLevel (`IL_0044..005E`), затем HasUnlocked (`IL_005F..006B`); ItemCrafter.CanCraft отдельно проверяет usable ingredients/condition и размер очереди. Поэтому прямой вызов CraftItem не доказывает соблюдение всех player blueprint/bench requirements. Для NPCPlayer возможен следующий исследовательский шаг с настоящими ingredient debits/queue, доступными blueprint и workbench; Gen2 owned container не получает это автоматически. 004 не выдаёт crafted tools и не реализует крафт.

## Что остаётся LIVE UNKNOWN

Конкретные natural tree/ore prefabs и pools на карте 004, реальные reachable approaches/LOS и физическое перемещение, asset values rock, actual condition semantics, Gen2 native equipment/animation, отсутствие второго output, независимое восстановление UID/character/goals, runtime Oxide compilation и safety cleanup. Всё перечисленное требует самостоятельных 004 receipts. Только STATIC/IL gate данного документа завершён; итоговые WOOD/ORE/TOOLS/PERSISTENCE/NAVIGATION/SAFETY заполняются по настоящим запускам в RESULT.

## Дополнение: scheduler gate после первого live 004

Первый run `.local/runtime/7aa268c9d09d445eb7bd2a63ee2e6bfd/` сохранил исходный **PARTIAL**: natural wood pool 375→355, два настоящих output UID и износ rock подтверждены; путь к ore прервался timeout, NPC двигался обратно к spawn. Его evidence и исходный plugin snapshot не переписываются. Ниже — read-only STATIC/IL диагностика причины и обоснование исправления; успешный повтор ею не подменяется.

В snapshot 004 использовалось `fsm.enabled=false`. Локальные аналоги 001/003 на самом деле вызывают **`fsm.SetFsmActive(false)`**. Это разные механизмы: `Scientist2FSM.InitShared` заканчивает `SetFsmActive(true)` (`IL_0781..0783`), Heavy-вариант — аналогично (`IL_0360..0362`). `FSMComponent.SetFsmActive(false)` меняет private `isRunning` и удаляет FSM из native `workQueue` (`IL_0032..0039`). У FSMComponent нет OnDisable; `Tick()` не проверяет Unity enabled. `TickFSMWorkQueue.RunJob` проверяет `ShouldAdd` и `isRunning`, затем вызывает senses/FSM tick; inherited `PersistentObjectWorkQueue<T>.ShouldAdd` в Rust.Global.dll возвращает true. Поэтому выключение Unity component само по себе не снимает native scheduler registration.

`State_Patrol.TrySetPatrolDestination` при выходе за homeRadius предпочитает направление к сохранённому spawn, вызывает `RustNavMeshAgent.SetPath` (`IL_01F0..01FB`) и меняет speed. Это установленный путь перезаписи plugin navigation и согласуется с наблюдаемым возвратом; фактическое имя текущего FSM state в первом run не логировалось. Минимальное исправление — вызвать `SetFsmActive(false)` после Spawn, точно как 001/003. Дополнительно восстановлен их порядок выбора prefab с предпочтением non-heavy; отдельная неспособность Heavy к управлению не доказана. Расширять recovery или регулярно перезаписывать destination для борьбы с scheduler не требуется.

`RustNavMeshAgent.SetDestination` не имеет stop-state gate в RustNav-ветви; `isStopped` только меняет флаг. Оснований приписывать этот timeout порядку снятия isStopped не найдено. `ResetPath` дополнительно обнуляет desiredSpeed и stopping-distance override, поэтому не нужен как недоказанный обход. Public `destinationWS`, path state и stop flag пригодны для компактного control receipt в повторном run. Source correction и offline contract подтверждают вызов нужного API; физическое движение/ore/restore доказываются только оставшимися live-запусками.

Raw IL: `.local/api-harvest004-navigation-signatures.txt`, `-navigation-il.txt`, `-fsm-queue-il.txt`, `-global-queue.txt` (общий префикс `api-harvest004`). Дополнительно исследованный Rust.Global.dll SHA-256: `84B661F33746DEEBD0345C0044CFE42BD04C0C80CC6A587E42D7C3DD5A1102BF`. В этой диагностике сервер не запускался; source/runner/cache и owner runtime не изменялись, Git не использовался.
