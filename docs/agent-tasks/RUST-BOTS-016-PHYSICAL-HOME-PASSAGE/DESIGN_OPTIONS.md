# Engineering choices — abandon the circular G1 hold

**Major correction to approach after 015.** We know the culprit but not native contact evolution. A no-PID investigation cannot establish whether a momentary 11mm contact resolves, persists or clips through. One TEST-ONLY measurement scenario is therefore justified **provided it cannot become gameplay success by itself**. No arbitrary "benign <12mm" rule.

## A. Native contact behavior (prioritize)

After building the normal 1x1 in a separate physical smoke, on first nonself overlap at the doorway threshold:

1. Log pre-throw actual body, contact, world point, portal, velocity, floor rays, full collider list. Then enter a short explicitly labeled `OBSERVE_CONTACT_ONLY` mode. This is **not** a change to gameplay collision admission: do not emit accepted `Clear`, `CROSSED_IN`, `CROSSED_OUT`, HOME_NAV_GREEN, or product-level PASS while contact is present.
2. Observe at bounded intervals/ticks, native movement and all contacts for a narrow limited displacement/time window; cap by conservative fixed seconds and distance. No manual transform writes, warp, collision/layer toggles, resize, fake gravity, Rigidbody force, NPC teleport, or native override of world objects. If velocity is nonphysical, contacts deepen/persist, other solid obstacles/foreign objects appear, or capsule sweeps across wall: stop as **NONPHYSICAL_CLIP/UNSAFE**, not GREEN. If owner safety cannot be guaranteed without fail-closed immediate throw, do not run this mode.
3. Record contact evolution and classify outcomes separately: `RESOLVED_NATIVE` with observed support and collision clearance; `NATIVE_STUCK` with bounded no-progress; `KINEMATIC_CLIP` if continuous path crosses occupied mesh despite penetration; `UNKNOWN` if unsupported. HumanNPC.IsOnGround must not be used as sole support proof. Native ComputePenetration on fresh poses; actual foot/floor ray and nav-mesh sample; swept capsule/contact along path, no false `PathComplete` success from enum defaults.
4. Even if agent moves through: do not promote to gameplay until proven no persistent real body obstruction / side pass of wall / physics bypass. A kinematic RustNav entity can report movement while interpenetrating. Acceptability must be decided from measured contact and native geometry, NOT from reaching a waypoint alone.

## B. Alternative paid native building geometry (when A is physically unsafe)

Investigate **installed actual prefab/Construction socket API** for native small steps/ramp/structural placement, and/or a site/foundation height variant that produces a *supported*, non-overlapping path through native doorway. Candidate is permitted only if this is a real Rust supported construction, paid exactly via loaded blueprint/grade/TC costs, registered with buildingID/save/stability/decay and not manually adjusting terrain or prefab colliders. No new free floor colliders or fake invisible ramps. If a small ramp/step changes layout from exactly eight entities, define a versioned home schema with explicit additional native roles/payments/restore witnesses and backwards compatible 010–014 diagnostic tests; don't silently assert an eight-entity house.

Static possibility != successful runtime: require a native RustNav projected path whose y comes from actual support geometry, full-size r0.5/h1.8 capsule clearance at portal, no manual Y/baseOffset override. Prefer bounded site-conditioned test in same smoke if trustworthy before paid irreversible placement. Without such an admissible native construction path, give precise `PARTIAL/ENGINE_BLOCKED` and stop; do not add a fabricated one.

## C. Native locomotion investigation (conditional, more risky)

Inspect installed `NPCPlayerNavigator`/`BaseNavigator`, native step support/CharacterController/Rigidbody and BasePlayer movement IL. An alternative movement mode is acceptable only after proving **same player-derived actor**, maintained full-size collider and ownership, actual collision/step response, physical samples and no manual position writes, with a real RustNav-compatible plan. Switching to a 0.25m sphere ray to impersonate a player-size capsule is forbidden. A new locomotion component solely to bypass collision guard is NOT admissible.

**Decision:** best evidenced of A/B/C, not all at once. Do not spend weeks on endless local exception flags. If none works safely, document architectural blocker and suggest choosing a different real native entry geometry for later gameplay, without claiming current 1x1 is traversable.
