# First Home 010 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Выполнение автономное по прямому запросу владельца; промежуточное одобрение плана не требуется.

**Goal:** один оплаченный native 1×1 дом одного ScientistNPC с TC/upkeep, физическим HOME_NAV и независимым graceful restore либо доказанный PARTIAL/BLOCKED на первом непройденном gate.

**Architecture:** расширять существующий test-only avatar/economy путь, сохраняя native inventory/held lifecycle и MapKey+WipeId. Placement только проверенным native API; SERVER_ACCOUNTED_BUILD допустим при полной native structural registration и точной оплате. Отдельный режим `-FirstHome` в существующем безопасном runner вводится только после G1.

**Tech Stack:** установленный Rust/Oxide, C# 7.3, Windows PowerShell 5.1; PEReader `scripts/Inspect-RustApi.cs` без исполнения игровых DLL.

**Spec:** [TASK.md](TASK.md), [GATES.md](GATES.md), [ACCEPTANCE.md](ACCEPTANCE.md).

## Global Constraints

- Baseline HEAD/local/public master: `648fbb1520e25bd1ac1b8f328c6d4d36e2a5641f`, проверено до изменений. Только master; exact-path staging/commit и обычный push origin/master.
- Server/ полностью read-only/ignored/untracked; Rust/Oxide/SteamCMD/updater/owner BAT не запускать и не изменять.
- Нет fake Steam ID, teleport/MovePosition/Warp, бесплатных материалов, отключения decay/коллизий или абсолютных координат карты.
- Не более двух плановых RustDedicated starts: JOURNEY и RESTORE. Третий только после документированного engine defect. Непройденный G0/G1/G2 запрещает live.
- Никакого blind retry после неопределённого consume/spawn; другой world/wipe/missing/foreign TC запрещает rebuild/recredit.
- Существующий физический cache + firewall deny-all + atomic kill-on-close Job Object. Чужие процессы не завершать; при наличии Rust/Steam live блокируется.
- CRASH_ATOMIC 009 остаётся NOT_PROVEN. Исторические результаты/raw 001–009 не переписывать.

## Read-first / reuse-first

Прочитаны root AGENTS/README, все восемь входных документов 010, API_DECISION/RESULT 006–009, LIFE_ROADMAP 003, RustBotsAvatarSurvival, EconomyJournal, runner, cache, safety, firewall, OwnedServerProcess, compile/suite и ближайшие validators. Ancestor/nested AGENTS, csproj/props/targets, code-map/pattern-файлы не найдены.

Локальные аналоги: 008 strict native inventory + transient-held sanitation; 009 world/wipe, native gather, debit-first craft и fail-closed journal; 006 RustNav scheduler/speed rearm и physical trace. Сохранять их контракты и стиль, без нового production слоя.

## Exact public allowlist / bounded exception

Задача явно объединяет один gameplay-сценарий с runner/validator/docs. Bounded exception до **18** public paths, включая восемь переданных документов, а не независимые product families:

1. `docs/agent-tasks/RUST-BOTS-010-FIRST-HOME-TC/README.md`
2. `docs/agent-tasks/RUST-BOTS-010-FIRST-HOME-TC/TASK.md`
3. `docs/agent-tasks/RUST-BOTS-010-FIRST-HOME-TC/GATES.md`
4. `docs/agent-tasks/RUST-BOTS-010-FIRST-HOME-TC/ACCEPTANCE.md`
5. `docs/agent-tasks/RUST-BOTS-010-FIRST-HOME-TC/EVIDENCE.md`
6. `docs/agent-tasks/RUST-BOTS-010-FIRST-HOME-TC/HANDOFF.md`
7. `docs/agent-tasks/RUST-BOTS-010-FIRST-HOME-TC/RISKS.md`
8. `docs/agent-tasks/RUST-BOTS-010-FIRST-HOME-TC/GOAL.txt`
9. `docs/agent-tasks/RUST-BOTS-010-FIRST-HOME-TC/PLAN.md`
10. `docs/agent-tasks/RUST-BOTS-010-FIRST-HOME-TC/API_DECISION.md`
11. `docs/agent-tasks/RUST-BOTS-010-FIRST-HOME-TC/RESULT.md`
12. `src/plugins/RustBotsAvatarSurvival.cs` — только bounded home hooks, если G1 пройден.
13. `src/home/FirstHome.cs` — компактный home adapter/contracts, если G1 пройден.
14. `scripts/FirstHomeValidation.ps1` — независимая проверка, если G1 пройден.
15. `scripts/Test-FirstHome.ps1` — focused contracts, если G1 пройден.
16. `scripts/Invoke-NavigationProbe.ps1` — отдельный FirstHome mode, если G1 пройден.
17. `scripts/Test-PluginCompile.ps1` — включение home source, если G1 пройден.
18. `scripts/Test-All.ps1` — focused home suite, если G1 пройден.

Это максимальная граница, не обязательство менять все пути. Старые EconomyJournal/validators, README/AGENTS, infrastructure/cache/firewall/job вне mutation scope. Если необходим иной путь — сначала уточнить PLAN с конкретным обоснованием; не расширять задачу молча. Raw inspection/IL/hashes/secrets/scripts/receipts только ignored `.local/audit/home010/` и `.local/runtime/`.

## Review Focus

- Native bot ID может не проходить TC authorization/persistence: отказ до материалов, никакого impersonation.
- Native support/socket/permission регистрация обязательна; Spawn одного prefab не доказывает дом.
- Загруженные grade/recipe/upkeep costs и реальные UID debit; partial consume/spawn не повторять.
- Динамическая геометрия может не поддерживаться RustNav; не исправлять teleport/position writes/collision disable.
- Restore требует точного world/save provenance и native disk witnesses; новый occupant/missing entity запрещает mutation.

## Tasks / gates

### 1. G0/G1 — read-only feasibility

- [x] Сверить HEAD/local/public master и исходный scope, Server ignored/untracked.
- [x] Выполнить обязательное чтение и найти локальные аналоги.
- [x] Зафиксировать owner full SHA/length baseline и safety/process/firewall/cache состояние: 3086 файлов; исходно процессы/порты/rules/open leases/locks=0. Проверен полный физический runtime и warm world SHA.
- [x] Независимые STATIC исследования construction/TC и RustNav; сверить installed fingerprints/prefabs/recipes. Записать точные сигнатуры/IL и STATIC/LIVE/UNKNOWN в API_DECISION.
- [ ] При техническом отказе остановиться до gameplay mutation, выполнить существующий Test-All и compile, оформить BLOCKED с точной причиной; не расходовать live budget для неизвестного API.

### 2. G2 — минимальное развитие только после G1

- [x] Сначала focused failing contracts: conservation, double-build/unknown intent, wrong world/foreign TC. Шесть focused групп закрывают различные critical risks, включая arbitrary-source replay, четыре held references и физический portal; это OFFLINE_ONLY.
- [x] Добавить компактный home adapter поверх существующего actor/economy: bounded dynamic site, loaded full budget, натуральные материалы, consume-before-build, structure/TC/upkeep/door ledger.
- [x] Подтвердить каждую используемую API сигнатуру installed C# 7.3 compile; independent validators и Test-All PASS до первого старта. Финальный prelive receipt: `.local/audit/home010/tests-g2.txt`, exit0.

### 3. G3 — headless pair при готовых G0–G2

- [ ] JOURNEY: native gather/payment/build/TC/upkeep, RustNav OUTSIDE→DOOR→INSIDE_TC→OUTSIDE. Raw physical samples/receipts, graceful native save и cleanup.
- [ ] Independent RESTORE: exact native world/home/TC/door, одна логическая личность, original Item UID, 0 harvest/craft/build/credit; повторный HOME_NAV из реальной геометрии.
- [ ] Если engine limitation — сохранить честный PARTIAL. Третий старт только при доказанном исправляемом дефекте с отдельной записью причины.

### 4. Итог / доставка

- [x] Test-All, отдельные mojibake и escaped Cyrillic scans, public privacy/exact-scope audit, full owner after SHA/length, процессы/порты/rules/leases/locks=0.
- [x] Независимое read-only review фактических изменений/evidence; исправить только подтверждённые дефекты в scope.
- [x] RESULT с отдельным статусом каждого gate и непроверенными фактами; exact18-path delivery подготовлена. Actual commit/push/local/tracking/public SHA equality и clean-tree записываются после commit в ignored delivery.json и финальном ответе; собственный SHA в commit не включается.

Новый Goal/Slice не начинать. GREEN_HOME_BOOTSTRAP возможен только по фактической новой live паре; offline fixtures, компиляция и STATIC IL этого не заменяют.

## Решения при исполнении

- Текущий checkout/master используется по прямому указанию владельца; worktree/branch не создаются. Skill-ledger и raw review размещены в `.local/audit/home010/`, как требует TASK.
- Нативный Planner пригоден: альтернативный hand-written Spawn adapter не нужен. Платить второй раз после native DoBuild запрещено.
- Upkeep резервируется консервативно полным Wood construction cost до первого placement; фактические rate/period/minutes обязан подтвердить TC. Никакой выдуманной выдачи из бюджета.
- До live независимое IL/review исправило дополнительный yaw в Target, выбор внешнего roof socket, закрытую дверь перед TC и авторизацию TC до последнего placement. Roof socket выбирается native DoPlacement/CheckSocketMods prediction без Spawn/consume, затем окончательный Planner API.
- Старые 009 validators не ослаблены. Для home каждый source проходит неизменённые проверки 009 в wood+stone pair; отдельная bounded проверка охватывает четыре held items. Новый physical validator связывает портал и события с actual samples/коллизией пола.
- Нативное состояние NPC collider записывается как есть. Roam asset имеет disabled CapsuleCollider; геометрическая clearance-проверка r0.5/h1.8 не является заявлением о rigidbody collision response и не меняет collider.
- Live starts не используются для изучения неизвестных сигнатур. Две sandbox-denied/preflight попытки без PID не считаются RustDedicated starts; повторённый preflight вне sandbox прошёл. Первый настоящий run: `aee154abff86469a8ca15f1c8166e535`.
- Первый run0.2.0 — PARTIAL до home materials,0build; native gather/paid axe и197.790817м реально подтверждены. Все raw сохранены. Offline native-map decode выявил чрезмерный .18м authored flatness gate; engine defect не доказан.
- Ruling: ограничить depth range половиной настоящей foundation глубины и входной перепад0.25м, добавить native foundation preview с planned ray и полный reasons ledger. Не ослаблять воду/дороги/монументы/foreign/collision/permission/native structural gates. Если admission всё ещё пуст — остановиться с честным BLOCKED_SITE; не тратить третий start без требуемого engine defect.
- Второй run0.2.1 `3268a3d257a4470892ec8abf567d3e24` — PARTIAL,340native previews/344complete approaches,0accepted sites,0build. Ни home inventory snapshot, ни TC/door/upkeep/navigation не появились. Current C# source frozen и совпадает с capture. Это повторный JOURNEY; independent RESTORE не проводился.
- Budget gate:2реальных starts использованы; третьего нет, engine defect отсутствует. Полные G3 gameplay/restore пункты остаются **NOT_PROVEN/NOT_CONDUCTED**, не отмечать их passed. BLOCKED_SITE — итог ACCEPTANCE; fixtures/публикация этого не меняют.
- Final safety:21leasesclosed; all process/ports/rules/active locks0. Owner3086files, changes0. Независимое final evidence review подтвердило оба immutable165-record journals, live compile/save/source и отсутствие ложного home claim.
