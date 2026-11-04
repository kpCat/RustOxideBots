# 008 — installed API decision (STATIC_IL)

The old early guard confused a saved network reference with durable item ownership. Item.Load IL_00D2–00EF copies worldEntity/heldEntity into EntityRef; EntityRef.Get resolves the ID in the current server realm. Passing a saved alias to Load is unsafe. A validated, detached protobuf copy must contain zero held references before native Load. Merely finding an entity at that number does not authorize any mutation of it.

Installed files rechecked unchanged against 006/007:

| Artifact | SHA-256 |
|---|---|
| Assembly-CSharp.dll | 04FB89520F18A1920C1B1A350B82DD24A4258F31D97B82496971A9CC7A49DCB7 |
| Rust.Data.dll | 1D62BAEF9B339F0416E6529618365C1ECAD01791A833E77E76EB6C8464406104 |
| Oxide.Rust.dll | 2128121E34B55BB1550D43E62842B87EA3720059F13DC84F97D8C7DD465C3423 |
| RustDedicated.exe | EFAC429DB737EB4B32A2BFC48029B4BE6FF475336958F4557F891F17255FFD38 |

Read through the existing PEReader metadata tool; no game assembly was executed for this analysis. Raw IL is ignored under `.local/audit/avatar008/`.

| Native method | Verified behavior / decision |
|---|---|
| PlayerInventory.Initialize / ServerInit | Existing main/belt/wear are initialized for the new BasePlayer; retain native playerOwner, never double-initialize. NPCPlayer.ServerInit uses BasePlayer initialization and existing navigator, as in 006. |
| PlayerInventory.Strip | Clears all three containers, then ItemManager.DoRemoves. Only the newly spawned probe actor's default kit is normalized. |
| PlayerInventory.Save(true,true) / Load | Save includes main/belt/wear. Load delegates to those existing containers; does not reconstruct playerOwner from the previous actor. |
| ItemContainer.Load | Restores container UID/capacity; ItemManager.Load restores each original Item UID, raw parent and slot (IL_01B0–01DF). It does not run Item.SetParent. Reject duplicate incoming Item/container UIDs, wrong roles/slots, nested contents and worldEntity before this call. |
| Item.Save / Load | Save serializes Item.uid plus transient held/world network IDs. Load directly assigns original UID (IL_0066–006D), amount/slot and condition/maxCondition; RegisterUID advances allocator bookkeeping. No replacement ItemManager.Create is used in RESTORE. |
| Item.RecalulateParentEntity(false) | Calls each installed ItemMod.OnParentChanged (IL_0000–0021). Run after native ownership/row validation. A second pass must leave the same held objects, proving idempotence for these two installed item types. |
| ItemModEntity.OnParentChanged | If a player owner exists and held is absent, CreateEntity creates the native held prefab; then ParentToPlayer uses the root container owner. A nonzero alias would take the existing-entity path, which is why sanitation must precede Load. |
| HeldEntity.SetupHeldEntity / GetItem | Setup stores ownerItemUID and initializes native owner. GetItem resolves that UID through the owner's real PlayerInventory. Require GetItem UID, parent, owner and distinct new net IDs for rock and axe. |
| BasePlayer.UpdateActiveItem | Native belt lookup and SetHeld(true); an absent UID is not inherently refused. Reuse the explicit belt/owner guard, then verify native active Item and held flag 1024 over multiple ticks. |
| NetworkableId versus ItemId | Separate installed value types. The former is a current server network lookup key; the latter is restored Item identity. Neither a matching number nor an absent old held entity establishes ownership. |

Only heldEntity is cleared, only after binary rows exactly match bound actor-state and source/world proof. Nonzero worldEntity and nested items still fail closed. Each old ID is inspected before sanitation and again afterward without killing, moving or reparenting its resolved entity. Incoming item UIDs already present globally still fail closed. No forcedOwner, manual SetParent, fake player ID, harvest, craft or starter kit is added to RESTORE.

Prelive review additionally closed empty-WEAR capacity/UID coverage: validate all three containers outside item loops, enumerate installed IInventoryProvider roots plus live item parent/contents, and reject even an empty unsupported nested container. Independent receipts bind MAIN/BELT/WEAR UIDs, exact tool/product held sets and active held ID. A proven conservation failure reports FAILED, including the delayed Setup callback. Collision inspection uses BaseEntity.GetItem for WorldItem as well as HeldEntity; an unavailable owner network ID is explicitly UNKNOWN, without exposing an account OwnerID.

Allocator limitation: native RegisterUID raises its high-water mark; a new held object could theoretically reuse an absent saved numeric ID. This probe conservatively requires distinct old/new held numbers and would report PARTIAL at the native held gate in that case; it never advances the allocator or calls it foreign mutation solely because a number is reused. This stricter acceptance is safe for the verified source and must be reported honestly if encountered live.

Prelive source 007 was eligible: immutable inventory/state hashes and cached generation/save hash matched the original clean JOURNEY proof. Its raw PARTIAL RESTORE is preserved. The historical 007 collision type is UNKNOWN because 007 did not record it. The completed 008 process recorded old 81011 absent and old 87252 aliased to an unrelated IOEntity, then independently proved native restore (RESULT.md). Its shutdown promoted a new cache generation; any later restore must recheck the full binding rather than assume this prelive eligibility still holds. Static IL and synthetic fixture success alone are not live restore proof.
