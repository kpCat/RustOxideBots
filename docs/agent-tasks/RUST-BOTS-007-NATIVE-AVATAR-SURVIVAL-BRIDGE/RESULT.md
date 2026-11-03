# RUST-BOTS-007 — результат 2026-11-03

Итог: **PARTIAL**. Один ScientistNPC нативно добыл ресурсы, оплатил accounted craft и держал именно изготовленный UID87251. Независимый restart остановлен защитным guard до Load; exact UID/active/held restore **не подтверждён**, GREEN_AVATAR_SURVIVAL не заявляется. Выполнены все три разрешённых игровых старта; четвёртого не было.

## Выполнение и бюджет

HEAD, локальный origin/master и публичный HTTPS master перед изменениями совпали с baseline `6834429b2c6b85e896f3b7dfdb9eaaae370fffb2`, ветка master. Исходное рабочее дерево содержало только распакованный пакет 007. SSH аутентификация недоступна; HTTPS использован без изменения remote config и истории.

| Игровой старт | Run ID | Фактический результат |
|---|---|---|
| 1 | a6f6b9d7ef034c0ba83f696b84082670 | PARTIAL: 99.20303 м, 9 legs к 8 natural trees; 0 добычи/крафта/выдачи, только стартовый rock |
| 2 | d5f2cbcbecd54c2dae6b772d327b8e3a | GREEN journey: native gather → оплаченный accounted craft → exact crafted UID native held |
| 3 | 346f0025715b4c22ace0cc9501f39f37 | Plugin PARTIAL до Load: live transient held reference; raw runner FAILED из-за ошибочной классификации partial validator, исправленной offline после запуска |

Причина дополнительного старта: action ground check ошибочно использовал луч для пустой точки уже после рождения BasePlayer и пересекал собственную капсулу. Версия0.1.1 переиспользует проверенный action guard 004: bound RustNav agent + terrain/water; source ownership, реальная дальность и LOS сохранены. Исходная версия и полный PARTIAL evidence первого старта сохранены. Четвёртый старт запрещён. Preflight-only проверки игровыми стартами не считаются.

Один bridge `src/plugins/RustBotsAvatarSurvival.cs`, без второго Gen2 actor, склада или смены стека. C#7.3 / PowerShell5.1. Из прежних файлов изменены только runner, перечень compile targets и Test-All. Четыре исторических plugin source имеют прежние SHA/length. Дополнительные ancestor/nested AGENTS, csproj/props/targets и code-map/pattern-файлы не найдены. Прочитаны AGENTS/README, весь пакет007, API/results005–006 и ближайшие AvatarProbe/Survival/runner/validation аналоги.

## LIVE: один avatar и настоящая добыча

Prefab: `Assets/Rust.Ai/Agents/NPCPlayer/HumanNPC/Scientist/ScientistNPC_Roam.prefab`, ScientistNPC : HumanNPC : NPCPlayer : BasePlayer. IsNpc=true, connection отсутствует, ID выделен движком как NPC bot ID; реальная Steam identity не назначалась. PlayerInventory main/belt/wear принадлежат этому же actor. До добычи native Strip безвозвратно удалил rifle.lr300×1, syringe.medical×2, hazmatsuit_scientist×1; их UID отсутствовали глобально. Baseline стал пустым. Единственная раскрытая стартовая выдача — native rock×1 UID81010 в belt0, condition/max100; это starter kit, не добыча.

Logical ActorId успешного эпизода: `avatar-007-82563576b443412aa71b2cd5444206d4`. Один NPC в каждом процессе, enableSaving=false, без client/Steam impersonation, position writes или teleport. Scheduler/wake fixes006 применены только к собственному NPC; скорость3 выставляется после каждого SetDestination.

Journey readiness266.481 с, live Oxide compile/load подтверждены. Rust protocol2635.289.1, Oxide.Rust2.0.7839. RustNav warm cache, seed424242 / size2000. Из195 непрерывных samples независимо восстановлено **73.602157477 м**, пять complete-path legs; максимальный шаг1.554353 м, интервал0.541077 с, скорость3.277521 м/с. Добыча связана с измеренными actor/time/source coordinates и реальными прибывшими legs. Range-отказ1.903619 м при loaded rock maxDistance1.25 + разрешённом tolerance0.5 сохранён, порог не повышался.

**GAMEPLAY_MECHANISM: NATIVE_PLAYER_GATHER**. Active native rock/BaseMelee, HitInfo.InitiatorPlayer=this avatar, WeaponOwned=true, DidGather=true. Native ResourceEntity/ResourceDispenser выполняет выдачу и износ; AdapterCredit=0, новых drops=0. Ground, range, LOS и natural provenance проверены.

| Natural source | Ресурс | Удары | Pool до→после | Реальная выдача |
|---|---|---:|---:|---:|
| TreeEntity6982 | wood | 21 | 375→123 | 126 |
| TreeEntity6981 | wood | 15 | 250→100 | 75 |
| OreResourceEntity5648 | stones | 13 | 750→536 | 107 |

Всего wood201 +stones107; native destroy fraction дал pool debit402 +214. Разница debit/yield явно учтена, бесплатного bonus/adapter output нет. Rock condition100→83.63402, max100; вся цепочка wear сверена с native Item rows.

## LIVE: оплата и изготовленный native held UID

**GAMEPLAY_MECHANISM: SERVER_ACCOUNTED_CRAFT**. Native queue context недоступен: в установленном Roam prefab отсутствует ItemCrafter, PlayerInventory.Initialize не добавляет его. Live availability guard=false, inventory before=after, queue0; CraftItem не вызывался. STATIC/IL и live receipts разделены в API_DECISION. Native player queue не заявляется.

Loaded stonehatchet recipe: wood200 +stones100 →1, default-known/allowed=true, bench0, time15 metadata. Фактическое списание native UseItem:

| Native UID | Предмет | До | Списано | После |
|---|---|---:|---:|---:|
| 82929 | wood | 201 | 200 | 1 |
| 87236 | stones | 107 | 100 | 7 |

После оплаты создан **новый stonehatchet UID87251**, amount1, condition/max100. Accounted transaction заняла0.005249 с; фиктивного ожидания native15 с нет. Из main2 тот же UID перемещён в belt1. Native active UID=87251; HeldEntity BaseMelee87252, GetItem UID87251, owner и parent равны actor79238, held flag1024=true. Связь удерживалась повторными проверками до snapshot. Ни fixture axe, ни UID65008, ни второй NPC не использовались.

Live guards отказали до мутации: missing ingredients, missing recipe, фактический rifle.ak bench gate, duplicate intent, absent UID и существующий foreign item. Inventory/active selection и foreign item unchanged. Это защитные guards перед native API, не заявление о встроенном отказе UpdateActiveItem для произвольного UID.

## Сохранение и restart

Journey завершён GRACEFUL, native exit−1, ACK/полный native world/RustNav save подтверждены, cache promotion=true. World generation `world-2ef374a7b00c4f91b2b9db6e6817698b`. Привязка до третьего процесса:

- .sav SHA256: `C6D1F894CC31472E9F7A27E7037DDD7FCC4843393641589E8C19F2E1D74342AD`;
- native PlayerInventory snapshot SHA256: `F1C56E0F4E92099112251B236B05108839D596108173613D6137FA3073E128D4`;
- actor state SHA256: `FF08CD6A1D8FF692E76761E36C98236B6CB57A3E9F7243E9B1630B6817728441`;
- source SHA256 обоих успешных сценариев: `0983E604512F4CD2A40F96E4964694C430B3C9192B38EDCA7CBE17BE1141A5ED`.

Native Save(true,true) включил main/belt/wear. До Load предусмотрены проверки protobuf UID/role/slot/amount/condition, существующих world UID, foreign entity refs и generation. Кандидат restore очищает stale heldEntity только в памяти и вызывает штатный `Item.RecalulateParentEntity(false)`; этот путь **не достигнут live**.

Третий independent процесс PID62528 (journey PID62456), readiness267.091 с, загрузил точную generation/.sav выше. Его единственный новый ScientistNPC actor87565 нормализован, inventory пуст, starter/gather/craft=0. До Item Load защитный guard отказал `Foreign transient entity or unsupported nested snapshot`. Read-only wire audit snapshot по Serialize IL Rust.Data установил worldEntity=0 и nestedItems=0 у всех четырёх Items; main items не содержат held refs. Первый belt item — rock UID81010 / saved heldEntity81011, затем axe UID87251 / held87252. Следовательно первый отказ вызван `serverEntities.Find(81011)!=null`. Тип и ownership разрешившейся entity не были записаны и остаются **UNKNOWN**; это не доказательство успешного восстановления либо безопасного повторного использования refs.

Saved state и exact native Items сохранены в snapshot, но новый actor не получил их: State=null, Inventory=[], active/held=null, Persistence.Restored=false. Логическая identity и выбор UID после restart **NOT_VERIFIED**. Новый похожий топор не выдавался, foreign entity не трогалась. Следующий отдельный gate — диагностировать lifecycle сохранённых held entities и согласовать их безопасное восстановление без второго Item/чужого ownership; это не разрешение на четвёртый старт007.

Raw runner классифицировал этот plugin PARTIAL как FAILED, поскольку `Assert-AvatarSurvivalRestart` сравнивал отсутствующий partial state как будто это GREEN. Focused fixture воспроизвёл ошибку RED→GREEN; итоговый validator сохраняет partial status/reason и проверяет exact equality только для GREEN. Raw result.json/plugin-result.json третьего запуска не переписаны. Фактов нарушения ресурсного баланса, owner data или cleanup не обнаружено, поэтому итог задания **PARTIAL** по ACCEPTANCE.

## Проверки, безопасность и поставка

Baseline и prelive Test-All001–006 +007 PASS; все пять plugins компилируются против installed DLL с C#7.3. Три focused fixture groups закрывают balances/default loadout, native held exact UID и route continuity, duplicate/foreign/missing guards, slot/condition restore, stale world/hash snapshots. RED→GREEN зафиксирован для поддельных маршрутов, отсутствующего paid output, подмены condition/owner и HeldEntity.GetItem UID. Независимое prelive ревью нашло и помогло исправить native parent lifecycle и same-belt MoveToContainer edge case.

После каждого из трёх стартов: 3086 owner files, SHA/length изменений0; Rust/Steam/helper процессов0, TCP/UDP тестовых портов0, rules0, open leases0, live brokers0, занятых locks0. Финальный audit16:53:34 UTC: все14 historical/new leases closed, locks свободны. Третий shutdown также GRACEFUL, ACK/native save, exit−1, owned process absent/ports released/firewall removed=true. RustDedicated работал без admin через kill-on-close owned Job; privileged helper управлял только собственными firewall rules. Owner BAT/SteamCMD/updater не запускались, owner worlds/config/mods не копировались и не менялись.

Raw logs/result/plugin-result, source snapshots, inventory/state/world proofs, owner hashes и secrets остаются только в ignored `.local/runtime/<run-id>/` и `.local/audit/avatar007/`. Публичный scope — exact17 paths из audit allowlist. Server/ полностью ignored/untracked. Strict UTF-8/NUL, owner-value/credential/Steam ID/non-loopback IP scans и сравнение всех трёх RCON secrets выполнены по exact allowlist. Финальная поставка SHA/remote receipt — в ignored delivery.json и итоговом ответе.

- mojibake-маркеры в изменённых файлах проверены;
- escaped Cyrillic в изменённых файлах проверены.

Git явно разрешён пользователем/TASK. Использованы bounded inspection: `git rev-parse HEAD`, `git rev-parse origin/master`, `git branch --show-current`, `git status --short`, `git ls-remote origin refs/heads/master`; HTTPS retry `git -c url.https://github.com/.insteadOf=git@github.com: ls-remote origin refs/heads/master`; scope checks `git ls-files -- Server/`, `git check-ignore -v Server/rustds/RustDedicated.exe Server/rustds/oxide/config .local/audit/avatar007/owner-before.json`, `git diff --check`, `git diff --stat`, `git diff --name-only`, `git diff -- scripts/Invoke-NavigationProbe.ps1`. Exact staging/commit/push — финальный шаг; remote SHA не может содержаться в собственном commit, receipt будет в ignored delivery.json и итоговом ответе. Force/reset/rebase/clean/stash/broad add не используются.

Delivery inventory: `git status --short --untracked-files=all`, `git diff --cached --name-only`, `git diff --cached --check`, `git diff --cached --stat`, `git diff --cached --no-ext-diff --`; `git add -n -- $paths`, `git add -- $paths` только для17 exact allowlist paths; `git commit -m 'feat: add native avatar survival bridge with guarded restart evidence'`; `git -c credential.interactive=false -c url.https://github.com/.insteadOf=git@github.com: push origin master`; тот же HTTPS prefix с `ls-remote origin refs/heads/master`; `git rev-parse HEAD origin/master` и `git status --short`. Публикация разрешена пользователем для честного PARTIAL.

Команды проверки: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-All.ps1`; journey `scripts/Invoke-NavigationProbe.ps1 -AvatarSurvival` (два запуска); restore `scripts/Invoke-NavigationProbe.ps1 -AvatarSurvival -RestoreFrom d5f2cbcbecd54c2dae6b772d327b8e3a` (один). Все через тот же PowerShell runner, без ручных команд владельца. Final Test-All receipt: `.local/audit/avatar007/tests-final.txt`.

PERSISTENT_WORLD_SOURCE_POOLS и CRASH_ATOMIC_CRAFT — **NOT_IMPLEMENTED**: обязательный следующий gate — durable per-world depletion/transaction journal с idempotent reconciliation. PLAYER_RENDERED_ANIMATION, native weapon damage/PvP, raids/clans, real Steam session и production50–100 — **NOT_VERIFIED / вне scope**. Восстановление logical avatar не означает непрерывную native Steam-сессию. Следующий Goal не начинался.
