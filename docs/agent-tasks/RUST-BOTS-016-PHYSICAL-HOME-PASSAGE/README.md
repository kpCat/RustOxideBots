# RUST-BOTS-016 — Physical Home Passage & Build Completion

**Одна самостоятельная задача, один новый диалог Codex, размышление HIGH.**

Ключевая развилка: после 014 обнаружен реальный контакт капсулы с поднятым порогом. 015 честно остановилась на OFFLINE G1, без единого нового live запуска: центрирование само по себе не устраняет вертикальный контакт, штатный full-body step solver не найден. **Не повторять тот же OFFLINE HOLD.** В изолированном диагностическом мире безопасно выяснить, что делает реальный RustNav при контакте, не выдавая проникновение сквозь MeshCollider за физически корректную ходьбу. Если контакт ненормальный, исследовать **нативную** проходимую архитектуру входа/опоры или иной обоснованный native locomotion path.

Главная поставка: реальный проход `OUTSIDE → INSIDE_TC → OUTSIDE → CLOSE DOOR` с оплаченной native базой; затем, при полном успешном первом smoke, оплаченный NATURAL JOURNEY и отдельный HOME RESTORE.

- Репозиторий: `D:\Codex\repos\RustOxideBots`, ветка `master`.
- GitHub: `https://github.com/kpCat/RustOxideBots`.
- **Baseline:** `673810c885520524471c179ece79b6bd932b34a5`. Перед началом проверить local HEAD, tracking, actual public master, статус дерева.
- Owner `Server/` read-only/ignored, никаких обновлений Rust/Oxide или owner BAT.
- Источники: TASK.md, DESIGN_OPTIONS.md, PHYSICS_GATE.md, HANDOFF.md, ACCEPTANCE.md, EVIDENCE.md, EXECUTION_PLAN.md, RISKS.md, AGENTS.md.
- Запуски: цель 1 smoke + 1 natural + 1 restore; **максимум 3 настоящих RustDedicated процесса**, не тратить оставшийся один на одиночный NATURAL, если нужен второй smoke.

Новый result: `DIAGNOSTIC_HOME_GREEN`, `PARTIAL/PASSAGE_UNSAFE`, `PARTIAL/ENGINE_BLOCKED`, `PARTIAL/NATURAL`, `GREEN_HOME_BOOTSTRAP` или честный `BLOCKED` с несмешанными доказательствами.
