# DECISION017 — выбран вариант C

**Выбран C.** 05.11.2026 владелец ответил: «C — собственный local controller (рекомендовано)». Универсальность и настоящий ScientistNPC/BasePlayer также согласованы. Основание обсуждения: TASK017 раздел1, DECISION_GATE.md и PHYSICS_CONTRACT.md пункт4. API_DECISION.md содержит установленные signatures/IL и отделяет STATIC_IL от live.

## Сравнение

| Вариант | Как работает и реалистичность | Риски/безопасность |50–100 NPC, обновления и стоимость |
|---|---|---|---|
| A. Существующий RustNav mover с общими probes | Сохраняется native transform sync; probes запрещают опасный advance, разрешённый маршрут обхода ищет RustNav | Минимальная миграция, но безопасный физический подъём не доказан. Может останавливаться на проходимых ступенях. Не закрывает требуемый traversal core сам по себе | Самая малая стоимость; queries и detours всё равно требуют budget. Минимум собственного physics code;100-agent нагрузка UNKNOWN |
| B. RustNav + native CharacterController bridge | RustNav планирует от actual pose, Unity CharacterController.Move разрешает локальные движения; тот же ScientistNPC и inventory | API установлен, совместимость не доказана. Это новый collider/controller рядом с исходной CapsuleCollider/Rigidbody. Замена/отключение исходной капсулы запрещены текущим scope; если это потребуется, остановиться и отдельно обсудить изменение инвариантов. Даже добавление без отключения требует проверки двойных контактов и lifecycle | Меньше своего step solver, но сложная Rust integration и зависимость от Unity/native component lifecycle. Реальный cost/perf UNKNOWN |
| C. RustNav route-only + собственный physics-aware local controller | Исходные actor/capsule/Rigidbody сохраняются. Собственный bounded sweep/slide/support/step controller исполняет локальный переход с pre-sweep и independent after-pose witness | Больше собственного кода и ответственности. Нужна явно согласованная bounded актуация исходного тела; Rigidbody.MovePosition — кандидат, а не гарантия. Никакого transform/Warp bypass. При недоказанном контакте/опоре STOP. Step/drop profile должен быть установлен и проверен | Самая высокая стоимость реализации/поддержки, но не требует prefab replacement и отделяет local physics от обновлений RustNav. Cast/repath budget и CPU instrumentation обязательны;100-agent perf UNKNOWN |

A сохраняет текущую fail-closed остановку и может служить rollback в blocked state; безопасный физический проход остаётся недоказанным. Это не замена уже выбранной универсальной системы. B рассматривается только при сохранении исходного body contract; blanket collision disabling/resize не предлагаются как разрешение задачи.

## Рекомендация исполнителя

**C**, потому что он сохраняет исходное тело и позволяет явно проверить каждую локальную траекторию, не выдавая RustNav path за разрешение коллизий и не требуя нового collider. Цена — разработка и проверка собственного low-level solver. Рабочий дизайн и bounded allowlist приведены в PLAN.md. Это гипотеза реализации, не обещание, что конкретный step уже доказан.

Согласованное решение владельца — C: собственный collision-aware local controller исходного ScientistNPC поверх RustNav route planning, включая ограниченное физическое применение проверенных перемещений исходного тела, при запрете teleport/unchecked transform/Warp, collider/scale/layer изменений и при обязательных continuous witnesses.

Первоначальный предел3 isolated live starts был исчерпан без physical PASS. После поставки честного PARTIAL владелец отдельно разрешил исправление physics-clock и ещё до2 starts: «Разрешаю исправление и ещё до 2 starts». Общий предел017 равен5, использованы все5 после offline-проверок и независимого review. BENCH4/5 подтвердили новый fixed horizon на коротких acquisition fragments, но оба остановились по независимому wall guard; universal physical gate не пройден. Шестой PID не разрешён. Исходная постановка и unsafe raw сохраняются; это изменение бюджета, а не physical acceptance или смена выбранного C. Кандидат остаётся bench-only. Original inventory/economy, independent review и physical up/down/building/outdoor/negative proof обязательны.

## Ответ владельца

05.11.2026: «C — собственный local controller (рекомендовано)», ответ на вопрос, явно перечисляющий RustNav route-only, исходного ScientistNPC и bounded проверенное применение перемещений без телепортации, Warp, изменения капсулы и отключения столкновений. Эти ограничения сохраняются. Дополнительное согласование рутинных исправлений и тестов не требуется.
