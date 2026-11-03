# EVIDENCE — что зафиксировать, а что нельзя выдавать за доказательство

Raw evidence — **только** `.local/runtime/<run-id>/`, `.local/audit/avatar007/`, не коммитить и не вставлять реальные secrets/owner parameters в публичный RESULT.

1. `server.log`, `result.json`, `plugin-result.json`, raw `RUSTBOTS_...` samples, exact plugin-source snapshot/SHA: сборка Oxide, concrete type/prefab, native avatar NetId/PlayerInventory UIDs, Rust version/protocol, RustNav ready, фактические local PID/ports.
2. AVATAR: engine native NPC bot id (в публичном отчёте только безопасная обезличенная метка), IsNpc=true/HasConnection=false, native main/belt/wear owners, до/после default loadout normalization. `ActorId` должен быть устойчивым между запусками; runtime `NetId` не обязан совпадать.
3. NAV: sample position/time/max step/gap/speed, complete path, корректные переходы, resetPath arrival и `agent.speed` re-arm, stuck/repath counts; физический путь к NATURAL tree/ore.
4. NATURAL source: runtime type/prefab/position, ID, pool before/after, remaining fraction/health, world mapping, дистанция/LOS; фактические native tool action или честный accounted adapter и реальные UID rewards; отсутствие двойного native+adapter output. Distinguish **damage-only** and **actual gather**.
5. CRAFT: точный runtime рецепт (не зашитая цена), известность blueprint/bench gate, списанные строки UID/amount, произведённый UID с condition и штатный Output, negative/duplicate action no-op.
6. EQUIP: exact crafted UID в belt и active, `GetHeldEntity` type, parent, owner, native held state до завершения процесса, отсутствие manual prop/SetParent/forcedOwner.
7. RESTART: два разных server process/run ID, предыдущий native shutdown ACK/save, full `.sav` и inventory/container/actor-state SHA, совместимость world-generation / cache, transfer `containerMain/Belt/Wear` с UID/condition, совпавший selected active UID, восстановленный native held avatar. Resume не делает new kit/harvest/craft. Никакого использования чужого historical run UID как продукта.
8. CLEANUP: только owned Job, timestamps, no foreign process change; TCP/UDP/firewall lease/lock all clear; 3086 owner files либо актуальный count byte-for-byte unchanged. Глубоко verify public staging/secret/encoding. Git final SHA и origin/master check.

Не засчитывать:
- Offline stub/fixture PASS как native running Rust;
- инвентарь от Gen2, присоединённый к отдельно созданному BasePlayer;
- предмет с совпадающим названием, но другим UID после restore;
- TEST_FIXTURE (кроме разрешённого и явно отмеченного rock/torch стартового kit) как добычу или crafted output;
- Node pool «начислен» без нативного debit;
- screenshot/player-animation claims без настоящего клиента;
- engine save successful как достаточное доказательство persistence без UID/actor/active reconciliation.

GREEN telemetry проверять **независимым** validation code: balances, trace continuity, native owner/slot, replay guards, world-restore proof. Обязательно включить фальшиво-положительные negative fixtures: UID substitution, double bonus/loot, nonowned item activation, default loadout credited to economy, stale world snapshot, missing equipment after restore, fake Native Player Gather, lost tool condition, native ResetPath speed zero stall.
