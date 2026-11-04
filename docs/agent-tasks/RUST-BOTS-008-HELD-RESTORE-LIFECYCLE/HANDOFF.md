# HANDOFF — известные факты перед 008

## Репозиторий и правила

- `D:\Codex\repos\RustOxideBots`, GitHub `https://github.com/kpCat/RustOxideBots`, `master`.
- Контрольный SHA: **`811220edbcbed8ffcaca804306e66cf6f40d1de6`** (007 PARTIAL, GitHub HEAD проверен ChatGPT 03.11.2026). Если на старте ветка уже другая, анализировать изменения и не делать reset/force/rebase/clean.
- Читать корневой `AGENTS.md`. `Server/` (6+ ГБ, owner game world/oxide/plugins/config/data) полностью приватен и read-only. Тесты — отдельный physical install, независимый writable Oxide, проверенные firewall deny rules, owned Job Object, auto quit/cleanup. SteamCMD/`update.bat`/`Run_DS.bat`/задача 002 не запускать.
- Тестовый runner `scripts/Invoke-NavigationProbe.ps1` с режимами `-AvatarSurvival` и `-RestoreFrom`; кеш RustNav в ignored `.local/probe-cache/` и результаты в `.local/runtime/`.

## Что доказано (не путать со следующей целью)

- 001: Gen2 RustNav 92,21 м, автоматические тесты/кеш.
- 003: 413,58 м, native barrel и native crate fixture, native ItemContainer.
- 004: wood20/stones20, серверный accounted tool, restore по UID.
- 005: оплаченный stonehatchet (Gen2) в ItemContainer, accounted craft, restore.
- 006: `ScientistNPC : BasePlayer`, PlayerInventory main/belt/wear, native ActiveItem/HeldEntity, 93,69549 м с RustNav; 006 не доказывает persistent native inventory.
- 007: **PARTIAL**: `ScientistNPC_Roam : BasePlayer`; реальный NATIVE_PLAYER_GATHER **201 wood +107 stones**, списание/износ native rock; оплаченный SERVER_ACCOUNTED_CRAFT stonehatchet **UID 87251**, положен в native belt и активирован; GetHeldEntity.GetItem UID 87251, parent/owner actor. Восстановление после рестарта не завершено.

## Опорные артефакты 007

- `src/plugins/RustBotsAvatarSurvival.cs` v0.1.1, в частности `Restore()` и `Save()`.
- `scripts/AvatarSurvivalValidation.ps1`, `scripts/Test-AvatarSurvival.ps1`, `scripts/Invoke-NavigationProbe.ps1`, `scripts/Test-All.ps1`.
- `docs/agent-tasks/RUST-BOTS-007-NATIVE-AVATAR-SURVIVAL-BRIDGE/{RESULT.md,API_DECISION.md,RISK_REGISTER.md}`.
- Успешный JOURNEY `d5f2cbcbecd54c2dae6b772d327b8e3a` (snapshot source SHA `0983E604512F4CD2A40F96E4964694C430B3C9192B38EDCA7CBE17BE1141A5ED`), GRACEFUL и world proof.
- Неуспешный независимый RESTORE `346f0025715b4c22ace0cc9501f39f37` — сохранён сырой PARTIAL; `ItemContainer.Load`/`PlayerInventory.Load` **не выполнялись**.
- Снимок: native PlayerInventory main/belt/wear, rock **item UID 81010** с **heldEntity network ID 81011**, stonehatchet **item UID 87251** с **heldEntity network ID 87252**; worldEntity=0, вложенных items=0. При `serverEntities.Find(81011)!=null` ранний guard остановил RESTORE. Конкретный тип и ownership найденного объекта — UNKNOWN.
- Origin world `world-2ef374a7b00c4f91b2b9db6e6817698b`, `.sav` SHA `C6D1F894CC31472E9F7A27E7037DDD7FCC4843393641589E8C19F2E1D74342AD`; inventory snapshot SHA `F1C56E0F4E92099112251B236B05108839D596108173613D6137FA3073E128D4`; actor-state SHA `FF08CD6A1D8FF692E76761E36C98236B6CB57A3E9F7243E9B1630B6817728441`. Эти значения — факты прошлого run, **не разрешение обходить проверку текущих cache generation/hash**.
- В исходном `Restore()` уже есть очистка **только `heldEntity` в in-memory protobuf** после строгих snapshot/UID/role проверок; она не была достигнута из-за более раннего guard. Нельзя просто снять guard или чистить живые `serverEntities`.

## Долгосрочная цель и следующие риски

~50–100 постоянных выживших: пляж, ферма/лут/крафт/базы с TC, двери, спальники/смерть, PvP/группы/рейды, карьер; oil rigs/cargo optional, Semantic Pack в конце. Но 008 — только Native Avatar Restore. Отдельно не закрыты истощение ResourceDispenser между рестартами и crash-atomic учёт списаний при крафте. Не подменять ими текущий приоритет.
