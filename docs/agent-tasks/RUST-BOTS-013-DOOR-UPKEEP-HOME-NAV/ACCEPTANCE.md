# ACCEPTANCE — исходы 013

| Gate | Что подтверждается |
|---|---|
| Baseline | local HEAD = confirmed public master `237fb6f...` at start; owner clean, no foreign code overwritten |
| Nav diagnosis | exact subcheck from `HomeBuildStand → NavSample → Ground`; raw before/after positions, collider/nav/tiles/path and real first failure |
| Six native blocks | actual `Planner.DoBuild`/paid Wood upgrade, correct connected building group, saving/support |
| Native TC | actual paid `BuildingPrivlidge`, owner/authorization/`IsAuthed`/`TC.CanBuild`; no foreign auth, repeated TC no |
| Native Door | actual paid `Door` from intended doorway socket, native registration, owner and paid Item UID; not fixture spawn |
| Upkeep | native TC inventory receives original paid Item UIDs, rate/period, protection >=60 minutes, decay on, source/dest conserved |
| HOME_NAV | same physical NPC path from outside through open door to accessible own TC then outside, actual collider/aperture and path/ground samples; no warp/teleport, verified open/close |
| Isolation | smoke fixture explicitly marked, no historical cache promotion; smoke never eligible for production RESTORE |
| NATURAL (conditional) | separate clean run, NATURAL source debit+tool wear, exact material/craft/build/TC payments, no diagnostic credits, completed save |
| RESTORE (conditional) | distinct server restores same world/home/item identity, live witnesses and TC protection, no build/harvest/craft replay |
| Delivery | offline Test-All+compiler, native Oxide load for live, safety/cleanup/owner hashes, encoded text and secrets scans, exact-path Git/push |

**`DIAGNOSTIC_HOME_GREEN`**: complete smoke — six blocks + TC + door + upkeep + crossing — but TEST_FIXTURE means this is **NOT** `GREEN_HOME_BOOTSTRAP`. Status should be `PARTIAL/DIAGNOSTIC_BUILD_ONLY` at task level unless real NATURAL + independent RESTORE also completed.

**`GREEN_HOME_BOOTSTRAP`**: complete diagnostic gate, separate fully paid NATURAL live + independent RESTORE, all checks and cleanup. Do not conflate smoke and natural.

**PARTIAL/BLOCKED:** honest stage-specific cause, source + live evidence; optional remaining runs not executed when gates fail. **FAILED:** duplicated or free production materials/builds, foreign mutation, owner data changed, orphan processes/firewall, fabricated records/claims.
