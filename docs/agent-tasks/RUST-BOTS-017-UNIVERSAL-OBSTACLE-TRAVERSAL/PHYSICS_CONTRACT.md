# PHYSICS_CONTRACT — нативное движение, а не телепорт

### Инварианты

1. Тот же native `ScientistNPC : BasePlayer` с настоящими `PlayerInventory`, `ActiveItem`, `HeldEntity`, native identity; профиль исходной капсулы около radius0.5m/height1.8m подтверждать **на этом runtime**, не уменьшать ради PASS.
2. Не модифицировать prefab MeshCollider, terrain, door colliders, layers/IgnoreCollision, игрока scale/radius/height, native building rules, невидимые платформы, чужую Steam identity. `Physics.OverlapCapsule` только read-only и не отменяет движение движка.
3. Проверять **sweep до исполнения**, затем реальный after-pose contact/penetration/support. `PathComplete` и forward pose сами по себе НЕ доказывают safe movement. `Rigidbody.isKinematic=true` может пропустить препятствие без физического ответа; такое событие FAIL.
4. Допустимы только реально поддерживаемые игровые способы подъёма/спуска с native collision resolution и без перехода сквозь чужие объекты. Если кастомное управление позициями неизбежно для collision-aware controller, это большая архитектурная развилка: представить владельцу API/план/риски/инварианты, не внедрять бесшумно. Не считать запрет на direct transform поводом вообще не разрабатывать решение.
5. Категории не зависят от одного prefab. Реальный низкий порог может быть `STEP_CANDIDATE`, но контакт 11–19mm с горизонтальным MTD либо foundation side edge НЕ может становиться `CLEAR` просто из-за маленькой цифры. Динамический подъём доказывается последовательными измерениями: нижняя сфера поднимается на настоящую опору, боковая/глубокая пенетрация не остаётся/не нарастает, полный swept path не проходит сквозь стену.
6. Отрицательные случаи: вертикальная стена, закрытая дверь, занятая лестница/ступень с недостаточной высотой, unsupported gap/drop, вода слишком глубока, чужой TC/запрет доступа, частичная/сломанная navmesh, небезопасная скорость. Все должны оставаться непроходимыми без реально найденного detour. Нельзя разрешить все `own BuildingBlock` colliders — внутренняя стена остаётся препятствием.
7. One-way **step up** и **step down** отдельно: проверка опоры в точке приземления, max drop, уклон/падение/подскальзывание, отсутствие подвешенного NPC; движение без резких скачков между тиками.

### Проверки для приемки

- Реальные native terrain slope / rocks / ступень/пандус (при наличии) вне дома; **независимый** дом с raised foundation+door; стенка или закрытая дверь как гарантированная отрицательная проверка. Навигация должна продемонстрировать хотя бы одно реальное безопасное изменение высоты в ходе движения и хотя бы один физический detour или честный `BLOCKED` для непреодолимого препятствия.
- Отдельные receipt `MOVE_DECISION`, `OBSTACLE_PROBE`, `STEP_ATTEMPT`, `PHYSICAL_CONTACT`, `STEP_RESOLVED`, `REPATH`, `BLOCKED`, `DOOR_OPEN/CLOSED` с source/current actor identity, native engine evidence. Не эмитить `STEP_RESOLVED` после одной предсказанной траектории.
- Кросс-проверка validator по raw: timestamps/positions/speed/acceleration bounds, actual capsule/colliders/mesh, support/ground and final clear. Mock fixtures OFFLINE_ONLY, native live measured separately. Не вводить magic epsilon специально под 19.329мм из 016.
