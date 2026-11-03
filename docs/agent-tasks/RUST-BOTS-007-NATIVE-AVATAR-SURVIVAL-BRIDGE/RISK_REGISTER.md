# RISK REGISTER / проект после 007

**R1 — долговечность истощения world resources (высокий, открыт).** 004/005 native `ResourceDispenser.containedItems` уменьшался в процессе, но state depletion не сохранялся между запусками сервера. World .sav сам по себе не доказывает сохранение per-node pools. До постоянной экономики 50–100 NPC нужен `WORLD-ECONOMY-PERSISTENCE` с stable world-key/source identity, idempotent replay, crash/restart journal, reconciliation и контролем двойного фарма; при различии процедурной карты/временного UID никакой replay на чужие узлы.

**R2 — crash-atomic accounting (высокий, открыт).** В 005 `Item.UseItem` и создание выхода синхронны, но между оплатой и новым Item нет полноценного persisted recovery. Требуется transactional intent и fail-closed без двойной выдачи, в том числе после падения process, а не только штатного quit.

**R3 — native/player equivalence.** 006 доказал native PlayerInventory/HeldEntity на ScientistNPC, но не native attack, tool animation, player skin/appearance, Steam-auth client. 007 сохраняет честные labels и не даёт фальшивого GREEN native pipeline.

**R4 — ограничения сервера и лимиты.** Тестовый cache реально ускоряет карту, но startup остаётся ~260 с. Не умножать E2E бесконечно: 2, максимум 3 после доказанного дефекта, с независимыми офлайн fixtures и сохранением raw evidence. Не трогать owner-конфиги ради ускорения.

**R5 — gameplay backlog (не делать в 007).** Bed/bag/sleeping/respawn и смерть с настоящим corpse/loot; дом (несколько real TC, upkeep, destruction/rebuild), комнатный граф/dynamic RustNav при дверях/гаражках; ящики/печи/верстаки/research; кланы/отношения/групповой PvP и защита; дорожный RT и access cards; Giant Excavator Pit с дизелем/зачисткой/добычей и атаками ограниченного числа rival clans. Нефтянки/карго факультативны. Semantic Pack в самом конце.

**После 007:** если GREEN — первоочередная R1/R2 persistent economy, затем verstaсk/blueprints/research, потом TC/home navigation/respawn, combat и группы. Если PARTIAL — устранить конкретный player-avatar bridge blocker без выкидывания успешных 001–006. Отдельный новый чат/архив для каждой задачи, обязательная проверка ChatGPT публичного GitHub master на каждом отчёте Codex.

**R6 — результат007 PARTIAL, transient held refs при restart (открыт).** Journey доказал native gathering, оплаченный SERVER_ACCOUNTED_CRAFT и crafted UID87251 native-held. Independent restart заблокирован до Load: первый сохранённый held ref81011 разрешается в live entity нового мира; type/ownership UNKNOWN. Exact item/active/held recovery пока NOT_VERIFIED. Следующий отдельный gate должен диагностировать native held save/destroy/rebind lifecycle и выполнить безопасное reconciliation без дублирования Item или изменения чужой entity. Бюджет007 исчерпан тремя стартами; четвёртый не разрешён. Этот blocker не отменяет открытые R1/R2 и не означает production-ready economy.
