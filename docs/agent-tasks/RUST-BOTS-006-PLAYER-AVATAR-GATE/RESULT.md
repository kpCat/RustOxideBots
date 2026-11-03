# RUST-BOTS-006 — RESULT, 03.11.2026

**Live avatar gate: GREEN in the bounded 006 scope.** One real `ScientistNPC : BasePlayer` without connection physically traveled **93.69549 m** on RustNav, using its own native PlayerInventory and native active rock/HeldEntity throughout. Three transitions completed, including movement after native path consumption reset speed to zero. Real missing/foreign UID guards passed. Both own servers stopped GRACEFUL. First run remains **PARTIAL**, never promoted or overwritten.

| Gate | Final evidence |
|---|---|
| AVATAR | LIVE: one ScientistNPC, native engine bot identity, no connection or Steam impersonation |
| NAV | LIVE: 3 complete planned/issued paths, actual 93.69549 m, each net >30 m, continuous physical samples; raw consumed arrival state preserved |
| PLAYER_INVENTORY | LIVE: same actor's PlayerInventory/main/belt/wear; exact default rows plus one native TEST_FIXTURE rock |
| HELD_ITEM | LIVE: same native fixture/active UID, actual BaseMelee held entity, native parent/owner equal actor during all samples |
| NEGATIVE | LIVE: missing and actual foreign UID resolved through native belt lookup and refused by owner guard without native activation or inventory changes |
| PERSISTENCE | NOT_VERIFIED: second process is a fresh regression run, not restore |
| SAFETY | LIVE: 3086 owner files unchanged; native ACK/save, own processes/ports/firewall/open leases/locks cleared |
| CODE | OFFLINE suite and installed C#7.3 compile; independent source/receipt review; actual live Oxide compilation/load |
| GIT | Exact-path delivery; final commit/local/remote SHA and clean-tree verification recorded after commit in delivery receipt and delivery response |

## Baseline and scope

Local master HEAD, cached origin/master and actual GitHub master matched `ce25f3482468a2be48a4896275657dc59b28e9e5` before work. Only the supplied eight 006 documents were initially untracked. SSH authentication was unavailable; temporary HTTPS URL mapping confirmed remote without changing origin configuration.

Read-first covered root AGENTS/README, supplied 006 task package, 001/003/004/005 results and 004/005 API decisions, three existing plugins, runner/cache/job/firewall/safety and validators/tests. No ancestor AGENTS, public csproj/props/targets, code-map or pattern files were found. Existing patterns were reused. Bounded exception: 18 public paths for this one gate, listed in PLAN; all historical plugins are protected unchanged.

## STATIC / OFFLINE

Installed metadata, IL and serialized prefab discovery are documented in [API_DECISION.md](API_DECISION.md). Candidate is ScientistNPC_Roam, concrete `ScientistNPC : HumanNPC : NPCPlayer : BasePlayer`, with native PlayerInventory and RustNavMeshAgent. Probe never assigns a user/Steam ID, connection, forced held owner or manually spawned held prop. No Harmony or new runtime dependency.

Full `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-All.ps1` passed before each live start, including existing 001/003/004/005 tests and installed C# 7.3 compilation of all four plugins. Focused offline fixtures independently reject wrong actor/UID/owner/container, absent held entity, duplicate fixture, inventory changes, fake missing/foreign activation, zero travel, warp, broken sample/leg chain, nonfinite numbers and false graceful shutdown. Native path-consumption fixtures keep raw PathInvalid distinct from planned complete paths. Fixtures establish validator behavior only.

Independent source review found and closed zone sleep/wake reactivation, ACK/save shutdown proof, missing-UID null-reference coverage and native desired-speed reset defects before the final live source. RED→GREEN receipts and review files remain in ignored `.local/audit/avatar006/`.

## First live — preserved PARTIAL

Run `ada3c026240f4f84acf5d3516c2d3c2d`, plugin 0.1.0, snapshot SHA-256 `8309819E64BEC917250CD439DA2DB08FEC769EFA4AB78839E7DDF32B29FBE28C`. Actual Oxide compilation/load succeeded. Ready=270.6257513 s, plugin=269.6161571 s, runner unelevated.

Actor net ID 69579, `ScientistNPC`, exact installed Roam prefab, engine-assigned bot ID 125, IsNpc=true, no connection, not sleeping; ScientistBrain, no FSM, native RustNav agent. Real PlayerInventory main/belt/wear container UIDs 69580/69581/69582, all native owner=actor. Three default rows (rifle.lr300, medical syringe, scientist suit) preserved; one declared TEST_FIXTURE rock UID 69627 added to native belt. Active UID=69627; held net ID 69628, actual BaseMelee `assets/prefabs/weapons/rock/rock.entity.prefab`, parent and owner=69579, native held flag set, limitNetworking=false. This is server equipment evidence, not client animation evidence.

| Leg | Actual / net, m | Observed arrival | Stuck / repath |
|---|---:|---|---|
| 1 | 30.9718361 /30.9440746 | ARRIVED, raw PathComplete | 0 /0 |
| 2 | 31.4690571 /31.1679726 | ARRIVED, raw PathInvalid, no path, remaining zero, about 0.990 m from target | 0 /0 |
| 3 | 0.0436041 /0.0436041 | FAILED after 20.4993 s, accepted complete path but no progress | 2 /1 |

84 physical samples independently reconstruct **62.48450269 m**, including the failed leg. Native inventory/held ownership remained valid. The missing case in this source is only NULL_ITEM_GUARD: its reported UID did not participate in lookup. Final validator correctly refuses this old receipt. It is not a final NEGATIVE or NAV GREEN.

Targeted native IL explains both endpoint and stall: arrival can ResetPath, returning PathInvalid/no-path/remaining zero; ResetPath also sets desiredSpeed=0, and SetDestination does not restore speed. Version 0.1.1 explicitly restores requested speed after every destination/repath and records speed/path states. It uses actual ItemId lookup for positive/missing/foreign requests. Second run retains three legs to exercise the corrected lifecycle, not merely a shorter success route.

First shutdown: GRACEFUL, native exit -1, actual plugin ACK plus native world/navmesh save; cache promoted. Owned absence, released ports and removed firewall lease confirmed. External audit after exit: Rust/Steam/helper/TCP/UDP/rules/open leases/occupied locks all zero. Full owner length/SHA comparison: **3086 files, 0 changes**.

## Second live — final same-actor proof

Run **1f413b585dde4380ac361dc3c965c9af**, runner exit **0**, plugin **0.1.1**, source snapshot SHA-256 **6D38201AD720E7CBB41B1FFE00C6F05F7DC3F6F324737DF57326DB4E48D689B8**. Source/snapshot/hash match; server.log proves actual Oxide compiled/loaded. Rust protocol **2635.289.1**, build date `10/22/2026 19:30:56`, installed Oxide.Rust **2.0.7839**. Ready=267.0322961 s, plugin=266.0223717 s, RunnerElevated=false. Warm physical cache key b37a93c03ae490a52662af2f167343eda017ce450d373f43abced8fb91b58b23; no download/update.

One actor net ID **73508**, concrete ScientistNPC, same manifest Roam prefab, engine-generated bot ID **112**, IsNpc=true, HasConnection=false, sleeping=false, LegacyNavigation=false. ScientistBrain stopped after native initialization; only this actor removed from zone sleep and competing TickMovement. Direct native RustNav agent performs path following; no plugin post-spawn coordinate writes, teleport, MovePosition or Warp.

Native PlayerInventory main/belt/wear UIDs **73509/73510/73511**, all playerOwner=73508. Default smg.mp5 UID 73512 ×1 condition 150, syringe.medical UID 73515 ×2 and hazmatsuit_scientist UID 73517 ×1 preserved exactly. Exactly one **TEST_FIXTURE** rock UID **73556**, amount 1, condition 100/100, added to the existing belt without stacking. Before=3 UID/4 units, after=4 UID/5 units. No claimed harvest, craft or transfer from 005.

`GetActiveItem().uid=73556`; native `GetHeldEntity()` net ID **73557**, type **BaseMelee**, actual `assets/prefabs/weapons/rock/rock.entity.prefab`. Item owner, held owner and held parent all equal 73508. Native held flag 1024/Reserved4 set, limitNetworking=false. Same active/held UID and owner across **all 64 samples**, then rechecked at completion. No manual held entity creation, parent or forced-owner assignment. Flags are server evidence only.

| Leg | Actual / net, m | Elapsed, s | Planned / issued path | Raw arrival | Speed before → issued |
|---|---:|---:|---|---|---|
| 1 | 30.9702644 /30.9430313 | 10.4818115 | Complete /Complete | PathComplete, hasPath=true, remaining1.05919945 | 3 →3 |
| 2 | 31.4639530 /31.1632786 | 10.5002136 | Complete /Complete | PathInvalid, hasPath=false, remaining0, reached native endpoint | 3 →3 |
| 3 | 31.2612724 /31.0476284 | 10.4956360 | Complete /Complete | PathInvalid, hasPath=false, remaining0, reached native endpoint | **0 →3** |

Every intermediate moving sample remains PathComplete/hasPath=true. Planned path lengths **32.000164/32.3070145/32.03599 m**. Terminal consumed paths are accepted only at <=1.05 m from target (observed leg2 **0.994706 m**, leg3 **0.993931 m**), with zero stuck/repath; raw PathInvalid is never rewritten. All three legs have stuck=0/repath=0. Third leg's native speed_before=0 followed by issued3 and31.2612724 m of movement is the live regression for the first stall.

Independent reconstruction from 64 samples: **93.6954901486 m**, max step **1.67490761 m**, max interval **0.504822 s**, max observed speed **3.49999292 m/s**. Plugin total agrees within float tolerance. Leg starts/ends/times, target arrivals, total and active/held continuity are independently reconciled. Coordinates are dynamically selected from synthetic seed 424242/size 2000 terrain, not the owner world.

MISSING request UID 18446744073709551615 is absent from actual ItemManager.GetAllItems; native belt.FindItemByUID returns null. FOREIGN request UID 2337 actually belongs to native world container 2336; same native belt lookup returns null. Both requests enter the same TryActivate(ItemId) path as the valid fixture, are refused before UpdateActiveItem, retain active 73556 and have exact actor inventory before=after. Foreign native tarp row before=after; no second fixture or actor is created. This proves an explicit server guard, **not engine rejection of arbitrary UpdateActiveItem calls**.

Shutdown GRACEFUL, actual native exit **-1**, plugin ACK, completed native world/navmesh save, AvatarCompletedSave=true, Cache.Promoted=true. Final independent audit at **15:56:21 UTC**: Rust/Steam/helper=0, test TCP/UDP=0, RustBots rules=0, open leases/live brokers/occupied locks=0. All11 historical leases are closed; both new ones removed. Full owner SHA/length inventory after both runs: **3086 files, 0 changes**. No third server was started.

Commands executed from repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-All.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-NavigationProbe.ps1 -PlayerAvatar -PreflightOnly
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-NavigationProbe.ps1 -PlayerAvatar -StartupTimeoutSeconds 900 -NavigationTimeoutSeconds 900
```

The last command ran twice with distinct ignored run directories. Final independent audit uses `.local/audit/avatar006/Audit-Live.ps1 -RunId 1f413b585dde4380ac361dc3c965c9af`. Full logs, both source snapshots and immutable plugin-result/result files stay local; final review and encoding/secret/scope receipts are separate artifacts.

## Limits and architecture

No client was used. External appearance, animations, multiplayer session, combat/native weapon use, native crafting queue, production economy and scale remain NOT_VERIFIED. Rock is a fixture, never the earned stonehatchet UID from 005. PERSISTENCE is NOT_VERIFIED: both live starts are independent fresh probe actors, not inventory restoration or continuous native entity identity.

Owner Server, worlds, configurations, plugins, launchers and installed Rust/Oxide remain read-only. No update, SteamCMD, owner server, client login, teleport or synthetic GREEN. Raw logs, source snapshots, secrets, owner hashes and telemetry stay ignored. No production Gen2 migration or dual-avatar bridge is implemented; the architectural decision is in DECISION.md.

## Delivery record

Exact allowlist has the eight supplied 006 files, four new 006 reports/plan, new avatar plugin/validator/test and three runner/compile/suite integration files. No Server, private data or other task family is publishable. Final Test-All receipt is `.local/audit/avatar006/tests-final.txt`; all three historical plugin length/SHA fingerprints remain unchanged. Strict UTF-8/NUL, owner-value/credential/Steam ID/non-loopback IP and both actual RCON secret comparisons cover exactly18 public files.

- mojibake-маркеры в изменённых файлах проверены: полная отдельная группа маркеров, все18 публичных файлов.
- escaped Cyrillic в изменённых файлах проверены: отдельные Unicode/XML regex-паттерны, все18 публичных файлов.

Git is explicitly authorized by the user and TASK. Used for baseline: `git branch --show-current`, `git rev-parse HEAD origin/master`, `git status --short`, `git ls-files Server`, `git ls-remote origin refs/heads/master`; HTTPS retry uses `git -c credential.interactive=false -c url.https://github.com/.insteadOf=git@github.com: ls-remote origin refs/heads/master`. Review used `git diff --check`, `git diff --stat`, and `git diff -- scripts/Invoke-NavigationProbe.ps1 scripts/Test-All.ps1 scripts/Test-PluginCompile.ps1`. Exact-path delivery checks/add/commit and ordinary push are the final step. No force/reset/rebase/clean/stash or broad add.

The final commit cannot contain its own SHA. Final local/remote SHA and clean-tree receipt belong to ignored delivery.json and the self-contained delivery response after push.

Delivery command inventory (authorized exact scope): `git status --short --untracked-files=all`, `git check-ignore -v Server/rustds/RustDedicated.exe Server/rustds/oxide/config .local/audit/avatar006/owner-before.json`, `git ls-files -- Server/`, `git diff --name-only`, `git diff --cached --name-only`, `git diff --cached --check`, `git diff --cached --stat`, `git diff --cached --numstat`, `git diff --cached --no-ext-diff --`. Exact-path staging uses `git add -n -- $avatar006Paths` then `git add -- $avatar006Paths`, where that variable contains only the 18 paths in the verified allowlist. Staged names must equal that allowlist before commit. Commit command: `git commit -m 'feat: verify player-derived RustNav avatar and native equipment'`. Ordinary publication: `git -c credential.interactive=false -c url.https://github.com/.insteadOf=git@github.com: push origin master`; remote inspection uses the same prefix with `ls-remote origin refs/heads/master`. Final `git rev-parse HEAD origin/master`, `git branch --show-current` and `git status --short` confirm delivery. No origin configuration change or history rewrite.
