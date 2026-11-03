# RUST-BOTS-006 — Player Avatar & Native Equipment Gate

## Зачем именно сейчас

001: один Gen2 NPC проходит 92,21 м на RustNav. 003: 413,58 м, нативный лут, owned `ItemContainer`, перезапуск. 004: настоящие деревья/руда, native pool debit и `SERVER_ACCOUNTED_TOOL`; 005: честный рецепт `200 wood + 100 stones → stonehatchet`, `SERVER_ACCOUNTED_CRAFT`, сохранённый UID. Все результаты ограничены тестовым scope.

**Архитектурный риск:** `ScientistNPC2 : BaseNPC2`, а НЕ `BasePlayer`. Его owned `ItemContainer` — не штатный `PlayerInventory`. Поэтому `GetActiveItem`, `GetHeldEntity`, `PlayerBlueprints`, обычный крафт, визуальная броня, доступы к TC/мешкам и игроковая механика PvP не становятся доступными автоматически. В установленном IL 004/005 уже замечено: `NPCPlayer : BasePlayer`, у него есть `NavAgent : RustNavMeshAgent` и APIs экипировки, но живое сочетание с новой навигацией НЕ ПРОВЕРЕНО.

**Outcome 006:** на отдельно запущенном RustDedicated определить, существует ли жизнеспособный **PLAYER_DERIVED_AVATAR** со штатными инвентарём и held-entity, который реально перемещается на RustNav без фальшивого Steam/клиента. Это не задача строить всю модель персонажа; это ранний выбор технического фундамента.

## 0. Безопасность и границы

- Перед правками прочитать `AGENTS.md`, `README.md`, `001/003/004/005 RESULT.md`, `004/005 API_DECISION.md`, код `src/plugins/RustBotsSurvival.cs`, `RustBotsWorldRoam.cs`, `RustBotsNavigationProbe.cs` и существующий runner/validators. Учитывать конкурирующие локальные изменения, не применять reset/clean/stash/rebase/force.
- Работать в `D:\Codex\repos\RustOxideBots`, ветка **master**, сверить исходный HEAD и origin/master с `ce25f3482468a2be48a4896275657dc59b28e9e5`. Если master ушёл вперёд, анализировать diff и безопасно согласовывать изменения, не перезаписывать их.
- **Весь `Server/` read-only и gitignored**. Не редактировать/обновлять локальные `Assembly-CSharp.dll`, Oxide, Rust, мир, owner configs, плагины, BAT, `.sav`, SteamCMD. Игровой сервер владельца не запускать. `002 SAFE-RUST-OXIDE-UPDATE` не выполнять.
- Только изолированная test install/cache/identity/Oxide writable data из существующего `Invoke-NavigationProbe.ps1`; блокирующие network firewall rules до старта, owned Job Object, ограниченные timeout+shutdown, проверка PID/портов/firewall/leases после каждой попытки. RustDedicated по возможности не администратор. Не завершать чужие процессы.
- Никаких новых пользовательских Steam ID, имитации чужого аккаунта, входа через Steam, реальных клиентских RPC или внешнего подключения. Если engine требует настоящую player connection для нужной функции, честно записать blocker.
- C# и PowerShell версии — фактически поддерживаемые локальным окружением (в 005: C# 7.3 / Windows PowerShell 5.1), отсутствие лишних зависимостей и Harmony. Данные и секреты только в ignored `.local/`.

## 1. Дешёвый API/IL gate до live

По установленным DLL + prefab manifest (read-only) проанализировать и документировать:

1. `NPCPlayer`, `ScientistNPC`, другие player-derived concrete prefabs, `BasePlayer`, `PlayerInventory`, `ItemContainer`, `ItemModEntity`, `HeldEntity`, `BaseMelee`, `RustNavMeshAgent`, `BaseNavigator`, `BaseAIBrain`, `FSMComponent`, spawn/sleep/destroy lifecycle.
2. Какие конкретные player-derived prefab **реально есть в установленном manifest**, имеют ли активный NavAgent, какой backend используют; являются ли их inventory/belt/wear и active item допустимыми без живой connection. Проверить реальные сигнатуры и существенные IL gates, не брать старые примеры из интернета как истину.
3. Жизненный цикл native equip: реальный native `Item`/UID, принадлежность `PlayerInventory.containerBelt`, `GetActiveItem`, `UpdateActiveItem`, `GetHeldEntity`, parent/owner, `SetHeld`, state/net visibility, возможные client-only ограничения. **Наличие методов в DLL — не доказательство работы на сервере.**
4. Сравнить рабочую архитектуру Gen2 с предполагаемым player-derived avatar, выделить минимальный adapter `IBotAvatar` / эквивалент *только если это нужно исполняемому коду*. Не переписывать `RustBotsSurvival` ради недоказанной миграции.
5. До первого полноценного запуска оформить `API_DECISION.md`: найденные prefab/type/signature/IL, риски и конкретный план live-проверки. Если вообще нет разумного безопасного candidate, ограничиться обоснованным BLOCKED или PARTIAL без длительных E2E.

## 2. Живое доказательство (1–2 запуска)

Создать **отдельный test-only** `src/plugins/RustBotsAvatarProbe.cs` (название можно обоснованно изменить), добавить минимальный режим в существующий headless runner, независимый валидатор и focused tests. Existing 001/003/004/005 режимы не ломать.

**A. Actor:** в изолированном тестовом мире создать **одного** поддерживаемого существующего player-derived NPC prefab без реальной Steam-сессии. Записать concrete type/prefab, наследование, nav agent, backend, brain/FSM, owner/session state, inventory component и net entity ID. Выяснить реальную причину отказа, если его нет. Не считать заранее Gen2 из 001 подходящим player actor.

**B. Движение:** если actor имеет рабочий RustNav, пройти не меньше **60 м actual** минимум в двух динамических complete-path переходах, не меньше **20 м net** хотя бы в одном. Telemetry time/positions, `PathComplete`, no warp/MovePosition/transform.position writes после spawn; bounded stuck/repath. Если player-derived модель не может ходить по RustNav, вернуть PARTIAL с конкретным failure mode; НЕ переключать ложный статус с помощью телепортации.

**C. Нативный инвентарь:** подтвердить наличие и работоспособность **того самого `PlayerInventory` у player-derived entity** (main/belt/wear, если применимо). Добавить 1 item `rock` **только как явно маркированный test-kit fixture**, либо доказанным native default loadout — не выдавать за фарм или 005 economy. Item должен иметь настоящий UID; записать owner/container, before/after, native inventory API. Отдельный native `stonehatchet` можно попробовать как дополнительный test fixture, но он НЕ является крафтом 005 и не должен выдаваться за перенесённый earned UID.

**D. Held item:** установить active item через применимый native путь и доказать, что `GetActiveItem` возвращает тот же UID, а `GetHeldEntity` принадлежит actor, если API позволяет; зафиксировать реальный held prefab, network flags и ограничения. Простой `ItemContainer`/item UID без активной held entity НЕ зачесть. Не заявлять визуальные анимации/клиентское отображение headless, если не тестировали их клиентом. Не включать combat/attack ради красивого статуса.

**E. Отрицательные проверки:** запрет activation отсутствующего/чужого UID; это не должно менять инвентарь и выдавать предмет. Если source/owner checks недоступны, описать, не придумывать. Если состоялся нативный equip — второй запуск предпочтительно посвятить перезапуску и проверке восстановленной identity/item UID/active selection, но не тратить третий сервер только ради необязательного визуального эффекта. Отличать вновь созданного аватара с восстановленным snapshot от непрерывно существующей native entity.

**F. Отказ без подлога:** если требуется network connection/Steam auth или конкретный player-derived NPC не поддерживает RustNav, выдать `PARTIAL` или `BLOCKED`, указать runtime proof. Оставить текущий Gen2 и его функционирующий 005 без изменений. В `DECISION.md` обозначить дальнейший путь: (а) player-derived avatar, (б) Gen2 с честными server adapters, (в) отложенный visual/dual-avatar bridge с рисками. НЕ обещать синхронизацию двух NPC, не делая её.

## 3. Контроль стоимости и регрессии

- Перед каждым live: metadata/IL/static compile и короткие tests. Ориентир **2 живых запуска максимум**, третий — только если устранён конкретный наблюдаемый технический дефект и есть ясная проверка. Не расходовать запуска ради бесконечного ожидания, не проводить 50-100 NPC нагрузочный тест.
- Если E2E будет успешен, доказать физический ход и inventory/equip **в одном логически связном тесте**, не склеивать несовместимые типы или подменять actor. Раздельные подстатусы `AVATAR`, `NAV`, `PLAYER_INVENTORY`, `HELD_ITEM`, `PERSISTENCE`, `SAFETY`.
- Валидаторы RED→GREEN на фальшивый UID/owner, нулевое расстояние, manual warp, чужой item, missing GetHeldEntity, duplicate fixture, failed shutdown. Несуществующую native equip не засчитывать через фиктивный mock.
- Отчёты фиксируют тип `NPCPlayer` или иной реальный `BasePlayer` наследник, не называют объект настоящим Steam-игроком. Разделить `STATIC`, `OFFLINE`, `LIVE`, `NOT_VERIFIED`.

## 4. Завершение и Git

Сохранить `API_DECISION.md`, `DECISION.md` и `RESULT.md` с доказательствами и следующей архитектурной рекомендацией. Выполнить full focused offline suite; live Oxide compilation и реальные логи только при состоявшемся запуске. Runtime/output/секреты — ignored `.local/`.

Проверить protected owner fingerprint, гигиену кода, mojibake и отдельно escaped Cyrillic, не перекодировать кириллицу в escape-строки. Убедиться, что нет оставшихся **собственных** PID, портов, firewall rules/leases. `Server/` не tracked и не публикуется.

Проверить точную allowlist после ревью diff и сделать **exact-path commit + обычный fast-forward `push origin master`**, без force, reset/rebase/clean, без широкого `git add .`. Итоговый SHA, `origin/master`, чистое дерево и список изменённых файлов — в RESULT/delivery. Если обнаружены чужие изменения, не затереть их.

**Не создавать бесконечную инфраструктуру; цель 006 — подтвердить или опровергнуть именно игрокоподобный технический фундамент.**
