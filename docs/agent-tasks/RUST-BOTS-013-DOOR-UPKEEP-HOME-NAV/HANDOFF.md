# HANDOFF — достоверная история и точные ограничения

## Проверенный GitHub baseline

- `origin/master` на момент постановки: `237fb6f18e513a2197d5a919e1fb38ab83ea6358` (commit `fix: correct native TC surface placement and own authorization`). Перед редактированием Codex обязан подтвердить local HEAD, `origin/master`, **фактический публичный GitHub master** и статус tree. Если отличаются — не reset/rebase/force/clean, зафиксировать различия и не затереть чужие правки.
- Путь repo `D:\Codex\repos\RustOxideBots`, owner runtime `D:\Codex\repos\RustOxideBots\Server\rustds` (~6+ GiB) ИСКЛЮЧЁН из Git и целиком read-only. Owner `Run_DS.bat`, `update.bat`, SteamCMD, Rust/Oxide update не запускать. Задача 002 updater — design only.
- `AGENTS.md`: isolated physical test install, Steam/чужие Rust процессы блокируют запуск; Job Object для своего PID, временный firewall broker, свежие Oxide data/identity, temp secrets в ignored `.local/`; exact staging, обычный push, no force, cleanup.

## Результаты и блокеры

- 006: `ScientistNPC : BasePlayer`, настоящий `PlayerInventory`, `ActiveItem/HeldEntity`, RustNav; исправлен `ResetPath` speed=0.
- 007: нативный gather из natural resources, `SERVER_ACCOUNTED_CRAFT`, изготовленный stonehatchet в native belt, PARTIAL restore.
- 008: original Item UID/amount/condition/active HeldEntity восстановлены после рестарта, GREEN_RESTORE.
- 009: journal с world/map/wipe binding, native depletion graceful-restart proven, повторный APPLY→NOOP. CRASH_ATOMIC=NOT_PROVEN; multi-map live отсутствует.
- 010: после четырёх стартов site найден, 3763wood добыто, но home placement не достигнут из-за времени, PARTIAL/BLOCKED_BUDGET.
- 011: BUILD_SMOKE c `TEST_FIXTURE` физически построил шесть real `BuildingBlock` Wood (foundation + 3 walls + doorway + roof), TC=null; natural/restore не запускались.
- 012: исправлен TC `onTerrain=socket==null`: `Socket_Free_Snappable` требует free-surface target даже при parent foundation. Native TC return и autoauthorization подтверждены. Последний run `65f0f52e10834a38954fa23e983304c9`: `homeStep=7`, фаза `BUILD_WAIT`, после TC и перед дверью `HomeBuildStand()` → `NavSample()` false → `No physical building approach`. `NavSample` вызывает RustNav `SamplePosition` И `Ground` (terrain ray, terrain height/normal, water, OverlapCapsule); **какой subcheck не прошёл, UNKNOWN**. Smoke 3/3, natural и restore 0. Actual TC net146584, owner engine bot15, buildingID1, auth own-only, `IsAuthed=true`, `TC.CanBuild=true`; upkeep/door/home nav NOT_PROVEN. 3086 owner файлов без изменений. 012 raw не менять.

## Код для обязательного чтения

- `src/home/FirstHome.cs`: `HomeBuildStand`, `HomeBuildStep`, `HomeMove`, `HomeArrived`, `HomeCheckSite`, `HomePlace`, `HomeTcDiagnostic`, `HomeAuthorizeAndUpkeep`, `HomeInterior`, `HomeOpenDoor`, `HomePhysicalSample`, `HomeCrossing`, `HomeSave`, `HomeRestorePreflight`.
- `src/plugins/RustBotsAvatarSurvival.cs`: `NavSample` и `Ground` (наследие outdoor), `agent`, `Tick`, `HomeTick`, physical sample, native actor/held ownership.
- `scripts/Invoke-NavigationProbe.ps1` (`-FirstHomeSmoke`), `ProbeCache.ps1`, `ProbeFirewall.ps1`, `ProbeSafety.ps1`, `OwnedServerProcess.cs`; `scripts/Test-FirstHome.ps1`, `FirstHomeValidation.ps1`, `Test-All.ps1`, `Test-PluginCompile.ps1`.
- `docs/agent-tasks/RUST-BOTS-012-TC-DOOR-PLACEMENT/{RESULT.md,API_DECISION.md}`; 011 `RESULT.md`; 010 `RESULT.md`; 009 `RESULT.md`.

## Цель владельца

50–100 самостоятельных человекоподобных NPC на **произвольной** совместимой карте Rust: начинают с берега, реальные loot/gather/craft, строят и содержат дома, используют двери/гаражки/ящики/верстаки, спальники/смерть/respawn, переживают захват TC/рейды, враждуют и объединяются, Giant Excavator с дизелем. Cargo/oil rig опционально; Semantic Pack поздно. Одно тестовое 1x1 не равно полной базе. Каждый этап — отдельный Codex-чат, ZIP-постановка; отчёт сверяется с GitHub исходниками.
