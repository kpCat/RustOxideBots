# RUST-BOTS-015 — план и журнал решений

**Цель:** доказать физически безопасный native проход настоящего порога в обе стороны; при отсутствии обоснованного исправления остановиться с PARTIAL/NATIVE_THRESHOLD_BLOCKED.

**Архитектура:** существующие FirstHome, RustNav movement, native placement/payment, validator и isolated runner. C#7.3/PowerShell5.1, без новых зависимостей. Источник требований: TASK.md, API_GATE.md, GATES.md, EXECUTION_PLAN.md и корневой AGENTS.md. Пользователь прямо поручил автономное исполнение; дополнительных approval/gate loops нет.

## Read-first и scope

Прочитаны root AGENTS/README, все11 входных файлов015, FirstHome.cs, FirstHomeValidation/Test-FirstHome, native actor/ground/nav в RustBotsAvatarSurvival, Test-All/Test-PluginCompile/Inspect-RustApi, релевантные runner/cache/safety/OwnedServerProcess участки и существующие аудит-скрипты014. Аналоги: placement012, native door/upkeep/approach013, actual collision/mesh/receipts014; дополнительно RESULT011. AGENTS выше корня и дополнительные вложенные AGENTS, отдельные code-map/pattern и csproj/props/targets не найдены; повторный поиск не нужен.

Публичный allowlist — **только14 документов текущего пакета015**: TASK, README, HANDOFF, COLLISION_BASELINE, API_GATE, GATES, ACCEPTANCE, EXECUTION_PLAN, EVIDENCE, RISKS, GOAL.txt плюс API_DECISION, PLAN, RESULT. Это bounded exception свыше10 файлов одной document family:11 переданы пользователем,3 отчёта созданы этой задачей. Product sources, scripts, root docs и история001–014 не меняются. Raw/аудит-скрипты только ignored `.local/audit/home015/`; это не новая runtime инфраструктура.

## Этапы и evidence

- [x] G0: actual HEAD/tracking/master baseline `ed25505e3e829af563243d242e2c3fc5729027f4`; public GitHub API и HTTPS ref совпадают. Входной status: только untracked docs015. SHA owner3086 файлов и protected inventory сняты до работ.
- [x] G1 investigation: fresh installed IL, native body/ground/mover, door/bake volume, fresh prefab/mesh и read-only сравнение014 geometry. Независимый reviewer проверяет альтернативы отдельно.
- [x] Сравнить centerline и ±25mm по portal transform. При прежней foot height threshold не исчезает; изменение horizontal settings не является vertical support. Base fallback найден, но не подменяет доказанный RustNav capsule contract.
- [x] Decision: остановиться на G1 HOLD. Не ослаблять guard, не добавлять бесполезный runtime waypoint и не выполнять smoke на необоснованном исправлении. Это разрешённая ветка EXECUTION_PLAN п.2, не заявление о невозможности будущего safe native маршрута.
- [x] Test-All под Windows PowerShell5.1, actual installed C#7.3 compile. Existing focused contracts проверены; новых contracts/RED→GREEN нет, потому что implementation не допущена.
- [x] Existing BUILD_SMOKE PreflightOnly: без RustDedicated PID/install/helper; prerequisites passed, diagnostic exit1. Это не live и не G2.
- [ ] G2 BUILD_SMOKE: **NOT_RUN, prerequisite G1 не выполнен**. Live compilation/load и physical crossing не заявляются.
- [ ] G3/G4 NATURAL/RESTORE: **NOT_RUN, prerequisite first smoke GREEN отсутствует**. Бюджет0/3, replay/fixture promotion0.
- [x] G5 preparation: финальное независимое review, owner/cache/history rehash, zero process/port/firewall/lease/lock audit, отдельные encoding и secret scans. Exact-path commit/ordinary push и remote/tree verification выполняются после этого snapshot; фактический SHA сохраняется в private delivery.json и финальном ответе без самоссылочного изменения документа. Product gate остаётся G1 HOLD.

## Отклонённые варианты и границы

1. Centerline без vertical support: больший lateral margin, но тот же измеренный crest; новый native corridor Y неизвестен. Новый live оправдан после конкретного способа подтвердить поверхность и full-body clearance, не только PathComplete.
2. baseOffset/Y correction: installed API существует, но additive lift без collision/support solver нарушил бы физический смысл задачи. Не применяется.
3. BaseNavigator step fallback: real API, однако другой режим с ray/sphere0.25 и записью `BaseEntity.ServerPosition`; не подтверждён для unchanged capsule0.5/1.8 и полного native path. Не интегрируется.
4. STEP_CONTACT до native resolution: diagnostic identity недостаточно. Не добавлять глубинный cutoff, blanket own/support exclusion, fake positive fixture или synthetic crossing.

Budgets сохранены: plugin NATURAL2100s/runner2400s, gather reserve1350/build360, historical gather около990s. Это существующие bounded значения с резервом, а не новая проверка способности закончить NATURAL. Smoke plugin900/runner1200/startup900. При последующем самостоятельном задании первым game process должен быть isolated BUILD_SMOKE; повторный smoke исключает одинокий NATURAL без RESTORE slot.

Все runtime возможности за пределами изученного installed пути, actual fresh grounded/Rigidbody/contact resolution и новая nav surface остаются UNKNOWN. Доставка закрывает исследование015 с честным PARTIAL; следующий Goal не начинается.
