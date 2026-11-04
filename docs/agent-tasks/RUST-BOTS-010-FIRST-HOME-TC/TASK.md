# TASK 010 — Первый настоящий дом, TC и перемещение через дверь

## Цель и честный масштаб

Перестать ограничиваться бегом/добычей/крафтом: построить **один функциональный мини-дом** одним реальным `ScientistNPC : BasePlayer` в полностью изолированном RustDedicated. Дом должен быть частью настоящего мира Rust (native building/decay/privilege/door), а не декоративным набором GameObject или маркеров. Критически важны оплаченные ресурсы, адекватные строительные правила, стабильная привязка к миру и проверка навигации.

Никаких постоянных координат, размеров конкретной тестовой карты, заданных заранее entity IDs, выдачи материалов из воздуха, телепортаций, `MovePosition` или создания чужого Steam ID. `424242/2000` — только тестовые параметры раннера, не логика бота.

## 1. API и исполнитель до первого live (G0/G1)

1. Прочесть AGENTS, 006–009 `RESULT/API_DECISION`, `LIFE_ROADMAP.md` из 003, исходники `RustBotsAvatarSurvival`, `EconomyJournal`, `Invoke-NavigationProbe`, cache, validation; реальный установленный DLL/IL. Версии/методы нельзя выдумывать из wiki или памяти.
2. Исследовать native `Planner`, `Construction`, `BuildingBlock`, `BuildingManager`, `BuildingPrivlidge`, `DecayEntity`, `Door`, `StorageContainer`, `ItemBlueprint`, `BasePlayer.CanBuild`, building permission, building grades, costs, socket/support, IO/network spawn, world save/load, `RustNavMeshAgent` и obstacle updates. Проверить реальные prefab names и цены установленной версии. Сформировать `API_DECISION.md` с точными классами, сигнатурами и статусами `STATIC`, `LIVE`, `UNKNOWN`.
3. Выбрать компактную схему дома: **1 квадратный фундамент, 3 сплошные стены, 1 дверной проём, крыша/перекрытие, деревянная дверь, 1 TC** (плюс обязательные native вспомогательные компоненты, если нужны). Допустим простой деревянный стартовый дом. Полные конструкционные требования (support/grade/buildingID/decay/privilege) должны быть настоящими, а не произвольными spawn-моделями. Разметка по относительным смещениям/ориентации от выбранной площадки; не absolute X/Z.
4. Приоритет настоящего player placement API. Если без клиентского RPC штатная сборка невозможна, разрешён явно маркированный `SERVER_ACCOUNTED_BUILD` **только с проверенной native structural registration и физической оплатой**. Не выдавать серверное создание за настоящий input обычного игрока. Если ни один безопасный путь недоступен — PARTIAL/BLOCKED; не spawn некорректную постройку ради PASS.

## 2. Поиск площадки, план и материалы

1. Один NPC живёт как логическая личность из системы 007–009; native avatar/held/PlayerInventory/RustNav сохраняются. Для теста допустима новая логическая личность, но НЕ второй фиктивный актёр-строитель.
2. Автоматически находить кандидаты площадок в **текущем мире** (terrain, slope, water, topology, соседние building blocks, монументы/дороги, привилегии чужих TC, коллизии, clearances, support). Выбирать безопасный доступный site с bounded поиском и причинами отказов, а не заданные координаты. Проверить возможность дойти RustNav до места постройки.
3. Добыть все необходимые материалы из NATURAL источников по механизмам 009, по реально загруженным расходам на строительство/крафт/TC/дверь/начальный upkeep. Если нужна кирка/топор/план постройки/молоток — получить через оплаченный рецепт или документированный стандартный стартовый item. Каждая расходная операция ведёт ledger native Item UID/amount, список полученных строительных сущностей, world binding и запрет повторного credit. Нет бесплатного prefab inventory/стартового полного мешка материалов для GREEN.
4. До первого placement выполнить план и подсчитать весь бюджет — не начинать необратимое строительство без ресурса на минимальный TC/upkeep. Материал/уровень должны существовать в установленном Rust; при частичных затратах не повторять операцию автоматически.

## 3. Строительство / TC / содержание

1. Физически достигнуть site и последовательно поставить основу, стены/проём, крышу, дверь и TC в валидных native положениях; правильные building groups, Grade, sockets, ground/terrain support, parent/building privileges. Обязательно фиксировать concrete entity net IDs, prefab/type, world coordinates, structural connections, owner/building ID, health/decay.
2. `TC` — настоящий `BuildingPrivlidge`, с рабочим container и native building privilege. Проверить, принимает ли нативный engine-assigned NPC bot ID авторизацию; НИКАКОЙ подмены SteamID настоящего человека. Если после рестарта новый engine bot ID требует rebind — только после полной проверки логического владельца/world/home ownership и того, что TC никем не захвачен. При неизвестном API отказ, не фальшивый TC.
3. Реальный native upkeep: средства физически переведены из NPC PlayerInventory в TC inventory, источник уменьшился, TC содержимое выросло ровно настолько, срок/затраты upkeep проверены через установленный API. Нельзя выставить decay time напрямую или отключить decay для GREEN. Сохранять информацию о запасах/сроке до и после, без обязательного ожидания 24 ч.
4. Дверь должна быть настоящей `Door`, корректно крепиться к doorway, менять open/closed через native/server API с проверкой ownership/access. Не создавать неуязвимый magic pass-through. Замок/кодовый замок/гаражки — следующий этап, если их безопасная реализация не нужна для прохождения первой двери.

## 4. Физический HOME_NAV

- Проход **снаружи → через реальный дверной проём → в точку взаимодействия с TC → наружу** одним NPC через RustNav без изменения координат вручную. При открытии дверь должна действительно менять native состояние/коллизию и позволять проход; затем закрываться.
- Подготовить минимальный local room/portal graph (`OUTSIDE`, `DOOR`, `INSIDE_TC`) поверх динамических координат **собственного** дома; при закрытой/заблокированной двери bounded open/repath/timeout. Не сканировать карту на каждом tick.
- Проверить raw navmesh/path `Complete/Invalid/Partial`, samples, дистанции, arrival/LOS/range, door state, collision. Если установленный RustNav не поддерживает динамическое строение без rebuild, не компенсировать телепортом; сообщить точный blocker, оставить корректную постройку как PARTIAL.

## 5. Независимый RESTORE

- Отдельный RustDedicated после штатного quit и native world save: точный world/wipe, save generation и hash proof, та же логическая личность и прежние Item UID; сохранённые building entities/TC/door обнаружены через допустимые native disk witnesses/geometry/owner checks, **не создаются заново**.
- Тот же дом, одна TC, одна дверь, те же building elements и реальный upkeep в пределах engine decay/time; никакого повторного harvest/craft/build/kit/credit, никаких дополнительных TC. Проверить, что посторонние строения и природа не изменены системой. Повторный поиск/rehydration `HOME_NAV` по фактическим entity positions, не по hardcoded coordinates.
- При другом WorldKey/вайпе/missing TC/new occupant/разрушении не воссоздавать собственность слепо и не переносить старый home. Удаление/рейд и восстановление после потери TC — отдельные будущие игровые сценарии.

## 6. Ограничения и процесс

- Тестовый режим вынести отдельно (`-FirstHome`/`-StarterHome` — выбрать одно имя) в существующий безопасный runner; остальные 001–009 должны работать. Разрешены небольшой новый плагин или компактное развитие существующего при реальном reuse, не 3000 строк копипасты. C#7.3 / PowerShell5.1.
- Target **2 настоящих live старта**: build JOURNEY и independent RESTORE. Третий — только если документирован конкретный engine defect, с полным сохранением PARTIAL evidence; если не безопасно, остановка. Offline/IL gates и независимые validators ДО каждого старта. Не запускать update/SteamCMD/owner `Run_DS.bat`.
- Owned private physical install, checked cache and world, firewall deny all test EXE, process-owned Job Object, graceful ACK/save, bounded finally cleanup, 0 owned process/ports/rules/leases/locks. На чужом Rust/Steam процессе не запускать и не убивать его.
- `Server/` полностью read-only/ignored (включая 6+ GiB, карты, файлы пользователя, конфиги, установленные плагины). Raw logs/hashes/secrets — только ignored `.local/`. Обычный `git push origin master`, exact-path staging, без force/reset/rebase/clean/stash/broad add. Проверки mojibake и escaped Cyrillic раздельно.
- Список затронутых отслеживаемых файлов заранее зафиксировать в PLAN; если нужен небольшой прямой фикс 009, отдельное обоснование; старые RESULT не переписывать. Сделать Test-All, точный `RESULT.md`, `API_DECISION.md`, отчёт о приватности и завершении.

## НЕ входит в 010

Гаражки, лестницы на несколько этажей, сортировка сундуков, спалки/смерть/respawn, ремонт после рейда, кланы, боевой NPC, умный PvP, нефтянки/карго, Giant Excavator, Semantic Pack и 50–100 NPC. Они сохраняются в `LIFE_ROADMAP.md`. CRASH_ATOMIC/аварийный recover source/item/craft из009 всё ещё NOT_PROVEN и не становится GREEN от штатного home-restart; до production-population необходим отдельный controlled-crash proof.
