# RESULT017 — PARTIAL_TRAVERSAL / NOT_PROMOTED

Дата: 05.11.2026. **GREEN_TRAVERSAL_CORE не достигнут.** Реализован проверяемый кандидат общего collision-aware local controller, но физическая приёмка не пройдена. Все **3 из3** разрешённых RustDedicated starts использованы. Четвёртый запуск и018 не начинались.

Блокер: длительность будущего native physics шага нельзя подменять предыдущим wall-clock интервалом наблюдения. В BENCH3 это дало actual acceleration4.029982m/s² при разрешённых4.001 с численным запасом. Контроллер остановился; validator отверг witness. Ни один неподтверждённый проход не объявлен PHYSICAL PASS.

## Решение владельца и baseline

Владелец ответил: «C — собственный local controller (рекомендовано)». Согласован тот же ScientistNPC/BasePlayer, RustNav как planner, исходные capsule/Rigidbody, bounded проверенное применение движений без teleport/Warp/resize/collision disabling. Ответ записан в DECISION.md.

Перед правками local HEAD, origin/master и actual public GitHub master совпали: b2a1131536297d3e3fb476cd7992fcbad91c72d1, ветка master/upstream origin/master. Первоначально untracked только12 supplied файлов017. SSH ls-remote не прошёл sandbox network; публичный SHA подтверждён GitHub-коннектором branches/master. Read-first и найденные аналоги описаны в PLAN.md.

## Что поставляется

- src/navigation/ObstacleTraversal.cs: общий local solver и реальные probes, original-body binding, раздельные route/support/obstacle/decision/actual witness, bounded step/slope/drop, static-floor acquisition, полный swept volume, penetration veto, nav epoch invalidation и ограниченный replan.
- src/navigation/TraversalBench.cs: caller integration и изолированный диагностический bench, actual component inventory, native door/portal witnesses.
- src/plugins/RustBotsAvatarSurvival.cs и src/home/FirstHome.cs: shared API для outdoor и home при явном включении кандидата; прежние native маршруты сохранены по умолчанию.
- scripts/Invoke-NavigationProbe.ps1: явный -TraversalBench, несовместимость с restore/другими selectors, прежняя физическая изоляция/Job Object/firewall/cleanup.
- scripts/TraversalValidation.ps1 и scripts/Test-Traversal.ps1: независимые focused contracts и negative fixtures.
- scripts/Test-PluginCompile.ps1 и scripts/Test-All.ps1: точная combined-source C#7.3 сборка и включение focused tests.

Публичный exact scope: **25 файлов** —9 перечисленных runtime/test и16 task documents:12 supplied + PLAN/API_DECISION/DECISION/RESULT. Это bounded exception одного traversal artifact family. Исходные12 файлов постановки не переписывались.

**Кандидат не продвинут в обычный runtime.** После провала physical gate EnsureTraversal разрешён только явному isolated TraversalBench. Обычные Avatar/FirstHome используют прежний native SetDestination/rearm/path/physics-guard путь. Это предотвращает регресс из-за непроверенного mover. Эти post-live gating изменения подтверждены OFFLINE_ONLY compile/tests/review, отдельного live после них нет.

Сам reusable module остаётся независимым от homeEntities, prefab/netId одного дома, seed и абсолютных координат. BENCH endpoints/геометрия выбираются из текущей карты. Solver не меняет actor class, scale, capsule, layers, gravity/kinematic или collision settings. Native inventory/held и существующая экономика сохранены; TEST_FIXTURE не считается natural progress.

## Реальные запуски

Времена начала ниже — UTC из native runner report. Во всех трёх есть installed Oxide compilation/load и server/RustNav readiness. Все test copies физически отдельные, diagnostic-only, без cache promotion.

| Run | Начало UTC / readiness | Native результат | Runner результат / actuation |
|---|---|---|---|
| BENCH1 f51951d33dbb4085a1424efe9e916f69 |04:50:23 /265.3144s|PARTIAL: pending tiles до расчёта маршрута|FAILED: validator zero-motion false-negative;0|
| BENCH2 ee5e7e94bcf04ed98427597a077678cc |05:05:37 /265.7892s|PARTIAL: initial support gap выше ordinary limit|PARTIAL;0|
| BENCH3 8375a9e65b0c47faa163748cfc2ecbd1 |05:37:31 /266.4606s|PARTIAL: actual continuity rejected|FAILED: OBSERVED_UNSAFE;1|

Frozen combined SHA по порядку:

    CAC1AF880D69F74828F48206248538F154F6973F269D2FE4A5252024EC93E59B
    8FFEE409E5FCBCADA84B3F681BC5D0A0020E4C2AB9DF17939762A2EA564793FC
    91B570977F7F980E482C9845BC480930D6DCE0621847C77AE75138ABA54F8FBA

Каждый SHA совпал с фактическим frozen plugin и проверенным combined source соответствующей версии. Исторические001–016 не использовались как новые movement proofs.

### BENCH1: readiness и честный zero-motion отказ

IsDefaultNavmeshBuilt уже был true, HasPendingTiles ещё true. Plan сохранил NOT_CALCULATED/corners0 и правильно отказал. Установленный IL подтвердил разные проверки built-count и pending queue. Readiness до Begin теперь требует обе предпосылки в прежнем600s budget; motor guard не ослаблен.

Runner первоначально отверг полный actual inventory12, потому что validator требовал MOTION_WITNESS даже при0 actuation. Narrow RED→GREEN допускает привязку исходного body к stationary BLOCKED только для incomplete/non-GREEN/zero-actuation/no-PASSED/no-issued cases. Повторная проверка неизменённого raw прошла как honest PARTIAL. Frozen runner FAILED не переписан.

### BENCH2: фактическая начальная поддержка

RouteComplete, pending=false, epochs совпали; исходное тело и overlaps0. Native sphere contact дал Gap0.0983219147m против ordinary SupportTolerance0.07m, MaxDrop0.5m. Exact origin этого gap — point-ray spawn либо native OnEnable/rebind — не установлен: исходный spawn ray не сохранён.

Увеличения допуска не было. Добавлен отдельный initial FLOOR_ACQUISITION для исходно неподвижного тела над одной известной статической опорой в пределах прежнего MaxDrop: только vertical descent, fresh same-floor geometry, full pre/actual-after sweeps/overlaps, native permission/water, measured supported rest до горизонтального движения. Он не действует после ordinary support loss и не даёт STEP_RESOLVED/scene height credit.

Actual CanBuild failure в BENCH2 не измерялся из-за прежнего short circuit. Native API audit не дал оснований менять vehicle/entity/TC authorization policy. В последующих receipts permission/water записаны независимо.

### BENCH3: actuator исполнился, временная модель не прошла

Исходный actor ScientistNPC/BasePlayer, capsule radius0.5/height1.8/center0.9/unit scale, Rigidbody kinematic=true/gravity=false/detectCollisions=true, layer17. Эти параметры не менялись.

После stationary observation issued command1 запросил vertical descent. Фактически Y5.44947529→5.43388653, XZ неизменны: **0.01558876m**. Запрос Y5.433886 достигнут с ошибкой около0.5µm. Current/landing/actual overlaps и swept hits отсутствуют; native floor/permission/water прошли соответствующие проверки. Native Rigidbody velocity.y−0.249420166 согласуется с порядком измеренной скорости−0.250644028.

Планирование использовало предыдущий dt0.08828735s: planned speed0.176573843m/s и acceleration1.99999022m/s². Следующий actual интервал составил0.0621948242s: speed0.250644028m/s и acceleration4.029982m/s². Поэтому unchanged4m/s² limit был нарушен, сработал STOP/OBSERVED_UNSAFE. Это **command-horizon mismatch**, а не доказанный position divergence или clipping.

PHYSICAL_CONTACT здесь имя общего error receipt, не доказательство столкновения. Floor gap остался0.082733m; FLOOR_ACQUIRED, rest, ordinary movement и STEP_RESOLVED не достигнуты. Этот микро-спуск не считается step/down PASS.

## Матрица приёмки

| Capability | Фактический итог |
|---|---|
| Installed API/IL, same actor/body |Подтверждены signatures/IL и actual original body в новых live|
| Общий reusable candidate |Реализован и подключён к обоим caller в явном bench; не promoted|
| Actual MovePosition |Одно native применение наблюдалось; control/witness gate FAILED|
| Безопасный outdoor ascent |NOT_PROVEN|
| Независимый slope/down traversal |NOT_PROVEN; acquisition не засчитывается|
| Native paid building threshold/in-out |NOT_TESTED: сцена не достигнута|
| Solid wall / closed door / detour |NOT_TESTED: сцены не достигнуты|
| Полная поддержка/step resolution |NOT_PROVEN|
|100NPC/performance/custom worlds |NOT_VERIFIED|
| Natural3760wood/home journey/RESTORE |Вне017, не запускались|
| Исторические013 outbound /016 evolution |UNKNOWN, не переименованы|
|009 CRASH_ATOMIC |NOT_PROVEN, без изменений|

В BENCH3 всего7 receipts и1 unsafe witness,0 ordinary distance. Максимум5 явно посчитанных queries/tick на этом коротком фрагменте; это не steady-state performance. Native privilege internals и allocations отдельно не измерялись. Pose-derived speed/acceleration — интервальные оценки; peak physics continuity/100-agent load не доказаны.

## Проверки и независимое review

Финальный powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-All.ps1 после opt-in gating завершился **exit0**. Лог: .local/audit/traversal017/test-all-final.txt. Все прежние contracts, acquisition/geometry/identity/world/negative/portal/economy fixtures и точная combined C#7.3 compile прошли. Единственное сохранённое warning CS0618 относится к legacy Rigidbody.velocity; API cleanup вне scope не выполнялся.

Pre-live Test-All выполнялся перед каждым PID. Один промежуточный run попал в ожидаемый RED missing-prelanding при добавлении regression; окончательные runs PASS. Synthetic fixtures остаются OFFLINE_ONLY и не заменяют PhysX.

Fresh independent reviewer проверил source/API, каждый frozen raw/server.log, все исправления и final nonpromotion branches. Найденные landing/undefined native outs/world/economy/inventory/observation gaps закрыты focused regressions. **Timing defect остаётся blocker для promotion**, а не скрытым minor. Открытых P1 для поставки отключённого кандидата и честного PARTIAL reviewer не оставил.

## Owner, cleanup, privacy и encoding

Полный owner inventory3086 files проверен SHA-256/length; изменений0 после запусков. Protected1507 файлов вне exact5 разрешённых existing source edits неизменны: история001–016, old audit/raw/cache witnesses сохранены. Начальный protected inventory1512 включает эти5 intentionally edited source paths; это различие не скрывается.

Каждый run: GRACEFUL quit/ACK, наблюдаемый native exit−1, OwnedProcessAbsent/PortsReleased/FirewallRemoved=true, Promoted=false. Финальный Windows audit: Rust/Steam/helpers/TCP/UDP/rules/live brokers/open leases/busy locks0; все35 historical+new leases закрыты. Закрытые marker/lock files как raw остаются локально; занятых locks нет.

SteamCMD/updater/owner BAT не запускались. Owner Server/maps/config/plugins не менялись; чужие процессы не останавливались. Source runtime и raw/secrets не публикуются из Server/.local/artifacts. Публичны только exact25 text files.

- mojibake-маркеры в изменённых файлах проверены;
- escaped Cyrillic в изменённых файлах проверены.

Exact-path audit также проверяет strict UTF-8/NUL, owner-value/credential/Steam-ID/non-loopback-IP patterns и все3 actual test RCON passwords. Raw только ignored .local/runtime/<run-id>/ и .local/audit/traversal017/. Audit manifests/hashes, test logs, source/raw reviews и safety reports сохранены там.

## Git: прямое разрешение и exact commands

Git разрешён пользователем и TASK017 раздел5 для baseline/scope, exact staging/commit и ordinary origin/master push. Ни force, branch, merge, rebase, reset, stash, clean или broad add не выполняются.

Выполненная bounded inspection:

    git status --short --branch --untracked-files=all
    git rev-parse HEAD
    git branch --show-current
    git rev-parse --abbrev-ref --symbolic-full-name '@{u}'
    git remote get-url origin
    git ls-remote origin refs/heads/master
    git rev-parse HEAD refs/remotes/origin/master
    git ls-files -- Server/ .local/ artifacts/
    git check-ignore Server/rustds/RustDedicated.exe .local/audit/traversal017/Audit-Owner.ps1
    git ls-files -- docs src scripts AGENTS.md README.md .gitignore
    git diff --check
    git diff --stat -- src/plugins/RustBotsAvatarSurvival.cs src/home/FirstHome.cs scripts/Invoke-NavigationProbe.ps1 scripts/Test-PluginCompile.ps1 scripts/Test-All.ps1
    git diff --cached --name-only
    git diff --name-only

Поставка после freeze/review использует exact25 paths из PLAN/allowlist; чужой index/иной путь останавливает staging:

    git status --short --untracked-files=all
    git diff --cached --name-only
    git add -n -- $paths017
    git add -- $paths017
    git diff --cached --check
    git diff --cached --name-only
    git diff --cached --stat
    git diff --cached --no-ext-diff -- $paths017
    git commit -m "feat: add gated traversal candidate and task 017 evidence"
    git push origin master
    git rev-parse HEAD refs/remotes/origin/master
    git status --short --branch --untracked-files=all
    git ls-files -- Server/ .local/ artifacts/

Actual command exits, final commit/tracking/public SHA и clean-tree verification фиксируются после commit в ignored delivery ledger и финальном ответе; self-SHA в самом документе не выдумывается. Публикация PARTIAL не означает физическую promotion.

## Что остаётся обязательным для GREEN

Нужен явный physics-step/time-horizon contract: fixedTime/fixedDeltaTime/tick index вместе с wall timestamps, применение на известном будущем integration step и независимые фактические witnesses, без подгонки acceleration epsilon. Затем нужен новый отдельно разрешённый live budget для outdoor ascent/down, genuine native building step/in-out и solid/door negative в разных контекстах. В017 больше PID не создаётся. До этих доказательств physical gate остаётся REQUIRED; universal product objective не объявлен завершённым.
