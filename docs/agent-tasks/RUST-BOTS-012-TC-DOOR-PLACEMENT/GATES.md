# GATES / критерии перехода к следующему запуску

## G0 — безопасность и baseline

Проверить local HEAD/master, public origin/master и нет чужих изменений. Baseline `610937733286263b83c2f70577ec629ecd482b3a`. Root AGENTS, 010/011 RESULT и исходники прочитаны. Все owner world/mod/config/BAT read-only. `Server/` полностью ignored, raw `.local/` only. Убедиться, что иностранные Rust/SteamCMD процессы блокируют startup.

## G1 — до любого дорогого live PID

- Разобраны installed DLL IL, TC prefab и target geometry. Offine C#7.3 compile + Test-All PASS. Независимый review применимых branch/permission/structure guards.
- Non-mutating diagnostics TC и capture Phrase/errors реализованы там, где это действительно позволяет installed API. Не подменять логи.
- Smoke no-promotion, physical world fork, safe firewall Job Object, проверки marker/identity/ports/owned cleanup неизменны.

## G2 — первый native smoke (самый важный)

- Хотя бы один ПОДЛИННЫЙ native `BuildingPrivlidge` в owned structural building с одной попытки после verified no-op previews, оплаченный реальным fixture Item; named `TC` true.
- Native authorization `IsAuthed`, `CanBuild`, защита >=60мин через реальные item transfers; complete doorway + настоящий Door, native opening/collision and physical crossing.
- Каждый gate свой: `TC_PLACEMENT`, `TC_AUTH`, `UPKEEP`, `DOOR`, `HOME_NAV`. При любом failure — raw proof/PI, **не запускать NATURAL**. Smoke status diagnostic-only. Не обходить engine guard.

## G3 — natural full journey (условно)

Только если G2 GREEN_SMOKE и независимые validators прошли; не приступать, если TC поставлен, но UPC/DOOR/HOME_NAV сломан. Натуральный расход должен быть оплаченный: no fixture. Planner/TC/HOME path все успешно проверены как собственные native игровые entity; bounded background.

## G4 — independent RESTORE (условно)

Только если G3 создал Completed valid home+actor+item/economy journal+world snapshots, game quit GRACEFUL, immutable proof. Нет HOME snapshot — no RESTORE call, не расходовать запуск. Не выдавать новых Items/строений. New bot native ID допускается только с защищённым rebind.

## Итог

- `GREEN_HOME_BOOTSTRAP` только G2+G3+G4 живыми испытаниями.
- `SMOKE_GREEN / DIAGNOSTIC_ONLY` при G2 pass без natural+restore — честный промежуточный результат.
- `PARTIAL` при хотя бы некотором live прогрессе с невыполненными критическими gates. `BLOCKED` когда безопасной проверки нет; `FAILED` при owner mutations, dupes, fake evidence, orphan processes.
- Бюджет 3 owned server starts максимум, не 3 на каждый gate. Перезапуск одной и той же пробы не бесплатен.
