# RUST-BOTS-019 — Native Obstacle Fixture, Refusal, Detour & Home Passage

**Отдельный новый диалог Codex, уровень HIGH.** Архив распаковать в корень `D:\Codex\repos\RustOxideBots`.

**Baseline:** public `kpCat/RustOxideBots` `master` commit `628cc8fa1d4e7d874665025dcb42d411d350623e`; before doing anything recheck local HEAD, tracking and public master + clean tree. Owner server `Server/` read-only. Root `AGENTS.md` applies.

**Решение владельца уже принято:** общий collision-aware controller C, original `ScientistNPC : BasePlayer` and original full capsule/real inventory; RustNav global planner; only one checked `Rigidbody.MovePosition` writer. Another architectural controller or global navigation replacement requires owner's discussion/choice, not unilateral change. No artificial movement/teleport/collider edits.

**Зачем 019:** 018 proved real FLOOR_ACQUIRED/rest and outdoor slope ascent+descent, 11.806m, 237/237 safe witnesses, but had NO eligible *existing* closed door within 48m and bounded route. Avoid another site-search-only PARTIAL: build an **authentic, native, test-only, paid** wall/door/house in an isolated physical test world as reproducible obstacle. No spawned fake props, no test-only collision disable. Test negative refusal, safe finite-wall detour and actual doorway IN/OUT.

Read all docs here in order: `HANDOFF.md`, `TASK.md`, `FIXTURE_DESIGN.md`, `GATES.md`, `ACCEPTANCE.md`, `API_GATE.md`, `EVIDENCE.md`, `EXECUTION_PLAN.md`, `RISKS.md`; `GOAL.txt` is the paste instruction. Codex should produce `PLAN.md`, `API_DECISION.md`, `RESULT.md`. Up to3 real isolated RustDedicated launches in this *new* task, not a continuation of budget018; each game start must be useful; no fourth without a separate task.
