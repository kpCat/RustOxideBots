# RustOxideBots

Диагностическая проба серверной навигации NPC для установленного Rust/Oxide. Первая задача готовит безопасный тестовый контур; полноценные автономные игроки находятся вне её scope.

Текущая проба 001 показала реальное движение одного Scientist2: три динамические цели, 92,21 м фактического пути, без застреваний и repath. Подробные живые метрики, контрольный запуск и shutdown — в [RESULT.md](docs/agent-tasks/RUST-BOTS-001-BOOTSTRAP-NAVIGATION/RESULT.md).

`Server/` целиком локален и исключён из Git. Сборку Rust/Oxide нужно установить отдельно; эти скрипты её не скачивают и не обновляют. Пользовательские миры, конфиги и сторонние плагины не копируются в тест.

Сценарий 003 добавляет отдельный test-only `RustBotsWorldRoam`: один Gen2 NPC идёт к геометрии настоящей дороги, подходит к native crate/barrel и переносит реальные Item UID в принадлежащий боту ItemContainer. Фактические результаты и ограничения — в [RESULT 003](docs/agent-tasks/RUST-BOTS-003-WORLD-ROAM-LOOT/RESULT.md), подтверждённые API — в [API_FEASIBILITY](docs/agent-tasks/RUST-BOTS-003-WORLD-ROAM-LOOT/API_FEASIBILITY.md). Это диагностический сценарий; видимая экипировка, PlayerInventory и production AI не реализованы.

Сценарий 004 — отдельный `RustBotsSurvival`: потребности wood/stones, bounded поиск естественных TreeEntity/OreResourceEntity, физический подход и явно обозначенный `SERVER_ACCOUNTED_TOOL`. Начальный kit — один native rock; это не добыча и не native экипировка. Адаптер читает установленный профиль камня, учитывает condition, списывает реальный single-category pool через `ResourceDispenser.DestroyFraction(amount)` и лишь после проверки debit создаёт native output Item. Фактические результаты — в [RESULT 004](docs/agent-tasks/RUST-BOTS-004-HARVEST-TOOLS/RESULT.md), ограничения API — в [API_DECISION](docs/agent-tasks/RUST-BOTS-004-HARVEST-TOOLS/API_DECISION.md).

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-NavigationProbe.ps1 -SurvivalGather
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-NavigationProbe.ps1 -SurvivalGather -RestoreFrom <completed-gather-run-id>
```

004 restore дополнительно связывает hash actor/goal/tool state с native inventory и точным завершённым миром; он проверяет прежние UID, amount и condition, затем останавливается без повторной добычи. Runtime pool ResourceDispenser сам по себе не сохраняется native ResourceEntity.Save: восстановление добытых предметов не доказывает сохранение depleted pools. Это ограниченный probe; cross-restart resource ledger, player animations и crafting требуют отдельного этапа. Режимы `-SurvivalGather` и `-WorldRoam` несовместимы; прежние команды 001/003 сохранены.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-NavigationProbe.ps1 -WorldRoam
# После clean run: native inventory restore в точном сохранённом test world.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-NavigationProbe.ps1 -WorldRoam -RestoreFrom <run-id>
# Дополнительно повторить journey, сохраняя ранее добытые предметы:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-NavigationProbe.ps1 -WorldRoam -RestoreFrom <run-id> -ResumeJourney
```

`RestoreFrom` принимает 32-символьный ID завершённого isolated run с per-run snapshot/hash и world-proof.json. Cache key, точный .sav hash, generation, успешный shutdown и UID/amount должны совпасть; несовместимый или старый мир не допускается. Без `-WorldRoam` runner выполняет прежнюю пробу 001. Все команды самостоятельно останавливают только собственный Job Object и убирают свой firewall lease.

На Windows 10+/Server 2016+ с PowerShell 5.1 запустите из корня репозитория:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-NavigationProbe.ps1
```

Нужен включённый Windows Firewall с разрешёнными локальными правилами. При запуске из обычного PowerShell runner использует отдельный UAC-helper только для временных блокирующих правил тестовой копии; RustDedicated наследует обычный Windows token runner. Helper подтверждает ActiveStore, runner дополнительно читает правила через COM. Авторизация Codex не считается повышением Windows-прав. Системный UAC может потребовать однократное разрешение для helper; вручную вводить команды запуска/остановки не требуется. При чужом процессе Rust или занятых тестовых портах запуск блокируется. `-PreflightOnly` проверяет предпосылки без UAC/копирования/запуска.

Runner хранит физическую тестовую установку и проверенные map/sav/RustNav в `.local/probe-cache/<key>/`. Ключ включает хеши Rust/Oxide/Unity/native DLL и EXE, параметры карты, backend и инвентарь assets; порядок не зависит от PowerShell 5.1/7 и локали. Завершённая копия runtime продвигается из staging после полного SHA-256 inventory; повреждение или несовместимость вызывают отказ от кеша и безопасное пересоздание. Мир восстанавливается только после проверки всех хешей. Плагины, конфиги, данные Oxide и прочее временное состояние создаются заново для запуска; предыдущая тестовая копия архивируется в `.local/runtime/<run-id>/`. Hardlink/junction не используются. Owner cfg/config/oxide/server и игровые сохранения не копируются и не меняются.

Рабочая копия собственного C# Oxide-плагина находится в `Server/rustds/oxide/plugins/RustBotsNavigationProbe.cs`; без test marker/environment/identity она инертна. Используются искусственные seed 424242, размер 2000 и loopback-порты 28965–28968. Повторный запуск той же совместимой установки использует постоянную test identity и проверенный мир; разовая генерация нужна для нового/несовместимого/повреждённого кеша. Все EXE тестовой копии блокируются для внешнего входящего и исходящего трафика. Случайный пароль RCON и raw evidence остаются только локально.

Проба ждёт полной готовности RustNav, печатает built/total tiles, затем проверяет ground/water/capsule и возможность уйти с точки рождения. Поиск покрывает 90% карты; для каждого вида отказа есть счётчик и до трёх примеров. Абсолютный порог высоты над морем не используется. Создаётся один человекоподобный NPC; цели подтверждаются активным агентом и complete path. Три перехода и не менее 60 м принимаются только с непрерывными фактическими координатами.

После пробы runner просит `quit` через локальный command-файл, ждёт до 30 секунд, затем закрывает Job Object только своего процесса и дочерних процессов. При аварийном завершении контроллера Job Object закрывается системой. Firewall lease удерживается reservation до выхода owned job, поэтому helper не может снять правила между проверкой и запуском. Закрывающийся lease не принимает новые запуски. При зависшем startup без загрузившегося плагина применяется ограниченное завершение своего Job Object. Кеш продвигается после ACK, завершённого save и подтверждённого выхода; установленный native `quit` вызывает Process.Kill после ServerMgr.Shutdown, поэтому его наблюдаемый exit −1 сохраняется в отчёте и обрабатывается явно.

Readiness ограничен 900 секундами, ожидание RustNav и навигации — ещё 900 (внутри плагина ожидание сетки до 600). Код выхода: 0 GREEN, 1 PARTIAL, 2 BLOCKED/FAILED. Timeline, координаты, cache и shutdown находятся в `.local/runtime/<run-id>/result.json`; полные сообщения остаются в server.log. UTF-8 декодируется явно, консоль и дочерний PowerShell выводят UTF-8; ошибки не скрываются. Недоступные Steam/MapCache/Unity-сервисы при изоляции ожидаемы и не получают разрешения в интернет. Длительный переход через карту/монументы/дома и масштабирование этим тестом не доказываются. Исторические raw test archives сохраняются локально; автоматическая очистка старых evidence не входит в 001.

Проверки без SteamCMD и настоящего сервера:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-All.ps1
```

Для offline compile-check нужен установленный .NET SDK и локальные Rust/Oxide DLL. Метаданные можно читать .NET 10 инструментом без исполнения DLL:

```powershell
dotnet run --file scripts/Inspect-RustApi.cs -p:PublishAot=false -p:NuGetAudit=false -- Server/rustds/RustDedicated_Data/Managed/Assembly-CSharp.dll 'ScientistNPC2$'
```

Обезличенные BAT-шаблоны лежат в `scripts/templates/`. `Run_DS.bat` требует локальной замены `@@SERVER_ARGUMENTS@@` исходными аргументами; шаблон не готов для игрового запуска без этого. `Protect-LocalLaunchers.ps1` предназначен только для исходного однострочного launcher и сохраняет его аргументы, бэкапы и SHA-256 в `Server/backups/`; для уже исправленных BAT повторное применение запрещено. В задаче 001 оба рабочих BAT уже исправлены локально и не исполнялись.

`update.bat` намеренно всегда отказывает до SteamCMD: 2 — нет SteamCMD/каталога, 3 — нет runscript, 4 — нет пакета Oxide, 78 — не проверено восстановление. Наличие ZIP само по себе не подтверждает совместимость. Для будущего обновления нужна отдельная задача: выбрать совместимый с целевой Rust сборкой пакет Oxide и проверить его происхождение/хеш; сделать бэкап установки, миров и настроек; явно подтвердить обновление; проверить Rust exit code, переустановить Oxide, подтвердить версии и загрузку на изолированной копии; при ошибке восстановить бэкап. До реализации и проверки этого процесса апдейтер остаётся заблокированным. В 001 updater и SteamCMD запускать запрещено.

Справка: [Facepunch: создание сервера и предупреждение об Oxide](https://wiki.facepunch.com/rust/creating-a-server), [исходники Oxide.Rust](https://github.com/OxideMod/Oxide.Rust), [Windows Job Objects](https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects). Runtime API проверяется по установленным DLL, поскольку старые примеры могут отличаться.

Полный updater одной командой и выборочный экспорт очищенных конфигураций сохранены как [следующая задача 002 — только проектирование](docs/agent-tasks/RUST-BOTS-002-SAFE-RUST-OXIDE-UPDATE/TASK.md). Их реализация существенно расширяет 001; текущий updater остаётся заблокированным. План предусматривает Steam public, официальный GitHub latest API/Windows asset, доверенный SHA-256, независимый compatibility gate, проверенный backup/restore и сохранность plugins/config/data. Для config export нужны exact выбранные файлы и allowlist публичных полей; массовое копирование owner config в Git запрещено. Настоящих обновлений или export/apply в 001 нет.
