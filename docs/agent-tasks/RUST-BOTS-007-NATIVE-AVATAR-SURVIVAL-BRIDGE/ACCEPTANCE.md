# ACCEPTANCE — что считается настоящим результатом 007

| Gate | GREEN (LIVE) | Что нельзя подменять |
|---|---|---|
| AVATAR | Один и тот же живой `ScientistNPC : BasePlayer`, без connection/Steam impersonation, native RustNav, валидный native PlayerInventory | Два персонажа с разными ролью и инвентарём — не один avatar |
| START_KIT | Native default Scientist loadout нормально снят или безопасно отключен **до** игровой добычи; тестовый старт явно содержит только допустимые starter вещи; все изменения account | Бесплатный MP5/костюм нельзя выдавать за добычу/крафт |
| NAV | Путь до **двух natural resource nodes**, continuous physical samples, complete-path legs, реальное расстояние, без warp; resetPath speed fix повторён | PathExists без движения не GREEN |
| GATHER | Фактическое уменьшение source pool и рост **native PlayerInventory** на 200 wood+100 stones (или actual recipe cost), настоящие UID; negative native yield/double-credit checks | Создать Item при неизменном pool нельзя |
| CRAFT | Loaded actual `stonehatchet` recipe; точные native debit UID/amount и **новый crafted UID** в inventory; как минимум missing-gate и duplicate-intent no-op | Использовать старый UID 65008 / fixture stonehatchet нельзя |
| EQUIP | Сам crafted stonehatchet в belt; `GetActiveItem().uid` = craftedUID; native HeldEntity `BaseMelee` с parent/owner этого же BasePlayer; до финиша не исчезает | `ItemContainer` со словами «экипирован» не считается |
| RESTART | Второй независимый RustDedicated с hash-verified original world/generation/actor snapshot; real UID/amount/condition/container slot и active/held нового native actor восстановлены; нет повторного kit/harvest/craft | Упрощённая выдача нового идентичного топора не GREEN |
| NEGATIVE | Запрет missing/foreign UID и отсутствующего рецепта; непригодное snapshot/world mismatch не меняет имущество; duplicate intent не создаёт output | Offline test не заменяет live core evidence |
| SAFETY | Owner hash unchanged, process/ports/firewall/lease cleanup после **каждого** live-run | `Server/` в git или orphan Rust process → FAILED |
| TEST/GIT | Все старые 001–006 тесты PASS, installed DLL offline compile, live Oxide load, exact-path commit и fast-forward push в master; UTF-8/secret scans | «Проверен код» не равно live execution |

**GREEN_AVATAR_SURVIVAL**: подтверждены все критические live пункты AVATAR, START_KIT, NAV, GATHER, CRAFT, EQUIP, RESTART и SAFETY. NEGATIVE включает минимум один live guard отказ до мутации плюс offline invalid-snapshot fixtures. GAMEPLAY_MECHANISM всегда явный — `NATIVE_PLAYER_GATHER` либо `SERVER_ACCOUNTED_TOOL`, `NATIVE_PLAYER_CRAFT` либо `SERVER_ACCOUNTED_CRAFT`; допускается accounted реализация, но нельзя называть её native player behavior. Текущий активный предмет — **именно оплаченный/скрафченный**, не test fixture.

**PARTIAL:** есть фактическое движение/добыча/крафт/экипировка, но отсутствует хотя бы один обязательный gate или real restart. Сохранить положительный evidence и точный blocker; НЕ подделывать success.

**BLOCKED:** невозможно безопасно выполнить live либо actor/API навсегда препятствует подтверждению сценария при текущей сборке.

**FAILED:** нарушен ресурсный баланс, чужой owner server изменён, удвоены предметы, есть orphan processes/rules или ложная квалификация доказательств.

PERSISTENT_WORLD_SOURCE_POOLS, CRASH_ATOMIC_CRAFT, PLAYER_RENDERED_ANIMATION, RAIDS/PVP/CLANS, REAL_STEAM_SESSION, PRODUCTION_50_100 — строго вне GREEN 007, перечислить в рисках/результате как `NOT_IMPLEMENTED` или `NOT_VERIFIED`.
