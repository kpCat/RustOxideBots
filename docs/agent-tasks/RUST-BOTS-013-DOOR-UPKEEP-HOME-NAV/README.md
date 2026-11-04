# RUST-BOTS-013 — Door, Upkeep & Home Navigation Gate

**Новая отдельная задача / новый диалог Codex / уровень мышления High.**

Репозиторий: `D:\Codex\repos\RustOxideBots`, GitHub `kpCat/RustOxideBots`, branch `master`.
Исходный подтверждённый SHA: `237fb6f18e513a2197d5a919e1fb38ab83ea6358`.

**Цель:** довести существующий физический BUILD_SMOKE до настоящей двери, native upkeep и прохода `OUTSIDE → DOOR → INSIDE_TC → OUTSIDE`, устранив конкретный blocker `HomeBuildStand → NavSample=false`. Все шесть деревянных блоков и TC уже подтверждены задачей 012, не переписывать работающий код без причины.

Только после успешного полного smoke возможно полноценное NATURAL JOURNEY + independent RESTORE в оставшемся бюджете. Диагностический smoke никогда не считается `GREEN_HOME_BOOTSTRAP`.

Порядок чтения: `AGENTS.md`, `HANDOFF.md`, `TASK.md`, `API_GATE.md`, `ACCEPTANCE.md`, `EVIDENCE.md`, `EXECUTION_PLAN.md`, `RISKS.md`, `GOAL.txt`. Затем исходники/отчёты 009–012.
