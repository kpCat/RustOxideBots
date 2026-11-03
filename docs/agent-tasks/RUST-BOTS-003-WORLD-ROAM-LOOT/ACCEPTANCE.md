# RUST-BOTS-003 — acceptance и проверка самих фактов

## Итоговая таблица (обязательно заполнить в RESULT.md)

| Проверка | Требование | Доказательство |
|---|---|---|
| Baseline | исходный HEAD/master, изменённые пути | remote + local SHA |
| Plugin | C# compile на live Oxide, actor concrete type | server.log, prefab, runtime |
| Map | procedural test world, RustNav backend, cache key | logs; protected world fingerprint |
| Spawn | физически пригодная grounded позиция | ground/nav/clearance logs |
| Outdoor | >=250 м actual cumulative + >=75 м один непрерывный episode, реальные дорожные координаты | per-leg samples, `PathComplete`, displacement/speed/no warp |
| Road | доказанная близость к дороге (не только имя waypoint) | topology/road object/id, измеренная дистанция |
| Crate | native loot, физический подход, source count ↓, owned inventory ↑ >=1 | before/after inventory receipts |
| Barrel | реальный damage → разрушение, native drop → pickup | hit/death/drop/inventory receipts |
| Conservation | отсутствие инъекций/дублирования предметов | item UID, amount, source/dest, anomalies=0 |
| Cleanup | test server/ports/firewall/lease removed; без owner mutations | owned PID, port checks, cleanup receipts |
| Git | `Server/` ignored, exact-path commit, fast-forward push master | `ls-files`, diff, SHA |

**GREEN:** все критерии выполнены фактически в одном или нескольких совместимых live E2E одного тестового контекста без фиктивного loot. **PARTIAL:** честная неполнота после доказанной реальной части. **BLOCKED:** невозможно безопасно запустить/изолировать/продолжить или API блокирует без workaround. **FAILED:** нарушение инвариантов безопасности/честности.

Скрипты mocked fixtures не заменяют live доказательства. Сырой серверный лог и JSON receipts в ignored `.local/`; публичный RESULT содержит обезличенные доказательства, без IP/identity/password/Steam ID/приватных путей. В каждом тесте отмечать, естественная бочка/ящик или native prefab создан по fixture.
