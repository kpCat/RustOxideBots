# EVIDENCE — что положить в RESULT и оставить в raw ignored

1. Baseline SHA/local/public master/status, installed native API/IL signatures + hashes, все реально изменённые public files; Test-All, real live compiler and Oxide startup.
2. Для каждого rejected building site: тип отказа и безопасный sample; для выбранного site: Terrain/Nav/грунт/коллизия/вода/ближайший road/monument/foreign TC/building privileges, размер/seed только как тестовые параметры.
3. Material ledger: native natural tree/ore entries с pool before/debit, yield Item UID/condition; все реальные loaded ItemBlueprint/BuildingGrade costs; декременты родительских Item UID и итоговые ItemContainer/TC balances. Нельзя считать один и тот же UID дважды.
4. Building ledger: planned relative footprint, concrete prefab/types/IDs, native grade/support/building ID, owner and adjacency for foundation, walls, doorway, roof, door, TC. Каждая entity реально существует/видна serverEntities после construction. Не перепутать несуществующую стенку и model-only.
5. TC: authentication native bot identity либо честное ограничение; actual privilege, upkeep source→TC, native cost/time, intact health/decay vs controls; нет искусственной правки decay time.
6. Door + navigation: status open/close/locks/collider, timestamps; door position, outside/inside/TC/exit points из текущей геометрии, rustnav complete/invalid raw, continuous samples and max physical step/speed, bounded failures.
7. Restart: raw `run-id`, proof .sav/map/WipeId/cache generation, world-key, entity lists before/after, native load/availability, 0 new created structure/item/source credit, preserved actor identity and inventories. Если дом разрушен/foreign, stop not rebuild.
8. Raw `server.log`, `result.json`, `plugin-result.json`, journal/home state, source snapshot, world proof, SHA, cleanup receipts — только `.local/runtime/` и `.local/audit/home010/` ignored. Public RESULT — обезличенные факты, без сетевых адресов/Steam IDs/реальных настроек пользователя.
9. Проверки безопасности: исходный/финальный fingerprint всего owner Server, total changed=0, own PID/Steam/helper/ports/firewall/lease/locks=0, Server tracked=0, exact paths/Git/push; mojibake и escaped Cyrillic раздельно.
10. Считать 1–2 live стартами только реальные RustDedicated. Старые probe результаты и fixtures не выдавать за новый E2E. Исторические raw 001–009 не переписывать.
