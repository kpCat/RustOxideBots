# TASK 011 — завершить первый дом, не прожигая live-запуски на повторном фарме

## Что должно получиться

Один `ScientistNPC : BasePlayer` в изолированном RustDedicated выбирает подходящую площадку ТЕКУЩЕЙ карты, натурально добывает и оплачивает материалы, строит **native** деревянный дом 1×1 (foundation, 3 стены, doorway, roof/floor, деревянная дверь, 1 TC), авторизуется в TC, оплачивает реальное содержание, проходит снаружи внутрь к TC и обратно без телепортации. Другой RustDedicated после штатного завершения восстанавливает **тот же дом**, `Item UID`, логическую личность/ownership и оплаченные ресурсы без повторного строительства/выдачи.

Отличие от 010: первым дорогим действием НЕ ДОЛЖНА быть повторная добыча 3760 дерева. Сначала доказать строительный API, затем реальная экономика.

## A. API/offline до любого игрового PID

1. Прочитать AGENTS и аналоги 009–010. Осмотреть конкретные строки `FirstHome.cs`, `HomeCheckSite`, `HomeBuildStep`, `HomePlace`, `HomeAuthorizeAndUpkeep`; installed DLL/IL и native prefabs. Не полагаться на abstract docs как live proof. Проверить методы `Planner.DoBuild`, `Construction.Target`, grade upgrade, support, BuildingManager, BuildingPrivlidge/TC authorisation/upkeep, Door state/RustNav gates, save/load; native protection of owner bot ID.
2. Отделить `SITE_GEOMETRY`, `NAV_PATH`, `TRAVEL_BUDGET`, `MATERIAL_BUDGET`, `TOOL_WEAR`, `BUILD_PLACEMENT`, `HOME_NAV`, `RESTORE` как независимые причины. Никакого «site changed», если только время исчерпано. Сохранять подробные early/late receipts, actual route length, travel estimate, remaining, reserve и полученный admission decision.
3. Реально разобрать материал/упкеп budget из установленного API. В 010 общий budget **3760wood**, часть — консервативное резервирование 1 суток по полной стоимости wood-grade; выяснить, можно ли рассчитать реальную часовую потребность без нарушения native API. Не занижать grade, отключать decay или выдумывать upkeep. Для мини-дома acceptance требует native paid protection **не менее 60 минут** по реальному `GetProtectedMinutes`; лучше сутки, если цена достоверна и бюджет позволяет. Любое изменение тарифа/периода явно обосновать в PLAN/RESULT. Не уменьшать нормальную стоимость foundation/walls/roof/TC/door ради искусственного PASS.
4. Учесть измерение 4-го запуска: 989.5с только на полный сбор бюджета + site travel минимум~81с + последовательные native placements, wait на navmesh/door/upkeep/home-nav. Профиль FIRST_HOME: bounded deadline по измеренному worst-case с буфером (ориентир 1800–2100 игровых секунд и корректный runner navigation timeout >= него; окончательное значение обосновать расчетом). Увеличивать ТОЛЬКО ограничение тестового режима FirstHome, не всех legacy режимов; никаких бесконечных while/бессрочного ждать. Самопроверки двух независимых таймаутов runner/plugin обязательны.
5. Проверить здоровье источников и износ по native профилю до последнего hit. Никакого бесплатного пополнения/ремонта, никаких farm retries при неоднозначной оплате. Учитывать реальные stage/health, остаток инструмента, доступные NATURAL nodes и ограниченную стратегию смены на owned rock/новый оплаченный топор.
6. Отсутствие домов в 010 запрещает использовать его `result.json` как оплаченный home checkpoint. Не переносить 3763wood из текстового отчёта в новую игровую сессию.

## B. Первый live: краткий BUILD_SMOKE с явно диагностическими материалами

Цель: **рано физически пройти неиспытанные native building API**, не расходуя 15 минут на 3760 wood. Допустим отдельный test-only сценарий, например `-FirstHomeSmoke`, в собственном isolated world copy. В этом режиме разрешена заранее выданная строго посчитанная `TEST_FIXTURE_WOOD` для строительного исследования, но:

- все выдачи маркируются `TEST_FIXTURE`, UID/amount фиксируются, `Planner/upgrade/craft/TC/upkeep` списывают реальные Item из **тестового** `PlayerInventory`; никакого безусловного `Spawn` готового дома и неподтверждённых структур;
- **SMOKE никогда не даёт `GREEN_HOME_BOOTSTRAP`** и не засчитывается за NATURAL gathering или economy persistence; в итоговом отчёте отдельный `DIAGNOSTIC_BUILD_ONLY`;
- тестовый мир SMOKE не должен загрязнить или продвинуть shared trusted warm cache/world, используемый обычными JOURNEY. Обязательно отдельный физический snapshot, namespace/explicit no-promotion, жёсткий guard в runner и regression offline proof. Никаких hardlinks/junction для writable данных;
- один native `ScientistNPC`, такой же player-derived inventory/held and RustNav, динамический выбор site; native structure, building registration/grade/TC, настоящая дверь/коллизии; если получилось — проверить физический переход outside→inside→outside;
- при отказе записать первый фактический native API error/code/target/socket/owner/position, а не запускать бесполезный 3760-wood JOURNEY. Не принуждать к полноте A–C для фиксированного GREEN, если native API действительно blocked.

**Принцип:** тестовая выдача допустима ТОЛЬКО для технического smoke в изолированной копии. Она строго запрещена для полноценно оплаченной игры и для итогового общего GREEN. Отдельный smoke не должен затронуть owner Server/ и trusted cache.

## C. Второй live: полноценный NATURAL home JOURNEY

После успешного smoke и review провести один живой полноценный сценарий:

- динамически найти подходящую площадку **до** дорогостоящей добычи, записать clearance/WorldKey, сохранить её в состоянии текущего этапа; не hardcode site/seed/maps; после сбора ещё раз проверить реальный site + native route с отдельно достаточным **временем**, не принимать `TRAVEL_BUDGET` за геометрическую ошибку;
- один BasePlayer-derived NPC, native rock/paid hatchet и NATURAL ресурсы; реальный Item/ResourceDispenser debit, durable journal, строгий source incarnation; реальные рецепты и нерастраченные ресурсы;
- оплаченные `building.planner`, `hammer`, wood door и `cupboard.tool`, затем native foundation/walls/doorway/roof, wood upgrades, TC, authorised bot-ID и native upkeep с `GetProtectedMinutes`, door open/closed, физическое прохождение home portal внутрь и обратно; никакой телепортации или отключения коллизий;
- сведения про net IDs, exact Entity types/buildingID/native links/health/stability/grade/permissions/worldSave и ledger о реальных списаниях; нужно увидеть **реальные placement calls >0**, а не только 340 previews;
- если новый engine gate откажет после уже оплаченной операции, fail closed, сохранить PARTIAL и не создавать второй дом автоматически; чужие структуры не удалять.

## D. Третий live: independent HOME RESTORE

Разрешён только если (C) создал **завершённый** native дом, штатно сохранил world, economy+home+actor+inventory snapshots и clean shutdown. Иначе не делать холостой RESTORE.

- `WorldKey / MapKey / WipeId` стабильные для той же карты; exact previous `.sav`, generation, journal, actor+inventory+home snapshots, source witness; нельзя использовать snapshot smoke либо из старого 010;
- native onDisk home entities **те же**, а не создание нового набора: foundation, 3 walls, doorway, roof, TC, door, grade/buildingID/links/upkeep/owner. При новом temporary bot ID — только доказанная защищённая reauthorization своего TC, отказ при owner чужой/снесённом TC;
- original actor logical ID, Item UID/amount/condition/slots, original paid tool/product, no extra starter, wood credit, craft, building or TC, no duplicate journal intent; physical home-nav through door after loaded geometry. No arbitrary rebind/foreign mutation;
- повторное применение economy/source/TC state даёт доказанный NOOP на уже применённом, wrong world or wipe — fail closed.

## E. Бюджет, защита, поставка

- После offline gates **до 3 реальных запусков всего на 011**: 1 smoke, 1 NATURAL full journey, 1 conditional independent restore. Если smoke не подтверждает native placement, реальную добычу пока не запускать. Дополнительных игровых запусков без отдельного явного разрешения не делать. Не назначать произвольный «5-й запуск 010».
- Тестовый runner запускает/останавливает сервер без ручных действий владельца; отдельный physical install, verified inbound/outbound firewall, own-process Job Object, timeout и finally; в конце 0 own Rust/SteamCMD/processes/ports/rules/leases/locks. Никогда не убивать чужой RustDedicated.
- `Server/` и owner Rust/Oxide/world/mods/BAT/data всегда read-only/ignored. Без updater 002, SteamCMD, network relaxation, Steam impersonation. Проверить 3086 owner files (или обновлённый фактический baseline) побайтово до/после.
- Важные 001–009 источники сохранять; не ретконить PARTIAL 010. Изменения только в минимальных firsthome+runner+validation/test+новые docs; не строить новую огромную framework.
- Git по явному разрешению этой задачи: inspect current HEAD/public master, exact-path `git add -- <paths>`, diff check/allowlist, commit+обычный push `origin master` без force/reset/rebase/stash/clean/broad add. `Server/` и `.local/` не публиковать.
- Проверить `Test-All`, installed DLL compile, отдельные mojibake markers и escaped Cyrillic, secret scan, независимое ревью исходников и фактических raw E2E. Итог `RESULT.md` с `GREEN_HOME_BOOTSTRAP` только при полной C+D; smoke-only/partial/blocked должно быть честно разделено.
