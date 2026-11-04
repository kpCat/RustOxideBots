# Приёмка — живые доказательства, не просто поля JSON

| Feature | Требования |
|---|---|
| NATIVE_BODY | Один реальный NPC/native `CapsuleCollider` r=0.5/h=1.8, real owner/network identity, no transform writes/collider manipulation |
| STEP_ROUTE | Derive inside/outside targets from actual native door portal and foundation. Measured path lateral margin supports real capsule; real Nav.CalculatePath Complete, pending false, no fake nav statuses |
| CONTACT | Full native overlap set and penetration/resolution/time; distinguish support step from obstruction. No unverified permissive ignore, no path through blocking wall/door/TC/foreign. `CROSSING_CANDIDATE` != accepted crossing |
| ACTOR_MOVEMENT | Continuous actual position/velocity/ground and native agent motion across doorway, no warp/discontinuity; no sustained unhandled penetration or stuck |
| STRUCTURE | Six native Wood blocks, one TC and one native Door, same owner/group, actual Planner payment/support/save registration |
| AUTH/UPKEEP | Own-only TC auth/CanBuild, original paid Wood Item UID transferred, native rate/period, GetProtectedMinutes(true) >= 60, decay enabled |
| DOOR_NAV | Native open+hinge movement; ACTUAL `CROSSED_IN`, `TC_REACHED` with LOS/range, `CROSSED_OUT`, Door.Close after exit and true state change |
| SMOKE_ISOLATION | Diagnostic TEST_FIXTURE labelled, no external reward, no trusted cache promotion or natural snapshot |
| NATURAL | Separate fully natural wood/stones/resource pool debit + wear/paid craft/build/upkeep, home checkpoint, no free fixture |
| RESTORE | New process, same WorldKey/wipe/saved house8 entities and original items/identity/TC upkeep, no rebuild/harvest/craft/kit/upkeep credit replay, home-nav |
| CLEANUP/GIT | Native compile/load and Test-All, owner unchanged; own jobs/ports/firewall/locks absent; scans, allowlisted commit/push |

**Outcomes:** `PARTIAL / NATIVE_THRESHOLD_BLOCKED` if safe crossing cannot be proven; `PARTIAL / DIAGNOSTIC_HOME_GREEN` if full smoke only; `PARTIAL / NATURAL_HOME_COMPLETE` if natural paid home but no valid restore; **`GREEN_HOME_BOOTSTRAP`** only when smoke + paid natural + independent restart complete. Controlled crash-atomic, all-map gameplay, 50–100 NPC not proven by these gates.

Reject fake GREEN if: contact info missing, wrong body or portal margin, negative wall example accepted with same depth/direction, physic blocked but `CROSSED_IN` emitted, source fixture used for NATURAL, or paid unit replay/mismatched WorldKey.
