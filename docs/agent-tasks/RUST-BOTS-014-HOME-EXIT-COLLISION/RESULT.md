# RUST-BOTS-014 — результат 04.11.2026

**PARTIAL / COLLIDER_IDENTIFIED для нового отказа на входе.** В одном изолированном smoke точно установлен MeshCollider настоящего деревянного doorway и контакт нижней полусферы NPC с его порогом. Это реальная пенетрация, безопасность её исключения не доказана. Причина именно исторического outbound отказа013 остаётся **COLLIDER_UNKNOWN**: новый запуск остановился раньше и не достиг выхода.

Runtime clearance не ослаблен. Исправлен доказанный пробел наблюдаемости: полный collider receipt теперь сохраняется до throw. Телепортации, уменьшения персонажа, отключения коллизий, изменения native навигации или бесплатного строительства нет. `GREEN_HOME_BOOTSTRAP` и `DIAGNOSTIC_HOME_GREEN` не достигнуты.

## Матрица фактических доказательств

| Gate | Класс | Результат |
|---|---|---|
| G0 baseline | STATIC | master; local HEAD, origin/master и actual public HTTPS master = `f9c56323d559e27dcf8d303524bd8e7123c5e4bd`; исходно только supplied пакет014 untracked |
| API/IL | STATIC_IL | Installed Physics/Collider/native capsule/BasePlayer/door/RustNav, C#7.3; без загрузки игровых DLL для анализа |
| Контракты | OFFLINE_ONLY | RED→GREEN: missing overlap evidence, actual native body binding, фактический CalculatePath; collider/path/fake crossing negatives |
| Native compile/readiness | LIVE_DIAGNOSTIC | Oxide compilation/load, готовность сервера и RustNav подтверждены |
| Дом / TC / дверь | LIVE_DIAGNOSTIC | Шесть настоящих Wood BuildingBlock, paid native TC и Door, одна группа, регистрация/поддержка/save, own-only TC auth |
| Upkeep | LIVE_DIAGNOSTIC | Original UID144553/144554:80+960wood перенесены в TC; protection0→11176.1191min, rate134wood/1440min, decay включён |
| Collider | LIVE_DIAGNOSTIC | На335.5896s ровно3 overlaps: own doorway, own foundation, self; guard `OVERLAP` из-за doorway |
| Порог | STATIC_ASSET + native penetration | Exact installed mesh74 vertices; аналитическая глубина11.2792556mm согласуется с native11.2793455mm; crest30.900mm выше feet |
| HOME_NAV | PARTIAL | Только предварительный IN candidate; accepted crossings0, TC_REACHED0, выход/закрытие двери не выполнены |
| SMOKE isolation | LIVE_DIAGNOSTIC | Новый physical install/identity/Oxide, явные TEST_FIXTURE, no promotion/save-ready |
| NATURAL / independent RESTORE | NOT_VERIFIED | 0 запусков: G2 не пройден, complete natural checkpoint отсутствует |
| Защита owner/history/cache | SHA-256 audit | Owner3086 и protected1182 файла, изменений0; история010–013 сохранена |
| Cleanup | Runtime + independent audit | GRACEFUL; собственных процессов, тестовых портов, правил, открытых leases, живых brokers и занятых locks0 |

## Единственный live запуск

Run `508c7d34b98149d49498d25e99efd495`, PID24560, старт04.11.2026 в22:41:32 Chisinau (`20:41:32.313044Z`). Readiness265.8314s, plugin-ready264.8280s. До этого выполнен только preflight7e6e3f2c3f7e46ea98933ffa69a875b3 без игрового PID. Всего **1 live**; SMOKE_2/NATURAL/RESTORE не запускались. Offline Test-All использует собственные stub fixtures, не настоящие SteamCMD/updater/server launches.

Physical fork использовал проверенную чистую generation `world-45fabb2276794f4abdbace642b1b814c`, save SHA `0D17022038534B023EFFCBCB464EC2CD69444A75317F33B2442D17BF51E6EF28`. Это новая diagnostic-only копия, а не failed013 checkpoint. Frozen combined source SHA `BCD407D9858DCB876B24BC0E68B191C3E7F852940E9EC68EC5D3786ECA41BE7A` совпадает с current/reconstructed source; FirstHome SHA `30316B067D3287A1D0874035CD216658E9687D0D30853B19AC6A0902D027D0F8`.

Один ScientistNPC/BasePlayer actor142724, native bot15; без Steam impersonation. Fixture3960wood+100stones, пять original UID, явные TEST_FIXTURE receipts; natural harvest0. Девятнадцать committed платежей, восемь native Planner placements, paid retries0, pending intent отсутствует. Foundation146503; walls146574/146668/146671; doorway146674; roof146677; TC146680; Door146982; owner15/buildingID1. Существующие validators отдельно проверили структуру/site/TC/auth/дверь/upkeep и final exact economic chain, несмотря на PARTIAL навигации.

Native actual capsule: radius0.5m, height1.8m, center(0,0.9,0), directionY, enabled/nontrigger, unit scale; endpoints совпадают с proof capsule. Отдельно записан agent height2.0m. Геометрия не менялась. Open door hinge collider действительно переместился; сама дверь отсутствует в overlap set отказавшего tick.

## Точный отказ и предел вывода

Tick335.5896s: actor position(−27.0086765,9.364136,−237.853271), `Inside=true`, `OwnedFloor=true`, `DoorOpen=true`, pendingfalse, current и recalculated `PathComplete`. Native capsule endpoints feet+(0,0.5,0)/(0,1.3,0), r0.5; mask−5/Ignore triggers. `Ground=false` старого composite, native groundedtrue и owned floortrue сохранены раздельно.

Полный overlap set:

| Collider | Native identity / геометрия | Native penetration |
|---|---|---|
| DOORWAY | MeshCollider instance−836046, entity146674; Collider.Name=`assets/prefabs/building core/wall.doorway/wall.doorway.wood.prefab`, entity Prefab=`assets/prefabs/building core/wall.doorway/wall.doorway.prefab`; own, layer21 Construction, enabled/nontrigger; bounds center(−27.23319,10.7663946,−237.919434), extents(0.188964844,1.5,1.50891113) | 0.0112793455m; direction(0.280285656,0.9598528,0.0110628344); no query error; именно он blocking по исходному guard |
| FOUNDATION | MeshCollider instance−833642, entity146503, own, layer21; center(−25.7390118,7.816393,−237.860489), extents(1.66185,1.55000043,1.66185) | 0.00225684047m вверх; исходное foundation exclusion сохранено |
| NPC_SELF | CapsuleCollider instance−786124, actor142724, layer17 Player(Server), enabled/nontrigger | self query не выполняется; self исключён исходным guard |

Foundation floor ray: y9.366393, normal(0,1,0), floor на2.257mm **выше** feet; doorway floor hits0. Native path и grounded flag не отменяют фактический контакт тела. У порога nonconvex MeshCollider; неподдержанный `ClosestPoint` для него не вызывался, сохранены bounds и настоящая `ComputePenetration`.

Bounded offline extract точного установленного prefab разрешил mesh `wall.doorway.collision` из assetscenes/content bundles. Ближайшая нижней полусфере точка — local(0.09451845,0.12864300,0.05727162), edge triangles(1,4,5)/(6,5,4). Feet localy0.097743: crest выше на30.900mm. Аналитическая глубина отличается от native менее чем на0.00000009m. Это corroboration контакта порога; decoded vertex AABB отличается от Unity cooked collider bounds и не объявляется идентичным. Native query остаётся первичным доказательством.

До rejection сохранён `CROSSING_CANDIDATE IN, Accepted=false`: требуемая halfwidth0.5766688m при aperture0.6000002m. Это номинальное геометрическое пересечение, **не принятый проход**. Accepted HomeCrossing и обычный Sample данного tick не вызваны после throw. Все140 предыдущих samples дают104.4899513m против total104.489944m; max gap0.53885s/max step1.604375m, manual position writes0. Ни TC_REACHED, ни CROSSED_IN/OUT, ни Door.Close не заявляются.

Наличие порога, направленная вверх пенетрация и движение агента не доказывают benign supporting surface ниже feet. Поэтому blanket doorway/terrain/foundation ignore или уменьшение capsule запрещены; безопасное исправление locomotion из этих данных не установлено. Исторический013 OUT tick не содержит collider receipt, и новый inbound не подменяет его доказательство. Независимый G2 reviewer подтвердил PARTIAL и отсутствие основания для corrected SMOKE_2. Неиспользованный бюджет не расходуется на догадки.

## Проверки, безопасность и доставка

До live и после него полный `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-All.ps1` завершился exit0; installed C#7.3 compile также exit0. Prelive reviewer нашёл два validation gap — native endpoints/world radius/actor binding и actual CalculatePath status — оба закрыты отдельными RED→GREEN. После live reviewer независимо сравнил обе PHYSICS receipts server.log↔plugin-result и frozen/current source SHA. Benign-support correction и соответствующий GREEN fixture не реализованы, потому что безопасность контакта не доказана.

Raw только ignored: `.local/runtime/508c7d34b98149d49498d25e99efd495/{server.log,result.json,plugin-result.json,RustBotsAvatarSurvival.cs,home-evidence/}`. Скопированы49 native evidence files с SHA-проверкой. Private `.local/audit/home014/`: installed IL/hashes, три RED/GREEN пары, Test-All logs, reviews, collision/mesh/geometry/build/trace audits, owner/protected inventories, public/safety audits и delivery.json. Исходный raw013 и protected history/cache не переписывались.

Штатный quit/ACK/native save и наблюдаемый native exit−1 сохранены; shutdown GRACEFUL, owned process absent/ports released/firewall removedtrue, promotionfalse. Native shutdown save не является completed natural home checkpoint. Owner3086 SHA/length неизменны; protected1182 source/history/raw/cache files неизменны. SteamCMD/updater/owner BAT не запускались, чужие процессы не останавливались. Runtime содержит только native bot/test identifiers; private owner values/RCON не публикуются.

- Mojibake-маркеры в изменённых файлах проверены.
- Escaped Cyrillic в изменённых файлах проверены отдельно.

Все16 exact public paths прошли strict UTF-8/NUL, owner private values, credential/Steam-ID/IP patterns и actual run RCON secret checks без вывода секретов. Финальный fresh-context independent review не нашёл code/isolation/privacy/false-GREEN blockers; две правки отчётов (таблица live API и различие Collider.Name/entity Prefab) сверены с raw и внесены. После финальных report edits проверки повторены перед staging. Review и доставка фиксируются в ignored `final-review.md`/`delivery.json`; SHA после commit сообщается в финальном ответе, без самоссылочного изменения отчёта.

Изменены только `src/home/FirstHome.cs`, `scripts/FirstHomeValidation.ps1`, `scripts/Test-FirstHome.ps1`; дополнительно supplied10 документов014 и новые PLAN/API_DECISION/RESULT. Exact allowlist16 — bounded exception одной document family; AGENTS, avatar/economy/runner, прежние001–013 и owner не изменены. Родительские AGENTS, отдельные code-map/pattern и csproj/props/targets не найдены.

Whitespace exception: полный `git diff --cached --check` выявил единственный исходный trailing space в supplied `TASK.md:20`. Входной пакет сохранён без косметических правок. Отдельный staged whitespace-check трёх product paths и новых PLAN/API_DECISION/RESULT проходит; полный raw вывод сохранён в `stage-console.txt`. Это не скрытый успешный full whitespace-check и не изменение требований TASK.

Git разрешён прямым запросом/TASK014. Использованные inspection-команды: `git status --short`, `git status --short --untracked-files=all`, `git branch --show-current`, `git rev-parse HEAD refs/remotes/origin/master`, `git remote get-url origin`, `git ls-remote origin refs/heads/master` (SSH отказ), временный `git -c url.https://github.com/.insteadOf=git@github.com: ls-remote origin refs/heads/master`; `git ls-files -- docs src scripts AGENTS.md README.md .gitignore` для protected inventory, `git ls-files -- Server/ .local/ artifacts/`, `git check-ignore Server .local artifacts`, `git diff --check`, `git diff --stat -- <три product paths>`, `git diff --numstat -- <три product paths>`, reviewer `git diff <baseline> -- <три product paths>`.

Доставка использует только exact16-path `git add -n -- <allowlist>`, `git add -- <allowlist>`, `git diff --cached --name-only`, `git diff --cached --check`, `git diff --cached --stat`, `git diff --cached --no-ext-diff -- <allowlist>`, `git commit -m ...`, обычный `git -c credential.interactive=false -c url.https://github.com/.insteadOf=git@github.com: push origin master`. После push — повторная local/tracking/public SHA и clean-tree/private-tracked0 проверка. Persistent origin config, force/reset/rebase/clean/stash/branch/merge/broad add не используются.

Следующая отдельная bounded задача: исследовать native vertical locomotion на поднятом doorway threshold — actual collider-specific floor/sweep/step measurements и installed movement IL; только затем доказанное исправление маршрута/движения без warp/resize/collider ignore и полный диагностический вход→TC→выход→закрытие. До него natural/restore gate остаётся закрытым. CRASH_ATOMIC=NOT_PROVEN, multi-map E2E не проводился; product/manual gate не отмечен passed.
