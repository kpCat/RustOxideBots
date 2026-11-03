# EVIDENCE — сырые факты для проверки отчёта

В игнорируемой `.local/runtime/<run-id>/` сохранять неизменяемые:

- `server.log` (UTF-8, полные компиляция/загрузка, ошибки), `result.json`, source snapshot + SHA, `plugin-result.json`, дополнительные сырые telemetry samples; при рестарте native inventory/actor snapshots и world generation/hash receipts.
- API: concrete prefabs найденных player-derived NPC, actual inheritance, NavAgent/brain/FSM, active nav backend, native PlayerInventory/main/belt/wear и held API, native/connection ownership на момент live.
- E2E: spawn position, 2+ legs start/target/end, каждые sample(time,coords), суммарное actual/net, max displacement, collisions/path status, stuck/repath. Не зачитывать координаты, записанные вручную вместо штатной навигации.
- Equip: before/after `Item.uid`, ItemDefinition shortname, реальный parent/container, active ItemId, `GetHeldEntity()` type/prefab/owner flags, weapon switch attempts. Чётко выделять `TEST_FIXTURE`.
- Negative case: requested nonexistent UID, фактическая API-реакция, полный inventory diff=0, нет посторонних предметов/переходов.
- Cleanup: завершение именно своего `RustDedicated` через ACK/save/job, PID/process absence, test TCP/UDP и временные firewall rules/lease=0; foreign процессы не затронуты.
- Owner: snapshot hashes, количество файлов, zero diff; public secret/encoding scan; git diff exact paths/branch/SHA/remote.

Публиковать в `RESULT.md` **обезличенное** резюме и конкретные контрольные значения. Не публиковать owner IP, Steam ID, пароли, настоящие identity, приватные конфиги и весь 6+ГБ Server/. Каждый claim обозначать `STATIC`, `OFFLINE_FIXTURE`, `LIVE`, `NOT_VERIFIED`. Тест-код должен отказывать фальшивым GREEN при wrong actor UID или `GetHeldEntity = null`.
