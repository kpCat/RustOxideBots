# Формат результата и диагностика

`RESULT.md` обязан содержать: технический вывод в 4–7 строках; pinned commit baseline/current; literal code/API evidence; exact E2E commands and exit statuses; native prefab/type/inventory adapters; map/runtime/cache summary; route coordinates, distance to road, path statuses, actual traveled/meters and rejected/failed segments; barrel native damage/drop details; crate loot and item transfer before-after (item UID/shortname/amounts, redacted); conservation accounting and anomalies; startup/ready time; shutdown and owner fingerprints; regression tests; final tracked file allowlist and `git ls-files -- Server/`; `origin/master` SHA. Distinguish claims from actual game logs and fixture-only unit tests.

Log prefixes propose `RUSTBOTS_WORLD_START`, `RUSTBOTS_TRAVEL_SAMPLE`, `RUSTBOTS_ROAD_ARRIVE`, `RUSTBOTS_INTERACT_START`, `RUSTBOTS_BARREL_HIT`, `RUSTBOTS_BARREL_DROP`, `RUSTBOTS_CRATE_OPEN`, `RUSTBOTS_ITEM_TRANSFER`, `RUSTBOTS_WORLD_RESULT`. Prefixes can differ, but MUST provide enough fields to independently reconstruct every success and failure; record errors per reason and bounded recovery.

Example *schema only*, NOT real evidence:
```
{ "Mode":"LIVE", "ActorType":"...", "TotalTravelMeters":0, "MaxContinuousNetMeters":0,
  "RoadEvidence": {"kind":"topology","distanceMeters":0},
  "Crate":{"source":"NATURAL","before":[],"after":[],"moved":[]},
  "Barrel":{"source":"FIXTURE_NATIVE_PREFAB","damage":[],"nativeDrops":[],"pickedUp":[]},
  "Conservation":{"ok":false,"anomalies":[]},"Shutdown":{"ownedPidAbsent":false,"portsFree":false,"firewallClean":false}}
```
No hardcoded lucky map coordinates or mocked successful telemetry. Не копировать пользовательские секреты, settings, Steam IDs/IP. Если задача остановлена на частичном E2E, приложить реальный failed proof и дальнейший минимальный путь к успеху.
