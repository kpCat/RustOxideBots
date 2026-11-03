# API decision 006 — installed player avatar gate

## Decision before live (STATIC / OFFLINE)

A reasonable native candidate exists. Test **ScientistNPC_Roam**, using its existing PlayerInventory and RustNavMeshAgent. Preserve Gen2 and all 001/003/004/005 plugins. No shared avatar abstraction or production migration is needed. This static decision is not live evidence.

Sources: installed Assembly-CSharp metadata/IL via scripts/Inspect-RustApi.cs without executing game assemblies; AssetSceneManifest.json and serialized assetscenes.bundle via the already available UnityPy reader; existing project probes and safety runner. No DLLs, assets or owner files changed. Raw dumps and serialized fields remain ignored in `.local/audit/avatar006/api-agent/`.

| Installed artifact | SHA-256 |
|---|---|
| Assembly-CSharp.dll | 04FB89520F18A1920C1B1A350B82DD24A4258F31D97B82496971A9CC7A49DCB7 |
| Oxide.Rust.dll | 2128121E34B55BB1550D43E62842B87EA3720059F13DC84F97D8C7DD465C3423 |
| AssetSceneManifest.json | C5E9B45F5C53A8105FFFE611A09BDEEFEAA8A8F4F1815B33F65E7DC84D72B7AC |
| assetscenes.bundle | 49427FEB91FC8A80E344700D2ED4D478847A66924C43B1BE01BD8083848D17F3 |

Oxide.Rust version 2.0.7839.0; Assembly-CSharp PE version 0.0.0.0 is not a Rust release identifier. Executable compile uses installed DLL references with C# 7.3; orchestration remains PowerShell 5.1.

## Candidate and lifecycle

Exact manifest prefab: `Assets/Rust.Ai/Agents/NPCPlayer/HumanNPC/Scientist/ScientistNPC_Roam.prefab`, prefabID 4199494415. Serialized script is ScientistNPC, deriving through HumanNPC/NPCPlayer from BasePlayer. Enabled components include PlayerInventory, PlayerMetabolism, PlayerEyes, ScientistBrain, NPCPlayerNavigator and Rust.Ai.Gen2.RustNavMeshAgent. LegacyNavigation=false, enableSaving=false, syncPosition=true, two native loadouts, health=150; agent type=0, areaMask=25, height=2. Patrol and roam variants also exist. NPCPlayerTest has no RustNav agent/navigator and is unsuitable. Runtime discovery rechecks actual manifest entries/components; it does not treat stale prefabs.txt as authoritative.

NPCPlayer.ServerInit configures its NavAgent and initializes the native BaseNavigator for the non-legacy backend. BasePlayer.ServerInit assigns an engine bot ID when userID is zero, initializes inventory and native ownership. The probe never assigns a Steam/user ID or connection. Actor identity must be IsNpc, no connection, native ID below 10000000. Sleeping, flags, concrete type, brain, FSM and net ID are recorded. Spawn once, enableSaving=false, Kill during probe cleanup; no sleeping/disconnect simulation.

Important scheduler detail: NPCPlayer.ServerInit sets NavAgent.updatePosition/updateRotation=false for native navigator control. BaseAIBrain.SetThinkMode(None) suppresses AI state thinking, but SetEnabled(false) alone does not cancel its independent TickMovement scheduler. After Unity Start has initialized the one test actor, the probe sets think None, disables its own brain, disables brain sleep and cancels the actual TickMovement delegate via public FacepunchBehaviour.CancelInvoke(Action). Then it enables native agent position/rotation updates, normal Jog/speed and SetDestination. LegacyNavigation stays false; the legacy NPCPlayer.MovementUpdate path is not used. FSMComponent, when present, is stopped via existing SetFsmActive(false). No MovePosition, Warp or transform position assignment after spawn is introduced by probe code. Native engine integration still requires live proof.

Prelive review identified an additional installed lifecycle gate: changing AllowedToSleep does not remove an already registered IAISleepable. AIInformationZone.SleepAI can pause the navigator; WakeAI resumes it and restarts TickMovement. The probe unregisters only its own brain from public AIInformationZone.zones via UnregisterSleepableEntity(IAISleepable), wakes it through IAISleepable if brain.sleeping, then performs the final CancelInvoke. Other zone entities are untouched. This prevents a later zone wake from reinstating competing movement.

## Native inventory and equipment

Verified signatures include BasePlayer.inventory:PlayerInventory; PlayerInventory.containerMain/containerBelt/containerWear:ItemContainer; Item.GetOwnerPlayer():BasePlayer; ItemContainer.GetOwnerPlayer():BasePlayer; BasePlayer.UpdateActiveItem(ItemId), GetActiveItem():Item, GetHeldEntity():HeldEntity; NPCPlayer.EquipWeapon(bool); HeldEntity.SetHeld(bool), GetOwnerPlayer():BasePlayer; inherited GetParentEntity():BaseEntity.

PlayerInventory.ServerInit initializes real main/belt/wear UIDs and playerOwner. Moving the real fixture into this belt invokes ItemModEntity.OnParentChanged: the native item-owner/root-container path creates and parents the held prefab. ItemModEntity.playerOnlyEntity refuses a missing player owner. ItemModEntity/held creation is not replaced by a manually spawned prop, SetParent or forcedOwner. The probe calls guarded native UpdateActiveItem(fixture.uid); NPCPlayer.EquipWeapon(false) uses the same native active-item path but normally chooses belt slot zero. Keeping default items and selecting the exact fixture UID avoids deleting the native loadout.

UpdateActiveItem finds native belt items, deselects the previous held object, selects the matching item and calls SetHeld(true). GetActiveItem resolves native belt UID with server/alive gates; GetHeldEntity derives from that active item. HeldEntity.GetOwnerPlayer uses forcedOwner or parent.ToPlayer. Probe never sets forcedOwner: both actual parent and owner must equal this actor. SetHeld(true) sets native numeric flag 1024, clears Disabled(64), updates visibility/network state and sends a network update. There is no installed IsHeld() method; read HasFlag((BaseEntity.Flags)1024). Headless flag evidence does not establish client rendering or animation.

**Negative gate is an explicit guard, not an invented engine guarantee.** Installed UpdateActiveItem can accept an absent UID into svActiveItemID and leave GetActiveItem null. The probe resolves ItemId via the installed public ItemContainer.FindItemByUID(ItemId), then validates the actual belt, direct membership and native GetOwnerPlayer before calling it. Missing and actual foreign-world item requests are refused before the unsafe native call; actor inventory/active selection and foreign item must be unchanged. This distinction is logged as GUARD_BEFORE_NATIVE_UPDATE_UID / NATIVE_BELT_UID. ItemId(ulong) is public in Rust.Data.dll; ItemManager.GetAllItems() confirms that the nonzero missing UID has no real Item. No fake native rejection is claimed.

The first source version used TryActivate(null) for its missing case, with a requested UID only in its report. Independent semantic review correctly limits that evidence to NULL_ITEM_GUARD. Version 0.1.1 routes valid, missing and foreign ItemId through the same native lookup. First-run raw source/results are preserved; a second bounded live start is justified by this concrete coverage defect. Final validator rejects the old missing receipt.

The only created kit is one native rock, labelled TEST_FIXTURE. It is neither harvested nor the earned/crafted UID from 005. Default loadout is preserved exactly. Foreign negative uses an existing natural LootContainer item without transfer or creation. All item/active/held ownership and fixture conservation are independently validated. BaseMelee is a held BasePlayer-owner consumer; combat, ServerUse, PlayerBlueprints/native crafting queue and native resource yield are not invoked or established here.

## Planned live proof and cost bounds

One physically isolated RustDedicated through the existing cache/job/firewall runner. Full RustNav readiness, one candidate, one TEST_FIXTURE rock in its existing PlayerInventory, native active/held receipts, missing/foreign guard negatives, then three dynamic complete paths of about 32 m. Record continuous time/position and active/held owner for the same actor; independent validator reconstructs >=60 m, >=2 legs and >=20 m net in one leg. Any lost held entity, stuck agent, discontinuity or missing native ownership yields PARTIAL rather than a replacement actor/teleport. Graceful quit, save receipt, owned job disposal and PID/port/firewall/lease verification are mandatory.

Second live start is reserved for an observed technical defect or optional bounded restart proof. PERSISTENCE is NOT_VERIFIED unless actually implemented and run with exact world/snapshot binding. Client appearance/animations, PvP, native crafting, production economy and 50–100 NPCs remain NOT_VERIFIED. Existing Gen2 accounted model remains unchanged regardless of gate outcome.

## First live observation and second-run boundary

Run ada3c026240f4f84acf5d3516c2d3c2d is PARTIAL, not promoted. The same ScientistNPC reached two targets (30.9718361 +31.4690571 =62.4408932 m) with native rock active/held throughout. Both paths were issued PathComplete; first raw arrival was PathComplete, second raw arrival PathInvalid/no-path/remaining=0 at about 0.990 m from target. Its third path stalled after 0.043604 m, despite PathComplete/hasPath/isStopped=false; one repath did not recover in 20.499 s. Inventory and held ownership remained valid; graceful shutdown and cleanup passed. Raw statuses are retained, not renamed.

Targeted IL then established the relevant native state transition: Tick IL_039B..03B6 computes remaining corner distance and calls ResetPath for the final corner at RestingDistance; ResetPath clears followingPath/corners and sets desiredSpeed=0. get_pathStatus returns PathInvalid when hasPath=false; remainingDistance returns zero. This prefab has letUnityMoveAgentIfPossible=true, so RestingDistance(1) is 1 m. The observed second arrival is consistent with normal path consumption; the exact private branch was not traced. ResetPath has other failure callers, so invalid/no-path alone cannot prove arrival.

SetDestination/SetPath do not restore desired speed. The first source set speed only once; this explains the next accepted path not moving after native path reset. Source 0.1.1 explicitly sets speed=3 after each successful SetDestination and bounded repath and records speed before/after. Second run retains all three planned transitions to test this specific defect, alongside the corrected UID guard. It preserves PlannedPathStatus, planned length, IssuedPathStatus and raw arrival PathStatus/hasPath/remaining separately. Continuous samples include actual path state; terminal PathInvalid is acceptable only at <=1.05 m, remaining zero, no stuck/repath, with every intermediate moving sample PathComplete/hasPath=true. Early invalid/partial or invalid away from the target remains failure. Thresholds >=60 actual, >=2 legs, >=20 net remain unchanged. First-run raw evidence and failed leg remain in sanitized RESULT; persistence is NOT_VERIFIED.

## Final LIVE decision

Run 1f413b585dde4380ac361dc3c965c9af passes the same-actor gate: ScientistNPC with native PlayerInventory, real rock UID 73556/held 73557 owned and parented by actor 73508, guarded missing/foreign ItemId lookup, and 93.6954901486 m of independently reconstructed physical travel across three paths. Native speed before leg 3 is actually 0, restored to 3, then 31.2612724 m traveled with zero stuck/repath. Raw terminal leg 2/3 PathInvalid/no-path/zero states are preserved and satisfy the strict native consumption endpoint contract. Actual Oxide compilation, native ACK/save and clean shutdown are separately verified. See RESULT for exact receipts.

Player-derived native ownership/navigation is **LIVE_PROVEN within 006**. This does not prove a real Steam session, client rendering/animations, native attack/gather/crafting, persistent native avatar identity or production reliability/scale. Keep Gen2 unchanged; next bridge is an independently scoped task. No dual-avatar emulation is justified by this result.
