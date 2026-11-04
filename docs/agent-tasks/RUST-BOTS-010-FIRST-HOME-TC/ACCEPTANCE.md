# ACCEPTANCE — честный критерий RUST-BOTS-010

| Gate | Минимум для GREEN_HOME_BOOTSTRAP | Проверяемые факты |
|---|---|---|
| ACTOR | Один `ScientistNPC : BasePlayer`, native PlayerInventory/active item/RustNav, одна логическая личность | Concrete prefab, native owner, physical samples |
| SITE | Найдена площадка динамически в текущем мире, а не зашита координата | Terrain/privilege/collision/road/monument/topology, reject samples |
| MATERIALS | Для всех изделий/строительных элементов и upkeep оплачены реальные добытые native Items | Native recipe/grade costs, UID/amount before/debit/after, natural source receipts |
| STRUCTURE | Зарегистрирован реальный native связный 1×1 shelter: foundation, 3 walls, doorway, roof, actual door, one TC | Prefabs/types/IDs/grade/health/support/building group/save, one instance per element |
| TC | Настоящая BuildingPrivlidge/auth/ownership и native контейнер; реальные привилегии/долговечность | Native auth bot ID without fake Steam, TC inventory, upkeep time/cost |
| DOOR | Native Door физически открывается/закрывается, коллизия/проём реальны | Door flags/owner before/after; no prop spoof |
| HOME_NAV | Тот же NPC движется снаружи → внутрь к TC → наружу; без телепорта | RustNav/paths/samples/timestamps, no position writes, door transitions |
| RESTORE | Второй RustDedicated, сохранённый native дом и TC (без второго spawn), та же личность и paid ownership/upkeep | Native save/world/wipe proof, entity-ledger, 0 recredit/rebuild |
| SAFETY | Защищённые файлы не менялись, own jobs/ports/firewall/locks очищены | SHA and cleanup receipts |
| CODE/GIT | API/validator/test/live compile, exact commit/push, Server ignored | Test-All, remote SHA, encoding/secret scans |

**GREEN_HOME_BOOTSTRAP:** все критические gates реально доказаны в headless E2E двух процессов; server-accounted placement разрешено только с **полной native structural registration** и точной оплатой. Явно маркировать размещение `NATIVE_PLAYER_BUILD`/`SERVER_ACCOUNTED_BUILD`, не выдавать второе за первое. NATIVE_PLAYER_GATHER допускается, уже proven в 007/009, но надо подтвердить вновь для материалов этого дома.

**PARTIAL:** доказаны оплаченные реальные элементы и/или TC, но невозможно подтвердить всю структуру, авторизацию, HOME_NAV или independent restart. Отделить каждый компонент, не заявлять GREEN по одному префабу.

**BLOCKED:** безопасный строительный/TC API/сайт или изолированный live environment недоступны. **FAILED:** бесплатное строительство, неверный owner, чужая mutation, дублирование, teleports/ложные receipts или orphan test server.

Не требуется в 010: двери с кодовым замком, сложный home graph на 2+ этажах, сундуки, спалка/respawn, рейд/восстановление после утраты TC, научные столы/верстаки, 50–100 NPC, crash-atomic proof. Эти функции не выдавать за реализованные.
