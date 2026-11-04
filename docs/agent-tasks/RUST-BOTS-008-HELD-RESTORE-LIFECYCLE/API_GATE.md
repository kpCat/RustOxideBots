# API_GATE — исследовать перед live

**Наблюдаемый дефект:** при 007 RESTORE `serverEntities.Find(81011)!=null` вызвал отказ до `PlayerInventory.Load`. Наиболее вероятная причина — сетевые ID временных held-сущностей не переносятся между новыми процессами/генерациями. Это гипотеза, а не доказанный тип конфликтующего объекта. Сохранённые `Item.uid` и `HeldEntity.net.ID` имеют разные жизненные циклы.

Проверить по установленным локальным DLL/IL и raw evidence:

| Сущность/API | Необходимый вопрос |
|---|---|
| `ProtoBuf.Item.UID`, `heldEntity`, `worldEntity` | Какие поля долговечны, какие требуют переинициализации после перезапуска? Можно ли занулить ephemeral held только в копии protobuf? |
| `Item.Save` / `Item.Load` | На каком шаге разрешается network `heldEntity`? Условия owner/parent, привязки, fallback? |
| `PlayerInventory.Load` / `ItemContainer.Load` | Восстанавливает ли UID контейнера? Как устанавливает `playerOwner`, `entityOwner`, Item.parent и `slot`? |
| `Item.RecalulateParentEntity(false)` / `ItemModEntity.OnParentChanged` | Создаёт ли необходимый новый native HeldEntity после Load, что происходит при повторном вызове? |
| `HeldEntity.SetupHeldEntity`, `SetHeld`, `GetOwnerPlayer` | Восстанавливает ли owner через native item/root player? Без forcedOwner и SetParent. |
| `BasePlayer.UpdateActiveItem`, `NPCPlayer` | Когда безопасно активировать сохранённый `ItemId`? Может ли оригинальный нет-ID быть повторно использован чужим миром? |
| `BaseNetworkable.serverEntities.Find` | Записать реальный resolved type/prefab/owner/parent/item — а не просто факт non-null. |

Модель безопасности: **предыдущие Item UID сохраняются; старые held net IDs НЕ обязаны сохраняться**. Новый native HeldEntity может получить новый net ID. До нативного Load не должны существовать действующие Items с входящими UID. Если факт IL не подтверждён, не чинить предположением. Снапшоты и хеши нельзя подгонять под результат.
