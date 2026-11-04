# API GATE — critical physical collision analysis

Read only the installed local DLLs / IL first; no internet-sourced signatures treated as proven. Prepare a compact `API_DECISION.md` with `STATIC_IL`, `OFFLINE_FIXTURE`, `LIVE_PROVEN`, `UNKNOWN` columns.

**Core investigation:**

- UnityEngine `Physics.OverlapCapsule`, `RaycastAll`, `Collider.bounds`, `GetComponentInParent<BaseEntity>()`, collider `enabled`/`isTrigger`/layer, `Collider.ClosestPoint`, `Physics.ComputePenetration` and shape casts *only if present*. `TerrainCollider` versus building meshes, exact NPC/doorway native colliders and actual support normals. Do not invoke unsupported API.
- Rust `RustNavMeshAgent`, `RustNavigation.DefaultNavmesh`, `CalculatePath`, `SamplePosition`, `HasPendingTiles`, `RebuildTilesInBounds`; `Door.SetOpen`, door native gates, animated collider transforms and `TryGetNavDoorwayVolume`.
- `HomePhysicalSample` in `FirstHome.cs`: old expression explicitly discards only `npc` and `foundation` by entity identity. Any terrain collider or structure with no owner is currently counted. This is a **suspected overconservative test**, not root cause until the returned collider(s) are measured live.
- Outbound world evidence from 013: first failure at time381.66626, outside flag, open door, path planned complete 1.457232m; exact Collider **UNKNOWN**, no claim as to which object intersects the probe. `HomeCrossing` occurs AFTER throwing `HomePhysicalSample`. A missing `CROSSED_OUT` does not by itself prove absence of geometric crossing. The desired fix must preserve this separation and never invent acceptance.

**Native geometry definition:** real actor collider endpoints/shape and door aperture, support floor vs vertical blocking collision. A terrain-contact adjustment may be made only after a bounded geometric justification and negative tests for actual forbidden terrain/wall/body collision. Classifying entire TerrainCollider as nonblocking without contact/height/normal proof is disallowed.

**Red/Green before expensive live:** fixture one benign support contact causing legacy FALSE and corrected TRUE; distinct fixtures wall/door/TC/foreign object/penetrating terrain/unsupported floor causing FALSE. Require stable on-disk log schema with collider type/ID and actual `inside` vs `outside` states. Offline contracts never substitute for headless native runtime proof.
