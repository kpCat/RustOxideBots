# RUST-BOTS-009 — результат 04.11.2026

Итог: **GREEN_WORLD_DEPLETION** — bounded graceful-restart durability доказана для двух NATURAL узлов и одного player-derived NPC. Native добыча, оплаченный accounted craft, исходные Item UID/condition/личность, восстановление depleted pools и повторный NOOP проверены в двух независимых RustDedicated. Первые две попытки остаются PARTIAL; raw evidence не переписывался.

**CRASH_ATOMIC=NOT_PROVEN; CRASH_RECOVERY=OFFLINE_ONLY; MULTI_MAP_E2E=NOT_CONDUCTED.** GREEN_CRASH_SAFE не заявляется. Native quit/save и offline fault fixtures не доказывают interrupted-process crash reconciliation.

## State matrix

| Требование | Уровень | Факт |
|---|---|---|
| Native actor / движение | LIVE | ScientistNPC : BasePlayer, RustNav, 201.842964966 м, 291 samples, 7 completed legs |
| NATURAL source / payment | LIVE | 53 hits, credit200 wood+107 stones, debit400+214, wear, adapters0 |
| Journal / save binding | LIVE+OFFLINE | 165 sequenced/checksummed records; exact journal/state/actor/inventory/.sav/generation proof |
| Stable source incarnation | LIVE, bounded | Actual fromDisk object witness, unique geometry, prefab/type/profile, exact map/wipe/save |
| Independent depletion restore | LIVE | Tree500→100, ore750→536, native DestroyFraction, expected fractions |
| Replay / соседи | LIVE | Второй apply NOOP/NOOP, 38/3 соседних pools/fractions unchanged, credits0 |
| Craft / identity / inventory | LIVE | Один paid hatchet UID106675; тот же actor, rock, 7stones, axe; harvest/craft/kit replay0 |
| Wrong world/source/journal/recipe/UID | OFFLINE_ONLY | Реальный helper и независимый validator, fail closed/no reward retry |
| Map/wipe isolation | LIVE same-world+OFFLINE multi-map | Stable WorldKey при смене .sav; procedural/custom/map/seed/size/format/wipe negatives |
| Crash / repeated restart chain | Не доказаны LIVE | Fixtures OFFLINE_ONLY; ещё один restart из нового checkpoint не запускался |
| Safety / owner / history | Проверено после4 запусков | Owner changes0, processes/ports/rules/open leases/occupied locks0, historical changes0 |
| Code / delivery | OFFLINE+LIVE load | Test-All exit0, C#7.3 compile, реальный Oxide v0.1.6, cumulative allowlist18 |

## Baseline, разрешения и бюджет

До правок local HEAD, tracking origin/master и публичный HTTPS master совпали с **58d384e23a8200387d2574f935273c3056ab5b0a**, ветка master; дерево содержало только восемь supplied docs009. SSH/sandbox network недоступны; использован HTTPS без изменения remote config.

Исходный TASK ограничивал запуски максимумом3. После двух PARTIAL владелец явно ответил о подготовленном исправлении: **«Разрешить ещё 2 старта, общий лимит 4»**. Выполнены ровно4 старта, последние2 — corrected JOURNEY+RESTORE. Пятого старта, второй карты, owner launch/update и controlled crash не было. Обязательное дополнение о любых совместимых картах выполнено в том же scope; оно не разрешает owner writes.

Rust protocol **2635.289.1**, Unity **6000.3.15x1-13**, Oxide.Rust **2.0.7839**, Changeset168909. Runtime не обновлялся. API/IL и UNKNOWNs — [API_DECISION.md](API_DECISION.md).

| Installed artifact | SHA-256 |
|---|---|
| Assembly-CSharp.dll | 04FB89520F18A1920C1B1A350B82DD24A4258F31D97B82496971A9CC7A49DCB7 |
| Rust.Data.dll | 1D62BAEF9B339F0416E6529618365C1ECAD01791A833E77E76EB6C8464406104 |
| Oxide.Rust.dll | 2128121E34B55BB1550D43E62842B87EA3720059F13DC84F97D8C7DD465C3423 |
| RustDedicated.exe | EFAC429DB737EB4B32A2BFC48029B4BE6FF475336958F4557F891F17255FFD38 |

## Все LIVE попытки

Времена UTC. Полные immutable receipts, логи, credentials, owner hashes и firewall paths только ignored в .local/runtime/run-id и .local/audit/economy009.

| № / run | Version / PID / старт | Readiness | Outcome |
|---|---|---:|---|
| 1 / 35d435c481484edd9682260d30d11ac7 | v0.1.3 / 44744 / 11:36:59 | 268.8367123с | PARTIAL: low-health tree исчерпан; следующий hit без yield, no adapter retry |
| 2 / eeb1767d19084083a92f5778fa914b4d | v0.1.4 / 57920 / 11:47:53 | 271.7154622с | PARTIAL: Local natural route unavailable до первого hit |
| 3 / 3f85a956a2d54c4c8bdd7450997e0b9e | v0.1.6 / 68816 / 12:22:45 | 272.9718907с | GREEN JOURNEY: native gather, paid craft/held, completed save/proof |
| 4 / 19dec76c099647dca062731daee4cd55 | v0.1.6 / 66012 / 12:31:10 | 269.861585с | GREEN RESTORE: exact identity/items, depleted sources, replay NOOP |

Оба последних лога подтверждают реальную compilation/load v0.1.6 и readiness. RustNav fully built35344 tiles, из cache loaded13027 tiles. Все4 процесса unelevated, под собственным kill-on-close Job Object; ActiveStore/COM проверили inbound/outbound block rules всех test EXE. Отдельные physical runtime/plugin/config/data, случайные secrets, loopback28965–28968. GRACEFUL/ACK/native save подтверждены, наблюдаемый native quit exit **−1** обработан явно. Последние cache promotions успешны.

Первая попытка:63wood против debit126, rock UID92220 condition100→96.326004, wood UID94209. NATURAL tiny birch6982: pool375→249, fraction1→0.664, health196.799911→−4.800089. Pool-only admission не учитывал сохранённый низкий health при reset pool. После11 committed hits последний PREPARED остался IN_DOUBT:35records, SHA **5AB44FD8348F5BFB422F138BF4CDA0F9DC8A226BAD3007CF45B7D87746B3121E**. Никакой компенсации/recovery этого intent; test inventory удалён штатным cleanup. Untouched discovery6975 не объявляется depleted source. Raw PARTIAL сохранён.

v0.1.4 добавил admission по pool/health, destroyFraction, rounding и maximum gatherScale×3; source record создаётся перед actual hit. Второй run выбрал healthy beech, но остановился до добычи на local waypoint: travel/hits/craft/source records0. Физический подтип старого отказа UNKNOWN: лог не разделял sample/ground/path gates. v0.1.5 отделил map/wipe identity от save proof. v0.1.6 переиспользовал WorldRoam36/24/12м safe progress candidates, native radius2.5, Ground и complete local path≤80м, затем Survival bounded source rejection. Другие режимы сохраняют прежние параметры; teleport/позиционного обхода нет. Prelive independent review clear; третья попытка завершила физический маршрут и экономику. Старые failed receipts не стирались ради GREEN.

## Источники, identity и добыча

Динамическое обнаружение текущего мира; координаты ниже — измерения, не runtime constants. NetID используется вместе с exact saved-incarnation proof; incarnation UUID — только journal key.

| Поле | NATURAL tree | NATURAL ore |
|---|---|---|
| Saved UID / incarnation | 7210 / 98249089ba074db599dc2e60c15041fc | 2823 / 53c3ee83011a445c9b9e4497bfb2b468 |
| Prefab | assets/bundled/prefabs/autospawn/resource/v3_temp_forest/american_beech_a.prefab | assets/bundled/prefabs/autospawn/resource/ores/stone-ore.prefab |
| Type / population | TreeEntity / procmap_v3_temp_forest_deciduous | OreResourceEntity / ores |
| Position | [24.4471684,8.436977,−222.981354] | [98.274086,16.4595833,−136.832077] |
| Rotation | [0,0.933167458,0,−0.359442025] | [0.09528102,−0.9324042,0.0462934859,0.345544368] |
| Scale | [0.8196248,0.8196248,0.8196248] | [0.524594367,0.524594367,0.524594367] |
| Hits / credit | 40 / 200wood | 13 / 107stones |
| Pool initial→depleted | 500→100 | 750→536 |
| Fraction initial→depleted | 1→0.2 | 1→0.714666665 |
| Native debit / destruction | 400 / 200 | 214 / 107 |
| Saved post-gather health | 199.999664 | 357.333466 |

Итого debit614 = credit307 + native destruction307; adapters0,new drops0. Owned held rock UID98288 condition **100→82.29802**. Native initiator/weapon, reach/LOS/ground, item chains и source pool проверены независимо. Движение **201.842964966м**,291samples,7completed legs, max step1.699037349м, max gap0.591125с; manual position writes0.

## Крафт, личность и предметы

Loaded stonehatchet blueprint: **200wood+100stones→1output**. Roam native ItemCrafter unavailable; честный **SERVER_ACCOUNTED_CRAFT**, без fake timed queue. Native UseItem consumed wood UID100299×200 и stones UID106659×100, затем создан один stonehatchet UID106675 condition/max100/100.

Личность **avatar-007-6f3b4acb0e2e4764a4fc92098e6ff22a**, intent **avatar007-3f85a956a2d54c4c8bdd7450997e0b9e**, Goal COMPLETE/CraftStatus CRAFTED сохранены. Concrete actor net96421→106986 — новая native оболочка той же личности, без connection/Steam impersonation.

| Original UID | После JOURNEY и RESTORE |
|---|---|
| 98288 | rock×1, condition82.29802/max100, BELT slot0 |
| 106659 | stones×7, MAIN slot1 |
| 106675 | stonehatchet×1, condition100/max100, BELT slot1, active |

008 lifecycle сохранён: strict incoming UID/container/binary gate, sanitation только ephemeral heldEntity в проверенной protobuf-копии, native Load и два parent passes. Axe held net106676→108785, GetItem UID106675, owner/parent106986, held flag=true. Source/foreign item/entity checks passed. RESTORE: starter kit=[],harvests=[],craft=null,movement legs0. Duplicate intent denied, inventory unchanged; новых Item/оплаты нет.

## Depletion restore и NOOP

По одному geometric candidate на source; оба — actual ResourceEntity instances из native OnEntityLoaded(fromDisk=true). Проверены UID/prefab/type, position1мм, rotation/scale/bounds, population, item definition/startAmount, saved health и native load policy. Новый respawn/map-only объект не получает старый witness. Все планы валидированы до debit.

| Source | Native reload | Apply | Итог | Второй pass | Соседи |
|---|---|---:|---|---|---:|
| Tree7210 | pool500/fraction1 | debit400 | pool100/fraction0.2 | NOOP100→100 | 38unchanged |
| Ore2823 | pool750/fraction1 | debit214 | pool536/fraction0.714666665 | NOOP536→536 | 3unchanged |

Native DestroyFraction с одной положительной категорией, actual result проверен; replay credits0. Tree health199.999664 сохранён; ore saved357.333466→current500 — установленный StagedResourceEntity.Load reset, не новый source. InputSnapshotHealth отдельно от output checkpoint; original economics не переписаны.

## Map identity и snapshot binding

Native World getters и SHA actual .map дают kind/level/seed/size/format/MapKey; плюс persistent SaveRestore.WipeId дают WorldKey. Cache key/generation, SHA .sav, URL и transient Entity ID не являются постоянной identity мира. WorldKey directories изолируют старые данные при map/seed/size/version/wipe change; unknown identity блокирует Load/debit. Discovery/навигация не содержат resource/NPC/road coordinates или test seed;424242/2000 только безопасный test fixture.

Фактический мир: PROCEDURAL,Procedural Map,seed424242,size2000,format289, map SHA **1F09D94EC8DA9DAC4E32908817A16BCC167D7B5A654E90DB19042E1501F17A47**, wipe **d8209fc56a19464b8b042fa872751434**.

- MapKey **4F644EE04C9A774971FEEE0B64222CB25F51AD05EE3A45330C36FF704ACD2D46**.
- WorldKey **50D9C07452A0FF03ABBCE2AB6493EF75581D3B82D30D0F3CB74481C6E887C8CE**, неизменен в обеих proofs.
- Compatibility **b37a93c03ae490a52662af2f167343eda017ce450d373f43abced8fb91b58b23**, отдельный installed-runtime gate.

| Checkpoint | JOURNEY output / RESTORE input | RESTORE output |
|---|---|---|
| Generation | world-4f082a1c535d471989ee22a20dc31e9e | world-cee320627654459188b50c7f24a92658 |
| .sav SHA | 8AFC1A78360B44725F0B5A1D49D2C1053EE310A1EE252FDEB26CBC647A7B7D58 | 40E83E047124ACD14BE6AD809A8C94E4F10802C815518AF9DDF891CCB536A7A9 |
| Inventory SHA | BAE10634AFAC3E64566CD61F71E4D610314E5D03B2968F03E01D1CFFBAA78A79 | 29B37665F8325FAB18267E6DAA1EFD76B9DE8D255A4FA579AB30FE5CC6B8A815 |
| Actor SHA | 5792D1E38087902D65045E0771AF09F0E6A5251DF3B2EA2ACDDBE1ECD38B3C73 | DB50755F75C0C995E7879627929A6E5352D9ECC843B4F77D1C929DFD6A1DDE12 |
| Economy state SHA | 3C301E3C01240E7615562D79A44293A433323CA9F561D7C287787AB81A994FDC | 6D5E51C0F85C0779E929CF5994AC91D14E37D203E99291A8829C5E39956FDDB7 |

Actor/inventory hashes меняются из-за новых ephemeral owners/held, economy state — из-за output health checkpoint. Exact economic rows и immutable source/payment records сохранены. Оба proofs независимо валидны. Ещё один native RESTORE из нового checkpoint не проводился.

## Journal, negatives и review

165records = header+53×(PREPARED/APPLIED/COMMITTED)+craft(PREPARED/DEBITTING/DEBITED/OUTPUT_CREATED/COMMITTED). Journal byte-identical в двух процессах: **792E60CC18695193A410F13A3B7BAEDEBE8BDB8DA0EBAC70FA4BEC9000245641**. Before-hit и before-debit стадии durable Flush(true); completion только после actual payment/result. Recovery не создаёт output из неподтверждённого intent. Checksums/proof hashes защищают integrity, не hostile administrator, переписывающего все артефакты.

OFFLINE_ONLY tests: реальный helper/files и independent parser/validator; duplicate intent/concurrent writer, пять interruption checkpoints, partial payment/output uncertainty, empty/torn/corrupt journal, wrong world/generation/actor/recipe/output UID, missing/ambiguous/new-respawn witness, wrong prefab/position/geometry, lower/partial pool, staged-health input/output, nonfinite receipts. Cross-world отказы не меняют journal SHA. Same map/wipe reopens paid intent при другом отдельном save proof; procedural/custom/map hash/level/seed/size/format/wipe changes отказывают и изолируют namespaces. Другая карта не запускалась: это contracts, не multi-map gameplay E2E.

Independent review закрыл staged-ore semantics, Windows writer/read sharing, finite telemetry (NaN reviewer воспроизвёл PS7; исходный PS5.1 RED не заявляется), ore×3 counterexample, input/output health boundary. Focused RED→GREEN сохранены локально. Финальный reviewer независимо проверил successful raw pair/journal/proofs, native debit/credit, original UID/intent, apply/NOOP; ledger anomalies не найдено. Fixtures/review не заменяют LIVE.

## Проверки, сохранность и ограничения

Финальный `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-All.ps1` — **exit0** после v0.1.6 route refinement, до последних2 live. Старые regression suites, economy/map contracts и C#7.3 compile пяти plugins passed. Итоговый/captured v0.1.6 source+helper SHA **CD5DCEF7C5AEA12E43572353DE27D2C281FC2E0B2F5C001A053138BAEEFEF1CD**, одинаков в обеих LIVE; код после запусков не менялся.

Safety audit **12:36:37UTC**: Rust/SteamCMD/helper processes0,TCP/UDP test endpoints0,firewall rules0,live brokers/open leases/occupied locks0; все19leases closed. Owner **Server/:3086 файлов, SHA/length changes0**. 22historical raw-файла007–008 unchanged; source001/003/004/006 unchanged. SteamCMD/update/validate/BAT не запускались; Rust/Oxide, owner configs/mods/saves не менялись.

- mojibake-маркеры в изменённых файлах проверены;
- escaped Cyrillic в изменённых файлах проверены.

Public audit: все18paths, strict UTF-8/NUL, обе encoding checks, owner values, credentials/Steam IDs, RCON secrets всех4runs, non-loopback IP. Server/,.local/,artifacts/ ignored; Server tracked0. Raw/секреты не публикуются.

GREEN ограничен graceful парой. Не доказаны production crash atomicity/live interrupted payment recovery, arbitrary map-only incarnation/законный respawn continuation, длительная restart chain, custom-map gameplay/все карты,50–100NPC,timed native craft queue/client animations. Map-independent architecture и fail-closed contracts реализованы; это не всемирный E2E. Новый Goal/Slice не начинался.

## Scope и Git

Cumulative allowlist **18public paths**: supplied8docs009+PLAN/API_DECISION/RESULT; src/economy/EconomyJournal.cs,src/plugins/RustBotsAvatarSurvival.cs; scripts/Invoke-NavigationProbe.ps1,EconomyValidation.ps1,Test-Economy.ps1,Test-PluginCompile.ps1,Test-All.ps1. Bounded exception/approval — [PLAN.md](PLAN.md). Старые результаты007–008 задним числом не изменялись.

Git прямо разрешён TASK/пользователем. Inspection: `git branch --show-current`, `git rev-parse HEAD`, `git rev-parse origin/master`, `git rev-parse HEAD origin/master`, `git status --short`, `git status --short --untracked-files=all`, `git remote -v`, `git ls-remote origin refs/heads/master`, `git ls-files Server`, `git ls-files -- Server/`, `git check-ignore Server/ .local/ artifacts/`; HTTPS `git -c credential.interactive=false -c url.https://github.com/.insteadOf=git@github.com: ls-remote origin refs/heads/master`. Exact review `git diff --stat -- <exact paths>`, `git diff --no-ext-diff -- src/plugins/RustBotsAvatarSurvival.cs`, `git diff --check`; reviewer only разрешённые diff. Cumulative `git diff --name-only 58d384e23a8200387d2574f935273c3056ab5b0a` и baseline+HEAD.

Delivery: `git add -n -- $paths`, `git add -- $paths` exact arrays; `git diff --cached --name-only`, `git diff --cached --check`, `git diff --cached --stat`, `git diff --cached --no-ext-diff -- $paths`; commits `feat: add guarded world economy journal and recovery probe`(a5f7413),`fix: separate map identity from economy save checkpoints`(2b58704), финальный `fix: complete bounded world economy restart proof`. Обычный `git -c credential.interactive=false -c url.https://github.com/.insteadOf=git@github.com: push origin master`, затем local/tracking/public SHA и clean-tree checks. Force/broad add/reset/rebase/stash/clean/history rewrite не применялись.

Финальный SHA/public equality/clean receipt после commit — ignored .local/audit/economy009/delivery.json и финальный ответ. Commit не может содержать собственный SHA. GREEN_WORLD_DEPLETION следует из raw proof, не из факта доставки.
