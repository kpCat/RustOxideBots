# EVIDENCE — что оставить Codex после работы

## Структура результата

`docs/agent-tasks/RUST-BOTS-005-CRAFTING-RECIPES/RESULT.md` — публичный обезличенный итог (не raw конфиги/логи). Новые `PLAN.md`/`API_DECISION.md` создаются по ходу работы. Сырые runtime receipts в `.local/runtime/<run-id>/` и `.local/audit/craft005/` (ignored); public report содержит пути к ним и опубликованные обезличенные метрики, ни паролей, ни private owner данных.

## Required gameplay measurements

- Rust/Oxide/Unity build and plugin exact versions, actor class/prefab; native versus accounted mechanism; actual recipe ItemBlueprint output item ID/shortname, amountToCreate, ingredients, default learned state and workbench requirement; method signatures/IL refs.
- Sampled route from physical spawn to NATURAL source; meaningful actual distance and continuous samples, PathComplete; inventory initial/harvested/craft/restart before/after; source pool debit vs credited new items; tool UID/condition.
- Craft attempt receipt: action ID, blueprint data, known/unlocked/bench gate, workbench actual context if relevant, ingredient slots/UID/amount before→after, output UID/item/amount/condition, full conservation reconciliation; positive and at least one negative recipe attempt. Denied branch has 0 mutations.
- Idempotence: duplicate intent/craft invocation does not award duplicate, no replay after process restart, stored actor goal and completion marker with snapshot hashes.
- Two independent live processes where available. Save/World/Inventory binding (exact world-generation .sav hash, cache key, proof, native quit complete), times, successful/unsuccessful E2E, raw log and report file paths. Any native resource source pool reset across restarts explicitly noted.
- Tests before/after, static vs live separated; if feasible 1–2 controlled real server runs, third only with diagnosed issue and rationale. Evidence must never be overwritten to make a previously failed run appear GREEN.
- Shutdown: owned PID/job closed, temp test ports released, firewall rules and helper lease removed, foreign processes untouched; fingerprint of owner protected files before/after.
- Git: baseline, commit(s), origin/master, changed paths, clean status, no Server/. UTF-8/mojibake and escaped-Cyrillic scans independent. If final commit SHA cannot be embedded in its own RESULT, store in ignored delivery receipt and final Codex response.

## Negative fixtures (offline, not live proof)

Wrong recipe/amount multiplier; missing/partial ingredients; duplicate UID; canceled/failed craft after debit; missing blueprint or workbench; method mismatch; invalid item condition; stale cache generation; saved-world mismatch; second-award from same craft intent; E2E validator spoofed totals/coordinates/UID; absent shutdown evidence. These are useful tests, **not** replacements for actual live craft/restart.
