# 011 — результат 04.11.2026

Итог: **PARTIAL / DIAGNOSTIC_BUILD_ONLY / BUILD_PLACEMENT_TC**. Один изолированный BUILD_SMOKE подтвердил настоящий `Planner.DoBuild`, native оплату и Wood upgrade шести структурных блоков. Седьмой вызов для TC вернул `null`, `Construction.lastPlacementErrorDebug` был пуст. Повторной попытки и дорогого натурального фарма не было.

**BUILD_SMOKE_GREEN не достигнут. GREEN_HOME_BOOTSTRAP не заявляется.** NATURAL JOURNEY и независимый HOME RESTORE не проводились: обязательный предшествующий gate не пройден. Оставшиеся два игровых старта не использованы; они условно предназначены для JOURNEY/RESTORE, а не повторного smoke.

## Статусы и границы доказательства

| Подсистема / gate | Статус | Факт |
|---|---|---|
| G0 baseline/privacy | Проверено | Local/public master совпали с baseline; owner read-only, исторический PARTIAL010 сохранён |
| G1 installed API / offline | Проверено до PID | Installed fingerprints совпали с исследованными DLL, C#7.3 compile и Test-All PASS; независимое review |
| Actor / outdoor RustNav | LIVE, diagnostic | Один ScientistNPC : BasePlayer, native inventory/held; 107.874908м,115 samples, manual position writes0 |
| Структурное строительство | LIVE, fixture-paid | Foundation,3walls,doorway,roof;6возвращённых BuildingBlock, Wood/250health, один buildingID, native registration/support/links |
| G2 полный builder smoke | PARTIAL / BLOCKED_TC | 7реальных DoBuild calls,6успешных, TC=null;8элементов не достигнуты |
| Door / TC auth / upkeep / HOME_NAV | NOT_PROVEN | Есть оплаченные Item двери/TC, но TC placement отказал; дверь как native entity не размещалась, home traversal не выполнялся |
| NATURAL economy 011 / G3 | NOT_CONDUCTED | 0harvest, только явно выданная TEST_FIXTURE; натуральный сценарий не запускался |
| Independent home restore / G4 | NOT_CONDUCTED | Нет completed home checkpoint; native world save не выдаётся за оплаченный home restore |
| Schedule | OFFLINE + bounded smoke | FirstHome2100/runner2400, разные path/time причины; full989.5s gather с новым профилем не проверялся live |
| Safety / cache / история | Проверено после smoke | Owner3086changes0;118protected cache/history files changes0; promotion=false; cleanup0 |
| G5 delivery | Проверки выполнены | Test-All, source/raw review, scope/encoding/privacy; commit/push и SHA проверяются отдельным delivery receipt |

G3/G4 остаются **required**, а не passed. Прогресс smoke не заменяет acceptance полноценного оплаченного дома.

## Что изменено и почему

Переиспользованы существующие `FirstHome`, player-avatar/economy adapter, debit-first home ledger, runner, cache copy и validators. Новый framework, другой стек и прямой Spawn готового дома не добавлялись.

- `src/home/FirstHome.cs`: отдельный test-only fixture path, per-phase telemetry и native placement receipts; разные NAV_PATH/TRAVEL_BUDGET/TIME_BUDGET; точный отказ admission вместо общей «site changed». TC stand физически приближен перед открытым doorway с сохранением native4m/LOS/permission checks.
- `src/plugins/RustBotsAvatarSurvival.cs`: mode BUILD_SMOKE, marker/run-root/no-restore guards, bounded2100s FirstHome; успешный smoke тоже должен оставаться PARTIAL/DIAGNOSTIC_BUILD_ONLY без survival snapshot.
- `scripts/Invoke-NavigationProbe.ps1`: FirstHomeSmoke, отдельные deadlines, новая физическая установка для каждого FirstHome run, запрет diagnostic cache promotion и smoke-as-restore-source.
- `scripts/ProbeCache.ps1`: физический fork install/world; smoke manifest/generation только в приватном namespace, самостоятельный fail-closed запрет promotion. Обычный FirstHome тоже получает новый runtime/install, сохраняя штатный trusted save/proof path только для натурального сценария.
- `scripts/ProbeFirewall.ps1`: помимо прежнего cache64/install разрешён ровно runtime32/install с соответствующим marker. Guard повторяется в caller и elevated broker; inbound/outbound/ActiveStore/COM/reservation/job/cleanup требования сохранены.
- `scripts/FirstHomeValidation.ps1`, `Test-FirstHome.ps1`, `Test-ProbeCache.ps1`, `Test-ProbeFirewall.ps1`: отдельный diagnostic validator, запрет fixture в NATURAL receipt, focused regressions для времени, физического cache separation/no-promotion и точного firewall-root admission.

Exact allowlist20путей зафиксирован в PLAN:9source/script/test и11документов011, включая переданный владельцем пакет. Это bounded exception одной home-задачи. Код001–009, EconomyJournal, старые010docs/evidence, owner Server/ и BAT не изменялись.

## Время и стоимость

010 run4:989.50436с сбора при cap1100с; оставалось110.49564с ещё до пути и reserve120с. Причина была бюджетом времени, а не доказанным изменением площадки.

Новый FirstHome cap2100с: измеренные989.5с + допустимый route до300с + строительный/nav reserve360с +450.5с на поиск, инструменты и буфер. Early site admission оставляет1350с для сбора/строительства; late admission360с плюс рассчитанный путь. Legacy gameplay900с не меняется. Runner FirstHome2400с, smoke900/1200с; явно слишком короткие FirstHome runner settings отвергаются. Runner отсчитывает navigation от plugin readiness; дополнительный RustNav wait ограничен существующим startup/plugin контролем, но редкий длительный rebuild не доказан этим warm smoke.

Бюджет3760wood сохранён: actual loaded home craft1420 + Twig260 + Wood upgrades1040 + консервативный upkeep1040. Установленный native IL при неизменных defaults предсказывает134wood/1440мин:104blocks +30door, TC без Upkeep attribute. Это условный static расчёт, а не live TC measurement. Новый tax planner ради сокращения фарма не вводился. Acceptance требует actual `CalculateUpkeepCostAmounts`/`GetProtectedMinutes` >=60мин; они до отказа TC не достигнуты. Снижение реальных construction/recipe costs, отключение decay, repair/телепортация не применялись.

## Единственный игровой запуск

Run `796947c80d214fc4aa309b429e637adc`, PID36396, старт18:20:38UTC, readiness272.841с. Installed changeset168909/release, RustNav; live Oxide загрузил `RustBotsAvatarSurvival0.3.0`. Combined plugin source SHA256:

`D1416598A20DC069994630A7FB3B2B501D1B05933FFBA8B113561AB1D135AD8A`.

Хеш совпал с runtime source и независимой реконструкцией repo plugin+EconomyJournal+FirstHome. Это smoke-source proof, не доказательство натурального прохождения.

Команда: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-NavigationProbe.ps1 -FirstHomeSmoke -StartupTimeoutSeconds 900`. Native процесс запущен собственным kill-on-close Job Object после verified test-only firewall lease; argv/secret остаются только в ignored raw.

До него orchestration `2f2d131b5d884bc79f117e9b3900c01a` остановилась на прежнем cache-only firewall-root guard. `ServerPid=null`, `StartedUtc=null`, `Shutdown=NOT_STARTED`: это не второй игровой запуск. После RED/GREEN и независимого review guard расширен только на точный runtime32/install+marker. Прерванная lease отдельно сверена как noPID/noBroker/noRules, её reconciliation явно помечена, не выдана за штатный broker receipt.

### Явные тестовые материалы и реальные расходы

TEST_FIXTURE_WOOD:3960wood, UID142734/142735/142736 по1000 и142737на960. TEST_FIXTURE_STONES:100, UID142738. Это полный home budget плюс loaded axe ingredients; не натуральная добыча. Единственный starter rockUID142732 — раскрытый исходный kit. Fixture выдача5receipts, натуральные harvest0, source replay0.

Оплаченный stonehatchetUID142739:200wood+100stones. Далее planner20wood, hammer100wood, door300wood, TC1000wood; native шесть Twig placements260wood и шесть Wood upgrades1040wood. Всего17committed payment operations,2920wood+100stones расходов;6checksum journal records относятся к paid tool craft, отдельные durable home intent files сохранены. Никакого заявления о crash-atomic journal это не даёт.

На отказе остались1040wood (UID142736:80,142737:960), planner144835, hammer144837, door144839, TC144841. TC amount1/condition1 и дверь amount1 сохранены. Pending BUILD_TC PREPARED Before совпал с terminal inventory: неуспешный вызов не списал TC/wood и не был повторён. Состояние intent остаётся неопределённым для автоматического retry; в NATURAL его переносить нельзя.

### Наблюдаемые native блоки

| Роль | Entity ID | Grade | Building / links | Health |
|---|---:|---|---|---:|
| Foundation |146471|Wood|1 /4|250|
| Wall N |146569|Wood|1 /4|250|
| Wall E |146637|Wood|1 /4|250|
| Wall W |146640|Wood|1 /4|250|
| Doorway |146643|Wood|1 /4|250|
| Roof |146646|Wood|1 /4|250|

У всех возвращённых rows saving/registered/support=true и один собственный engine bot owner. Это список подтверждённых возвращённых сущностей, не полный forensic inventory всех transient/world entities. HOME_NAV внутри дома не выполнялся.

Site динамически выбран на38-м кандидате из18432limit, native preview и PathComplete; расчёт route70.369705м/54с, remaining899.49с/reserve360с при late admission. Физически пройдено107.874908м, включая подходы к строительным сторонам. Координаты, точный ray/socket/parent и raw path samples остаются в локальном evidence. Координаты площадки не заданы в исходнике; она выбирается динамически на тестовой карте. Runner задаёт fixture seed424242/size2000 только для воспроизводимой карты.

### Первый отказ и его пределы

На gameplay~56.5с, при remaining~843.5с, native `Planner.DoBuild(Construction.Target,Construction)` для `TC`, parent foundation146471, socket=null, вернулnull. Reach/owned held Planner/affordability/CanBuild/surface/hook guards до вызова прошли. `lastPlacementErrorDebug=""`; native Phrase не была захвачена этим исходником. Это **BUILD_PLACEMENT_TC**, не TIME_BUDGET, не SITE_GEOMETRY и не доказанная невозможность NPC API.

Installed IL содержит несколько native отказов с пустым debug: LOS, placement update/geometry/privilege и другие проверки могут писать только Phrase либо не писать debug. Из текущего raw нельзя выбрать конкретную внутреннюю причину. **ROOT_CAUSE=UNKNOWN**; изменения правил, speculative replacement API и повторная оплаченная операция не выполнялись. Следующее исследование требует capture native Phrase и точных deployable placement checks перед новым отдельно разрешённым smoke; эта задача не открывает новый запуск.

## Raw, save и изоляция

Локальные файлы только в `.local/runtime/796947c80d214fc4aa309b429e637adc/`: `result.json`, `plugin-result.json`, `server.log`, combined `RustBotsAvatarSurvival.cs`, `home-evidence/` (44файла с проверенными SHA), `home-evidence-hashes.json`, собственный `install/` и `smoke-cache/`. Никаких owner config/save, RCON secrets или полных logs в public commit.

Smoke loaded exact verified warm generation в собственную физическую копию. `Cache.DiagnosticOnly=true`, `Cache.Promoted=false`. После smoke совпали118SHA/length защищённых cache/history files, включая исходный trusted manifest/generations и010raw/docs. Offline regression отдельно изменяет private save, проверяет неизменность trusted copy, запрещает promotion и затем создаёт NATURAL fork из pristine trusted save.

Shutdown: GRACEFUL, exit-1 соответствует установленному native quit; ACK и Saving complete присутствуют. Сохранён диагностический native мир с частичной структурой, но `Persistence.Saved=false`, `FirstHome.SaveReady=false`, ни оплаченного home checkpoint, ни restore proof нет. Нельзя использовать его в JOURNEY/RESTORE.

Owner audit18:27:41UTC:3086файлов, SHA/length changes0. Safety18:27:44UTC: Rust/Steam/helpers/TCP/UDP/rules/open leases/occupied locks0,25leases закрыты (включая явно reconciled pre-PID abort). Чужие процессы не останавливались. SteamCMD/update/validate/BAT не запускались. Owner world/mods/config остались read-only.

## Проверки и поставка

- Focused RED→GREEN: schedule/no fixture-as-natural; physical cache fork/no-promotion; точный firewall runtime path+marker. Existing ordinary suites и installed compile — Test-All PASS до PID и перед доставкой.
- Независимое source/API prelive review и повторное review firewall guard; отдельное независимое source/raw native payment/evidence review после smoke. Ограничения пустой native ошибки и отсутствия полного realm inventory сохранены.
- mojibake-маркеры в изменённых файлах проверены;
- escaped Cyrillic в изменённых файлах проверены.
- Strict UTF-8/NUL, owner-value/RCON-secret/credential/Steam-ID/non-loopback-IP scan, exact allowlist, protected source/history и owner audit выполнены. Runtime secrets сравниваются в памяти и не печатаются.

Git разрешён прямым запросом и TASK E для baseline/scope и exact delivery. Использованы `git status --short`, `git rev-parse HEAD`, `git branch --show-current`, `git ls-remote origin refs/heads/master` (SSH denied), `git check-ignore Server .local artifacts`, `git ls-files -- Server/`; HTTPS `git -c credential.interactive=false -c url.https://github.com/.insteadOf=git@github.com: ls-remote origin refs/heads/master` (sandbox network denied, вне sandbox успешно). Review использовал `git diff 19ab338c518defa5508fbe8a70448ae773c2b0ec -- <точные source/script пути PLAN>`. Scope использует `git diff --check`, `git diff --stat -- <точные пути>`, `git diff --name-only`, `git status --short --untracked-files=all`.

Доставка: `git add -n -- <20 exact PLAN paths>`, `git add -- <те же20paths>`, `git diff --cached --name-only`, `git diff --cached --check`, `git diff --cached --stat`, `git diff --cached --no-ext-diff -- <те же20paths>`, `git commit -m 'fix: isolate first-home build smoke and phase budgets'`, обычный HTTPS-rewrite `git ... push origin master`. Затем `git rev-parse HEAD refs/remotes/origin/master`, HTTPS ls-remote и clean status. Фактические exit codes/commit/local/tracking/public SHA хранятся в ignored `.local/audit/home011/delivery.json` и финальном ответе: commit не может включать собственный SHA. Remote config не меняется; broad add/force/reset/rebase/stash/clean/history rewrite не используются.

Не доказаны полноценный натуральный дом и independent restore, а также crash safety, arbitrary custom-map E2E, production50–100bots и дальнейший roadmap. Следующий Goal/Slice не начинался.
