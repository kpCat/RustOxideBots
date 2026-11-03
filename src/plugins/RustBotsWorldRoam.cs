using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Newtonsoft.Json;
using Rust.Ai.Gen2;
using Rust.Ai.Gen2.Nav;
using UnityEngine;
using UnityEngine.AI;

namespace Oxide.Plugins
{
    [Info("RustBotsWorldRoam", "RustOxideBots", "0.1.0")]
    [Description("Isolated single-NPC outdoor journey and native loot receipts.")]
    public class RustBotsWorldRoam : RustPlugin
    {
        private string root, token, prefab, backend;
        private BaseEntity npc;
        private RustNavMeshAgent agent;
        private FSMComponent fsm;
        private BaseAIBrain brain;
        private bool active, finished, legActive;
        private Vector3 previous, start, target, progressPosition;
        private float previousTime, legStarted, progressTime, traveled, total;
        private int completed, repaths, stuckCount, rejectedSamples;
        private readonly List<object> legs = new List<object>();
        private readonly Dictionary<string, int> rejections = new Dictionary<string, int>();
        private readonly Dictionary<string, List<object>> rejectionExamples = new Dictionary<string, List<object>>();
        private bool beginRequested;
        private float navWaitStarted, nextNavReport;
        private float capsuleHeight = 1.9f;
        private const float CapsuleRadius = 0.45f;
        private Vector3 goal, episodeStart;
        private string stage = "ROAD", lootKind, lootSource;
        private LootContainer loot;
        private DroppedItem drop;
        private ItemContainer inventory;
        private readonly List<BaseEntity> fixtures = new List<BaseEntity>();
        private readonly List<DroppedItem> nativeDrops = new List<DroppedItem>();
        private readonly List<ItemRow> barrelBefore = new List<ItemRow>();
        private readonly List<ItemRow> barrelDrops = new List<ItemRow>();
        private readonly List<object> samples = new List<object>();
        private readonly List<object> transfers = new List<object>();
        private readonly List<object> hits = new List<object>();
        private readonly List<string> anomalies = new List<string>();
        private readonly Dictionary<string, string> parts = new Dictionary<string, string> {
            { "OPEN_TRAVEL", "BLOCKED" }, { "CRATE", "BLOCKED" }, { "BARREL", "BLOCKED" }, { "INVENTORY", "BLOCKED" }
        };
        private object road;
        private bool destroyedByDamage, saved, restored, barrelDropConserved = true;
        private float nextHit, dropWaitUntil;
        private int dropIndex, hitCount;
        private string inventoryPath;
        private List<ItemRow> expectedInventory = new List<ItemRow>();
        private List<ItemRow> initialInventory = new List<ItemRow>(), restoreExpected = new List<ItemRow>(), restoreActual = new List<ItemRow>();
        private readonly Dictionary<string, string> moved = new Dictionary<string, string>();

        private sealed class ItemRow
        {
            public string Uid, Shortname;
            public int Amount;
        }

        private static ItemRow Row(Item item) { return new ItemRow { Uid = item.uid.Value.ToString(), Shortname = item.info.shortname, Amount = item.amount }; }
        private static List<ItemRow> Contents(ItemContainer container) { return container == null ? new List<ItemRow>() : container.itemList.Select(Row).ToList(); }
        private static string InventoryKey(IEnumerable<ItemRow> items) { return string.Join(";", items.OrderBy(i => i.Uid, StringComparer.Ordinal).Select(i => i.Uid + ":" + i.Shortname + ":" + i.Amount).ToArray()); }

        private bool IsTestRoot()
        {
            root = Environment.GetEnvironmentVariable("RUST_BOTS_TEST_ROOT");
            token = Environment.GetEnvironmentVariable("RUST_BOTS_RUN_TOKEN");
            Guid parsed;
            if (string.IsNullOrEmpty(root) || !Guid.TryParseExact(token, "N", out parsed)) return false;
            string cwd = Path.GetFullPath(Directory.GetCurrentDirectory()).TrimEnd('\\', '/');
            if (!string.Equals(cwd, Path.GetFullPath(root).TrimEnd('\\', '/'), StringComparison.OrdinalIgnoreCase)) return false;
            string identity = Environment.GetEnvironmentVariable("RUST_BOTS_TEST_IDENTITY") ?? ("rustbots_probe_" + token);
            if (!identity.StartsWith("rustbots_probe_", StringComparison.Ordinal) || !ConVar.Server.identity.Equals(identity, StringComparison.Ordinal)) return false;
            string marker = Path.Combine(root, "rustbots-test.marker");
            return File.Exists(marker) && File.ReadAllText(marker) == token && Environment.GetEnvironmentVariable("RUST_BOTS_SCENARIO") == "WORLD_ROAM";
        }

        private void OnServerInitialized()
        {
            if (!IsTestRoot()) { Puts("Probe inert: isolated runner marker/identity missing."); return; }
            inventoryPath = Path.Combine(root, "oxide", "data", "RustBotsWorldRoam.inventory.bin");
            backend = ConVar.AI.useUnityNavmesh ? "RustNavMeshAgent/Unity" : "RustNavMeshAgent/RustNav";
            Puts("RUSTBOTS_READY " + backend);
            timer.Every(0.5f, () =>
            {
                try
                {
                    string stop = Path.Combine(root, "rustbots-stop.request");
                    if (File.Exists(stop) && File.ReadAllText(stop) == token)
                    {
                        CleanupNpc();
                        Puts("RUSTBOTS_SHUTDOWN_ACK");
                        ConsoleSystem.Run(ConsoleSystem.Option.Server, "quit");
                        return;
                    }
                    if (beginRequested && !finished && !active) WaitForNavigation();
                    if (active && !finished) TickProbe();
                }
                catch (Exception ex) { PrintError(ex.ToString()); Finish("BLOCKED", "Probe exception: " + ex.GetType().Name); }
            });
            timer.Once(5f, () =>
            {
                try {
                    if (Environment.GetEnvironmentVariable("RUST_BOTS_RESTORE") == "1") { RestoreInventory(); return; }
                    beginRequested = true; navWaitStarted = Time.realtimeSinceStartup; WaitForNavigation();
                }
                catch (Exception ex) { Finish("BLOCKED", "Probe initialization: " + ex.GetType().Name); }
            });
        }

        private void WaitForNavigation()
        {
            if (ConVar.AI.useUnityNavmesh) { Finish("BLOCKED", "World roam requires RustNav backend"); return; }
            var nav = RustNavigation.Instance;
            bool ready = ConVar.AI.useUnityNavmesh || (nav != null && nav.IsDefaultNavmeshBuilt());
            if (ready) { beginRequested = false; BeginProbe(); return; }
            if (Time.realtimeSinceStartup >= nextNavReport)
            {
                nextNavReport = Time.realtimeSinceStartup + 10f;
                var mesh = nav == null ? null : nav.DefaultNavmesh;
                Puts("RUSTBOTS_NAV_WAIT " + JsonConvert.SerializeObject(new {
                    Elapsed = Time.realtimeSinceStartup - navWaitStarted,
                    BuiltTiles = mesh == null ? 0 : mesh.NumBuiltTiles, TotalTiles = mesh == null ? 0 : mesh.TotalTiles,
                    IsValid = mesh != null && mesh.IsValid(), IsBuilt = ready
                }));
            }
            if (Time.realtimeSinceStartup - navWaitStarted > 600f)
                Finish("BLOCKED", "RustNav default mesh not fully built after 600 seconds; see RUSTBOTS_NAV_WAIT tile counts");
        }

        private void BeginProbe()
        {
            // Discover installed prefabs; no map-specific coordinates or hard-coded prefab path.
            var choices = GameManifest.Current.entities
                .Where(p => p.EndsWith(".prefab") && p.IndexOf("scientist", StringComparison.OrdinalIgnoreCase) >= 0)
                .OrderByDescending(p => p.IndexOf("roam", StringComparison.OrdinalIgnoreCase) >= 0)
                .ThenBy(p => p.IndexOf("heavy", StringComparison.OrdinalIgnoreCase) >= 0)
                .ThenBy(p => p).ToArray();
            GameObject selected = null;
            foreach (bool modern in new[] { true })
            {
                foreach (string path in choices)
                {
                    var obj = GameManager.server.FindPrefab(path);
                    if (obj == null || obj.GetComponent<RustNavMeshAgent>() == null) continue;
                    if (obj.GetComponent<ScientistNPC2>() == null) continue;
                    selected = obj; prefab = path; break;
                }
                if (selected != null) break;
            }
            if (selected == null) { Finish("BLOCKED", "No installed humanoid prefab with RustNavMeshAgent"); return; }
            var settings = selected.GetComponent<RustNavMeshAgent>();
            capsuleHeight = Mathf.Clamp(settings.height, 1.9f, 2.5f);
            Puts("RUSTBOTS_PREFAB " + JsonConvert.SerializeObject(new { Prefab = prefab,
                AgentType = settings.agentTypeID, AreaMask = settings.areaMask, Height = capsuleHeight, Radius = CapsuleRadius }));
            Vector3 spawn;
            if (!FindSpawn(settings, out spawn)) { Finish("BLOCKED", "No grounded clear spawn on active backend within bounded search"); return; }
            // Exactly one entity. No retry spawning and no reposition/warp after birth.
            npc = GameManager.server.CreateEntity(prefab, spawn, Quaternion.identity, true);
            if (npc == null) { Finish("BLOCKED", "CreateEntity returned null"); return; }
            npc.enableSaving = false;
            npc.Spawn();
            agent = npc.GetComponent<RustNavMeshAgent>();
            fsm = npc.GetComponent<FSMComponent>();
            brain = npc.GetComponent<BaseAIBrain>();
            if (fsm != null) fsm.SetFsmActive(false);
            if (brain != null) brain.SetThinkMode(AIThinkMode.None);
            if (agent == null || !agent.IsNavMeshBuilt || !agent.isOnNavMesh)
            { Finish("BLOCKED", "Spawned humanoid has no bound built navigation mesh"); return; }
            Puts("RUSTBOTS_NPC " + JsonConvert.SerializeObject(new {
                Type = npc.GetType().FullName, Prefab = prefab, Backend = backend,
                Brain = brain == null ? null : brain.GetType().FullName,
                Fsm = fsm == null ? null : fsm.GetType().FullName,
                Agent = agent.GetType().FullName, IsBasePlayer = npc is BasePlayer, Position = Point(npc.transform.position)
            }));
            agent.updatePosition = true;
            agent.isStopped = false;
            agent.SetGait(RustNavMeshAgent.Speeds.Jog);
            agent.speed = 3f;
            agent.stoppingDistance = 1f;
            if (inventory == null)
            {
                inventory = new ItemContainer();
                inventory.ServerInitialize(null, 48);
                inventory.GiveUID();
            }
            inventory.entityOwner = npc;
            episodeStart = previous = npc.transform.position;
            Vector3 roadGoal;
            if (!FindRoadGoal(out roadGoal)) { Finish("BLOCKED", "No complete outdoor road route between 280 and 450m"); return; }
            previousTime = Time.realtimeSinceStartup;
            samples.Add(new { Time = previousTime, Position = Point(previous), Stage = stage });
            active = true;
            StartRoute(roadGoal, "ROAD");
        }

        private bool Reject(string reason, Vector3 candidate, object detail)
        {
            rejectedSamples++;
            if (!rejections.ContainsKey(reason)) { rejections[reason] = 0; rejectionExamples[reason] = new List<object>(); }
            rejections[reason]++;
            if (rejectionExamples[reason].Count < 3)
            {
                var example = new { Reason = reason, Candidate = Point(candidate), TerrainHeight = TerrainMeta.HeightMap.GetHeight(candidate), Detail = detail };
                rejectionExamples[reason].Add(example);
                Puts("RUSTBOTS_REJECT " + JsonConvert.SerializeObject(example));
            }
            return false;
        }

        private bool ClearGround(Vector3 navPoint, out Vector3 foot)
        {
            foot = navPoint;
            RaycastHit hit;
            if (!Physics.Raycast(navPoint + Vector3.up * 4f, Vector3.down, out hit, 8f,
                Physics.DefaultRaycastLayers, QueryTriggerInteraction.Ignore)) return Reject("NoGroundRayHit", navPoint, null);
            float terrain = TerrainMeta.HeightMap.GetHeight(hit.point);
            if (Mathf.Abs(hit.point.y - navPoint.y) > 1f) return Reject("NavGroundHeightMismatch", navPoint, new { Ground = Point(hit.point), Collider = hit.collider.name });
            if (Mathf.Abs(hit.point.y - terrain) > 0.8f) return Reject("AboveTerrainStructureOrRock", navPoint, new { Ground = Point(hit.point), Terrain = terrain, Collider = hit.collider.name });
            if (hit.normal.y < 0.85f) return Reject("SteepGround", navPoint, new { Normal = Point(hit.normal), Collider = hit.collider.name });
            foot = hit.point + Vector3.up * 0.05f;
            float water = WaterLevel.GetWaterSurface(foot, true, true, null);
            if (water - foot.y > 0.15f) return Reject("UnderWater", navPoint, new { Foot = Point(foot), Water = water });
            var overlaps = Physics.OverlapCapsule(foot + Vector3.up * (CapsuleRadius + 0.12f),
                foot + Vector3.up * (capsuleHeight - CapsuleRadius), CapsuleRadius,
                Physics.DefaultRaycastLayers, QueryTriggerInteraction.Ignore);
            if (overlaps.Length != 0) return Reject("CapsuleObstacle", navPoint, new {
                Foot = Point(foot), Height = capsuleHeight, Radius = CapsuleRadius,
                Colliders = overlaps.Take(4).Select(c => new { Name = c.name, Type = c.GetType().Name, Layer = c.gameObject.layer }).ToArray()
            });
            return true;
        }

        private bool FindSpawn(RustNavMeshAgent settings, out Vector3 spawn)
        {
            // Low-discrepancy coverage of 90% of the map, including low coastal terrain.
            for (int i = 1; i <= 1024; i++)
            {
                Vector3 candidate = new Vector3((Halton(i, 2) - 0.5f) * TerrainMeta.Size.x * 0.9f,
                    0f, (Halton(i, 3) - 0.5f) * TerrainMeta.Size.z * 0.9f);
                candidate.y = TerrainMeta.HeightMap.GetHeight(candidate);
                Vector3 sample, foot;
                if (!SampleInitial(settings, candidate, out sample) || !ClearGround(sample, out foot)) continue;
                if (!HasDeparture(settings, foot)) { Reject("NoCompleteDeparturePath", foot, null); continue; }
                spawn = foot;
                Puts("RUSTBOTS_SPAWN_ACCEPT " + JsonConvert.SerializeObject(new { Candidate = Point(candidate), NavPoint = Point(sample), Foot = Point(foot), Rejections = rejections }));
                return true;
            }
            spawn = Vector3.zero; return false;
        }

        private static float Halton(int index, int radix)
        {
            float fraction = 1f, value = 0f;
            while (index > 0) { fraction /= radix; value += fraction * (index % radix); index /= radix; }
            return value;
        }

        private bool HasDeparture(RustNavMeshAgent settings, Vector3 from)
        {
            for (int i = 0; i < 12; i++)
            {
                float angle = i * Mathf.PI / 6f;
                Vector3 candidate = from + new Vector3(Mathf.Cos(angle), 0f, Mathf.Sin(angle)) * 36f;
                candidate.y = TerrainMeta.HeightMap.GetHeight(candidate);
                Vector3 sample, foot;
                if (!SampleInitial(settings, candidate, out sample) || !ClearGround(sample, out foot)) continue;
                if (ConVar.AI.useUnityNavmesh)
                {
                    var path = new NavMeshPath();
                    var filter = new NavMeshQueryFilter { agentTypeID = settings.agentTypeID, areaMask = settings.areaMask };
                    if (NavMesh.CalculatePath(from, foot, filter, path) && path.status == NavMeshPathStatus.PathComplete) return true;
                }
                else
                {
                    var path = new RustNavMeshPath();
                    if (RustNavigation.Instance.DefaultNavmesh.CalculatePath(new NavVector3(from), new NavVector3(foot), path, false) && path.status == NavMeshPathStatus.PathComplete) return true;
                }
            }
            return false;
        }

        private bool SampleInitial(RustNavMeshAgent settings, Vector3 candidate, out Vector3 point)
        {
            point = Vector3.zero;
            if (ConVar.AI.useUnityNavmesh)
            {
                NavMeshHit hit;
                var filter = new NavMeshQueryFilter { agentTypeID = settings.agentTypeID, areaMask = settings.areaMask };
                if (!NavMesh.SamplePosition(candidate, out hit, 2.5f, filter)) return Reject("UnityNavSampleMiss", candidate, new { Radius = 2.5f });
                point = hit.position; return true;
            }
            var navigation = RustNavigation.Instance;
            if (navigation == null || !navigation.IsDefaultNavmeshBuilt()) return Reject("RustNavNotFullyBuilt", candidate, null);
            NavHit navHit;
            if (!navigation.DefaultNavmesh.SamplePosition(new NavVector3(candidate), out navHit, new Vector3(2.5f, 3f, 2.5f), false))
                return Reject("RustNavSampleMiss", candidate, new { Extents = new[] { 2.5f, 3f, 2.5f }, BuiltTiles = navigation.DefaultNavmesh.NumBuiltTiles, TotalTiles = navigation.DefaultNavmesh.TotalTiles });
            point = navHit.position.Value; return true;
        }

        private bool SelectTarget(out Vector3 chosen)
        {
            Vector3 from = npc.transform.position;
            var full = new RustNavMeshPath();
            if (!agent.CalculatePath(goal, full) || full.status != NavMeshPathStatus.PathComplete)
            { chosen = Vector3.zero; return Reject("GoalPathIncomplete", goal, new { Status = full.status.ToString() }); }
            // Recalculate local progress towards the same world goal, never orbit for distance.
            foreach (float length in new[] { 36f, 24f, 12f })
            {
                Vector3 candidate = goal, cursor = from;
                float remaining = length;
                foreach (var corner in full.corners)
                {
                    float distance = Vector3.Distance(cursor, corner.Value);
                    if (distance > remaining) { candidate = Vector3.Lerp(cursor, corner.Value, remaining / distance); break; }
                    remaining -= distance; cursor = corner.Value;
                }
                NavMeshHit hit;
                Vector3 foot;
                if (!agent.SamplePosition(candidate, out hit, 2.5f, false)) { Reject("AgentNavSampleMiss", candidate, null); continue; }
                if (!ClearGround(hit.position, out foot)) continue;
                var path = new RustNavMeshPath();
                if (!agent.CalculatePath(foot, path) || path.status != NavMeshPathStatus.PathComplete || path.GetPathLength() > 80f)
                { Reject("AgentIncompletePath", foot, new { Status = path.status.ToString(), Length = path.GetPathLength() }); continue; }
                Puts("RUSTBOTS_SEGMENT_PATH " + JsonConvert.SerializeObject(new { Target = Point(foot), Length = path.GetPathLength(), Status = path.status.ToString(), AgentType = agent.agentTypeID }));
                chosen = foot; return true;
            }
            chosen = Vector3.zero; return false;
        }

        private bool FindRoadGoal(out Vector3 chosen)
        {
            chosen = Vector3.zero;
            if (TerrainMeta.Path == null || TerrainMeta.Path.Roads == null) return false;
            var candidates = new List<Vector3>();
            foreach (var r in TerrainMeta.Path.Roads)
                if (r.Path != null && r.Path.Points != null) candidates.AddRange(r.Path.Points);
            foreach (var p in candidates.Where(p => Vector3.Distance(episodeStart, p) >= 280f && Vector3.Distance(episodeStart, p) <= 450f)
                .OrderBy(p => Mathf.Abs(Vector3.Distance(episodeStart, p) - 310f)).Take(256))
            {
                NavMeshHit hit; Vector3 foot;
                if (!agent.SamplePosition(p, out hit, 3f, false) || !ClearGround(hit.position, out foot)) continue;
                var path = new RustNavMeshPath();
                if (!agent.CalculatePath(foot, path) || path.status != NavMeshPathStatus.PathComplete || path.GetPathLength() > 650f) continue;
                chosen = foot;
                Puts("RUSTBOTS_WORLD_GOAL " + JsonConvert.SerializeObject(new { Start = Point(episodeStart), Goal = Point(foot), Net = Vector3.Distance(episodeStart, foot), PathLength = path.GetPathLength(), Road = RoadEvidence(foot) }));
                return true;
            }
            return false;
        }

        private object RoadEvidence(Vector3 position)
        {
            float best = float.MaxValue;
            int roadIndex = -1, segment = -1;
            Vector3 nearest = Vector3.zero, a = Vector3.zero, b = Vector3.zero;
            for (int r = 0; r < TerrainMeta.Path.Roads.Count; r++)
            {
                var points = TerrainMeta.Path.Roads[r].Path.Points;
                for (int i = 1; i < points.Length; i++)
                {
                    Vector3 delta = points[i] - points[i - 1];
                    float t = delta.sqrMagnitude == 0 ? 0 : Mathf.Clamp01(Vector3.Dot(position - points[i - 1], delta) / delta.sqrMagnitude);
                    Vector3 q = points[i - 1] + delta * t;
                    float d = Vector3.Distance(q, position);
                    if (d < best) { best = d; roadIndex = r; segment = i - 1; nearest = q; a = points[i - 1]; b = points[i]; }
                }
            }
            return new { Kind = "TerrainMeta.Path.Roads/Path.Points", RoadIndex = roadIndex, SegmentIndex = segment,
                SegmentStart = Point(a), SegmentEnd = Point(b), Nearest = Point(nearest), Distance = best,
                Arrival = Point(position), EpisodeStart = Point(episodeStart), EpisodeNet = Vector3.Distance(episodeStart, position), PathStatus = "PathComplete" };
        }

        private void StartRoute(Vector3 destination, string phase)
        {
            goal = destination; stage = phase;
            agent.stoppingDistance = phase == "ROAD" ? 1f : 0.2f;
            if (Vector3.Distance(npc.transform.position, goal) <= (phase == "ROAD" ? 1.8f : 0.55f)) { GoalArrived(); return; }
            StartLeg();
        }

        private void StartLeg()
        {
            legActive = false;
            if (completed >= 48) { Finish("PARTIAL", "Bounded segment budget reached"); return; }
            traveled = 0f; repaths = 0; stuckCount = 0;
            start = progressPosition = npc.transform.position;
            legStarted = progressTime = Time.realtimeSinceStartup;
            if (!SelectTarget(out target)) { Finish("PARTIAL", "No complete local path towards world goal"); return; }
            legActive = true;
            agent.isStopped = false;
            if (!agent.SetDestination(target)) { Finish("BLOCKED", "Agent rejected complete-path target"); return; }
            Puts("RUSTBOTS_LEG_START " + JsonConvert.SerializeObject(new { Leg = completed + 1, Stage = stage, Start = Point(start), Target = Point(target), PathStatus = "PathComplete" }));
        }

        private void TickProbe()
        {
            if (npc == null || npc.IsDestroyed || agent == null) { Finish("BLOCKED", "Probe entity lost"); return; }
            float now = Time.realtimeSinceStartup;
            float dt = now - previousTime;
            if (dt <= 0f) return;
            Vector3 pos = npc.transform.position;
            float step = Vector3.Distance(previous, pos);
            if (now - previousTime > 1.5f || step > 5f || step > 6f * (now - previousTime) + 1f)
            { Finish("BLOCKED", "Discontinuous position evidence; displacement rejected"); return; }
            total += step;
            if (legActive) traveled += step;
            previous = pos; previousTime = now;
            var sample = new { Time = now, Leg = completed + 1, Stage = stage, Position = Point(pos), Target = Point(target),
                Traveled = total, Net = Vector3.Distance(episodeStart, pos), PathStatus = agent.pathStatus.ToString(), Speed = step / dt, Stuck = stuckCount, Repath = repaths };
            samples.Add(sample);
            Puts("RUSTBOTS_TRAVEL_SAMPLE " + JsonConvert.SerializeObject(sample));
            if (stage == "HIT") { HitBarrel(now); return; }
            if (stage == "DROP_WAIT") { if (now >= dropWaitUntil) CollectDrops(); return; }
            if (!legActive) return;
            float arrivalRadius = stage != "ROAD" && Vector3.Distance(target, goal) < 0.1f ? 0.55f : 1.8f;
            if (Vector3.Distance(pos, target) <= arrivalRadius)
            {
                legs.Add(new { Leg = completed + 1, Stage = stage, Status = "ARRIVED", Start = Point(start), Target = Point(target), End = Point(pos),
                    Elapsed = now - legStarted, Traveled = traveled, Net = Vector3.Distance(start, pos), PathStatus = "PathComplete", Stuck = stuckCount, Repath = repaths });
                completed++; legActive = false;
                if (Vector3.Distance(pos, goal) <= (stage == "ROAD" ? 1.8f : 0.55f)) GoalArrived(); else StartLeg();
                return;
            }
            if (Vector3.Distance(pos, progressPosition) >= 1f) { progressTime = now; progressPosition = pos; }
            if (now - progressTime >= 10f)
            {
                stuckCount++;
                Puts("RUSTBOTS_STUCK leg=" + (completed + 1));
                if (repaths >= 1) { Finish("PARTIAL", "STUCK after one bounded repath"); return; }
                repaths++;
                var path = new RustNavMeshPath();
                if (!agent.CalculatePath(target, path) || path.status != NavMeshPathStatus.PathComplete || !agent.SetDestination(target))
                { Finish("BLOCKED", "Bounded repath failed"); return; }
                progressTime = now; progressPosition = pos;
            }
            if (now - legStarted > 70f) Finish("PARTIAL", "Leg exceeded 70 seconds");
        }

        private void GoalArrived()
        {
            agent.isStopped = true;
            if (stage == "ROAD")
            {
                road = RoadEvidence(npc.transform.position);
                parts["OPEN_TRAVEL"] = total >= 250f && Vector3.Distance(episodeStart, npc.transform.position) >= 75f ? "GREEN" : "PARTIAL";
                Puts("RUSTBOTS_ROAD_ARRIVE " + JsonConvert.SerializeObject(road));
                BeginLoot("CRATE");
            }
            else if (stage == "CRATE_APPROACH")
            {
                bool ok = TransferContainer();
                parts["CRATE"] = ok ? "GREEN" : "PARTIAL";
                BeginLoot("BARREL");
            }
            else if (stage == "BARREL_APPROACH")
            {
                barrelBefore.AddRange(Contents(loot.inventory));
                Puts("RUSTBOTS_BARREL_BEFORE " + JsonConvert.SerializeObject(barrelBefore));
                stage = "HIT"; nextHit = Time.realtimeSinceStartup;
            }
            else if (stage == "DROP_APPROACH")
            {
                if (drop != null && !drop.IsDestroyed && drop.item != null) Transfer(drop.item, null, drop, "BARREL");
                NextDrop();
            }
        }

        private bool IsKind(LootContainer container, string kind)
        {
            string name = container.ShortPrefabName.ToLowerInvariant();
            return kind == "BARREL" ? name.Contains("barrel") : name.StartsWith("crate_normal", StringComparison.Ordinal);
        }

        private bool Approach(BaseEntity entity, out Vector3 position)
        {
            position = Vector3.zero;
            if (entity == null || entity.IsDestroyed || entity.OwnerID != 0 || entity.IsLocked()) return false;
            for (int i = 0; i < 16; i++)
            {
                float angle = i * Mathf.PI / 4f;
                Vector3 p = entity.transform.position + new Vector3(Mathf.Cos(angle), 0, Mathf.Sin(angle)) * (i < 8 ? 1.5f : 2.1f);
                p.y = TerrainMeta.HeightMap.GetHeight(p);
                NavMeshHit hit; Vector3 foot;
                if (!agent.SamplePosition(p, out hit, 1f, false) || !ClearGround(hit.position, out foot)) continue;
                var path = new RustNavMeshPath();
                if (Vector3.Distance(foot, entity.transform.position) > 2.6f || !agent.CalculatePath(foot, path) || path.status != NavMeshPathStatus.PathComplete || path.GetPathLength() > 180f) continue;
                position = foot; return true;
            }
            return false;
        }

        private void BeginLoot(string kind)
        {
            lootKind = kind; loot = null;
            Vector3 approach = Vector3.zero;
            foreach (var entity in BaseNetworkable.serverEntities.OfType<LootContainer>()
                .Where(e => !e.IsDestroyed && IsKind(e, kind) && e.inventory != null && e.inventory.itemList.Count > 0 &&
                    Vector3.Distance(e.transform.position, npc.transform.position) <= 100f)
                .OrderBy(e => Vector3.Distance(e.transform.position, npc.transform.position)).Take(20))
            {
                if (!Approach(entity, out approach)) continue;
                loot = entity; lootSource = "NATURAL"; break;
            }
            if (loot == null)
            {
                lootSource = "FIXTURE_NATIVE_PREFAB";
                var paths = GameManifest.Current.entities.Where(p => p.EndsWith(".prefab", StringComparison.OrdinalIgnoreCase) &&
                    p.IndexOf("/modding/", StringComparison.OrdinalIgnoreCase) < 0 && p.IndexOf("invisible", StringComparison.OrdinalIgnoreCase) < 0 &&
                    (kind == "BARREL" ? p.IndexOf("loot-barrel", StringComparison.OrdinalIgnoreCase) >= 0 || p.IndexOf("loot_barrel", StringComparison.OrdinalIgnoreCase) >= 0 :
                        p.IndexOf("crate_normal_2.prefab", StringComparison.OrdinalIgnoreCase) >= 0)).OrderBy(p => p).ToArray();
                string selected = null;
                foreach (var p in paths)
                {
                    var obj = GameManager.server.FindPrefab(p);
                    var c = obj == null ? null : obj.GetComponent<LootContainer>();
                    if (c != null && c.initialLootSpawn) { selected = p; break; }
                }
                if (selected != null)
                {
                    for (int i = 0; i < 16; i++)
                    {
                        float angle = i * Mathf.PI / 4f;
                        Vector3 p = npc.transform.position + new Vector3(Mathf.Cos(angle), 0, Mathf.Sin(angle)) * (8f + i / 8 * 4f);
                        p.y = TerrainMeta.HeightMap.GetHeight(p);
                        NavMeshHit hit; Vector3 foot;
                        if (!agent.SamplePosition(p, out hit, 1f, false) || !ClearGround(hit.position, out foot)) continue;
                        var entity = GameManager.server.CreateEntity(selected, foot, Quaternion.identity, true);
                        if (entity == null) break;
                        entity.enableSaving = false; fixtures.Add(entity); entity.Spawn();
                        loot = entity as LootContainer;
                        // Spawn -> LootContainer.ServerInit -> SpawnLoot is the sole initializer.
                        if (loot != null && Approach(loot, out approach)) break;
                        Finish("PARTIAL", "Native fixture approach unavailable; no repeated fixture spawning"); return;
                    }
                }
            }
            if (loot == null || loot.inventory == null || loot.inventory.itemList.Count == 0)
            {
                parts[kind] = "PARTIAL";
                Puts("RUSTBOTS_INTERACT_UNAVAILABLE " + kind + " native loot/approach missing");
                if (kind == "CRATE") BeginLoot("BARREL"); else CompleteJourney();
                return;
            }
            Puts("RUSTBOTS_INTERACT_START " + JsonConvert.SerializeObject(new { Kind = kind, Source = lootSource, Prefab = loot.PrefabName,
                Type = loot.GetType().FullName, Position = Point(loot.transform.position), Approach = Point(approach), Before = Contents(loot.inventory) }));
            StartRoute(approach, kind + "_APPROACH");
        }

        private bool Reach(BaseEntity entity, out float distance)
        {
            distance = entity == null ? float.MaxValue : Vector3.Distance(npc.transform.position, entity.transform.position);
            if (entity == null || entity.IsDestroyed || distance > 2.8f || entity.OwnerID != 0 || entity.IsLocked()) return false;
            Vector3 eye = npc.transform.position + Vector3.up * 1.2f;
            Vector3 end = entity.transform.position + Vector3.up * (entity is DroppedItem ? 0.05f : 0.6f);
            Vector3 delta = end - eye;
            foreach (var hit in Physics.RaycastAll(eye, delta.normalized, delta.magnitude, Physics.DefaultRaycastLayers, QueryTriggerInteraction.Ignore))
            {
                var owner = hit.collider.GetComponentInParent<BaseEntity>();
                if (owner == npc || owner == entity) continue;
                Puts("RUSTBOTS_LOS_BLOCKED " + hit.collider.name);
                return false;
            }
            return true;
        }

        private bool TransferContainer()
        {
            float distance;
            if (loot == null || loot.inventory == null || loot.inventory.IsLocked() || !Reach(loot, out distance)) return false;
            var before = Contents(loot.inventory);
            foreach (var item in loot.inventory.itemList.ToArray()) Transfer(item, loot.inventory, loot, "CRATE");
            Puts("RUSTBOTS_CRATE_OPEN " + JsonConvert.SerializeObject(new { Source = lootSource, Before = before, After = Contents(loot.inventory), Inventory = Contents(inventory) }));
            return before.Count > 0 && loot.inventory.itemList.Count == 0;
        }

        private bool Transfer(Item item, ItemContainer source, BaseEntity entity, string kind)
        {
            float distance;
            if (item == null || !Reach(entity, out distance)) return false;
            var worldItem = entity as WorldItem;
            if (worldItem != null && !worldItem.allowPickup) { Puts("RUSTBOTS_PICKUP_DISABLED"); return false; }
            var row = Row(item);
            Vector3 sourcePosition = entity.transform.position;
            if (moved.ContainsKey(row.Uid) || inventory.itemList.Any(i => i.uid == item.uid)) { anomalies.Add("Duplicate source UID"); return false; }
            int sourceBefore = source == null ? (entity is DroppedItem && ((DroppedItem)entity).item == item ? item.amount : 0) : source.itemList.Where(i => i.uid == item.uid).Sum(i => i.amount);
            if (sourceBefore != row.Amount) { anomalies.Add("Source ownership mismatch"); return false; }
            // No stacking: the same native Item UID must survive the transfer.
            if (!item.MoveToContainer(inventory, -1, false)) { Puts("RUSTBOTS_TRANSFER_REJECTED " + row.Uid); return false; }
            int sourceAfter = source == null ? (entity != null && !entity.IsDestroyed && ((DroppedItem)entity).item == item ? item.amount : 0) : source.itemList.Where(i => i.uid.Value.ToString() == row.Uid).Sum(i => i.amount);
            int destAfter = inventory.itemList.Where(i => i.uid.Value.ToString() == row.Uid).Sum(i => i.amount);
            if (sourceAfter != 0 || destAfter != row.Amount) anomalies.Add("Source/destination delta mismatch");
            moved[row.Uid] = row.Shortname + ":" + row.Amount;
            var receipt = new { Kind = kind, Source = lootSource, row.Uid, row.Shortname, row.Amount, Distance = distance, LineOfSight = true,
                SourceBefore = sourceBefore, SourceAfter = sourceAfter, DestBefore = 0, DestAfter = destAfter, Actor = Point(npc.transform.position), SourcePosition = Point(sourcePosition) };
            transfers.Add(receipt);
            Puts("RUSTBOTS_ITEM_TRANSFER " + JsonConvert.SerializeObject(receipt));
            return sourceAfter == 0 && destAfter == row.Amount;
        }

        private void HitBarrel(float now)
        {
            if (now < nextHit) return;
            float distance;
            if (loot == null || loot.IsDestroyed || !Reach(loot, out distance) || hitCount >= 20)
            { parts["BARREL"] = "PARTIAL"; CompleteJourney(); return; }
            float before = loot.Health();
            var preDrops = new HashSet<DroppedItem>(BaseNetworkable.serverEntities.OfType<DroppedItem>());
            var hit = new HitInfo(npc, loot, Rust.DamageType.Blunt, 20f, loot.transform.position);
            hit.DidHit = true;
            loot.OnAttacked(hit);
            hitCount++;
            bool dead = loot == null || loot.IsDestroyed || loot.IsDead();
            float after = dead ? 0f : loot.Health();
            var receipt = new { Hit = hitCount, Before = before, After = after, Damage = 20f, DamageType = "Blunt", Initiator = npc.GetType().FullName, Distance = distance, LineOfSight = true, Native = "LootContainer.OnAttacked(HitInfo)" };
            hits.Add(receipt);
            Puts("RUSTBOTS_BARREL_HIT " + JsonConvert.SerializeObject(receipt));
            nextHit = now + 1f;
            if (dead)
            {
                destroyedByDamage = after < before;
                nativeDrops.AddRange(BaseNetworkable.serverEntities.OfType<DroppedItem>().Where(d => !preDrops.Contains(d) && d.item != null &&
                    barrelBefore.Any(b => b.Uid == d.item.uid.Value.ToString())));
                foreach (var d in nativeDrops) { barrelDrops.Add(Row(d.item)); d.enableSaving = false; }
                Puts("RUSTBOTS_BARREL_DROP " + JsonConvert.SerializeObject(new { Before = barrelBefore, Drops = barrelDrops, DestroyedByDamage = destroyedByDamage }));
                stage = "DROP_WAIT"; dropWaitUntil = now + 2f;
            }
        }

        private void CollectDrops()
        {
            foreach (var before in barrelBefore)
                if (barrelDrops.Where(d => d.Uid == before.Uid && d.Shortname == before.Shortname).Sum(d => d.Amount) != before.Amount) barrelDropConserved = false;
            dropIndex = 0; NextDrop();
        }

        private void NextDrop()
        {
            while (dropIndex < nativeDrops.Count)
            {
                drop = nativeDrops[dropIndex++];
                if (drop == null || drop.IsDestroyed || drop.item == null) continue;
                float distance; Vector3 approach;
                if (Reach(drop, out distance)) { Transfer(drop.item, null, drop, "BARREL"); continue; }
                if (Approach(drop, out approach)) { StartRoute(approach, "DROP_APPROACH"); return; }
                Puts("RUSTBOTS_DROP_UNREACHABLE " + JsonConvert.SerializeObject(new { Item = Row(drop.item), Position = Point(drop.transform.position) }));
            }
            parts["BARREL"] = destroyedByDamage && barrelDropConserved && barrelDrops.Count > 0 && barrelDrops.All(d => moved.ContainsKey(d.Uid)) ? "GREEN" : "PARTIAL";
            CompleteJourney();
        }

        private void CompleteJourney()
        {
            var items = Contents(inventory);
            if (items.Count != moved.Count + initialInventory.Count || items.Any(i =>
                !initialInventory.Any(b => b.Uid == i.Uid && b.Shortname == i.Shortname && b.Amount == i.Amount) &&
                (!moved.ContainsKey(i.Uid) || moved[i.Uid] != i.Shortname + ":" + i.Amount))) anomalies.Add("Final owned inventory mismatch");
            if (items.Count > 0 && anomalies.Count == 0)
            {
                using (var snapshot = inventory.Save()) File.WriteAllBytes(inventoryPath, snapshot.ToProtoBytes());
                expectedInventory = items;
                saved = true;
                parts["INVENTORY"] = "GREEN";
            }
            else parts["INVENTORY"] = "PARTIAL";
            Finish(parts.Values.All(p => p == "GREEN") ? "GREEN" : "PARTIAL", "Bounded journey complete; inventory restart requires separate restore run");
        }

        private void RestoreInventory()
        {
            stage = "RESTORE";
            expectedInventory = JsonConvert.DeserializeObject<List<ItemRow>>(File.ReadAllText(Path.Combine(root, "oxide", "data", "RustBotsWorldRoam.expected.json")));
            inventory = new ItemContainer();
            inventory.ServerInitialize(null, 48);
            using (var snapshot = ProtoBuf.ItemContainer.Deserialize(File.ReadAllBytes(inventoryPath))) inventory.Load(snapshot);
            restored = expectedInventory.Count > 0 && InventoryKey(expectedInventory) == InventoryKey(Contents(inventory));
            restoreExpected = expectedInventory.ToList(); restoreActual = Contents(inventory);
            Puts("RUSTBOTS_INVENTORY_RESTORE " + JsonConvert.SerializeObject(new { Expected = expectedInventory, Actual = Contents(inventory), Restored = restored }));
            if (restored && Environment.GetEnvironmentVariable("RUST_BOTS_RESUME_JOURNEY") == "1")
            {
                initialInventory = Contents(inventory);
                stage = "ROAD"; beginRequested = true; navWaitStarted = Time.realtimeSinceStartup; WaitForNavigation();
                return;
            }
            Finish(restored ? "GREEN" : "PARTIAL", restored ? "Native ItemContainer restored after server restart" : "Native restore mismatch");
        }

        private static float[] Point(Vector3 p) { return new[] { p.x, p.y, p.z }; }

        private void Finish(string status, string reason)
        {
            if (finished) return;
            finished = true; active = false;
            if (npc != null && legActive)
                legs.Add(new { Leg = completed + 1, Status = "FAILED", Reason = reason, Start = Point(start), Target = Point(target),
                    End = Point(npc.transform.position), Elapsed = Time.realtimeSinceStartup - legStarted, Traveled = traveled,
                    Net = Vector3.Distance(start, npc.transform.position), PathStatus = "PathComplete", CurrentPathStatus = agent == null ? null : agent.pathStatus.ToString(), Stuck = stuckCount, Repath = repaths });
            var result = new { RunId = token, Status = status, Reason = reason, Backend = backend, Prefab = prefab,
                Mode = stage == "RESTORE" ? "RESTORE" : "JOURNEY", Parts = parts, ActorType = npc == null ? null : npc.GetType().FullName,
                CompletedLegs = completed, TotalTraveled = total, RejectedSamples = rejectedSamples,
                Rejections = rejections, RejectionExamples = rejectionExamples, Legs = legs, Samples = samples, Road = road,
                Transfers = transfers, InitialInventory = initialInventory, Inventory = Contents(inventory),
                Barrel = new { Source = lootSource, Before = barrelBefore, Hits = hits, Drops = barrelDrops, DestroyedByDamage = destroyedByDamage, NativeDropConserved = barrelDropConserved },
                Conservation = new { Ok = anomalies.Count == 0, Anomalies = anomalies }, Persistence = new { Saved = saved, Restored = restored, Expected = expectedInventory, RestoreExpected = restoreExpected, RestoreActual = restoreActual } };
            if (!string.IsNullOrEmpty(root))
            {
                string path = Path.Combine(root, "oxide", "data", "RustBotsWorldRoam.result.json");
                File.WriteAllText(path + ".tmp", JsonConvert.SerializeObject(result, Formatting.Indented));
                File.Move(path + ".tmp", path);
            }
            Puts("RUSTBOTS_WORLD_RESULT " + JsonConvert.SerializeObject(result));
            CleanupNpc();
        }

        private void CleanupNpc()
        {
            if (npc != null && !npc.IsDestroyed) npc.Kill(); npc = null;
            foreach (var fixture in fixtures) if (fixture != null && !fixture.IsDestroyed) fixture.Kill();
            // Kill is cleanup only, never evidence of a barrel hit or pickup.
            foreach (var d in nativeDrops) if (d != null && !d.IsDestroyed) d.Kill();
            if (inventory != null) { inventory.Kill(); inventory = null; }
        }
        private void Unload() { CleanupNpc(); }
    }
}
