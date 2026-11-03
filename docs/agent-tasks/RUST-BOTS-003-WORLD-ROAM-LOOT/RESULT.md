# RUST-BOTS-003 — RESULT, 03.11.2026

Итог: **GREEN в ограниченном test-only scope 003** после двух headless live E2E.
Один ScientistNPC2 физически прошёл 413,583 м; дорожный episode — 315,043 м actual / 311,800 м net, без warp.
Обычный native crate fixture опустошён через реальные Item transfers; естественная бочка разрушена native damage, оба выпавших UID подобраны.
После server restart восстановлены прежние 6 UID / 12 единиц; итоговый native inventory — 10 UID / 21 единица, anomalies=0.
Оба сервера завершены GRACEFUL; процессов/портов/firewall rules не осталось, 402 защищённых owner файла неизменны.
Это не production AI и не BasePlayer: инвентарь принадлежит боту, но player equipment/крафт/Steam session не реализованы.

## Baseline, код и публикация

Baseline local master и origin/master: `b4a2c6f17e3a23c5cdb78e02c422a82fb8eb368d`. Чужих изменений не было; предоставленный пакет 003 первоначально untracked. Код и безопасная документация фиксируются exact-path, без смены ветки. Pinned implementation commit: **f94bb92544a8df235403004a44099fb13da0bf89**. После него меняется только этот отчёт. Финальный delivery HEAD должен совпасть с origin/master; точные SHA и push receipt сохраняются в ignored `.local/audit/world003/delivery.json` и сообщаются в финальном ответе. SHA коммита нельзя включить в его собственное содержимое.

Финальный plugin SHA-256: `3D6AFE71A4B4CCA36AD5952682B64BED8244AA89DA518E7D3E2223EF37C2088C`. Он live compiled/loaded во втором запуске. Первый live source SHA: `BB4F96A9D50103B4CBBB57CFCD869DF744DDDB51ECA6C195F85325BFC2689E4C`; snapshot каждого исходника сохранён в своём ignored run. Первое evidence не переписано после исправлений.

## Приёмка

| Часть | Статус | Факт |
|---|---|---|
| OPEN_TRAVEL | GREEN | Второй run: 315,042727 м по road samples, 311,800171 м net, 11 завершённых локальных сегментов; дорога в 1,212676 м |
| CRATE | GREEN | `FIXTURE_NATIVE_PREFAB`, обычный `radtown/crate_normal_2.prefab`; 2 UID / 6 единиц, source → 0, dest +6 |
| BARREL | GREEN | `NATURAL`, `autospawn/resource/loot/loot-barrel-2.prefab`; 3 hits, health 50→32→14→0; 2 native drop UID / 3 единицы подобраны |
| INVENTORY | GREEN | Native ItemContainer; exact restore 6 UID / 12 единиц; initial + новые 4 UID / 9 единиц = 10 UID / 21 единица |
| Live compile | GREEN | Оба server.log: `RustBotsWorldRoam was compiled successfully in 0ms`, `Loaded plugin ... v0.1.0` |
| Safety | GREEN | GRACEFUL, owned absence, ports/firewall released, locks свободны, owner fingerprint unchanged |

## Запуски и честная корректировка

Команды исполнял агент из корня репозитория; owner BAT, SteamCMD, updater 002 и owner RustDedicated не запускались.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-All.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-NavigationProbe.ps1 -WorldRoam -PreflightOnly
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-NavigationProbe.ps1 -WorldRoam -StartupTimeoutSeconds 900 -NavigationTimeoutSeconds 900
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-NavigationProbe.ps1 -WorldRoam -RestoreFrom c5892c25763347f7866e935de0494471 -ResumeJourney -StartupTimeoutSeconds 900 -NavigationTimeoutSeconds 900
```

Preflight в sandbox сначала вернул 2: Windows запретил CIM endpoint query. Тот же разрешённый preflight вне sandbox прошёл, exit 1 — предусмотренный PARTIAL без live start. Настоящих игровых запусков ровно два; оба runner exit 0, оба native server exit −1 при подтверждённом quit/save. Это известный `ConVar.Global.quit` путь установленной DLL, не замаскированный crash.

| Run (ignored `.local/runtime/<id>/`) | Ready / plugin, s | Travel, м | Road actual / net, м | Samples | Shutdown |
|---|---:|---:|---:|---:|---|
| `c5892c25763347f7866e935de0494471` | 267,423 / 266,412 | 382,130737 | 312,176421 / 308,704800 | 272 | GRACEFUL; ports/firewall=true |
| `1ef1052cac9345da961a3f976b401519` | 265,479 / 264,473 | 413,583282 | 315,042727 / 311,800171 | 296 | GRACEFUL; ports/firewall=true |

Первый plugin/runner raw status GREEN сохранён как факт, но **его crate proof отдельно оценивается PARTIAL**: discovery выбрал `assets/bundled/prefabs/modding/lootables/invisible/invisible_lootable_prefabs/invisible_crate_normal_2.prefab`. Предметы были native, однако невидимый modding fixture не засчитан за обычный ящик. Финальный фильтр исключает modding/invisible; второй run подтвердил обычный видимый prefab. Повтор также проверил restart, поэтому третьего server run не было.

## Карта, actor и физический маршрут

Установленный runtime: Rust protocol `2635.289.1`, app manifest buildid `26139947`, Oxide.Rust `2.0.7839`. Actor: `Rust.Ai.Gen2.ScientistNPC2`; prefab `Assets/Rust.Ai/Agents/NPCPlayer/HumanNPC/Scientist/Gen2/Scientist2.prefab`; FSM `Scientist2FSM` выключен только у своего actor. Agent `Rust.Ai.Gen2.RustNavMeshAgent`, agentType=0, areaMask=25, height=2, capsule radius=0,45; backend **RustNav**, не Unity fallback. Создан один probe NPC на каждый run. Другие штатные игровые NPC не выдаются за probe.

Оба запуска: synthetic Procedural Map, size 2000, seed 424242. Cache key `b37a93c03ae490a52662af2f167343eda017ce450d373f43abced8fb91b58b23`, WARM, Promoted=true. `.map` SHA-256 `1F09D94EC8DA9DAC4E32908817A16BCC167D7B5A654E90DB19042E1501F17A47`, 8 303 540 bytes. Второй сервер загрузил 13027 data tiles за 121,4851 ms, default mesh 35344/35344 built через 22,79 s. Processing World=0,5 s; холодная генерация и тяжёлое повторное копирование не выполнялись. Ошибки MapCache upload/Steam connectivity ожидаемы при проверенных block rules; наружу сеть ради startup не открывалась. RunnerElevated=false, повышен только временный firewall broker.

Spawn динамический, не зашитые координаты: Halton кандидат принят на первом пригодном grounded месте около `(0,5.449,-300)`, с water/slope/capsule и complete departure path. Beach/shoreline как отдельный биом не доказан. Во втором run дорога выбрана через TerrainMeta.Path.Roads[13].Path.Points, segment 12: A=`(-240.211853,31.094313,-100.890739)`, B=`(-242.806946,30.140340,-108.171356)`. Arrival=`(-239.247757,31.279997,-101.725761)`, ближайшая проекция=`(-240.357346,31.040829,-101.298920)`, distance=1,212676 м. Путь до выбранной дальней цели: PathComplete, 314,481171 м; длина прямого episode=311,800171 м. Непрерывный episode допускает короткие локальные сегменты согласно ACCEPTANCE; отдельный локальный leg на 75 м не заявляется.

Второй маршрут: start первого leg `(0,5.449,-300)`, start каждого следующего равен End предыдущего. Все 15 legs ARRIVED, PathComplete; stuck/repath=0/0. Координаты округлены только в этой таблице; raw float samples сохранены полностью.

| Leg / phase | Target (x,y,z) | End (x,y,z) | s | actual / net, м |
|---|---|---|---:|---:|
| 1 road | −26.689,10.229,−275.980 | −25.741,10.255,−276.832 | 11.947 | 35.080 / 34.963 |
| 2 road | −35.506,9.653,−270.037 | −34.533,9.885,−270.715 | 4.000 | 10.737 / 10.717 |
| 3 road | −63.298,11.230,−249.181 | −62.333,11.192,−249.904 | 12.002 | 34.920 / 34.751 |
| 4 road | −90.497,16.855,−228.794 | −89.329,16.540,−229.669 | 11.497 | 34.263 / 34.160 |
| 5 road | −116.856,26.568,−208.696 | −115.940,26.365,−209.394 | 11.502 | 35.038 / 34.868 |
| 6 road | −142.706,28.045,−185.337 | −141.802,28.283,−186.150 | 11.997 | 35.239 / 34.825 |
| 7 road | −159.936,26.657,−170.439 | −159.010,26.791,−171.241 | 8.000 | 22.829 / 22.817 |
| 8 road | −177.134,25.878,−155.539 | −176.209,26.032,−156.340 | 8.001 | 22.771 / 22.769 |
| 9 road | −203.367,28.518,−132.811 | −202.482,28.483,−133.578 | 11.999 | 35.158 / 34.848 |
| 10 road | −229.650,30.374,−110.041 | −228.771,30.220,−110.802 | 12.000 | 35.067 / 34.826 |
| 11 road | −240.212,31.144,−100.891 | −239.248,31.280,−101.726 | 5.001 | 13.941 / 13.902 |
| 12 crate | −229.748,31.390,−101.726 | −230.089,31.492,−101.356 | 3.485 | 9.434 / 9.169 |
| 13 barrel | −238.797,26.126,−134.806 | −238.482,26.276,−134.006 | 11.488 | 34.485 / 34.113 |
| 14 barrel | −252.365,24.919,−167.101 | −251.662,24.969,−165.620 | 11.498 | 34.451 / 34.276 |
| 15 barrel | −260.537,24.758,−184.320 | −260.307,24.786,−183.834 | 7.000 | 20.170 / 20.162 |

Road episode=107,949524 s. Независимая реконструкция всех samples дала 413,583371 м против float total 413,583282 м; расхождение <0,001 м. Max sample gap=0,550171 s, step=1,648717 м, speed=3,611597 м/s. Первый run реконструирован в 382,130502 м против 382,130737. После spawn код не вызывает warp/MovePosition/transform.position assignment; движение только SetDestination. Rejected candidates второго run: capsule 146, nav/ground mismatch 148, sample miss 4, above terrain 4, steep 2; всего 304. Это bounded отказы geometry/loot approaches, не 304 spawns. Failed legs=0; три примера каждого отказа есть в raw JSON. Conservative clearance отверг ряд естественных crate approaches, поэтому использован fixture; исчерпывающая невозможность natural crates на карте не заявляется.

## Native damage, лут и баланс

Concrete crate: `assets/bundled/prefabs/radtown/crate_normal_2.prefab`, runtime `LootContainer`, fixture на физической поверхности `(-231.247742,31.671764,-101.725708)`. Инициализация ровно один раз: CreateEntity→Spawn→LootContainer.ServerInit→SpawnLoot, без повторного PopulateLoot. Approach actor=`(-230.088600,31.491913,-101.355957)`, distance=1,229914 м, LOS=true, owner/locked checks пройдены.

Natural barrel: `assets/bundled/prefabs/autospawn/resource/loot/loot-barrel-2.prefab`, `LootContainer`, `(-262.037445,24.470032,-184.319763)`. Три вызова `loot.OnAttacked(new HitInfo(npc, loot, Rust.DamageType.Blunt, 20f, ...))` на расстоянии 1,824961 м, LOS=true, интервал >=1 s. Requested damage=20, фактическое health 50→32→14→0; native damage/protection pipeline не обходится. Прямые Kill/DropItems для зачёта не используются. После смерти два новых DroppedItem с прежними UID источника; pickup distance=1,761602 / 2,269119 м, allowPickup=true по выполненному guard. Анимация взмаха/экипированный melee tool не реализованы: это серверный proximity damage adapter.

В таблице только ephemeral Item UID из синтетического теста, не Steam/account ID. Все новые transfers второго run: source уменьшается на Amount, destination увеличивается ровно на Amount; stacking отключён, UID не меняется.

| Source / UID | Shortname | Source before→after | Owned before→after |
|---|---|---:|---:|
| crate fixture / 40972 | semibody | 1→0 | 0→1 |
| crate fixture / 40973 | scrap | 5→0 | 0→5 |
| natural barrel drop / 2537 | spikes.floor | 1→0 | 0→1 |
| natural barrel drop / 2538 | scrap | 2→0 | 0→2 |

Barrel-before и native drops совпадают по UID/shortname/amount; NativeDropConserved=true. Объекты Item перемещены `item.MoveToContainer(inventory, -1, false)`. Нет GiveItem/CreateByName/CreateByItemID/выдачи ресурсов ради теста. Gen2 не получает BasePlayer-only бонусы DropBonusItems.

Первый run сохранил: UID 30395 gears×2, 30396 diving.mask×1, 30397 electric.pressurepad×1, 30398 scrap×5 из честно помеченного invisible native fixture; UID 2790 metalspring×1 и 2791 scrap×2 из естественной бочки. Во втором server process native Load восстановил все шесть без изменений, затем эти же UID остались в итоговом inventory. Баланс: **12 initial + 6 crate + 3 barrel = 21 единица**, 6+2+2=10 разных UID; destination/source anomalies=0. Старые и новые scrap stacks специально не объединены.

## Persistence, raw receipts и ограничения

Native `ItemContainer.Save().ToProtoBytes()` → isolated binary snapshot, затем `ProtoBuf.ItemContainer.Deserialize(bytes)` → native `inventory.Load(snapshot)`. Runner проверяет clean prior run, exact cache generation, SHA-256 .sav и snapshot до запуска второго сервера; старый/холодный мир не допускается. После независимого review одного compatibility key признано недостаточно.

First .sav SHA-256 `DC0D7D51EA234E83CF9AB9DE2939B247BB6F78AFB2A6DA32150BF511B55272F6`; snapshot `244FB598CEC36EBC35F27F5013999D237108C88AA326D0B1B72C9ED823CFFF02`. Отдельный append-only world-proof создан после clean shutdown первого run под cache lock, до нового запуска; raw result не менялся. Второй .sav `0802FAFCB8BEA429A5A4DE25D6A58A67160AB86F6D2F4E4ABFBA27722DC6EBF8`; новый snapshot `C313ED3E6CE9245AB31B3D3A4D5FDDD2BE6DF884D0BD70DF92FC996B807DB721`, world-proof сформирован runner автоматически.

Per-run raw: `server.log`, `result.json`, `plugin-result.json`, `inventory.bin`, `world-proof.json`, `plugin-source.cs` в ignored `.local/runtime/<run-id>/`. Итоговые независимые расчёты, tests-delivery.txt, cleanup.json и owner fingerprints — ignored `.local/audit/world003/`. Старые логи и поколения кеша не удалялись. Public configs/secrets/owner identity/IP не экспортировались.

Применимость ограничена одним Gen2 и bounded outdoor route на этой совместимой карте. Не доказаны production persistence service, native PlayerInventory, visual equipment, инструментальный melee animation, natural crate acquisition, beach biome, произвольная карта, PvP/crafting/building/respawn/clans или 50–100 активных NPC. Последние 9 единиц записаны в новый native snapshot, но третьим restart не проверялись; restart-проверка 12 прежних единиц выполнена реально. Это сознательное соблюдение лимита двух игровых запусков. Save log содержал engine warning `Entity is NULL but is still in saveList`; completed save, hash binding и успешный restart зафиксированы, исправление движка вне scope.

## Проверки, cleanup и scope

Final `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-All.ps1`: **exit 0**, полный существующий focused suite + WorldRoam contracts + offline C# 7.3 обоих plugins. RED→GREEN: отсутствующий validator; ложная road geometry/arrival/empty chain; независимый GREEN part без pickup; stale world binding; resumed inventory quantity mismatch. Fixtures — только contract inputs, не game evidence. Один промежуточный Test-All запуск exit 1: BAT fixture отказал из-за реально работающего test RustDedicated; после cleanup весь suite пройден. Ошибка alias в новом synthetic resume fixture исправлена, финальный suite проверен повторно. Offline compile не выдан за live compile.

Оба runs: owned Job Object на creation; graceful marker→ACK→native quit, полный save, exit −1; OwnedProcessAbsent/PortsReleased/FirewallRemoved=true. Внешняя финальная проверка `2026-11-03T12:24:06Z`: Rust/SteamCMD processes=0, TCP/UDP 28965–28968=0/0, RustBots001 firewall rules=0, оба leases Closed/Removed=true, lifecycle/cache locks эксклюзивно открываются. Lock-файлы остаются как evidence, активных handles нет. Owner fingerprint: 402 файлов до/после, изменений/добавлений/удалений=0. Owner binaries/configs/world/plugins/BAT не менялись; новые plugin copies в owner Server не устанавливались.

Final exact allowlist: README.md; scripts/Invoke-NavigationProbe.ps1, Test-All.ps1, Test-PluginCompile.ps1, Test-WorldRoam.ps1, WorldRoamValidation.ps1; src/plugins/RustBotsWorldRoam.cs; docs/agent-tasks/RUST-BOTS-003-WORLD-ROAM-LOOT/{ACCEPTANCE.md, API_FEASIBILITY.md, EVIDENCE.md, GOAL.txt, HANDOFF.md, LIFE_ROADMAP.md, PLAN.md, README.md, RESULT.md, TASK.md}. Всего 17 text paths, включая семь предоставленных task-файлов. Это зафиксированный bounded exception одного сценария; другие подсистемы, AGENTS.md, plugin 001 и task 002 не менялись.

Git-команды разрешены прямым запросом и TASK §5. Использованы read-only `git status --short`, `git status --ignored --short -- Server/ .local/ artifacts/`, `git branch --show-current`, `git rev-parse HEAD`, `git remote -v`, `git ls-remote origin refs/heads/master`, `git ls-files -- Server/`, `git diff --stat`, `git diff --numstat`, `git diff --check`, `git diff -- scripts/Invoke-NavigationProbe.ps1 scripts/Test-All.ps1 scripts/Test-PluginCompile.ps1`. Точные ignore-проверки: `git check-ignore -v Server/rustds/RustDedicated.exe .local/api-world.txt` и `git check-ignore -v Server/rustds/RustDedicated.exe Server/rustds/oxide/config .local/runtime/1ef1052cac9345da961a3f976b401519/result.json`. SSH/HTTPS из sandbox недоступны; разрешённый HTTPS read-only запрос вне sandbox подтвердил baseline. Для remote применён временный `-c credential.interactive=false -c url.https://github.com/.insteadOf=git@github.com:`, origin config не меняется.

Доставка: `git add -n -- $world003Paths`, `git add -- $world003Paths`, где $world003Paths — перечисленные 16 exact путей без RESULT; затем `git add -n -- docs/agent-tasks/RUST-BOTS-003-WORLD-ROAM-LOOT/RESULT.md`, `git add -- docs/agent-tasks/RUST-BOTS-003-WORLD-ROAM-LOOT/RESULT.md`. Проверки: `git diff --cached --name-only`, `git diff --cached --check`, `git diff --cached --stat`, `git diff --cached --numstat`, `git diff --cached --no-ext-diff --`. Коммиты: `git commit -m 'feat: prove isolated world roaming and native loot persistence'`, `git commit -m 'docs: record verified world roam loot evidence'`. Публикация: `git -c credential.interactive=false -c url.https://github.com/.insteadOf=git@github.com: push origin master`, затем `git rev-parse HEAD`, `git -c credential.interactive=false -c url.https://github.com/.insteadOf=git@github.com: ls-remote origin refs/heads/master`, `git status --short`. Без broad add, branch/merge/rebase/reset/restore/stash/clean/force. `git ls-files -- Server/` пустой; effective ignores Server/ и .local/ подтверждены. UTF-8/binary/credential/owner-value scan перед staging пройден; точный delivery SHA/receipt фиксируется после push отдельно, без изменения собственного commit.

- mojibake-маркеры в изменённых файлах проверены: 17 файлов, отдельная полная группа маркеров.
- escaped Cyrillic в изменённых файлах проверены: 17 файлов, отдельные Unicode/XML regex-паттерны.

Read-only review проведён отдельным агентом; Critical/Important замечания исправлены одним проходом и focused contracts. Deferred minors нет. Решения: текущий master по запросу владельца; native owned ItemContainer вместо замены actor; один corrective resume run ради visible prefab и restart. Цена этих решений — перечисленные ограничения, без обещаний production survivor AI.
