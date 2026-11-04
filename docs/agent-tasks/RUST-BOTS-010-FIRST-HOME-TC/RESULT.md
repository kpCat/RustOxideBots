# RUST-BOTS-010 — First Home / TC

Итог: **BLOCKED_SITE** по ACCEPTANCE. Оба headless JOURNEY завершились runtime **PARTIAL** до первого строительного placement. **Дом, дверь, TC, upkeep, HOME_NAV и independent home RESTORE не доказаны. GREEN_HOME_BOOTSTRAP не заявляется.**

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

Read-only native-map decode воспроизвёл первые48XYZ до0.000088м и все512кандидатов:20 проходят прежнюю эвристику перепада≤0.18м, все20 запрещены topology. В21из48подходах весь native nav check был успешным. Water-equality гипотеза отвергнута. Это чрезмерное ограничение site policy, **не native engine defect** и не доказательство невозможности дома на всей карте.

v0.2.1 заменяет этот искусственный flatness threshold глубиной настоящего foundation bounds/2, добавляет отдельный входной перепад≤0.25м, native foundation socket preview с проверенным planned-ray/rotation и все причины отказов. Water/topology/road/monument/foreign/collision/permission/native placement guards сохраняются. Никаких координат/индексов диагностической карты в runtime не внесено. Independent review и Test-All повторены до второго JOURNEY.

Первый shutdown GRACEFUL, ACK/native save, exit−1; own process absent/ports released/firewall removed, cache promotion=true. Независимый аудит: Rust/Steam/helper/ports/rules/open leases/live brokers/occupied locks=0;20leases closed. Owner3086files, SHA/length changes0. Raw snapshot/logs/journal/rejection evidence сохранены неизменными в ignored `.local/runtime/` и `.local/audit/home010/`.

## Второй JOURNEY

Run `3268a3d257a4470892ec8abf567d3e24`, plugin0.2.1, PID62212. Readiness271.164с, plugin270.154с; actual Oxide compile/load подтверждены. Captured combined source SHA **9581F331C87DDB90F8C353780A086DE5E2BED03C90EEB660D1C64E108446163F** совпадает с итоговым C# source+helper+module; после этого старта runtime code не менялся.

Один новый test-only ScientistNPC той же архитектуры, без второго строителя в процессе.53 native natural hits →200wood+107stones; оплачено200wood+100stones, новый stonehatchet UID130234. Это новый **JOURNEY**, не восстановление Items первого run. Финальные Items — original starter rock,7stones, paid axe. Полный home budget3760wood не добывался, поскольку первоначальный site admission отказал.

Независимый audit восстановил **260.577550м**,330samples,8legs, max step1.660229м, max gap0.524414с. Два небезопасных source routes отклонены до debit. Native journal165records (53GATHER и1CRAFT), SHA **DCB65BE51D3B79129C517BAAAF18E704B8625498028DE064350FC1A88D5900A4**; receipts и exact payment проверены отдельно.

Все512кандидатов теперь имеют полные причины:340прошли native foundation socket preview,352outdoor sampling,344complete approaches. Ни один не прошёл весь admission. Число отказов по отдельным flags (они пересекаются):478 — широкий45м `DecayEntity` proximity filter;449entrance height;432topology;431monument;265collision;205road;172native preview;168nav;156depth range;8water. **478 не означает478 настоящих TC/чужих домов**: этот консервативный фильтр охватывает также другие native DecayEntity-подтипы. Кандидатов, которым помешал только этот фильтр,0; простое снятие одного ограничения не подтверждает работоспособность.

Остановка та же: `Bounded safe home site unavailable before materials`. Placement calls0, owned building ledger пуст, Home/TC/upkeep null, SaveReady/Saved/Restored=false, home navigation events0.340previews — операции над native Placement-данными, **не созданные foundations**. Возможность построить дом в другом участке/другом мире не опровергнута; map-wide невозможность не заявляется.

GRACEFUL, ACK/complete native world/navmesh save, exit−1; process absent/ports released/firewall removed, cache promotion=true. **Native world save не является отсутствующим actor/home snapshot**; передавать этот run в RESTORE как completed home запрещено.

Третий real start не выполнялся: доказанного engine defect нет. Первый отказ — чрезмерная authored policy, второй — отсутствие accepted site в текущем bounded поиске. Снимать safety filters/спавнить некорректный дом/расширять live budget ради GREEN нельзя. Следующий Goal/Slice не начинался.

## Ограничения / итоговые gates

| Gate | Итог010 |
|---|---|
| ACTOR / outdoor RustNav / paid tool | LIVE: один ScientistNPC в каждом процессе, native gather/real payment/continuous trace |
| Loaded home recipes / grade budget | LIVE_LOADED; расход на home entities ещё не выполнялся |
| SITE | BLOCKED:0accepted sites; во втором run340native previews и344подхода не заменяют полный admission |
| Full MATERIALS / STRUCTURE / TC / upkeep / DOOR | NOT_PROVEN, native home entities0 |
| HOME_NAV | NOT_CONDUCTED: дома нет |
| Independent home RESTORE | NOT_CONDUCTED: нет completed bound home snapshot |
| Safety | PASS в пределах проверенных fingerprints/process/ports/rules/leases/locks |
| Code / offline contracts | Test-All и installed C#7.3 compile PASS; home runtime branches после site не проверены live |

Два preflight без игрового PID и offline fixtures не считаются real starts. CRASH_ATOMIC009 остаётся NOT_PROVEN; production/multi-map/50–100NPC не заявляются. Совместимость001–009 проверена existing offline suite; их прежние live результаты не переписываются и не выдаются за новые E2E010.

Native Roam capsule state записывается как есть. r0.5/h1.8 geometric clearance samples не выдаются за Rigidbody collision response или client animation. Actual floor/door collider motion/portal crossing и postbuild Complete paths обязательны для HOME_NAV.

## Проверки / сохранность / delivery

Полные `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-All.ps1` прошли до обоих starts; финальный source0.2.1 и contract suite также прошли повторную compile/review проверку. Receipt — ignored `.local/audit/home010/tests-prelive-v021.txt`; финальная проверка доставки — `tests-final.txt`. Ни fixture, ни compile не заменяет отсутствующие live home gates.

Независимый final review заново разобрал оба native165-record journals, source snapshots, фактические compiler/startup/ACK/save logs и отсутствие home claims. Общий outcomeBLOCKED_SITE и per-runPARTIAL согласованы.

Финальный safety audit после Test-All **15:01:01UTC**: Rust/Steam/helper/TCP/UDP/rules/live brokers/open leases/occupied locks=0; все21leasesclosed. Full owner audit после финального Test-All **15:01:50UTC**: **3086файлов, SHA/length changes0**. Все four legacy plugin source hashes прежние. Rust/Oxide, owner мир/конфиги/моды/BAT не менялись; SteamCMD/update/validate/owner BAT не запускались. Тестовые процессы — только physical cache + deny-all firewall + owned kill-on-close Job Object; чужие процессы не завершались.

Raw server/result/plugin-result, captured source,165-record journals, map-decode diagnostics, source/owner/cache hashes, passwords и audit receipts остаются только ignored `.local/`. Public guard проверяет18exactpaths, strict UTF-8/NUL, owner values/credentials/Steam IDs/non-loopback IP и оба реальных RCON secrets. Server/ полностью ignored/untracked; raw/секреты не stage/push.

- mojibake-маркеры в изменённых файлах проверены;
- escaped Cyrillic в изменённых файлах проверены.

Git разрешён пользователем и TASK для baseline, scope/privacy audit и точной доставки. Фактические inspection команды: `git rev-parse HEAD`, `git rev-parse refs/heads/master`, `git rev-parse refs/remotes/origin/master`, `git branch --show-current`, `git remote get-url origin`, `git ls-remote origin refs/heads/master` (SSH отказ), HTTPS `git -c credential.interactive=false -c url.https://github.com/.insteadOf=git@github.com: ls-remote origin refs/heads/master`; `git status --short`, `git status --short --untracked-files=all`, `git ls-files -- Server/`, `git check-ignore Server/ .local/ artifacts/`, `git diff --check`; `git diff --stat --` и `git diff --numstat --` для четырёх изменённых tracked code/runner/compile/suite paths. Exact scope guard также использует `git diff --name-only 648fbb1520e25bd1ac1b8f328c6d4d36e2a5641f`.

Delivery inventory: `git add -n -- $paths`, `git add -- $paths` — только18path allowlist PLAN; `git diff --cached --name-only`, `git diff --cached --check`, `git diff --cached --stat`, `git diff --cached --no-ext-diff -- $paths`; `git commit -m 'feat: add guarded first-home probe and blocked site evidence'`; обычный `git -c credential.interactive=false -c url.https://github.com/.insteadOf=git@github.com: push origin master`; затем `git rev-parse HEAD refs/remotes/origin/master`, public HTTPSls-remote и clean-tree check. No force/reset/rebase/merge/branch/clean/stash/broad add/history rewrite. Remote config не меняется.

Commit не может содержать собственный SHA. Итоговый local/tracking/public SHA, фактический commit/push exit status и clean-tree receipt фиксируются после доставки в ignored `.local/audit/home010/delivery.json` и финальном ответе. BLOCKED_SITE от факта публикации не становится GREEN.
