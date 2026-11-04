# GATES — этапы и условия перехода

| Gate | Проход / следующий шаг | Отказ |
|---|---|---|
| G0 Repo & privacy | HEAD/master, статус, AGENTS, Server ignored/read-only, 010 report/source read | STOP; чужие процессы не убивать |
| G1 API preflight | native placement/owner/grade/TC/upkeep/door API реально существует; C#7.3 compile; well-formed target/socket/cost; correct time budget | BLOCKED_STATIC, никаких live |
| G2 Native builder smoke | **реальные** 8 native home entities либо конкретный native API blocker; fixture строго test-only, чужая экономика/мир не затронуты | Если нет native build, НЕ запускать полный farm; PARTIAL или исправить offline без дополнительных live |
| G3 Natural full journey | один player-derived actor, stable site+route, NATURAL resource debit, оплаченные native Item, actual native structural build, TC auth/upkeep, home physical traversal and clean save | PARTIAL, сохранить результаты, никакого fake home restore |
| G4 Independent restore | exact clean output G3; old entities rebuilt nowhere, rebind authorized, no replay, home/nav/door passed | PARTIAL, сохранить old world proof, 0 foreign mutations |
| G5 Delivery | Test-All/live-source hash, full owner audit, cleanup, Git narrow commit/push SHA, reports/scans | Не публиковать fake GREEN |

**TIME_BUDGET ≠ SITE_GEOMETRY.** Перечислять раздельно: missing site, actual path invalid, planner rejected, lack of native permission, cost mismatch, insufficient remaining schedule. Отказ по времени после собранных материалов — НЕ «site changed».

Любой production `GREEN_HOME_BOOTSTRAP` требует полноценный NATIVE-resource JOURNEY + actual native structures + home navigation + independent RESTORE. `BUILD_SMOKE_GREEN` является только доказательством API, никак не доказательством натурального выживания и сохранения.
