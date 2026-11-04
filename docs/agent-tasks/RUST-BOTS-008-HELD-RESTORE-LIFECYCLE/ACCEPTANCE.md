# ACCEPTANCE — RUST-BOTS-008

## Обязательные GREEN_RESTORE gates

| Gate | Что доказывает |
|---|---|
| BASELINE | Local/master SHA и опубликованный source 007 сверены; предыдущий PARTIAL остался нетронутым |
| SOURCE_PROOF | Исходный JOURNEY был реальным, чисто завершён; exact world generation/.sav/cache + snapshot/state SHA валидны; иначе создаётся новый подтверждённый JOURNEY |
| CONFLICT_DIAGNOSIS | Известно, какая сущность заняла сохранённый held net ID, или зафиксирован честный UNKNOWN без необоснованного удаления проверки |
| NATIVE_LOAD | Новый RustDedicated, реальный `ScientistNPC : BasePlayer`, загрузка `PlayerInventory` main/belt/wear через native code; нет подмены `Item` |
| PERSIST_UID | После restart все native Item UID, shortname, amount, condition/maxCondition и slot/role соответствуют source, нет пропавших/лишних UID и дублей |
| IDENTITY | Логический `ActorId`, goal, tool UID, product UID, craft completion/intent неизменны; новый native actor net ID допускается |
| ACTIVE_HELD | Native belt содержит именно saved crafted stonehatchet UID, ActiveItem совпадает, HeldEntity.GetItem совпадает, parent/owner новый actor, held flag true; повторное измерение после ticks |
| NO_REPLAY | RESTORE не выдаёт starter kit, не добывает, не создаёт новый stonehatchet, не списывает ресурсы, не запускает крафт и не меняет посторонние сущности |
| NEGATIVE | Incoming duplicate item UID/foreign or corrupt held/snapshot/world/role/slot не становится GREEN, fail closed |
| SAFETY | Изоляция runtime/Oxide, owner SHA unchanged, owned game exited/ports & firewall rules & leases & locks released |
| CODE/GIT | Offline Test-All, live Oxide compile/load, scans кодировок/секретов, exact-path commit и обычный push master, Server ignored |

**GREEN_RESTORE** только при всех live source/native load/active/held/persistence + safety gates. Нет GET/Set «новый топор того же вида» вместо старого UID. Первоначальный 007 остаётся PARTIAL исторически.

**PARTIAL:** доказаны хотя бы части восстановления, но не все item/native ownership/active checks. **BLOCKED:** нет безопасного совместимого source-world или API не даёт выполнить проверку; не спамить перегенерацией. **FAILED:** дублирование Items, потеря экономической собственности, мутация чужих объектов/owner мира, оставшиеся owned процессы/правила, фальшивый GREEN.

Не требовать 50 ботов, PvP, native player crafting/animation, постоянный source depletion/crash journal или настоящий Steam-account: эти темы **вне scope 008**.
