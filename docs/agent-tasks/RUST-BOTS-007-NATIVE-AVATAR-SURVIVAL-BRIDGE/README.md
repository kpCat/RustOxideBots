# RUST-BOTS-007 — Native Avatar Survival Bridge

**Новая, самостоятельная задача для НОВОГО диалога Codex. Thinking: HIGH.**

- База репозитория: `D:\Codex\repos\RustOxideBots`, `master`, публичный `https://github.com/kpCat/RustOxideBots`.
- Pinned baseline при постановке: `6834429b2c6b85e896f3b7dfdb9eaaae370fffb2`.
- Пользователь распаковывает этот ZIP **в корень репозитория** с сохранением путей; файлы попадают в `docs/agent-tasks/RUST-BOTS-007-NATIVE-AVATAR-SURVIVAL-BRIDGE/`.
- Перед выполнением изучить `TASK.md`, `ACCEPTANCE.md`, `API_GATE.md`, `HANDOFF.md`, `EVIDENCE.md`, `RISK_REGISTER.md` и корневой `AGENTS.md`.
- Запуск: в новом чате Codex команда из `GOAL.txt` (уровень High). Никаких ручных PowerShell-команд владельцу.

**Итоговый результат:** один **и тот же** живой игрокоподобный NPC, наследующий BasePlayer, сам ходит, добывает wood/stones, честно крафтит stonehatchet, переносит его в native belt и активирует его через native `GetHeldEntity`. После полного restart восстановлены настоящие предметные UID, состояние и выбор активного топора. Если какой-то этап недоступен, честный PARTIAL/BLOCKED, без ломания проверенных 001/003/004/005/006.

Не путать: LIVE GREEN в 006 доказал игрокоподобный NPC с **тестовым** rock, но не совместную работу его экипировки с экономикой и не persistence. 007 — целевой мост к этой связке.
