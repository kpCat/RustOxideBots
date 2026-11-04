# EVIDENCE — только наблюдаемые факты, никакой подмены fixture на gameplay

## Для каждого игрового запуска

- Owned run ID, argv/flag mode, TEST_FIXTURE vs NATURAL, versions Rust/Oxide/plugin/combined plugin source SHA, loaded cache/world SHA, map/wipe identity, server PID, phase timing, native compiler lines, start/end UTC.
- Exact raw paths `.local/runtime/<run-id>/{server.log,result.json,plugin-result.json,plugin-source.cs,...}` — только локально. Не публиковать RCON secrets/IP/Steam account/owner save/config.
- Fail/pass ledger по каждой `GATE` c реальными `Status/Reason/Time`, last 30s samples, native API reject codes and first failure.
- Хеши исполняемого исходника vs repo source и immutable historical 010 receipts. Не редактировать неуспешные прошлые логи ради нового GREEN.

## Smoke (отдельный раздел RESULT)

- Прямо зафиксировать source=`TEST_FIXTURE_WOOD`, количество выдано, UID, расходы на каждые оплаченные Item/Native Construction, remaining; не учитывать как натуральную добычу.
- Реальные `Planner/DoBuild/ChangeGrade`, native entity IDs/building groups/TC auth/upkeep, door transitions и actual physical home-nav, если достигнуто. При первом блокере — конкретный method and actual result, а не только `PARTIAL`.
- Доказать, что world/cache не promoted в trusted изолированную базу; удалить/не использовать smoke экономику в FULL. Fail closed if separation uncertain.

## Full natural journey

- Site chosen BEFORE extended farming; early and late geometry/permission/monument/road/foreign/Collision/Path/TimeBudget receipts отдельно. `travelSeconds`, `remaining`, `reserve`, reason-specific counters. Не считать послефармовый TIME_BUDGET SITE_CHANGED.
- Per-resource natural native debit/yield/wear/Item UIDs, Item shortnames, recipe costs loaded from installed Rust, journal intents, 0 adapter injection/double credit; фактические Tool switch/condition.
- `Placement`: exact prefab, actual native type, owner/buildingID, supports, connected sockets, health, grade, saving, payment before-after+UID, origin native action and errors.
- TC: native auth, cupboard inventory, rate/tax, `MinutesBefore/After` + protection duration, original item UIDs. Door and HOME_NAV: opened/closed, collider and portal, step-by-step continuous points, no warp, actual nav statuses.

## Restore (только после завершённого full journey)

- `JOURNEY` proof: exact .sav/cache generation/WorldKey/WipeId/journal, native actor/home/inventory/stored source SHA. Real `fromDisk` home witnesses, same 8 original elements, exact item UID+condition, owner rebind with no foreign auth and no duplicate structures.
- `RESTORE` proof: 0 new harvest/craft/build/kit, home unchanged after native load, TC inventory/upkeep preserved, new engine actor ID allowed for same logical ActorId, repeated journal NOOP; usable home path if dynamic RustNav allows. If nav fails, report HOME_NAV=PARTIAL without teleport.
- Independent check of owner `Server/`, foreign entities, test PID/job/firewall/ports/locks. Report exact cleanup even for failures.

**Offline fixtures != live proof.** Full GREEN only with real Source/Item/Building/TC/door/route receipts from game log; never just a C# method signature or fake JSON PASS.
