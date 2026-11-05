# GATES — phase gates with honest statuses

**G0 BASELINE:** HEAD/current public `master`, root AGENTS and old results; owner read-only SHA baseline; original Rust/Oxide loaded DLLs.

**G1 NATIVE/CODE DESIGN:** document native locomotion options, scope, exact supported collision/ground APIs. If fundamental architectural choice arises, ask OWNER via DECISION_GATE; owner already chose UNIVERSAL (do not ask that question again). Offline RED→GREEN safety contracts and installed C#7.3 compile.

**G2 GENERAL CORE:** one reusable movement layer callable by both outdoor and home; no home-prefab-only fixes, no direct position writes to bypass collision, support+climb/descend+repath/blocked typed, reuse native actor, bounded step/stuck. Source-level negative tests before expensive live.

**G3 LIVE_BENCH1:** one physical owned RustDedicated on isolated world; scenes (a) natural terrain/slope/step, (b) native paid diagnostic base threshold, (c) wall/door negative. Each has real native continuous measurements. No fixture report counted as natural economy. If any irrecoverable fail, terminate with evidence.

**G4 OPTIONAL LIVE_BENCH2 / REGRESSION:** only a different supported obstacle or diagnosed change justified by new raw. Entire task <=3 live starts; don't spend them repeatedly on same isolated lip. No user's manual BAT scripts. No unsafe bypass.

**G5 SAFETY & DELIVERY:** independent review, Test-All, real native compile/load if live, own process cleanup/owner SHA, no secrets, exact-path commit and normal push. If code isn't proven across multiple classes, status PARTIAL. No fabricated or duplicate prior proofs.

Success categories:
- `GREEN_TRAVERSAL_CORE` = real supported up/down/height delta + safe movement in **at least two distinct physical contexts** (outdoor and real native build) + real obstacle blocked/detour + no clip + integrated shared runtime + all negative/safety tests, no hardcoded XYZ.
- `PARTIAL_TRAVERSAL` = code/probes or one context passed but universal physical proof incomplete.
- `ARCHITECTURE_DECISION_REQUIRED` = no safe native mover and significant implementation fork requires owner choice; document alternatives, don't silently switch actor/physics.
- `BLOCKED_ENGINE` = grounded installed API limitation prevents safe test, without false GREEN.
- `FAILED` = forced/clipped passage accepted, free items in natural run, owner/foreign world modified, secret exposed, or residual server.
