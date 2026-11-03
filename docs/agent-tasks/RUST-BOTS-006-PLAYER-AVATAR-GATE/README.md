# RUST-BOTS-006 — Player Avatar & Native Equipment Gate

**Отдельная задача для НОВОГО диалога Codex. Уровень мышления: HIGH.**

Цель этапа: рано проверить главный риск всего Rust Phantom Life — может ли человекоподобный, наследующий `BasePlayer` NPC одновременно **ходить по актуальному RustNav** и **пользоваться нативными инвентарём/экипировкой** без клиентской Steam-сессии и без вмешательства в игровую сборку.

Исходная версия публичного репозитория: `ce25f3482468a2be48a4896275657dc59b28e9e5` (`master` на момент подготовки задачи, 03.11.2026). До исполнения проверить реальный локальный HEAD и `origin/master`; не стирать чужие изменения.

В этом архиве 8 документов: `TASK.md` (главный), `API_GATE.md`, `ACCEPTANCE.md`, `EVIDENCE.md`, `HANDOFF.md`, `RISKS_AND_NEXT.md`, `GOAL.txt`, этот README. Распаковать весь архив **в корень** `D:\Codex\repos\RustOxideBots\` с сохранением пути `docs/agent-tasks/...`.

Не делать в 006 production-ботов, рейды, дома, кланы, изучение чертежей или переработку всех старых плагинов. Сначала доказать или опровергнуть пригодность нативного player-derived аватара. Если API не позволяет — честный PARTIAL/BLOCKED полезнее выдуманного GREEN.

Режим исполнения из корня репозитория (новый plugin остаётся инертным вне изолированного runner):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-NavigationProbe.ps1 -PlayerAvatar -PreflightOnly
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-NavigationProbe.ps1 -PlayerAvatar
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-All.ps1
```

PlayerAvatar несовместим с WorldRoam/SurvivalGather/SurvivalCraft и не поддерживает RestoreFrom/ResumeJourney. Созданный rock — TEST_FIXTURE для native экипировки, не добыча и не крафт 005. Persistence и клиентская визуализация отдельно ограничены в RESULT.md. API, итог развилки и фактические evidence находятся в API_DECISION.md, DECISION.md и RESULT.md.
