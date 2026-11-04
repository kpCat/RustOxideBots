# RUST-BOTS-015 — результат, 04.11.2026

**PARTIAL / NATIVE_THRESHOLD_BLOCKED. G1 HOLD; live0/3.** Полный OUTSIDE → INSIDE_TC → OUTSIDE → close Door не доказан. DIAGNOSTIC_HOME_GREEN и GREEN_HOME_BOOTSTRAP не достигнуты. Работа остановлена по разрешённой ветке EXECUTION_PLAN п.2 до первого PID: центрирование не устраняет известный вертикальный порог, а безопасный native step/vertical-support механизм для действующего RustNav пути не установлен. Это не доказательство невозможности любого будущего native решения.

## Установленный результат

| Проверка | Класс | Факт |
|---|---|---|
| Baseline | STATIC | HEAD = origin/master = GitHub API master = HTTPS refs/heads/master = `ed25505e3e829af563243d242e2c3fc5729027f4`, ветка master; исходно только supplied untracked docs015 |
| Native movement | STATIC_IL | RustNav использует corridor height и native transform sync; не подтверждён capsule step solver. HumanNPC.IsOnGround всегда true; ground flag не доказывает опору |
| Native alternatives | STATIC_IL | BaseNavigator step найден, но работает в другом Base режиме с sphere r0.25 и single ray; не доказан full-body r0.5/h1.8 RustNav contract. baseOffset — additive Y без support solver |
| Installed assets | STATIC_ASSET | Fresh roam prefab: kinematic/no-gravity Rigidbody, native capsule0.5/1.8, без root CharacterController. Fresh doorway mesh74 vertices/triangles совпадает с014 после JSON нормализации |
| Centered routes | OFFLINE_PREDICTION | Centerline и ±25mm дают боковой запас75–100mm, но predicted penetration остаётся11.279mm при записанной высоте. Старая native nav sample Y равна feet Y. Исправленная новая поверхность UNKNOWN |
| Независимый review | READ_ONLY | Подтвердил stop/go вывод и ограничения; отдельно проверил Base fallback, ground override, bake settings, mesh prediction и существующий guard. G1 passed не объявлен |
| Test-All | OFFLINE_ONLY | Windows PowerShell5.1, exit0; штатные safety/cache/economy/home/physics negatives и C#7.3 compile всех plugins против installed DLL |
| Preflight | NO_PID | Existing `-FirstHomeSmoke -StartupTimeoutSeconds 900 -PreflightOnly`: prerequisites passed, ожидаемый PARTIAL/exit1; ServerPid=null, StartedUtc=null, Cache=null, helper не запущен |
| BUILD_SMOKE | NOT_RUN | Нет обоснованного исправления vertical route; native live compilation/loading, STEP_CONTACT resolution и actual crossings015 отсутствуют |
| NATURAL / RESTORE | NOT_RUN | First smoke GREEN отсутствует, поэтому оплаченный journey и restore не допущены. Fixture promotion/replay0; никакой подмены source014 |
| Owner/history | SHA_AUDIT | Owner3086 файлов, protected1310 файлов истории/raw/world/manifest проверены до/после; изменений0 |
| Trusted test cache | SHA_AUDIT | Existing `Assert-ProbeInstallManifest` проверил1928 runtime files по сохранённому SHA-256 manifest; integrity PASS. Cache generation/manifests не менялись |
| Cleanup | READ_ONLY_AUDIT | Rust/Steam/helper0, TCP/UDP тестовых портов0, firewall probe rules0, live/open leases0, locked lifecycle/cache files0. Старые30 закрытых lease directories сохранены |

## Почему не запущен smoke

014 записал реальную native penetration0.0112793455m на входе. Lower sphere соответствует native capsule; triangle prediction0.0112792556m воспроизводит измерение с ошибкой менее0.0000001m. При projection на actual door centerline прогноз0.0112793518m: выигрыш в боковом запасе не меняет full-width threshold. Нормальный sweep на фиксированной historical foot height предсказывает максимум около30.898mm, а не безопасное преодоление.

Проверенные climb/slope defaults и `apertureStepOver` относятся к bake/connectivity, не к физическому разрешению контакта. Native support query только читает поверхность. Native internal transform updates являются обычным движением RustNav и сами по себе не названы teleport; проблема — отсутствие доказанного full-body collision/support response. Ручное применение query point, поднятие baseOffset ради просвета, смена physics/collider/mask или permissive11.279mm cutoff не применялись.

Новый маршрут мог бы иметь другую native Y, но такая sampled safe surface не установлена. Ни один кандидат не имеет одновременно подтверждённых новых complete native legs, supported foot и capsule clearance на пороге. Тратить smoke на прежнюю непроверенную вертикальную поверхность означало бы проверять необоснованное исправление. Зафиксирован bounded blocker; следующий Goal автоматически не начат.

Исторический013 outbound collider остаётся UNKNOWN. В015 не проведён новый outbound; native014 contact resolution отсутствует, так как014 останавливался сразу. Временный STEP_CONTACT и разрешённый контакт нельзя выдумать из одного upward MTD. Existing runtime foundation exclusion шире физического proof; existing validator `RequireClear` отвергает foundation overlap. Эти ограничения сохранены и явно описаны в review, не представлены как готовая поддержка ступени.

## Scope и проверки

Product sources/scripts не изменялись. Новый публичный результат — API_DECISION.md, PLAN.md и этот RESULT;11 supplied документов015 добавляются вместе с ними. Exact allowlist14 документов одной family — bounded exception, зафиксирован в PLAN. Runtime/экономика/строительство, README/AGENTS корня и история001–014 неизменны. New tests/contract/RED→GREEN не создавались: G1 не допустил implementation. Existing Test-All PASS не назван доказательством нового шага или live compilation.

Первый fresh asset comparison в приватном Python audit сравнил tuples UnityPy с JSON lists и завершился assert; нормализованное повторное сравнение **тех же уже extracted данных** подтвердило полное равенство mesh. Повторной игровой попытки не было. Первоначальный safety audit в sandbox не имел CIM доступа; authorized read-only проверка вне sandbox успешно выполнилась. Полные raw сохранены, не отредактированы ради успешного отчёта.

- mojibake-маркеры в изменённых файлах проверены:14/14, совпадений0.
- escaped Cyrillic в изменённых файлах проверены:14/14, включая XML numeric references, совпадений0.
- UTF-8/NUL, owner-value/credentials/Steam ID/IP secret audit: PASS14/14;26 owner config files и6 private values сравнены в памяти без вывода значений. Новых RCON secrets нет, потому что live0.
- Independent final document/scope review: завершён, physics/status/safety/scope blockers не найдено; уточнена запись native property `BaseEntity.ServerPosition` вместо имени несуществующего метода. G1/product gate не объявлен passed.

Raw только ignored `.local/audit/home015/`: IL, fresh assets, geometry script/result, Test-All output, independent prelive review, owner/protected/safety audits и delivery proof. Preflight receipt `.local/runtime/cc09a2581b4c4f2e9ea0e06658c7b01b/result.json` не является live run. Test-All запускал свои синтетические safety fixtures, включая foreign-process blocker; это не настоящий RustDedicated/игровой старт и не расход live бюджета.

## Git и доставка

Git явно разрешён пользователем и TASK015 для baseline/scope/exact delivery. Использованные команды и цель:

```text
git status --short
git rev-parse HEAD
git rev-parse origin/master
git branch --show-current
git remote get-url origin
git ls-remote origin refs/heads/master
git -c core.sshCommand='ssh -o BatchMode=yes -p 443 -o Hostname=ssh.github.com' ls-remote origin refs/heads/master
git ls-remote https://github.com/kpCat/RustOxideBots.git refs/heads/master
git ls-files -- Server .local
git check-ignore Server/rustds/RustDedicated.exe .local/audit/home015
git ls-files -- docs src scripts AGENTS.md README.md .gitignore
git diff --exit-code -- src/home/FirstHome.cs scripts/FirstHomeValidation.ps1 scripts/Test-FirstHome.ps1
git diff --check
git diff --cached --name-only
git status --short --untracked-files=all
```

SSH22: sandbox network denied, затем publickey denied вне sandbox; SSH443: host key verification failed, trust store/ключи не менялись. HTTPS read подтвердил ref, GitHub connector независимо подтвердил master commit. Origin config сохранён.

Exact delivery использует14 путей из PLAN и private allowlist, без directory staging. Команды доставки (фактические outputs/SHA сохраняются после создания этого документа в ignored `scope-audit.json`/`delivery.json` и финальном ответе, без самоссылочного изменения RESULT):

```text
git add -n -- <14 exact paths>
git add -- <14 exact paths>
git diff --cached --name-only
git diff --cached --check
git diff --cached --stat
git diff --cached --no-ext-diff -- <14 exact paths>
git ls-files -- Server/
git commit -m "docs: record native threshold feasibility blocker for task 015"
git -c credential.interactive=false -c url.https://github.com/.insteadOf=git@github.com: push origin master
git rev-parse HEAD refs/remotes/origin/master
git -c credential.interactive=false -c url.https://github.com/.insteadOf=git@github.com: ls-remote origin refs/heads/master
git status --short --untracked-files=all
git ls-files -- Server/ .local/ artifacts/
```

`<14 exact paths>` означает каждое из14 имён текущего пакета, перечисленных в PLAN; это не wildcard или `git add` каталога. Force/reset/rebase/clean/stash/broad add, history rewrite и persistent remote change не применяются.
