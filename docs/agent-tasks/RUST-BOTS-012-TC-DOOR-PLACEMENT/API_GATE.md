# API_GATE — целенаправленная диагностика TC=null

**Установленные IL и реальные сигнатуры обязательны; этот список — вопросы для проверки, не утверждения о конкретной причине.**

| Проверяемое звено | Что зафиксировать | Возможный blocker, который надо подтвердить |
|---|---|---|
| Cupboard prefab / item | реальный item `cupboard.tool`, `ItemModEntity`, `Planner`, `GetDeployable`, `Construction`, deploy volume | неверный prefab/обход deployable path |
| `Planner.DoBuild(target,c)` | IL branches, native error/Phrase/Debug, возвращаемый тип, захват ошибок | null без публичного debug |
| `Construction.Target` | `entity=foundation`, `socket=null`, `onTerrain`, `normal`, `ray`, `rotation`, `shouldParent`, `valid`, `position` | target не соответствует surface/deployable правилам |
| Фундамент/внутренний объём | foundation top collider, wall+roof collision/LOS, OBB/capsule TC, vertical placement | TC пересекает roof/wall/actor или опирается неверно |
| Размещение TC после шести блоков | actual calculated alignment, constrained snap/socket; сравнить с admissible preview | порядок placement мешает реальному cupboard |
| Actor native reach | eyes→ray target ≤ native distance, LOS, issued position, correct held item | физически недоступная точка |
| Permissions | native CanBuild/GetBuildingPrivilege/hook + BuildingManager + owner bot ID | ограничение прав, а не коллизия |
| Server-only API | Player input vs server overload semantics, Hook result, placement error phrase | неэквивалентный вызов перегрузки |
| Payment and failure | exact native Item debit or no debit; pending intent stages, entity list/net IDs | повторный paid retry или неполный rollback |

Начать с зарегистрированного отказа 011: `run 796947c80d214fc4aa309b429e637adc`, parent foundation146471, role TC, empty `Construction.lastPlacementErrorDebug`. Эти IDs **только доказательства старого теста**, не hardcoded runtime.

Писать `API_DECISION.md`: три колонки `STATIC_IL`, `LIVE`, `UNKNOWN`; точные условия для разрешённой коррекции. Предварительный отдельный static `TC placement source preview` не заменяет native live `BuildingPrivlidge` и upkeep.

Запрещены обход `CanBuild`, отключение DeployVolume/collision/LOS, ручной `GameManager.CreateEntity` готового TC для GREEN, fake ownership, Steam ID spoof, temp отключение decay/anti-cheat и второй `DoBuild` на том же незавершённом intent.
