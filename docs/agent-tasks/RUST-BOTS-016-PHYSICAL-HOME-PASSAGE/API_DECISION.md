# API и решение 016

Выбрано A из DESIGN_OPTIONS: ограниченный `BUILD_SMOKE / OBSERVE_CONTACT_ONLY`. C#7.3 и установленный RustNav, исходный ScientistNPC/BasePlayer r0.5/h1.8. Runtime, owner и навигационные настройки не заменяются. `IsOnGround` остаётся telemetry, не доказательством опоры. Native full-body step solver пока UNKNOWN.

Installed metadata reader подтвердил `Physics.CapsuleCastAll(Vector3,Vector3,float,Vector3,float,int,QueryTriggerInteraction)`, `ComputePenetration`, Rigidbody kinematic/gravity/collision mode/velocity, `RustNavMeshAgent.nextPositionWS`, velocity, CalculatePath и `RustNavMeshPath.corners`. Raw metadata: `.local/audit/home016/physics-api.txt`, `nav-api.txt`. Исторические IL015 прочитаны без изменения: corridor/native transform sync не доказывает solid-body response.

Существующий HomePhysicalSample расширен настоящими rotation/Rigidbody/agent pose/corners, capsule sweep между фактическими позами и пятью support-ray probes. Full native collider identities/poses/ownership и ComputePenetration014 сохранены. High-frequency watcher действует только в NAV изолированного BUILD_SMOKE; timer requested 25ms, actual time всегда записывается. Main sample связывается с receipt по точному времени. Обычный FirstHome не получает permissive mode; swept solid теперь также блокирует его admission.

## Stop policy, не clearance tolerance

- Общий observation максимум0.35s и0.30m суммарной фактической дистанции; интервал между измерениями максимум0.10s, displacement не более6m/s плюс0.01m numerical slack.
- Наблюдать можно только measured own doorway threshold с upward native MTD и own floor contact, неизменённым телом, открытой дверью, body-fit aperture, актуальным полным native path и реальной опорой. Если upward own foundation contact возникает раньше lip, он начинает тот же общий budget; первый lip устанавливает только baseline глубины, без сброса времени/дистанции. Рост foundation penetration также имеет отдельный cumulative stop. Любая иная solid geometry, unsupported floor, closed door или nonphysical velocity>6m/s немедленно останавливают путь.
- 0.04m — аварийный верхний stop bound, никогда не допустимая пенетрация. Рост более0.001m относительно минимальной наблюдённой глубины останавливает движение;0.15s устойчивого контакта заканчиваются STUCK/UNSAFE. Это пределы краткой диагностики, все перекрывающиеся кадры остаются blocking.
- `KINEMATIC_CLIP` требует нескольких фактических поз, native kinematic Rigidbody, движения при увеличении ComputePenetration без соответствующего подъёма feet. Sweeps сохраняются отдельно; неподтверждённую геометрию нельзя объявлять доказанным клиппингом.
- Потеря контакта сама по себе только `UNKNOWN / CLEARANCE_REQUIRES_REVIEW`, не RESOLVED_NATIVE. Для достоверного RESOLVED_NATIVE нужны дополнительные физические доказательства; код не выдумывает их. Diagnostic никогда не выдаёт accepted crossing/TC/navigation success и не меняет Clear у контакта.
- При sensor exception/разрыве/unsafe outcome native agent немедленно останавливается, результат PARTIAL; таймер не продолжает движение. Никаких xyz/Y/baseOffset writes, Warp, forces, collider/layer/size/terrain edits.

Independent validator реконструирует continuity, sweep, collider penetration, support ray geometry, aperture, cumulative growth и outcome из самих receipt. Отрицательные OFFLINE_ONLY fixtures не считаются Unity simulation. До PID обязателен независимый review; фактические live outcome, alternative native geometry и итог проверки будут записаны в RESULT.

Новые physics receipts с Sweep используют строгий `Clear`: ни endpoint nonself overlap, ни nonself swept hit. Старый `LegacyClear` сохраняется отдельно, включая историческое foundation exclusion. Старые receipts014 без Sweep читаются по старому диагностическому контракту и не переименовываются в безопасный проход. Initial-overlap capsule-cast hit проверяется дополнительным native ComputePenetration на предыдущей позе, с записанными query position/rotation; геометрия служебного cast hit не используется как доказательство стены. Это read-only physics query, без перемещения collider.

Runner/cache/firewall/OwnedServerProcess не изменяются. Smoke — свежая физическая no-promotion копия проверенного pristine world, с TEST_FIXTURE и всеми native платежами. Только полный первый физический smoke разрешает отдельные natural+restore; второй smoke заканчивает задачу.

## После первого smoke: исправление диагностического дизайна

Первый live05.11.2026 подтвердил ранний контакт с передней нижней кромкой doorway: native depth0.0167371333m, upward MTD0.5135387, lateral MTD относительно портала около0.00002977. Foot height на251.25mm ниже recorded014. Независимое сопоставление с exact native mesh triangles(7,8,9)/(8,10,9) предсказывает0.0167376405m — расхождение около0.5µm. Это именно новая ранняя фаза подхода к тому же низкому mesh edge, не доказательство клиппинга, stuck или resolved step; исторический outbound013 остаётся UNKNOWN.

Нормальная проверка full-radius aperture остановила и диагностическое наблюдение при center normal≈−0.538m и lateral≈0.1235m. Полная капсула ещё не достигла центральной плоскости портала; её сечение в реальной толщине frame уже контактует с низкой кромкой. Поэтому одного изменения full-width check недостаточно: исходный smoke-only MTD cutoff0.85 и sweep height от текущих feet тоже преждевременно отвергли бы этот измеренный edge.

PolicyRevision2 меняет только **диагностическую candidacy**. Для own doorway collider требуется positive-up MTD≥0.1, lateral projection≤0.05, lower-sphere contact estimate в60mm от отдельно измеренного forward own-foundation floor. Это идентификация наблюдаемой низкой кромки, не доказательство безопасности или clearance epsilon. Forward floor ray имеет настоящие origin/hit/normal/distance и проверку entity/ownership. Swept hit должен согласоваться с тем же edge либо отдельно подтверждённым начальным overlap.

Диагностическая апертура теперь учитывает максимальное сечение r0.5/h1.8 capsule в **реальной толщине native Mesh.bounds**, с transform/scale и projected slab, а не полный радиус в любой внешней позе. На самой плоскости crossing production по-прежнему требует полный размер. Все body overlaps, native penetration и swept hits сохраняются; ни один obstructed frame не получает Clear/Accepted. Все прежние time/distance/depth/growth/support stops неизменны. Native position, speed, collider, Y и baseOffset не меняются.

Ruling: второй smoke используется для исправления измеренного premature diagnostic stop на native entry trajectory, а не для заявления уже найденного безопасного step solver. Это ограниченная интерпретация TASK о measured correctable native defect в пользу требуемого реального after-contact наблюдения, подтверждённая независимым post-smoke1 review. Цена — после smoke2 обязательный STOP016, без одиночного NATURAL и без RESTORE. Старый raw и PolicyRevision1 receipts неизменны и читаются своим контрактом. Новая candidacy имеет OFFLINE_ONLY negative fixtures, installed compile и отдельное pre-smoke2 review.

## Native строительные альтернативы — исследованы, не применены

Fresh installed assets подтвердили реальные `foundation.steps` и `ramp`: BuildingBlock/Construction/Upkeep, BuildingGrade baseCost twig50wood/Wood200wood, Construction.costMultiplier0.5, upkeepMultiplier1, maxplaceDistance4. Значения baseCost не выдаются за итоговый платёж: loaded CostToBuild после native setup для нового объекта не измерялся, транзакции не было. Native ramp-male/type7/support≈0.7 и ramp-female/type7/support1 имеют terrain/not-terrain socket tests; штатная foundation имеет четыре совместимых female sockets. Это реальное семейство construction, не свободный collider или невидимая подкладка.

Wood steps mesh имеет высоту около1.686m, native ramp skins75/150 — примерно0.77/1.53m. Но совместимые parent/socket transforms, реальный выбранный variant, paid placement/stability/TC receipt и supported full-size RustNav через поднятый doorway lip не установлены. Ни один такой объект не создан и не оплачен; заявлять paid fix нельзя. Добавление требует versioned home schema и restore witnesses вместо молчаливого девятого объекта. Результат статического Wood→Stone сравнения также отрицателен: оба doorway дают≈11.279mm на pose014 и≈30.898mm max center sweep. Просто заменить grade — не решение.

Raw исследования только `.local/audit/home016/native-entrances*.json`, `doorway-grade-comparison.json`, `post-smoke1-review.md`. Эти данные не являются новой native navigation simulation и не оправдывают спекулятивный ramp launch.

## Итог второго smoke / STOP

Второй настоящий isolated run завершился PARTIAL/SWEPT_OBSTACLE: одновременно19.329mm native doorway contact и0.112mm foundation front-edge contact. Последний имеет upward MTD≈0.4514 и собственный swept hit, не доказанный плоский support. Политика не расширена для его игнорирования; native path остановлен на первом contact frame. Actual after-contact evolution не измерена, native step/устойчивый clipping/stuck остаются UNKNOWN. Возможное будущее разрешение этого compound contact не доказано и не опровергнуто. Цель физического дома не достигнута, третьего запуска и natural/restore не было.

На false ComputePenetration prior-pose queries Distance/Direction out-поля не являются валидными penetration measurements. Raw сохранён, анализ использует только `Intersects` и actual true-contact результаты; undefined false outs не используются для GREEN или отрицательных расстояний. Подробные native факты, ограничения и safety evidence — RESULT.md.
