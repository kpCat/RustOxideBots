# RUST-BOTS-008 — результат 04.11.2026

Итог: **GREEN_RESTORE** в пределах native inventory/held lifecycle. В независимом RustDedicated восстановлены исходная логическая личность 007 и все четыре оригинальных Item UID. Изготовленный в 007 stonehatchet **UID 87251** активирован с новым native HeldEntity **89451**, owner/parent — новый NPC **87574**. Заменяющий Item не создавался. Исторический 007 остаётся **PARTIAL**.

## Baseline и бюджет

До правок local master HEAD, tracking origin/master и публичный HTTPS master совпали с `811220edbcbed8ffcaca804306e66cf6f40d1de6`. Изначально были только восемь untracked task-документов 008. SSH недоступен; HTTPS проверен без изменения remote config.

Использован **один полноценный игровой старт 008**: RESTORE `2b10b4d7c99b4bad93a00bf6dc3fd630`, PID 35980. Повторного JOURNEY и второго/третьего старта не было. Источник — реальный JOURNEY 007 `d5f2cbcbecd54c2dae6b772d327b8e3a`, PID 62456. Новый процесс стартовал 04.11.2026 в 10:42:17 UTC, readiness 266.1703549 с, Oxide compile/load v0.1.2 подтверждены. Rust protocol 2635.289.1, Oxide.Rust 2.0.7839, RustNav warm cache.

## Source proof и STATIC_IL

Источник допущен существующим строгим binding gate: прежний GRACEFUL/ACK/native save, cache key, generation, фактические SHA всех cached world files, inventory и actor-state совпали. Старый PARTIAL RESTORE `346f0025715b4c22ace0cc9501f39f37` не подгонялся под успех. SHA всех 14 верхнеуровневых raw-файлов двух исходных runs остались прежними.

| Исходный артефакт | Факт |
|---|---|
| Cache key | b37a93c03ae490a52662af2f167343eda017ce450d373f43abced8fb91b58b23 |
| Loaded generation | world-2ef374a7b00c4f91b2b9db6e6817698b |
| Exact .sav SHA-256 | C6D1F894CC31472E9F7A27E7037DDD7FCC4843393641589E8C19F2E1D74342AD |
| Source inventory SHA-256 | F1C56E0F4E92099112251B236B05108839D596108173613D6137FA3073E128D4 |
| Source actor-state SHA-256 | FF08CD6A1D8FF692E76761E36C98236B6CB57A3E9F7243E9B1630B6817728441 |
| Tested plugin SHA-256 | 8891D1151B67E7A7EFC594E564D3522C2D436A91190DD012272123C035A4839A |

Независимая проверка прежнего JOURNEY заново проверила physical trace: 73.602157477 м, 195 samples, 5 legs, максимальный шаг 1.554353 м; также natural debit, wear и recipe payment. Это сохранённое LIVE_JOURNEY evidence 007, а не новая добыча 008: native wood 201 + stones 107, оплаченный SERVER_ACCOUNTED_CRAFT. Native player crafting не заявляется.

Установленные DLL/EXE имеют прежние хеши; metadata/IL решение — в [API_DECISION.md](API_DECISION.md). Item.Load копирует heldEntity в EntityRef, который разрешает номер в текущем server realm. ItemContainer.Load восстанавливает оригинальные UID/slot и raw parent, затем требуется установленный native parent lifecycle. Исправление очищает только heldEntity в уже проверенной deserialized копии, до Load. UID, amount, condition, slots, container UID и original binary/state не меняются ради восстановления. Native ItemModEntity создаёт новый held prefab; ручного SetParent/forcedOwner нет.

## CONFLICT_DIAGNOSIS — фактический новый процесс

Исторический тип коллизии **81011 из 007 остаётся UNKNOWN**: его тогда не записали. В 008 этот номер отсутствовал до и после Load. Для второго saved held ID обнаружен реальный alias:

| Saved ref | До и после native restore |
|---|---|
| rock Item 81010 → held 81011 | Find отсутствует; parent/owner/item отсутствуют |
| axe Item 87251 → held 87252 | IOEntity; `assets/prefabs/io/electric/lights/sirenlightorange.prefab`; net 87252; parent=null; associated Item=null; IsDestroyed=false; in test world=true; probe-owned=false |

Для IOEntity owner network ID не предоставлен этим held API и явно UNKNOWN, персональный OwnerID не публикуется. Одинаковые before/after receipts и проверки на последующих ticks подтверждают неизменность наблюдаемых полей лампы; plugin не вызывает её Kill/SetParent/transfer. Ссылка на неё не попадала в Item.Load. Получены сразу оба случая: отсутствующий старый ID и занятый чужой test-world entity ID.

## LIVE_RESTORE — оригинальные предметы и native ownership

Восстановлен `ScientistNPC : BasePlayer` без connection/подмены Steam identity. Старый actor net 79238 заменён новым представителем той же логической личности net 87574. ActorId `avatar-007-82563576b443412aa71b2cd5444206d4`, Goal COMPLETE, ToolUid 81010, ProductUid/ActiveUid 87251, завершённый craft intent/status неизменны.

Все native containers сохранили UID и получили нового owner 87574: MAIN 79239 / 24 slots, BELT 79240 / 6, WEAR 79241 / 8; WEAR пуст. Native Load действительно выполнен, original incoming UIDs перед ним глобально отсутствовали.

| Item UID | Предмет | Amount | Condition / max | Role / slot | Новый held net |
|---|---|---:|---:|---|---:|
| 81010 | rock | 1 | 83.63402 / 100 | BELT / 0 | 89450 |
| 82929 | wood | 1 | 0 / 0 | MAIN / 0 | — |
| 87236 | stones | 7 | 0 / 0 | MAIN / 1 | — |
| 87251 | stonehatchet | 1 | 100 / 100 | BELT / 1 | 89451 |

Мировой Item count непосредственно вокруг синхронного Load: **1230 → 1234**, ровно четыре original snapshot UID. Остальные Item rows неизменны. Оба новых held имеют GetItem.uid соответствующего оригинального Item, owner/parent 87574; повторный native parent pass не создал второй held. Два parent passes, пять equipment samples за 1.998078 с: ActiveItem UID 87251, BaseMelee net 89451, GetItem UID 87251, owner/parent 87574, native flag 1024=true. Dangling/stale alias не наблюдался.

RESTORE receipts: StarterKit=[], Harvests=[], Craft=null, movement legs=0; повторной оплаты/выдачи/крафта нет. Нормализован только default loadout вновь созданного probe NPC. Короткий movement leg после restore не запускался: acceptance сосредоточен на Load/ownership/held, физический JOURNEY источника валиден.

Новый inventory snapshot SHA `029BE5DC419A8AA39AE725A642B7E13DCF57C64966E72799AB4C92DEF87D84C8`, actor-state SHA `E78D1BF04F54E6F64973631D1858B277A6230DA71807FCA487AB06826416DC2A`. Binary/state hashes закономерно отличаются из-за новых held/owner net IDs; independent wire audit и validator подтверждают прежние Item/container UID и экономические атрибуты. Original source snapshots сохранены неизменными.

## OFFLINE_FIXTURE, review и safety

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-All.ps1` прошёл до live, включая 001–007 regression и C# 7.3 compile всех пяти plugins против installed DLL. Focused fixture RED→GREEN воспроизвёл принятие недоказанного restore-receipt; отрицательные варианты проверяют aliases, отсутствие native held, incoming UID presence, повторные UID, wrong role/slot/condition, changed foreign owner, лишние Items, replay kit/harvest/craft, corrupt snapshot/world generation/hash и cleanup races в существующих safety tests. Fixtures доказывают контракт валидатора, а не выполнение Unity/native Load в offline.

Независимое prelive read-only review закрыло: ошибочный PARTIAL при экономическом нарушении в Setup; неполную связь held-ledger с активным ProductUid; пустые WEAR/foreign containers и unsupported empty nested inventory. Исправлен также PS5 fixture clone, чтобы вложенные массивы не сериализовались как wrapper; каждый мутируемый fixture сначала проходит неизменённым. Оставлен консервативный gate разных old/new held numbers: законное повторное выделение отсутствующего старого номера даст PARTIAL, без искусственного изменения allocator. Live получил разные номера и этот риск не проявился.

GRACEFUL quit, ACK, complete native world/RustNav save и cache promotion=true. Native quit exit −1 сохранён как фактический результат установленного shutdown path. Cleanup audit 10:47:22 UTC: Rust/Steam/helper processes=0, TCP/UDP test endpoints=0, firewall rules=0, open leases=0, live brokers=0, occupied locks=0; все 15 исторических/new leases закрыты. RustDedicated работал без admin в собственном kill-on-close Job Object, privileged helper обслуживал только временный firewall lease. Ручных команд владельца не требовалось.

Owner Server/: **3086 файлов, SHA/length changes=0**. SteamCMD, update/validate, BAT и установка Rust/Oxide не запускались. Исторические plugins 001/003/004/006 неизменны. Raw evidence/secrets остаются ignored в `.local/runtime/<run-id>/` и `.local/audit/avatar008/`; `git ls-files -- Server/` пуст, `.gitignore` закрывает весь Server/ и `.local/`.

- mojibake-маркеры в изменённых файлах проверены;
- escaped Cyrillic в изменённых файлах проверены.

## Доставка и границы

Exact allowlist: 15 публичных файлов — три code/test файла, 11 документов 008 (восемь supplied + PLAN/API_DECISION/RESULT), только добавленная ссылка в RESULT 007. Обоснованный bounded scope записан в PLAN. Корневой AGENTS, README, runner/cache/firewall/Job Object, updater и прежние producer plugins не изменены. Public audit проверяет strict UTF-8/NUL, оба encoding scan, owner values, credentials/Steam IDs, RCON secrets и non-loopback IP.

Git явно разрешён пользователем и TASK. Bounded inspection: `git status --short --branch`, `git rev-parse HEAD`, `git rev-parse origin/master`, `git ls-remote origin refs/heads/master` и HTTPS URL fallback, `git ls-files -- Server/`, `git check-ignore -v Server/rustds/RustDedicated.exe Server/rustds/oxide/config .local/audit/avatar008/owner-before.json`, `git diff --stat -- src/plugins/RustBotsAvatarSurvival.cs scripts/AvatarSurvivalValidation.ps1 scripts/Test-AvatarSurvival.ps1`, `git diff --` для этих трёх файлов при независимом review, `git diff --numstat`, `git diff --check`. Final exact-path staging/review/commit и обычный `push origin master` — последний шаг доставки; итоговый SHA, remote equality и clean-tree receipt сохраняются в ignored `delivery.json` и финальном ответе, поскольку commit не может содержать собственный SHA. Force/reset/rebase/stash/clean/broad add не используются.

Final delivery commands: `git status --short --untracked-files=all`, `git diff --cached --name-only`, `git add -n -- $paths`, `git add -- $paths` (только массив 15 exact allowlist paths), `git diff --cached --check`, `git diff --cached --stat`, `git diff --cached --no-ext-diff -- $paths`, `git commit -m 'fix: restore native avatar inventory and held lifecycle'`; обычный `git -c credential.interactive=false -c url.https://github.com/.insteadOf=git@github.com: push origin master`; HTTPS `ls-remote origin refs/heads/master`, `git rev-parse HEAD origin/master`, `git status --short`. Цель — scope guard, exact diff review и прямо разрешённая доставка в master.

Production world depletion/crash journal, player animation, PvP и масштабирование 50–100 NPC остаются вне 008. Новый Goal/Slice не начинался.
