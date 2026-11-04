# ACCEPTANCE — доказательства, а не отчёты с красивым PASS

| Часть | Смысл реального прохождения |
|---|---|
| Baseline | GitHub/public master=local, source hashes, versioned docs, no owner writes |
| Actor+movement | тот же native `ScientistNPC : BasePlayer`, собственный real PlayerInventory, RustNav/physical samples/no warp |
| 6 blocks | настоящие native wood-grade foundation+3walls+doorway+roof, all support/links/one buildingID, реальная оплата |
| TC placement | **реальный** `Planner.DoBuild` return `BuildingPrivlidge`, `entity != null`, correct prefab/position/group/buildingID, saving, OwnerID, no foreign mutation; receipt до/после/ID |
| TC permissions | actual native bot auth/CanBuild, no fake Steam ID, cannot authorize strangers; failure=PARTIAL |
| Upkeep | настоящие Item UID переходят из native PlayerInventory в TC; rate/period и `GetProtectedMinutes(true) >=60`, decay enabled, no free credit |
| Door | native Door правильно attached к doorway, controls open/closed and collider state verified, owner/lock/access check |
| HOME_NAV | физическое outside→inside→TC→outside через native open door, actual clearance/ground/portal/path, no teleport or manual coordinates |
| Smoke isolation | test fixture material labels and exact paid ledger; diagnostic cache not promoted; smoke never equals natural gameplay |
| Natural production-like journey | отдельный clean world и actor, NATURAL resources and WorldEconomy journal, costs paid, identical real native home gates, SaveReady/proof |
| Native restore | третий process exact disk witnesses/house/buildingID/TC/door/upkeep+original Item UID/condition/persona, 0 rewards/build/kit replay, same WorldKey, wrong-world denied |
| Safety/test/delivery | `Test-All`, native Oxide compile, owner hashes/no secrets, UTF8 checks, no owned process/firewall leftovers, exact path commit + ordinary push |

Счетчик строительных префабов/скрин отчёта — не замена `BuildingPrivlidge`, `GetProtectedMinutes`, native door и физическому проходу. Если `Planner.DoBuild==null` без объяснения, не предполагать, что проблема в CLR, и не писать GREEN.

Конкретно по 011: 6 blocks доказаны, TC null, error debug empty. Новый smoke source должен сохранять независимый новый run evidence. Старый 011 raw никогда не исправлять задним числом.
