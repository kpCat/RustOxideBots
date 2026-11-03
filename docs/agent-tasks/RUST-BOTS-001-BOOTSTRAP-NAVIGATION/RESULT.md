# RUST-BOTS-001-BOOTSTRAP-NAVIGATION v2 — RESULT

## Актуальный результат продолжения от 03.11.2026: GREEN

Два настоящих E2E выполнены агентом самостоятельно: отдельный RustDedicated без повышения Windows-прав, подтверждённые block-правила через UAC-helper, live Oxide compilation, один Scientist2, три динамические complete-path цели и более 92 м фактического движения в каждом запуске. Оба сервера штатно завершены; финальные Rust/SteamCMD PID, TCP/UDP endpoints и собственные firewall rules — 0. Rust/Oxide/SteamCMD не обновлялись. Задача 002 не запускалась.

| Запуск | Ready по result.json | NPC / legs | Фактический путь | Shutdown / cache |
|---|---:|---:|---:|---|
| Предоставленный владельцем `fc3ce0bee5e14e958e30289ad61929c8` | 342.65 s | 0 / 0 | 0 м | GRACEFUL, исходный BLOCKED сохранён |
| Первый самостоятельный `88436ae68e38489dbc15252303353fc2`, PID 37284 | 268.51 s | 1 / 3 | 92.20833 м | GRACEFUL; внешний lease закрыт отдельным receipt |
| Контрольный `b0bd803ae7854a309af9f8ed000731da`, PID 48800 | 264.44 s | 1 / 3 | 92.2068253 м | GRACEFUL, PortsReleased=true, FirewallRemoved=true, Cache.Promoted=true |

Последний runner был Windows PowerShell 5.1, `RunnerElevated=false`; первый — PowerShell 7, также false. Параметр Codex sandbox escalation не использовался как доказательство Windows elevation. Только helper имел проверенный Administrator token и делал firewall-операции; CreateProcess игрового сервера выполнялся обычным runner с атомарным включением в собственный kill-on-close Job Object. Команды запуска/остановки владелец не выполнял.

Runtime: Rust Steam app manifest buildid **26139947**, живой лог `Protocol: 2635.289.1`, Oxide.Rust **2.0.7839**, плагин **0.2.0**. SHA игровых DLL/EXE из исходной поставки ниже остались прежними; Unity FileVersion не выдаётся за Rust build number.

### Причина прежнего отказа и исправление

Установленная DLL показывает: `RustNavigation.IsDefaultNavmeshBuilt()` вызывает `RustNavmesh.IsBuilt()`, который сравнивает numBuiltTiles с полной длиной tiles; RustNavMeshAgent также не привязывается к default mesh до этого условия. Старый SampleInitial возвращал false до геометрических проверок, если вся сетка ещё не готова. В предоставленном запуске после готовности сервера сохранялось 14 837 pending tiles; это согласуется с ранним отказом всех 169 кандидатов. В самостоятельном запуске новая диагностика непосредственно зафиксировала **21461/35344** и затем **28720/35344** при `IsBuilt=false`. После полной готовности первая проверенная точка сразу принята.

Проба теперь ограниченно ждёт сетку, выводит built/total и отличает этот блокер от sample miss, отсутствия ground ray hit, перепада nav/ground, поверхности над terrain, уклона, воды, capsule obstacle и неполного маршрута. Для каждой причины — счётчик и до трёх примеров с координатами, terrain/ground/nav height и collider type/name/layer. В двух успешных пробах RejectedSamples=0, поэтому примеров отвергнутых точек в этих запусках нет; они не выдуманы.

Убран абсолютный `p.y < 3`; вода проверяется относительно WaterLevel. Поиск Halton покрывает 90% размера карты, вместо прежней центральной сетки. Высота и capsule проверяются относительно фактического ground hit; структуры/скалы над terrain и занятое пространство отвергаются. До рождения проверяется complete departure path. Предпочтён обычный Gen2 Scientist2 вместо Heavy; height=2.0, capsule radius=0.45, agentType=0, areaMask=25. Сам по себе переход на более мягкие геометрические допуски не объявляется доказанной причиной старого отказа.

Фактический NPC: `Rust.Ai.Gen2.ScientistNPC2`, prefab `Assets/Rust.Ai/Agents/NPCPlayer/HumanNPC/Scientist/Gen2/Scientist2.prefab`, FSM `Rust.Ai.Gen2.Scientist2FSM`, brain=null, агент `Rust.Ai.Gen2.RustNavMeshAgent`, backend **RustNav**. Gen2 scientist не BasePlayer и не живое Steam-соединение. Плагин использует штатный агент, отключая конкурирующее поведение FSM только собственного NPC.

### Живые метрики контрольного запуска

| Leg | Start → target → end (x,y,z; округлено) | elapsed | traveled / net | status, stuck/repath |
|---|---|---:|---:|---|
| 1 | (0,5.449,-300) → (32,5.348,-300) → (30.468,5.592,-300) | 10.476 s | 30.50128 / 30.4685 м | ARRIVED / PathComplete, 0/0 |
| 2 | (30.468,5.592,-300) → (40.886,8.605,-269.743) → (40.438,8.610,-271.046) | 10.501 s | 30.94933 / 30.77066 м | ARRIVED / PathComplete, 0/0 |
| 3 | (40.438,8.610,-271.046) → (15.221,7.100,-251.345) → (16.324,7.092,-252.206) | 10.500 s | 30.75621 / 30.63828 м | ARRIVED / PathComplete, 0/0 |

Итого 92.2068253 м; каждый net >20 м. Независимая реконструкция из 63 raw RUSTBOTS_SAMPLE дала 92.206827 м. Для первой пробы 64 samples дали 92.208317 м против plugin total 92.20833. Допуск расхождения менее 0.001 м связан с float/JSON. В каждом логе ровно один RUSTBOTS_NPC. Телепортаций/ручного изменения координат в исходнике нет; после рождения движение выполняется SetDestination штатного агента. Discontinuity/stuck watchdog не сработал. Это не доказывает длительные путешествия, обход домов, монументы, farming/crafting/PvP или масштаб 50–100.

### Проверенный постоянный тестовый кеш

Ключ контрольного кеша: `b37a93c03ae490a52662af2f167343eda017ce450d373f43abced8fb91b58b23`, identity `rustbots_probe_b37a93c03ae490a52662af2f`. Он связывает Rust/Oxide/compiler/native/Unity fingerprints, размер/seed/level/backend и инвентарь Bundles. Ключ использует ordinal primitives; найденное различие culture sorting PowerShell 5.1/7 воспроизведено focused regression test и устранено.

Копия runtime создаётся в staging, полный инвентарь файлов проверяется SHA-256, затем выполняется promotion. При отсутствии/повреждении manifest/runtime установка карантинируется и пересоздаётся. Map/sav/navmesh/occlusion копируются физически только после проверки всех world hashes; configs/DB/Oxide/логи не входят в world snapshot. Повреждённый world manifest отвергается до копирования, и новый тестовый мир может быть безопасно создан. Ни hardlink/junction, ни owner world/cache/configs не используются. Для каждого запуска writable Oxide/cfg/data и временное состояние свежие; исторические тестовые архивы сохраняются локально.

Оба agent run использовали WARM map cache, затем второй получил полный RustNav первого. В контрольном логе — загрузка **13027 data tiles**, default mesh **35344/35344**, 124.1978 ms загрузки, без холодных Terrain Erosion/Harbors/Cliffs generation phases. Processing World: **0.5 s**, против **75.5 s** в предоставленном холодном запуске (первая тёплая проба — 0.6 s). SHA-256 .map всех трёх запусков одинаков: `1F09D94EC8DA9DAC4E32908817A16BCC167D7B5A654E90DB19042E1501F17A47`. Одна общая строка «Generating procedural map» всё ещё печатается движком и не использовалась как признак регенерации.

Второй quit сохранил RustNav с **0 pending tiles**. Cache.Promoted=true; итоговый snapshot затем отдельно восстановлен в ignored proof directory и все его хеши проверены. Полный cached install также повторно проверен по manifest. Третьего игрового запуска ради этой проверки не было. Оставшаяся задержка между полной загрузкой default mesh (~22.76 s от старта) и ready (~264.44 s) по этой телеметрии не разложена полностью; сетевые ошибки при изоляции ожидаемы, доступ наружу ради ускорения/чистоты лога не открывался.

### Делегирование, shutdown, encoding и сохранность

Короткий UAC broker ограничен `.local/probe-cache/<key>/install`, проверяет plain paths и ActiveStore, создаёт только Block Inbound/Outbound для EXE этого test root. Runner читает точные правила через firewall COM. Reservation удерживается от финальной проверки до окончания owned job; closing marker и exclusive lock запрещают новый старт и снятие правил в опасном окне. Ошибка ready/start запрашивает cleanup и не выдаёт недоказанный FirewallRemoved=true. Внешний lease допускает несколько попыток на одной установке до часа; завершение controller/expiry ведёт к безопасному закрытию, при живом процессе denial сохраняется.

Установленный `ConVar.Global.quit` сначала вызывает ServerMgr.Shutdown, затем Process.Kill. Поэтому наблюдаемый exit **−1** при ACK/законченном save не был заменён на 0 и не принят за crash без исследования. Cache promotion требует ACK, completed native/world save, подтверждённый exit/absence и явный разрешённый 0/−1. В контрольном запуске это условие выполнено; никакого принудительного stop runner после timeout не потребовалось. Owned Job Object затем закрыт для всех дочерних процессов.

Финальные проверки вне sandbox: RustDedicated/RustClient/Rust/SteamCMD **0**, endpoints 28965–28968 TCP **0**, UDP **0**, правила `RustBots001-*` **0**. Helper обоих запусков завершён. Контрольный closed.json: Removed=true, RemainingProcesses=0, `2026-11-03T11:31:50.0246527Z`. Первый result.json сохранил FirewallRemoved=false на момент окончания его внешнего lease; последующее удаление подтверждено отдельным `.local/probe-firewall/52e7d9bced32431f889e196f1e30a6bf/closed.json` и нулевым COM inventory. Автоматический reviewer отклонил попытку вручную обновить старое поле; safer alternative сохранила raw отчёт без изменений и использовала отдельный receipt. Сам E2E был разрешён и выполнен отдельной командой.

Исходные server.log строго декодируются как **UTF-8 без BOM**. Во всех трёх логах replacement/box-drawing chars **0**; русские сообщения целы. Искажение консоли соответствует неверной OEM-интерпретации UTF-8. Теперь producer/consumer явно UTF-8: Console.InputEncoding/OutputEncoding, PowerShell OutputEncoding и строгий StreamReader с BOM detection. Source теста с кириллицей — UTF-8 BOM для Windows PowerShell 5.1. Отдельно проверены русско-украинский log round trip и реальные UTF-8 stdout bytes дочернего PowerShell. IO retries пишут warning; полный текст исключений и сетевых ошибок сохраняется, логирование не отключалось.

397 исходных owner файлов по прежнему fingerprint байтово неизменны. BAT hashes прежние; реальные BAT и SteamCMD не вызывались. Рабочая копия нашего плагина 0.2 обновлена после проверки исходного hash и бэкапа: `Server/backups/RUST-BOTS-001/plugin-20261103-133234/RustBotsNavigationProbe.cs`, old SHA `53844F0E3636CDCBDEEDFB37AB6DFA828AD135D71A7E875B803585B348BF078D`. Source, реально испытанная копия и новая owner-копия имеют SHA `ED4918A5FBDD5EEC04E6813D7C1D7CEB6F3442CE7853D0F485C8300F540886DD`. Она инертна вне test environment. Owner configs, мир и сторонние плагины не менялись.

### Tests, scope и публикация продолжения

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-All.ps1` — **PASS**, включая BAT stubs, чужой процесс, owned job/abrupt controller exit, log sharing/UTF-8 console, junctions, native telemetry validator, key PS5/7 consistency, incomplete/corrupt cache, native quit −1/complete-save gate и firewall close reservation. Негативные fixtures намеренно печатают BLOCKED/corruption warnings; это ожидаемые отказы, а не ошибки live E2E. Offline C# 7.3 compilation также PASS; live Oxide compilation подтверждена отдельно двумя game logs. Сырые logs/results/tests/receipts остаются только в `.local/`.

Exact allowlist продолжения — 12 публичных файлов:

```text
README.md
docs/agent-tasks/RUST-BOTS-001-BOOTSTRAP-NAVIGATION/PLAN.md
docs/agent-tasks/RUST-BOTS-001-BOOTSTRAP-NAVIGATION/RESULT.md
scripts/Invoke-NavigationProbe.ps1
scripts/ProbeSafety.ps1
scripts/ProbeCache.ps1
scripts/ProbeFirewall.ps1
scripts/Test-All.ps1
scripts/Test-ProbeSafety.ps1
scripts/Test-ProbeCache.ps1
scripts/Test-ProbeFirewall.ps1
src/plugins/RustBotsNavigationProbe.cs
```

Git разрешён прямым запросом владельца. Base SHA продолжения: `0f27566a612213f4f7f094a9411fa5ac1f6875d0`. Использованы read-only `git status --short`, `git rev-parse HEAD`, `git diff --stat`; перед публикацией — `git diff --check`, `git check-ignore -v Server/Run_DS.bat Server/update.bat Server/rustds/oxide/plugins/RustBotsNavigationProbe.cs`, `git status --ignored --short`, `git add -n -- $paths`, `git add -- $paths` строго с allowlist выше, `git diff --cached --name-only`, `git diff --cached --check`, `git diff --cached --stat`, `git diff --cached --no-ext-diff --`, `git ls-files -- Server/`, `git commit -m "fix: verify RustNav readiness and reuse isolated E2E cache"`, обычный `git -c credential.interactive=false -c url.https://github.com/.insteadOf=git@github.com: push origin master` и такой же HTTPS-mapped `ls-remote origin refs/heads/master`, затем rev-parse/status. Remote не меняется, force/history operations отсутствуют. Final SHA и remote/status receipt — в финальном ответе и новом ignored `.local/audit/resume-delivery.json`; versioned файл не может содержать SHA собственного коммита.

- mojibake-маркеры в изменённых файлах проверены: 12 публичных файлов, совпадений нет; raw UTF-8 logs дополнительно проверены на OEM box-drawing/replacement chars.
- escaped Cyrillic в изменённых файлах проверены: отдельная Unicode/XML escaped Cyrillic проверка 12 файлов, совпадений нет.

Ограничение хранения: старые test evidence/state archives и поколения кеша сохраняются для диагностики и расходуют диск; broad cleanup намеренно не смешан с навигационной задачей. Фундаментального блокера навигации после исправлений нет. Остальные обещания/статусы ниже относятся к прежней поставке и сохранены как история.

## Исторический отчёт предыдущей поставки (до предоставленного live E2E)

Дата: 03.11.2026. Итог: **BLOCKED**. Безопасная статическая часть, локальные BAT и focused tests выполнены. Навигационный E2E **не состоялся**: текущий Windows token не Administrator; создание отключённого per-program firewall capability rule получило `Отказано в доступе`. Ограничение сети не ослаблялось, сервер не запускался.

| Проверка | Фактический результат |
|---|---|
| Изоляция Git | `/Server/`, `.local/`, artifacts и секреты исключены; фактические пути проверены check-ignore |
| Локальные BAT | Исправлены после проверенных бэкапов; игровые аргументы сохранены буквально |
| Stub/contract tests | PASS; настоящий RustDedicated, updater и SteamCMD не вызывались |
| Offline C# compile | PASS, C# 7.3 против установленных DLL; не доказательство live Oxide compilation |
| Собственный игровой PID / full starts | Нет / 0 |
| Readiness / Oxide+plugin live load | NOT_VERIFIED |
| NPC / переходы / реальные метры | Не создавался / NOT_VERIFIED / NOT_VERIFIED |
| Game graceful shutdown | NOT_VERIFIED, игровой процесс не был создан |
| Финальные Rust/SteamCMD процессы | 0 по Win32_Process вне sandbox |
| Тестовые TCP / UDP endpoints | 0 / 0, порты 28965–28968 |
| Owner preservation | 397 исходных файлов проверены SHA-256; изменений 0; добавлена только явно запрошенная инертная рабочая копия собственного плагина |
| Commit / push | Реализация `01b325e95c5cb216e25917259efd8559d2d445a4` опубликована обычным push; final docs receipt — в финальном ответе |

## Baseline и установленный runtime

Работа выполнена в существующем checkout `D:/Codex/repos/RustOxideBots`, ветка master. Baseline HEAD и публичный origin/master совпали: `daa38dbfad1716db3978c90d1870f8c3064c1a4d`. В начале README был единственным tracked-файлом; Server/ и поставленный пакет docs были untracked. AGENTS.md в root/предках, code-map/pattern-файлы, csproj/props/targets отсутствовали. Прочитаны README, весь пакет задачи v2, реальные BAT/runscript, два локальных аналога Oxide-плагинов, актуальные DLL и исторический output. Чужие Rust/server/client/SteamCMD процессы в baseline не обнаружены.

Основной runtime находится в `Server/rustds/`. Инвентаризированы `oxide/plugins`, `oxide/config`, `oxide/data`, `server`, `cfg`, `config`, `HarmonyMods`, root EXE и Managed DLL. Их конфигурация не публикуется. Рабочий каталог исходного launcher был относительным; новая версия привязана к своему каталогу. У исходного launcher есть batchmode и относительный logfile; параметры hostname, identity, seed, worldsize, maxplayers и порта сохранены, но намеренно не раскрываются. Явного level/SteamCMD в исходном launcher не было. Runscript использует anonymous login, приложение 258550 с `validate`; отдельная beta-ветка не задана. Runscript и loadMod не изменялись и не исполнялись.

| Файл | Версия / SHA-256 |
|---|---|
| RustDedicated.exe | FileVersion `6000.3.15.11082995` — версия Unity player, не Rust build ID; `EFAC429DB737EB4B32A2BFC48029B4BE6FF475336958F4557F891F17255FFD38` |
| Assembly-CSharp.dll | Assembly/FileVersion `0.0.0.0`; `04FB89520F18A1920C1B1A350B82DD24A4258F31D97B82496971A9CC7A49DCB7` |
| Oxide.Rust.dll | `2.0.7839.0`; `2128121E34B55BB1550D43E62842B87EA3720059F13DC84F97D8C7DD465C3423` |

Текущая исполняемая версия Rust build/protocol и активный backend: **NOT_VERIFIED**, поскольку сервер не стартовал. Исторический output содержит Oxide.Rust 2.0.7286 и прежнюю карту protocol 283; он относится к другой сборке и не выдаётся за лог текущего E2E.

Инвентарь 18 текущих source-плагинов (имя — версия из `[Info]`): AdminDeepCover 2.2.8; AdminRadar 5.4.1; Arkan 1.0.21; BuildingActions 1.1.2; BuildingWorkbench 1.4.1; BypassQueue 1.0.4; EasySkin 1.0.0; GatherManager 2.2.78; ItemSkinRandomizer 1.6.3; LootMultiplier 1.3.4; NoGiveNotices 0.3.0; NoGreen 1.3.10; ObjectRemover 3.0.5; PrefabSniffer 2.0.2; QuickSmelt 5.1.5; RecyclerSpeed 2.0.2; StackSizeController 4.1.3; TimeOfDay 2.3.4. Для каждого текущая live-загрузка **NOT_VERIFIED**. В просмотренном историческом startup все они отмечены loaded; прежний MonumentAssault также встречается в логе, но отсутствует среди текущих source. Не переносился. Тот лог содержит ошибки создания agent вне NavMesh, GPU/shader warnings и отключение RCON из-за слабого пароля; реальные настройки в отчёт не переносились. Ошибок, доказывающих необходимость обновления именно текущих 18 плагинов на установленной сборке, не установлено; возраст файла не использовался как критерий. Ничего не удалялось/обновлялось.

## Карта и медленный старт

В owner identity найдены существующие map/sav; текущая пара имён согласуется с размером/seed исходного BAT. Map timestamp 23.04.2026, sav 26.04.2026, присутствуют старые sav других protocol/параметров. Имена с seed/identity не публикуются. Файлы не переименовывались и не удалялись; хеши сохранены в локальном fingerprint.

Исторические измерения из output, **не новый startup timeline**:

| Фаза | Длительность в историческом логе |
|---|---:|
| Managed assemblies | 13.555 s |
| Loading World | 0.5 s |
| Spawning World | 6.7 s |
| Terrain Mesh | 1.3 s |
| Train Track Collation | 1.7 s |
| Processing World | 3.3 s |
| Ocean Patrol Paths | 17.3 s |
| Finalizing World | 1.2 s |
| Navmesh source collection | 9.46 s |
| Main Navmesh build | 24.71 s |
| Отдельные monument Navmesh builds | Есть, в том числе 12.33 s и 16.26 s |

Порядок исторического startup: assemblies/assets/config → Oxide/extensions → plugins → сообщение procedural map → world phases → NavMesh → загрузка entity/plugin init → `Server startup complete`. Записи не имеют достаточных абсолютных timestamps для измерения process start → Oxide/plugins/ready. Эти интервалы **NOT_VERIFIED**. Видны существенные затраты NavMesh/world processing; безусловный BAT restart объясняет возможность нового полного старта после каждого quit. Наличие строки «Generating procedural map» не доказывает повторную генерацию; нет двух контролируемых запусков одной identity и сравнения cache до/после. Owner maps не трогались ради проверки.

Runner создаёт собственную новую карту с искусственными параметрами; owner .map/.sav и NavMesh cache не использует. Разовая генерация этой копии ожидаема. Повторное использование test cache в 001 не проверено.

## BAT: резервные копии и поведение

Локальный каталог бэкапов: `Server/backups/RUST-BOTS-001/20261103-112447-760/`. Содержит оригинальные Run_DS.bat, update.bat и hashes.json. Сам каталог и реальные BAT в Git не попадают.

| Файл | SHA-256 оригинала / бэкапа | SHA-256 исправленного файла |
|---|---|---|
| Run_DS.bat | `3540C34C00B8E350D54B4C78521F178650C17087D2B2BAF0B1EFD93D8798B668` | `3B070BAA8F32B9298AD5C46AA099433D689967C46DC8D4E6E180616462B8F7AE` |
| update.bat | `2DA69DDEE5E71ACA3E513780DCBE84BA06DAC6B4A92C1DE93760EDCEA750AA63` | `38397864DA83B1DD5B7C581554FE79D6A859BBDA431353B66A40C972C3381BE4` |

Безопасный behavioral diff: Run_DS использует `%~dp0rustds`, проверяет каталог/exe, выполняет ровно один запуск, возвращает exit code. `goto start` удалён, SteamCMD отсутствует. Точная строка всех исходных игровых аргументов сравнена программно: сохранена. Update использует `%~dp0`, проверяет SteamCMD/runscript/Oxide-package и возвращает 2/3/4 либо 78. Даже наличие ZIP не разрешает запуск: совместимость и восстановление не доказаны. Рабочего update→restore workflow в 001 нет; он сознательно fail-closed до отдельной задачи, как разрешено TASK C2.

Tests исполняют только копии обезличенных шаблонов в `.local/tests/` с собственными stub EXE. Проверены foreign cwd и пробелы, единственный запуск с 0, сохранение кода 17, все отказы updater и ноль вызовов SteamCMD stub. Дополнительная regression-проверка hardener защищает существующий посторонний `.bat.new`; новые временные файлы уникальны и создаются через CreateNew. Реальные BAT, SteamCMD, update/validate не запускались.

Инструкция владельцу: обычный запуск исправленного локального Run_DS завершается после штатного выхода сервера; для нового старта запустите BAT снова. Обновление намеренно заблокировано. Подробный будущий update/backup/Oxide-restore gate описан в README. Для возврата оригиналов вручную при остановленном сервере скопируйте ровно два BAT из указанного бэкапа поверх соответствующих локальных файлов; это вернёт и старый нежелательный restart loop. Не восстанавливайте весь Server/ и не меняйте мир/конфиги.

## Runner, API и навигация

Команда: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-NavigationProbe.ps1`.

Фактический последний самостоятельный preflight: `.local/runtime/0269e88ebc7c49fab38bffcdabad059a/result.json`. Status BLOCKED, ServerPid null, Shutdown NOT_STARTED, OwnedProcessAbsent true, Navigation NOT_VERIFIED. До копирования runtime и создания игровых процессов gate требует работающее per-executable firewall isolation. Windows token не Administrator; отдельная попытка создать отключённое правило для несуществующего тестового EXE получила AccessDenied. Независимое перечисление firewall rules также запрещено Windows; inventory правил **NOT_VERIFIED**, успешного создания правил этой задачей не было. Небезопасный обход отсутствует.

Предусмотренная E2E-установка — новая физическая копия `.local/runtime/<id>/install`; owner cfg/config/oxide/server не копируются. Выбранные roots и файлы проверяются на reparse points до обхода; writable Oxide-каталоги создаются заново, root/ancestors проверяются. Источник — `src/plugins/RustBotsNavigationProbe.cs`; test deployment выполняется runner только после gate. По последующему прямому указанию владельца добавлена также рабочая копия в `Server/rustds/oxide/plugins/RustBotsNavigationProbe.cs` через CreateNew без overwrite. SHA-256 source/copy совпал: `53844F0E3636CDCBDEEDFB37AB6DFA828AD135D71A7E875B803585B348BF078D`. Без marker/environment/identity runner она инертна. Для E2E эта owner-копия не используется; отдельный writable root остаётся обязательным. Игровой сервер после установки копии не запускался.

Метаданные текущих DLL прочитаны без загрузки/исполнения игрового кода. Сопоставлены старые NPCPlayer→BasePlayer и ScientistNPC→HumanNPC с Gen2 ScientistNPC2→BaseNPC2→BaseCombatEntity. Подтверждены RustNavMeshAgent.SamplePosition/CalculatePath/SetDestination, RustNavMeshPath.status/GetPathLength, FSMComponent.SetFsmActive и RustNavigation.DefaultNavmesh. Методы sample/path выбираются по фактическому `ConVar.AI.useUnityNavmesh`; один Unity SamplePosition не считается доказательством RustNav. Compile references учитывают blacklist установленного CSharpPluginLoader: standalone Newtonsoft/protobuf/websocket исключены в пользу Oxide.References.

Плагин выбирает доступный humanoid prefab из установленного manifest, предпочитает Gen2; конкретный prefab/NPC/brain/agent и backend выводятся только при live run. Gen2 scientist не BasePlayer и не предоставляет эквивалент полноценного игрока; старый NPCPlayer является BasePlayer, но живого Steam-соединения не создаёт. Что реально активно для выбранного NPC, **NOT_VERIFIED**.

Реализованы terrain/navmesh/height/clearance checks, один spawn, три динамических complete-path цели, штатный nav agent, координатные samples, elapsed/path/stuck/repath, отказ при разрыве измерений/скачке, один bounded repath и timeout. После рождения телепортаций/ручного MovePosition в plugin source нет. Runner отдельно проверяет пороги и согласованность GREEN метрик. Unit-test fixtures являются только contract inputs и не публикуются как live телеметрия.

Фактических sample/path/stuck/arrived сообщений игрового NPC нет; spawn attempts 0, navigation attempts 0, успешные/неуспешные live legs не измерялись. Статическая компиляция успешна, **live Oxide compilation NOT_VERIFIED**. Нельзя утверждать движение по карте/монументам, обход домов, player behavior или масштаб 50–100 NPC. Фарм, крафт, PvP, строительство не добавлялись.

## Проверки и shutdown

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-All.ps1` — PASS. Сводка: все PowerShell-файлы разбираются; BAT/hardener fixtures, foreign-process gate, shared writable log, junction rejection, GREEN evidence validation, exception/abrupt-controller cleanup и offline C# compile прошли. Статический/fixture успех не меняет статус E2E.

OwnedServerProcess использует Windows 10+ PROC_THREAD_ATTRIBUTE_JOB_LIST при CreateProcess, hidden/suspended start и kill-on-close. Назначение Job Object атомарно, до исполнения child. Бounded quit→wait→close касается только собственного job/handle, не поиска процессов по имени. Тесты с отдельными sleeping fixtures показали завершение собственного child после исключения и после принудительного выхода контроллера, при этом посторонний fixture остался жив. Все созданные fixtures затем остановлены по сохранённым handles. Windows API проверен по [Microsoft](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-updateprocthreadattribute).

Финальный Win32_Process: RustDedicated/RustClient/Rust/SteamCMD = 0. Финальные TCP/UDP endpoints 28965–28968 = 0/0. Полного game shutdown evidence нет, поскольку game PID не существовал. При будущем live-run команда quit передаётся test-only plugin через локальный marker-scoped файл; без загрузившегося plugin может понадобиться forced owned-job stop. Это ограничение явно сохранено.

Owner fingerprint включает server worlds/maps/saves, все oxide files, cfg/config/HarmonyMods, ключевые game/Oxide binaries и неизменяемые BAT/runscript: 397 файлов, 0 изменённых. Разрешённые два BAT исключены из fingerprint и проверены отдельно по аргументам/backup hashes. Все raw отчёты остаются в `.local/audit/` и `.local/runtime/`, а бэкапы — в игнорируемом Server/.

- mojibake-маркеры в изменённых файлах проверены: 27 файлов, совпадений нет.
- escaped Cyrillic в изменённых файлах проверены: отдельная проверка Unicode/XML escaped Cyrillic, 27 файлов, совпадений нет.

Дополнение владельца об автоматическом Rust+Oxide update сохранено в `docs/agent-tasks/RUST-BOTS-002-SAFE-RUST-OXIDE-UPDATE/TASK.md` как **DESIGN ONLY / NOT STARTED**. Это разрешённое владельцем выделение существенного дополнительного объёма: official latest API, Windows Oxide.Rust.zip, source/hash/compatibility gates до SteamCMD public, backup/restore, сохранность mods/config/data и отказ от autostart при ошибке. Там же сохранён выборочный export очищенных configs через exact files + field allowlist. Updater/export не реализованы и не выданы за работающую автоматизацию. Реальные downloads/updates не запускались; текущий fail-closed BAT остаётся на месте.

## Git и публикация

SSH origin остался `git@github.com:kpCat/RustOxideBots.git`. SSH baseline получил `Permission denied (publickey)`. Git Credential Manager уже содержит аккаунт kpCat; команда с временным HTTPS insteadOf подтвердила публичный baseline и dry-run push `Everything up-to-date`. Remote config не менялся; аутентификация/защита не обходилась.

Разрешение Git: прямой запрос пользователя и TASK A/B/F, включая exact-path commit и обычный fast-forward push master. Никаких branch/merge/rebase/reset/restore/stash/clean/force или broad add.

Использованные уникальные команды (повторы проверок не перечисляются):

```text
git remote -v
git branch --show-current
git status --short
git status --ignored --short
git rev-parse HEAD
git ls-remote origin refs/heads/master
git ls-remote https://github.com/kpCat/RustOxideBots.git refs/heads/master
git -c credential.interactive=false -c core.askPass= ls-remote https://github.com/kpCat/RustOxideBots.git refs/heads/master
git -c credential.interactive=false -c core.askPass= -c url.https://github.com/.insteadOf=git@github.com: ls-remote origin refs/heads/master
git check-ignore -v Server/Run_DS.bat Server/update.bat Server/update_script.txt Server/rustds/RustDedicated.exe Server/rustds/oxide/config Server/rustds/server
git ls-files -- Server/
git diff --check
git config --get-all credential.helper
git config --get user.name
git config --get user.email
git config --get commit.gpgsign
git config --get core.hooksPath
git config --get core.fsmonitor
git config --get core.untrackedCache
git config --get maintenance.auto
git config --get gc.auto
git credential-manager github list
git -c credential.interactive=false -c url.https://github.com/.insteadOf=git@github.com: push --dry-run origin master
```

Secret scan проверил high-confidence credential/Steam ID patterns, а также значения hostname/identity/seed и найденные непустые secret-поля локальных Oxide configs, не выводя сами значения: совпадений нет. UTF-8/binary guard пройден. До первого add: check-ignore, status --ignored и exact-path add dry-run прошли; sandbox index.lock denial устранён разрешённым запуском той же операции вне sandbox.

Exact final artifact allowlist (27 файлов, включая неизменённый поставленный task package и явно запрошенный design следующей задачи):

```text
.gitignore
AGENTS.md
README.md
docs/agent-tasks/RUST-BOTS-001-BOOTSTRAP-NAVIGATION/ACCEPTANCE.md
docs/agent-tasks/RUST-BOTS-001-BOOTSTRAP-NAVIGATION/BAT_AUDIT.md
docs/agent-tasks/RUST-BOTS-001-BOOTSTRAP-NAVIGATION/CODEX_LAUNCHER.txt
docs/agent-tasks/RUST-BOTS-001-BOOTSTRAP-NAVIGATION/EVIDENCE.md
docs/agent-tasks/RUST-BOTS-001-BOOTSTRAP-NAVIGATION/GOAL.txt
docs/agent-tasks/RUST-BOTS-001-BOOTSTRAP-NAVIGATION/HANDOFF.md
docs/agent-tasks/RUST-BOTS-001-BOOTSTRAP-NAVIGATION/PLAN.md
docs/agent-tasks/RUST-BOTS-001-BOOTSTRAP-NAVIGATION/README.md
docs/agent-tasks/RUST-BOTS-001-BOOTSTRAP-NAVIGATION/RESULT.md
docs/agent-tasks/RUST-BOTS-001-BOOTSTRAP-NAVIGATION/TASK.md
docs/agent-tasks/RUST-BOTS-002-SAFE-RUST-OXIDE-UPDATE/TASK.md
scripts/Inspect-RustApi.cs
scripts/Invoke-NavigationProbe.ps1
scripts/OwnedServerProcess.cs
scripts/ProbeSafety.ps1
scripts/Protect-LocalLaunchers.ps1
scripts/Test-All.ps1
scripts/Test-Bootstrap.ps1
scripts/Test-OwnedProcess.ps1
scripts/Test-PluginCompile.ps1
scripts/Test-ProbeSafety.ps1
scripts/templates/Run_DS.bat
scripts/templates/update.bat
src/plugins/RustBotsNavigationProbe.cs
```

Выполнены `git add -n -- $paths`, `git add -- $paths` с первоначальной exact allowlist 26 файлов, `git diff --cached --name-only`, `git diff --cached --check`, `git diff --cached --stat`, `git diff --cached --numstat`, `git diff --cached --no-ext-diff --`, `git commit -m "feat: bootstrap isolated Rust navigation probe with safety gates"`, `git -c credential.interactive=false -c url.https://github.com/.insteadOf=git@github.com: push origin master`, затем rev-parse/ls-remote/status. После дополнения используется та же процедура exact-path add/diff для пяти documentation paths: AGENTS.md, README.md, PLAN.md, RESULT.md и TASK 002; команда commit — `git commit -m "docs: record bootstrap evidence and safe updater follow-up"`. Никаких иных изменений в индексе нет.

Staged scope реализации совпал с exact allowlist: 26 paths, 1625 added lines, без binaries/Server; diff --check прошёл. Публичные файлы повторно проверены на owner secret values, credential patterns и обе группы encoding markers после дополнения (27 файлов). `git ls-files -- Server/` пустой; actual paths в Server/ игнорируются. Реализация: `01b325e95c5cb216e25917259efd8559d2d445a4`. Push receipt: `daa38db..01b325e master -> master`; ls-remote origin/master равен этому SHA. Автоматическая maintenance, запущенная самим Git после commit, завершилась; ручная очистка/изменение истории не выполнялись. Статус после первого push содержит только пять ещё не закоммиченных документационных путей дополнения, перечисленных выше; чужие изменения отсутствовали.

Этот RESULT хранит проверенный SHA реализации и receipt первого push. Финальный документационный commit со всеми дополнениями имеет собственный SHA; он не может быть вписан в собственное содержимое. Его точный SHA, совпадение с origin/master и конечный status сообщаются в финальном ответе и сохраняются в игнорируемом `.local/audit/delivery.json`. Реальные Server/, конфиги, saves, DLL/EXE, логи и secrets не публикуются.

Следующий шаг для E2E: владелец может запустить ту же команду из повышенного PowerShell при отсутствии своего игрового сервера. Runner по-прежнему обязан отказать при невозможности доказать firewall/isolation. Этот следующий запуск и GREEN не заявлены выполненными.
