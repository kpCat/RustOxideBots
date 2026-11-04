# TASK 012 — native TC placement / door / first-home proof

## Главная цель

Установить **точную причину** текущего `TC DoBuild = null`, исправить выбранный подход без обхода штатных игровых ограничений и доказать реальную установку `BuildingPrivlidge`, полномочия бота, перенос оплаченного wood в шкаф на upkeep, установку настоящей двери и физическое перемещение NPC через дверной проём и обратно. Всё это сначала на отдельной fixture-paid диагностической копии мира.

Если diagnostic home полностью пройден, разрешается один натуральный `JOURNEY` за реально добытые ресурсы и один independent `RESTORE` при условии наличия подтверждённого сохранённого дома. Если smoke не пройден, **никакого натурального JOURNEY**, независимо от оставшихся запусков.

## 1. До live: native/IL и проверка первой причины отказа

1. Обязательно прочитать `API_GATE.md` и изучить локально установленную DLL Rust/Oxide (read-only metadata/IL и asset/prefab, не доверять старым API docs). Разобрать ТОЧНЫЙ порядок и возврат `Planner.DoBuild(Construction.Target,Construction)` для deployable TC: `Construction.Target`, ray origin/direction, hit entity, socket=null, `onTerrain`, rotation, `shouldParent`, deployment volumes, LOS, reach, privilege, `CanBuild`, collision, `CreateConstruction`, server item consumption. Не считать неуспешную выдачу entity доказательством отказа Rust в NPC.
2. Выяснить все пути возврата `null`: `Construction.lastPlacementErrorDebug`, `Phrase`/статус/ошибка `GetPlacement`, дополнительный internal validation; какие доступны через установленный public API без patch/Harmony, какие требуют отдельной допустимой диагностической проверки. Не подделывать error phrase.
3. Сравнить TC-target с реальной установкой cupboard обычным игроком. Особое внимание: на каком основании и к какой поверхности должен привязываться `cupboard.tool`, как взаимодействуют target.parent = foundation без socket, его bounds/DeployVolume, пол/стены/крыша, capsuled actor, физическая позиция игрока перед открытым проёмом. Ничего из этого не менять наугад, сначала IL и наличие измеримых причин.
4. Подготовить **неразрушающую диагностическую телеметрию** для точного TC placement: `PlayerInventory/active held Planner/GetDeployable`, actual target fields, native surface hit + collider type/id/layer, ray distance/LOS, actor capsule, proposed TC OBB/overlap, foundation/world position/rotation, nearby structures/TC, exact `CanBuild`/hook permissions, native socket/placement result и реальные error/phrase fields. Если нет API для явного Phrase, писать `NOT_EXPOSED`, а не выдумывать.
5. Для floor foundation vs terrain, roof-present vs roof-absent и стен на пути можно создать **несколько не мутирующих previews в одном smoke**. Запрещено многократно вызывать оплаченный `DoBuild` или выдавать второй `cupboard.tool` для подбора счастливой позиции. Выбрать один корректный native target, затем ОДНА оплаченная попытка. При отказе не восстанавливать «использованный intent» без строгого доказательства и не запускать второй native call на том же мире.

## 2. Diagnostic BUILD_SMOKE — первичная проверка

- Тот же изолированный `-FirstHomeSmoke`, один `ScientistNPC : BasePlayer`, реальная нативная экипировка инструментов и `Planner`; физический RustNav. Fixture resources строго маркированы `TEST_FIXTURE`, но все расходы проверяются по real loaded blueprints/Construction/grade costs; нет бесплатного `Spawn` готовых building entities.
- Построить foundation, walls/doorway, roof (или безопасно изменить **порядок** TC/roof/walls, только по изученным placement requirements), затем **реальный cupboard.tool** с native `Planner.DoBuild`, зарегистрированный как `BuildingPrivlidge`, правильно привязанный к одному buildingID, own `OwnerID`/saveList/structural group и native privilege.
- Привязать TC auth к engine-assigned bot ID, проверить `IsAuthed`, `CanBuild` и native privilege; запрет чужих IDs/Steam spoof. Перевести реальные предметы из native `PlayerInventory` в TC `ItemContainer`, доказать item UID/amount ledger и native `GetProtectedMinutes(true)` >=60 минут без отключения decay.
- Поставить реальную деревянную дверь в native doorway, открыть/закрыть через native API, проверить colliders/door state и физический RustNav маршрут outside→inside→TC→outside (без teleport, warp, manual position writes, ghost collision/disable). При динамическом NAV blocker статус PARTIAL_SMOKE с конкретной ошибкой, не фиктивный путь.
- Smoke всегда только **DIAGNOSTIC_BUILD_ONLY**, даже если весь дом собран: натуральная экономика и реальный HOME_RESTORE им не подтверждаются. Diagnostic world/cache не может стать источником натуральной игры или быть promoted. Все чужие объекты не меняются.

## 3. Conditional NATURAL JOURNEY + RESTORE

Запускать ТОЛЬКО после диагностического smoke с подтверждёнными native TC, Door, Upkeep, HOME_NAV и независимого review.

- `JOURNEY`: в новом изолированном чистом test world, один NPC динамически выбирает site. Native natural gather, source debit/journal/condition, все расходы на loaded home recipes/grades/TC/upkeep; реальная постройка уже проверенным native путём. Никаких fixture materials. Сохранять exact home/actor/item/world proofs и grace quit.
- Следить за реальным time budget: previous full gather989.5s; current home2100s/runner2400s. Если возможно, сократить только **консервативный upkeep reserve** на основании фактически измеренного native tax (например, оплаченная защита >=60мин), не менять цену строительства, добычу, decay или реальные ставки. При неизменном бюджете дополнительно оценить расход wear/время. Нельзя выдавать сокращённый план за проверенный, пока actual TC подтверждение отсутствует.
- `RESTORE`: только после valid native home checkpoint, независимый RustDedicated, прежние building net IDs/disk witnesses/TC inventory/wood upkeep/door, original Item UIDs/active held, логический ActorId, безопасная повторная auth при новом native bot ID, физический HOME_NAV и ноль повторного harvest/craft/build/upkeep credit. Отказ при смене WorldKey/wipe/owner/захвате TC.
- Ни один smoke result, даже успешный, не является source для NATURAL RESTORE. `009` crash-atomic остаётся NOT_PROVEN.

## 4. Завершение и ограничения

До **трёх** реально запущенных RustDedicated в 012: 1 smoke, 1 conditional natural journey, 1 conditional restore. Исключительная замена непройденного smoke повторным smoke допустима только после явно установленного и исправленного дефекта; она расходует один из трёх запусков и НЕ разрешает натуральную часть, пока полный smoke не пройден. Новый дополнительный бюджет не запрашивать; без условия сдавать PARTIAL.

Изменять минимально home plugin/module и focused validators/tests; safety runner только если доказан конкретный дефект. Публиковать честный `RESULT.md`: точный TC root cause если установлен, либо UNKNOWN с аргументами; source SHA, native entities/payments; `SMOKE_GREEN`, `GREEN_HOME_BOOTSTRAP` только если NATURAL+RESTORE доказаны, иначе PARTIAL/BLOCKED.

Отдельно проверять `Test-All`, live Oxide compilation/load, owner SHA, 0 residual PID/ports/firewall/leases/locks, UTF-8/mojibake, Unicode-escaped Cyrillic, secrets. `Server/` и `.local/` остаются ignored/untracked. Commit exact paths + ordinary fast-forward push origin/master без force/reset/rebase/clean/stash/broad add. В новом чате Codex — самостоятельное исполнение без ручного участия владельца.
