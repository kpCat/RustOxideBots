# ACCEPTANCE — конкретные критерии

| Проверка | Требование для полного GREEN | Доказательство |
|---|---|---|
| ACTOR | один `ScientistNPC : BasePlayer`, один PlayerInventory/main/belt/wear, без чужого Steam ID/сессии | prefab/type/runtime actor UID, owner/active/held |
| MAP | отсутствие hardcoded positions и seed, site из текущей terrain/RustNav/privilege | dynamic candidate, MapKey/WorldKey, native site preview, actual route |
| NO_FAKE_MATERIAL | В FULL только NATURAL wood/stones и paid recipes, exact source debits/wear; smoke fixture отдельно | pool before/after, Item UID/count, real cost ledger, mode label |
| SCHEDULE | измеренный проект/физический путь и все строительные фазы имеют достаточный bounded budget | remaining≥travel+build reserve, actual elapsed, phases |
| BUILD | 1 foundation, 3 walls, 1 doorway, 1 roof/floor; native BuildingBlock, grade Wood, support/registration/native links | eight-home entity ledger including door+TC, Native DoBuild receipts |
| DOOR/TC | native `Door`+`BuildingPrivlidge`, реальная auth, owner, buildingID; отсутствуют foreign users | real component state, native authorization |
| UPKEEP | real wood transfer inventory→TC, native upkeep rate/protection >=60 minutes, no direct decay override | UID conservation, native CalculateUpkeep/GetProtectedMinutes |
| HOME_NAV | physical outside→door opened→inside floor/TC→outside, real RustNav and door collider state; no warp | continuous samples, portal crossings, ground/collision, path status |
| SAVE/RESTORE | independent RustDedicated, exact original saved structure/TC/door and 1 logical actor with prior Item UID, no duplicate actions | native fromDisk witness, per-role original building IDs & entity IDs, actor/world/inventory/journal hashes |
| SAFETY | owner read-only, own processes/job/ports/firewall cleared, smoke doesn't pollute production/trusted cache | hash audit, lease receipts, cache proofs |
| DELIVERY | offline suite+live compile+receipt validator, no mojibake/escaped Cyrillic, narrow Git push/master | Test-All, source hashes, commit/tree |

**GREEN_HOME_BOOTSTRAP:** все реальные FULL JOURNEY + RESTORE пункты доказаны. Diagnostic smoke нужен для сокращения рисков, но не заменяет natural payment. **PARTIAL:** meaningful native building/TC/nav подтверждён, но все gates не доказаны. **BLOCKED:** безопасный native build/site/path/permissions недоступен. **FAILED:** fake payment, чужой мир/Item, дублирование, телепортация, orphan server или ложный GREEN. Статусы по подсистемам обязательны независимо от общего.

Долгосрочно не проверено: garage doors, несколько этажей, сундуки/сортировка, спальник/respawn, demolition/rebuild, PvP/groups, quarry, 50–100 bots, native queue, client animations, crash-atomic journal, arbitrary custom-map live E2E.
