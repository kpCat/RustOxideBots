# Architecture decision 006

**Choose the installed player-derived ScientistNPC as a viable candidate for the next bounded avatar bridge.** Corrected live run 1f413b585dde4380ac361dc3c965c9af proves native inventory/held ownership and 93.69549 m of physical RustNav movement on the same actor without a connection. Three transitions, real UID guard negatives and cleanup pass. First PARTIAL and its diagnosis remain in RESULT.md; no synthetic combination of different actors or tests is used.

| Option | Decision and reason |
|---|---|
| Player-derived ScientistNPC avatar | LIVE_PROVEN technical candidate in this bounded gate. Existing prefab has genuine native player inventory and held ownership without a Steam connection. No player ID or equipment prop emulation is needed. Next bridge remains a separate task, not an automatic migration. |
| Existing Gen2 plus honest adapters | Preserve current 001/003/004/005 implementation unchanged. It remains the proven accounted economy/navigation baseline; it is not PlayerInventory or native equipment. |
| Visual or dual-avatar bridge | Defer. No need to combine two independent actors to fake one gate; synchronization, collision, ownership and persistence risks remain unsolved. |

Next work must be a separate task: compact bridge for logical identity and existing validated economy to one native player-derived avatar, with regression proof rather than broad migration. Native held activation does not establish gathering, firing, crafting queue, blueprint learning, PvP or client presentation. Test those separately before claiming them.

Native arrival and brain lifecycle need explicit ownership: isolate the actor's AI scheduler and zone sleep registration, preserve raw path completion/consumption semantics, restore desired speed for every new destination. Persistence must distinguish an inventory snapshot and reconstructed logical avatar from a continuously saved player entity. No such restoration is proven here.

Before persistent production economy, retain the separate world-keyed source-depletion/crash-safe debit/craft requirement from 004/005. Do not advertise durable resource pools or crash-atomic crafting based on avatar success. No next goal or production implementation is started in 006.
