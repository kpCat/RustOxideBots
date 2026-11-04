# HANDOFF — факты и ограничения, известные до 010

## Git и инфраструктура

- Публичный `https://github.com/kpCat/RustOxideBots`, local `D:\Codex\repos\RustOxideBots`, master. **Фактически проверенный GitHub baseline 009:** `648fbb1520e25bd1ac1b8f328c6d4d36e2a5641f`. Три commits 009: a5f7413, 2b58704, 648fbb1. Проверить актуальное состояние; не делать reset/rebase/force.
- `Server/` — приватная локальная папка RustDedicated/Oxide, 6+ GB, целиком ignored; owner solo world/config/plugins/read-only. `Server/Run_DS.bat`, `Server/update.bat`, SteamCMD и updater002 не запускать. Не менять owner мир или третьесторонние плагины.
- Self-run harness: `scripts/Invoke-NavigationProbe.ps1` PS5.1, `ProbeCache.ps1`, `ProbeFirewall.ps1`, `OwnedServerProcess.cs` atomic Job Object, UAC firewall helper, separate test identity/map and world. `Test-All.ps1`; real start/stop Codex сам. No foreign processes allowed. Normal observed quit exit -1 can be graceful with ACK/native save.

## Verified gameplay progression

- `001`: Gen2 + RustNav, 92.21m, warm map/nav cache.
- `003`: one Gen2 413.58m, natural barrel, native crate **fixture**, inventory UID persistence.
- `004`: Gen2 natural wood/stones with accounted tool, native source pool debits.
- `005`: Gen2 paid loaded stonehatchet recipe, SERVER_ACCOUNTED_CRAFT, inventory restore.
- `006`: `ScientistNPC : NPCPlayer : BasePlayer`, real native PlayerInventory/belt/active/HeldEntity, 93.70m via RustNav, native speed rearm after ResetPath.
- `007`: natural NATIVE_PLAYER_GATHER wood/stones; paid accounted stonehatchet; exact crafted UID native held; restart PARTIAL originally.
- `008`: native PlayerInventory restored 4 original Item UIDs and crafted held with safe transient heldEntity ref sanitation; original PARTIAL 007 preserved.
- `009`: current plugin `src/plugins/RustBotsAvatarSurvival.cs` + `src/economy/EconomyJournal.cs`: **GREEN_WORLD_DEPLETION** graceful pair — tree500→100, ore750→536, replay NOOP/NOOP; 201.84m/291 samples; 200 wood+107 stones, paid stonehatchet; 165 immutable journal records, exact actor and inventory, two independent RustDedicated. First two PARTIAL 009 retained; last two GREEN. `CRASH_ATOMIC=NOT_PROVEN`, `MULTI_MAP_E2E=NOT_CONDUCTED`.

## Map-independent design

009 now separates `MapKey` (kind/level/seed/size/format/actual map SHA) + `SaveRestore.WipeId` WorldKey from changing `.sav` SHA and generation. Resource node matching uses saved fromDisk witness, prefab/type/position/rotation/scale/bounds/startAmount/health with 1:1 candidates; incomplete/ambiguous/respawn mismatches fail closed. Current `seed424242/worldsize2000` are test fixture, not production coordinates. Preserve this design for HOME world-owned state; do not transfer ownership across wipes.

## Why first home now

The owner wants humanlike 50–100 NPCs who spawn naked, roam, gather, craft, inhabit homes determined by real TC/building entities, pay upkeep, own boxes/workbenches/doors, place sleeping bags, respawn after death, recover/rebuild after TC raids, form gangs and fight; Giant Excavator later, oil rigs/cargo optional, Semantic Pack late. This task is first 1x1 native home with TC, door, upkeep and local movement. Explicitly **not yet** respawn/raid/blueprint tech tree/clans. Need genuine gameplay progress instead of infinite infrastructure tasks.

## Code hotspots

- `src/plugins/RustBotsAvatarSurvival.cs` 009: BasePlayer avatar, natural gather, accounted crafting, ledger/state/native held and restore; do not fork 1000 lines without necessity.
- `src/economy/EconomyJournal.cs` BCL-only append helper (included into isolated plugin source by runner), currently journal records GATHER/CRAFT only; extending kind requires explicit versioned compat and tests. Avoid editing history.
- `scripts/AvatarSurvivalValidation.ps1`, `EconomyValidation.ps1`, `Test-AvatarSurvival.ps1`, `Test-Economy.ps1`, runner startup/restore flags; maintain legacy tests.
- `docs/agent-tasks/RUST-BOTS-003-WORLD-ROAM-LOOT/LIFE_ROADMAP.md`, `docs/agent-tasks/RUST-BOTS-009-WORLD-ECONOMY-PERSISTENCE/RESULT.md`, `API_DECISION.md`, `RISKS.md` — read-first.

## Known limitations

- Existing Roam prefab lacks ItemCrafter: reported `SERVER_ACCOUNTED_CRAFT`, not native queue. No client animation verification.
- 009 crash atomicity and recovery after real abrupt process stop are NOT_PROVEN; fail-closed IN_DOUBT is preferable to double credit. 010 may use graceful save/restores only, cannot declare production economy.
- 009 live node identity proof only same save and same map; multiple maps tests offline. Building site must be fully dynamic on current map.
- Rust building/TC native API for NPC not yet demonstrated. 010 API gate must discover it before making any claims.
