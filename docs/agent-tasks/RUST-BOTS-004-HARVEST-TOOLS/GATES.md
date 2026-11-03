# GATES — важнейшая развилка: NPC, инструмент и реальная добыча

**Не выбирай заранее «всё возможно».** Фактическая установленная Assembly-CSharp и live execution решают, какой интерфейс реализуем.

| Развилка | Что установить | Признак корректного результата |
|---|---|---|
| A: `ScientistNPC2` может native удерживать tool? | API `HeldEntity`, `Item`, weapon/gesture, сетевые видимые изменения, native animator | Лог конкретного equipped item UID + подтверждение реального изменения native state. Только item в owned container недостаточно. |
| B: Добыча ресурсов работает через NPC damage? | `TreeEntity`, ore/resource entity, dispenser/native gather, путь `HitInfo` в IL | Native source↓ + native output Item↑ + доказанная причинно-следственная связь. |
| C: Требуется серверный адаптер? | Проверить, что native NPC не получает output, хотя resource health уменьшается | Разрешён только строго учтённый source debit + созданный native Item; provenance `SERVER_ACCOUNTED_TOOL`; недопустимо называть native player harvest. |
| D: Нужен `BasePlayer`-derived actor? | `NPCPlayer` и `BasePlayer` API / наличие RustNav agent, inventory, движение, controls | Сравнительная матрица, минимальный эксперимент **только если** не ломает текущий NPC/harness. Нет переключения всей архитектуры на основании одного предположения. |
| E: Player-native crafting возможно? | `PlayerInventory`, crafting/blueprint/bench requirements | Зафиксировать feasibility для 005; полноценный craft не в scope 004. |

**GREEN 004** — реальная автономная добыча у двух естественных типов узлов, физический подход, accounting + restore и честная классификация инструмента (native gear либо явно server-accounted). **GREEN 004 не означает, что NPC уже выглядит как игрок с киркой в руках.** Для такого утверждения нужен отдельный `NATIVE_EQUIPMENT` PASS.

Если у выбранного actor нельзя одновременно получить native player gear и стабильный RustNav — сохрани работающий Gen2 actor и продумай future `IAvatarBridge`, а не ломай навигацию ради красивой имитации. Лучше PARTIAL с реальными метриками, чем ложный GREEN.
