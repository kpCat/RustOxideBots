# Подтверждённый handoff из GitHub master

## Репозиторий и локальная среда

- GitHub: `https://github.com/kpCat/RustOxideBots` (`master`). Baseline SHA `610937733286263b83c2f70577ec629ecd482b3a` проверен в публичном GitHub.
- Локально: `D:\Codex\repos\RustOxideBots\`. `Server\rustds` — личный RustDedicated/Oxide. Весь `Server/` ~6+ GB приватный, read-only, ignored. Не запускать owner `Run_DS.bat`, `update.bat`, SteamCMD или task002.
- `scripts/Invoke-NavigationProbe.ps1 -FirstHomeSmoke` существует, сам управляет изолированным физическим тестовым RustDedicated, временным firewall block и kill-on-close Job Object. Source `src/home/FirstHome.cs` добавляется runner к исходнику `src/plugins/RustBotsAvatarSurvival.cs` вместе с `src/economy/EconomyJournal.cs`.
- Smoke fork мира **отделён** от trusted warm cache и НЕ может делать promotion; уникальный diagnostic namespace, отдельный marker, физические копии, никакого hardlink/junction для изменяемых данных. Сохранить эти проверки.
- Runtime C#7.3/Oxide 2.0.7839/PowerShell5.1 по прежним фактам, перед запуском вновь проверить фактические DLL и compiler.

## Уже доказано

- 006: `ScientistNPC : BasePlayer` и RustNav, native PlayerInventory и HeldEntity.
- 007–008: native gathering дерева/камня, оплаченный accounted craft, crafted stonehatchet native-held, восстановление точных UID после рестарта.
- 009: journal и source depletion для одной карты, штатный independent restart и idempotent replay, **не** crash-atomic и **не** multi-map E2E.
- 010: 4 live попытки; site и 3763wood получены, но не выполнено ни одного placement до deadline. PARTIAL, не считать домом.
- 011: один физический `BUILD_SMOKE` `796947c80d214fc4aa309b429e637adc`; 6 native Wood blocks (foundation ID146471; 3 walls, doorway, roof), один buildingID, native support/registration, fixture-paid. До TC: 17 committed payment ops, 2920wood+100stones потрачено, осталось 1040wood, оплаченный `cupboard.tool` item UID144841 остался в инвентаре.
- 011 `Planner.DoBuild(Construction.Target, Construction)` для TC, parent foundation146471/socket=null, вернул `null`, `Construction.lastPlacementErrorDebug` пуст. Код НЕ захватил native Phrase/полный внутренний отказ. **Причина неизвестна**. TC, дверь, upkeep, room navigation и natural home restore не доказаны. 011 PARTIAL.
- 011 actual smoke: 107.874908м, Test-All PASS, protected owner 3086 files без изменений, процессы/правила/ports/locks0, cache promotion=false.
- Последний commit `6109377` уже содержал улучшения timeout и безопасного smoke isolation. Проверить новые файлы, не переписывать старые RESULT/raw receipts задним числом.

## Ближайшие исходники

- `src/home/FirstHome.cs`: `HomePlace()`, `HomeTarget()`, `HomeBuildStep()`, `HomeBuildStand()`, `HomeFoundationPreview()`, `HomeAuthorizeAndUpkeep()`, `HomeOpenDoor()` и `HomeInterior()`.
- Для TC текущее `HomePlace("TC","TC","cupboard.tool",foundation,null,foundation.transform.TransformPoint(new Vector3(0.65f,0,0.6f)))`. Этот target/parent/ray/rotation/surface/LOS требует изучения, не объявлять виновным заранее.
- `docs/agent-tasks/RUST-BOTS-011-FIRST-HOME-COMPLETION/RESULT.md` и `docs/agent-tasks/RUST-BOTS-010-FIRST-HOME-TC/API_DECISION.md`.
- `scripts/FirstHomeValidation.ps1`, `scripts/Test-FirstHome.ps1`, `scripts/ProbeCache.ps1`, `scripts/ProbeFirewall.ps1`, `scripts/Invoke-NavigationProbe.ps1`, `scripts/Test-All.ps1`.

## Долгосрочная пользовательская цель

50–100 постоянных автономных выживших: пляж, roam/roads, crates/barrels, native farming, gear/craft/blueprints/benches, настоящие базы/TC/upkeep/ящики/двери/гаражки, спальки/смерть/respawn/восстановление после рейда, PvP/кланы/оборона, Giant Excavator с дизелем и выборочной атакой групп. Нефтянки/карго необязательны, Semantic Pack в конце. В 012 не делать это всё.
