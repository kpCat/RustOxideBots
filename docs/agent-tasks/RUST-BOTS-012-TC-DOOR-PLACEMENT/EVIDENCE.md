# EVIDENCE — что фиксировать локально и что публиковать

Хранить raw только в ignored `.local/runtime/<run-id>/`, `.local/audit/home012/`. Защитить owner, secret, RCON, IP, token, user IDs. Публичный RESULT обезличен.

## Preflight / native reasoning

- Exact installed DLL SHA, C# compile, проверенные сигнатуры/ветки IL возвращающие null и/или Phrase, актуальные prefab assets; отдельный `API_DECISION.md`.
- Для каждого TC preview/hypothesis: expected foundation placement, holder/Item UID/held entity, `Construction.Target` поля, hit/normal/collider names+layers, raw LOS/reach/ray, TC oriented bounds and overlaps, foundation/wall/roof ids, native privilege/permission, status и Phrase/error если реально доступна.
- **Не выбирать причину только по близости координат:** correlate exact live native return branch and relevant geometric value.

## Smoke

- Spawn/actor and physical path samples; exact TEST_FIXTURE source and Item UID/amount. Price/grade/structure entity IDs, before/after, no additional/hidden spawn. Touch-up statuses and native payment/journal stage.
- On null: record `PLACEMENT_TC_BLOCKED` reason, native method return, immediate persisted `ErrorDebug` and `PhraseOrNotExposed`, no item debit, no additional successful TC, new run id, correct cleanup. **Do not replay pending TC intent**.
- If success: TC entity owner/buildingID/saving/group, native auth/privileges and rate/period/minutes with UID balances. Door collider open+closed, HOME_NAV physical samples and crossings. No cache promotion.

## Natural JOURNEY (conditional)

- Separate no-fixture receipt, native source debit/yield and wear, real recipe/grade costs, planned/actual time and site before/after, 8 entity roles with native net IDs, economical journal/actor/home snapshots and grace save.
- Avoid assuming exact map test coordinates; use actual current map discovery.

## RESTORE (conditional)

- Independent server world generation/.sav/hash, WorldKey/MapKey/wipe, exact old building IDs/entities disk witness and new native bot-ID only after safe owner/auth check; original Item UIDs, 0 replay, state of actual upkeep, physical HOME_NAV if feasible.
- Negative offline fixtures: wrong world/owner/role/disk witness/TC removed, corrupted snapshot, collision, unsupported route, false Phrase and intent replay.

## Delivery

Final full `RESULT.md` reports E2E counts, real vs fixture provenance, exact status per gate, time spent, limitations, code/commit hashes and remote equality, cleanup/owner SHA and both encoding scans. Raw log references are local relative paths only; never publish source secrets or owner configs. `Server/` and `.local/` absent from Git index.
