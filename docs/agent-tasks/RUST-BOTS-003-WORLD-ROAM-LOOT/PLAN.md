# План 003

Спецификация: TASK.md и ACCEPTANCE.md. Baseline master: b4a2c6f17e3a23c5cdb78e02c422a82fb8eb368d; origin/master совпал при read-only проверке. Пользователь явно поручил самостоятельное исполнение без промежуточных согласований.

Выбран отдельный test-only RustBotsWorldRoam поверх runner 001. Gen2 + native ItemContainer сохраняет доказанную навигацию; перевод на NPCPlayer/PlayerInventory потребовал бы другой навигации и проверки неподтверждённой player-семантики. Production AI, updater 002 и owner runtime вне scope.

- [x] API: прочитать metadata/IL текущих DLL без исполнения; описать дороги, prefab discovery, damage/drop, native transfer и protobuf persistence в API_FEASIBILITY.md.
- [x] Контракты: focused PS validator tests для реконструкции физического пути, source/destination conservation и persistence; сначала увидеть отказ без validator.
- [x] Реализация: отдельный Oxide probe, флаг WorldRoam существующего runner, сохранение native protobuf перед shutdown и restore-only второй запуск; regression 001 не менять.
- [x] Проверка: C# 7.3, Test-All, два extended headless E2E, второй с restart proof и исправлением fixture. Bounded stuck/repath, native drops, UID/amount, cleanup и owner fingerprint проверены.
- Доставка: статусы и фактические метрики находятся в RESULT; exact allowlist/UTF-8/секреты/Server ignore проверяются перед staging. После commit и обычного push master финальная сверка SHA сохраняется отдельным delivery receipt и сообщается в финальном ответе.

Общий интерфейс: runner выбирает plugin/result по режиму, JSON содержит Legs/Samples/Transfers/Inventory; независимый validator пересчитывает расстояния и баланс. Старый режим 001 сохраняет свой validator. Restore-only получает только завершённый protobuf snapshot и receipt предыдущего clean isolated run, без повторной выдачи лута.

Проверяемые риски: ложная сумма пути при discontinuity; road arrival без геометрии дороги; remote/blocked item transfer; merge stack/duplicate UID; неполное восстановление или cleanup. Fixture tests не являются live evidence.

Bounded exception к 8–10 файлам: один связанный сценарий требует plugin, runner, validator, focused tests, compile/test registration, README и трёх отчётов; плюс семь неизменённых предоставленных task-файлов. Других подсистем нет. Исторические evidence не переписывать, кеш/логи не удалять.

## Решения и review

- Ruling: исполнение в текущем master без нового worktree — прямое указание пользователя; чужие изменения не обнаружены, исходный пакет 003 сохранён.
- Ruling: native ItemContainer вместо смены Gen2 на BasePlayer — сохранение доказанного RustNav; цена: нет штатной визуальной player equipment/crafting/Steam session.
- Ruling: после первого live невидимый native crate fixture не принимается за обычный ящик. Фильтр исключает modding/invisible; второй и заключительный запуск использует `-RestoreFrom <first-run> -ResumeJourney`, чтобы одновременно проверить persistence и исправленный сценарий. Это обоснованный повтор, не бесконечный retry.
- Read-only reviewer выявил недостаточные geometry/part/provenance checks; RED fixtures воспроизвели ложное принятие. Один fix pass добавил точный road sample/leg/projection contract, независимые GREEN parts и exact-save binding; failed raw JSON сохраняется в своём run, FAILED не продвигается в кеш.
- При native drop mismatch статус BARREL остаётся PARTIAL; уже доказанный crate inventory сохраняется независимо. Transfer anomalies не скрываются.
- Final review: один независимый read-only reviewer; live facts, сохранность owner и shutdown проверяет основной агент по raw receipts. Deferred minor findings отсутствуют.
