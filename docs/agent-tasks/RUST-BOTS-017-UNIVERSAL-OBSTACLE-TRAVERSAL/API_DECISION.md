# API_DECISION017 — установленный native locomotion, 05.11.2026

**STATIC_IL, не LIVE_PROVEN017.** Анализ существующим scripts/Inspect-RustApi.cs через PEReader/MetadataReader: игровые DLL не загружаются и не исполняются. .NET SDK10.0.402. Test-All выполнялся Windows PowerShell5.1; интерактивная orchestration PowerShell7.6.9. Product target C#7.3.

## Installed SHA-256

| DLL | SHA-256 |
|---|---|
| Assembly-CSharp | 04FB89520F18A1920C1B1A350B82DD24A4258F31D97B82496971A9CC7A49DCB7 |
| Rust.Data | 1D62BAEF9B339F0416E6529618365C1ECAD01791A833E77E76EB6C8464406104 |
| UnityEngine.PhysicsModule | 8C14EB5CB74477ABBD1F043F26D9A4E58BB3E4ED7DDA1B81937E59D08967EA11 |
| UnityEngine.CoreModule | 6B971445185B5F71834C4BCCD7CEAA6264CFB27841E8EA8364FCD15188E246E9 |
| Oxide.Rust | 2128121E34B55BB1550D43E62842B87EA3720059F13DC84F97D8C7DD465C3423 |
| Oxide.CSharp | B64977609A31FBE0C462626D966BC7C6818A06725D085F7CC2D2951FBC2B9094 |
| Oxide.Core | 3CFE0C52796C7C29F14108330812A5E58D3B685E0B3D00DCCC56703F28D5DE05 |

Raw017 находится только в ignored `.local/audit/traversal017/`: installed-hashes.json, rustnav-il.txt, rustnav-motion-il.txt, rustnav-sync-il.txt, native-navigator-il.txt, native-bridge-contract-il.txt, unity-motion-il.txt. Это новый анализ тех же установленных DLL, обновлений не было.

## Подтверждённая цепочка

| Предмет | Доказательство STATIC_IL | Вывод и предел |
|---|---|---|
| Actor | ScientistNPC -> HumanNPC -> NPCPlayer -> BasePlayer | Исходный native player-derived actor сохраняется |
| Ground flag | HumanNPC.IsOnGround: IL_0000 true, IL_0001 ret | Это override с константой; для опоры необходимы physics queries |
| RustNav move | RustNavMeshAgent.MoveInternal IL_016A CorridorOptimizeAndMove / IL_0195 CorridorMove, IL_01A3 _nextPositionNS | Движение по nav corridor; full-body collision response в исследованной managed цепочке не установлен |
| Vertical position | GetMovementWorldPosition IL_0008–0029: nextPositionNS + up*baseOffset -> NavToWorldSpace | Высота берётся из nav position/offset; это не доказанный step solver |
| Immediate sync | SyncWorldPosWithNavPos IL_0012 _updatePosition, IL_0056 SetPositionAndRotation, IL_0064 set_position | Прямое native transform sync; kinematic тело не становится collision-safe из-за существования capsule |
| Batch sync | FlushTransformBatch IL_00D7 SetPositionAndRotation / IL_00E7 set_position | Этот fallback путь тоже пишет transform. TryQueuePathFollowing IL_0044/0049 исключает scientists; batch path нельзя без проверки приписать конкретному actor |
| nextPosition | get_nextPosition/get_nextPositionWS без setters | Нельзя проектировать bridge на выдуманном nextPositionWS=actualPose |
| Velocity | set_velocity IL_0032 предупреждает об отсутствии эффекта при RustNav | Не API управления физическим телом; setter не заменяет mover |
| Route-only planning | Public CalculatePath(NavVector3 start, NavVector3 destination, RustNavMeshPath) | Возможно строить маршруты от actual pose; корректность нового bridge ещё UNKNOWN |
| Base navigator | NPCPlayerNavigator.UpdatePositionAndRotation IL_0003 -> BaseNavigator; NavMesh branch BaseNavigator IL_00D6 ServerPosition | Не обнаружен отдельный player-body solver |
| Base mode | BaseNavigator.UpdatePositionAndRotation: forward Raycast IL_01F2, downward SphereCast radius0.25/range10 IL_022A; rise check IL_0255–025C; ServerPosition IL_0265 | Иной navigation mode. Нет full original capsule/headroom/явного bounded drop в этой ветке; не годится как уже доказанное решение |
| Player walk | Installed BaseMovement/PlayerWalkMovement: данные и constructors | Обычный client walking implementation в этих server типах не найден |
| Ground query | SampleGroundPositionWithPhysics IL_004F GamePhysics.TraceRealm | Surface probe, не актуация/разрешение коллизии |
| Native controller candidate | UnityEngine.CharacterController.Move(Vector3)->CollisionFlags, SimpleMove; stepOffset/slopeLimit/skinWidth/height/radius/detectCollisions | API существует; native Move_Injected не раскрывает solver IL. Совместимость с ScientistNPC/Rigidbody/capsule UNKNOWN |
| Existing-body actuator candidate | Rigidbody.MovePosition(Vector3), SweepTest и SweepTestAll | Наличие native entrypoint не гарантирует безопасный full-body step. Особенно нельзя считать kinematic MovePosition автоматическим collision resolution |
| Full geometry queries | Physics.CapsuleCastAll(Vector3,Vector3,float,Vector3,float,int,QueryTriggerInteraction), OverlapCapsule, ComputePenetration | Реальные native queries; для общего solver нужны pre-execution sweeps, support и after-pose witness. ComputePenetration false сам по себе не clearance |

updatePosition=false отключает соответствующие transform writes, но само по себе не останавливает advancement внутреннего corridor/nextPosition. Два независимых writer или попытка периодически Warp тело к nav position запрещены. Требуются явное отключение автоматического locomotion и маршрут от реальной позиции; details должны быть подтверждены кодом/bench после выбора владельца.

## Исторические доказательства — не новые live017

Независимый reviewer сверил raw016 smoke2:8 Watch PHYSICS frames,1 observation; contact336.244324s совпадает с последним physical sample; subsequent contact frames0. Actual ScientistNPC/BasePlayer, capsule radius0.5/height1.8, enabled/nontrigger, unit scale; Rigidbody kinematic=true/gravity=false. Outcome UNSAFE/SWEPT_OBSTACLE, Accepted=false/Clear=false. Ни resolved step, ни устойчивый clip/stuck после этого кадра не доказаны.

Extracted installed roam prefab015 содержит root CapsuleCollider, Rigidbody, NPCPlayerNavigator, RustNavMeshAgent и NavMeshAgent; root CharacterController в extracted списке отсутствует. Live016 не содержит полного component inventory. Prefab evidence не подменяет actual runtime inventory будущего bench.

## Статусы и выбор

- STATIC_IL: методы/цепочки выше подтверждены установленной сборкой и независимо проверены.
- OFFLINE_ONLY: final Test-All, новые focused traversal/acquisition contracts и C#7.3 exact combined compile прошли. Эти проверки не моделируют PhysX.
- LIVE_PROVEN017: три native compile/load/readiness и исходное actual тело; одно observed native применение MovePosition0.01558876m в BENCH3. Оно нарушило control limit и не является traversal PASS. История001–016 не переименована.
- UNKNOWN: безопасный step-up/down solver для исходного тела, controller compatibility, разрешённый actuator, max capability, multi-context passage,100-agent perf.

Проверено отсутствие подтверждённого подходящего solver **в исследованных путях**; это не доказательство отсутствия любого такого API во всём движке. Владелец выбрал C, ответ записан в DECISION.md. Реализован bench-only checked controller исходного тела, не promoted. Native CharacterController/BaseNavigator replacement не внедряются; default legacy native movement сохранён.

## Реализация выбранного C

`src/navigation/ObstacleTraversal.cs` использует установленный native Rigidbody.MovePosition как единственный actuator, полную исходную CapsuleCollider и independent actual witness следующего наблюдения из FixedUpdate. Предварительный расчёт никогда сам не даёт STEP_RESOLVED. В явном bench отключены логические native movement writers; параметры тела, layers, collisions, gravity/kinematic, scale не меняются. Rigidbody.detectCollisions, Collider.enabled/isTrigger и layer читаются, не выключаются.

Установленные `RustNavmesh.BuildParams` содержат agentMaxClimb/agentMaxSlope/agentRadius/agentHeight; public TileChangeVersion/TileDataVersion/NavMeshHandle подтверждены metadata и компиляцией. Explicit-start CalculatePath строится от actual pose. Изменение epoch инвалидирует маршрут; физические surfaces не кешируются между ticks.

Declared custom profile: MaxStep=min(original radius, installed agentMaxClimb, BaseNavigator.maxStepUpDistance), MaxDrop=MaxStep, MaxSlope=min(installed slope,60°), скорость не выше min(native walkSpeed,1.2m/s), full-vector acceleration не выше4m/s², actual tick не более0.1s. Это conservative policy controller, а не доказательство native step capability. Числа исходных контактов016 в допуски не включены. Skin=2*installed Physics.defaultContactOffset; initial support capture учитывает исходный terrain spawn+0.05m, положительная penetration не разрешается.

Для STEP_EDGE требуются независимые native source-floor и same-collider walkable-top rays, bounded real rise, точная spherical corner geometry, полный headroom/capsule pre-sweep и actual after-sweep. Own building identity не делает контакт допустимым. Для plain slope действует native-derived slope ceiling. False ComputePenetration out Distance/Direction не интерпретируются; нужны независимые full-volume и exact tangent proofs. Любая true positive penetration запрещает advance.

На углах и у цели код требует торможение до наблюдённого нуля, включая BRAKE_HOLD; смена цели не обнуляет движущуюся velocity фиктивно. Единственный bounded local detour/replan не заменяет global RustNav. Per-route120s,6000ticks на lifetime controller,64physics queries/tick,16384retained receipts; исчерпание приводит к STOP, idle queries0. Масштабирование100NPC и allocation profile не заявлены.

Independent pre-live source review допустило core/validators к измерению без открытых P1. Pre-live Test-All exit0 и exact combined C#7.3 compile exit0. BENCH1 actual frozen combined SHA `CAC1AF880D69F74828F48206248538F154F6973F269D2FE4A5252024EC93E59B`; installed Oxide compilation/load наблюдались в isolated runs. Отдельная оценка actuation/support/physical passage по raw приведена в RESULT; одно успешное load не является GREEN_TRAVERSAL_CORE.

## Исправления по двум живым отказам до движения

BENCH1 обнаружил incomplete readiness: built tiles не исключают pending queue. Вход до Begin теперь ждёт обе native предпосылки в прежнем600s budget; motor pending guard сохранён. BENCH2 показал реальный initial full-sphere gap0.098322m при ordinary tolerance0.07m и MaxDrop0.5m, без overlaps и без движения. Точная роль point-ray spawn и native OnEnable/rebind неизвестна: первоначальный spawn ray не сохранён.

В выбранном C добавлен отдельный initial FLOOR_ACQUISITION, который не расширяет ordinary tolerance. Перед первой обычной командой требуется actual stationary observation, static single-hit native walkable floor, original body clear, floor withinMaxDrop, native permission/water. Далее только vertical descent с прежними speed/acceleration/tick limits, fresh full-body pre/after sweep и unchanged floor point/normal/identity. Горизонтальное движение запрещено до actual normal support и измеренного покоя у skin; после этого маршрут связывается с actual pose. Поздняя потеря опоры не получает этот initial-only recovery.

Acquisition имеет отдельный SupportPhase/MotionMode и никогда не считается STEP_RESOLVED либо доказательством outdoor/building height transition. Это маленький контролируемый спуск, не correction live Y/teleport. `Permission` и `WaterDepth` теперь вычисляются/сохраняются независимо от поддержки; native construction-privilege policy не изменена. Подтверждённый CanBuild overload проверяет vehicle/entity privilege и TC.CanBuild, а не road topology в исследованной цепочке; данных о permission failure в BENCH2 нет из-за прежнего short circuit.

Численные velocity/acceleration в receipts — finite differences actual pose по интервалам наблюдения. Native Rigidbody.linearVelocity сохранён отдельно. Они не доказывают пиковую native physics velocity/acceleration между samples; такие более сильные заявления и100-agent performance не делаются.

BENCH3 показал конкретный timing blocker: past dt0.08828735s использован для следующего смещения, future observed dt0.0621948242s дал acceleration4.029982m/s²>4.001. Endpoint error≈0.5µm, overlaps/swept hits0, native velocity.y−0.249420166; это не позиционная ошибка и не доказанный clipping. FLOOR_ACQUIRED/STEP_RESOLVED отсутствуют. Пределы не увеличены, raw не исправлялся. Нужен explicit future physics integration horizon и новая отдельно разрешённая live приёмка; current proof не позволяет GREEN_TRAVERSAL_CORE.
