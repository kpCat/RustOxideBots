# Известный измеренный контакт 014 — не предположения

Источник: уже опубликованные `docs/agent-tasks/RUST-BOTS-014-HOME-EXIT-COLLISION/RESULT.md` и `API_DECISION.md`, actual GitHub commit `ed25505e3e829af563243d242e2c3fc5729027f4`. Эти факты — **результат чужого live-теста**, а не текущий тест Codex 015.

- Smoke 014: `508c7d34b98149d49498d25e99efd495`, один native `ScientistNPC : BasePlayer`, test-only Wood/Twig home built by genuine `Planner.DoBuild`; оплаченные Wood upgrades, TC, дверь, перенесённый в TC wood upkeep.
- На первом *inbound* crossing candidate (а НЕ на выходе), время игрового tick **335.5896 s**, `HomePhysicalSample` получил три `OverlapCapsule` коллайдера: own `DOORWAY` MeshCollider, own `FOUNDATION`, `NPC_SELF`.
- Body: физический `CapsuleCollider` `radius=0.5 m`, `height=1.8 m`, center `(0,0.9,0)`, Y-axis, scale 1; RustNav agent height отдельно 2.0 m. Не уменьшать и не подменять размеры.
- `DOORWAY` collider entity **146674**, MeshCollider native intersection **0.0112793455 m** (11.279 мм), native minimum translation direction `(0.280285656,0.9598528,0.0110628344)` — преимущественно вверх. Установленная сетка `wall.doorway.collision` содержит 74 vertices; crest примерно **30.900 мм** выше feet. Это **реальная пенетрация**, не доказанный false positive.
- `FOUNDATION` own support contact 0.00225684 m; floor ray normal up, floor **2.257 мм выше feet**. Door open, его hinge collider не входил в конфликтный набор. Native `IsOnGround=true`, RustNav current+recalculated `PathComplete`, tiles not pending.
- Nominal inbound portal halfwidth 0.6000002m, modeled required halfwidth 0.5766688m (боковой запас всего ~23.3 мм на измеренном кандидате). `CROSSING_CANDIDATE` не является принятым `CROSSED_IN`.
- Смоук 013 прошёл внутрь до TC, но столкнулся на *outbound* участке; collider его исторического outbound tick **UNKNOWN**, потому что он не был записан. 014 не заполняет задним числом этот пробел.
- Smoke 014 завершился `PARTIAL/COLLIDER_IDENTIFIED`. NATURAL/RESTORE не запускались. Test-All PASS, owner `Server/` 3086 файлов без изменений, isolated no promotion.

**Важная развилка**: нужно исследовать как штатный NPC/RustNav преодолевает низкие пороги и насколько краевая траектория провоцирует penetration. Нельзя просто объявить все own doorway overlaps допустимыми или ослабить условие до `depth < 0.02`: реальные столкновения сохраняют статус BLOCKING, пока установленное поведение native движения и корректное сопровождение контактов не доказаны. Граница *физическая*, а не только геометрия OBB.
