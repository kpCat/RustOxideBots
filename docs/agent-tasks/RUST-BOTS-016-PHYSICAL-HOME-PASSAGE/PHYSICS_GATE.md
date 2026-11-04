# Truth gate — real contact versus pathfinding claims

Observed 014: own native doorway MeshCollider penetration **0.0112793455m** (lower capsule sphere), threshold crest about **0.030900m** above feet; foundation overlap0.00225684m; native actor capsule **r0.5 h1.8**, agent height2.0; door open, portal halfwidth ~0.6m. 013 historical OUT unknown. 015 lateral centerline improvements do not remove threshold at recorded height; no live data015.

### NEVER acceptable

- `Clear=true` after silencing a real solid overlap without measured safe resolution.
- "The NPC got through" while native capsule intersects a wall/frame/TC, or because a kinematic agent simply passed through solids.
- Constant epsilon `<=0.012`, ignoring all own colliders, simply excluding doorway or changing physics layer/agent radius/body/terrain/rock/mesh/health.
- Manually setting transform Y or baseOffset, Warp, MovePosition, direct ServerPosition; synthetic path receipts, fake accepted crossing, fixture accepted as natural.
- Modifying owner world/save/installed DLL to fix geometry.

### For every contact frame

Record original world-time actor position/rotation, previous pose and time; native full collider r/h/capsule endpoints/scale, component state; actual `OverlapCapsule`, `ComputePenetration` direction+depth for each contact with native collider identity/entity owner/category; contact growth/decay; nearby rays to native walkable support (including underside/upper floor and wall threshold), normal, height, water; actual RustNav agent position/velocity/remaining/path and independent `CalculatePath`; native tile pending and mesh support. Door `IsOpen`, hinge collider bounds and native aperture geometry. Account for collider-to-actor orientation and time; ensure no non-finite values. Data in ignored `.local`.

### Supported safe passage (minimum)

1. Same native BasePlayer-derived NPC, standard unmodified runtime capsule with real source proof and owner; continuous physical trajectory through native open doorway, on actual supported floor, without discontinuities or transform writes.
2. No enduring non-support penetration: if any temporary threshold touch, demonstrate that native movement resolves it in bounded physical time with actual clearance and does not tunnel through frame/wall or enlarge world geometry. Compare body and swept volume to installed doorway mesh/door portal. If automatic solver missing and entity kinematic-clips: FAIL/PARTIAL.
3. At door crossing body fits aperture (radius and height), floor support and LOS valid, no closed-door crossing; physically approach TC and back, close door after exit. Neither "PathComplete" nor final coordinates alone suffice.
4. Controlled diagnostic observation must be visibly flagged in receipts and can NEVER alone satisfy home navigation. Only when separate production-level admission checks succeed on all crossing frames, with no unsafe override, may `HOME_NAV` become GREEN.
5. Negative cases reject wall, closed/open hinge blocking volume, foreign structure, unsupported floor, roof, lateral misses, stale tile, partial path, fake sensor frames. Independent validator reconstructs distances/contact transitions and rejects fake "resolved".

### Stop criteria

At first unsafe overlap that deepens, persists without support, crosses occupied mesh, involves foreign objects, or exceeds bounded time/distance, stop native path; keep original truth and all receipts. Never self-approve step clearance from a near-vertical displacement vector alone. If test design cannot ensure process cleanup / world isolation / zero release of unsafe code, stop before PID.
