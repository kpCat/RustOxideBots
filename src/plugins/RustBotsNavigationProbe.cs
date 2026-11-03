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
    [Info("RustBotsNavigationProbe", "RustOxideBots", "0.1.0")]
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

        private bool IsTestRoot()
        {
            root = Environment.GetEnvironmentVariable("RUST_BOTS_TEST_ROOT");
            token = Environment.GetEnvironmentVariable("RUST_BOTS_RUN_TOKEN");
            Guid parsed;
            if (string.IsNullOrEmpty(root) || !Guid.TryParseExact(token, "N", out parsed)) return false;
            string cwd = Path.GetFullPath(Directory.GetCurrentDirectory()).TrimEnd('\\', '/');
            if (!string.Equals(cwd, Path.GetFullPath(root).TrimEnd('\\', '/'), StringComparison.OrdinalIgnoreCase)) return false;
            if (!ConVar.Server.identity.Equals("rustbots_probe_" + token, StringComparison.Ordinal)) return false;
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
                    if (active && !finished) TickProbe();
                }
                catch (Exception ex) { Finish("BLOCKED", "Probe exception: " + ex.GetType().Name); }
            });
            timer.Once(5f, () =>
            {
                try { BeginProbe(); }
                catch (Exception ex) { Finish("BLOCKED", "Probe initialization: " + ex.GetType().Name); }
            });
        }

        private void BeginProbe()
        {
            // Discover installed prefabs; no map-specific coordinates or hard-coded prefab path.
            var choices = GameManifest.Current.entities
                .Where(p => p.EndsWith(".prefab") && p.IndexOf("scientist", StringComparison.OrdinalIgnoreCase) >= 0)
                .OrderByDescending(p => p.IndexOf("roam", StringComparison.OrdinalIgnoreCase) >= 0)
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

        private bool ClearGround(Vector3 p)
        {
            RaycastHit hit;
            if (p.y < 3f || !Physics.Raycast(p + Vector3.up * 3f, Vector3.down, out hit, 6f,
                Physics.DefaultRaycastLayers, QueryTriggerInteraction.Ignore)) return false;
            if (Mathf.Abs(hit.point.y - p.y) > 0.7f || hit.normal.y < 0.92f) return false;
            return !Physics.CheckCapsule(p + Vector3.up * 0.55f, p + Vector3.up * 1.75f,
                0.4f, Physics.DefaultRaycastLayers, QueryTriggerInteraction.Ignore);
        }

        private bool FindSpawn(RustNavMeshAgent settings, out Vector3 spawn)
        {
            // Terrain-relative grid; actual points are sampled on the selected live backend.
            float spacing = Mathf.Min(80f, TerrainMeta.Size.x / 20f);
            for (int x = -6; x <= 6; x++) for (int z = -6; z <= 6; z++)
            {
                Vector3 candidate = new Vector3(x * spacing, 0f, z * spacing);
                candidate.y = TerrainMeta.HeightMap.GetHeight(candidate);
                Vector3 sample;
                if (!SampleInitial(settings, candidate, out sample) || !ClearGround(sample)) { rejectedSamples++; continue; }
                spawn = sample; return true;
            }
            spawn = Vector3.zero; return false;
        }

        private bool SampleInitial(RustNavMeshAgent settings, Vector3 candidate, out Vector3 point)
        {
            point = Vector3.zero;
            if (ConVar.AI.useUnityNavmesh)
            {
                NavMeshHit hit;
                var filter = new NavMeshQueryFilter { agentTypeID = settings.agentTypeID, areaMask = settings.areaMask };
                if (!NavMesh.SamplePosition(candidate, out hit, 1.5f, filter)) return false;
                point = hit.position; return true;
            }
            var navigation = RustNavigation.Instance;
            if (navigation == null || !navigation.IsDefaultNavmeshBuilt()) return false;
            NavHit navHit;
            if (!navigation.DefaultNavmesh.SamplePosition(new NavVector3(candidate), out navHit, new Vector3(1.5f, 2f, 1.5f), false)) return false;
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
                if (!agent.SamplePosition(candidate, out hit, 1.5f, false) || !ClearGround(hit.position)) { rejectedSamples++; continue; }
                if (Vector3.Distance(from, hit.position) < 28f) { rejectedSamples++; continue; }
                var path = new RustNavMeshPath();
                if (!agent.CalculatePath(hit.position, path) || path.status != NavMeshPathStatus.PathComplete || path.GetPathLength() < 28f)
                { rejectedSamples++; continue; }
                chosen = hit.position; return true;
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
                CompletedLegs = completed, TotalTraveled = total + (completed < 3 ? traveled : 0f), RejectedSamples = rejectedSamples, Legs = legs };
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
