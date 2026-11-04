# 011 — план исполнения

Spec: TASK.md и EXECUTION_PLAN.md в этой папке. Исполнение автономное, в указанном владельцем master; без новой ветки/worktree. Предыдущие 010 source/evidence read-only.

Прочитаны корневые AGENTS/README, все обязательные документы 011, FirstHome, actor/economy, runner/cache/validators/tests, 009 RESULT и 010 RESULT/API_DECISION/PLAN, installed IL/prefab receipts. Других AGENTS, csproj/props/targets, code-map/pattern-файлов не найдено. Локальные аналоги: native gather/paid craft 009; debit-first home operations 010; физический cache copy и negative fixtures Test-ProbeCache.

## Ограничения и решения

- C# 7.3, Windows PowerShell 5.1, installed Rust/Oxide; никакого обновления или изменения owner Server/.
- Стоимость 3760 wood сохраняется: loaded recipes + Twig260 + Wood1040 + консервативный upkeep1040. Native IL предсказывает при defaults 134 wood/1440 минут, включая дверь30, но mutable tax/group/prefab параметры ещё не измерены live. Не вводить новый speculative planner ради сокращения фарма. Фактический TC rate/period/protection обязателен.
- FirstHome2100с: измеренный сбор989.5 + travel до300 + builder/nav reserve360 + search/tool/buffer450.5. Runner2400с после readiness. Smoke900с. Legacy900с остаётся прежним. Initial admission reserve1350с (сбор + строительство), late reserve360с.
- Независимые причины NAV_PATH, TRAVEL_BUDGET, TIME_BUDGET и SITE_GEOMETRY; early/late receipts сохраняют длину, время и запас. Не ослаблять native checks.
- TC: физический stand перед ещё открытым doorway ближе (2.25м от foundation вместо3м); прежний target(.65,0,.6) оставлял лишь1.618м высоты eyes при native maxplaceDistance4м. Проверки reach/LOS/permission неизменны.
- Smoke: только новая физическая install/world copy под runtime run-id. Чтение trusted cache под lock, собственный manifest namespace, запрет Save-ProbeWorldCache для DiagnosticOnly. TEST_FIXTURE выдаётся один раз с UID/amount; не переносится в JOURNEY/RESTORE. Завершённый smoke остаётся DIAGNOSTIC_BUILD_ONLY, без production GREEN.
- До3 стартов: BUILD_SMOKE → только при полном smoke proof NATURAL JOURNEY → только при completed clean saved journey independent RESTORE. Не запускать лишнюю попытку при native blocker.

## Exact public mutation/delivery allowlist

Bounded exception: 9 существующих source/script/test файлов и пакет документов одной задачи; это один FirstHome pipeline, не отдельные подсистемы. До первого PID выяснилось, что firewall broker допускает только старый cache-install. Необходимы два дополнительных safety/test пути: точный runtime/run-id/install guard с соответствующим marker, без ослабления firewall enforcement.

- src/home/FirstHome.cs
- src/plugins/RustBotsAvatarSurvival.cs
- scripts/Invoke-NavigationProbe.ps1
- scripts/ProbeCache.ps1
- scripts/FirstHomeValidation.ps1
- scripts/Test-FirstHome.ps1
- scripts/Test-ProbeCache.ps1
- scripts/ProbeFirewall.ps1
- scripts/Test-ProbeFirewall.ps1
- docs/agent-tasks/RUST-BOTS-011-FIRST-HOME-COMPLETION/README.md
- docs/agent-tasks/RUST-BOTS-011-FIRST-HOME-COMPLETION/TASK.md
- docs/agent-tasks/RUST-BOTS-011-FIRST-HOME-COMPLETION/HANDOFF.md
- docs/agent-tasks/RUST-BOTS-011-FIRST-HOME-COMPLETION/EXECUTION_PLAN.md
- docs/agent-tasks/RUST-BOTS-011-FIRST-HOME-COMPLETION/GATES.md
- docs/agent-tasks/RUST-BOTS-011-FIRST-HOME-COMPLETION/ACCEPTANCE.md
- docs/agent-tasks/RUST-BOTS-011-FIRST-HOME-COMPLETION/EVIDENCE.md
- docs/agent-tasks/RUST-BOTS-011-FIRST-HOME-COMPLETION/RISKS.md
- docs/agent-tasks/RUST-BOTS-011-FIRST-HOME-COMPLETION/GOAL.txt
- docs/agent-tasks/RUST-BOTS-011-FIRST-HOME-COMPLETION/PLAN.md
- docs/agent-tasks/RUST-BOTS-011-FIRST-HOME-COMPLETION/RESULT.md

## Проверяемые этапы

- [x] Focused RED→GREEN: раздельный time admission/таймауты и реальная physical smoke cache isolation/no-promotion/no-natural-acceptance; дополнительный firewall-root regression.
- [x] Минимальный smoke path, phase receipts; installed compile + Test-All; независимое prelive source review, затем review точного firewall guard.
- [x] Owner hash baseline, safety preflight, один smoke live и immutable evidence. Независимый review фактического результата:6Wood blocks, TC DoBuild=null, PARTIAL.
- [x] Conditional branches оценены: G2 не пройден, поэтому NATURAL JOURNEY и independent RESTORE **NOT_CONDUCTED**. G3/G4 required, не passed. Не использовать оставшиеся старты для неразрешённого повторного smoke.
- [x] Owner/hash/safety/history и independent raw review; RESULT подготовлен. Final Test-All/scans/scope/exact delivery проверяются перед commit; фактический commit/push receipt хранится отдельно после операции.

Не проверено до live: DoBuild, grade, TC/auth/upkeep, door/native rebuilt HOME_NAV и independent home restore. Gate required остаётся required, пока фактический evidence не представлен.
