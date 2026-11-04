# 012 — TC placement / door / first-home proof, 04.11.2026

Итог: **PARTIAL / SMOKE_DOOR_FAILED (PRE_DOOR_APPROACH) / DIAGNOSTIC_BUILD_ONLY**. Причина TC=null установлена и исправлена; настоящий native TC, собственный native autoauth, `IsAuthed` и `TC.CanBuild` доказаны. Последний smoke остановился до двери на `InvalidOperationException: No physical building approach`. Полный BUILD_SMOKE, оплаченный upkeep, Door и физический HOME_NAV не доказаны. NATURAL JOURNEY и HOME RESTORE не запускались; GREEN_HOME_BOOTSTRAP не заявляется.

## Baseline и объём

Local HEAD/master и публичный master по HTTPS совпали с `610937733286263b83c2f70577ec629ecd482b3a`. Исходно untracked только переданный пакет012; чужих изменений не обнаружено. SSH origin не имел доступного ключа, HTTPS read успешно проверен без изменения remote.

До правок прочитаны root AGENTS/README, весь пакет012, RESULT/API010–011, home module/plugin/runner/validators и installed IL. Дополнительные ancestor/nested AGENTS, csproj/props/targets и code-map/pattern не найдены. Переиспользованы debit-first intents/receipts, native Planner/socket preview, имеющиеся native TC/door/nav paths, физический isolated runner, firewall/Job Object и focused validators. C#7.3/PowerShell5.1, установленный Rust/Oxide без обновлений и новых зависимостей.

Bounded scope:15 публичных путей —12 документов в текущем пакете012 (10 входных плюс RESULT/API_DECISION) и три существующих файла: `src/home/FirstHome.cs`, `scripts/FirstHomeValidation.ps1`, `scripts/Test-FirstHome.ps1`. Это одна home-family задача; safety runner, инфраструктура, EconomyJournal, остальные plugins и старые документы не менялись. Raw, scripts аудита, source/compiler snapshots и receipts только в ignored `.local/audit/home012/` и `.local/runtime/`.

## Точная диагностика и коррекции

1. **TC=null:** `HomeTarget` ошибочно задавал `onTerrain=parent==null`. У TC `Socket_Free_Snappable` наследует `Socket_Free.TestTarget`, возвращающий именно `onTerrain`; foundation parent без female socket исключал единственный male socket. `UpdatePlacement` с пустым списком возвращает false без Phrase/debug. Коррекция `onTerrain=socket==null` сохраняет физический foundation hit/normal/parent и все native placement guards.
2. **Ошибка новой диагностики в smoke1:** inherited Unity `Object.name` у detached prefab attribute вызвал NRE. Заменён на подтверждённое managed поле `PrefabAttribute.fullName`. Regression проверяет emitted IL реально compiled plugin без исполнения DLL.
3. **Native autoauth в smoke2:** установленный `ItemModDeployable.OnDeployed` после native hook сам вызывает `AddPlayer` для фактического player. Старый guard запрещал любой непустой auth-list. Native `.sav` подтвердил ровно own engine bot и0предметов. Теперь принимается own-only autoauth, чужие IDs/items/owner/group/registration запрещены; недостающий self-add проходит тот же native hook. Receipt связан с actual actor/TC net ID/building ID.

Подробные STATIC_IL/LIVE/UNKNOWN и fingerprints — [API_DECISION.md](API_DECISION.md). Старый011 не имел branch trace: его фактический самый ранний возврат не переписывается задним числом. В012 причинная цепочка target воспроизведена парным preview, затем native TC.

## Фактические старты

| Run | Outcome | Доказательства |
|---|---|---|
| `dfd7dd03c5be4123bd0c414aee7b244d` | PARTIAL, diagnostic NRE до TC |6native Wood blocks,17committed payments,TC calls0,harvest0,107.893639м/115samples; GRACEFUL |
| `21eb7b8a5a544576998ebff9eccabb48` | PARTIAL, old autoauth guard |7native entities/18payments,TC calls1/return1;TC146687;harvest0,107.887932м/114samples; GRACEFUL |
| `65f0f52e10834a38954fa23e983304c9` | PARTIAL, PRE_DOOR_APPROACH |7native entities/18payments,TC calls1/return1,TC146584/own auth/CanBuild;harvest0,108.320404м/118samples; GRACEFUL |

Второй smoke: старый target дал male0/preview=false/Phrase=""/debug="", исправленный male1/preview=true/socket mods=true/native LOS=true/DeployVolume=false/inside=false. Reach3.1934м при native4м. Оба preview сохранили entity count/exact inventory; готовый TC напрямую не создавался. Native saved TC146687/prefab2476970476 имеет auth только own bot15 и пустой ItemContainer. Save SHA-256 `D2B2E3EDE5A1A3ABF0C2650D26153A6D5F4F3D78FC27767F58EE34C7AD71CB9C`;7097record stream проверен offline по installed Serialize IL.

| Gate | Итог после3старта |
|---|---|
| TC_PLACEMENT | LIVE: одна оплаченная попытка в каждом из smoke2/3, настоящий BuildingPrivlidge, native prefab, own OwnerID, один buildingID, group registration/saveList |
| TC_AUTH | LIVE: финальный TC146584, exact own engine ID15, native autoauth=true, adapter AddPlayer calls0, IsAuthed=true, TC.CanBuild=true, buildingID1; receipt связан с actual actor/TC/group |
| Native privilege query после полного дома | NOT_PROVEN: поздний `foundation.GetBuildingPrivilege()==tc` расположен после двери; этот этап не достигнут |
| UPKEEP | NOT_PROVEN: transfer0, TC inventory empty;1040wood остались у бота; native >=60мин не измерены, decay не отключался |
| DOOR | NOT_PROVEN: native placement calls0, оплаченный door Item остаётся в belt; open/close/collider transition не выполнялись |
| HOME_NAV | NOT_CONDUCTED:0входов/выходов; физический outdoor trace не считается home traversal |
| G2 полный smoke | REQUIRED / НЕ ПРОЙДЕН, SMOKE_GREEN не заявляется |
| G3/G4 | NOT_CONDUCTED / required, нет completed natural home checkpoint |

Точная граница последнего отказа: после TC/auth `homeStep=7`, фаза `BUILD_WAIT`, перед Door. `HomeBuildStand()` пытается выбрать внешний подход, вызывает `NavSample`, получает false и бросает исключение. Составной `NavSample` — RustNav `SamplePosition` и `Ground`; последний проверяет ray/terrain height/normal/water/capsule. Returned sample, конкретный failed subcheck и pending tile state здесь не записаны. **Почему отказал именно subcheck — UNKNOWN.** Нельзя объявлять доказанными collision, временную перестройку tiles или невозможность RustNav. Новая позиция, warp, изменение collision/agent, слепой retry и четвёртый процесс не применялись.

Финальный TC146584 имеет health100, saving/registered=true, Owner15/building1. Native save witness: auth только15,0items,7094records, `.sav` SHA-256 `6B1BA3105DD6CBEF0B99873A1C571CD9DD22530F6AAFEDEFD2525DC1E69DC97B`. Оплачено2920wood+100stones и отдельно native consumed cupboard Item1;1040wood сохранены как80+960 в прежних UID. Материалы имеют только TEST_FIXTURE provenance. Никакой upkeep credit не выдавался. Pending home intent отсутствует.

Frozen combined source SHA-256 по трём runs: `50B6C2C005BF6C9E0BF3CF48C36877AA0B7A05D114B1AA1C6BFD04EA7AC36EE4`, `3D99999D85CAB13654C5AEFD7D35F1A536155967BAEF1B79A691A06191FF0F15`, `CCC53EE7B5EBADD8CADC1093FA5B97E8CD1D1291303F30AB9B0869ED657DB1D2`. Последний точно совпал с current plugin+EconomyJournal+FirstHome. Live Oxide compilation/load подтверждены во всех трёх процессах. Финальный FirstHome source SHA `C19D947F4A7E2CF1017A0BCB656186BE0DE011B017FD3A16A1D81D7CBC67DB40`. Третий readiness272.007с/plugin-ready271.001с; это startup интервалы, не длительность compilation.

NATURAL и HOME RESTORE не проводились: два доказанных adapter-дефекта потребовали корректирующих diagnostic запусков. Третий разрешён TASK replacement clause и EXECUTION_PLAN «one other follow-up», после исправления, offline tests и независимого review. Цена решения — исчерпание общего лимита3; натуральный JOURNEY и независимый RESTORE уже не помещаются. Четвёртый запуск и дополнительный бюджет не запрашивались. TEST_FIXTURE не считается натуральным фармом или restore-source. Все smoke no-promotion; crash-atomic009 остаётся NOT_PROVEN.

## Проверки и review

Focused regressions: free-surface TC evidence/payment/no-retry; emitted diagnostic IL; own native autoauth и привязка к actual actor/TC/group. Тесты сначала RED, затем GREEN; fake foreign auth, непустой TC, неверные IDs/group, blocked/no-op/LOS/collision и повторная paid-попытка отвергаются. Полный Test-All/C#7.3 против installed DLL проходит перед каждым игровым стартом.

Независимые read-only reviews: `prelive-review.md`, `smoke1-review.md`, `smoke2-review.md` в private audit. Исправлены no-op guard отрицательного preview, natural validator coverage и внешняя привязка auth receipt. Review не объявляет live GREEN; все игровые процессы запускал только основной runner.

Финальный `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-All.ps1` — exit0 (`tests-final.txt`). Все три shutdown — GRACEFUL с ACK/native save; наблюдаемый native exit−1 сохранён, не переименован в exit0. Во всех runtimes owned process absent/ports released/firewall removed=true, cache promotion=false. Финальный независимый safety inventory: Rust/Steam/helpers/TCP/UDP/rules/open leases/live brokers/занятые locks0,28leases closed. Owner3086files SHA/length changes0;178protected cache/history files changes0. История PARTIAL010–011 сохранена. SteamCMD/updater/owner BAT не запускались.

Независимый финальный review (`.local/audit/home012/final-review.md`): Critical0, новых определённых source-дефектов/завышенных claims0; Important — реальный нерешённый pre-door approach, уже раскрытый выше; Minor, требующих правок,0. Current combined source независимо совпал с frozen smoke3. Неполный G2 не исправляется неподтверждённой гипотезой после исчерпания3/3; стоимость остановки — отсутствие Door/upkeep/HOME_NAV и natural/restore proof.

- Mojibake-маркеры в изменённых файлах проверены: совпадений0.
- Escaped Cyrillic в изменённых файлах проверены отдельно: совпадений0.

Strict UTF-8/NUL, owner/private values, credential/Steam-ID/non-loopback-IP patterns и все3RCON secrets проверены на всех15публичных путях; утечек0. Четыре legacy plugin source hashes совпали. Финальные scope/privacy checks повторяются после этого report-only closing amendment; source/tests не меняются.

Git использован по прямому разрешению пользователя и TASK012: baseline/public inspection, bounded review/scope guard, exact-path staging/commit и ordinary push. `Server/` и `.local/` ignored, в индексе отсутствуют. Команды inspection: `git rev-parse HEAD`, `git branch --show-current`, `git status --short`, `git status --short --untracked-files=all`, `git ls-remote origin refs/heads/master` (SSH отказал), `git ls-remote https://github.com/kpCat/RustOxideBots.git refs/heads/master`, `git check-ignore Server .local artifacts`, `git ls-files -- Server/ .local/`, `git diff --check`, `git diff --stat -- src/home/FirstHome.cs scripts/FirstHomeValidation.ps1 scripts/Test-FirstHome.ps1`; reviewers использовали `git diff --` этих трёх путей и `git diff 610937733286263b83c2f70577ec629ecd482b3a --` тех же путей.

Delivery через `.local/audit/home012/Stage-Exact.ps1`: `$paths` содержит ровно15путей, перечисленных в разделе scope; `git diff --cached --name-only`, `git add -n -- $paths`, `git add -- $paths`, `git diff --cached --check`, `git diff --cached --stat`, `git diff --cached --no-ext-diff -- $paths`, `git ls-files -- Server/`. Затем `git commit -m 'fix: correct native TC surface placement and own authorization'`, `git -c credential.interactive=false -c url.https://github.com/.insteadOf=git@github.com: push origin master`. Проверка: `git rev-parse HEAD refs/remotes/origin/master`, тот же HTTPS rewrite с `ls-remote origin refs/heads/master`, clean status и private index checks. Никаких force/reset/rebase/clean/stash/branch/merge/broad add. Развёрнутые команды exact paths сохранены в `.local/audit/home012/git-commands.txt`; delivery SHA/public equality фиксируются после commit/push в `delivery.json` и финальном ответе: report не может включать свой будущий commit hash.
