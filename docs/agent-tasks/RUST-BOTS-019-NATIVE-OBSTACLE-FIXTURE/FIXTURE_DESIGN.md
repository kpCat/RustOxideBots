# Reproducible actual native obstacles: avoid wandering to find a door

The failed018 algorithm searched a closed `Door` in the *existing procedural world*, within48m after downhill. It found none. A benchmark requires a testable object, not a lucky monument placement.

## A. Native paid fixture as test geometry (preferred)

Use a **new physical isolated smoke fork** and existing native `Construction`, `Planner.DoBuild`, grade upgrades, `ItemModDeployable` and actual inventory UID payments / TC permission. TEST_FIXTURE material may enter the private NPC's native inventory only in *diagnostic* mode, accounted with source label. Native placement must pass installed `CanBuild`, terrain/nav clearance, stability and entity network/decay registration; no `GameManager.CreateEntity` shortcut or `Spawn` direct for building, no fake invisible colliders, no copied old entity from another world, no changing physics.

Choose a dynamically discovered suitable site first using native preview/site checks: stable ground, proper walking support/slope, valid construction placement, water/monument/road/foreign privilege exclusion, path from actor via real RustNav, bounded distance/time and no overlapping world objects. Probe/plan candidate **before** game placement; do not use a hardcoded location or bypass native placement when no site exists. Can reuse proven home BUILD_SMOKE construction logic, without repeating natural 3760wood farm. If a native 1x1 is feasible, build it in the fixture; otherwise a smaller actual foundation+doorway+hinged Door+native wall (optionally TC) can be used for **G4 physical tests only**, clearly reporting `HOME_G5_NOT_ATTEMPTED`. Don't claim full G5 on minimal fixture.

Need a *finite* obstacle to allow a real bypass route. A sealed house with a closed Door is NOT bypassable by walking from inside to outside; do not demand an impossible detour through its walls. Test these separately:

1. **Own native solid wall:** from a clear physically supported stand outside, a full original body ray/sweep toward wall yields `SOLID_BLOCKED`, target wall contact ID, zero actuation through wall. No fake collision. Its refusal must NOT poison a purely observational probe state.
2. **Own native closed Door:** door physically closed with real attached collider; direct displacement/route across its actual leaf is denied, door/leaf ID and hinge witnessed, zero through-door actuation. The test uses owned door rather than pretending it's a foreign user-owned door. Reopening is a native permission-controlled action, not passing through a closed leaf.
3. **Actual bounded detour around exterior corner/finite wall:** two naturally reachable supported points on the exterior of the same structure with a *real* wall obstructing the straight swept segment, while native RustNav provides a `PathComplete` legal way around the exposed outer corner. Actual actor follows that path, stays outside and does not cross sealed building, distance > baseline straight-line direct motion. If no valid detour exists, record G4_DETOUR_NOT_PROVEN, never fake `PathComplete` or reverse via teleport.
4. **Full home:** paid native 6 wood building blocks + TC with original UID upkeep (>=60min) + hinged door. Native open (own auth/range), refresh relevant RustNav tiles; actual actor outside→inside to cupboard→outside, native physical clearance/sweeps/foot support through **real doorway lip** and close Door after exit. If doorway still physically unsafe, stop as PARTIAL/G5_UNSAFE; no forced Pass and no old-physics bypass.

If native class/owner/TC/material/geometry can't be reused without a major change to product construction or actor architecture, **present options to owner** and await choice before such major change. For routine test sequencing, do not interrupt autonomy.

## B. Alternatives only if actual native placement is blocked

- Use a **verified existing physical native world obstacle** or monument wall and its native door only if there is a concrete qualified locator and safe path in this isolated world's map (not another game's world). Existing world claims are grounded in live API, not name-only assumptions.
- A private bench-only native paid prefabricated wall/door minimal fixture is acceptable G4 evidence, not full house; strict real product costs and network entities required.
- Never manually create a collision mesh, manipulate door ownership to fake чужую, import someone else's save, or modify owner Server. No hardcoded coordinates/seed as product logic. Do not grant own bot foreign TC auth.

## C. Must preflight before spending game-PID budget

Inspect `FirstHome.cs` actual building site finder and `HomePlace`, installed APIs and 018 runner. Build a deterministic **fixture plan in local structure coordinates**, not absolute map points. Confirm native placement rules/cost source, expected stable building sequence and test tasks with focused offline fixture validation. In live, collect reasons of candidate refusal before expensive runs; if no location after bounded scan, stop once with `NO_NATIVE_SITE` not three identical game starts.
