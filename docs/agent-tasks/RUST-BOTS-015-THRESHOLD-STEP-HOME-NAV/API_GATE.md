# API / physics decision gate

Codex заполняет actual `API_DECISION.md` на установленной Rust build. Базовая версия из 014: Rust protocol2635.289.1, Oxide.Rust2.0.7839, Assembly-CSharp SHA `04FB89520F18A1920C1B1A350B82DD24A4258F31D97B82496971A9CC7A49DCB7`. **Сверить с собственными installed файлами, не принимать старую версию за обязательную.**

Изучить с доказательствами:

- `Rust.Ai.Gen2.Nav.RustNavMeshAgent`: `SetDestination`, `CalculatePath`, `SetGait`, `speed`, `baseOffset`, `height`, path reset/desiredSpeed, native path following and vertical support. Есть ли вообще штатная возможность невысоких ступеней без прямой записи transform? Какие значения поддерживаются установленной системой, где и когда применяются?
- `ScientistNPC`, `NPCPlayer`, `BasePlayer` и native mover/physics: какие компоненты меняют Y, проверка `IsOnGround`, физическая capsule/CharacterController/agent. Доказать чей и как движется collider; `PathComplete` не равен physics clearance.
- Native `Door.TryGetNavDoorwayVolume`, `RustNavDoorGates`, native open hinge physics/colliders, `RustNavigation.RebuildTilesInBounds`, `HasPendingTiles`.
- `Physics.OverlapCapsule`, `ComputePenetration` and collision mask/trigger, `Physics.RaycastAll`, actual `MeshCollider` nonconvex limitations; explicit 014 guard: if any non-self/non-foundation overlap, throws before accept crossing.
- Native `Planner.DoBuild` + `BuildingPrivlidge` are already live-proven. Don't rework home construction API unless fresh evidence requires it.

**Запрещённые shortcuts:** `transform.position=` after spawn, teleport/Warp, `MovePosition` equivalent bypass, `Physics.IgnoreCollision`, disabling native collider/LayerMask, scale/radius/height reduction, changing existing doorway/door prefab or per-item costs, manually spoofed `CROSSED_IN/OUT`. Temporary diagnostic probes may read native physics, not mutate owner runtime.

**Completion of this gate:** hypotheses for path alignment and step support are separately labeled; only provable API calls are incorporated into runtime; each geometry claim has a source (actual installed IL, native live, previous raw, offline prediction). Unsupported native body control is `UNKNOWN` and must not be faked.
