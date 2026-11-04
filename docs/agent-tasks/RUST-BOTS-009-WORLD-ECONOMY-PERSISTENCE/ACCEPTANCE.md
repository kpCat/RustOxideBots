# ACCEPTANCE — из чего складывается доказанный результат 009

| Gate | GREEN_WORLD_DEPLETION (все обязательно) | Evidence |
|---|---|---|
| SOURCE | NATURAL tree и/или ore реальной карты, native player gather, уникальный узел + доказанный source key между 2 процессами | prefab, position, type, pool and source identity |
| PAYMENT | pool уменьшился, native Item UID/amount увеличились только на реальную добычу, condition инструмента ухудшилось | before/after native ledger, no adapter double award |
| SAVE | durable journal bound exact world/cache generation и native .sav + inventory/actor hash; initial/updated pools stored | journal manifest/hash, completed native save, ignored raw |
| RESTART | отдельный RustDedicated, exact world, source найден однозначно; после reload pool <= recorded depleted and conserved | native pool/fraction before/after, actor/held/inventory restore |
| REPLAY | второй apply того же journal → verified NOOP, без повторного depletion/Item credit | source ledger and exact replay receipt |
| NEGATIVE | bad source/world/recipe/journal/UID rejected with 0 mutation | independent fixtures; live if feasible |
| CRAFT | paid installed recipe, one unique product/intent; recovery/replay denies duplicate output | debit UID/amount, output exact UID/condition, restored intent |
| SAFETY | 0 owner file changes, test processes/ports/firewall/leases/locks cleaned | hashes, cleanup audit |
| CODE/GIT | Test-All, live load/compile, mojibake/escaped checks, exact paths, ordinary push `master`, no Server tracked | independent validator, commit SHA |

**Outcome policy:**

- `GREEN_WORLD_DEPLETION` — два независимых live processes доказали правильную persistence/NOOP конкретных NATURAL узлов, native rewards и стабильную личность/предметы, CRAFT replay без двойной выдачи. Можно заявить **только bounded graceful-restart durability**. Укажите отдельно `CRASH_ATOMIC=NOT_PROVEN` и `CRASH_RECOVERY=OFFLINE_ONLY`, если не было реального аварийного опыта.
- `GREEN_CRASH_SAFE` — дополнительно есть контролируемый live fault/crash restart proof с доказанной reconciliation source+items+craft, не из fixtures, без аномалий, owner safety и без условных бесплатных credits. Не заявлять, если тест был только offline.
- `PARTIAL` — какая-то значимая LIVE часть доказана, но source mapping или live restart/depletion/крафт не выдержал gates. Сохранить факты, не подгонять статус.
- `BLOCKED` — безопасный live путь либо source key не удалось доказать; опишите конкретную причину. `FAILED` — double credit, wrong-world mutation, owner file changes, orphan processes или ложные измерения/утверждения.

GREEN не означает production for 50–100 NPC, абсолютную crash-atomic транзакцию, сохранение всех мировых узлов, корректное respawn после полного wipe, нативный timed crafting queue, анимации, дома или PvP. Всё перечисленное помечать отдельно.
