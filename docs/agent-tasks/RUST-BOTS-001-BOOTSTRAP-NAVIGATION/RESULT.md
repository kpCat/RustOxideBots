# RUST-BOTS-001-BOOTSTRAP-NAVIGATION v2 — RESULT

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
| Owner preservation | 397 исходных файлов проверены SHA-256; изменений 0 |
| Commit / push | Ожидают финальной проверки; см. раздел Git ниже |

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

Предусмотренная установка — новая физическая копия `.local/runtime/<id>/install`; owner cfg/config/oxide/server не копируются. Выбранные roots и файлы проверяются на reparse points до обхода; writable Oxide-каталоги создаются заново, root/ancestors проверяются. E2E-копия в owner `oxide/plugins` намеренно не развёртывалась: критическое уточнение C2 требует отдельного writable install root. Источник — `src/plugins/RustBotsNavigationProbe.cs`; deployment выполняется runner только после gate.

Метаданные текущих DLL прочитаны без загрузки/исполнения игрового кода. Сопоставлены старые NPCPlayer→BasePlayer и ScientistNPC→HumanNPC с Gen2 ScientistNPC2→BaseNPC2→BaseCombatEntity. Подтверждены RustNavMeshAgent.SamplePosition/CalculatePath/SetDestination, RustNavMeshPath.status/GetPathLength, FSMComponent.SetFsmActive и RustNavigation.DefaultNavmesh. Методы sample/path выбираются по фактическому `ConVar.AI.useUnityNavmesh`; один Unity SamplePosition не считается доказательством RustNav. Compile references учитывают blacklist установленного CSharpPluginLoader: standalone Newtonsoft/protobuf/websocket исключены в пользу Oxide.References.

Плагин выбирает доступный humanoid prefab из установленного manifest, предпочитает Gen2; конкретный prefab/NPC/brain/agent и backend выводятся только при live run. Gen2 scientist не BasePlayer и не предоставляет эквивалент полноценного игрока; старый NPCPlayer является BasePlayer, но живого Steam-соединения не создаёт. Что реально активно для выбранного NPC, **NOT_VERIFIED**.

Реализованы terrain/navmesh/height/clearance checks, один spawn, три динамических complete-path цели, штатный nav agent, координатные samples, elapsed/path/stuck/repath, отказ при разрыве измерений/скачке, один bounded repath и timeout. После рождения телепортаций/ручного MovePosition в plugin source нет. Runner отдельно проверяет пороги и согласованность GREEN метрик. Unit-test fixtures являются только contract inputs и не публикуются как live телеметрия.

Фактических sample/path/stuck/arrived сообщений игрового NPC нет; spawn attempts 0, navigation attempts 0, успешные/неуспешные live legs не измерялись. Статическая компиляция успешна, **live Oxide compilation NOT_VERIFIED**. Нельзя утверждать движение по карте/монументам, обход домов, player behavior или масштаб 50–100 NPC. Фарм, крафт, PvP, строительство не добавлялись.

## Проверки и shutdown

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-All.ps1` — PASS. Сводка: все PowerShell-файлы разбираются; BAT/hardener fixtures, foreign-process gate, shared writable log, junction rejection, GREEN evidence validation, exception/abrupt-controller cleanup и offline C# compile прошли. Статический/fixture успех не меняет статус E2E.

OwnedServerProcess использует Windows 10+ PROC_THREAD_ATTRIBUTE_JOB_LIST при CreateProcess, hidden/suspended start и kill-on-close. Назначение Job Object атомарно, до исполнения child. Бounded quit→wait→close касается только собственного job/handle, не поиска процессов по имени. Тесты с отдельными sleeping fixtures показали завершение собственного child после исключения и после принудительного выхода контроллера, при этом посторонний fixture остался жив. Все созданные fixtures затем остановлены по сохранённым handles. Windows API проверен по [Microsoft](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-updateprocthreadattribute).

Финальный Win32_Process: RustDedicated/RustClient/Rust/SteamCMD = 0. Финальные TCP/UDP endpoints 28965–28968 = 0/0. Полного game shutdown evidence нет, поскольку game PID не существовал. При будущем live-run команда quit передаётся test-only plugin через локальный marker-scoped файл; без загрузившегося plugin может понадобиться forced owned-job stop. Это ограничение явно сохранено.

Owner fingerprint включает server worlds/maps/saves, все oxide files, cfg/config/HarmonyMods, ключевые game/Oxide binaries и неизменяемые BAT/runscript: 397 файлов, 0 изменённых. Разрешённые два BAT исключены из fingerprint и проверены отдельно по аргументам/backup hashes. Все raw отчёты остаются в `.local/audit/` и `.local/runtime/`, а бэкапы — в игнорируемом Server/.

- mojibake-маркеры в изменённых файлах проверены: 26 файлов, совпадений нет.
- escaped Cyrillic в изменённых файлах проверены: отдельная проверка Unicode/XML escaped Cyrillic, 26 файлов, совпадений нет.

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
git credential-manager github list
git -c credential.interactive=false -c url.https://github.com/.insteadOf=git@github.com: push --dry-run origin master
```

Secret scan проверил high-confidence credential/Steam ID patterns, а также значения hostname/identity/seed и найденные непустые secret-поля локальных Oxide configs, не выводя сами значения: совпадений нет. UTF-8/binary guard пройден. До первого add: check-ignore, status --ignored и exact-path add dry-run прошли; sandbox index.lock denial устранён разрешённым запуском той же операции вне sandbox.

Exact final artifact allowlist (26 файлов, включая неизменённый поставленный task package):

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

Далее выполняются только `git add -n -- $paths`, `git add -- $paths` с этой exact allowlist, `git diff --cached --name-only`, `git diff --cached --check`, `git diff --cached --stat`, `git diff --cached --numstat`, `git diff --cached --no-ext-diff --`, `git commit -m "feat: bootstrap isolated Rust navigation probe with safety gates"`, `git -c credential.interactive=false -c url.https://github.com/.insteadOf=git@github.com: push origin master`, затем rev-parse/ls-remote/status. После push исходного результата допускается отдельный exact-path docs commit RESULT/PLAN с publication receipt; его SHA сообщается в финальном ответе, поскольку файл не может содержать hash собственного коммита.

Final staged scan, commit SHA, push и remote/status receipt будут добавлены после заключительных проверок. Реальные Server/, конфиги, saves, DLL/EXE, логи и secrets не публикуются.

Следующий шаг для E2E: владелец может запустить ту же команду из повышенного PowerShell при отсутствии своего игрового сервера. Runner по-прежнему обязан отказать при невозможности доказать firewall/isolation. Этот следующий запуск и GREEN не заявлены выполненными.
