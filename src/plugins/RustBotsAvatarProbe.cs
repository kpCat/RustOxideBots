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
    [Info("RustBotsAvatarProbe", "RustOxideBots", "0.1.1")]
    [Description("Isolated player-derived NPC, native inventory/held and RustNav gate.")]
    public class RustBotsAvatarProbe : RustPlugin
    {
        private string root, token, prefab, backend;
        private NPCPlayer npc;
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
        private sealed class ItemRow
        {
            public string Uid, Shortname, ContainerUid, OwnerNetId;
            public int Amount;
            public float Condition, MaxCondition;
        }
        private sealed class EquipmentRow
        {
            public string ActorNetId, RequestedUid, ActiveUid, ItemUid, ContainerUid, OwnerNetId;
            public string HeldNetId, HeldType, HeldPrefab, HeldOwnerNetId, HeldParentNetId;
            public bool IsHeld, LimitNetworking;
            public string NetworkFlags;
        }
        private Item fixture;
        private object actorReceipt, inventoryReceipt;
        private EquipmentRow equipment, equipmentFinal;
        private List<ItemRow> beforeInventory = new List<ItemRow>();
        private readonly List<object> negatives = new List<object>(), samples = new List<object>(), discovery = new List<object>();
        private readonly Dictionary<string, string> parts = new Dictionary<string, string> {
            {"AVATAR","NOT_VERIFIED"},{"NAV","NOT_VERIFIED"},{"PLAYER_INVENTORY","NOT_VERIFIED"},
            {"HELD_ITEM","NOT_VERIFIED"},{"NEGATIVE","NOT_VERIFIED"}
        };
        private int spawnCount, fixturesCreated;
        private string plannedPathStatus, issuedPathStatus;
        private float speedBeforeLeg, issuedSpeed, plannedPathLength;
        private static string NetId(BaseNetworkable entity) { return entity == null || entity.net == null ? null : entity.net.ID.Value.ToString(); }
        private static ItemRow Row(Item item)
        {
            return new ItemRow { Uid=item.uid.Value.ToString(), Shortname=item.info.shortname, Amount=item.amount,
                Condition=item.condition, MaxCondition=item.maxCondition, ContainerUid=item.parent == null ? null : item.parent.uid.Value.ToString(),
                OwnerNetId=NetId(item.GetOwnerPlayer()) };
        }
        private List<ItemRow> Contents()
        {
            if(npc == null || npc.inventory == null) return new List<ItemRow>();
            return new[] {npc.inventory.containerMain,npc.inventory.containerBelt,npc.inventory.containerWear}
                .Where(c=>c != null).SelectMany(c=>c.itemList).Select(Row).OrderBy(i=>i.Uid,StringComparer.Ordinal).ToList();
        }
        private static string Key(List<ItemRow> rows) { return JsonConvert.SerializeObject(rows); }

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
            return File.Exists(marker) && File.ReadAllText(marker) == token && Environment.GetEnvironmentVariable("RUST_BOTS_SCENARIO") == "PLAYER_AVATAR";
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
                catch (Exception ex) { PrintError(ex.ToString()); Finish(npc == null ? "BLOCKED" : "PARTIAL", "Avatar exception: " + ex.Message); }
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
            if (ConVar.AI.useUnityNavmesh) { Finish("BLOCKED", "RustNav required; Unity backend rejected"); return; }
            // Discover installed prefabs; no map-specific coordinates or hard-coded prefab path.
            var choices = GameManifest.Current.entities
                .Where(p => p.EndsWith(".prefab") && p.IndexOf("npcplayer", StringComparison.OrdinalIgnoreCase) >= 0)
                .OrderByDescending(p => p.IndexOf("roam", StringComparison.OrdinalIgnoreCase) >= 0)
                .ThenBy(p => p.IndexOf("heavy", StringComparison.OrdinalIgnoreCase) >= 0)
                .ThenBy(p => p).ToArray();
            GameObject selected = null;
            foreach (string path in choices)
            {
                var obj = GameManager.server.FindPrefab(path);
                var player = obj == null ? null : obj.GetComponent<NPCPlayer>();
                if (player == null) continue;
                var navAgent = obj.GetComponent<RustNavMeshAgent>();
                discovery.Add(new { Prefab=path, Type=player.GetType().FullName, IsBasePlayer=player is BasePlayer,
                    HasAgent=navAgent != null, player.LegacyNavigation, HasInventory=obj.GetComponent<PlayerInventory>() != null,
                    Brain=obj.GetComponent<BaseAIBrain>() == null ? null : obj.GetComponent<BaseAIBrain>().GetType().FullName });
                if (selected == null && navAgent != null && !player.LegacyNavigation && obj.GetComponent<PlayerInventory>() != null)
                { selected=obj; prefab=path; }
            }
            Puts("RUSTBOTS_AVATAR_DISCOVERY " + JsonConvert.SerializeObject(discovery));
            if (selected == null) { Finish("BLOCKED", "No installed player-derived prefab with native RustNav agent/inventory"); return; }
            var settings = selected.GetComponent<RustNavMeshAgent>();
            capsuleHeight = Mathf.Clamp(settings.height, 1.9f, 2.5f);
            Puts("RUSTBOTS_PREFAB " + JsonConvert.SerializeObject(new { Prefab = prefab,
                AgentType = settings.agentTypeID, AreaMask = settings.areaMask, Height = capsuleHeight, Radius = CapsuleRadius }));
            Vector3 spawn;
            if (!FindSpawn(settings, out spawn)) { Finish("BLOCKED", "No grounded clear spawn on active backend within bounded search"); return; }
            // Exactly one entity. No retry spawning and no reposition/warp after birth.
            var created = GameManager.server.CreateEntity(prefab, spawn, Quaternion.identity, true);
            npc = created as NPCPlayer;
            if (npc == null) { if(created != null)created.Kill(); Finish("BLOCKED", "CreateEntity did not return NPCPlayer"); return; }
            spawnCount++;
            npc.enableSaving = false;
            npc.Spawn();
            // Unity Start initializes AI after Spawn. Configure only after that lifecycle step.
            timer.Once(1f,()=> {
                if(finished)return;
                try { SetupActor(); }
                catch(Exception ex) { PrintError(ex.ToString()); Finish("PARTIAL","Actor setup: "+ex.Message); }
            });
        }

        private void SetupActor()
        {
            agent = npc.GetComponent<RustNavMeshAgent>();
            fsm = npc.GetComponent<FSMComponent>();
            brain = npc.GetComponent<BaseAIBrain>();
            if (fsm != null) fsm.SetFsmActive(false);
            if (brain != null) {
                brain.SetThinkMode(AIThinkMode.None);
                brain.SetEnabled(false);
                brain.AllowedToSleep=false;
                // InitializeAI may already have registered this brain for zone sleep.
                // Remove only our actor; a later zone WakeAI would restart TickMovement.
                foreach(var zone in AIInformationZone.zones)
                    if(zone != null)zone.UnregisterSleepableEntity(brain);
                if(brain.sleeping)((IAISleepable)brain).WakeAI();
                brain.CancelInvoke(brain.TickMovement);
            }
            actorReceipt = new {
                NetId=NetId(npc), Type=npc.GetType().FullName, Prefab=prefab, IsBasePlayer=npc is BasePlayer,
                IsNpc=npc.IsNpc, HasConnection=npc.net.connection != null, NativeBotId=npc.userID > 0 && npc.userID < 10000000,
                UserId=npc.userID.ToString(), PlayerFlags=npc.playerFlags.ToString(), Sleeping=npc.IsSleeping(), LegacyNavigation=npc.LegacyNavigation,
                Brain = brain == null ? null : brain.GetType().FullName,
                Fsm = fsm == null ? null : fsm.GetType().FullName,
                Agent=agent == null ? null : agent.GetType().FullName, Position=Point(npc.transform.position)
            };
            Puts("RUSTBOTS_AVATAR_ACTOR " + JsonConvert.SerializeObject(actorReceipt));
            if(!npc.IsNpc || npc.net.connection != null || npc.userID == 0 || npc.userID >= 10000000)
            { Finish("PARTIAL","Actor did not have engine-native bot identity without connection"); return; }
            parts["AVATAR"]="GREEN";
            // NPCPlayer.ServerInit disables direct agent position/rotation updates for its navigator.
            // This probe disables only its own brain, then uses the agent's normal native update loop.
            if(!EquipFixture()) { Finish("PARTIAL","Native PlayerInventory/held fixture gate failed"); return; }
            if (agent == null || !agent.IsNavMeshBuilt || !agent.isOnNavMesh)
            { Finish("PARTIAL", "Player-derived agent has no bound built RustNav mesh"); return; }
            agent.updatePosition = true;
            agent.updateRotation = true;
            agent.isStopped = false;
            agent.SetGait(RustNavMeshAgent.Speeds.Jog);
            agent.speed = 3f;
            agent.stoppingDistance = 1f;
            active = true;
            StartLeg();
        }

        private object Container(ItemContainer container)
        { return new { Uid=container.uid.Value.ToString(), OwnerNetId=NetId(container.GetOwnerPlayer()) }; }

        private EquipmentRow ReadEquipment()
        {
            var item=npc.GetActiveItem(); var held=npc.GetHeldEntity();
            return new EquipmentRow { ActorNetId=NetId(npc),RequestedUid=fixture == null ? null : fixture.uid.Value.ToString(),
                ActiveUid=item == null ? null : item.uid.Value.ToString(), ItemUid=item == null ? null : item.uid.Value.ToString(),
                ContainerUid=item == null || item.parent == null ? null : item.parent.uid.Value.ToString(), OwnerNetId=NetId(item == null ? null : item.GetOwnerPlayer()),
                HeldNetId=NetId(held), HeldType=held == null ? null : held.GetType().FullName, HeldPrefab=held == null ? null : held.PrefabName,
                HeldOwnerNetId=NetId(held == null ? null : held.GetOwnerPlayer()), HeldParentNetId=NetId(held == null ? null : held.GetParentEntity()),
                IsHeld=held != null && held.HasFlag((BaseEntity.Flags)1024), LimitNetworking=held != null && held.limitNetworking,
                NetworkFlags=held == null ? null : held.flags.ToString() };
        }
        private bool Equipped(EquipmentRow row)
        { return fixture != null && row.ActiveUid==fixture.uid.Value.ToString() && row.HeldNetId != null && row.HeldOwnerNetId==NetId(npc) && row.HeldParentNetId==NetId(npc) && row.IsHeld; }

        private bool TryActivate(ItemId requestedUid)
        {
            // UpdateActiveItem itself does not guarantee that an absent UID is refused.
            // Validate the actual native belt/root owner before calling this engine API.
            var item=npc.inventory.containerBelt.FindItemByUID(requestedUid);
            if(item == null || item.parent != npc.inventory.containerBelt || item.GetOwnerPlayer() != npc ||
                !npc.inventory.containerBelt.itemList.Contains(item)) return false;
            npc.UpdateActiveItem(requestedUid); return npc.GetActiveItem() == item && npc.GetHeldEntity() != null;
        }
        private void Negative(string kind, ItemId requestedUid, Item requested)
        {
            var before=Contents(); var activeBefore=npc.GetActiveItem();
            string foreignBefore=requested == null ? null : JsonConvert.SerializeObject(Row(requested));
            var lookup=npc.inventory.containerBelt.FindItemByUID(requestedUid);
            bool inBelt=lookup != null && lookup.parent == npc.inventory.containerBelt;
            bool absent=kind == "MISSING" && !ItemManager.GetAllItems().Any(i=>i.uid == requestedUid);
            if(kind == "MISSING" && !absent)throw new InvalidOperationException("Missing-UID fixture collided with real item");
            bool accepted=TryActivate(requestedUid);
            var after=Contents(); var activeAfter=npc.GetActiveItem();
            negatives.Add(new { Kind=kind,RequestedUid=requestedUid.Value.ToString(), FoundInBelt=inBelt,Accepted=accepted,
                BeforeActiveUid=activeBefore == null ? null : activeBefore.uid.Value.ToString(), AfterActiveUid=activeAfter == null ? null : activeAfter.uid.Value.ToString(),
                Before=before,After=after,ForeignOwnerNetId=requested == null ? null : NetId(requested.GetOwnerPlayer()) ?? ("container:"+requested.parent.uid.Value),
                ForeignBefore=foreignBefore,ForeignAfter=requested == null ? null : JsonConvert.SerializeObject(Row(requested)),
                Mechanism="GUARD_BEFORE_NATIVE_UPDATE_UID",Lookup="NATIVE_BELT_UID",LookupItemUid=lookup == null ? null : lookup.uid.Value.ToString(),
                MissingUidAbsentGlobally=absent,NativeApiCalled=inBelt && lookup.GetOwnerPlayer() == npc });
            if(accepted || Key(before)!=Key(after) || activeBefore != activeAfter) throw new InvalidOperationException("Negative activation mutated actor");
        }
        private bool EquipFixture()
        {
            var inv=npc.inventory;
            if(inv == null || inv.containerMain == null || inv.containerBelt == null || inv.containerWear == null) return false;
            beforeInventory=Contents();
            fixture=ItemManager.CreateByName("rock",1);
            if(fixture == null)return false;
            fixturesCreated++;
            // Find a free belt slot. Preserve the native default loadout and all of its UID.
            if(!fixture.MoveToContainer(inv.containerBelt,-1,false))return false;
            inventoryReceipt=new { ActorNetId=NetId(npc),Component=inv.GetType().Name,Main=Container(inv.containerMain),Belt=Container(inv.containerBelt),Wear=Container(inv.containerWear),Before=beforeInventory,After=Contents() };
            parts["PLAYER_INVENTORY"]="GREEN";
            if(!TryActivate(fixture.uid))return false;
            equipment=ReadEquipment(); equipmentFinal=equipment;
            Puts("RUSTBOTS_AVATAR_EQUIP " + JsonConvert.SerializeObject(equipment));
            if(!Equipped(equipment))return false;
            parts["HELD_ITEM"]="GREEN";
            Negative("MISSING",new ItemId(ulong.MaxValue),null);
            // Use a real existing world item, without creating a second actor or another kit.
            var foreign=BaseNetworkable.serverEntities.OfType<LootContainer>().Where(c=>c.inventory != null)
                .SelectMany(c=>c.inventory.itemList).FirstOrDefault(i=>i.parent != null && i.GetOwnerPlayer() != npc && i.uid != fixture.uid);
            if(foreign == null)return false;
            Negative("FOREIGN",foreign.uid,foreign);
            parts["NEGATIVE"]="GREEN";
            return true;
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
                plannedPathStatus=path.status.ToString();
                plannedPathLength=path.GetPathLength();
                chosen = foot; return true;
            }
            chosen = Vector3.zero; return false;
        }

        private void StartLeg()
        {
            legActive = false;
            traveled = 0f; repaths = 0; stuckCount = 0;
            start = previous = progressPosition = npc.transform.position;
            if (!SelectTarget(out target)) { Finish("BLOCKED", "No reachable dynamic target after 24 candidates"); return; }
            legActive = true;
            speedBeforeLeg=agent.speed;
            if (!agent.SetDestination(target)) { Finish("BLOCKED", "Agent rejected complete-path target"); return; }
            // Native arrival ResetPath clears desiredSpeed; SetDestination does not restore it.
            agent.speed=3f; issuedSpeed=agent.speed;
            issuedPathStatus=agent.pathStatus.ToString();
            if(issuedPathStatus != "PathComplete") { Finish("PARTIAL","Issued path was not complete"); return; }
            if(samples.Count == 0) {
                previousTime=Time.realtimeSinceStartup;
                RecordSample(previousTime,start);
            }
            legStarted = progressTime = previousTime;
            Puts("RUSTBOTS_LEG_START " + JsonConvert.SerializeObject(new { Leg = completed + 1, Start = Point(start), Target = Point(target),
                PlannedPathStatus=plannedPathStatus,PathStatus=agent.pathStatus.ToString(),SpeedBefore=speedBeforeLeg,IssuedSpeed=issuedSpeed }));
        }

        private void TickProbe()
        {
            if (npc == null || npc.IsDestroyed || agent == null) { Finish("BLOCKED", "Probe entity lost"); return; }
            float now = Time.realtimeSinceStartup;
            Vector3 pos = npc.transform.position;
            equipmentFinal=ReadEquipment();
            if(!Equipped(equipmentFinal)) { parts["HELD_ITEM"]="PARTIAL"; Finish("PARTIAL","Native held selection/ownership lost during movement"); return; }
            float step = Vector3.Distance(previous, pos);
            if (now - previousTime > 1.5f || step > 5f || step > 6f * (now - previousTime) + 1f)
            { Finish("BLOCKED", "Discontinuous position evidence; displacement rejected"); return; }
            traveled += step;
            previous = pos; previousTime = now;
            RecordSample(now,pos);
            Puts("RUSTBOTS_SAMPLE " + JsonConvert.SerializeObject(new {
                Leg = completed + 1, Position = Point(pos), Target = Point(target), Elapsed = now - legStarted,
                Traveled = traveled, Net = Vector3.Distance(start, pos), PathStatus = agent.pathStatus.ToString(),
                HasPath = agent.hasPath, Moving = !agent.isStopped && agent.hasPath, Remaining = agent.remainingDistance,
                Stuck = stuckCount, Repath = repaths
            }));
            if (Vector3.Distance(pos, target) <= 1.8f)
            {
                legs.Add(new { ActorNetId=NetId(npc), Leg = completed + 1, Status = "ARRIVED", Start = Point(start), Target = Point(target), End = Point(pos),
                    StartTime=legStarted, EndTime=now,
                    Elapsed = now - legStarted, Traveled = traveled, Net = Vector3.Distance(start, pos),
                    PlannedPathStatus=plannedPathStatus,IssuedPathStatus=issuedPathStatus,PathStatus=agent.pathStatus.ToString(),
                    PlannedPathLength=plannedPathLength,StoppingDistance=agent.stoppingDistance,
                    SpeedBefore=speedBeforeLeg,IssuedSpeed=issuedSpeed,
                    ArrivalHasPath=agent.hasPath,ArrivalRemaining=agent.remainingDistance, Stuck = stuckCount, Repath = repaths });
                total += traveled; completed++; legActive = false;
                if (completed == 3) {
                    parts["NAV"]=total >= 60f ? "GREEN" : "PARTIAL";
                    Finish(total >= 60f ? "GREEN" : "PARTIAL", total >= 60f ? "One player-derived NPC: native inventory/held and acceptance-distance RustNav legs" : "Travel below 60m");
                }
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
                agent.speed=3f;
                progressTime = now; progressPosition = pos;
            }
            if (now - legStarted > 70f) Finish("BLOCKED", "Leg exceeded 70 seconds");
        }

        private static float[] Point(Vector3 p) { return new[] { p.x, p.y, p.z }; }

        private void RecordSample(float now,Vector3 position)
        {
            var eq=ReadEquipment();
            samples.Add(new { ActorNetId=NetId(npc), Time=now, Position=Point(position),
                ActiveUid=eq.ActiveUid,HeldNetId=eq.HeldNetId,HeldOwnerNetId=eq.HeldOwnerNetId,
                PathStatus=agent.pathStatus.ToString(),HasPath=agent.hasPath,Remaining=agent.remainingDistance,
                NextPosition=Point(agent.nextPositionWS),DesiredVelocity=Point(agent.desiredVelocityWS),Stopped=agent.isStopped,Speed=agent.speed });
        }

        private void Finish(string status, string reason)
        {
            if (finished) return;
            finished = true; active = false;
            if (npc != null && legActive)
                legs.Add(new { ActorNetId=NetId(npc), Leg = completed + 1, Status = "FAILED", Reason = reason, Start = Point(start), Target = Point(target),
                    StartTime=legStarted,EndTime=Time.realtimeSinceStartup,
                    End = Point(npc.transform.position), Elapsed = Time.realtimeSinceStartup - legStarted, Traveled = traveled,
                    Net = Vector3.Distance(start, npc.transform.position), Stuck = stuckCount, Repath = repaths });
            if(status == "BLOCKED" && npc != null)status="PARTIAL";
            if(npc != null && fixture != null)equipmentFinal=ReadEquipment();
            if(inventoryReceipt != null && npc != null) {
                var inv=npc.inventory;
                inventoryReceipt=new {ActorNetId=NetId(npc),Component=inv.GetType().Name,Main=Container(inv.containerMain),Belt=Container(inv.containerBelt),Wear=Container(inv.containerWear),Before=beforeInventory,After=Contents()};
            }
            var result = new { RunId = token, Status = status, Reason = reason, Backend = backend, Prefab = prefab,
                Parts=parts,Actor=actorReceipt,Inventory=inventoryReceipt,Fixture=fixture == null ? null : new {Kind="TEST_FIXTURE",Created=fixturesCreated,Item=Row(fixture)},
                Equipment=equipment,EquipmentFinal=equipmentFinal,Negative=negatives,Samples=samples,Discovery=discovery,
                Persistence="NOT_VERIFIED",ManualPositionWrites=0,SpawnCount=spawnCount,
                CompletedLegs = completed, TotalTraveled = total + (legActive ? traveled : 0f), RejectedSamples = rejectedSamples,
                Rejections = rejections, RejectionExamples = rejectionExamples, Legs = legs };
            if (!string.IsNullOrEmpty(root))
            {
                string path = Path.Combine(root, "oxide", "data", "RustBotsAvatarProbe.result.json");
                File.WriteAllText(path + ".tmp", JsonConvert.SerializeObject(result, Formatting.Indented));
                File.Move(path + ".tmp", path);
            }
            Puts("RUSTBOTS_RESULT " + JsonConvert.SerializeObject(result));
            CleanupNpc();
        }

        private void CleanupNpc() {
            if(fixture != null) { fixture.Remove(); fixture=null; }
            if (npc != null && !npc.IsDestroyed) npc.Kill(); npc = null;
        }
        private void Unload() { CleanupNpc(); }
    }
}
