# API decision 005 — 2026-11-03

Decision: retain ScientistNPC2 / RustNav and label crafting **SERVER_ACCOUNTED_CRAFT**. No BasePlayer bridge, Steam identity, native player queue or equipment simulation. Installed code, serialized assets and live receipts are separate evidence classes.

Read-first sources: AGENTS/README, complete 005 package, results 001/003/004, 004 API_DECISION, LIFE_ROADMAP; Survival, WorldRoam, runner, validators, compile and metadata tools. Ancestor/nested AGENTS, csproj/props/targets and code-map/pattern files were not found. Existing local patterns: 004 native source debit/condition, 003 native container serialization/world proof, 001/003 SetFsmActive(false) and RustNav. C# 7.3, Windows PowerShell 5.1, no runtime dependency changes.

## Fingerprints and static evidence

| Installed file | SHA-256 |
|---|---|
| RustDedicated.exe | EFAC429DB737EB4B32A2BFC48029B4BE6FF475336958F4557F891F17255FFD38 |
| Assembly-CSharp.dll | 04FB89520F18A1920C1B1A350B82DD24A4258F31D97B82496971A9CC7A49DCB7 |
| Oxide.Rust.dll | 2128121E34B55BB1550D43E62842B87EA3720059F13DC84F97D8C7DD465C3423 |
| Bundles/shared/items.preload.bundle | 19A05C0C2BA11A12408C1E820CC9547051D5AE47A685F89D81C21B763E05EE73 |

Unity executable file version 6000.3.15.11082995 and Oxide 2.0.7839. Rust protocol/build must be read from the live log, not inferred from PE version. Raw fingerprints: `.local/audit/craft005/fingerprints.json`. Metadata-only inspector does not execute game DLLs: `api.txt`, `debit-il.txt` in the same ignored directory.

Read-only UnityPy 1.25.4 was installed in ignored audit/pythonlibs to parse the installed bundle, not added to runtime or project dependencies. `read-assets.py`, `assets.json`, `assets-summary.txt` retain MonoBehaviour/GameObject links and resolved ingredient references; 8497 objects, 6841 selected records, zero parse errors. No Rust process was needed for this gate.

## Recipe gate before first live

Installed asset **stonehatchet**, item ID **-1583967946**, ItemBlueprint attached to the same GameObject: **wood (-151838493) 200 + stones (-2099697608) 100 → 1 stonehatchet**. defaultBlueprint=true, userCraftable=true, workbenchLevelRequired=0, time=15 seconds, no recipe overrides, no NeedsSteamItem/RequireUnlockedItem, no Steam DLC reference. Useful wood tool and naturally harvestable ingredients; stone.pickaxe has the same installed costs but only one product is needed.

Negative installed example **rifle.ak**, ID 1545779598: defaultBlueprint=false, workbench level 3, 45 seconds; metal.refined 50, wood 200, riflebody 1, metalspring 4. The actor has no learned knowledge, bench or these components. Live additionally attempts stonehatchet before harvesting, when its real ingredients are absent. A denial counts only if inventory and all natural resource pool fingerprints remain equal.

Loaded runtime always re-reads `ItemDefinition.Blueprint`, `ItemBlueprint.GetIngredients()`, `GetWorkbenchLevel()`, `GetCraftTime()` and amountToCreate immediately before each attempt. Raw asset prices are **not** constants in execution. GetIngredients IL_0000..0067 applies recipe/game-mode overrides; GetWorkbenchLevel IL_0000..0022 applies override. Nonfinite/fractional/duplicate/empty costs and output beyond a single native stack fail closed.

## Installed API/IL and supported policy

| Capability | Decision / evidence class |
|---|---|
| Gen2 inheritance | SUPPORTED / STATIC: ScientistNPC2 : BaseNPC2, not BasePlayer. Existing navigation proven 001/003/004; 005 requires its own receipts |
| Native player queue | UNSUPPORTED for this actor: PlayerInventory.crafting : ItemCrafter; owner : BasePlayer; containers/queue. CraftItem(ItemBlueprint,BasePlayer,InstanceData,int,int,Item,bool,int) calls CanCraft then CollectIngredients, hooks and queue; not the complete blueprint/bench guard |
| Player blueprint/bench | STATIC_ONLY: PlayerBlueprints.CanCraft(int,int,BasePlayer) IL_0044..006B compares currentCraftLevel with GetWorkbenchLevel, then HasUnlocked. HasUnlocked IL_012E..0150 uses ItemManager.defaultBlueprints after entitlement checks |
| Accounted unlock | SUPPORTED: only defaultBlueprint AND membership in loaded ItemManager.defaultBlueprints; Steam item/DLC/RequireUnlockedItem rejected. No learning claimed |
| Accounted bench | SUPPORTED: available level fixed at 0, only actual requirement 0 accepted; higher levels denied. No native proximity, bench placement or research claimed |
| Era/game mode | SUPPORTED / STATIC: ItemDefinition.IsAllowed((Rust.EraRestriction)4), exactly the value used by installed ItemCrafter.CanCraft IL_0000..000E |
| Ingredient debit | SUPPORTED / STATIC: Item.UseItem(int), IL_0029..0060 reduces amount, invokes hooks, removes full stacks or MarkDirty. Verify actual delta; Remove queues destruction, so zero stack is detached with public RemoveFromContainer before comparison/save |
| Output | SUPPORTED / STATIC: ItemManager.Create(ItemDefinition,int,ulong) after verified debit, MoveToContainer(...,false); exact UID/amount/condition/native inventory comparison |
| Timing | Synchronous accounted transaction. Loaded craft time is reported as metadata, not a simulated player queue or a claimed 15-second native task |
| Identity/persistence | Reuse native ItemContainer Save/Load and actor JSON with world/cache/generation/snapshot hashes. CRAFTED intent/product UID saved; RESTORE performs no harvest/craft/kit award |
| Future avatar bridge | NPCPlayer : BasePlayer has inventory/player APIs and RustNav field (STATIC_ONLY). Migration may enable native queue/equipment; exact prefab/ownership/AI/progression remains UNKNOWN and is outside 005 |

Craft latches its one irreversible intent before any debit. Failure after debit ends IRREVERSIBLE_PARTIAL without rollback/recredit. This is not a crash-atomic production ledger. RESOURCE_POOL_PERSISTED remains NOT_IMPLEMENTED: native pools may reset on restart, as established in 004. Future work needs a durable per-world stable-entity depletion journal with idempotent replay and crash recovery. RESTORE is deliberately read-only for gameplay.

Live 1 `8f6f793e39fa471d8aa4e936fcd66033`: loaded stonehatchet matches asset costs/output, known=true from actual default list, allowed=true, bench=0, GetCraftTime=15. Actual native debit of 40 earned UID paid 200 wood +100 stones and created stonehatchet UID 65008, condition 100. The same installed recipe was denied before harvest (missing ingredients), rifle.ak was denied with actual unknown/bench3/missing reasons, and duplicate intent was denied. These are **LIVE_PROVEN accounted** recipe/gate/debit/output capabilities, not native PlayerBlueprints/queue enforcement. See RESULT and raw receipts for independent reconciliation and restart status.

The rifle.ak asset time is 45, but loaded GetCraftTime returned **35** in this runtime. No timing simulation is used; this difference is recorded rather than substituting asset values for the actual loaded method. Its live ingredient/bench/known fields are retained in plugin-result. Unsupported native equipment/queue/learning stay unsupported regardless of accounted success.

Live 2 `240c374bfd7345aeaeb4749e346f1e8b` independently restored exact rock/crafted UID, amount and condition, logical identity/goals/completed intent. No harvest/craft replay and no new kit. Native inventory serialization/world binding is now **LIVE_PROVEN** for this bounded artifact; native resource pool durability remains unsupported/not proven.
