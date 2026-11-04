# 010 — установленный API, до LIVE

Статус этого раздела **STATIC_IL / OFFLINE_COMPILE**, не live proof. Исследование PEReader не исполняло игровые DLL; serialized assets прочитаны UnityPy из установленной копии. Raw остаётся в ignored `.local/audit/home010/api-build/` и `api-nav/`.

## Native placement / оплата

- `Planner.DoBuild(ProtoBuf.CreateBuilding):void` — полный серверный путь, включая начальные affordability/deployable/socket/CanBuild checks. Клиентский input не заявляется.
- Выбран public `Planner.DoBuild(Construction.Target,Construction):BaseEntity` на **настоящем held Planner из оплаченного Item**. Явно повторить пропущенные входные проверки `GetOwnerPlayer`, `GetDeployable`, `CanAffordToPlace`, `BasePlayer.CanBuild()` и `CanBuild(Vector3,Quaternion,Bounds)`. Он выполняет native socket occupancy/LOS/placement и payment, поэтому повторно материалы не списывать. Механизм маркировать **SERVER_ACCOUNTED_BUILD**, без имитации RPC/Steam connection.
- `Construction` находится через `PrefabAttribute.server.Find<Construction>(StringPool.Get(prefab))`; native sockets — `FindAll<Socket_Base>(prefabID)`. `CreateConstruction(target,true)` вызывает native placement/socket mods и `DecayEntity.AttachToBuilding`; частный `Planner.SpawnConstruction` задаёт default grade/health/OnPlaced/owner, Spawn и OnConstructionBuilt/PayForPlacement. Ручная копия spawn-последовательности не выбрана.
- `Construction.Target` содержит world-space position/normal/ray/rotation(Euler), player, entity/socket, valid/onTerrain/shouldParent и snapping flags. Геометрия дома относительна найденному site; sockets берутся из фактических loaded объектов.
- Native placement оплачивает Twig. Wood upgrade: `CanChangeToGrade(Wood,0,actor)`, `CanAffordUpgrade(Wood,0,actor)`, `SecondsSinceAttacked>=30`, затем **ровно один** `PayForUpgrade(ConstructionGrade,BasePlayer)` и `ChangeGrade(Wood,true,true)` — установленная последовательность RPC. Не ставить freeBuild/setToGrade.
- `ItemModEntity.playerOnlyEntity` требует native Item.GetOwnerPlayer, но не исключает IsNpc. Способность owned ScientistNPC получить Planner подтверждена IL, **LIVE UNKNOWN**.

## Загруженные prefab / цены

| Элемент | Точный установленный prefab | costMultiplier |
|---|---|---:|
| Foundation | assets/prefabs/building core/foundation/foundation.prefab | 1 |
| Wall | assets/prefabs/building core/wall/wall.prefab | 1 |
| Doorway | assets/prefabs/building core/wall.doorway/wall.doorway.prefab | около 0.7 |
| Roof/floor | assets/prefabs/building core/floor/floor.prefab | 0.5 |
| Door | assets/prefabs/building/door.hinged/door.hinged.wood.prefab | Item |
| TC | assets/prefabs/deployable/tool cupboard/cupboard.tool.deployed.prefab | Item |

Serialized base Twig: wood50, Wood: wood200. `ConstructionGrade.UpdateCosts` применяет construction multiplier, target grade ConVar multiplier и Ceil; читать `defaultGrade.CostToBuild((BuildingGrade.Enum)(-1))` и `woodGrade.CostToBuild(currentGrade)`, не подменять runtime цену этой таблицей. Vanilla шесть блоков: Twig260 + Wood1040. Default/bench0/output1 recipes: building.planner20 wood; hammer100 wood; wood door300 wood; TC1000 wood. Общий строительный бюджет2720 wood до инструмента и upkeep — **STATIC ожидание**, runtime обязан перечитать цены.

Foundation top=pivot y, bounds center(0,-1.4,0)/extents(1.4,1.4,1.4). Foundation female wall sockets /1..4 расположены (0,0,-1.5),(-1.5,0,0),(0,0,1.5),(1.5,0,0); native support1. Roof использует actual wall/floor-female /1 или /2 на y3, не dummy /3-/4 на y1.5. Doorway native door sockets на y1. Door и TC `Deployable.setSocketParent=false`: не принуждать transform parent; использовать native building group/socket links.

## TC / сохранение

- Public `BuildingPrivlidge.AddPlayer(BasePlayer,ulong)` добавляет engine-assigned bot ID в native HashSet без Steam validation; `IsAuthed(BasePlayer)`, `IsAuthed(ulong)`, `CanBuild(BasePlayer)` проверяются отдельно. Autoauth после spawn **не предполагается**.
- `CalculateUpkeepCostAmounts(List<ItemAmount>)`, `CalculateUpkeepPeriodMinutes()`, `GetProtectedMinutes(bool)` — реальные расходы/срок; native Item.MoveToContainer переносит физический запас. Никаких timer/decay writes.
- BaseEntity.Save/Load сохраняют OwnerID; DecayEntity — buildingID и forDisk decay/upkeep; BuildingBlock — grade; StabilityEntity — support/distance; StorageContainer — native ItemContainer/UID; TC — raw authorized IDs без Steam filter.
- Restore допускает rebind только после actual fromDisk witness UID/prefab, owner/world/home/geometry/grade/group/TC auth+inventory checks, отсутствия чужого auth. Эта возможность **STATIC**, сам restart **LIVE UNKNOWN**.

## RustNav / дверь

- `RustNavigation.RebuildTilesInBounds(Bounds,bool)`, `RebuildTilesUnder(BaseEntity)`, `HasPendingTiles()` существуют. DecayEntity lifecycle сам запрашивает rebuild. Native BackgroundTileBuilder включает Construction layer и BuildingBlock collider geometry; dynamic home nav не признан невозможным по STATIC.
- Door.ServerInit регистрирует RustNavDoorGates; OnFlagsChanged(Open) меняет native colliders и gate flags. `Door.GetPlayerLockPermission(BasePlayer)` + `SetOpen(bool,bool)` — callable path при проверенном owner/auth/range. Roam canOpenDoors=false; не полагаться на автоматическое открытие NPC.
- Старые terrain-only Ground/NavSample нельзя применять внутри foundation. Нужны actual owned foundation collider floor sample, raw Complete/Partial/Invalid, physical portal crossing и TC LOS/range; ранний outdoor arrival<=1.05m не доказывает проход через дверь.
- Только RustNav SetDestination с native speed rearm из 006/009; размер агента, коллизии, координаты и decay не подменять. Native Unity-only links не выдавать за RustNav поддержку.

Public surface проверен отдельной C#7.3 library-компиляцией против installed DLL (`CompileHomeApi.cs/ps1`, compile-result.txt в raw). Исполнения методов, реального auth/строительства/nav/upkeep/restart пока не было. Установленные fingerprints и фактический outcome будут зафиксированы в RESULT; GREEN из этой страницы не следует.

## Installed fingerprints 010

Полный runtime/cache inventory проверен до live; compatibility key совпадает с 009. Owner файлы не обновлялись.

| Артефакт | SHA-256 |
|---|---|
| RustDedicated.exe | EFAC429DB737EB4B32A2BFC48029B4BE6FF475336958F4557F891F17255FFD38 |
| Assembly-CSharp.dll | 04FB89520F18A1920C1B1A350B82DD24A4258F31D97B82496971A9CC7A49DCB7 |
| Oxide.Rust.dll | 2128121E34B55BB1550D43E62842B87EA3720059F13DC84F97D8C7DD465C3423 |
| Rust.Data.dll | 1D62BAEF9B339F0416E6529618365C1ECAD01791A833E77E76EB6C8464406104 |

## После первого JOURNEY: site admission 0.2.1

Первый run дошёл до native gather/paid axe, но не нашёл site. Это **не engine defect**. Read-only decoder воспроизвёл 512 кандидатов из SHA-проверенной native .map, без исполнения DLL. Первые 48 XYZ совпали с телеметрией в пределах 0.000088м. Только20 проходят прежний искусственный перепад≤0.18м; все20 имеют запрещённую topology. Гипотеза о water-height fallback отвергнута: dry water-map обычно−500м, не равна terrain. Native paths не сломаны:21 из первых48 расчётов дали Complete path.

Новая authored admission policy: footprint range≤половины реальной глубины foundation bounds (2.8/2=1.4м), перепад floor→terrain у входа/подхода≤0.25м, native `Socket_Base.DoPlacement(Target)` + `CheckSocketMods(ref Placement)` до admission. Это консервативная политика агента, **не название/имитация native Rust rule** и не доказательство postbuild path. Native Planner, collisions/TC/monuments/roads/water/topology, actual support и физический HOME_NAV остаются обязательны. Прежние запреты не отключены.

Planning ray берётся из предполагаемого физического outside-подхода; rotation из native prediction повторно проверяется против реального footprint. Actual Planner использует настоящие eyes. Terrain/floor contact normal читается физическим raycast. Кандидаты сохраняют все причины отказа, а не только последнюю. Ни диагностические координаты карты, ни найденный offline индекс464 в runtime не вносятся.

STATIC map coverage новой политики:322/512 проходят depth range,25 также water/topology,3 также entry bound,1 — сохранённые monument/road proxies. Последние — только proxies; native placement/collision/permission/nav ещё должны подтвердиться live. Это обоснование второй проверки исправленного алгоритма, не разрешение третьего старта и не GREEN.

## Итог после двух процессов

**LIVE:** обе actual Oxide-компиляции, native ScientistNPC/PlayerInventory/RustNav, natural gather200wood+107stones и оплаченный accounted stonehatchet в каждом JOURNEY. Home recipes/grade budget реально загружены; во втором процессе340foundation `DoPlacement/CheckSocketMods` previews и344calculated Complete paths. Previews не создавали building entities; эти paths не являются пройденными SITE legs.

**LIVE BLOCKED_SITE:**0accepted sites в обоих bounded512-search; все проверки не прошёл ни один кандидат. Данные второго процесса содержат все reasons;478proximity отказов используют широкий DecayEntity guard, не означают478TC. Этот исход не доказывает map-wide или RustNav/API невозможность.

**STATIC / UNKNOWN:** настоящий Planner.DoBuild/paid Wood upgrade/structural registration, TC auth/upkeep, native door open/close, rebuilt home traversal и independent home RESTORE **не исполнялись в010**. Компиляция/IL/offline fixtures не повышают их до LIVE. Итог **BLOCKED_SITE**, не GREEN. Current source0.2.1 совпадает с последним live compiler snapshot; подробные receipts — RESULT/raw ignored.

## Site fix 0.2.2 перед разрешённой дополнительной парой

Владелец разрешил ещё два старта после offline fix/review. Новая версия пока **STATIC/OFFLINE_ONLY**; исторический compiler snapshot0.2.1 не является её live проверкой.

Installed IL и отдельная C#7.3 compilation подтвердили `new OBB(Vector3,Quaternion,Bounds)`, `BaseEntity.WorldSpaceBounds().Distance(OBB)`, `MonumentInfo.Distance(OBB)`, `GamePhysics.CheckOBB(OBB,int,QueryTriggerInteraction)`, `Rust.Layers.Mask.Prevent_Building`, `BaseEntity.GetBuildingPrivilege(OBB,bool,float,BuildingPrivlidge,bool)`, `BasePlayer.CanBuild(OBB,bool)` и `TerrainMeta.Position`. `MonumentInfo.CheckPlacement` относится к procedural monument generation и не используется как player placement gate.

Любой LootContainer наследует StorageContainer/DecayEntity; это не чужой дом. Structural guard использует уже существующее семейство BuildingBlock/BuildingPrivlidge/Door, независимо от OwnerID, и45м до native bounds. Отдельно сохраняются коллизии любых объектов и поиск standalone TC. Native privilege queried без кеша; любой чужой результат запрещает site, даже при формально разрешённой авторизации.

Сохранён прежний120м origin guard; дополнительно обязательны≥6м до native oriented monument bounds и отсутствие пересечения полного home OBB с Prevent_Building layer, включая triggers. Это консервативная authored политика поверх native checks, а не заявление о native универсальном120м правиле. Road guard измеряет расстояние до отрезков, а не только nodes. DoPlacement/CheckSocketMods остаётся preview; полный Construction.UpdatePlacement/native Planner при actual build по-прежнему обязателен.

Bounded search:512 локальных и4096 world-derived Halton centers, четыре направления подхода, максимум18432 попытки, до64/30мс за tick. Никакого seed-specific положения. Ray-derived native foundation rotation и outside согласуются повторным preview до четырёх итераций. Site revalidated до оплаты home craft. Подход требует actual complete RustNav path≤800м, travel bound ceil(length/3+30)≤300с; физический trace/общий deadline сохраняются.

Read-only native-map proxy coverage:8 local и34 world orientations проходят прежние numerical/topology/road/monument-origin proxies. Сохранённые monument roots неполны: это **не доказательство** native site availability. Native bounds, volumes, collision, preview, permissions и path ещё должны пройти live. Raw API/compile/coverage: ignored `site-fix-api/`.

Дополнительный STATIC upkeep audit: installed default `decay.tick=600с`, у всех home prefabs override0. `ServerInit` устанавливает lastDecayTick по текущему engine time; Load восстанавливает upkeepTimer без wall-clock catch-up. `GetProtectedMinutes(true)` не списывает Items. Обычное списание проходит через ServerBuildingManager.Cycle→DecayTick→OnDecay→PurchaseUpkeepTime; отдельный forcedecaytick в тестах не вызывается. Поэтому270с boot сами по себе не обосновывают допуск потери1wood. Exact TC inventory gate сохраняется; реальное списание между snapshot и native save либо startup≥600с может честно заблокировать restore. Raw: `api-build/upkeep-restore/`.

## После третьего JOURNEY: wear fix 0.2.3

**LIVE0.2.2:** native site принят на16184-й попытке: height range0.646м, entry0.243м, outside−0.057м; native monument bounds66.318м/origin131.518м, foreign bounds134.886м, road segment25.436м, PreventBuilding=false, uncached privilege=null и calculated Complete path152.000м. Это подтверждает admission одного участка, не физический SITE leg/home placement. Добыча axe3057wood из native sources исчерпала condition до полного бюджета3760wood; следующий hit списал остаток0.313634→0 без yield.0building entities.

Installed `ResourceDispenser.OnAttacked` IL списывает `BaseMelee.GetGatherInfoFromIndex(gatherType).conditionLost` **перед** GiveResources и возвращается при broken weapon до credit. Поэтому ожидание condition0 перед следующим действием запаздывает. v0.2.3 проверяет loaded wear+1 positive reserve до PREPARED; один раз выбирает тот же исходный rock, native Activate/rebind и повторный Discover/Approach под его меньший maxDistance. ProductUid/ToolUid и четыре held references сохраняются; repair/replacement/дополнительного credit нет. Receipt связывает exact actor, неизменённый inventory и первый последующий native rock gather. Final equipment по-прежнему обязан быть прежним paid product.

FirstHome-only global deadline1100с при явном runner timeout1200с; phases не сбрасывают deadline, legacy режимы900с. Первый admission сохраняет650с резерва на добычу/стройку; перед paid home craft —120с. Полный result сохраняется в том же private JSON; повторная console запись home result сокращена до summary. Native exit delay третьего процесса не объяснён этим изменением и не объявлен исправленным. Перед четвёртым процессом изменения имели статус OFFLINE_ONLY.

## Итог LIVE0.2.3 / ограничения

Четвёртый процесс реально compiled/loaded frozen source4A18E5357C4735CA03C5839E249B7871539F255D9EC4361AE4EFA9BA52001DA7.488native hits, bound paid-axe→original-rock switch, оба condition>0 и полный stock3763/3760wood подтверждены receipt/journal audit. Site admission прошёл; initial calculated Complete path153.463м. Физический SITE leg не выполнялся. Перед home craft geometry/native preview/permission/collision по-прежнему проходят, final calculated path statusComplete. Остаток времени≤110.49564с сам по себе нарушает reserve120+minimum30 travel; длина final path и его TravelSeconds не записаны, их отдельное прохождение UNKNOWN. Никаких home placement/TC/door/upkeep/HOME_NAV/independent RESTORE не было.

Дополнительный STATIC tax audit выявил обоснованный путь для будущего исправления material/time plan, без изменения текущего бюджета: `BuildingPrivlidge.CalculateBuildingTaxRate()` — public instance, не static(int). Private native tax formula читает актуальные public ConVar.Decay bracket fields; не следует брать только cctor-snapshot upkeepBrackets. Установленные defaults: six Wood blocks1040×0.1=104wood, wood door loaded recipe300×Upkeep1×0.1=30wood, TC без Upkeep attr→0; one-auth group multiplier1. Итого134wood/1440мин **только при этих проверенных defaults**, не actual TC receipt. Текущие mutable live bracket settings не записаны, поэтому уменьшение reserve1040 не применялось. Будущий prebuild план обязан проверить loaded settings/attrs и actual TC rate после native registration; fake TC/group не нужен и не разрешается.

Весь budget2+2использован. Итог PARTIAL/BLOCKED_BUDGET не доказывает невозможность Rust building API. Реальные DoBuild/upgrade/registration, TC authorization/upkeep, door collision/navigation и home restore остаются STATIC/UNKNOWN. Следующий live требует нового разрешения и offline/review исправления плана; conditional RESTORE без дома неприменим.
