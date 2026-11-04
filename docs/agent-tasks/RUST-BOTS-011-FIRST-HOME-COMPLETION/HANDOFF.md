# HANDOFF — актуальная фактическая база

## Где проект

- Local checkout `D:\Codex\repos\RustOxideBots`, remote `https://github.com/kpCat/RustOxideBots`, ветка master, проверенный HEAD `19ab338c518defa5508fbe8a70448ae773c2b0ec`.
- Вся `Server/` — приватная 6+ГБ установка владельца: `Server/rustds/`, `oxide/plugins`, `config`, `data`, `server` saves, `Run_DS.bat`, `update.bat`. Всё игнорируется Git и должно остаться **read-only**. Не обновлять Rust/Oxide/SteamCMD; updater 002 — DESIGN ONLY.
- `AGENTS.md`: isolated physical runtime и свежая writable Oxide state, firewall блокировка тестовых exe, separate elevated broker, kill-on-close Job Object, закрытие только своих серверов, bounded graceful quit, конфиденциальные logs/evidence в `.local/`, exact-path Git.

## Доказанные предшественники

- 001 RustNav: 92.21м, Gen2; тёплый тестовый мир/cache и собственный runner.
- 003 Road/Loot: 413.58м, native barrel, native crate fixture, реальный item transfer.
- 004/005: натуральная добыча и оплаченный stonehatchet, первоначально accounted tools/craft.
- 006: `ScientistNPC : BasePlayer` + RustNav + настоящий PlayerInventory/ActiveItem/HeldEntity.
- 007: на одном player-derived NPC живой native gather wood/stones, paid SERVER_ACCOUNTED_CRAFT, тот же crafted UID удерживается; исторический PARTIAL из-за restore.
- 008: реальный native PlayerInventory restore, original Item UID/condition и новый native HeldEntity после рестарта; old held entity netID transient.
- 009: `GREEN_WORLD_DEPLETION`, native farming+paid axe, source pool tree 500→100 и ore750→536 после restart, replay NOOP; stable MapKey/WorldKey/WipeId; **crash atomicity NOT_PROVEN**, multi-map gameplay E2E NOT_DONE. Исторические raw receipts не изменять.

## 010 — анализ четырёх запусков из опубликованного RESULT

- HEAD `5310f8a...` — два JOURNEY с `BLOCKED_SITE`, 512 кандидатов, 0 размещений. Более гибкий world search и native previews потом нашли сайт.
- Новый HEAD `19ab338c...` — 3-й запуск: site на 16184-м кандидате, source/tool wear: axe сломался при 3057/3760 wood, terminal PREPARED=IN_DOUBT, no home.
- 4-й `39baf6925235477ebbca7aa07d2b73fd` (v0.2.3): 488 native hits, gross3963wood+107stones; paid stonehatchet wood200/stones100; terminal3763wood+7stones, **полный home budget3760wood**. Single controlled axe→starter rock switch (оба честные), journal1470COMMITTED. Travel554.629м/37legs, GREEN native gather/ownership; no fake resource awards.
- Site native preview и path Complete подтвердились. Но gameplay elapsed **989.50436с**, limit **1100с**, remaining~110.49564с. `HomeCheckSite` требует travel + reserve120с, поэтому `RUSTNAV_OR_TRAVEL_BOUND`. Дома нет. Фраза «Selected home site changed» является общей ошибкой revalidation, не доказательством изменившейся геометрии.
- 4 запуска из 010 исчерпали разрешённый бюджет. Разрешение «пятый только RESTORE» не применимо, т.к. завершённого дома/снимка нет. **011 — отдельная новая задача, а не допуск продолжить пятый 010.**
- В 010 реальные `Planner.DoBuild`, native grade, TC auth/upkeep, дверь/проход, home native save/restore **НЕ ВЫЗЫВАЛИСЬ**; static/fixture checks их не доказывают. Не начинать очередной 3760-wood фарм до доказательства native строительного пути в изолированном smoke.

## Где код

- `src/home/FirstHome.cs` ~605 строк: `PrepareHome`, `HomeSearchBatch`, `HomeCheckSite`, `HomeMaterialsReady`, `HomePlace`, `HomeBuildStep`, `HomeAuthorizeAndUpkeep`, `HomePhysicalSample`, `HomeRestorePreflight`.
- `src/plugins/RustBotsAvatarSurvival.cs`: player-derived actor, genuine native gathering, paid accounted craft, avatar restore and shared economy hooks.
- `src/economy/EconomyJournal.cs`: durable sequence/checksum helper, Source/incarnation/wipe binding. **Не обещать crash-safe как доказанное.**
- `scripts/Invoke-NavigationProbe.ps1 -FirstHome` + existing compiler/tests/validators.
- `docs/agent-tasks/RUST-BOTS-010-FIRST-HOME-TC/{RESULT,API_DECISION,PLAN}.md` — read-first источник фактов.
- `docs/agent-tasks/RUST-BOTS-003-WORLD-ROAM-LOOT/LIFE_ROADMAP.md` — конечная цель 50–100 выживших с домом, TC, дверьми, ящиками, спалками, кланами, PvP, карьером.

## Рабочая среда

C# 7.3, Oxide compiler installed; Windows PowerShell 5.1. Test-only procedural map seed424242/size2000 — **только fixture**, не coordinates/program behavior. RustNav default mesh/build readiness, own test identity and warm cache. Startup в 010 ~272–279с; избегать лишних full launches. Все live тесты запускает/останавливает Codex сам, пользователь не запускает BAT/PowerShell.
