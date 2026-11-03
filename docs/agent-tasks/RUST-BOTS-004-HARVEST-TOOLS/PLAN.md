# Harvest & Tools Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans; continuous autonomous execution is explicitly requested. Independent API inspection may run concurrently; one controller owns live runs.

**Goal:** Один Gen2 NPC физически добывает wood и stones/ore у естественных источников, с честным инструментом, source debit и независимым восстановлением.

**Architecture:** Отдельный `RustBotsSurvival` использует проверенные spawn/RustNav/native ItemContainer из 003. Небольшой actor state отделяет личность, потребности и инструмент от сущности Gen2. Native harvest/equipment выбираются только по установленным DLL; допустимый fallback явно `SERVER_ACCOUNTED_TOOL`. Существующий runner сохраняет единоличное управление firewall/job/cache/shutdown.

**Tech Stack:** Installed Rust/Oxide, C# 7.3, Windows PowerShell 5.1, native RustNav, protobuf ItemContainer.

**Spec:** TASK.md, ACCEPTANCE.md, GATES.md, EVIDENCE.md в этом каталоге.

## Global Constraints

- Один NPC; no warp; natural wood и ore/stone; fixtures не дают natural GREEN.
- Source debit до output, starter rock отдельно, no fake native equip.
- Owner Server read-only; no updater/SteamCMD; raw evidence только ignored .local.
- Цель два live запуска (gather, restore), максимум три при доказанном дефекте.
- Current master разрешён пользователем; точечный staging, обычный push, без смены истории.
- Bounded exception: один связный gameplay slice, 17 публичных файлов: семь предоставленных input docs; PLAN/API_DECISION/RESULT; survival plugin; runner; SurvivalValidation/Test-Survival; Test-All/Test-PluginCompile; README. Никаких изменений 001/003 plugins, safety/cache/firewall/process helpers или task 002.

## Review Focus

- Native damage не должен начислять второй yield параллельно адаптеру.
- Отсутствующий/сломанный tool, range/LOS и exhausted source обязаны закрывать действие.
- Дублирующий UID, credited output без равного pool debit и несогласованная бухгалтерия отвергаются.
- Restore обязан привязывать inventory и actor/goal/tool state к exact completed .sav/generation/hash.
- Точки подхода и samples должны доказывать physical continuity, а не только PathComplete в логах.

### Task 1: API gate

Files: API_DECISION.md; raw IL в ignored .local.

- [x] Проверить actor/equipment/dispenser/tool API и IL по локальным DLL; записать hashes.
- [x] Выбрать SERVER_ACCOUNTED_TOOL с native amount debit; native player/crafting и несохранение dispenser pools раскрыты в API_DECISION.

### Task 2: Survival contracts, plugin and runner

Files: src/plugins/RustBotsSurvival.cs; scripts/SurvivalValidation.ps1; scripts/Test-Survival.ps1; scripts/Invoke-NavigationProbe.ps1; scripts/Test-All.ps1; scripts/Test-PluginCompile.ps1.

Interfaces: runner `-SurvivalGather [-RestoreFrom <id>]`, mutually exclusive WorldRoam. Plugin result `Mode=GATHER|RESTORE`, native inventory rows UID/Shortname/Amount/Condition; ActorState and starter kit; Samples/Legs/Harvests; Conservation; Persistence. Per-harvest hits include actual pool before/after, output rows, tool state, range/LOS and source identity/provenance. State snapshot is independently hashed alongside inventory and bound to exact world proof.

- [x] Focused synthetic contracts: RED отсутствующего validator, затем GREEN. Review regression: unrelated harvest route RED → GREEN после timestamp/sample binding.
- [x] Bounded discovery, complete-path approach, NeedResource planner, source debit, tool accounting и native save/restore; road/loot subsystem не перенесён.
- [x] Режим подключён к текущему runner с сохранением 001/003 и exact-world proof; snapshot исходника входит в run evidence.
- [x] Focused validators, C# 7.3 compile и существующий offline suite прошли. Fixtures не live evidence.

### Task 3: Live evidence and delivery

Files: RESULT.md; README.md; ignored per-run audit/evidence.

- [ ] Снять owner fingerprint; preflight/isolation; проверить отсутствие чужих процессов.
- [ ] Live gather с natural источниками и независимой реконструкцией receipts; автоматический shutdown и cleanup.
- [ ] Live restore в точном saved world; сверить UID/amount, actor identity/goals/tool state; повторить cleanup и owner fingerprint.
- [ ] Свежий read-only code review и минимальные необходимые исправления/проверки.
- [ ] RESULT с полной matrix и честным итогом; две отдельные encoding проверки; exact allowlist/diff/ignore/secret guard.
- [ ] Exact-path commit, ordinary push origin master, remote SHA receipt; итоговый ответ с SHA и ограничениями.
