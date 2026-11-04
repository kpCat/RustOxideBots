# RUST-BOTS-016 — результат 05.11.2026

**PARTIAL / PASSAGE_UNSAFE.** Выполнены два настоящих изолированных BUILD_SMOKE; оба остановлены на первом небезопасном контакте. Настоящий проход OUTSIDE→INSIDE_TC→OUTSIDE→CLOSE DOOR не достигнут. Во втором запуске одновременно измерены реальные doorway и foundation front-edge контакты; безопасного основания продолжить наблюдение не было. **After-contact evolution — NOT_MEASURED**, native step/resolution/stuck/устойчивый KINEMATIC_CLIP — UNKNOWN. Не следует выдавать остановку диагностики за доказательство отсутствия любого возможного native step.

GREEN_HOME_BOOTSTRAP и DIAGNOSTIC_HOME_GREEN не достигнуты. После smoke2 выполнен обязательный STOP016: третий PID, NATURAL и independent RESTORE не запускались. Физический product goal остаётся нерешённым; следующие шаги требуют иной доказанной native входной геометрии или отдельного безопасного способа измерить compound contact, в пределах новой задачи.

## Baseline и scope

Перед правками local HEAD, origin/master и public GitHub master совпали: `673810c885520524471c179ece79b6bd932b34a5`, ветка master. Исходно untracked только предоставленный пакет016. Изменены `src/home/FirstHome.cs`, `scripts/FirstHomeValidation.ps1`, `scripts/Test-FirstHome.ps1`; добавлены PLAN/API_DECISION/RESULT и поставлены десять исходных файлов пакета016. Exact public allowlist —16 файлов. Runner/cache/firewall/OwnedServerProcess, owner Server и история001–015 не изменялись.

Реализован отдельный BUILD_SMOKE watcher с запрошенным интервалом25ms и записью actual dt, native pose/velocity/rotation/Rigidbody/capsules, OverlapCapsule и ComputePenetration, предыдущей позы, capsule sweep/initial overlap, support/forward floor rays, RustNav sample/path/corners/pending, door/mesh/aperture. Observe-only frames всегда Accepted=false; actual nonself overlap/sweep никогда не становится Clear. Любой terminal outcome останавливает native agent. В ordinary FirstHome наблюдатель недоступен, physical guard стал строже.

## Настоящие запуски

| Факт | Smoke1 | Smoke2 |
|---|---|---|
| Run | `ec94c9a706574d74b3a36a7732a5c2e0` | `b8df0f7e39b44ab4b120c603637993c9` |
| PID |44264|44556|
| Старт Chisinau05.11.2026 |00:11:57|00:35:22|
| Native readiness |266.7948s|266.9543s|
| Policy |1|2|
| Итог |PARTIAL/UNSAFE/DOOR_OR_APERTURE|PARTIAL/UNSAFE/SWEPT_OBSTACLE|
| Final cleanup report Chisinau05.11.2026 |00:17:48.802|00:41:08.792|

Последняя строка — время записи уже завершённого cleanup report, а не выдуманное точное время native process exit. Оба native quit имеют exit−1 после shutdown/ACK; оба runner подтверждают GRACEFUL, owned process absent, ports released и firewall removed. Smoke1 frozen combined source SHA `7669AB1F06DE6D344B0AD4CCC797BE26C4B8C4990FF8F8BB6CF4AC29AF9E82CB`; smoke2 `A2666DCA61546D1A6FBB3ACACB5B1ACF2EDA57C3D51A282D1E56BA084128DA53`. Saved source и фактический plugin source в isolated install совпадают по SHA.

Оба — отдельные physical diagnostic forks из trusted pristine generation `world-45fabb2276794f4abdbace642b1b814c`, save SHA `0D17022038534B023EFFCBCB464EC2CD69444A75317F33B2442D17BF51E6EF28`, no promotion. Это не failed-home checkpoint и не натуральный фарм. До smoke1 был preflight `540fd59c3f5d45b4a8738218bf2c58d1` без game PID; offline Test-All создаёт stub fixtures, не реальные Rust/SteamCMD/update процессы.

### Smoke1 — измеренный ранний контакт

Live Oxide compilation/load и native RustNav readiness подтверждены. Native оплаченные шесть Wood BuildingBlock, TC и Door;19 economic operations и8 Planner placements, TEST_FIXTURE3960wood+100stones; TC собственная авторизация и11176.1191min protection. Existing structure/site/payment/TC/door/upkeep validators отдельно прошли, pending intent нет, natural harvest0, save/promotion нет.

На340.1706s p=(−27.7797279,9.112886,−237.822128), native doorway penetration0.0167371333m, MTD=(−0.8572853,0.5135387,−0.03660568). Portal normal≈−0.538233m, lateral≈0.1235m. Actual terrain support есть, дверь открыта; NPC ещё ниже foundation top. Standard native r0.5/h1.8 сохранён. Строгий full-radius diagnostic aperture test остановил уже первый контакт; принятых IN/OUT/TC событий0.

Independent mesh analysis подтвердил нижнюю переднюю кромку: triangles(7,8,9)/(8,10,9), closest local(−0.12254577,0.09831964,0.12543864), predicted depth0.0167376405m, отличие от native≈0.5µm. Это более ранний кадр подхода, чем014, а не новое измерение при старой высоте. Один контактный кадр не доказывает движение после контакта, clipping, native stuck или native resolution. Outbound013 остаётся UNKNOWN.

Потребовалась bounded correction диагностического дизайна, описанная с ruling в API_DECISION/PLAN. Policy2 учитывает реальную толщину frame и сечение капсулы, forward native own-floor ray и согласованные low-edge MTD/sweep признаки. Политика production clearance не ослаблялась; time/travel/depth/growth stops не сбрасываются. Поэтому после второго smoke задача обязательно заканчивается, даже если останется третий свободный PID.

### Smoke2 — compound contact, продолжение недопустимо

Native source frozen перед запуском: FirstHome SHA `6AB75F36B3ABD24A8889FCB38AA23E47B0D1E6EA89C425EEFE92142979FEE031`, validator `765B74C31FF26CCA2AA11B55BCFBA82C055E9528A2377D16D9E2F04B858EF636`, tests `34C48F886B0C5D18A475E77608782B720B96C4EF66165B1E2934784685D1FD26`. Independent pre-smoke2 review сопоставил эти хеши; native live compilation/load подтверждены.

Семь clear watcher frames, затем один unsafe contact frame. Последний интервал336.221344→336.244324s: фактический шаг37.217mm, Y уменьшился на3.579mm. Agent velocity magnitude≈1.612m/s; Rigidbody kinematic=true/gravity=false/Discrete, его velocity=(0,0,0). Native full capsule r0.5/h1.8, enabled/nontrigger, unit scale с обычной float погрешностью; agent height2, baseOffset0. Body/coords/collider не менялись. Path и независимый CalculatePath — Complete, pending=false; это не отменило реальные контакты.

| Одновременный native контакт | ComputePenetration depth | MTD | Sweep |
|---|---|---|---|
| Own Wood doorway lower edge |19.329010mm|(−0.8784607,0.472964555,−0.06790661)|distance16.250448mm, hit y9.364712|
| Own Wood foundation front edge |0.111729mm|(−0.8896552,0.451420426,−0.06879986)|distance37.096225mm, hit y9.366393|

Feet находились на274.341mm ниже отдельно измеренного forward foundation top; реальная текущая опора — terrain, не плоская foundation surface. Doorway low-edge candidacy Policy2 сама по себе согласуется с измерениями, но foundation contact имеет сильную горизонтальную MTD и не соответствует native floor-support допуску. Foundation swept hit также не соответствует разрешённому support contact. Guard правильно остановил compound collision, не исключил own foundation и не увеличил penetration epsilon.

На этом кадре `Clear=false`, `LegacyClear=false`, `Accepted=false`; IN/OUT/TC_REACHED0, door open подтверждена, закрытия после выхода не было. Source не выдал HOME_NAV_GREEN, save-ready или cache promotion.19 native economic operations,8 paid placements, fixture3960wood+100stones, transferred original UID upkeep11176.1191min снова независимо валидированы; natural harvest0, pending intent отсутствует.

Prior-pose ComputePenetration для обоих swept collider вернул `Intersects=false`. Сохранённые native out Distance/Direction при false не имеют геометрического смысла и не интерпретируются как физические расстояния/глубины. Из одного текущего контактного кадра нельзя вывести последующее разрешение контакта или сравнить глубины разных процессов как временной рост. Не было разрешённого continuation tick после контакта; требуемое наблюдение native evolution остаётся недостигнутой частью задачи. Новый smoke ради ещё одного исключения не запускался.

## Native строительные альтернативы

Installed native foundation.steps/ramp и реальные costs/socket/support contracts исследованы. Применение/оплата не выполнены: совместимые native parent/socket transforms, skin75/150, фактическая stability/TC registration и физически безопасная RustNav высота у lip не доказаны. Добавление требует versioned home schema и restore witnesses. Wood→Stone doorway имеет практически ту же нижнюю контактную геометрию и не устраняет lip при записанной высоте. Нет доказанного paid native fix; speculative ramp launch не выполнялся. Детали и ограничения — API_DECISION.

## Проверки и evidence

До каждого PID выполнены installed C#7.3 compile и PS5.1 Test-All/negative contracts, independent read-only review. Сохранены RED→GREEN наблюдения: отсутствующий observation validator, пространственно ложная опора, low-edge/slab candidacy и причина deepening/depth-bound. Пять focused contract groups16–20 закрывают real collider/support/sweep/legacy/diagnostic risks; OFFLINE_ONLY fixtures не подменяют Unity live. Compile имеет одно предупреждение CS0618 для подтверждённого installed Rigidbody.velocity getter; компиляция успешна, API не выдуман.

Raw остаётся только ignored `.local/runtime/ec94c9a706574d74b3a36a7732a5c2e0/`, `.local/runtime/b8df0f7e39b44ab4b120c603637993c9/` и `.local/audit/home016/`. Там находятся server.log, plugin-result.json, result.json, frozen combined source, actual secrets, durable native payment receipts, summaries, native meshes/API, review reports, owner/protected/safety/public audits. Оба raw набора по58 файлов зафиксированы SHA-манифестами; исторические raw001–015 неизменны. Публичный отчёт содержит только обезличенные факты isolated test.

После обоих запусков: owner3086 файлов, SHA/length изменений0; protected1372 файлов, изменений0. Safety audit22:42:26Z: Rust/Steam/helpers/TCP/UDP/firewall rules/live broker/open lease/lock failures0. Все32 исторических firewall leases закрыты, rules удалены, живых brokers нет. Native quit exit−1 сохранён, не скрыт. SteamCMD/updater/owner BAT, owner mods/world/config и installed DLL не изменялись/не запускались. Тестовые собственные processes закрывались только через owned Job, без kill по executable name.

- mojibake-маркеры в изменённых файлах проверены;
- escaped Cyrillic в изменённых файлах проверены.

Отдельный exact16path аудит подтвердил strict UTF-8/NUL, owner-value/credential/Steam-ID/non-loopback-IP guards и отсутствие обоих фактических RCON passwords в публикуемых файлах. Финальные audit JSON и полный список команд/выходов сохранены локально.

## Git: разрешение и точные команды

Git использовался по прямому запросу пользователя и TASK016 для baseline/tree/artifact inventory, exact scope/staging/commit и обычного push. Ниже ledger команд; реальные delivery SHA и clean-tree подтверждение записываются после freeze в ignored `.local/audit/home016/delivery.json` и финальный ответ. Никаких reset/rebase/clean/stash/force или изменения истории.

```text
git rev-parse HEAD
git rev-parse origin/master
git branch --show-current
git remote get-url origin
git status --porcelain=v1
git ls-files -- docs src scripts AGENTS.md README.md .gitignore
git diff --stat 673810c885520524471c179ece79b6bd932b34a5 -- src/home/FirstHome.cs scripts/FirstHomeValidation.ps1 scripts/Test-FirstHome.ps1
git diff --unified=5 673810c885520524471c179ece79b6bd932b34a5 -- src/home/FirstHome.cs scripts/FirstHomeValidation.ps1 scripts/Test-FirstHome.ps1
```

Exact staged scope audit подтвердил16 файлов из `.local/audit/home016/allowlist.txt`, private Server tracked0 и чистый whitespace diff. `$paths` в следующих командах — ровно этот проверенный список: три перечисленных рабочих файла и13 файлов текущего пакета016. Scope сначала сравнивается с полным status; чужой index или иной файл останавливает staging.

```powershell
git diff --cached --name-only
git status --short --untracked-files=all
git diff --check
git add -n -- $paths
git add -- $paths
git diff --cached --check
git diff --cached --stat
git diff --cached --no-ext-diff -- $paths
git ls-files -- Server/
git add -- docs/agent-tasks/RUST-BOTS-016-PHYSICAL-HOME-PASSAGE/RESULT.md
git diff --name-only
```

Авторизованная поставка после freeze/review использует следующие exact команды; окончательные exit codes, commit/tracking/public SHA и clean-tree result фиксируются уже после commit в `delivery.json` и финальном ответе, без циклического self-SHA в этом документе:

```text
git commit -m "feat: add bounded physical home diagnostics for task 016"
git push origin master
git rev-parse HEAD refs/remotes/origin/master
git -c credential.interactive=false -c url.https://github.com/.insteadOf=git@github.com: ls-remote origin refs/heads/master
git ls-files -- Server/ .local/ artifacts/
```

При недоступности SSH допустим тот же ordinary push через HTTPS transport override без изменения remote/config/history. Ни broad add, ни публикации Server/.local/artifacts нет; reset/rebase/merge/force не разрешались и не выполнялись. Independent final review и точные staged patch/scope checks находятся только `.local/audit/home016/`.
