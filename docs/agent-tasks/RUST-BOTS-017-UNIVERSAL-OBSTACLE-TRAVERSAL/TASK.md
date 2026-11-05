# TASK017 — Universal collision-aware obstacle traversal

## 0. Что именно сделать

Разработать **универсальную** подсистему локального физически корректного движения одного `ScientistNPC : BasePlayer`, совместимую с существующим RustNav, природным миром и настоящими строениями. Новая подсистема должна определять: можно ли безопасно пройти, нужно ли подняться/спуститься по небольшой ступени/склону, как обойти препятствие, когда остановиться, когда native door действительно открыта. Она должна быть пригодна для переиспользования всем будущим населением 50–100 NPC, а не привязана к prefab/координатам одного дверного порога.

**Текущий blocker:** 016: native path complete, but own doorway mesh19.329mm + own foundation edge0.112mm at real capsule, feet≈274mm below forward foundation, kinematic/gravity-off agent. No after-contact evolution proven, cannot mark existing house traversable. Do NOT flip `Clear` or exclude `foundation` globally.

## 1. Native audit + архитектурный выбор (до live)

- Полностью прочесть AGENTS/HANDOFF/PHYSICS/ARCHITECTURE/DECISION_GATE/старые 014–016 RESULT/API и исходники `RustBotsAvatarSurvival.cs`/`FirstHome.cs`. Установленные `Assembly-CSharp`/Oxide/Unity/possible `BaseNavigator`, `NPCPlayerNavigator`, `RustNavMeshAgent`, native motion, ground, gravity, physics sweep/CharacterController/step handling: IL/signatures, real prefab components. Do not assume online wiki versions match installed.
- Выбрать кандидата natively supported collision-aware full-body motion; изучить, что делает RustNav transform sync (`updatePosition`, `updateRotation`, `nextPositionWS`, Rigidbody kinematic), как и кем может меняться вертикальная координата. При отсутствии встроенного solver — спроектировать physics-aware local mover со строгим пробным контролем; не писать свой high-level global pathfinder.
- Документировать сравнение вариантов в `API_DECISION.md` с `STATIC_IL`, `OFFLINE_ONLY`, `LIVE_PROVEN`, `UNKNOWN`. Если изменение фундаментального способа движения или замена player-derived actor нужна — применить DECISION_GATE, **предложить варианты владельцу до реализации**. Нельзя автоматически брать самый лёгкий implementation path вместо выбранной реалистичности.

## 2. Reusable runtime implementation

- Выделить общий `ObstacleTraversal`/`LocalMove` в `src/navigation/...` или аналогичный узкий reusable модуль; новый класс/partial integration должен работать в combined Oxide C#7.3 runner без сторонних NuGet. Не привязывать к `homeEntities`, `homeStep`, foundation local coords, test map seed, known netIds. `FirstHome` uses shared mover, outdoor gather/roam route can use same interface. Не копировать большую проверку коллизий в два места.
- Разделить `route valid`, `surface support`, `obstacle classification`, `safe locomotion`, `actual observed outcome`, `repath/blocked` и обеспечить fail-closed при `UNKNOWN`/nonfinite/owner violations. Bound local lookahead and replans, invalidate cached surface data при изменениях Doors/BuildingBlocks/nav tiles.
- Сохранить native actor, inventory/held/economy and guest/own rights. Отдельный `Door` interaction only through native access, range, LOS, unlocked, own authentication; чужая/закрытая без разрешения — обойти или отказать. Никакого `Physics.IgnoreCollision`, уменьшения NPC, вручную зашитых координат или walls clipping.
- Implement **one** general physically supported step/height-delta crossing, **one** slope/down/support case, **one** actual obstacle avoidance/blocked. If installed engine provides no safe physics mover, don't fabricate GREEN; record supported architectural options and ask owner, but include maximally useful shared probes/real tests.
- Тесты с негативными фикстурами: repeated tick collisions, wall vs step same 1–20mm depth, own foundation side wall, closed/open door hinge, unsupported gap, unsafe drop, non-Player impostor, invalid map/world/speed, native fail returns. Ensure runtime source never inherits diagnostic permissive bypass.

## 3. Live E2E — несколько разных препятствий, не только старый порог

- Codex самостоятельно запускает isolating RustDedicated. Разумный бюджет **до 3 live starts всего**. Первый `TRAVERSAL_BENCH` должен по возможности содержать последовательно: (A) натуральный рельеф/уклон или небольшую ступень вне дома; (B) native paid diagnostic wood foundation/doorway+door+TC, real height change and inside→outside; (C) настоящую непроходимую стену или закрытую дверь с bounded detour/`BLOCKED`, не `PathComplete` fabrication. Все в одной физической test world copy с fixture-paid construction; raw marker TEST_FIXTURE, no promotion. No need to farm 3760 wood here.
- Если одна сцена не даёт трёх независимых классов, использовать второй запуск для **другой** native surface/obstacle, а не дублировать 1×1 без новых возможностей; третий только при обоснованном конкретном дефекте, с review. Один тест не должен бесконечно выбирать site. No hardcoded absolute map coords; site discovered from current map and installed rules; fixture seed may remain fixed only in runner.
- Все действия по физике должны быть доказаны continuous real actor pose/velocity, full capsule sweep/overlap, native support/ground+rise/drop, contact resolution, native door state/collision. Если NPC доходит до координаты сквозь стену (kinematic clip), это **FAIL**, не GREEN, независимо от PathComplete.
- Don't call **task** GREEN only for static API, offline fixture, native door placement, or calculated path. Подробные statuses отдельно по типам препятствий и времени. Если безопасный реалистичный mover не найден, закончить `PARTIAL/ARCHITECTURE_DECISION_REQUIRED` с вариантами для владельца, а не делать новый костыль.

## 4. Bounded scope и следующий этап

**НЕ входит:** натуральный сбор 3760 wood на дом, независимый home RESTORE 008/009, 50–100 live bots, PvP, raids, sleeping bags, GIANT Excavator, workbench research. После `GREEN_TRAVERSAL_CORE` можно поставить 018 на честный NATURAL HOME JOURNEY + independent RESTORE, затем применять core к миру/дорогам/базам. Это не регресс продуктовой цели, а самостоятельная системная основа.

## 5. Safety, report and commit

- Всегда `Server/` read-only/ignored, owner worlds/config/mods, SteamCMD/update/owner BAT не трогать, чужие Rust/Steam процессы блокируют live, их не убивать. Физически отдельный runtime, no writable links, own Job Object + firewall inbound/outbound, leased ports/broker, test-only creds, graceful quit and bounded finally cleanup. 0 own processes, TCP/UDP, firewall rules, locks, brokers when finished.
- Preserve previous PARTIAL/RESULT 001–016, raw local only in `.local/`, no rewrite history, no exposed secrets. source C#7.3/PS5.1; Test-All PASS, installed compiler/Oxide live, independent source+raw review, UTF8/NUL, mojibake+escaped Cyrillic **separately**, secret scan exact changed paths.
- Git within explicit permission this task: read local/tracking/public HEAD, exact-path allowlist/staging, commit+ordinary nonforce `git push origin master`, verify public SHA/clean tree; never reset/rebase/stash/clean/force/broad add. Do not stage `Server/`, `.local/`, artifacts. Plan and RESULT must identify all live counts and out-of-scope limitations.
- Reports: `PLAN.md` (decisions/allowlist), `API_DECISION.md` (installed native evidence), `DECISION.md` if discussed with owner, `RESULT.md` (matrix live by obstacle class & safety). No promises of background work.
