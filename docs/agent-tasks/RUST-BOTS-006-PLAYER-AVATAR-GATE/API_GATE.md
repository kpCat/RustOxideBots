# API gate — вопросы, которые нельзя решать предположениями

Из 004/005 `API_DECISION`:

- Доказано в static/IL: `ScientistNPC2 : BaseNPC2 : BaseCombatEntity`; НЕ `BasePlayer`. Имеет работающий `RustNavMeshAgent` в live.
- Доказано в static/IL: `NPCPlayer : BasePlayer`, `NPCPlayer.NavAgent : RustNavMeshAgent`, `PlayerInventory` содержит player-specific системы; `NPCPlayer.EquipWeapon(bool)`, `BasePlayer.GetActiveItem`, `GetHeldEntity`, `UpdateActiveItem` присутствуют. **Их одновременная работа с движением и server-only NPC НЕ подтверждена.**
- `HeldEntity.GetOwnerPlayer()` и `BaseMelee.ServerUse()` ожидают `BasePlayer`; `ItemContainer.entityOwner=ScientistNPC2` не заменяет owner player. Native craft queue и выдача добычи привязаны к `BasePlayer` и контексту его инвентаря/владения.
- 005 пока использует `SERVER_ACCOUNTED_CRAFT`; наличие `stonehatchet` в owned `ItemContainer` НЕ значит, что NPC его держит или может использовать.

Обязательно исследовать по установленным DLL, конкретной версии/manifest (не только по старым декомпиляциям):

| Gate | Что доказать |
|---|---|
| Actor discovery | Точный prefab, `NPCPlayer`/`BasePlayer`, `ScientistNPC`, NavAgent, наличие default inventory |
| Native ownership | `userID`, `playerFlags`, `IsNpc`, data vs live connection; не использовать чужой Steam ID |
| PlayerInventory | `inventory` не null, belt/main/wear и ownership работают без клиента; не создаёт дубликаты |
| Active item | `UpdateActiveItem`/`GetActiveItem`/`GetHeldEntity`, held owner, prefab, network state |
| Navigation | `NavAgent` действительно способен вести actor по RustNav, не только объявлен как поле |
| Life cycle | `Spawn`, think, sleeping/disconnect, kill/destroy/save не ломают сервер; cleanup без orphan-сущностей |
| Persistence | После полного restart UID/condition/selection восстановлены либо честно помечены недоступными |

**Если нет подходящего player-derived prefab с нативным NavAgent или native owner path упирается в обязательную подключённую клиентскую сессию:** не пытаться создавать фальшивого Steam-клиента и не превращать блокер в полусекретный Harmony-патч. Задокументировать точное техническое препятствие; текущий Gen2 остаётся рабочей исходной моделью.
