# GATES — до затратных запусков

## G0. Основание и безопасность

- Local/public `master` должен содержать `648fbb1520e25bd1ac1b8f328c6d4d36e2a5641f` либо безопасно исследованный последующий fast-forward; branch `master`; отсутствуют неотнесённые пользовательские изменения.
- Читать корневой AGENTS и 009 RESULT/API; запомнить, что 009 GREEN только для graceful two-run depletion, а не crash-atomicity или любого мира.
- Проверить real installed Rust/Oxide DLLs/prefabs и fingerprint. Owner `Server/` read-only и вне Git; любой чужой Rust/Steam процесс — block, без kill.

## G1. Native construction feasibility (STATIC / IL)

- Какие именно classes/API обеспечивают: foundation/walls/roof, valid support/building group, `BuildingPrivlidge`, auth, decay/upkeep, `Door`/open, saving and spawn? Не делать live запуск для проверки неизвестного метода; сначала offline C# compile.
- Проверить реальные recipe и grade costs. Если требуемый object только клиентский RPC, определить **конкретный** безопасный server-accounted adapter; если registration / privilege impossible — честный blocker.
- Проверить можно ли native bot ID использовать для TC auth без Steam impersonation; unknown значит не называть TC авторизованным.

## G2. Оплата и размещение (OFFLINE gate)

- Валидатор conservation: сколько native Items было ДО каждого шага, сколько UseItem/consume, сколько building entities реально Spawned/registered, никаких retries после неизвестного результата.
- Site preview: no monuments, roads, slopes, water, foreign TC or building footprints, collision/support fail closed. Home shape only relative to site.
- Recovery: не дублировать TC/door/building block при повторной фазе или рестарте; different map/wipe denied; wrong owner/foreign buildings denied.

## G3. Два LIVE запуска (и только по обоснованной необходимости третий)

- 1: реальная добыча материалов → paid blueprint/TC/building → native door/TC/upkeep → RustNav через door и обратно. Полная source/position/receipt telemetry.
- 2: independent completed native save / precise world witness; 0 new items/builds; same home and upkeep; bounded HOME_NAV/door check if possible. Если live limitation — PARTIAL.
- Native Test-All PASS, cleanup0 и final exact-path commit/push. Ни одна fixture-проверка не заменяет live приемку.
