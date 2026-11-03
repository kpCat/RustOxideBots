# RISKS / следующая техническая задолженность

## R1 — native actor / player features

`ScientistNPC2` способен ходить по RustNav, но не является `BasePlayer`. Его owned `ItemContainer` — не `PlayerInventory`; у него нет автоматически работающей native craft queue, UI, удержания оружия, обычных player blueprints или полноценной клиентской сессии. До объявления эквивалентности нужны runtime доказательства. Установленный 004 `API_DECISION.md` — исходная точка. `NPCPlayer`/`BasePlayer` можно исследовать как будущий avatar bridge, но не требуется переписывать все существующие probes в 005.

## R2 — сохранение добычи из resource nodes

004 сохранил item UID и actor, **но не persisted source resource pools**. После рестарта число оставшихся ресурсов в том же дереве/узле может вернуться, создавая возможности повторного фарма. Перед выпуском production-популяции обязательно решить durable conservation: versioned per-world transaction journal, source stable identity/position/prefab/world generation, idempotent replay, multi-category resource handling, failure and crash recovery. **Не фиксировать** проблему путём обнуления всех деревьев или массового изменения owner мира.

## R3 — настоящее развитие после крафта

Следующие этапы: изучение конкретных чертежей за скрап, player-like progression и обоснованные цены/верстаки; placement workbench/печей/переработчиков; дом/TC/upkeep с возможностью потерять базу; перемещение по комнатам/дверям, хранение по ящикам, спалка/смерть/respawn; группировки/PvP; Giant Excavator. Cargo и oil rigs optional; Semantic Pack почти в конце. Не делать всё в рамках 005.

## R4 — расходы и защита сервера

Игра 004 требовала 3 полных server runs; 005 ограничить 2 (3 при реальном техническом blocker). Test cache не должен копировать owner's `.sav`, Oxide configs и плагины. Привилегированный helper только для temporary firewall, RustDedicated без admin. Не делать upgrade/clean/delete для экономии времени; не отключать безопасность.
