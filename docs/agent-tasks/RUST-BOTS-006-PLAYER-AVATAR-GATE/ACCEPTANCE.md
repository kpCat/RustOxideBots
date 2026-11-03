# ACCEPTANCE — RUST-BOTS-006

| Gate | Подтверждение GREEN / PARTIAL |
|---|---|
| Baseline | Реальные local HEAD/master, статусы, snapshot установленных DLL и actual prefab discovery |
| AVATAR | Один live player-derived entity: тип наследует BasePlayer, конкретный prefab и owner/session state |
| NAV | **На том же actor** >=60 м actual, >=2 `PathComplete` legs, >=20 м net в одном, без warp/teleport, с сырыми физическими samples |
| PLAYER_INVENTORY | **На том же actor** работающий native `PlayerInventory` с belt/main/wear, настоящий item UID, подтверждённое владение, не owned arbitrary ItemContainer |
| HELD_ITEM | UID в native belt, active UID через `GetActiveItem`, native `GetHeldEntity` на нём, owner relationship; пустой метод/field не доказательство |
| NEGATIVE | Активация несуществующего/чужого UID отказана без изменения инвентаря/появления items |
| PERSISTENCE | Если был повторный запуск: точная связь с world generation и сохранение UID/condition/active intent; если не проверено — `NOT_VERIFIED`, НЕ подменять GREEN claim о persistence |
| SAFETY | Owner файлы unchanged, processes/ports/firewall/lease очищены, test install isolated |
| CODE | Все прошлые тестовые сценарии не сломаны, C# compile, validators, live log, проверки кодировок |
| GIT | Exact-path fast-forward commit/push в `master`, `origin/master` подтверждён, `Server/` не tracked |

**GREEN_AVATAR_GATE**: обязательные AVATAR + NAV + PLAYER_INVENTORY + HELD_ITEM + NEGATIVE + SAFETY + CODE + GIT доказаны реальным E2E. Не обязательно доказать визуальные анимации, нативный крафт, PvP или восстановление после restart, если второго запуска не было; эти пункты отдельно `NOT_VERIFIED`. GREEN в этих границах означает только техническую пригодность player-derived модели как кандидата.

**PARTIAL**: доказан actor и часть native inventory/held/nav, но хотя бы один критический живой gate не пройден; указан точный дефект, не размазывать по красивому summary.

**BLOCKED**: нет безопасного concrete candidate, серверной возможности или прав/среды для живой проверки. Отсутствие live-данных явно указать.

**FAILED**: потеря item-conservation, owner mutation, orphan-servers/security breach, ложные E2E claims или неверно подтверждённый GREEN.

`Gen2` параллельным actor и отдельно созданный `BasePlayer` не могут быть «сложены» в один GREEN. Создание test fixture `rock/stonehatchet` допустимо ТОЛЬКО для проверки экипировки и маркируется как `TEST_FIXTURE`, а не фарм/крафт. Предполагаемое клиентское изображение игрока и native multiplayer session не проверяются без клиента.
