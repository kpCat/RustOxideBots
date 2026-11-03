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
    [Info("RustBotsNavigationProbe", "RustOxideBots", "0.2.0")]
    [Description("One test-only humanoid navigation probe; inert outside its isolated runner.")]
    public class RustBotsNavigationProbe : RustPlugin
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
            return File.Exists(marker) && File.ReadAllText(marker) == token;
        }

        private void OnServerInitialized()
        {
            if (!IsTestRoot()) { Puts("Probe inert: isolated runner marker/identity missing."); return; }
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
                catch (Exception ex) { Finish("BLOCKED", "Probe exception: " + ex.GetType().Name); }
            });
            timer.Once(5f, () =>
            {
                try { beginRequested = true; navWaitStarted = Time.realtimeSinceStartup; WaitForNavigation(); }
                catch (Exception ex) { Finish("BLOCKED", "Probe initialization: " + ex.GetType().Name); }
            });
        }

        private void WaitForNavigation()
        {
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
            foreach (bool modern in new[] { true, false })
            {
                foreach (string path in choices)
                {
                    var obj = GameManager.server.FindPrefab(path);
                    if (obj == null || obj.GetComponent<RustNavMeshAgent>() == null) continue;
                    if (modern ? obj.GetComponent<ScientistNPC2>() == null : obj.GetComponent<ScientistNPC>() == null) continue;
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
            active = true;
            StartLeg();
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
            // A different heading per leg, bounded alternatives; every target needs a complete real path.
            for (int i = 0; i < 24; i++)
            {
                float angle = (i * 137.5f + completed * 71f) * Mathf.Deg2Rad;
                Vector3 candidate = from + new Vector3(Mathf.Cos(angle), 0, Mathf.Sin(angle)) * (32f + (i % 3) * 4f);
                candidate.y = TerrainMeta.HeightMap.GetHeight(candidate);
                NavMeshHit hit;
                Vector3 foot;
                if (!agent.SamplePosition(candidate, out hit, 2.5f, false)) { Reject("AgentNavSampleMiss", candidate, new { Radius = 2.5f, AgentType = agent.agentTypeID }); continue; }
                if (!ClearGround(hit.position, out foot)) continue;
                if (Vector3.Distance(from, foot) < 28f) { Reject("TargetTooNear", foot, null); continue; }
                var path = new RustNavMeshPath();
                if (!agent.CalculatePath(foot, path) || path.status != NavMeshPathStatus.PathComplete || path.GetPathLength() < 28f)
                { Reject("AgentIncompletePath", foot, new { Status = path.status.ToString(), Length = path.GetPathLength() }); continue; }
                chosen = foot; return true;
            }
            chosen = Vector3.zero; return false;
        }

        private void StartLeg()
        {
            legActive = false;
            traveled = 0f; repaths = 0; stuckCount = 0;
            start = previous = progressPosition = npc.transform.position;
            previousTime = legStarted = progressTime = Time.realtimeSinceStartup;
            if (!SelectTarget(out target)) { Finish("BLOCKED", "No reachable dynamic target after 24 candidates"); return; }
            legActive = true;
            if (!agent.SetDestination(target)) { Finish("BLOCKED", "Agent rejected complete-path target"); return; }
            Puts("RUSTBOTS_LEG_START " + JsonConvert.SerializeObject(new { Leg = completed + 1, Start = Point(start), Target = Point(target), PathStatus = agent.pathStatus.ToString() }));
        }

        private void TickProbe()
        {
            if (npc == null || npc.IsDestroyed || agent == null) { Finish("BLOCKED", "Probe entity lost"); return; }
            float now = Time.realtimeSinceStartup;
            Vector3 pos = npc.transform.position;
            float step = Vector3.Distance(previous, pos);
            if (now - previousTime > 1.5f || step > 5f || step > 6f * (now - previousTime) + 1f)
            { Finish("BLOCKED", "Discontinuous position evidence; displacement rejected"); return; }
            traveled += step;
            previous = pos; previousTime = now;
            Puts("RUSTBOTS_SAMPLE " + JsonConvert.SerializeObject(new {
                Leg = completed + 1, Position = Point(pos), Target = Point(target), Elapsed = now - legStarted,
                Traveled = traveled, Net = Vector3.Distance(start, pos), PathStatus = agent.pathStatus.ToString(),
                HasPath = agent.hasPath, Moving = !agent.isStopped && agent.hasPath, Remaining = agent.remainingDistance,
                Stuck = stuckCount, Repath = repaths
            }));
            if (Vector3.Distance(pos, target) <= 1.8f)
            {
                legs.Add(new { Leg = completed + 1, Status = "ARRIVED", Start = Point(start), Target = Point(target), End = Point(pos),
                    Elapsed = now - legStarted, Traveled = traveled, Net = Vector3.Distance(start, pos), PathStatus = agent.pathStatus.ToString(), Stuck = stuckCount, Repath = repaths });
                total += traveled; completed++; legActive = false;
                if (completed == 3) Finish(total >= 60f ? "GREEN" : "PARTIAL", total >= 60f ? "Three complete navigation legs" : "Travel below 60m");
                else StartLeg();
                return;
            }
            if (Vector3.Distance(pos, progressPosition) >= 1f) { progressTime = now; progressPosition = pos; }
            if (now - progressTime >= 10f)
            {
                stuckCount++;
                Puts("RUSTBOTS_STUCK leg=" + (completed + 1));
                if (repaths >= 1) { Finish("BLOCKED", "STUCK after one bounded repath"); return; }
                repaths++;
                var path = new RustNavMeshPath();
                if (!agent.CalculatePath(target, path) || path.status != NavMeshPathStatus.PathComplete || !agent.SetDestination(target))
                { Finish("BLOCKED", "Bounded repath failed"); return; }
                progressTime = now; progressPosition = pos;
            }
            if (now - legStarted > 70f) Finish("BLOCKED", "Leg exceeded 70 seconds");
        }

        private static float[] Point(Vector3 p) { return new[] { p.x, p.y, p.z }; }

        private void Finish(string status, string reason)
        {
            if (finished) return;
            finished = true; active = false;
            if (npc != null && legActive)
                legs.Add(new { Leg = completed + 1, Status = "FAILED", Reason = reason, Start = Point(start), Target = Point(target),
                    End = Point(npc.transform.position), Elapsed = Time.realtimeSinceStartup - legStarted, Traveled = traveled,
                    Net = Vector3.Distance(start, npc.transform.position), Stuck = stuckCount, Repath = repaths });
            var result = new { RunId = token, Status = status, Reason = reason, Backend = backend, Prefab = prefab,
                CompletedLegs = completed, TotalTraveled = total + (completed < 3 ? traveled : 0f), RejectedSamples = rejectedSamples,
                Rejections = rejections, RejectionExamples = rejectionExamples, Legs = legs };
            if (!string.IsNullOrEmpty(root))
            {
                string path = Path.Combine(root, "oxide", "data", "RustBotsNavigationProbe.result.json");
                File.WriteAllText(path + ".tmp", JsonConvert.SerializeObject(result, Formatting.Indented));
                File.Move(path + ".tmp", path);
            }
            Puts("RUSTBOTS_RESULT " + JsonConvert.SerializeObject(result));
            CleanupNpc();
        }

        private void CleanupNpc() { if (npc != null && !npc.IsDestroyed) npc.Kill(); npc = null; }
        private void Unload() { CleanupNpc(); }
    }
}
