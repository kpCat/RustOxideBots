# EVIDENCE — необязательность ручных действий, строгие доказательства

Все настоящие E2E самостоятельно выполняет Codex. Сохранить raw immutable evidence на каждую попытку в ignored `.local/runtime/<run-id>/` и дополнительный read-only audit в `.local/audit/economy009/`. При выходе всегда owned cleanup независимо от GREEN/PARTIAL/BLOCKED. Исторические `.local` 001–008 не редактировать.

## LIVE receipts (не подменять OFFLINE fixtures)

- `server.log` UTF-8, actual compile/load, readiness, RustNav, native save; `result.json`, `plugin-result.json`, source snapshot & SHA.
- Native actor type, genuine BasePlayer PlayerInventory, logical actor ID, active Item UID, held owner/parent, original/restored Item UID/amount/condition, no replay starter kit/gather/craft in RESTORE.
- Natural source: current world generation/hash, exact prefab & position/rotation, transient net ID **только как наблюдение**, найденный durable mapping basis, candidates matched, alternate candidates rejected, same source depletion native `ItemAmount.amount`, `fractionRemaining` before/after/replay. Отдельно source respawn/incarnation flags, если доступно.
- Native harvest hits: actor/tool/source coordinates with timestamps/range/LOS, source debit и inventory credit, item UID, tool wear, no adapter credit. Наибольший риск — намерения, по которым после crash была неизвестная фактическая выдача; сохранять `IN_DOUBT` и никогда не выдавать снова только для красивого GREEN.
- Craft recipe/id/ingredient IDs and amounts from loaded runtime, consumed UID and quantity, output UID, state transitions, replay duplicate denial, actual status native vs accounted. Сохранить inventory before/after и exact material balance.
- Journal raw append/checkpoint/replay proof + hash/version, world binding, provenance, bad-world/missing-node/ambiguous identity/corrupt journal negatives with explicit `mutation count=0`; snapshots cache world `.sav` hash, source and actor state hash. Нельзя раскрывать secrets или owner fingerprints в Public docs.
- Process and security: owned process PID per run, shutdown ACK/save/exit; audit Rust/SteamCMD/helper=0, TCP/UDP endpoints=0, firewall rules/leases=0, locks freed, owner hashes unchanged. If test fails before complete load, record exactly that status; raw JSON not rewritten as success.

## Validation

- Offline focused tests: duplicate intent, torn journal, replay twice, wrong world/generation, transient netID collision, ambiguous source, overwritten source, legal/new respawn, wrong native pool, failed output after debit, wrong actor/item UID. Independent validator must reject false positive GREEN. Use RED→GREEN counterexamples with evidence.
- Real LIVE vs OFFLINE separation in final matrix, no synthetic travel/harvest or fabricated source matches.
- Two separate text checks: mojibake patterns and escaped Cyrillic. Strict UTF-8 public source and no secrets/sensitive data. Report reason for any NOT_VERIFIED. Raw personal/private paths and RCON secrets only ignored `.local`.

## Final deliverables

`docs/agent-tasks/RUST-BOTS-009-WORLD-ECONOMY-PERSISTENCE/RESULT.md`, `API_DECISION.md` if necessary, source/test/runner amendments, exact public allowlist, final commit SHA, `origin/master` match, no `Server/` published. Do not include raw local logs in Git.
