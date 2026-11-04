# RUST-BOTS-008 — HeldEntity Restore Lifecycle

**Отдельная новая задача Codex**, High. Не продолжать старый диалог 007.

Распаковать ZIP в корень `D:\Codex\repos\RustOxideBots\`, сохранив структуру: файлы попадут в `docs/agent-tasks/RUST-BOTS-008-HELD-RESTORE-LIFECYCLE/`.

Читать в порядке: `TASK.md`, `API_GATE.md`, `ACCEPTANCE.md`, `EVIDENCE.md`, `HANDOFF.md`, `RISKS.md`, `AGENTS.md`; затем опубликованные результаты 006/007 и исходники. Текст `/goal` — в `GOAL.txt`.

**Цель:** устранить только установленный в 007 блокер восстановления PlayerInventory/активного изготовленного инструмента. Не объединять работу с persist world depletion, кланами, строительством, новой очередью крафта или обновлением Oxide.

**Git:** публичный `kpCat/RustOxideBots`, `master`, исходный HEAD `811220edbcbed8ffcaca804306e66cf6f40d1de6`. Сверить актуальное состояние до редактирования. `Server/` навсегда ignored и не публикуется. Codex сам запускает и закрывает тестовый RustDedicated. Максимум два live запуска, третий — только для конкретного доказанного дефекта. Честный `GREEN_RESTORE` / `PARTIAL` / `BLOCKED` / `FAILED` и обычный fast-forward push в `master`.
