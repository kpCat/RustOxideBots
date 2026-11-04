# RUST-BOTS-011 — First Home: ранний live build gate и завершение полного цикла

**Отдельный НОВЫЙ диалог Codex. Уровень мышления: High.**

Репозиторий: `D:\Codex\repos\RustOxideBots`, ветка `master`, `https://github.com/kpCat/RustOxideBots`.
Проверенный GitHub baseline: `19ab338c518defa5508fbe8a70448ae773c2b0ec`. Перепроверь HEAD, remote master и local status перед изменениями. Никакого reset/rebase/force.

010 завершён PARTIAL: четыре игровых запуска, реального placement=0. На четвёртом найден безопасный site и оплачено/добыто 3763 wood при полном бюджете 3760, но оставшиеся ~110 с не покрывали путь к площадке и строительные этапы. Значит, **нельзя снова сначала 15 минут фармить, а потом впервые проверять Planner**.

**Новая последовательность:** (A) API/offline review и короткий диагностический native build smoke на отдельном тестовом клоне с явными fixture-материалами, (B) полноценный NATURAL-JOURNEY с честными ресурсами и реальным домом, (C) независимый RESTORE того же дома/собственности и инвентаря. Smoke НЕ даёт права на общий GREEN и НЕ переносит своё имущество в (B)/(C).

Прочти `TASK.md`, `GATES.md`, `ACCEPTANCE.md`, `EVIDENCE.md`, `HANDOFF.md`, `RISKS.md`, `EXECUTION_PLAN.md`, затем `AGENTS.md` и реальные исходники. Стартовая инструкция — `GOAL.txt`.
