# PLAN017 — универсальный traversal, согласован вариант C

> Implementation: текущая сессия, focused contracts до live и независимое source/raw review. Подготовка плана через writing-plans; связанные implementation tasks допускают subagent-driven-development. Пользователь требует самостоятельного исполнения после выбора архитектуры, повторный procedural approval не нужен.

**Goal:** общий физически проверяемый local mover для исходного ScientistNPC, outdoor и FirstHome.

**Architecture:** выбран владельцем C: RustNav планирует от actual pose; один local controller проверяет полный объём, опору, step/drop и observed outcome. Исходная capsule/Rigidbody и economy сохраняются.

**Tech stack:** installed Rust/Oxide/Unity, C#7.3, PS5.1, без NuGet.

**Spec:** TASK.md, ARCHITECTURE.md, PHYSICS_CONTRACT.md, DECISION.md текущей017.

## Execution ledger

- Продолжение05.11.2026: владелец разрешил physics-clock fix и до2 дополнительных isolated starts после offline checks/review. Общий предел5; первые3 остаются учтены. Текущий опубликованный master `e3b303b62ce3c4b6a8ead25997fa44948f4e0e4c`. Перед новым start: явный future physics horizon, отдельный wall clock, focused regression, installed compile/Test-All и независимое review. Старые unsafe receipts не переклассифицировать.

- [x] Read-first/native audit, Test-All baseline, независимое source/raw/API review.
- [x] Владелец согласовал C в ответе 05.11.2026.
- [x] Task1: shared ObstacleTraversal + controller safety receipts; installed C#7.3 compile; focused offline negative contracts.
- [x] Task2: outdoor/FirstHome callers и test-only bench; combined source runner; independent pre-live review, pre-live Test-All exit0.
- [x] Task3: выполнены первоначальные3 и явно разрешённые дополнительные2 isolated starts, всего5/5. Actual результаты в RESULT. Это выполнение bounded test work, не physical gate PASS; шестого PID нет.
- Task4: final Test-All/installed compile/review/SHA/safety пройдены; exact privacy/encoding/scope и commit/push выполняются последними, факт поставки фиксируется в delivery ledger и финальном ответе.

Review focus: same shallow wall/step penetration; own foundation side; initial overlap and after-pose sweep; two writers/nav drift; unsupported drop и delayed physics actuation. Ни один contact-only receipt не даёт STEP_RESOLVED.

Ruling: работаем в явно указанном master checkout; новые branch/worktree не создаются. Public task allowlist и final ordinary master push разрешены пользователем. Ledger/raw в .local/audit/traversal017; shell workflow helpers, создающие commits/branches вне task, не используются.

Дата: 05.11.2026. C согласован владельцем; общий кандидат реализован, physical gate не пройден. План фиксирует сделанную работу и оставшуюся приёмку; универсальное движение не объявлено завершённым.

## Read-first и baseline

Прочитаны корневые AGENTS.md/README.md, все 12 файлов постановки017, RESULT/API_DECISION014–016, runtime `src/plugins/RustBotsAvatarSurvival.cs`, `src/home/FirstHome.cs`, связанный outdoor pattern `RustBotsWorldRoam.cs`, runner/compile/Test-All и safety helpers. Исторические документы и raw дополнительно проверены независимым рецензентом. AGENTS выше корня, csproj/props/targets, code-map/pattern-файлы и отдельный каталог tests не найдены; повторный поиск не требуется. Тесты находятся в scripts.

Local HEAD, origin/master и публичный GitHub master: `b2a1131536297d3e3fb476cd7992fcbad91c72d1`; текущая ветка master, upstream origin/master. Начальное рабочее дерево содержит только 12 untracked файлов постановки017. SSH ls-remote недоступен из sandbox; actual public SHA прочитан GitHub-коннектором через branches/master.

Перед изменениями сохранены SHA-256/length owner3086 и protected1512 файлов. Protected включает tracked source/docs/scripts, исторические home audit/raw и сохранённые cache worlds. Это не полный SHA всех runtime installations; owner Server проверяется полностью. Raw017: ignored `.local/audit/traversal017/`.

## Переиспользование и ограничения

- `HomePhysicalSample`/`HomeNativeCapsule`/`HomeSweepHit`: реальные capsule endpoints, native identities, sweeps и penetration. Домовые role/netId/floor исключения не переносить в общий core.
- Outdoor `StartLeg` и `HomeMove`: existing RustNav CalculatePath, bounded progress/repath. Complete route и физическая проходимость остаются разными результатами.
- `HomeOpenDoor`: own TC/auth/lock/range/LOS/native state. Door policy остаётся отдельной от геометрии.
- `Test-PluginCompile.ps1` и runner AppendAllText: существующий combined Oxide source, C#7.3, без новых NuGet; orchestration PS5.1.
- `ProbeSafety`, firewall lease, физический isolated runtime и OwnedServerProcess Job Object переиспользуются. Их безопасность не ослабляется.
- Никаких owner Server изменений, SteamCMD/update/BAT, переписывания001–016, economy/craft/restore redesign, collider/scale/layer/physics cheats. Никакого нового global pathfinder.

## Архитектурный gate: выбор владельца получен

G0 baseline исследован. G1 native audit доступен в API_DECISION.md и проверен независимо. Владелец выбрал C явным ответом05.11.2026, записанным в DECISION.md. Архитектурный ответ получен; это не physical acceptance и не автоматическое PASSED product gate. Требования full-body proof и последующего независимого review сохраняются.

Выбран вариант C из DECISION.md — RustNav только планирует маршрут от actual pose; отдельный collision-aware local controller использует исходную капсулу/actor.

## Согласованный дизайн C

`ActualActor + WorldIdentity -> RustNav route -> LocalProbe -> TraversalDecision -> CheckedLocalMotion -> IndependentWitness -> Repath/Blocked`.

1. Один writer движения. Остановить существующее автоматическое исполнение пути до передачи управления; исключить competing BaseAIBrain/FSM/navigator/queued transform writes. Одного updatePosition=false недостаточно. RustNav CalculatePath(start,destination,path) вызывать от фактической позиции. Не пытаться присвоить read-only nextPositionWS или управлять RustNav через velocity setter.
2. Shared module в src/navigation не знает homeEntities, seed, test coordinates, prefab/netId конкретного порога. Строгая проверка ScientistNPC/BasePlayer identity, оригинальной world capsule/scale, map/wipe, времени, скорости, конечности чисел, готовности navmesh. UNKNOWN запрещает advance.
3. Раздельные route, support, obstacle, decision, applied motion и observed outcome. Ступень определяется геометрией опоры/высоты/полного объёма, а не малой глубиной penetration. Кандидат подъёма не считается CLEAR. Проверять подъём, forward clearance/headroom, landing и отдельный допустимый спуск; wall/foreign side/closed hinge/gap не превращаются в опору.
4. Собственный local step/slide/support solver должен проверять полный swept volume до каждого ограниченного физического продвижения и затем actual pose/contact/support. Установленный Rigidbody.MovePosition — только кандидат actuator: он сам не гарантирует collision resolution. Не применять transform/Warp/baseOffset для обхода коллизий. Если безопасный actuator/continuous crossing не доказан, результат BLOCKED_ENGINE/PARTIAL, без придуманного PASS.
5. Пределы step/slope/drop задаются проверенным capability profile исходного тела. maxStepUpDistance другого native navigation mode и navmesh climb metadata не считать автоматически способностью этого тела. Пока профиль не доказан — UNKNOWN/отказ. Числа016 не использовать как clearance tolerance.
6. До одного local detour/repath на эпизод; при неизменном obstacle/stuck исчерпать bounded budget и остановиться. Physics queries локальные; idle не выполняет active sensor. Изменение door/building/nav tiles инвалидирует результаты; на первом варианте не кешировать surface evidence между движущимися тиками.
7. Witness записывает фактические timestamps/pose/body/sweeps/penetration/support/door/path/casts/query time/retries; validator восстанавливает результат из измерений. Внутренние flags и calculated trajectory сами по себе не дают STEP_RESOLVED. Perf для50–100 остаётся UNKNOWN до отдельного stress E2E.

## Scope guard

До решения владельца были добавлены только четыре документа. После явного выбора C разрешена реализация в exact scope ниже. Исходные12 файлов постановки остаются побайтно неизменными. Private audit scripts/logs только `.local/audit/traversal017/`.

Bounded exception:16 task documents (12 supplied +4 reports) и не более9 связанных runtime/test файлов одного traversal artifact family. Exact runtime allowlist:

```text
src/navigation/ObstacleTraversal.cs
src/navigation/TraversalBench.cs
src/plugins/RustBotsAvatarSurvival.cs
src/home/FirstHome.cs
scripts/Invoke-NavigationProbe.ps1
scripts/Test-PluginCompile.ps1
scripts/TraversalValidation.ps1
scripts/Test-Traversal.ps1
scripts/Test-All.ps1
```

TraversalBench — отдельная test-only partial integration; construction/economy используются существующие, не копируются в solver. Если понадобится другой файл, пересмотреть scope до правки. ProbeCache/ProbeFirewall/ProbeSafety/OwnedServerProcess, EconomyJournal и owner Server вне product allowlist. Выбор C получен; будущие physics доказательства всё ещё обязательны.

## Порядок после решения владельца

1. Записать ответ в DECISION/RESULT и актуализировать точный design/allowlist. Затем implementation plan с focused RED→GREEN contract groups: obstacle geometry; bounded state/repeated collisions; identity/world/native-failure/continuity negatives. Никаких фиктивных native fixtures.
2. Реализовать shared core и оба caller: outdoor resource approach и FirstHome. Все изменения C#7.3, existing economy/actor сохранены. Installed compile + Test-All + independent source review до game PID.
3. BENCH1 в одной физической test copy: discovered outdoor height/slope; paid TEST_FIXTURE native foundation/doorway/door/TC; genuine wall/closed-door negative. Сохранить full actual runtime component inventory и непрерывные before/during/after witnesses. Не фармить3760wood и не выполнять HOME_RESTORE.
4. BENCH2 только для другого класса либо конкретного установленного дефекта; BENCH3 только с обоснованием и review. Первоначальные3 starts использованы. По последующему явному разрешению владельца допускаются BENCH4–5 после physics-clock fix/offline/review, общий максимум5. На unsafe outcome немедленный STOP, не следующая сцена ради GREEN.
5. Финальный независимый source/raw review, Test-All/compile, owner/protected SHA, safety cleanup, UTF-8/NUL, отдельные mojibake и escaped Cyrillic, secret exact-path audit. Exact-path staging/commit и обычный git push origin master; public SHA/clean tree. До закрытия архитектурного gate не начинать эту поставку.

## Пока не проверено

Shared core, callers, bench и focused validators созданы в exact scope. Declared custom limits ограничены installed BuildParams/body, не выдаются за native capability. BENCH3 нарушил acceleration limit. Новый clock в BENCH4/5 подтвердил соответственно5 и2 accepted acquisition witnesses, native velocity matches и delta0.0625; оба остановлены по wall gap выше0.1. Acquisition не завершён. Up/down/building/outdoor/negative physical proof остаётся NOT_PROVEN. BENCH5 warmup прошёл, затем home-first paid craft/first travel; placements0. Исторический013 outbound collider и after-contact resolution016 остаются UNKNOWN. GREEN_TRAVERSAL_CORE не заявляется.

## Final nonpromotion и следующий технический шаг

После failed physical gate кандидат активируется только явным isolated -TraversalBench. Обычные outdoor/FirstHome маршруты сохраняют прежние native SetDestination/rearm/path/physical guards. Это post-live OFFLINE_ONLY integration guard; core SHA и frozen live evidence не переписаны. Universal product objective остаётся незавершённым, физический gate REQUIRED.

Timing defect BENCH3 исправлен явным physics-step contract: driver без wall throttle снимает каждый FixedUpdate с sequence, double fixed/unscaled/wall times, actual future delta, mode и timeScale. Core/validator требуют exact next step, native velocity и независимый wall gap/deadline. Unknown/skip/change останавливают движение; stale-velocity replan запрещён до actuation. Single JSON reconstruction исправлена без расширения velocity limits. BENCH4/5 actual timing прошёл на коротких fragments, но wall gaps0.1031844/0.125893 остановили приёмку. Bench5 stationary warmup2s/20s и home-first sequencing этого не устранили. Лимиты не увеличены; neutral terminal after-geometry не принимает late command. Бюджет5/5 исчерпан. Следующий технический вопрос — доказуемая политика scheduler lateness и безопасного hold/recovery в выбранном C; реализация/новые live не объявлены разрешёнными.018 не начинается.
