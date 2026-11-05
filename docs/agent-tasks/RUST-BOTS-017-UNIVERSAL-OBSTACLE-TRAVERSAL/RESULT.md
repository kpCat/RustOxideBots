# RESULT017 — PARTIAL_TRAVERSAL / NOT_PROMOTED

Дата: 05.11.2026. **GREEN_TRAVERSAL_CORE не достигнут, universal product objective не выполнен.** Первоначальные3 starts и явно разрешённые владельцем дополнительные2 использованы, всего5/5. Ответ владельца: «Разрешаю исправление и ещё до 2 starts». Шестой PID и018 не запускались. Реализован и проверен timing fix, кандидат остаётся bench-only.

BENCH3 command-horizon defect исправлен явным fixed clock; BENCH4/5 подтвердили короткие acquisition fragments. Текущий blocker: оба новых runs остановились по независимому wall gap0.1031844/0.125893s при guard0.1s. Поддержка/rest и требуемые outdoor/building/negative сцены не завершены. Ни один неподтверждённый проход не объявлен PHYSICAL PASS.

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

**Кандидат не продвинут в обычный runtime.** EnsureTraversal разрешён только явному isolated TraversalBench. Обычные Avatar/FirstHome используют прежний native SetDestination/rearm/path/physics-guard путь. Это предотвращает регресс из-за непроверенного mover. Gating подтверждён compile/tests/review; BENCH4/5 проверяли только явный isolated candidate.

Сам reusable module остаётся независимым от homeEntities, prefab/netId одного дома, seed и абсолютных координат. BENCH endpoints/геометрия выбираются из текущей карты. Solver не меняет actor class, scale, capsule, layers, gravity/kinematic или collision settings. Native inventory/held и существующая экономика сохранены; TEST_FIXTURE не считается natural progress.

## Реальные запуски

Времена начала ниже — UTC из native runner report. Во всех пяти есть installed Oxide compilation/load и server/RustNav readiness. Все test copies физически отдельные, diagnostic-only, без cache promotion.

| Run | Начало UTC / readiness | Native результат | Runner результат / actuation |
|---|---|---|---|
| BENCH1 f51951d33dbb4085a1424efe9e916f69 |04:50:23 /265.3144s|PARTIAL: pending tiles до расчёта маршрута|FAILED: validator zero-motion false-negative;0|
| BENCH2 ee5e7e94bcf04ed98427597a077678cc |05:05:37 /265.7892s|PARTIAL: initial support gap выше ordinary limit|PARTIAL;0|
| BENCH3 8375a9e65b0c47faa163748cfc2ecbd1 |05:37:31 /266.4606s|PARTIAL: actual continuity rejected|FAILED: OBSERVED_UNSAFE;1|
| BENCH4 a9cebf7a5cba42a288b56490077e6ed6 |06:31:08 /267.0331s|PARTIAL: wall gap0.1031844s выше0.1s|FAILED: validator float reconstruction;6, из них5 observed|
| BENCH5 c8f6bf1232e44f0e932dbfe0d62f0d17 |06:55:15 /265.6167s|PARTIAL: WALL_GAP0.125893s|FAILED: wall guard;3, из них2 accepted и1 terminal-only|

Frozen combined SHA по порядку:

    CAC1AF880D69F74828F48206248538F154F6973F269D2FE4A5252024EC93E59B
    8FFEE409E5FCBCADA84B3F681BC5D0A0020E4C2AB9DF17939762A2EA564793FC
    91B570977F7F980E482C9845BC480930D6DCE0621847C77AE75138ABA54F8FBA
    4A02201C2F2C8802ECB82FD7CC93D9F7C4222A1A921A594A0AFB54D2824AF3A2
    6D7CDC7CC8B8FAB3FF04D5D204FFD3B8CFFF43DE04D20CA4ED01EBEE227E6257

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

### BENCH4: physics horizon подтверждён, независимый wall guard остановил

Schema2 снимает double fixed/unscaled/wall clocks, current delta, sequence, native mode/timeScale. Actual FixedUpdate mode/timeScale1/delta0.0625 и следующие consecutive steps наблюдались. Пять accepted acquisition witnesses дали0.07192898m vertical descent, максимальные sampled speed0.359924316m/s и acceleration2m/s²; native velocity error0 во всех пяти. Это подтверждает новый timing на этих командах, но не завершённую acquisition или traversal.

Перед witness команды6 sequence/fixed increments оставались корректны, но wall gap0.1031844s превысил неизменный0.1s guard. Сработал UNOBSERVED STOP до after-geometry; причина общего clock receipt не означала фактический physics skip. В новой версии wall причины отделены. При валидном physics clock добавлена только read-only terminal diagnostic; она не принимает команду, не даёт height credit и не разрешает продолжение.

Runner сперва обнаружил отдельный serialization mismatch: восстановление Vector3 из shortest Single JSON decimals в Double дало error около3.36e-6 вместо native float0. Исправлен только reported-error arithmetic с восстановлением Single operands; независимый velocity limit0.001 сохранён. Focused RED→GREEN и read-only revalidation принимают пять witnesses, но полный frozen BENCH4 по-прежнему отвергают за wall gap/unobserved6. Старый report не переписан.

### BENCH5: warmup прошёл, последующий wall gap остался

Bench-only stationary warmup прошёл:34callbacks,2.0591788 stable wall seconds, max gap0.0948103s, resets0. После него existing paid home/building/negative порядок поставлен перед outdoor up/down. Фиктивный zero-length маршрут не использовался: acquisition запустилась первым реальным HomeMove. Coarse actual trace сохранялся во время ожиданий.

Выполнены5 paid craft operations: tool/planner/hammer/door/TC. До первой placement NPC начал initial acquisition. Два accepted witnesses дали примерно0.023438m descent, скорости0.125/0.25m/s, acceleration2 и native velocity error0. На третьей команде fixed interval0.0625 и sequence остались корректны, но wall gap0.125893s превысил0.1s. Terminal-only read-only after-geometry записала target error≈0.5µm, clear sweeps/overlaps, same native floor/permission/water, native velocity error0. Она не приняла команду: pending завершён обязательным UNOBSERVED/WALL_GAP STOP. Runner правильно отверг полный run.

Placements0, ordinary motion0, scenes0, FLOOR_ACQUIRED0, STEP_RESOLVED0. Warmup не устранил задержку; причина scheduler lateness неизвестна. Измерения terminal diagnostic не превращены в height/traversal credit. Бюджет5/5 исчерпан.

## Матрица приёмки

| Capability | Фактический итог |
|---|---|
| Installed API/IL, same actor/body |Подтверждены signatures/IL и actual original body в новых live|
| Общий reusable candidate |Реализован и подключён к обоим caller в явном bench; не promoted|
| Actual MovePosition |BENCH3 unsafe; BENCH4 пять корректных fixed witnesses, шестой UNOBSERVED; общего PASS нет|
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

Финальный powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-All.ps1 перед BENCH5 завершился **exit0**. Лог: .local/audit/traversal017/test-all-prelive5.txt. После него runtime/test source не менялся. Прежние contracts, новые dual-clock/Single reconstruction regressions, acquisition/geometry/identity/world/negative/portal/economy fixtures и точная combined C#7.3 compile прошли. Единственное сохранённое warning CS0618 относится к legacy Rigidbody.velocity; API cleanup вне scope не выполнялся.

Pre-live Test-All выполнялся перед каждым PID. Один промежуточный run попал в ожидаемый RED missing-prelanding при добавлении regression; окончательные runs PASS. Synthetic fixtures остаются OFFLINE_ONLY и не заменяют PhysX.

Fresh independent reviewer проверил source/API, каждый frozen raw/server.log, все исправления и final nonpromotion branches. Найденные landing/undefined native outs/world/economy/inventory/observation/stale-velocity/Single reconstruction gaps закрыты. PRELIVE4 и PRELIVE5 source admissions получены до PID. Финальный raw review подтвердил PARTIAL и отсутствие P1 для bench-only поставки. **Wall-lateness policy и отсутствие multi-context physical proof остаются blockers для promotion.** Старые unsafe evidence не переклассифицировались.

## Owner, cleanup, privacy и encoding

Полный owner inventory3086 files проверен SHA-256/length; изменений0 после запусков. Protected1507 файлов вне exact5 разрешённых existing source edits неизменны: история001–016, old audit/raw/cache witnesses сохранены. Начальный protected inventory1512 включает эти5 intentionally edited source paths; это различие не скрывается.

Каждый run: GRACEFUL shutdown, наблюдаемый native exit−1, OwnedProcessAbsent/PortsReleased/FirewallRemoved=true, promotion=false. Финальный Windows audit после BENCH5: Rust/Steam/helpers/TCP/UDP/rules/live brokers/open leases/busy locks0; все37 historical+new leases закрыты. Закрытые marker/lock files как raw остаются локально; занятых locks нет.

SteamCMD/updater/owner BAT не запускались. Owner Server/maps/config/plugins не менялись; чужие процессы не останавливались. Source runtime и raw/secrets не публикуются из Server/.local/artifacts. Публичны только exact25 text files.

- mojibake-маркеры в изменённых файлах проверены;
- escaped Cyrillic в изменённых файлах проверены.

Exact-path audit также проверяет strict UTF-8/NUL, owner-value/credential/Steam-ID/non-loopback-IP patterns и все5 actual test RCON passwords. Raw только ignored .local/runtime/<run-id>/ и .local/audit/traversal017/. Audit manifests/hashes, test logs, source/raw reviews и safety reports сохранены там.

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

Первичная поставка exact25 paths завершена commit `e3b303b62ce3c4b6a8ead25997fa44948f4e0e4c`, local/tracking/public совпали. Её команды:

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

Продолжение использует только8 изменённых paths внутри прежнего25-path allowlist: PLAN.md, API_DECISION.md, DECISION.md, RESULT.md текущей017, src/navigation/ObstacleTraversal.cs, src/navigation/TraversalBench.cs, scripts/TraversalValidation.ps1, scripts/Test-Traversal.ps1. Дополнительная bounded inspection: git status --short; git rev-parse '@{upstream}'; git diff --stat; git diff --numstat -- src/navigation/ObstacleTraversal.cs scripts/TraversalValidation.ps1 scripts/Test-Traversal.ps1. Stage-Exact.ps1 проверяет baseline e3b303b/master/empty index, вычисляет только этот exact changed subset `$changed`, затем выполняет git add -n -- $changed и git add -- $changed. Cached diff/check/stat и final private exclusion выполняются прежними командами. Commit: git commit -m "fix: bind traversal to native physics clock". Push обычный, без force; из-за проверенного SSH publickey отказа используется только transport override, без изменения origin/config:

    git -c credential.interactive=false -c url.https://github.com/.insteadOf=git@github.com: push origin master

После push проверяются git rev-parse HEAD refs/remotes/origin/master, git status --short --branch --untracked-files=all, git ls-files -- Server/ .local/ artifacts/ и публичный branches/master через GitHub-коннектор. Полный восьмипутевой staging list и actual exits сохранены в ignored audit; supplied12 и остальные public artifacts не stage-изменяются.

## Что остаётся обязательным для GREEN

Явный physics-step/time-horizon contract реализован и подтверждён на коротких acquisition fragments. Нужны доказуемая политика scheduler lateness/безопасного hold и новые live доказательства outdoor ascent/down, genuine native building step/in-out, solid/door negative либо detour. Это не выполнено в017: все5 разрешённых starts использованы, шестой запрещён текущим бюджетом. Ни thresholds, ни native body не изменяются ради PASS. Physical gate REQUIRED; universal product objective не объявлен завершённым,018 не начинается.
