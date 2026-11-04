# RUST-BOTS-010 — First Home / TC

Итог после четырёх JOURNEY: **PARTIAL / BLOCKED_BUDGET**. Четвёртый процесс нашёл допустимый site и добыл3763wood при бюджете3760, но временной guard остановил сценарий до home craft/placement. **Главная цель не достигнута: дом, дверь, TC, upkeep, HOME_NAV и independent home RESTORE не доказаны. GREEN_HOME_BOOTSTRAP не заявляется.** Первые два исторических результата — BLOCKED_SITE.

## Основание и scope

HEAD, local master, tracking origin/master и публичный master совпали с `648fbb1520e25bd1ac1b8f328c6d4d36e2a5641f`. Ветка master; исходно untracked только восемь переданных файлов010. SSH оказался недоступен; HTTPS проверен без изменения remote. Корневые/родительские инструкции, README, пакет010, API/RESULT006–009, roadmap и ближайшие runtime/runner/validator аналоги прочитаны до правок. Дополнительные ancestor/nested AGENTS, csproj/props/targets, code-map/pattern не найдены.

Exact allowlist —18 paths из [PLAN.md](PLAN.md):11 документов010, существующий avatar plugin, компактный `src/home/FirstHome.cs`, новый validator/test и три runner/compile/suite integration файла. Старые RESULT и EconomyJournal не переписаны; four legacy plugins и infrastructure/cache/firewall/job source не меняются. C#7.3/PowerShell5.1, текущий Rust/Oxide, без новых dependencies.

## STATIC / OFFLINE

Точные API/IL/prefab/cost/native save решения — в [API_DECISION.md](API_DECISION.md). Путь — настоящий оплаченный held Planner, native sockets/DoBuild/registration/payment, отдельно native Wood upgrade; честный **SERVER_ACCOUNTED_BUILD**. TC bot-ID authorization/upkeep/door и RustNav dynamic geometry API подтверждены STATIC; само исполнение этих home API до текущего run не доказано.

Test-All001–009 и шесть focused home contract групп PASS перед каждым real start. C#7.3 compile всех пяти plugins против installed DLL PASS. Fixtures — OFFLINE_ONLY: exact costs/UID/condition, world/owner/structure, portal position/time/clearance, arbitrary source disk/geometry/health/depletion/NOOP, четыре native held items/alias/container restore. Fixtures не являются live building evidence.

Независимый prelive review нашёл и помог исправить: дополнительный Target yaw, наружный roof socket, закрытую дверь перед TC, TC auth до последнего placement, structural preflight до rebind, недостаточную связку source/held/nav receipts, PowerShell quaternion/boolean precedence. Все проверенные негативы отвергаются. Ни один review не объявлял GREEN.

## Первый JOURNEY — сохранённый PARTIAL

Run `aee154abff86469a8ca15f1c8166e535`, plugin0.2.0, PID50832. Live Oxide compiled/loaded; readiness275.774с, plugin273.747с. Captured combined source SHA **C9C2726A7AB29195EAE3E7A4AD2B1878918E7DFE6EED89B84C84D3051E99340A**.

Один настоящий ScientistNPC/BasePlayer, engine bot identity без Steam impersonation, native PlayerInventory/rock/held/RustNav.53 natural native hits →200wood+107stones; **NATIVE_PLAYER_GATHER**, adapter credits0, drops0.200wood+100stones физически списаны, создан один stonehatchet UID119812 через **SERVER_ACCOUNTED_CRAFT**. Финальные native Items: original rock, stones7, тот же paid axe. Повторной/бесплатной выдачи материалов нет.

Независимо восстановлены **197.790817м**,289samples,7legs, max step1.734155м, max gap0.59729с. Native journal165records, SHA **6F241CD046059C0A5A24FC0F998BDA6AD255FB3B49778EE7875A572BA02368CC**; parser и native before/debit/after chain проверены отдельно. Actor/item inventory snapshot для RESTORE не создан: это не completed home journey.

Остановка: `Bounded safe home site unavailable before materials`.512 кандидатов,0 строительных placement/TC/door/upkeep/HOME_NAV. Первые48 final-reason samples:9COLLISION,8ROAD,27RUSTNAV,4TOPOLOGY. Эти причины перезаписывали более ранние flags, поэтому histogram не является диагнозом engine.

Read-only native-map decode воспроизвёл первые48XYZ до0.000088м и все512кандидатов:20 проходят прежнюю эвристику перепада≤0.18м, все20 запрещены topology. В21из48расчётов пути native nav check был успешным. Water-equality гипотеза отвергнута. Это чрезмерное ограничение site policy, **не native engine defect** и не доказательство невозможности дома на всей карте.

v0.2.1 заменяет этот искусственный flatness threshold глубиной настоящего foundation bounds/2, добавляет отдельный входной перепад≤0.25м, native foundation socket preview с проверенным planned-ray/rotation и все причины отказов. Water/topology/road/monument/foreign/collision/permission/native placement guards сохраняются. Никаких координат/индексов диагностической карты в runtime не внесено. Independent review и Test-All повторены до второго JOURNEY.

Первый shutdown GRACEFUL, ACK/native save, exit−1; own process absent/ports released/firewall removed, cache promotion=true. Независимый аудит: Rust/Steam/helper/ports/rules/open leases/live brokers/occupied locks=0;20leases closed. Owner3086files, SHA/length changes0. Raw snapshot/logs/journal/rejection evidence сохранены неизменными в ignored `.local/runtime/` и `.local/audit/home010/`.

## Второй JOURNEY

Run `3268a3d257a4470892ec8abf567d3e24`, plugin0.2.1, PID62212. Readiness271.164с, plugin270.154с; actual Oxide compile/load подтверждены. Captured combined source SHA **9581F331C87DDB90F8C353780A086DE5E2BED03C90EEB660D1C64E108446163F** совпадал с source+helper+module в историческом commit5310; последующие изменения отдельно проверены в третьем/четвёртом процессах.

Один новый test-only ScientistNPC той же архитектуры, без второго строителя в процессе.53 native natural hits →200wood+107stones; оплачено200wood+100stones, новый stonehatchet UID130234. Это новый **JOURNEY**, не восстановление Items первого run. Финальные Items — original starter rock,7stones, paid axe. Полный home budget3760wood не добывался, поскольку первоначальный site admission отказал.

Независимый audit восстановил **260.577550м**,330samples,8legs, max step1.660229м, max gap0.524414с. Два небезопасных source routes отклонены до debit. Native journal165records (53GATHER и1CRAFT), SHA **DCB65BE51D3B79129C517BAAAF18E704B8625498028DE064350FC1A88D5900A4**; receipts и exact payment проверены отдельно.

Все512кандидатов теперь имеют полные причины:340прошли native foundation socket preview,352outdoor sampling,344calculated Complete paths. Ни один не прошёл весь admission. Число отказов по отдельным flags (они пересекаются):478 — широкий45м `DecayEntity` proximity filter;449entrance height;432topology;431monument;265collision;205road;172native preview;168nav;156depth range;8water. **478 не означает478 настоящих TC/чужих домов**: этот консервативный фильтр охватывает также другие native DecayEntity-подтипы. Кандидатов, которым помешал только этот фильтр,0; простое снятие одного ограничения не подтверждает работоспособность.

Остановка та же: `Bounded safe home site unavailable before materials`. Placement calls0, owned building ledger пуст, Home/TC/upkeep null, SaveReady/Saved/Restored=false, home navigation events0.340previews — операции над native Placement-данными, **не созданные foundations**. Возможность построить дом в другом участке/другом мире не опровергнута; map-wide невозможность не заявляется.

GRACEFUL, ACK/complete native world/navmesh save, exit−1; process absent/ports released/firewall removed, cache promotion=true. **Native world save не является отсутствующим actor/home snapshot**; передавать этот run в RESTORE как completed home запрещено.

На момент commit5310 третий real start не выполнялся: engine defect не было. Затем владелец явно разрешил ещё два старта после offline fix/review. Первые два raw сохранены; это разрешение не переименовывает authored ошибки в engine defect. Следующий Goal/Slice не начинался.

## Третий JOURNEY по дополнительному разрешению

Run `ad44b7ffe71c49bdb611cb81827340dc`,0.2.2, PID66856; readiness279.433с, plugin-ready278.426с. Actual Oxide compile/load подтверждены отдельно; эти интервалы не являются длительностью компиляции. Captured source SHA **6BBAE218E39565CC6DC35EF1DF0FDD49074D8D5C3646A0504A42CF569285C9A3**. Native site принят на16184-й попытке; все прежние запреты сохранены и дополнены native bounds/PreventBuilding/uncached privilege. Рассчитан Complete site path152.000м; физический SITE leg ещё не выполнялся. Подробные clearance measurements — API_DECISION.

352 успешных native hits:3257wood+107stones всего, из них200wood+100stones оплачивают axe UID140460. Финальный запас3057wood+7stones. После299 успешных axe hits его condition0.313634; следующий native удар уменьшил condition до0 и не выдал ресурс. Runtime PARTIAL: `Native debit without inventory yield; no adapter retry`. Это ошибка планирования wear, не engine defect.0home payments/placements, snapshot отсутствует, home RESTORE запрещён.

Независимый audit: journal1063records, SHA **C98D368520929FE8131A164FF870187749575C3E11C64863A5195ECB478247D4**. Committed prefix1062records совпадает с352native receipts и paid craft; последний PREPARED остаётся IN_DOUBT и existing parser отвергает automatic replay. Terminal inventory отличается от последнего successful receipt только native break condition; ресурсный credit не появился. Trace541.495916м,1556samples,32legs, max step1.678833м/max gap0.559723с.

ACK и complete native save записаны, но процесс не вышел за30с: **FORCED_OWNED_JOB**, cache promotion=false. Это не graceful bound checkpoint для RESTORE. После cleanup Rust/Steam/helper/ports/rules/open leases/live brokers/occupied locks0, все22leasesclosed. Immutable предыдущая warm generation и runtime hashes повторно PASS; raw journal/result/source/log сохранены. Причина задержки native exit UNKNOWN.

v0.2.3 предотвращает breaking hit и один раз переключается на исходный rock с новым физическим approach; ничего не чинит и не выдаёт. Global FirstHome1100с/runner1200с, legacy900с. Полный private result остаётся, console summary сокращён. До следующего live эти изменения — OFFLINE_ONLY; review нашёл и исправил смешение expected product/active rock UID и недостаточную привязку switch receipt к chain/actor.

## Четвёртый JOURNEY — полный material budget, без дома

Run `39baf6925235477ebbca7aa07d2b73fd`,0.2.3; readiness271.994с, plugin-ready270.986с. Actual Oxide compile/load подтверждены; итоговый source точно совпадает с captured combined SHA **4A18E5357C4735CA03C5839E249B7871539F255D9EC4361AE4EFA9BA52001DA7**. Runtime code после этого старта не менялся.

488 успешных native hits →3963wood+107stones gross. Paid axe стоит200wood+100stones; terminal inventory3763wood+7stones, полный loaded budget3760wood доступен. Один actual switch с того же paid axe на исходный rock связывает actual actor, неизменённый inventory и следующий native gather. Axe condition1.313834, rock35.87207; repair/replacement/new tool credit отсутствуют. Journal **1470records, все intents COMMITTED**, SHA **CD082E71D27373F36D3B2EE422DC41586B296F48FF9548AFBDBB2360ECE1EF50**. Независимый parser/receipt audit PASS; не путать с IN_DOUBT третьего run.

Site принят на16184-й попытке с рассчитанным initial Complete path153.463м и native clearance guards. Физический SITE leg не выполнялся; реальные554.629021м ниже относятся к ресурсным маршрутам. После сбора материалов geometry/native preview/коллизии/privilege снова проходят; final calculated path status `PathComplete`. Единственная rejection category — `RUSTNAV_OR_TRAVEL_BOUND`. Gameplay989.50436с оставил **не более110.49564с**; reserve120с плюс minimum travel bound30с гарантированно запрещают admission. Final path length/TravelSeconds в rejected telemetry не записаны: прохождение отдельных length≤800/seconds≤300 branches не заявляется. Сообщение `Selected home site changed before paid home craft` здесь обозначает общий отказ admission, а не доказанное изменение геометрии.

Это недостаточное планирование времени полного сбора с консервативным upkeep reserve, **не доказанный engine defect**. Home craft/payment/placement0, building entities0, TC/door/upkeep отсутствуют. SaveReady/Saved/Restored=false; completed actor/home snapshot не создан. Full native material ledger не заменяет отсутствующий дом.

Trace **554.629021м**,1981samples,37legs, max step1.660832м/max gap0.510987с; positional writes0, один controlled ScientistNPC. GRACEFUL, ACK и native save, process absent/ports released/firewall removed, cache promotion=true. Эта world-only promotion не разрешает home RESTORE без snapshot. Пятый условный RESTORE неприменим: его условие — валидный сохранённый дом — не выполнено. Исходный бюджет2 и разрешённые владельцем дополнительные2старта исчерпаны; пятого процесса нет.

## Ограничения / итоговые gates

| Gate | Итог010 |
|---|---|
| ACTOR / outdoor RustNav / paid tool | LIVE: один controlled ScientistNPC в каждом процессе, native gather/real payment/continuous trace |
| Loaded home recipes / grade budget | LIVE_LOADED; расход на home entities ещё не выполнялся |
| SITE | LIVE_ADMITTED в третьем/четвёртом процессах; это не доказательство placement. Первые два — BLOCKED_SITE |
| MATERIALS | LIVE: полный loaded stock3763/3760wood после paid axe; расходы на дом ещё не выполнялись |
| STRUCTURE / TC / upkeep / DOOR | NOT_PROVEN, native home entities0 |
| HOME_NAV | NOT_CONDUCTED: дома нет |
| Independent home RESTORE | NOT_CONDUCTED: нет completed bound home snapshot |
| Safety | PASS в пределах проверенных fingerprints/process/ports/rules/leases/locks |
| Code / offline contracts | Test-All и installed C#7.3 compile PASS; home runtime branches после site не проверены live |

Два preflight без игрового PID и offline fixtures не считаются real starts. CRASH_ATOMIC009 остаётся NOT_PROVEN; production/multi-map/50–100NPC не заявляются. Совместимость001–009 проверена existing offline suite; их прежние live результаты не переписываются и не выдаются за новые E2E010.

Native Roam capsule state записывается как есть. r0.5/h1.8 geometric clearance samples не выдаются за Rigidbody collision response или client animation. Actual floor/door collider motion/portal crossing и postbuild Complete paths обязательны для HOME_NAV.

## Проверки / сохранность / delivery

Полные `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-All.ps1` прошли до каждого start, после исправлений review и после четвёртого процесса. Финальный source0.2.3: C#7.3 compile всех пяти plugins и focused suite PASS, receipt `.local/audit/home010/tests-final-v023.txt`. Ни fixture, ни compile не заменяет отсутствующие live home gates.

Независимый review разобрал первые два165-record journals, третий1063-record IN_DOUBT и четвёртый1470-record committed journal, source snapshots, фактические compile/startup/ACK/save/cleanup и отсутствие home claims. Отдельные дефекты site coverage, wear и временного плана не названы engine невозможностью. Финальный код сохраняет fail-closed поведение, но полного bootstrap ещё не достигает.

Финальный safety audit после Test-All **16:49:59UTC**: Rust/Steam/helper/TCP/UDP/rules/live brokers/open leases/occupied locks=0; все23leasesclosed. Full owner audit после четвёртого процесса: **3086файлов, SHA/length changes0**. Все four legacy plugin source hashes прежние. Rust/Oxide, owner мир/конфиги/моды/BAT не менялись; SteamCMD/update/validate/owner BAT не запускались. Тестовые процессы — только physical cache + deny-all firewall + owned kill-on-close Job Object; чужие процессы не завершались.

Raw server/result/plugin-result, captured source, все четыре journals, map-decode diagnostics, source/owner/cache hashes, passwords и audit receipts остаются только ignored `.local/`. Public guard проверяет18exactpaths, strict UTF-8/NUL, owner values/credentials/Steam IDs/non-loopback IP и четыре реальных RCON secrets. Server/ полностью ignored/untracked; raw/секреты не stage/push.

- mojibake-маркеры в изменённых файлах проверены;
- escaped Cyrillic в изменённых файлах проверены.

Git разрешён пользователем и TASK для baseline, scope/privacy audit и точной доставки. Фактические inspection команды: `git rev-parse HEAD`, `git rev-parse refs/heads/master`, `git rev-parse refs/remotes/origin/master`, `git branch --show-current`, `git remote get-url origin`, `git ls-remote origin refs/heads/master` (SSH отказ), HTTPS `git -c credential.interactive=false -c url.https://github.com/.insteadOf=git@github.com: ls-remote origin refs/heads/master`; `git status --short`, `git status --short --untracked-files=all`, `git ls-files -- Server/`, `git check-ignore Server/ .local/ artifacts/`, `git diff --check`; `git diff --stat --` и `git diff --numstat --` для четырёх изменённых tracked code/runner/compile/suite paths. Exact scope guard также использует `git diff --name-only 648fbb1520e25bd1ac1b8f328c6d4d36e2a5641f`.

Delivery inventory: `git add -n -- $paths`, `git add -- $paths` — только18path allowlist PLAN; `git diff --cached --name-only`, `git diff --cached --check`, `git diff --cached --stat`, `git diff --cached --no-ext-diff -- $paths`; `git commit -m 'feat: add guarded first-home probe and blocked site evidence'`; обычный `git -c credential.interactive=false -c url.https://github.com/.insteadOf=git@github.com: push origin master`; затем `git rev-parse HEAD refs/remotes/origin/master`, public HTTPSls-remote и clean-tree check. No force/reset/rebase/merge/branch/clean/stash/broad add/history rewrite. Remote config не меняется.

Продолжение после5310 дополнительно использовало `git status --porcelain=v1`, `git diff --stat`, `git diff --numstat -- src/home/FirstHome.cs scripts/FirstHomeValidation.ps1 scripts/Test-FirstHome.ps1`; review команды `git diff 5310 -- src/home/FirstHome.cs src/plugins/RustBotsAvatarSurvival.cs scripts/FirstHomeValidation.ps1 scripts/Test-FirstHome.ps1 docs/agent-tasks/RUST-BOTS-010-FIRST-HOME-TC/PLAN.md` и `git diff -- src/plugins/RustBotsAvatarSurvival.cs scripts/FirstHomeValidation.ps1 scripts/Test-FirstHome.ps1`. Они разрешены тем же TASK/user scope guard и независимым review.

Новая доставка stage только7из18разрешённых путей: `docs/agent-tasks/RUST-BOTS-010-FIRST-HOME-TC/PLAN.md`, `docs/agent-tasks/RUST-BOTS-010-FIRST-HOME-TC/API_DECISION.md`, `docs/agent-tasks/RUST-BOTS-010-FIRST-HOME-TC/RESULT.md`, `src/plugins/RustBotsAvatarSurvival.cs`, `src/home/FirstHome.cs`, `scripts/FirstHomeValidation.ps1`, `scripts/Test-FirstHome.ps1`. Final review также использовал `git diff --numstat -- $paths` в разрешённой allowlist. Команды exact staging/cached checks те же с точным набором семи изменённых `$paths`; commit — `git commit -m 'fix: bound first-home site search and preserve gathering tools'`. Push — `git -c credential.interactive=false -c url.https://github.com/.insteadOf=git@github.com: push origin master`, без force; remote config не меняется.

Commit не может содержать собственный SHA. Итоговый local/tracking/public SHA, фактический commit/push exit status и clean-tree receipt фиксируются после доставки в ignored `.local/audit/home010/delivery.json` и финальном ответе. PARTIAL/BLOCKED_BUDGET от публикации не становится GREEN. Следующий live требует нового явно разрешённого бюджета и исправленного offline/review плана; прежний conditional RESTORE не подходит для нового JOURNEY.
