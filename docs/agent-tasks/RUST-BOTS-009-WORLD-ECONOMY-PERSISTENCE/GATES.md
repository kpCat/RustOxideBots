# GATES — stop/go до дорогих live запусков

## G0. Базовый репозиторий

- GitHub master SHA при постановке `58d384e23a8200387d2574f935273c3056ab5b0a`, live local/master status перепроверить; owner `Server/` приватный и read-only. Проверить текущую Roam native BasePlayer модель, journal/persistence helpers, runner isolation.
- Корневой `AGENTS.md` строгий, никакой SteamCMD/update/owner BAT/устаревших модов. Сохранить старые source и raw receipts.

## G1. Stable source mapping — первоочередной риск

- `ResourceEntity` после reboot может иметь другой net ID. Нужна доказанная source incarnation и 1:1 сопоставление в том же exact world/gen на известной синтетической карте; нельзя использовать лишь координату или net ID. Не затрагивать новый естественно respawned ресурс старой долговой записью.
- Собирать конкретные позиции, prefab, pool contents/item definitions, terrain/nav/world identity, possible lifecycle/spawn marker в установленном API. Проверить коллизии и отрицательный wrong-source пример в offline tests.
- Если найден устойчивый API source identity — доказать LIVE. Если нельзя отличить старый от нового узла, выдавать `SOURCE_IDENTITY_AMBIGUOUS`, **не изменять пул**. Успех одиночного fixture без live matching не GREEN.

## G2. Transaction / durability gate

- Существующая добыча 007 — `NATIVE_PLAYER_GATHER`; создание native Item и source debit идут через engine, не через одну DB-транзакцию. Нельзя обещать crash-atomicity или exactly-once только из синхронной записи JSON после удара.
- Journal должен различать `PREPARED`, `APPLIED`, `COMMITTED`, `IN_DOUBT`, иметь write integrity/checksum/version and exact world binding. При неясности после crash — fail closed, no reward retry. Чёткий протокол ordering/durable flush documented. Подмена corrupted journal и replay другого generation отвергаются ДО мутации.

## G3. Проверка recipe/gather

- Только реальные wood/stones из NATURAL узлов, реальный Item UID, native tool wear + источники. Стоимость stonehatchet читается из установленного ItemBlueprint, не из предположения.
- Native craft queue по 007 unavailable для Roam; допустим только честный `SERVER_ACCOUNTED_CRAFT`, без фиктивных 15 с native queue и без free materials.

## G4. Runtime budget

- Target 2 live E2E, exceptional 3rd with a specific root-cause. Review static/fixtures прежде каждого; не запускать новый сервер, если чужой RustDedicated/SteamCMD.
- Полная ready, RustNav mesh built; controlled quit and completed save; Job Object, firewall lease; после завершения owner processes/ports/rules/locks=0. Процессы и пароли пользователя не раскрывать.
