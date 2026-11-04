# EVIDENCE — что сохранить и что опубликовать

Сырые данные — **только** в ignored `.local/runtime/<run-id>/` и `.local/audit/avatar008/`, не в Git. Не изменять raw 007 и его `result.json` / snapshots. Никаких владельческих IP, Steam IDs, паролей, содержимого приватных конфигов, чужих пользовательских путей в публичных документах.

Нужно собрать: baseline local/remote SHA; exact исходный journey/restore run IDs, source binary/state hashes и world-generation/proof; installed Rust/Oxide fingerprints; транскрипт/резюме IL; original protobuf UID/role/slot/held/worldEntity; при коллизии — live entity type/prefab/net ID/parent/owner/item UID; deep copy cleanup decision; native Load success/exception stage; actual loaded main/belt/wear owners/container IDs; per-item UID/amount/condition/slot ledger; native active/held GetItem/owner/parent/flags before/after и по нескольким ticks; no replay/item creation events; независимый validator output; original snapshot vs new inventory hash proof; final server/native save/quit receipt; process/ports/firewall/locks audit; owner file hash before/after; exact-path Git staged allowlist, SHA/push receipt; mojibake + escaped Cyrillic separately.

Факты `STATIC_IL`, `OFFLINE_FIXTURE`, `LIVE_JOURNEY`, `LIVE_RESTORE` помечать отдельно. При новом негативном исходе сохранить исходный статус и причину, не переписывать текущий лог ради красивого `GREEN`.

Рекомендуемые файлы: `docs/agent-tasks/RUST-BOTS-008-HELD-RESTORE-LIFECYCLE/{PLAN.md,API_DECISION.md,RESULT.md}` и audit receipts локально. В публичном RESULT указать только безопасные synthetic/native ephemeral IDs и измерения, не raw secrets.
