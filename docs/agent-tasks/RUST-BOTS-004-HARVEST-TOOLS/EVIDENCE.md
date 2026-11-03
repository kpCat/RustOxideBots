# EVIDENCE — шаблон достоверного отчёта

## До игрового запуска

- Дата, local repo HEAD + `origin/master` + status; полный input scope, runtime DLL fingerprints; preflight/isolation readiness. Все публичные данные безопасны; no Steam ID, no owner seed/IP, no private paths/пароли.
- `API_DECISION.md` с verified names/signatures/class inheritance и смежными классами; indicate STATIC/IL/LIVE.
- Offline compilation + focused negative tests для неправильных item debit, повреждённого snapshot, stale world, no nav/LOS, same UID duplicate, failed harvest retries, tool absence, native-vs-adapter mislabel.

## Для каждого live run

Сохранить в ignored `.local/runtime/<run-id>/` и ссылаться из публичного отчёта только на относительные sanitized paths:

```text
run-id; runtime/Oxide/Plugin versions; cache key+generation
actor concrete runtime type/prefab; navigation backend; spawn (anonymous test world)
source: NATURAL or FIXTURE; type/prefab/id/coordinates; target distance and full path status
instrument: UID/shortname/ownership; native-equip? server-accounted? durability before/after
resource pool/health before, each native attack + result, resource pool/health after
item ledger: starter items separately; per-yield UID/shortname/amount, source debit and dest delta
physical movement samples; max step and speed; stuck/repath; geometry/LOS
before shutdown inventory + goal state SHA; world save and local snapshot SHA
restart: before/after exact UID/amount and world generation binding
full shutdown ACK, save, PID/process/ports, firewall helper/rules/lease closure
```

- Не исправлять старый live результат задним числом; каждый повтор — новый run ID и отдельный raw файл. Тест-фикстуры именовать `FIXTURE`, нельзя предъявлять их как natural.
- Если item conservation требует adapter с `ItemManager.Create...`, отчёт должен прямо раскрывать source-debit operation, момент транзакции, anti-double-award и неполное соответствие нативному сбору ресурса человеком.
- Параллельные агенты не должны изменять runner/cache пока работает owned server. Один контроллер, bounded запуск с максимальным временем.

## Финальная таблица

`API`, `NAVIGATION`, `WOOD`, `ORE`, `TOOLS`, `NATIVE_EQUIPMENT`, `INVENTORY`, `PERSISTENCE`, `SAFETY`, `TESTS`, `GIT` — каждую строку сопоставить с конкретным raw evidence и ограничениями. Отдельный итог GREEN/PARTIAL/BLOCKED/FAILED и список пока НЕ реализованных: PlayerInventory, visual-held gear, native crafting, bench/blueprint, bags/respawn, TC/building, PvP, player equivalence, 50–100 bots.

Точные команды Git включить в итоговый RESULT; коммит и remote SHA из последнего опубликованного состояния подтверждаются после push; файлы `Server/` не должны появиться в `git ls-files`.
