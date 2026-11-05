# ARCHITECTURE — цель общего traversal слоя

Не переписывай весь RustNav и не делай новый NPC вид. `RustNav` остаётся глобальным планировщиком; новый слой обеспечивает **физически исполнимый локальный переход** и решает, продолжать, подняться, объехать, перепланировать или остановиться.

Рекомендуемая схема (точные имена/тип выбирает Codex после actual installed API):

`WorldGoal → RustNav corridor/path → LocalObstacleProbe → TraversalDecision → SupportedNativeMotion → MotionWitness → Recover/Repath/FailClosed`.

- `LocalObstacleProbe`: для native полноценной капсулы (не узкий луч) проверяет предстоящий swept volume, примыкание к ground/foundation/ramp/steps, нормаль опоры, высоту перепада, уклон и боковые зазоры; подвижные/foreign коллайдеры. Проверять тайлы/navmesh readiness и возможности native agent. Не сканировать весь остров каждый tick.
- `TraversalDecision`: категории `CLEAR`, `SMALL_STEP_UP`, `STEP_DOWN`, `SLOPE`, `SOLID_BLOCKED`, `DOOR_CLOSED`, `UNSUPPORTED_GAP`, `DYNAMIC_BLOCKED`, `REPATH`, `UNKNOWN`. Конкретный step height/slope/drop limit **из installed movement capability/real actor**, не магическое число 0.3m. При `UNKNOWN` fail closed и raw diagnostics.
- `SupportedNativeMotion`: использовать штатный collision-aware native mover **если** доказан установленной DLL/IL; при отсутствии оценить безопасный physics-aware local controller, который действительно разрешает столкновения/опору и не меняет world geometry. Кинематический `transform` sync RustNav не является collision-safe locomotion. **Не разрешать вручную писать transform / Warp / baseOffset ради пропуска препятствия**. Если для новой реализации требуется принципиально иной low-level movement/physics компонент — задействовать `DECISION_GATE.md` и получить выбор владельца ДО внедрения. Сохранить тот же `ScientistNPC : BasePlayer`, inventory/held/ownership.
- `MotionWitness`: независимые на каждом реальном переходе: native actor pose/velocity/agent path, full 3D capsule volume and swept collision, support before/during/after, penetration evolution, wall/door/foreign blocking, consistency of time/distance. При псевдо-прохождении через MeshCollider status `KINEMATIC_CLIP` и STOP, никогда GREEN.
- `Recover`: bounded attempts e.g. 1 detour/repath, detect stuck, avoid endless loops, record reason. Стены/закрытые чужие двери обходить только по существующей доступной траектории, не протыкать. Own unlocked door opening policy — отдельное разрешённое действие при подтверждённой ownership, не просто obstacle suppression.

**Переиспользование**: выписать interface / contract, чтобы outdoor destination and `FirstHome` могли вызвать один traversal solver; не копировать в `FirstHome` ещё сотни строк. Небольшой `src/navigation/*` допустим, но в существующем runner combined C# должно собираться корректно без новых NuGet/runtime dependencies. Старый `FirstHome.cs` сохраняет native construction/TC/door economics, а не становится новым physics engine. В 017 не переписывать весь ресурсный journal, крафт, world save, spawns.

**Performance instrumentation**: number of physics casts/agent/tick, query latency/CPU approximation, allocations if accessible, path retry count, sample rate at idle vs active obstacle, cache invalidation on door/building change. 50–100 bots не нужно запускать сейчас; не заявлять масштабируемость без отдельного stress E2E.
