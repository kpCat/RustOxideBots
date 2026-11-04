# RUST-BOTS-009 — результат 04.11.2026

Итог: **PARTIAL**. Durable journal, консервативное восстановление source и идемпотентный accounted craft реализованы в изолированном сценарии и проверены offline. Основная цель — сохранение истощения природных узлов через независимый restart вместе с предметами и личностью — **не доказана**. Ни GREEN_WORLD_DEPLETION, ни GREEN_CRASH_SAFE не заявляются.

**WORLD_DEPLETION=NOT_PROVEN; CRASH_ATOMIC=NOT_PROVEN; CRASH_RECOVERY=OFFLINE_ONLY.** Два live старта, оба PARTIAL; RESTORE не запускался. Успешный native quit не считается доказательством crash recovery.

## State matrix

| Контракт | Фактический уровень | Результат |
|---|---|---|
| Native actor, held rock, физический подход и gather | LIVE, первый запуск | 34.127420672 м, 11 hits, 63 wood, source debit 126, native wear |
| Native stone gather / оплаченный stonehatchet в 009 | NOT_PROVEN | 0 stones, 0 craft, 0 produced Item |
| Journal ordering/integrity | LIVE записи + OFFLINE проверки | 11 подтверждённых gather actions; последнее PREPARED блокируется как IN_DOUBT |
| Stable source incarnation | STATIC_IL + OFFLINE fail-closed policy | Exact world/save binding и native disk-loaded object witness реализованы; matching между процессами не выполнен |
| Depletion apply / второй replay NOOP / соседние pools | OFFLINE_ONLY | Реальных RESTORE receipts нет |
| Craft duplicate / interrupted stages | OFFLINE_ONLY | PREPARED, DEBITTING, DEBITED, OUTPUT_CREATED, COMMITTED; recovered intent не повторяется |
| UID/held/personality restore 009 | NOT_PROVEN | 008 lifecycle переиспользован, но новый completed JOURNEY отсутствует |
| Safety / owner / history | Проверено после двух запусков | Owner changes=0; processes/ports/rules/open leases/occupied locks=0; historical raw changes=0 |
| Code / scope | OFFLINE, исторический LIVE load | Test-All exit 0, C# 7.3 compile; v0.1.3/4 live loaded, итоговый v0.1.5 только offline; allowlist 18 файлов |

## Baseline и установленный runtime

До правок local HEAD, tracking origin/master и настоящий публичный HTTPS master совпали с **58d384e23a8200387d2574f935273c3056ab5b0a**, ветка master. В дереве были только восемь распакованных документов 009. SSH и sandbox network были недоступны; публичный ref проверен обычным HTTPS без изменения remote config. Не выполнялись reset/rebase/force/clean/stash.

Rust protocol **2635.289.1**, Unity **6000.3.15x1-13**, Oxide.Rust **2.0.7839**. Установка не обновлялась. Факты API и ограничения изложены в [API_DECISION.md](API_DECISION.md).

| Installed artifact | SHA-256 |
|---|---|
| Assembly-CSharp.dll | 04FB89520F18A1920C1B1A350B82DD24A4258F31D97B82496971A9CC7A49DCB7 |
| Rust.Data.dll | 1D62BAEF9B339F0416E6529618365C1ECAD01791A833E77E76EB6C8464406104 |
| Oxide.Rust.dll | 2128121E34B55BB1550D43E62842B87EA3720059F13DC84F97D8C7DD465C3423 |
| RustDedicated.exe | EFAC429DB737EB4B32A2BFC48029B4BE6FF475336958F4557F891F17255FFD38 |

## LIVE — фактические попытки

Все времена в таблице — UTC. Raw receipts не переписывались; дополнительно захвачены закрытые журналы неуспешных runs. Полные логи, пути firewall leases, секреты и owner inventory остаются только ignored в `.local/`.

| Run / source version | PID / старт | Readiness | Результат |
|---|---|---:|---|
| 35d435c481484edd9682260d30d11ac7 / v0.1.3 | 44744 / 11:36:59 | 268.8367123 с | PARTIAL: Native debit without inventory yield; no adapter retry |
| eeb1767d19084083a92f5778fa914b4d / v0.1.4 | 57920 / 11:47:53 | 271.7154622 с | PARTIAL: Setup: Local natural route unavailable; до первого hit |

Оба процесса unelevated, с собственным kill-on-close Job Object, проверенными inbound/outbound block rules для всех test EXE, отдельными plugin/config/data, случайными test secrets и loopback ports 28965–28968. В обоих логах реально присутствуют compilation/load RustBotsAvatarSurvival, полная readiness, RustNav, shutdown ACK и завершённый native save. GRACEFUL quit дал наблюдаемый native exit **−1**, как предусмотрено существующим runner; owned processes завершены.

WARM compatibility key: `b37a93c03ae490a52662af2f167343eda017ce450d373f43abced8fb91b58b23`. RustNav полностью built: 35344 tiles; из cache загружены 13027 tiles. Успешное сохранение test world и cache promotion не создаёт actor/journal save-proof для PARTIAL run.

| Run | Loaded generation | Loaded .sav SHA-256 |
|---|---|---|
| Первый | world-9a4d0e6491464cd8b192d479a87aef54 | D0E4B8BBFCE5B1E2D2C9128C034BC22DB78B3BF277C1EB81C009953200FA9945 |
| Второй | world-5d6302e4983046e58b2caf88a3ee12f2 | A6966D7265AC7535AE2BBEAB627FC14FCB75883A45B72526F0F310ED037F3EF5 |

Первый эпизод выявил реальный дефект admission: native pool после reload reset, но ранее повреждённый tree health сохранился. Pool-only guard 007 не гарантировал возможность собрать рецепт и оставить узел живым. NATURAL TreeEntity 6982, `assets/bundled/prefabs/autospawn/resource/v3_temp_field/birch_tiny_temp.prefab`, position `[-35.088, 7.152832, -304.476074]`, population `procmap_v3_temp_field_small`, rotation `[0, 0.8458856, 0, 0.5333645]`, scale `[0.6742678, 0.6742678, 0.6742678]`. Transient netID не объявлен постоянной identity. Journal incarnation `3b4b5dc5293d412f9e08f9281a8f7a6f` — ключ записи, а не доказательство engine identity.

| Измерение первого эпизода | До | После |
|---|---:|---:|
| Native pool wood | 375 | 249 |
| fractionRemaining | 1 | 0.664 |
| Native source health | 196.799911 | −4.800089 |
| Rock condition, UID 92220 | 100 | 96.326004 |
| Native wood, UID 94209 | 0 | 63 |

Native расход 126 = 63 credited wood + 63 native destruction; adapter credit=0, new drops=0. Последующий hit по закончившемуся дереву не дал yield; автоматического retry/компенсации не было. Дерево не подходит для доказательства same-node restart. Неповреждённое сопоставление/накладывание depletion после restart не выполнялось.

Логический actor первого эпизода: `avatar-007-7450dda36ea6446f8584243bcbf9290c`. 60 фактических samples, 2 legs; независимая сумма пути 34.127420672 м, max step 1.534252469 м, max gap 0.503579 с. Inventory перед cleanup — один исходный rock и 63 wood, без product. NPC и его test inventory штатно удалены owned cleanup; эти предметы не заявляются сохранёнными между рестартами.

После дополнительного native IL исследования v0.1.4 учитывает health/pool capacity, native destroyFraction, rounding reserve и maximum gatherScale ×3. Focused regression на фактическом классе ошибки и ore bonus counterexample прошёл RED → GREEN. Source journal теперь включает только действительно затронутые узлы: untouched discovery не считается depletion.

Во втором запуске выбран NATURAL beech 7210, prefab `assets/bundled/prefabs/autospawn/resource/v3_temp_forest/american_beech_a.prefab`, position `[24.4471684, 8.436977, -222.981354]`, pool 500. Существующий StartLeg не нашёл допустимую локальную точку маршрута и остановился до hit: travel=0, harvests=0, source records=0, craft=null. Нет оснований объявлять admission исправленным LIVE до завершения игрового эпизода.

Третий старт **не использован**. Первый дефект обосновывал исключительный бюджет на новую пару JOURNEY + RESTORE, но второй маршрутный отказ оставил только один старт и ни одного допустимого completed JOURNEY. Обходить provenance gate, восстанавливать незавершённый intent или запускать заведомо недоказательную серию серверов не стали. Navigation fix и новая полная пара E2E остаются необходимыми для достижения основного outcome; следующий Goal не начинался.

## Journal / recovery / negatives

Первый реальный journal: **35 entries** = header + 11 × (PREPARED/APPLIED/COMMITTED) + последнее PREPARED. SHA-256 **5AB44FD8348F5BFB422F138BF4CDA0F9DC8A226BAD3007CF45B7D87746B3121E**. Actual helper и независимый parser классифицируют его **IN_DOUBT** и отказывают completed recovery. Аудит не изменил bytes/hash. Это quarantined evidence, а не завершённая recoverable economy.

Schema/sequence/hash chain, exclusive writer, Flush(true), complete-tail и world/actor/recipe binding реально используются плагином. COMMITTED записывается после проверенного source debit/credit/wear или exact craft payment/output. Любой recovered incomplete intent и любой повтор committed intent блокируются; restore не создаёт предмет по намерению. Native source/inventory/save и journal остаются разными системами, общей crash-atomic transaction нет.

Focused OFFLINE_ONLY проверки используют настоящий helper и durable files: five craft interruption checkpoints, duplicate intent, concurrent writer, empty/truncated/corrupt journal, wrong world/generation/actor/recipe, reset/NOOP, missing/ambiguous/new-respawn witness, unexpected lower/partial pool, wrong source prefab/position, wrong output UID, geometry/health mismatch и nonfinite telemetry. Отказы защищают нулевое исполнение/retry в этих contracts; они не являются живыми Rust Item/payment fault experiments. Не было реального interrupted-process recovery, live craft, live replay или физической проверки соседних pools.

Независимое prelive code review закрыло staged ore health reset и Windows writer/read sharing; дополнительно усилены finite measurements и source geometry receipts. Reviewer воспроизвёл NaN gap в PowerShell 7; исходный PS5.1 вариант не объявлен наблюдённым RED. После первого live root cause reviewer дал конкретный ore ×3 counterexample; он наблюдался RED и закрыт до второго запуска. Финальное независимое raw-ledger review подтвердило PARTIAL, conservation, actual source hash и отсутствие необъяснимых awards/cleanup anomalies.

## Проверки и сохранность

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-All.ps1` — **exit 0** после v0.1.4 admission исправления, до второго live; повторён после обязательного map-identity дополнения v0.1.5. Включены прежние regression suites, focused economy/map contracts и C# 7.3 compile всех пяти plugins против installed DLL. Live captured v0.1.4 — source + реально подключённый BCL helper — SHA **305CE45592CCBC2CB3219B94CA6BBFD83C713729FB8F605913660E9C52DBB354**. v0.1.3 capture первого run: **09EADBC7F7D1DC6ED6E8686077DB55D65E82F3F57AC2482AB1FBBF49DC651CB4**. Итоговый v0.1.5 изменён после этих запусков по обязательному дополнению владельца; совпадение с live capture и live compilation для него не заявляются.

Финальный safety audit 11:53:40 UTC: Rust/SteamCMD/helper processes=0, TCP/UDP test endpoints=0, firewall rules=0, live brokers=0, open leases=0, occupied locks=0; все 17 исторических/new leases закрыты. Owner **Server/: 3086 файлов, SHA/length changes=0**. 22 исторических raw-файла 007–008 unchanged; source 001/003/004/006 unchanged. SteamCMD, updater, BAT, обновление Rust/Oxide и owner runtime не запускались и не изменялись.

- mojibake-маркеры в изменённых файлах проверены;
- escaped Cyrillic в изменённых файлах проверены.

Отдельный public audit проверяет strict UTF-8/NUL, обе encoding-проверки, owner values, credentials/Steam IDs, RCON secrets обоих runs и non-loopback IP. Server/, .local/ и artifacts/ остаются ignored, Server/ tracked files=0. Raw/секреты не входят в public allowlist.

## Обязательное дополнение: любые совместимые карты

После первого PARTIAL delivery владелец уточнил обязательную map-independent архитектуру. v0.1.5 разделяет стабильную identity карты/мира и состояние save. Динамические World.Name/Procedural/Seed/Size, native map file и numeric format берутся из подтверждённого API; содержимое реальной .map хешируется один раз. MapKey включает kind/level/seed/size/format/map SHA, WorldKey — MapKey + persistent native wipe GUID. Изменяющийся SHA .sav, cache key/generation, URL и transient Entity ID не используются как постоянная identity мира.

Journal/state разделены по WorldKey directories. При новой карте, seed/size/version или wipe прежние данные остаются изолированными; автоматического переноса/replay нет. Неизвестная identity останавливает работу до Load/debit. Strict exact save/generation/hash proof остаётся отдельным gate состояния. Runtime discovery ресурсов/навигации не содержит координат или seed тестовой карты; фиксированные 424242/2000 остаются только параметрами существующего безопасного test runner.

Для последовательных обычных RESTORE разрешён новый completed checkpoint без повторного craft. Original source/payment journal не меняется; native health следующего save хранится отдельно от health входного checkpoint, особенно для staged ore. Независимое review поймало смешение входного и выходного health в receipts; реалистичный regression 80 → native 100 → output checkpoint 100 наблюдался RED и закрыт до финального Test-All.

OFFLINE tests реально проверяют committed-intent reopen для той же карты/wipe при другом отдельном save proof, отказ при изменении level/map hash/seed/size/format/kind/wipe, различие namespaces и неизменный SHA старого журнала после cross-world отказов. Проверены procedural и custom descriptors, включая смену содержимого custom map. **MULTI_MAP_E2E=NOT_CONDUCTED; v0.1.5 LIVE=NOT_PROVEN; повторная цепочка native RESTORE=NOT_PROVEN.** Дополнительных live запусков или генерации второй карты не было. Эти архитектурные проверки не меняют общий PARTIAL и не доказывают работу игры на всех картах.

Итоговый v0.1.5 source + helper SHA-256: **7E02414624A3D8FC14FD3F8BE1FDC3CB927707D2A4DEBD40033FB6D3A711FBE6**. Финальный Test-All после input/output checkpoint исправления — exit 0; public audit повторно проверил все 18 файлов и оба live RCON secrets, исторический capture сохранён. Runtime .map hashing выполняется однократно перед созданием actor.

## Scope и Git delivery

Bounded exception: **18 exact public paths** из [PLAN.md](PLAN.md): восемь supplied docs 009, PLAN/API_DECISION/RESULT, helper/plugin и пять scripts. Никаких старых task-результатов задним числом не изменено. No new dependency/project/UI/updater/owner file.

Git прямо разрешён TASK и пользователем. Использованы inspection: `git branch --show-current`, `git rev-parse HEAD`, `git rev-parse origin/master`, `git status --short`, `git remote -v`, `git ls-remote origin refs/heads/master`, `git ls-files Server`, `git check-ignore Server/ .local/ artifacts/`; HTTPS fallback `git -c credential.interactive=false -c url.https://github.com/.insteadOf=git@github.com: ls-remote origin refs/heads/master`. Exact review: `git diff --stat -- <exact code paths>`, `git diff --check`; reviewer использовал только `git diff --stat` и `git diff --no-ext-diff --unified=6` для разрешённых code paths.

Final scope/delivery commands: `git status --short --untracked-files=all`, `git add -n -- $paths`, `git add -- $paths` с массивом ровно 18 allowlist paths; `git diff --cached --name-only`, `git diff --cached --check`, `git diff --cached --stat`, `git diff --cached --no-ext-diff -- $paths`; `git commit -m 'feat: add guarded world economy journal and recovery probe'`; обычный `git -c credential.interactive=false -c url.https://github.com/.insteadOf=git@github.com: push origin master`; затем HTTPS ls-remote, `git rev-parse HEAD origin/master`, `git status --short`, `git ls-files -- Server/`. Ни force, ни broad add, ни history rewrite не используются.

Первый PARTIAL commit **a5f7413ae9440b99072576c8a006d88f209286a9** обычным push опубликован в master; HEAD/tracking/public ref перед map-дополнением совпали. Дополнение коммитится тем же exact-path процессом, message `fix: separate map identity from economy save checkpoints`; bounded diff выполняется против a5f7413 для review и против исходного 58d384e для cumulative 18-path guard. Финальный commit/ref SHA и remote equality записываются после commit в ignored `.local/audit/economy009/delivery.json` и сообщаются в финальном ответе: commit не может содержать собственный SHA. Доставка PARTIAL означает публикацию честного bounded результата; она не меняет outcome на GREEN.
