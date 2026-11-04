# Installed API / physics decision 015

Итог исследования: **NATIVE_THRESHOLD_BLOCKED, G1 HOLD**. Безопасный исправленный маршрут не установлен. Это решение о допуске к тесту, а не доказательство невозможности любого будущего native решения. Новый live не выполнялся; LIVE ниже означает только опубликованное evidence 014.

Собственные metadata/IL прочитаны существующим `scripts/Inspect-RustApi.cs` через PEReader, без загрузки/исполнения игровых DLL. Fresh asset extraction выполнен установленным локальным UnityPy, без установки пакетов. Assembly-CSharp SHA-256 `04FB89520F18A1920C1B1A350B82DD24A4258F31D97B82496971A9CC7A49DCB7`; RustDedicated `EFAC429DB737EB4B32A2BFC48029B4BE6FF475336958F4557F891F17255FFD38`. Установка не обновлялась.

| Предмет | STATIC_IL / STATIC_ASSET | OFFLINE | LIVE / UNKNOWN |
|---|---|---|---|
| RustNav normal movement | Scientist: `Rust.Ai.Gen2.RustNavMeshAgent.Tick` обнуляет Y направления → `MoveInternal` → `CorridorMove`/`CorridorOptimizeAndMove` → `_nextPositionNS`; `GetMovementWorldPosition` добавляет baseOffset, `SyncWorldPosWithNavPos` пишет transform. `TryQueuePathFollowing` исключает scientists; отдельно изученный batch `CalculatePathFollowing` также следует corridor | Native corridor height не является capsule collision response | 014: nav sample и feet на одной Y, несмотря на 11.279mm penetration. Новый маршрут UNKNOWN |
| Vertical support query | `SampleGroundPositionWithPhysics` вызывает `GamePhysics.TraceRealm`, возвращает collider/point/normal/distance; сам не двигает тело и не разрешает penetration | Читать такую опору допустимо; присваивать возвращённую высоту телу вручную запрещено | Связь этого query с автоматическим low-step в используемом path-following не подтверждена |
| Ground flag | `HumanNPC.IsOnGround()` override: `ldc.i4.1; ret`, ScientistNPC наследует HumanNPC | Нельзя использовать true как измерение пола. BasePlayer implementation с ModelState не определяет этот override | NativeGrounded=true 014 не доказывает поддержку порога |
| Actual body versus prefab | Fresh roam prefab: Capsule r0.5/h1.8, Rigidbody kinematic, gravity=false, discrete; CharacterController среди root components отсутствует. Prefab capsule disabled, native ServerInit/runtime включает его; prefab не подменяет runtime receipt | 014 actual enabled capsule подтверждает правильное тело; runtime Rigidbody flags текущего запуска UNKNOWN, потому что запуска нет | Native capsule 014 r0.5/h1.8/center(0,.9,0), agent height2.0 отдельно |
| Native alternate Base navigation | `BaseNavigator.maxStepUpDistance` и `SetBaseDestination` действительно существуют. В `UpdatePositionAndRotation` step относится к NavigationType.Base; NavMesh ветка только передаёт позицию пути. Base использует forward ray/down sphere radius0.25 и запись `BaseEntity.ServerPosition`, не полный r0.5/h1.8 capsule solver | Переключение с действующего RustNav на Base не доказывает сохранение complete RustNav route и physical body clearance | Безопасность такого переключения для этого порога UNKNOWN; не интегрировано |
| Bake climb/slope | `NavMeshBuildParams` constructor: radius0.25, height1.7, cellSize=radius/3, cellHeight=cellSize, maxClimb0.4, maxSlope45; это defaults структуры, не измеренные параметры текущей mesh | Bake connectivity через низкую ступень не равна отсутствию penetration тела r0.5 | Actual baked surface каждой новой centerline UNKNOWN; глобальные bake settings не менялись |
| Door portal | `Door.TryGetNavDoorwayVolume` возвращает cached bounds и localToWorldMatrix. `RustNavDoorGates.apertureStepOver` default0.5 используется в `TryGetNavDoorwayBakeVolume` для bounds | Это bake volume, не величина физического шага персонажа | Native door/hinge 014 доказаны, полный проход не доказан |
| Standard settings | speed/SetGait регулируют скорость; canSteer/maxTurnRadius — горизонтальный поворот; baseOffset добавляет Y после corridor result | Уменьшение скорости/кривизны не создаёт поддержку. Поднять baseOffset для обхода порога означало бы постоянный offset без доказанной опоры | Никаких settings/collider/mask/physics/anti-hack changes |
| Physics / rebuild | Installed `OverlapCapsule`, `ComputePenetration`, `RaycastAll`, native doorway mesh, `RebuildTilesInBounds`/`HasPendingTiles` прочитаны; старый guard и validator сохранены | Complete path и pending=false не заменяют clearance. Nonconvex mesh closest-point limitation учтена: использованы сохранённые native penetration и отдельный triangle prediction | 014 real MeshCollider penetration остаётся BLOCKING, а не STEP_CONTACT/Clear |

## Три геометрических кандидата

Все кандидаты определены actual `Door.TryGetNavDoorwayVolume` center/right/normal, без фиксированных map coordinates: внешний supported подход → waypoint по нормали → внутренняя точка → TC, затем обратная последовательность. Кандидаты: centerline и lateral ±25mm. Для будущего допуска каждому нужны actual native SamplePosition/CalculatePath Complete на всех участках, supported feet, открытая hinge geometry, real continuous body и измеренный clearance; такие новые native samples в 015 отсутствуют.

Fresh decoded `wall.doorway.collision` содержит74 vertices; после нормализации JSON vertices/triangles **полностью совпадают** с историческим extraction014. Lower sphere/triangle calculation воспроизводит native depth0.0112793455m с ошибкой менее0.0000001m. Исторический rejected pose lateral55.266mm отличается от interpolated crossing candidate lateral76.669mm; required halfwidth0.576669m относится ко второму, не к rejected endpoint.

| Кандидат на recorded foot height | Lateral | Боковой запас для r0.5 | Predicted depth у recorded normal |
|---|---:|---:|---:|
| Исходный rejected endpoint014 | 55.266mm | 44.734mm | 11.279256mm |
| Centerline | 0mm | 100.000mm | 11.279352mm |
| Centerline −25mm | −25mm | 75.000mm | 11.279395mm |
| Centerline +25mm | +25mm | 75.000mm | 11.279308mm |

Гребень почти одинаков по всей usable ширине. Sweep ±0.6m по нормали при **фиксированной исторической высоте** предсказывает максимальное пересечение lower sphere около30.898mm. Это не PhysX cooking/новая native симуляция и не требуемый manual Y offset. Следовательно, центрирование полезно для бокового запаса, но само не устраняет вертикальное препятствие на известной surface height. Какую высоту дал бы иной новый native corridor, остаётся UNKNOWN.

## Контакты и решение

Self, own foundation foot contact, doorway threshold, frame/wall, open hinge/closed door, TC и foreign сохраняются разными категориями. Own identity, upward MTD, малая глубина, native ground flag или complete path не дают clearance. Для STEP_CONTACT нужны наблюдаемые entry → ограниченная native кинематика → native resolution без устойчивого penetration, одновременно валидный full body/support/aperture. Таких данных нет; новый permissive classifier и положительный fixture не создавались. Существующий validator даже foundation overlap отвергает при `RequireClear`; диагностическое legacy exclusion не является разрешением физического прохода.

Выбран fail-closed G1 stop по EXECUTION_PLAN п.2: нет credible исправленной вертикальной траектории, которую следовало бы оплачивать новым smoke. Runtime, строительство и экономические контракты не менялись. RED→GREEN нового contract, native Oxide loading, CROSSED_IN/OUT, NATURAL и RESTORE в015 **NOT_VERIFIED**, не заменены offline PASS. Исторический outbound013 collider остаётся UNKNOWN.

Raw только ignored `.local/audit/home015/`: agent/following/native/ground/aperture/body-physics/nav-build IL, installed-assets.json, centerline-analysis.json, независимый reviewer IL и prelive-review.md. Исторические014 raw прочитаны без изменения.
