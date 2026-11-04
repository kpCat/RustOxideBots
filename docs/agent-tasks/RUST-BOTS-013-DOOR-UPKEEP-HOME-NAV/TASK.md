# TASK 013 — доказать дверь, upkeep и физическое перемещение внутри построенного дома

## 0. Непосредственная цель и граница

Текущий результат 012: 6 wood-grade structural BuildingBlock + реальный BuildingPrivlidge в одной native group, TC собственно авторизован; ни двери, ни upkeep, ни HOME_NAV. В последнем диагностическом smoke `HomeBuildStand` на step7 не смог найти физическую позицию перед door placement (`NavSample` false). Нужно понять именно этот отказ, исправить его без имитации и завершить диагностический дом с native door + TC protection + real RustNav crossing.

**Не делать заново крупный фарм, пока технический smoke не завершён.** Следует переиспользовать установленный API и уже написанные код/валидаторы. Не заменять RustNav на телепортацию/Unity fallback, не уменьшать размер NPC, не выключать столкновения, не раздавать ресурсы бесплатно за пределами помеченного диагностического smoke. Не использовать hardcoded absolute XYZ/seed/предыдущие net IDs. 424242/2000 лишь тестовый runner.

## 1. Статическое исследование до дорогих запусков

1. Прочитать AGENTS + HANDOFF и исходники. Определить точный вызов после TC: `HomeBuildStep`/`BUILD_WAIT` → `HomeBuildStand` → `NavSample` → `Ground`. Проверить, какой stand (offset относительно foundation/doorway) выбирается и где реально стоит actor в конце TC placement.
2. Проверить в установленной версии Rust/Oxide API и IL: `RustNavigation.DefaultNavmesh.SamplePosition`, `RustNavMeshAgent.SamplePosition`/`CalculatePath`, `HasPendingTiles`, `RebuildTilesInBounds`/`RebuildTilesUnder`, нативная obstacle/door gate; `Physics.RaycastAll`, `TerrainMeta.HeightMap`, own `BuildingBlock` collider, prefab foundation/door/TC; native `Planner.DoBuild` door socket, TC tax/upkeep и защита двери. Не использовать неподтверждённые интернет-сигнатуры.
3. Инструментировать **раздельные** этапы: native nav sampled? точная navPoint XYZ? ray hit collider/owner/layer/normal/height? отклонение от terrain/foundation? water? capsule overlaps с prefab/owner? pending tiles? current actor world coords, distance до actual door/TC/eyes, actual complete path? какие native permission/LOS/placement checks? Запись только runtime-telemetry без секретов.
4. Зафиксировать заранее, какое правило запрещает какую ошибку. `NavSample=false` нельзя переводить в придуманную категорию collision или claimed engine defect без наблюдения. Тесты должны отвергать отсутствие subreason, ложный PathComplete и fake-door receipt.

## 2. Исправление подхода у построенного 1x1

- До TC и после TC позиции должны выбираться по **геометрии собственной построенной doorway/foundation**, а не жёсткому single offset `-3m` и предположению, что поверхность всегда является terrain. Использовать фактический doorway transform/native socket, позицию/ориентацию foundation, ограниченный набор физических точек/радиусов/ориентаций. Для каждой — grounded surface (terrain вне здания или реальный own foundation внутри), актуальный navmesh, complete path от реального положения NPC, LOS, `maxplaceDistance`, разрешения native `CanBuild` и отсутствие чужих коллизий. Отсеивать TC/door blockage и свой collider NPC корректно; не игнорировать чужие сущности.
- Если NPC **уже физически стоит в зоне допустимого размещения** с нужным LOS/range, разрешено не начинать ненужный переход только после фактического доказательства current actor position/surface/capsule/permission. Это не телепортация и не обход native `Planner` — DoBuild должен исполнить все собственные проверки.
- Если сетка перестраивается, ждать ограниченное время `HasPendingTiles`/readiness и log before/after, а не считать `NAV_SAMPLE` постоянным до завершения rebuild. No infinite loop. RustNav/физика должны подтверждаться live; никакой подмены `transform.position`, `MovePosition`, `Warp`, отключения коллайдеров, игнорирования range/LOS или искусственного доступного `pathStatus`.
- Distinguish `NAV_SAMPLE`, `GROUND_TERRAIN`, `OWN_FOUNDATION_FLOOR`, `SLOPE`, `WATER`, `CAPSULE_FOREIGN`, `CAPSULE_OWN_STRUCTURE`, `PATH_PARTIAL`, `PENDING_TILES_TIMEOUT`, `DOOR_LOS/RANGE`, `TIME_BUDGET`. Классы отказа могут иметь численные причины.

## 3. Diagnostic BUILD_SMOKE — критическая приёмка

Один новый **полностью отдельный** физический `-FirstHomeSmoke` из чистой проверенной копии мира, raw evidence и world namespace run-specific. Прежний 012 snapshot с частичной базой **не источник** нового smoke. Разрешены только явно помеченные `TEST_FIXTURE` materials и настоящий starter rock; весь расчёт цен берётся из actual installed recipe/native cost, в smoke расходы списываются из native PlayerInventory.

В одном NPC и одном run:
1. Динамически выбрать safe site; real `Planner.DoBuild`, native Wood upgrades 6 blocks и native TC через proven path 012. Проверить same buildingID/group/support/ownership/saveList, один own engine bot ID, authorised list чужих0, `TC.IsAuthed` и `TC.CanBuild`.
2. Пройти корень step7: native door placement на doorway с **реальной оплатой item door**, correct socket/support, owner/building ID, live native `Door` entity, do not Spawn shortcut. Fail closed с сохранением native `Phrase/debug` при настоящем `DoBuild==null`.
3. Перенести реальные Item UID из PlayerInventory в TC Inventory, замерить native `CalculateUpkeepCostAmounts`, `CalculateUpkeepPeriodMinutes`, `GetProtectedMinutes(true)` до/после, decay enabled. Требовать **>=60 минут** реальной оплаченной protection и отсутствие бесплатного credit.
4. Дверь открывается и закрывается через нативное API с настоящими collider/state и разрешениями. Физический маршрут `OUTSIDE → DOOR → INSIDE_TC → OUTSIDE` одним `ScientistNPC : BasePlayer` через RustNav; непрерывные positions/timestamps, native sample/path/repath/door aperture/supported floor, TC interaction range. Только при этом `DIAGNOSTIC_HOME_GREEN` или `BUILD_SMOKE_GREEN`; общий статус run всё ещё PARTIAL/DIAGNOSTIC_BUILD_ONLY, не GREEN_HOME_BOOTSTRAP.
5. При blocker после TC, door placement или upkeep сохранить first failing stage/complete receipts, остановиться с PARTIAL. Не повторять оплаченный `DoBuild` в том же частичном мире и не двигать/kill чужую сущность ради PASS.

## 4. Последующий NATURAL и RESTORE — только при полностью зелёном smoke и бюджете

Если **первый** smoke полностью подтвердил все части (включая native door и crossing) и есть независимое code review, допускаются два остальных live запуска в этом же TASK (общий максимум 3):

- NATURAL JOURNEY: новый isolated clean world/test actor, без fixture и без re-use smoke world. Собрать реальный budget в open world по 009, wear accounting, оплаченный stonehatchet/`Planner`/hammer/door/TC, site chosen before expensive farm, phase-bounded time based on measured ~990s of previous farming (не менять цену/cheat), real native home full build, paid upkeep, HOME_NAV, correct world/actor/economy/home state and clean completed native save. Нельзя выдавать smoke ledger за natural.
- HOME RESTORE: только из completed NATURAL JOURNEY, другой RustDedicated, exact WorldKey/map/wipe/.sav/generation, original building entity witnesses, owner/TC rebind только для собственной логической identity с no foreign auth, native same Item UIDs/slots/condition, unchanged TC inventory/upkeep, HOME_NAV after dynamic rebuild, no replay/build/free credit.

Если понадобился **второй** smoke для проверки одного уже доказанного дефекта, не запускать одиночный natural JOURNEY без слота на independent RESTORE только ради красивого результата: завершить diagnostic gate, подвести честный итог, а natural+restore перенести отдельной задачей. Любое GREEN_HOME_BOOTSTRAP требует реальный NATURAL + независимый RESTORE; диагностический зелёный smoke = отдельная полезная победа, но не полная цель.

## 5. Safety, limits, git, evidence

- До первого live: installed C#7.3 compile, all `Test-All`, focused RED→GREEN validator counterexamples and source review. Не запускать live с неустановленным API; limited budget 3 (smoke + optional NATURAL + RESTORE, или smoke+targeted smoke fix). Бесконечные перезапуски запрещены.
- Windows PowerShell 5.1, scoped guard `AGENTS.md`: owner `Server/` read-only; no Rust/Oxide/SteamCMD/update/owner BAT. Unique physical fork, never hardlink/junction to writable owner, own firewall lease/broker, owned-job process, auto stop, cleanup PID/TCP/UDP/rules/locks, owner SHA read-only before/after.
- Preserve older 001–012 source/results/historical PARTIAL/immutable raw. No artificial SteamID for NPC. C# changes минимальные `FirstHome.cs`, perhaps precise extraction/instrumentation `RustBotsAvatarSurvival.cs`, focused tests and runner only if technically needed; no unrelated refactor/framework.
- Actual commit and ordinary **fast-forward** `git push origin master` authorised for exact verified paths. Before write compare local HEAD/remote/public. Exact-path staging only; no broad `git add`, no force/reset/rebase/clean/stash; no `Server/`, `.local/`, `artifacts/`, secrets tracked. Verify remote equality and clean tree.
- Result matrices per phase: STATIC, OFFLINE_ONLY, LIVE_DIAGNOSTIC, LIVE_NATURAL, LIVE_RESTORE, NOT_PROVEN. Include source SHA, versions, actual run IDs, failure receipts, exact raw ignored paths, previous source fingerprints, reasons, empty partial updates, owner audit, two separate encoding scans: mojibake and escaped Cyrillic.
