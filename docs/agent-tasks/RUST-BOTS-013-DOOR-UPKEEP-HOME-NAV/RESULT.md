# RUST-BOTS-013 — результат 04.11.2026

Итог: **PARTIAL**. В одном изолированном BUILD_SMOKE доказаны исправленный post-TC подход, настоящая оплаченная дверь, native TC upkeep более 60 минут и физический вход NPC к TC. На обратном выходе сработал capsule-clearance guard. Полный `DIAGNOSTIC_HOME_GREEN` и `GREEN_HOME_BOOTSTRAP` не достигнуты.

Выполнен **1 live запуск из максимума 3**. SMOKE_2, NATURAL и independent RESTORE не запускались: G2 не допускает новый smoke без установленного узкого дефекта и безопасного исправления. Старый raw не содержит collider identity нового отказа; угадывать его или менять clearance ради PASS нельзя. Manual gate остаётся REQUIRED, passed не объявлен.

| Этап | Класс доказательств | Фактический результат |
|---|---|---|
| Baseline | STATIC | Local HEAD, origin/master, actual HTTPS remote и публичный GitHub master совпали с `237fb6f18e513a2197d5a919e1fb38ab83ea6358`; master, supplied docs013 untracked, чужих правок нет |
| API/IL | STATIC_IL | Установленные RustNav sample/path/tiles, Physics, Planner, Door gates/colliders и native upkeep; C# 7.3 compile |
| Контракты | OFFLINE_ONLY | Focused RED→GREEN: missing subreason/legacy diagnosis, false complete path, fake-door receipt/payment, UID upkeep/60-minute floor |
| Post-TC approach | LIVE_DIAGNOSTIC | Legacy sample и terrain успешны; собственный NPC ошибочно считается capsule obstacle. CURRENT stand прошёл отдельные физические/native проверки |
| Дом / TC | LIVE_DIAGNOSTIC | 6 native Wood blocks, own TC, одна native group, поддержка/связи/save registration, own-only auth/IsAuthed/CanBuild |
| Door | LIVE_DIAGNOSTIC | Один оплаченный Planner.DoBuild, native Door, настоящий doorway socket, native open и изменение collider |
| Upkeep | LIVE_DIAGNOSTIC | Original wood UIDs перенесены в TC; native rate134 wood/1440 min, protection0→11176.1191 min, decay включён |
| HOME_NAV | LIVE_DIAGNOSTIC / PARTIAL | Calculated complete path, физический вход и supported floor, TC LOS/range; на обратном пути collision guard. Полный exit/close NOT_PROVEN |
| Smoke isolation | LIVE_DIAGNOSTIC | Новая физическая install/identity/Oxide data, TEST_FIXTURE, no cache promotion, no production/restore source |
| NATURAL | NOT_PROVEN | 0 запусков, harvest0, нет натуральной экономики дома |
| Independent RESTORE | NOT_PROVEN | 0 запусков, completed natural home checkpoint отсутствует |
| Safety | STATIC + runtime receipts | Owner3086 файлов без изменений; protected348 без изменений; cleanup процессов/портов/firewall/locks подтверждён |

## Изменения и ограничения

Три существующих файла: `src/home/FirstHome.cs`, `scripts/FirstHomeValidation.ps1`, `scripts/Test-FirstHome.ps1`. Дополнительно только документы013: девять supplied файлов, API_DECISION и этот RESULT — exact allowlist14 путей. Это bounded exception для одной document family; продуктовый scope остаётся в трёх файлах. UI, инфраструктура, прежние001–012, avatar/economy source и owner Server не изменялись. AGENTS выше корня, отдельные code-map/pattern, csproj/props/targets и GATES013 не найдены.

Переиспользованы HomeInterior floor/raycast pattern, проверенный native placement012 и HomeMove complete-path route. Добавлены раздельные nav/ground/normal/terrain/water/capsule/LOS/range/permission/path receipts, geometry-relative кандидаты и доказательство current stand. После размещения — native rebuild фактических bounds, before/after pending и 30-секундный timeout. Приёмка отвергает missing legacy subreason и default PathComplete без CalculatePath, fake Door и неоплаченный upkeep. Native DoBuild, стоимость, LOS, range и коллайдеры сохранены; warp/teleport/collider disable/resize не добавлены.

Rust protocol2635.289.1, Unity6000.3.15x1-13, Changeset168909; Oxide.Rust2.0.7839, .NET SDK10.0.402, Windows PowerShell5.1.19041.6456. Runtime не обновлялся. Assembly-CSharp SHA `04FB89520F18A1920C1B1A350B82DD24A4258F31D97B82496971A9CC7A49DCB7`; RustDedicated SHA `EFAC429DB737EB4B32A2BFC48029B4BE6FF475336958F4557F891F17255FFD38`.

## Единственный smoke

Run `16760351f75b4a29a8fc138ffa7f1c08`, PID70452, старт `2026-11-04T20:02:59.5036542Z` (22:02:59 Chisinau). Readiness311.195с, plugin-ready310.181с; фактическая live Oxide compilation/load подтверждена отдельно. Frozen combined source SHA `5B16046E165318C0097727A92A29BF2BDF634800FC30D81190875F563027B21F` совпадает с текущими avatar + EconomyJournal + FirstHome. FirstHome SHA `27B9F7F2DC28256A01A380CA864AA44A12364B9B27C8920AB1B2D4B6EEB07644`; предыдущий012 FirstHome SHA `C19D947F4A7E2CF1017A0BCB656186BE0DE011B017FD3A16A1D81D7CBC67DB40`.

Свежая физическая копия verified pristine generation `world-45fabb2276794f4abdbace642b1b814c`, input save SHA `0D17022038534B023EFFCBCB464EC2CD69444A75317F33B2442D17BF51E6EF28`. Частичный дом012 не использован. Отдельная run-specific identity, свои Oxide config/data/logs, atomic Job Object и firewall lease. Source/map/manifest hash checks выполнены существующим runner.

Один ScientistNPC/BasePlayer, actor142730, native engine bot15 без Steam impersonation. Starter rock и явно маркированные TEST_FIXTURE:3960wood+100stones, пять UID. 19 committed payments: native/accounted crafted tools/items, шесть Twig builds с native Wood upgrades, TC и Door. Списано2920wood+100stones; Door потребил настоящий `door.hinged.wood` Item. Native placement calls8, повторов paid intent0, pending intent отсутствует.

Native foundation146592, walls146650/146705/146760, doorway146763, roof146766, TC146769, Door146777; owner15/buildingID1, real group/support/save registration. TC autoauth только15, adapter AddPlayer0, чужих auth0, IsAuthed/CanBuild=true. Door создан на parent146763/socket `wall.doorway/sockets/doorway-female/1`; Phrase/debug пустые, DoBuild вернул Door, spawn shortcut отсутствует.

Upkeep переносит original UID142746 (80wood) и142747 (960wood), stacking=false; exact PlayerInventory→TC conservation проверен отдельно. Native CalculateUpkeepCostAmounts134wood, period1440min, GetProtectedMinutes(true)0→11176.1191min. Decay.upkeep=true/scale1/wood duration3. Бесплатный credit отсутствует. После transfer inventory совпадает с paid ledger и конечным native inventory.

### Корень post-TC отказа

В новом мире старый composite на step7: SamplePosition=true, first ray=Terrain, normal/water допустимы, sample delta−0.127336м, terrain delta−0.000013м, pending=false. Overlap ровно1 — собственный CapsuleCollider actor142730, Self=true. Итог `CAPSULE_OVERLAP`; native RustNav здесь не отказал. Исторический012 subreason остаётся UNKNOWN: его старую telemetry задним числом не дополняем.

CURRENT receipt на настоящей позиции: SamplePosition=true, terrain floor, CapsuleClear=true после исключения только self, CanBuild/LOS=true, reach0.812125м при native4м, CalculatePath=true/PathComplete. Door выполнен без ненужного перемещения. Семь rebuild/readiness пар показали pending true→false за ограниченное ожидание; timeout не сработал.

### Физический вход и незавершённый выход

Native Door.SetOpen(true,false), flag false→true, реальный hinge collider изменил положение. INSIDE_TC PathComplete1.599467м; фактические PHYSICS clear/OwnedFloor, CROSSED_IN в380.664764с, TC_REACHED381.163147с, range1.546368м/LOS=true. Затем рассчитан OUTSIDE PathComplete1.457232м.

Первый отказ381.66626с: PHYSICS Clear=false, Inside=false, DoorOpen=true. Frozen HomePhysicalSample бросает при непустом overlap, исключив только self/foundation. Floor-branch не причина throw, потому что Inside=false. **Collider ID/type отсутствуют: точный объект UNKNOWN.** Из этого нельзя заключить frame/terrain collision или дефект RustNav. Отказ произошёл до HomeCrossing и Sample этого tick; CROSSED_OUT=false, NavigationComplete=false. Native door close не исполнялся. Сохранены все фактические receipts, но полный HOME_NAV не доказан.

Независимая геометрическая проверка: интерполированный outbound crossing требует halfwidth≈0.599725м при native0.600000143м; выход за aperture не установлен. Read-only heightmap proxy калиброван по ray до0.000000424м и остаётся ниже capsule минимум0.07296м; Unity collider identity этот proxy не доказывает. Decoded doorway collider данные не найдены в ближайшем historical extract. Поэтому спекулятивного исправления/SMOKE_2 нет.

141 непрерывный sample, независимо пересчитано105.319054м, max gap0.578888с/max step1.832899м; совпадает с total105.319038м в пределах float. Это включает успешный вход, но не полный обратный маршрут. Position writes0 подтверждены source review. Smoke не сохраняет actor/home checkpoint, SaveReady/Saved/Restored=false. Native shutdown save не является completed natural home.

## Проверки, evidence и доставка

Raw только ignored: `.local/runtime/16760351f75b4a29a8fc138ffa7f1c08/{server.log,result.json,plugin-result.json,RustBotsAvatarSurvival.cs,home-evidence/}`; 49 home evidence files скопированы с SHA checks. Private audit `.local/audit/home013/`: IL/API, RED/GREEN logs, prelive-review.md, smoke1-review.md, phase-audit.json, live-run audit, terrain-comparison.json, owner/protected/safety/public audits. Raw smoke/source не переписывались после завершения.

Prelive Test-All exit0; финальный `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-All.ps1` — exit0, полный вывод в `tests-final.txt`. Native compiler работает против installed DLL, synthetic tests помечены OFFLINE_ONLY. Independent source review исправил missing legacy-receipt/subreason validation через RED→GREEN; G2 review требует PARTIAL и не допускает спекулятивный повтор. Финальный независимый review (`final-review.md`) не нашёл новых blocking source defects или неподтверждённых success claims. Две формулировки отчёта уточнены: legacy input отличается от CURRENT candidate при неподвижном actor; финальные проверки приведены по фактическим результатам. Product source после live не менялся.

GRACEFUL shutdown, ACK/native save, наблюдаемый native exit−1 сохранён; process absent/ports released/firewall removed=true, promotion=false. Independent safety audit после финального Test-All: Rust/Steam/helpers/TCP/UDP/rules/open leases/live brokers/occupied locks0, 29 closed leases. Owner3086 SHA/length unchanged, protected348 unchanged. SteamCMD, реальный updater и owner BAT не запускались; Test-All выполняет собственные stub fixtures. Чужие процессы не останавливались.

- Mojibake-маркеры в изменённых файлах проверены.
- Escaped Cyrillic в изменённых файлах проверены отдельно.

Все14 публичных exact paths прошли strict UTF-8/NUL, owner private values, credential/Steam-ID/non-loopback-IP patterns и actual run RCON secret без вывода секретов; утечек0. Публичные файлы не содержат owner cfg/data, Server/.local/artifacts в индексе отсутствуют. После closing report edits эти проверки повторяются.

Git разрешён прямым запросом и TASK013: baseline/public comparison, bounded scope/review, exact-path staging/commit и обычный fast-forward push origin/master. Команды: `git status --short`, `git status --short --untracked-files=all`, `git branch --show-current`, `git rev-parse HEAD`, `git rev-parse origin/master`, `git remote get-url origin`, `git ls-remote origin refs/heads/master` (SSH sandbox отказ), HTTPS rewrite с `ls-remote origin refs/heads/master`; `git ls-files -- docs src scripts AGENTS.md README.md .gitignore` только protected inventory; `git check-ignore Server .local artifacts`, `git ls-files -- Server/ .local/ artifacts/`, `git diff --check`, `git diff --stat --`, `git diff --numstat --` и `git diff --` трёх изменённых product paths.

Exact staging через `.local/audit/home013/Stage-Exact.ps1`: allowlist14 paths, `git diff --cached --name-only`, `git add -n -- $paths`, `git add -- $paths`, `git diff --cached --check`, `git diff --cached --stat`, `git diff --cached --no-ext-diff -- $paths`, `git ls-files -- Server/`. Commit message `fix: prove paid home door and diagnose native navigation clearance`; ordinary push command `git -c credential.interactive=false -c url.https://github.com/.insteadOf=git@github.com: push origin master`. Последующая проверка: `git rev-parse HEAD refs/remotes/origin/master`, тот же HTTPS `ls-remote origin refs/heads/master`, clean status и private tracked0. SHA/public equality/clean tree фиксируются после commit в ignored delivery.json и финальном ответе. Force/reset/rebase/clean/stash/branch/merge/broad add не использовались.
