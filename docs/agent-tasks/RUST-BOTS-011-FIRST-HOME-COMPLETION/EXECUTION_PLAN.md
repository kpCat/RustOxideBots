# EXECUTION PLAN — как не повторить 010

## Почему предыдущая последовательность неоптимальна

010 4-й run: 488 ударов → 3763wood, elapsed gameplay989.5с; нужен был site path153.46м плюс building, upkeep, home-nav. Доступный gameplay time110.5с меньше reserve120с ещё **до реального пути**. Код вернул обобщённое «site changed» вместо точного TIME_BUDGET и не сделал ни одного `Planner.DoBuild`. Следовательно пятый условный `RESTORE` был логически неприменим.

## Рекомендуемый порядок Codex

1. Проверить текущие источники и весь home pipeline; вычислить реальные затраты и фазовый бюджет, в первую очередь критические native API вызовы. Добавить offline negative checks для time reserve and no fixture leakage.
2. Подготовить отдельный test-only smoke path. После общего `Test-All` одна автономная физическая тестовая установка. Ранний native foundation + full 1x1/TC/door/home nav из обозначенного fixture, exact native debit. Если не получилось — анализировать **конкретную** native ошибку, не отправлять NPC фармить ещё 3700wood без доказательства building path.
3. Только если smoke подтвердил native feasibility, один полноценный NATURAL fresh JOURNEY. Выбрать площадку первой, прочесть cost/condition/time. Порядок `discover → gather → paid tools → travel → build → TC/upkeep → door → home-nav → save`; `time_budget` отдельно от `site_geometry`.
4. Только если JOURNEY complete и clean native save, независимый HOME RESTORE. Заявить GREEN лишь после native proof; если independent restart нельзя проверить безопасно, не выдавать world save за proof.
5. Финальный аудит Git/cleanup/encoding/secret/report. Максимум3 реальных live starts и ни одного сверх — эти старты относятся только к новой 011 и не являются продолжением истёкшего 010.

## Длительность — bounded, не «вечный таймер»

Plugin 010 `1100s` и runner `-NavigationTimeoutSeconds 1200` доказанно недостаточны. Нужны отдельные ограничения per phase, основанные на фактическом измерении 010. Например, если стоимость останется 3760 wood: сбор~990с + planned route~81с + builder TC/door+rebuild ~180–300с + резерв на NavMesh и подтверждение ≈300с → 1550–1700с с запасом. Обоснованный global FIRST_HOME cap в диапазоне 1800–2100с и runner cap 2100–2400с подходит для проверки; конкретные значения выбирает Codex после анализа расходов, а не магически без ограничений. Вынести constants в диагностическую спецификацию, не распространять на другие сценарии.

Если native расчет upkeep уменьшит только необязательный резерв (но не стоимость строительства и не фактическое покрытие >=60мин), можно уменьшить farm target и улучшить вероятность завершения. Источник цен — actual runtime ItemBlueprint/Construction Grade и native cupboard accounting, а не hard-coded whitepaper.

Для diagnostic smoke принципиально запретить продвижение fixture world generation в shared trusted cache. Только индивидуальная копия мира и собственные writable state; no auto copy-back to owner. Экономика smoke изолирована, без retry intent в NATURAL run.
