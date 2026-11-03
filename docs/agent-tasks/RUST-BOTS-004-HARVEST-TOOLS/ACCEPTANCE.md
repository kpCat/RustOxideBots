# ACCEPTANCE — RUST-BOTS-004

## Обязательные критерии GREEN в заявленном survival-gather test scope

| Система | Что требуется от настоящего E2E |
|---|---|
| SOURCE | Естественные `NATURAL` дерево и ore/stone entity найдены на настоящей процедурной карте; runtime prefab/type/position + геометрия + provenance. Fixture не засчитывается для natural GREEN. |
| MOVEMENT | NPC физически добрался до обоих источников, validated complete path, LOS/range/ground, continuity of position, no warp. Достаточно meaningful distance между источниками; абсолютный новый 400 м норматив не нужен. |
| HARVEST | Натуральный источник уменьшил health/remaining native pool, добыча действительно возникла и была перенесена; численные receipts до/после. Прямой GiveItem без source debit запрещён. |
| INVENTORY | Реальные native Item UID/shortname/amount, starter kit отдельно, source-minus/dest-plus, no duplicates/negative amounts/phantom credits. |
| TOOLS | Реальный item-инструмент участвует в действии и учитывается. Native equip подтверждать только доказанным native state/ability; server adapter маркирован отдельно. |
| PERSISTENCE | Один самостоятельный полный server restart, правильный test-world/identity binding, прежние UIDs/количества инструментов/новых ресурсов сохранены в независимом запуске; отсутствие duplication. |
| SAFETY | Owner hashes (world, configs, mods) не менялись; test process/ports/firewall/helper закрыты; session logs и secrets приватны. |
| TESTS | Offline static/fixture tests PASS + live Oxide compiled/loaded + real headless gameplay; no fabricated receipts. |
| GIT | Только исходники/документы/scripts вне `Server/`, exact-path changes, ordinary fast-forward push `origin/master`, remote SHA checked. |

Для GREEN допустим явно маркированный `SERVER_ACCOUNTED_TOOL` **только** при живом source debit и native Item accounting. Тогда итог `SURVIVAL_GATHER=GREEN / NATIVE_EQUIPMENT=NOT_VERIFIED (или UNSUPPORTED)`; не объявлять полноценное поведение живого игрока. Если ресурс только смоделирован, без реальной убыли source, HARVEST=PARTIAL/BLOCKED.

## Когда не GREEN

- `PARTIAL`: один тип ресурсов, нет независимого restart или native tool/equipment остаётся исследовательской частью. Не маскировать фактически успешный core stage из-за вторичного stretch, но не присваивать общий GREEN без обязательных критериев.
- `BLOCKED`: у runtime/актора отсутствует безопасный путь честной добычи, несовместимость API, нет natural source при bounded search, невозможно безопасно изолировать/запустить тест.
- `FAILED`: дубль UID, ресурсы без debit, нарушение owner isolation или leakage, неправильное закрытие owned process, поддельные результаты.

Доказательства: фактический runtime type и source ID, before/after pool, native yield/provenance, UID/amount list, exact world binding, путь/координаты, raw log samples, 0 lingering processes/ports/rules, Git tree. Цель — минимум один сильный E2E, а не искусственные десятки PASS.
