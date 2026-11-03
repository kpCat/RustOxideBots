# RUST-BOTS-005 — RESULT, 03.11.2026

**Итог: GREEN в ограниченном test-only scope 005, механизм SERVER_ACCOUNTED_CRAFT.** Один Gen2 NPC физически добыл и оплатил 200 wood +100 stones за настоящий stonehatchet; реальный отказ и защита от повторной выдачи подтверждены. Второй независимый процесс восстановил точные UID/amount/condition и завершённый intent. Ровно **2 live запуска**, оба GRACEFUL. Все **3086 owner файлов Server неизменны**, остаточных процессов/портов/firewall/занятых locks нет. Native player queue и видимая экипировка не заявляются.

Baseline local master, cached origin/master and actual remote master: `d9147f18a6e4671cb76d3c042e9d85f2f2f18639`. Only the supplied 005 task package was initially untracked; no foreign source changes were found. SSH remote read failed for missing key; HTTPS read confirmed the same master without changing origin configuration.

| Required part | Status | Evidence |
|---|---|---|
| NATIVE_PLAYER_CRAFTING | UNSUPPORTED for this Gen2 actor | Installed BasePlayer/ItemCrafter ownership; no native queue used |
| SERVER_ACCOUNTED_CRAFT | GREEN / LIVE_PROVEN | Real loaded recipe, verified debit then native output UID 65008 |
| BLUEPRINT_GATE | LIVE_PROVEN accounted policy | Actual loaded default known recipe allowed; rifle.ak unknown denied; no learning |
| BENCH_GATE | LIVE_EVALUATED accounted policy | Positive requirement 0; rifle.ak requirement 3 versus context 0, part of co-denial; no native proximity or bench-only proof |
| INVENTORY / CONSERVATION | GREEN | Natural debit 300 units, exact 40 ingredient UID consumed, one output, duplicate intent no changes |
| PERSISTENCE | GREEN | Separate process, exact native snapshot/world binding, both final UID/condition and logical completion restored |
| NAVIGATION | GREEN | 4 complete legs, independently reconstructed 71.69658767 m, no warp |
| SAFETY | GREEN | Owner SHA comparison 3086/3086 unchanged; owned/helper/ports/rules/lock failures=0 |
| CODE / TESTS | GREEN | Legacy suite, focused RED→GREEN fixtures, installed C#7.3 compile and actual live Oxide compilation in both processes |
| GIT | Exact-path delivery | 18-path allowlist; commit and ordinary master push, final SHA/remote check recorded after delivery in ignored delivery.json and final response |

## Mechanism and limits

**SERVER_ACCOUNTED_CRAFT**, reusing the existing Gen2 Survival plugin. **NATIVE_PLAYER_CRAFTING=UNSUPPORTED**, **NATIVE_EQUIPMENT=NOT_NATIVE_EQUIPPED**. No player inventory, native queue, Steam identity, research, bench construction or avatar migration. Loaded craft time is metadata; the accounted debit/output transaction is synchronous.

Installed asset recipe and API/IL are documented in [API_DECISION](API_DECISION.md). Live re-reads the installed ItemBlueprint and default blueprint list. The initial kit is exactly one rock, explicitly separate from harvested ingredients. Existing 004 source debit/condition pipeline is preserved; output is awarded only after verified native source debit. Craft pays existing Item UID via UseItem, verifies the complete inventory, then creates and transfers the exact recipe output without stacking. Used intents cannot award twice.

Resource dispenser depletion across restart is **NOT_IMPLEMENTED / NOT_PROVEN**. Native world save does not serialize the exact dispenser pools. RESTORE forbids new harvest/craft/kit award; future production needs a durable, idempotent, per-world stable-entity depletion journal and crash recovery. Craft failure after debit is IRREVERSIBLE_PARTIAL with no rollback/recredit; a crash-atomic economic journal is outside this slice.

## Live 1 — actual recipe, movement and economy

Run `8f6f793e39fa471d8aa4e936fcd66033`, CRAFT, runner exit 0. Rust protocol **2635.289.1**, build date `10/22/2026 19:30:56`; Oxide.Rust **2.0.7839**, plugin **0.2.0**, Unity executable version **6000.3.15.11082995**. Plugin snapshot SHA-256 **37666589DEB9B66B1466BE3313511AFEA526010BB93957333B93354AA464B4FF**. Server log proves actual Oxide compiled successfully / loaded, not just offline compilation.

Loaded `stonehatchet` ID **-1583967946**, amountToCreate=1, **wood (-151838493) 200 + stones (-2099697608) 100**, default/known/userCraftable/allowed=true, workbench=0, craft time metadata=15. Gen2 owned ItemContainer with the actual default list, no entitlement/learned substitution. Native player craft queue is not invoked.

Actor `Rust.Ai.Gen2.ScientistNPC2`, installed `Assets/Rust.Ai/Agents/NPCPlayer/HumanNPC/Scientist/Gen2/Scientist2.prefab`; logical ID `survivor-005-8f4d9d9c2be64993b3fe37065be66813`. Native scheduler stopped through SetFsmActive(false), navigation only through RustNav. The planner discovers geometry/resources by deficit; coordinates below are observations, not configured targets. Rejected source memory includes the unreachable approach #6978, then completed #6975/#5648. No fixtures or free resources were created.

| Natural source | Position on synthetic map | Pool before → after | Hits / earned | Reach |
|---|---|---|---|---|
| TreeEntity #6975, `v3_temp_field/birch_small_temp.prefab` | -31.2587, 7.2966, -304.9832 | 375 → 175 | 20 × 10 wood = 200 | 1.55115 m |
| OreResourceEntity #5648, `ores_sand/stone-ore.prefab` | -64.5744, 4.2143, -325.4796 | 750 → 650 | 20 × 5 stones = 100 | 1.57151 m |

Each hit records native pool debit before output, unique earned UID, clear LOS/ground/range, tool UID/wear and actor coordinates tied to a continuous sample. Two native Gen2 probes gave zero native yield/drops; adapter hits disable CanGather and do not kill the source. Source health after hits: tree 696, ore 458. This remains **SERVER_ACCOUNTED_TOOL**, with actual installed rock profile and no held-equipment claim.

Physical route: **4 ARRIVED / PathComplete legs**, distances **29.87237 + 1.73532 + 29.86180 + 10.22710 = 71.6966 m**. Independent reconstruction: **71.69658767 m**, 161 continuous samples, max step 1.57585 m, max sample gap 0.558753 s, max observed speed 3.57349 m/s; stuck/repath=0. Every leg chains to the next. No post-spawn warp/position assignment. All coordinates belong only to synthetic seed 424242 / size 2000, not the owner world.

| Recipe attempt | Actual result | Mutations |
|---|---|---|
| stonehatchet before harvest | DENIED / MISSING_INGREDIENTS; rock only | 0 item changes, 0 source pool changes |
| rifle.ak after harvest | DENIED / BLUEPRINT_UNKNOWN; additional evaluated reasons WORKBENCH_REQUIRED (3 > 0), MISSING_INGREDIENTS | 0 item changes, 0 source pool changes |
| stonehatchet, one intent | CRAFTED / PAID | 40 exact earned UID debits, output UID 65008 |
| same completed intent again | DENIED / INTENT_ALREADY_USED | 0 item changes, 0 source pool changes |

The live rifle metadata differs from the serialized asset's time: loaded GetCraftTime=35 seconds versus asset time 45; raw loaded metadata is retained. Blueprint/bench evaluations are accounted policy checks, not independent native player enforcement. There was no bench-only attempt with an otherwise unlocked recipe; the required negative is independently established by the real stonehatchet ingredient refusal.

Before craft: **41 UID / 301 units** = starter rock 1 + earned wood 200 + earned stones 100. UseItem consumed all 20 wood stacks ×10 and all 20 stones stacks ×5, verified each native amount and synchronous detachment of zero stacks. Examples: wood UID 60705/60706, 10→0 each; stones UID 65006/65007, 5→0 each. All 40 exact rows remain in Crafting.Attempts[2].Debits. Their disappearance is legitimate recipe consumption. Live does not claim a partial-stack debit; its 10→3 UID preservation is covered by the offline contract fixture.

After craft: **2 UID / 2 units**: starter rock UID **58401**, condition **86.6400146/100**; crafted stonehatchet UID **65008**, condition **100/100**, amount 1. Reconciliation by shortname: rock 1→1; wood 0+200-200=0; stones 0+100-100=0; stonehatchet 0+1=1. Unspent wood/stones=0. All source fingerprints remain identical during every craft attempt, including successful conversion. No double output or unexplained credit.

Ready=267.6052 s, plugin marker=266.5905 s; start to final report approximately 358.55 s (file timestamp). Native graceful quit ACK/save/navmesh and observed native exit **-1** are preserved; no forced termination. RunnerElevated=false, elevated helper only for temporary per-executable block rules. Cache WARM, key `b37a93c03ae490a52662af2f167343eda017ce450d373f43abced8fb91b58b23`.

## Live 2 — independent persistence proof

Run **240c374bfd7345aeaeb4749e346f1e8b**, new server process, RESTORE, runner exit 0. Loaded exactly the CRAFT world/generation and snapshot/state hashes below, verified by the runner before startup. Live compiled/loaded the same plugin SHA as run 1 and current public source. Native Load restored **rock UID 58401 ×1, condition 86.6400146/100** and **stonehatchet UID 65008 ×1, condition 100/100**. Actor ID, goal, tool/product/intent, completed categories and rejected memory match exactly. CraftStatus=CRAFTED. There are **0 harvest receipts, 0 craft attempts and 0 starter-kit creations** in this process. Persistence.Saved=false means no new inventory snapshot was produced by the read-only restore; it does not mean restoration failed (Restored=true, Expected/Actual equal).

Ready=264.6999 s, plugin marker=263.6945 s, start to final report approximately 274.37 s. Shutdown GRACEFUL, observed native exit -1, completed native world/navmesh save and owned absence. RunnerElevated=false. Third launch was neither needed nor performed.

CRAFT save generation **world-37c0794e1a7446c9971be04295fb731e**, native .sav SHA-256 **DFEFDF0EB5D0E4CF474A29FB21927B476A92045EA35BEB2D9F11C8CD05E496C0**; inventory SHA-256 **28F55D42E13DDFF0E958A365F86DA40685C3CBBC855D17046CC3B83F8E159879**; actor-state SHA-256 **01805552216EB88A012D431B30E42673807F4636D85336975A44FC804FB86CA6**. Completed logical intent, goal CARRY_SAVE, product UID, rock UID, Completed=[WOOD,ORE] and Rejected=[6978,6975,5648] are bound to this exact world. A fresh Gen2 avatar on restore represents the saved logical actor; persistent native player/entity equivalence is not claimed.

## Safety, commands and cleanup

The existing runner made a physical test installation/cache with isolated Oxide writable state, synthetic identity/logs/secrets and loopback ports 28965–28968. Every test EXE was covered by verified inbound/outbound deny rules before owned CreateProcess in a kill-on-close Job Object. Each finally requested graceful quit, waited for exit and disposed only its owned job. SteamCMD, update/validate, owner BAT and loadMod were never run. Owner worlds, configs, identities, ports and third-party mods were not changed, copied as writable links, installed over or published.

Commands executed by Codex from repo root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-All.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-NavigationProbe.ps1 -SurvivalCraft -PreflightOnly
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-NavigationProbe.ps1 -SurvivalCraft -StartupTimeoutSeconds 900 -NavigationTimeoutSeconds 900
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-NavigationProbe.ps1 -SurvivalCraft -RestoreFrom 8f6f793e39fa471d8aa4e936fcd66033 -StartupTimeoutSeconds 900 -NavigationTimeoutSeconds 900
```

Preflight run `7d901415e04641279bf7f432247161b5` passed without Rust startup (its PARTIAL is the intentional preflight-only status). Two actual live source snapshots and earlier failed fixture results were retained, not overwritten. Both independent live audits passed. Final read-only cleanup at 15:04:49 UTC: owned=0, broker=0, Rust/SteamCMD=0, TCP=0, UDP=0, RustBots firewall rules=0, exclusive lock failures=0; both closed.json receipts Removed=true / RemainingProcesses=0. Owner audit at 15:04:56 UTC compared every Server file by length/SHA-256: **3086 files, 0 changes/additions/deletions**.

## Evidence locations

Raw evidence is ignored and local only: `.local/audit/craft005/` and `.local/runtime/<run-id>/`. Each live run retains full console/server log, plugin source snapshot/hash, plugin-result/result, native inventory/actor snapshots and world proof as applicable. Owner hashes and runtime RCON secrets remain private. Public figures refer only to the synthetic test map/actor, never owner settings.

## Offline verification and review

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-All.ps1` passed after code changes (`tests-final-code.txt`, exit 0). Includes legacy 001/003/004, safety/job/firewall/cache fixtures, crafting receipts and all three plugins compiled against installed DLLs using C# 7.3. Fixtures cover absent/incorrect recipe, actual missing quantities, blueprint/bench, partial/full stack UID debit, duplicate/debit replay, interrupted paid output, wrong multiplier, condition, selected recipe mismatch and restore replay/world binding.

A fresh read-only review found validator false-GREEN cases; RED→GREEN receipts and resolution are in `review.txt` / `review-red*.txt`. A newly crafted broken tool, missing selected recipe, nonexistent-only negative, empty intent and missing Crafting on a requested craft restore are rejected. Legitimate paid interruption is preserved as PARTIAL. No unresolved Critical/Important review finding remains in the implemented code; live evidence is still required separately.

## Public scope and delivery

Bounded exception: 18 exact public text paths for one gameplay slice: README; RustBotsSurvival; Invoke-NavigationProbe, SurvivalValidation, CraftValidation, Test-Craft, Test-All; 005 TASK/GATES/ACCEPTANCE/EVIDENCE/HANDOFF/RISKS/README/GOAL/PLAN/API_DECISION/RESULT. No other task family or safety helper changes. Full allowlist: `.local/audit/craft005/allowlist.txt`.

Git use is explicitly authorized by the user and TASK §5. Baseline commands: `git status --short`, `git branch --show-current`, `git rev-parse HEAD`, `git rev-parse origin/master`, `git ls-remote origin refs/heads/master`, `git -c credential.interactive=false ls-remote https://github.com/kpCat/RustOxideBots.git refs/heads/master`, `git check-ignore Server/rustds/RustDedicated.exe .local`, `git ls-files Server`, `git diff --check`, `git diff --stat`. No reset/rebase/force/clean, broad add or owner staging. Final exact commit/push SHA is stored after delivery in ignored `delivery.json` and the final response because a commit cannot contain its own SHA.

Delivery commands, authorized for this exact slice: `git status --short --untracked-files=all`; `git check-ignore -v Server/rustds/RustDedicated.exe Server/rustds/oxide/config .local/audit/craft005/owner-before.json`; `git ls-files -- Server/`; `git diff --cached --name-only`; `git diff --cached --check`; `git diff --cached --stat`; `git diff --cached --numstat`; `git diff --cached --no-ext-diff --`. `git add -n -- $craft005Paths` then `git add -- $craft005Paths`, where the variable is exactly the 18 paths in allowlist.txt, with an exact staged-path comparison before commit. Commit: `git commit -m 'feat: prove real recipe crafting and isolated restart persistence'`. Ordinary push and remote inspection use the existing temporary HTTPS analogue: `git -c credential.interactive=false -c url.https://github.com/.insteadOf=git@github.com: push origin master` and the same prefix with `ls-remote origin refs/heads/master`. Final `git rev-parse HEAD`, `git rev-parse origin/master`, `git branch --show-current`, `git status --short`. Origin configuration stays unchanged; Server ls-files is empty and Server/.local ignore guards pass.

- mojibake-маркеры в изменённых файлах проверены: все 18 публичных файлов, полная отдельная группа маркеров.
- escaped Cyrillic в изменённых файлах проверены: все 18 публичных файлов, отдельные Unicode/XML regex-паттерны.

Strict UTF-8/NUL/binary guard, owner-value/credential/Steam ID scan and both actual live RCON secret comparisons pass on the exact allowlist. Raw snapshots, owner hashes, passwords and private configs remain ignored. This GREEN establishes one bounded accounted gameplay slice, not native player equivalence or production crash-safe resource persistence.
