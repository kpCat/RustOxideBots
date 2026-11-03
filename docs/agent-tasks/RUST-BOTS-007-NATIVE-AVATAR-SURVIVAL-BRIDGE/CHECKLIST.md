# CHECKLIST — компактная последовательность для Codex

- [ ] Pinned SHA / `master` / рабочее дерево / `AGENTS.md` и существующие proofs прочитаны.
- [ ] Native API/IL решение записано **до** первого live: actor lifecycle, inventory/held, gather, crafting, snapshot.
- [ ] Создан ограниченный bridge без копирования всех старых 500+ строк; старые modes/tests работают.
- [ ] Offline compile/validators/negative fixtures PASS до запуска.
- [ ] Реальный test run 1: Player-derived avatar → starter kit → RustNav → natural wood/stones → debit/pay → crafted stonehatchet → exact new UID held in native belt.
- [ ] Тестовые процессы и broker закрыты, world/native save completed, доказан snapshot binding.
- [ ] Реальный test run 2: independent restore в том же compatible test world; логическая identity, native item UID/condition, slot и active crafted held равны, нет повторного material/kit/craft awards.
- [ ] Любой 3-й E2E — только по реальному defect с описанием, не для косметики.
- [ ] Source depletion durability и crash journal открыто отмечены как `NOT_IMPLEMENTED` (если не реализованы действительно), не прятать проблемы за GREEN.
- [ ] Ревью raw receipts, финальный Test-All и owner SHA, zero owned processes/ports/firewall rules/locks.
- [ ] Публичные изменения только exact allowlist, без secrets/Server; UTF-8, отдельные mojibake+escaped Cyrillic проверки.
- [ ] RESULT+API_DECISION, exact-path commit, fast-forward push, remote SHA и чистый status.
