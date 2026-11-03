# ACCEPTANCE — матрица исхода 005

| Gate | GREEN означает | Доказательства |
|---|---|---|
| Baseline/Code | master и SHA сверены, installed DLL signatures/IL известны | repo ref, `API_DECISION.md`, compile log |
| Real Recipe | recipe data actual runtime; полезный target product и cost известны | blueprint shortname/id, ingredients, amountToCreate, workbench/learned metadata |
| NAV | npc физически двигается к natural resources, continuous samples, path complete, без warp | legs, samples, resource IDs, LOS/range |
| MATERIALS | только natural source debit, real item UID credited once | pool before/after, source provenance, tool wear |
| CRAFT | выполняется один реальный `ItemBlueprint` с exact ingredient debit и созданием exact output UID/amount | before/after inventory, debit receipts, output proof, mechanism label |
| GATE | минимум один фактически недоступный recipe отклонён без изменения имущества | live negative attempt, actual denial reason, inventory diffs=0 |
| PERSIST | отдельный full restart восстановил crafted UID/amount/condition, actor state; не повторил craft | world/snapshot hash, restart receipts, no replay |
| SAFETY | owner не менялся, owned PID/ports/firewall/lease все закрыты | local hashes, cleanup and process/port evidence |
| GIT | публичный коммит только проверенного кода и документов, `origin/master` совпал, `Server/` не опубликован | SHA, exact path git diff, secret/encoding scan |

### Статусы

- **GREEN**: все критические строки таблицы подтверждены live и соответствующими независимыми validators. Режим **SERVER_ACCOUNTED_CRAFT** допускается для GREEN, но ВСЕГДА явно указывается: не native player queue, не визуальная экипировка. Достаточно одного реального негативного gate; отсутствие других gates помечается отдельно.
- **PARTIAL**: реально достигнута часть сценария, но отсутствует positive craft/restart/negative gate. Нельзя скрывать частичный debit/output failure.
- **BLOCKED**: невозможно безопасно провести E2E либо установленный API не допускает валидный рецепт/механизм.
- **FAILED**: нарушение conservation/duplicate, чужая owner мутация, отсутствие bounded cleanup, фальшивые результаты.

`BLUEPRINT_LEARN`, `WORKBENCH_BUILT`, `NATIVE_PLAYER_CRAFTING`, `RESOURCE_POOL_PERSISTED` **не являются** обязательными для GREEN 005 и **не должны заявляться выполненными**, если не были отдельно реально доказаны. Верстаки/blueprints изучаются на уровне API и проверочного отказа по мере доступности, а не декларируются реализованными.
