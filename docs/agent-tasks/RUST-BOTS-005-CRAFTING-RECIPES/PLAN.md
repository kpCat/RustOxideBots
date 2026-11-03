# 005 implementation plan

Spec: [TASK.md](TASK.md), GATES/ACCEPTANCE/EVIDENCE. Execution: inline, autonomous as requested.

Goal: one Gen2 actor pays a loaded Rust recipe with naturally harvested items, denies an unavailable recipe, then restores the exact crafted inventory in a separate process.

Architecture: extend RustBotsSurvival, retaining its source debit, tool wear, RustNav and native inventory serialization. An intentionally limited SERVER_ACCOUNTED_CRAFT accepts default, unrestricted recipes in a grounded owned context with bench level 0. It never impersonates a player or unlocks knowledge. No native queue/equipment claim.

Constraints: C# 7.3; current master; no owner writes/update; existing physical cache/firewall/job lifecycle; two live processes, a third only for a diagnosed defect. Raw evidence stays ignored. Resource depletion across restart is not solved; RESTORE cannot harvest/craft.

Bounded scope exception: up to 18 public paths for this one slice: existing Survival plugin, runner, SurvivalValidation, Test-All, README; new CraftValidation/Test-Craft; supplied 005 task documents and PLAN/API_DECISION/RESULT. No edits to other task families or safety infrastructure.

## Tasks and checks

- [x] Read-first, local/remote baseline and installed metadata/IL.
- [x] Inspect installed recipe assets; document static versus loaded runtime rules in API_DECISION.
- [x] Add focused validator fixtures first and observe RED for absent craft support. Cover absent recipe, ingredients, unlock/bench, partial UID debit, wrong multiplier, duplicate, output interruption, condition, replay/world binding.
- [x] Extend Survival with recipe-driven needs, synchronous Item.UseItem debit verification, output verification and immutable intent completion. Keep legacy GATHER intact.
- [x] Add exclusive -SurvivalCraft runner route and exact state/world binding; run fixtures, all offline legacy checks and installed DLL compilation before live.
- [x] Live 1 CRAFT: one natural gather journey, loaded recipe, live denial without item/pool mutation, one successful craft and duplicate-intent denial; graceful save/shutdown.
- [x] Live 2 RESTORE: separate process, exact UID/amount/condition/actor completion, no kit/harvest/craft replay; graceful shutdown.
- [x] Independent review, owner hash comparison, process/port/firewall/lock audit; RESULT with actual limitations.
- [x] Separate mojibake and escaped Cyrillic scans, public secret scan and final 18-path scope allowlist prepared. Exact staged review/commit, ordinary origin master push and remote SHA verification follow this artifact; their post-commit receipt is `.local/audit/craft005/delivery.json` and the final response.

Review focus: recipe override versus raw asset cost; unsupported entitlement gates fail closed; no award after partial debit failure; consumed UID removal and remaining partial stacks; restore rejects crafted completion replay; source coordinates stay tied to physical samples; old gather/world/nav routes remain intact.

## Execution ledger

Baseline local HEAD and cached origin/master d9147f18a6e4671cb76d3c042e9d85f2f2f18639; actual remote master verified over HTTPS. Only supplied 005 package was untracked. SSH has no usable key; temporary HTTPS insteadOf is the existing repository delivery analogue.

Task authorization overrides generic skill approval/worktree defaults: work autonomously on master, preserve this task's evidence under .local/audit/craft005, commit once after verification. No extra approval gate or unrelated workspace helper is introduced.

Prelive review: a fresh read-only agent identified false-GREEN paths (missing Crafting route dispatch, selected/paid recipe mismatch, nonexistent recipe counted as real negative, broken output/empty intent), an inaccurate interruption fixture and null dispenser handling. RED receipts: review-red*.txt; fixed in one pass with focused tests and installed-DLL compile. No runtime processes were used for review. Timing stays synchronous accounted; native 15-second queue is not implemented. No production depletion journal is added.

Live 1 8f6f793e39fa471d8aa4e936fcd66033 CRAFT=GREEN; live 2 240c374bfd7345aeaeb4749e346f1e8b RESTORE=GREEN. Both native compiled/loaded, GRACEFUL, exit -1 after complete native save. Independent reconciliation and cleanup passed; Server 3086 files, 0 changes. Third run unused. Exact code hash matches both run snapshots; only documentation changed after live.
