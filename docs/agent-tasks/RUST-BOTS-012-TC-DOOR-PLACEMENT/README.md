# RUST-BOTS-012 — TC, дверь и завершение первого дома

**Отдельная задача для нового диалога Codex, мышление HIGH.**

Цель: установить точную причину `Planner.DoBuild(...) == null` при размещении настоящего шкафа `BuildingPrivlidge` после шести успешно созданных строительных блоков; безопасно исправить её и, если diagnostic smoke доказан полностью, перейти к полноценному натуральному дому и независимому восстановлению.

**Стартовый baseline:** `610937733286263b83c2f70577ec629ecd482b3a` в `kpCat/RustOxideBots`, `master`. Локальный каталог `D:\Codex\repos\RustOxideBots`.

Прочесть в порядке: `AGENTS.md` → этот `HANDOFF.md` → `TASK.md` → `API_GATE.md` → `GATES.md` → `ACCEPTANCE.md` → `EXECUTION_PLAN.md` → `EVIDENCE.md` → `RISKS.md`. Затем 010/011 RESULT/API и реальные src/home/FirstHome.cs + RustBotsAvatarSurvival.cs + runners/validators.

Ни одного пользовательского PowerShell или ручного Rust server запуска. Codex самостоятельно выполняет offline gate, headless E2E, shutdown, checks, commit и обычный fast-forward push. История PARTIAL 010–011 сохраняется.

Важное правило: **пока TC+дверь+upkeep+физический HOME_NAV не доказаны в diagnostic smoke, запускать долгую добычу 3760 wood ЗАПРЕЩЕНО.**
