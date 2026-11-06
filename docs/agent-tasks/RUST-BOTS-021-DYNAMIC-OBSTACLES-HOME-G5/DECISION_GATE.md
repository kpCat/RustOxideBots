# Owner discussion gate

The owner explicitly requested discussion when a **substantial** design or behavior choice arises. This is a product policy, not merely C# implementation style.

Already selected: architecture C original ScientistNPC/BasePlayer, RustNav as route planner, checked local MovePosition with full original body, no teleport/collision masking, shared navigation. This task assumes a temporary **non-combat** dynamic obstacle behavior: investigate movement, wait/avoid/retreat along measured safe route or stop. It does not decide whether bots attack wolves, players, Bradley, PvP or hunt.

**Ask user BEFORE** replacing mover/actuator/physics material, changing native body/capsule/layer/owner or building requirements, forcing crowd behavior / de-spawning animals, implementing AI combat/killing wolves, irreversible multi-map/ownership schema changes, or enabling C by default for all bots. Present 2–3 substantive options, gameplay impact, performance, safety, recommendation, then owner choice. Don't ask about ordinary validation fixes, report serialization, seed-independent native site probing or extra reviewed headless starts.

No promise of `GREEN_TRAVERSAL_CORE` without real G5, and even then bench-only until separate explicit owner product adoption. Owner has lifted numerical launch budget and values honest physical evidence, not arbitrary counts or future asynchronous work.
