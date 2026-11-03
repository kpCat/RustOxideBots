# API feasibility 003 — установленная сборка

Metadata/IL прочитаны существующим scripts/Inspect-RustApi.cs, без загрузки игровых DLL. Команда: `dotnet run --file scripts/Inspect-RustApi.cs -p:PublishAot=false -p:NuGetAudit=false -- <installed.dll> <type-regex> <method-regex>`. Первоначальный запуск без двух свойств попытался обратиться к NuGet и не собрал inspector; повтор использовал уже установленный SDK без AOT/audit. Библиотеки игры не скачивались и не обновлялись. Raw вывод: ignored `.local/api-world*.txt`, `.local/api-persistence.txt`, `.local/api-data-all.txt`.

## Дороги и физическая навигация

`TerrainMeta.Path` → `TerrainPath.Roads : List<PathList>` → `PathList.Path : PathInterpolator` → `Points : Vector3[]`. Это реальная геометрия текущей procedural map, а не координаты из 001. Ближайшая точка вычисляется проекцией на каждый segment; receipt содержит индекс дороги/segment, оба конца, проекцию и расстояние. Дорога — цель, не граница spawn.

Повторяется proven 001: Halton-поиск по 90% карты, terrain/ground ray, slope/water/capsule, complete departure path. После spawn нет изменения transform/warp. `RustNavMeshAgent.CalculatePath(Vector3,RustNavMeshPath)`; `RustNavMeshPath.corners : List<NavVector3>`, `.status`, `.GetPathLength()` подтверждены. Дальняя цель выбирается в 280–450 м, полный path <=650 м, затем локальные complete-path сегменты 36/24/12 м. Ограничены число сегментов, время и один repath при stuck. Samples записывают actual position/time, runner независимо восстанавливает путь. Unity backend не выдаётся за RustNav.

## Native loot и урон

`LootContainer : StorageContainer : DecayEntity : BaseCombatEntity`. `StorageContainer.inventory : ItemContainer`, `LootContainer.initialLootSpawn`, `lootDefinition`, `LootSpawnSlots`, `SpawnLoot/PopulateLoot` существуют. IL `LootContainer.ServerInit` вызывает native `SpawnLoot` при initialLootSpawn и отсутствии restore. Probe не создаёт ресурсов и не вызывает повторную генерацию лута; fallback fixture проходит CreateEntity → Spawn → native ServerInit один раз.

Concrete prefab выбирается только из установленного `GameManifest.Current.entities`, затем проверяется `FindPrefab(...).GetComponent<LootContainer>()`. Фильтры имён — кандидаты для discovery, не утверждение о concrete type. Приоритет natural наполненным обычным ящикам/бочкам в радиусе 100 м, с проверенным подходом. При отсутствии доступных экземпляров разрешён один native fixture данного класса; provenance явно NATURAL/FIXTURE_NATIVE_PREFAB. Фактические имена/типы записываются только live и приводятся в RESULT.

Первый live discovery выбрал `modding/lootables/invisible/.../invisible_crate_normal_2.prefab`. Его лут был native, но такой невидимый fixture не подтверждает обычный видимый ящик. Финальный фильтр исключает `/modding/` и `invisible`; повторный live проверяет обычный prefab, без изменения первого evidence.

`HitInfo(BaseEntity,BaseEntity,Rust.DamageType,float,Vector3)` и `LootContainer.OnAttacked(HitInfo)` подтверждены. `BaseCombatEntity.OnAttacked` проходит native damage pipeline; `LootContainer.OnDied` → `StorageContainer.OnDied` → `DropItems`. Адаптер наносит 20 Blunt от собственного NPC с интервалом >=1 s, только при distance <=2.8 м и clear ray. Здоровье до/после и источник пишутся на каждый hit. Это серверный proximity damage adapter, анимация/экипированный melee-инструмент не реализованы. `Kill()` используется только для cleanup и не является damage proof.

`DroppedItem : WorldItem`, `WorldItem.item : Item`. После lethal hit рассматриваются только новые native DroppedItem с UID из barrel-before. Прямого вызова DropItems/GenerateScrap нет. IL DropBonusItems требует BasePlayer для player modifier bonuses — Gen2 эти бонусы не получает. Отсутствие native drops означает PARTIAL; добавлять scrap для прохождения запрещено.

## Инвентарь и сохранение

`ScientistNPC2 : BaseNPC2 : BaseCombatEntity`, не BasePlayer. Штатные PlayerInventory, Steam connection, player RPC/loot UI к нему не применимы. NPCPlayer/BasePlayer потребовал бы смены actor/navigation contract; это повышает риск и не входит в минимальный 003.

Выбран native owned `ItemContainer`: `ServerInitialize(null,48)`, `GiveUID()`, `entityOwner=npc`. `Item.uid.Value`, `.amount`, `.info.shortname`; `Item.MoveToContainer(ItemContainer,int,bool,...)` сохраняет реальный объект. Stacking отключён, один UID переносится целиком; source-minus/dest-plus и окончательный inventory проверяются независимо. Range/LOS/OwnerID/locked проверяются до действия; Gen2 не имитирует player permissions или Steam ID. Инвентарь не виден как player equipment и не реализует crafting/respawn.

`ItemContainer.Save(bool,bool) : ProtoBuf.ItemContainer`, `Load(ProtoBuf.ItemContainer)`; Rust.Data.dll содержит `ProtoStreamExtensions.ToProtoBytes(IProto)` и `ProtoBuf.ItemContainer.Deserialize(byte[])`. Native protobuf сохраняется в isolated oxide/data и копируется runner в ignored per-run evidence. Restore-only второй сервер принимает только hash-verified snapshot завершённого isolated запуска совместимого cache key, expected UID/shortname/amount. Восстановление через native Load — единственный путь materialization saved items; выдачи новых ресурсов нет. До live restart это feasibility, не доказанная persistence.

После review добавлена строгая привязка snapshot к generation и SHA-256 точного .sav; одного compatibility key недостаточно. `-ResumeJourney` сначала подтверждает native restore, затем повторяет путь и loot, сохраняя initial UID/amount отдельно от новых переносов. Ошибка native barrel drop понижает BARREL до PARTIAL, но не мешает сохранить уже доказанные crate items. В access checks дополнительно учитывается `WorldItem.allowPickup`.

Фактический второй live подтвердил native restore 6 UID / 12 единиц, обычный `assets/bundled/prefabs/radtown/crate_normal_2.prefab` и естественный `assets/bundled/prefabs/autospawn/resource/loot/loot-barrel-2.prefab`; concrete runtime type обоих — LootContainer. Измерения и ограничения приведены в RESULT.md.

## Границы достоверности

Offline compile C# 7.3 подтверждает сигнатуры, но не live Oxide load/behavior. Публичных project/props/targets, дополнительных AGENTS.md/code-map/pattern-файлов не найдено. Аналоги: RustBotsNavigationProbe, Invoke-NavigationProbe/ProbeSafety и focused PS tests. Установки/кеш/ownership/isolation остаются под существующими safety helpers; owner Server полностью read-only. Конкретная карта/road/loot/сохранение подтверждаются только E2E в RESULT.
