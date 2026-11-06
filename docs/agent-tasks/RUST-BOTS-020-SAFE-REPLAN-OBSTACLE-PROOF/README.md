# RUST-BOTS-020 — Safe Moving Replan, Native Obstacle Proof & Report Fidelity

**Новая самостоятельная задача Codex (High).** ZIP распаковать в корень `D:\Codex\repos\RustOxideBots`, все файлы появятся в `docs/agent-tasks/RUST-BOTS-020-SAFE-REPLAN-OBSTACLE-PROOF/`. Текст `/goal` также находится в `GOAL.txt`.

Публичная база на момент подготовки: `kpCat/RustOxideBots` `master` **936c0a4ff03e2c9928ae89f3a9b636db63af8269**. До любых изменений сравнить local HEAD, origin/master и публичный master; при расхождении без reset/rebase/force, разбираться в истории безопасно.

## Приоритет

019: 649/649 *native MovePosition witnessed*, 34.1714m, real native registered **paid Wood foundation**. Не выполнены стены, Door, обход, дом. Обнаружена конкретная гонка контракта: `Obstacle(...)` разрешил REPATH сразу после свидетеля с `lastVelocity != 0`, но без выдачи следующей команды; следующий FixedUpdate остановился `CLOCK_UNOBSERVED_ACTIVE_HOLD`. Это не подтверждённая потеря коллизий. Требуется осмысленная **continuous-motion / measured braking** recovery, но без физически невозможного торможения.

Второй независимый P2: `scripts/Invoke-NavigationProbe.ps1` `Save-Report` делает `ConvertTo-Json -Depth 8` и портит внутренние триплеты `Navigation.RoutePlan[].NativeCorners[]` в **вторичном** result.json, хотя сырой `plugin-result.json` валиден. Починить и проверить offline без перезапуска Rust.

Цель020: после исправления motor recovery native fixture действительно доходит до стен и закрытой двери и проверяет реальные `PROBE_REFUSED`, наружный обход; если физика и бюджет позволяют — дойти до G5 (TC/upkeep, open/in/out/close). Один полноценный игровой сеанс предпочтительнее трех одинаковых остановок на подходе. Честный partial допустим. **GREEN_TRAVERSAL_CORE** только при полном G4/G5 + реально доказанном дискретном переходе; SLOPE из 018/019 его не подменяет.

Читать `AGENTS.md`, затем `HANDOFF.md`, `REPLAN_DESIGN.md`, `NATIVE_FIXTURE.md`, `P2_REPORT.md`, `API_GATE.md`, `GATES.md`, `TASK.md`, `ACCEPTANCE.md`, `EVIDENCE.md`, `EXECUTION_PLAN.md`, `RISKS.md`. Runtime и тесты — только исходный ScientistNPC : BasePlayer и согласованный вариант C. Не переключать его по умолчанию. Значимые изменения архитектуры — обсуждать с владельцем, рутинные исправления не спрашивать.
