# RUST-BOTS-004 — RESULT, 03.11.2026

**SURVIVAL_GATHER=GREEN в ограниченном test-only scope ACCEPTANCE.md.** Один Gen2 NPC автономно добыл **20 wood и 20 stones** у двух **NATURAL** источников, физически прошёл **71,6513 м** и после независимого полного server restart восстановил **7 native Item UID / 41 единицу**, включая начальный rock и его condition. Личность, цели и память узлов также восстановлены.

Классификация действия: **SERVER_ACCOUNTED_TOOL**. **NATIVE_EQUIPMENT=NOT_NATIVE_EQUIPPED**, player equivalence не заявляется. Реальных server launches ровно **3**: первый PARTIAL из-за доказанного дефекта управления FSM, один исправленный gather и один restore. Все завершены GRACEFUL; owner Server неизменен.

Implementation commit **1ca21bdf42a8fdd55bb9ffccb046b125130538c4** опубликован обычным fast-forward push; local HEAD и origin/master совпали. Этот отчёт и финальная отметка PLAN поставляются отдельным docs commit. SHA самого final commit и remote receipt сохраняются в ignored `.local/audit/harvest004/delivery.json` и финальном ответе после push.

## Матрица проверки ACCEPTANCE / EVIDENCE

| Система | Статус | Факт и evidence |
|---|---|---|
| API | STATIC/IL + LIVE | Локальные DLL и [API_DECISION](API_DECISION.md); live Gen2 не BasePlayer, PlayerInventoryComponent=false; native NPC probe не даёт yield |
| SOURCE | GREEN | NATURAL TreeEntity #6975 и OreResourceEntity #5648; конкретные prefab/позиции ниже; ресурсные fixtures не создавались |
| MOVEMENT / NAVIGATION | GREEN | 4 ARRIVED / PathComplete legs; 72 физических samples; 71,651306 м независимой реконструкции; no warp; до обоих источников |
| HARVEST | GREEN | Native pool debit wood 375→355, stones 750→730; только затем создание native output Item; numerical ledger, без второго native award |
| WOOD | GREEN | 2 tool hits ×10 wood; source-minus=20, inventory-plus=20 |
| ORE | GREEN | 4 tool hits ×5 stones; source-minus=20, inventory-plus=20; metal/sulfur не проверялись |
| TOOLS | GREEN: SERVER_ACCOUNTED_TOOL | Настоящий starter rock UID 51502; installed BaseMelee profile; condition 100→97,996; реальная ownership/range/LOS проверка |
| NATIVE_EQUIPMENT | NOT_NATIVE_EQUIPPED | Native PlayerInventory/HeldEntity owner path требует BasePlayer. Предмет в owned ItemContainer не выдан за экипировку/анимацию |
| INVENTORY | GREEN | 1 starter UID +6 earned UID; 1 rock +20 wood +20 stones; stacking выключен, anomalies=0; точные строки ниже |
| PERSISTENCE | GREEN | Отдельный процесс RESTORE: exact UID/shortname/amount/condition/maxCondition и actor ID/goal/tool/rejected state; exact .sav/generation/hash binding |
| SAFETY | GREEN | Все 3086 файлов Server побайтово прежние по SHA-256; owned/broker/ports/rules/locks=0; секреты и raw evidence только ignored |
| TESTS | GREEN | C# 7.3 installed-DLL compile и offline suite; live Oxide compiled/loaded во всех трёх процессах; fixture PASS не засчитаны за live |
| GIT | GREEN: implementation опубликован | Exact-path 16 файлов, ordinary fast-forward 56247c5→1ca21bd; final docs commit/remote SHA — отдельный delivery receipt |

## Runtime, actor и механизм

Живой Rust protocol **2635.289.1**, Build Date в server.log `10/22/2026 19:30:56`; Oxide.Rust **2.0.7839**, RustBotsSurvival **0.1.0**. Установленные DLL fingerprints приведены в API_DECISION. Финальный plugin SHA-256, одинаковый в gather 2, restore 3 и публичном исходнике: `21DD14D789447D29CE3CBCCD8D1E015E996AC824ECC22DF753D5528DD62E959D`.

Actor: `Rust.Ai.Gen2.ScientistNPC2`; prefab `Assets/Rust.Ai/Agents/NPCPlayer/HumanNPC/Scientist/Gen2/Scientist2.prefab`; `Scientist2FSM` остановлен через **SetFsmActive(false)** по аналогу 001/003. Backend `RustNavMeshAgent/RustNav`; один actor на процесс, без Steam identity/подмены игроков. Actor ID: `survivor-004-0b45d70e9cd34209a9f0de3611d6a64b`. Owned native ItemContainer, не PlayerInventory.

Planner проверяет реальный недостаток wood/stones и выбирает существующий reachable ресурс по расстоянию. Поиск выполняется по событию потребности/recovery, максимум 64 ближайших кандидата в радиусе 400 м и 6 discovery attempts; движение ограничено 40 legs/600 s. Сначала найденный oak #6978 отвергнут из-за физического range/LOS/ground, затем выбран birch #6975. Чужие сундуки/TC не рассматриваются, маршрут и координаты ресурсов не заданы в коде.

Native Gen2 probe перед каждой категорией: CanGather=true, InitiatorPlayer=false, pool без изменения, InventoryDelta=0, NewDrops=0; health уменьшается. Это диагностический NPC damage, без зачёта добычи. IL GiveResources требует настоящего BasePlayer. Два probe hits учитываются отдельно от шести tool-adapter hits.

Адаптер требует настоящий owned rock, допустимый condition, grounded actor, clear LOS и дистанцию ≤min(2,8; native maxDistance+0,5)=**1,75 м** до root источника. Профиль из `assets/prefabs/weapons/rock/rock.entity.prefab`: maxDistance=1,25; gatherDamage tree=10, ore=5; destroyFraction=0,5; conditionLost=0,334. Это серверный допуск, не утверждение о player-native strike.

На каждом tool hit: bounded native damage с CanGather=false; проверка отсутствия неожиданного pool delta; native Item.LoseCondition; **ResourceDispenser.DestroyFraction(amount)** списывает amount из единственной положительной native категории; проверяется точная убыль и fraction↓; лишь затем ItemManager.Create(itemDef,amount) и MoveToContainer без stacking. Этот метод debit не создаёт предметов. Multi-category/negative/nonfinite/empty pools отвергаются. При сбое output после debit pending item удаляется, credit не повторяется; crash-atomic journal/rollback не реализован. Hotspot/finish bonuses и native gather multipliers не воспроизводятся.

## Natural источники и бухгалтерия

Координаты относятся только к synthetic procedural test map, size 2000 / seed 424242. Все три запуска использовали WARM физический кеш `b37a93c03ae490a52662af2f167343eda017ce450d373f43abced8fb91b58b23`; install integrity и world hashes проверяет существующий runner. Owner writable data и конфиги в тест не копировались; Steam/Rust/Oxide не обновлялись.

| Source | Native prefab | Root position | Pool до→после | Health: до probe→после probe→после tool hits | Yield / дистанция |
|---|---|---|---|---|---|
| WOOD / NATURAL / TreeEntity #6975 | `assets/bundled/prefabs/autospawn/resource/v3_temp_field/birch_small_temp.prefab` | −31,2587; 7,2966; −304,9832 | 375→365→355 | 744→742→740→738 | wood 10+10; 1,56242049 м |
| ORE / NATURAL / OreResourceEntity #5648 | `assets/bundled/prefabs/autospawn/resource/ores_sand/stone-ore.prefab` | −64,5744; 4,2143; −325,4796 | 750→745→740→735→730 | 500→498→496→494→492→490 | stones 5+5+5+5; 1,57201838 м |

Wood fraction 1→0,946666658; stones 1→0,973333359. Фактический protected damage каждого probe/tool hit ≈2,0; ограничение raw profile перед native protection — 10, не lethal Kill. Source entity ни разу не уничтожалась ради PASS. Sources/Harvests в plugin-result.json содержат отдельные timestamps, source ID/prefab/type, actor/source positions, pool/fraction/health, tool costs, output UID и geometry.

| UID | Назначение | Amount перед shutdown | После restart | Condition перед / после restart |
|---|---|---:|---:|---|
| 51502 | starter kit: rock | 1 | 1 | 97,996 / 97,996; max=100 |
| 55153 | earned wood | 10 | 10 | 0 / 0 |
| 55154 | earned wood | 10 | 10 | 0 / 0 |
| 55182 | earned stones | 5 | 5 | 0 / 0 |
| 55223 | earned stones | 5 | 5 | 0 / 0 |
| 55289 | earned stones | 5 | 5 | 0 / 0 |
| 55290 | earned stones | 5 | 5 | 0 / 0 |

Starter kit изначально содержал ровно один rock condition=100; это разрешённый subset native GiveDefaultItems, не ресурсный output. Шесть новых UID оплачены ровно 40 единицами native pool. Tool condition: 100→99,666→99,332→98,998→98,664→98,33→97,996. Native output отсутствовал в probe; adapter health hit отключает gather; source остаётся живым, native death/drop/finish bonus не вызывается. Final ledger реконструирован независимо и сравнен с настоящим ItemContainer.

## Физическое движение

| Leg | Start (x,y,z) | Target | End | actual / net, м | Repath |
|---|---|---|---|---|---:|
| WOOD 1 | 0; 5,449; −300 | −29,773; 7,635; −302,862 | −29,479; 7,807; −302,834 | 29,788143 / 29,708403 | 0 |
| WOOD 2 | −29,479; 7,807; −302,834 | −29,859; 7,395; −304,983 | −29,783; 7,582; −304,556 | 1,763170 / 1,763170 | 0 |
| ORE 1 | −29,783; 7,582; −304,556 | −55,536; 5,432; −318,408 | −55,346; 5,560; −318,264 | 29,861080 / 29,076570 | 0 |
| ORE 2 | −55,346; 5,560; −318,264 | −63,584; 4,445; −324,490 | −63,468; 4,503; −324,401 | 10,238913 / 10,234584 | 0 |

Все legs ARRIVED / PathComplete, continuous chain. Между добычей дерева и камня фактически пройдено около 40,10 м. Plugin total=71,6513 м, независимая сумма samples=71,651306 м; max step=1,559644 м, max sample gap=0,503814 s. Есть короткий стартовый interval 0,029479 s: raw максимальная производная скорости=10,612094 м/s; для интервалов ≥0,1 s максимум=3,470264 м/s. Устойчивые 3 м/s для каждого интервала не заявляются. Watchdog проверяет step≤5 и step≤6×dt+1; после начального Spawn код не пишет transform.position, не вызывает warp/MovePosition. Каждый harvest actor position дополнительно привязан к timestamped physical sample; отдельные fabricated координаты отвергает validator.

## Запуски, restart и исправление

| Run ID в `.local/runtime/` | Mode / исход | Ready / plugin, s | До финального runner result, s | Shutdown |
|---|---|---:|---:|---|
| `7aa268c9d09d445eb7bd2a63ee2e6bfd` | GATHER / PARTIAL: segment timeout | 264,577 / 263,571 | 386,48 | GRACEFUL, native exit −1 |
| `fcdbab93166e4c80afffa9dc4f1b6e92` | GATHER / GREEN | 265,704 / 264,691 | 309,70 | GRACEFUL, native exit −1 |
| `3fc3cffcbb52481293db178ad5ac6a94` | RESTORE / GREEN | 265,824 / 263,802 | 274,51 | GRACEFUL, native exit −1 |

Первый raw result остаётся PARTIAL: Heavy prefab, wood20 реально добыто, ore найден, но NPC шёл обратно к spawn. Эти wood UID не засчитаны во второй run и не использованы для persistence. Причина: ошибочное `fsm.enabled=false` оставляло FSM в custom native work queue; patrol мог перезаписывать путь. Установленные IL и точный локальный аналог 001/003 требуют SetFsmActive(false). Исправлены этот вызов и предпочтение обычного Scientist2; добавлена native destination/stopped/path telemetry. STATIC regression дал RED→GREEN, потом offline suite и новый live. Второй run: 0 repaths, оба natural sources. Третий запуск потрачен только на independent restore; четвёртого нет.

Перед gameplay был metadata/IL gate и C#7.3 compile. Два preflight без Rust: sandbox отказал CIM port query (`24ae40ad09e04edba9a1e99e6aae362a`); тот же разрешённый preflight вне sandbox прошёл (`7357b044bdf14d83b5979a96610229f1`). Это не дополнительные live launches. Серверы работали без Administrator; UAC helper повышался только для временных firewall deny rules. Внешняя сеть тестовой копии не разрешалась ради Steam/MapCache/Unity ошибок.

Restore принял только успешный завершённый gather generation **world-7332e6c9d47f4163ac47657a090f3d10**. `.sav` SHA-256 `296C6A945CEE95AFCC0FBC8B431409217F0BDFA23C31C78740E585FE591EC30D`; inventory snapshot `B662053292BB99C4F51EAA8F4C9197B17A9D6DF0E8F30F8B607BDC5F447301E9`; actor-state `2E4C1A4DF34367B531095411E0C56CA8FCE37ABD57B2A177F0EA5919ACFFF006`. Проверены cache key, WARM state, точная generation, actual saved-world hash, snapshot hashes, graceful provenance. Run 3 хранит RestoreBinding/LoadedGeneration/LoadedSaveSHA256 и копию restore-world-proof.json. После native Load совпали все строки inventory, ActorId, ToolUid, Goal=CARRY_SAVE, Completed=[WOOD,ORE], Rejected=[6978,6975,5648]. Повторной добычи в RESTORE нет.

## Проверки и evidence

Команды live исполнял сам Codex из repo root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-All.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-NavigationProbe.ps1 -SurvivalGather -PreflightOnly
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-NavigationProbe.ps1 -SurvivalGather -StartupTimeoutSeconds 900 -NavigationTimeoutSeconds 900
# Та же gather команда второй раз только после доказанного FSM defect.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-NavigationProbe.ps1 -SurvivalGather -RestoreFrom fcdbab93166e4c80afffa9dc4f1b6e92 -StartupTimeoutSeconds 900 -NavigationTimeoutSeconds 900
```

Offline suite включает неизменённые 001/003 contracts, safety/job/firewall/cache checks, C# compile всех трёх plugin. Новые focused contracts отвергают incorrect debit, duplicate UID, invalid tool/wear, no LOS/ground/range/path, fabricated harvest location, native double yield, fixture-as-natural GREEN, wrong equipment label, corrupt snapshot/state, stale saved world и forced-shutdown restore. Это FIXTURE/STATIC, не synthetic live PASS. Финальный full offline suite после всех code changes: `.local/audit/harvest004/tests-delivery.txt`, exit 0. Fresh read-only reviewer нашёл отсутствующую связь harvest coordinates с samples; найденный counterexample исправлен RED→GREEN. FSM defect найден настоящим live, исправлен с IL-доказательством и проверен live 2/3. Отложенных Critical/Important review findings нет.

Per-run raw: `server.log`, `result.json`, `plugin-result.json`, snapshot `RustBotsSurvival.cs` с hash; gather 2 также `inventory.bin`, `actor-state.json`, `world-proof.json`. Все находятся только в ignored `.local/runtime/<run-id>/`. Игровые логи прямо содержат compiled successfully / Loaded plugin. `.local/audit/harvest004/` хранит console receipts, tests-final-code.txt, per-run summaries, owner-before/after.json, cleanup.json, allowlist.txt и delivery receipts. Metadata dumps — `.local/api-harvest004*.txt`. Не редактировались старые live receipts.

Owner audit прочитал все **3086** файлов Server до/после: **changes=0**. Final independent read-only cleanup подтвердил owned=0, broker=0, Rust/SteamCMD=0, TCP=0, UDP=0, RustBots firewall rules=0, exclusive cache/lease lock failures=0; каждый helper closed.json содержит Removed=true / RemainingProcesses=0. Native quit exit −1 сохранён без подмены: ACK, completed save, navmesh save и owned absence проверены по существующему gate. Ни owner BAT, ни updater, ни SteamCMD не запускались; ничего из owner мира/mods/config не заменялось и не публикуется.

## Scope, Git и кодировка

Baseline local master и origin/master проверен: `56247c53eecb3632c8619436d69220db5e815090`. Первоначально рабочая копия чистая, пакет 004 отсутствовал; после уточнения пользователь добавил семь постановочных файлов, они прочитаны и включены в delivery. Архитектура/версия/ограничения сверены до правок; дополнительные AGENTS, csproj/props/targets, code-map/pattern не найдены. Работа на текущем master явно разрешена пользователем.

Bounded exception: **17 публичных путей** одного gameplay slice, включая семь предоставленных task docs. 001/003 plugins, task 002, AGENTS и safety/cache/firewall/process helpers не менялись.

```text
README.md
src/plugins/RustBotsSurvival.cs
scripts/Invoke-NavigationProbe.ps1
scripts/SurvivalValidation.ps1
scripts/Test-Survival.ps1
scripts/Test-All.ps1
scripts/Test-PluginCompile.ps1
docs/agent-tasks/RUST-BOTS-004-HARVEST-TOOLS/TASK.md
docs/agent-tasks/RUST-BOTS-004-HARVEST-TOOLS/ACCEPTANCE.md
docs/agent-tasks/RUST-BOTS-004-HARVEST-TOOLS/HANDOFF.md
docs/agent-tasks/RUST-BOTS-004-HARVEST-TOOLS/GATES.md
docs/agent-tasks/RUST-BOTS-004-HARVEST-TOOLS/EVIDENCE.md
docs/agent-tasks/RUST-BOTS-004-HARVEST-TOOLS/GOAL.txt
docs/agent-tasks/RUST-BOTS-004-HARVEST-TOOLS/README.md
docs/agent-tasks/RUST-BOTS-004-HARVEST-TOOLS/PLAN.md
docs/agent-tasks/RUST-BOTS-004-HARVEST-TOOLS/API_DECISION.md
docs/agent-tasks/RUST-BOTS-004-HARVEST-TOOLS/RESULT.md
```

Git разрешён прямым запросом и TASK §5. Read-only baseline/scope: `git rev-parse --show-toplevel`, `git branch --show-current`, `git rev-parse HEAD`, `git status --short --untracked-files=normal`, `git status --short`, `git ls-tree --name-only HEAD docs/agent-tasks/`, `git ls-tree --name-only 56247c53eecb3632c8619436d69220db5e815090 docs/agent-tasks/`, `git ls-tree -r --name-only HEAD -- docs/agent-tasks/RUST-BOTS-004-HARVEST-TOOLS`, `git ls-files -- Server/`, `git check-ignore Server/rustds/owner-protection-check .local/audit/harvest004/report-check`, `git diff --stat`, `git diff --check`, `git diff --no-ext-diff -- README.md scripts/Invoke-NavigationProbe.ps1 scripts/Test-All.ps1 scripts/Test-PluginCompile.ps1`. Reviewer использовал только `git diff 56247c53eecb3632c8619436d69220db5e815090 -- scripts/Invoke-NavigationProbe.ps1`.

Первый `git ls-remote --exit-code origin refs/heads/master` не прошёл sandbox SSH deny; HTTPS-mapped ls-remote также не прошёл sandbox networking. Разрешённый повтор вне sandbox: `git -c credential.interactive=false -c url.https://github.com/.insteadOf=git@github.com: ls-remote origin refs/heads/master` подтвердил baseline и повторно сверил его перед commit. Origin config не менялся. Дополнительно `git check-ignore -v Server/Run_DS.bat Server/rustds/oxide/config .local/runtime/3fc3cffcbb52481293db178ad5ac6a94/secrets.json artifacts/harvest004-private.json` подтвердил effective ignores; `git ls-files -- Server/` пустой.

Exact staging: `git add -n -- $harvestPaths`, затем `git add -- $harvestPaths`, где $harvestPaths — 16 путей allowlist выше без RESULT. `git diff --cached --name-only` точно совпал с этими 16 путями; `git diff --cached --check`, `git diff --cached --stat`, `git diff --cached --no-ext-diff --` проверили staged artifact; patch сохранён ignored. Коммит: `git commit -m "feat: prove natural resource harvesting and survivor restore"`. Публикация: `git -c credential.interactive=false -c url.https://github.com/.insteadOf=git@github.com: push origin master`; затем `git rev-parse HEAD` и HTTPS-mapped `ls-remote origin refs/heads/master` оба дали полный implementation SHA выше.

Финальная доставка выполняется exact двумя путями: `git add -n -- docs/agent-tasks/RUST-BOTS-004-HARVEST-TOOLS/RESULT.md docs/agent-tasks/RUST-BOTS-004-HARVEST-TOOLS/PLAN.md`, затем такая же `git add --`; проверки `git diff --cached --name-only`, `git diff --cached --check`, `git diff --cached --no-ext-diff --`; `git commit -m "docs: record verified harvest tools and restart evidence"`; обычный HTTPS-mapped `push origin master`, `git rev-parse HEAD`, HTTPS-mapped `ls-remote origin refs/heads/master`, `git status --short`, `git ls-files -- Server/`. Final artifact guard сравнивает `git diff --name-only 56247c53eecb3632c8619436d69220db5e815090 HEAD` с exact 17-path allowlist; `git diff --check 56247c53eecb3632c8619436d69220db5e815090 HEAD` проверяет итоговый patch. Фактический финальный SHA/remote/status receipt сохраняется отдельно после исполнения, поскольку SHA нельзя включить в собственный commit. Broad add, branch/merge/rebase/reset/restore/stash/clean/force не применялись.

- mojibake-маркеры в изменённых файлах проверены: 17 публичных файлов, полный marker scan, совпадений нет.
- escaped Cyrillic в изменённых файлах проверены: 17 публичных файлов, отдельные Unicode/XML regex, совпадений нет.

Strict UTF-8 и отсутствие NUL/binary проверены; три фактических live RCON secrets не встречаются в публичных файлах. Git LF→CRLF warnings отражают локальную line-ending настройку, не потерю кириллицы; public code/receipts hash привязан к фактически испытанным bytes.

## Практические ограничения

Это bounded survival probe с доказанными источниками, бухгалтерией и inventory/state restart. **Cross-restart depletion ledger источников не реализован**: native ResourceEntity.Save не сериализует весь ResourceDispenser pool. Между первым и вторым запуском birch сохранил health=744, но pool снова стал 375 вместо 355; этот факт не скрыт и не принят за сохранность истощения. Сохранённая память completed/rejected sources и RESTORE без повторного gather не начисляют второй output той же транзакции, но production world economy потребует отдельного решения.

Не реализованы PlayerInventory, visible-held gear, native player melee/equivalence, crafting/bench/blueprints, bags/respawn, TC/building, PvP, кланы или 50–100 ботов. NPCPlayer/BasePlayer с RustNav статически возможен как будущий bridge, но не проверен живым переходом в 004. Source accounting — server adapter, без player animation/finish bonuses; source pool и durable transaction journal нельзя считать production-ready. Следующий Goal не начинался.
