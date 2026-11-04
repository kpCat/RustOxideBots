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
    [Info("RustBotsAvatarSurvival", "RustOxideBots", "0.2.1")]
    [Description("Isolated single native player-avatar survival and exact inventory restart probe.")]
    public partial class RustBotsAvatarSurvival : RustPlugin
    {
        private sealed class ItemRow {
            public string Uid, Shortname, Role, ContainerUid, OwnerNetId;
            public int Amount, Slot;
            public float Condition, MaxCondition;
        }
        private sealed class StateRow {
            public string ActorId, Goal, ToolUid, ProductUid, ActiveUid, CraftIntent, CraftStatus;
        }
        private sealed class Snapshot {
            public StateRow State;
            public List<ItemRow> Inventory;
        }
        private sealed class RestoreRow {
            public string Stage="VALIDATE";
            public bool LoadCalled, IncomingAbsent, PreLoadHeldZero, SourceUnchanged, ForeignItemsUnchanged, ForeignEntitiesUnchanged, HeldStable;
            public int ItemsBefore, ItemsAfter, ParentPasses;
            public List<ItemRow> SourceInventory, NativeBefore, Loaded;
            public List<object> TransientRefs=new List<object>();
            public object[] HeldItems;
            public object[] SourceContainers;
        }
        private sealed class Cost { public string Shortname; public int Amount; }
        private sealed class RecipeRow {
            public string Shortname;
            public int AmountToCreate, Workbench;
            public bool Known, Allowed;
            public float Time;
            public List<Cost> Ingredients;
        }
        private sealed class EconomySource {
            public string Incarnation, SavedUid, Prefab, Type, Resource, Population;
            public float[] Position, Rotation, Scale, Bounds;
            public float InitialPool, InitialFraction, ExpectedPool, ExpectedFraction, StartAmount, Health;
        }
        private sealed class EconomyState {
            public int Schema=2;
            public RustBots.EconomyWorldIdentity World;
            public Dictionary<string,float> SnapshotHealth=new Dictionary<string,float>();
            public string WorldKey, RecipeHash, ActorId, InventoryHash, CraftIntent, ProductUid;
            public List<EconomySource> Sources=new List<EconomySource>();
        }
        private sealed class DiskWitness { public string Uid; public uint Prefab; public float Health; }
        private bool economy;
        private RustBots.EconomyWorldIdentity currentWorld;
        private Dictionary<string,float> restoreInputHealth;
        private EconomyState economyState;
        private RustBots.EconomyJournal journal;
        private readonly Dictionary<ResourceEntity,DiskWitness> diskLoaded=new Dictionary<ResourceEntity,DiskWitness>();
        private readonly Dictionary<ResourceEntity,EconomySource> sourceRecords=new Dictionary<ResourceEntity,EconomySource>();
        private readonly List<object> sourceReplays=new List<object>();
        private object economyReplay;
        private NPCPlayer npc;
        private RustNavMeshAgent agent;
        private Item rock, product;
        private BaseMelee melee;
        private ResourceEntity source;
        private ResourceDispenser dispenser;
        private ItemAmount pool;
        private string root, token, prefab, mode, need, sourceId;
        private StateRow state;
        private RecipeRow recipe;
        private object actor, normalization, craft;
        private RestoreRow restoreAudit;
        private readonly List<object> equipmentSamples=new List<object>();
        private readonly Dictionary<NetworkableId,string> oldEntities=new Dictionary<NetworkableId,string>();
        private string stableHeld;
        private List<ItemRow> craftBefore;
        private readonly List<ItemRow> starter = new List<ItemRow>();
        private readonly List<object> samples = new List<object>(), legs = new List<object>(), harvests = new List<object>(), negatives = new List<object>();
        private readonly HashSet<string> rejected = new HashSet<string>();
        private bool finished, active, navigating, saved, restored, nativeProbeZero, economicFailure;
        private float wait, deadline, previousTime, total, legTime, progressTime, nextAction, craftTime, holdTime;
        private Vector3 previous, goal, target, legStart, progress;
        private float speedBefore, issuedSpeed;
        private int spawns, equipmentChecks, discoveries, repaths;
        private string gatherMechanism, craftMechanism;
        private static string Id(BaseNetworkable e) { return e == null || e.net == null ? null : e.net.ID.Value.ToString(); }
        private static float[] Point(Vector3 p) { return new[] { p.x,p.y,p.z }; }
        private string Data(string suffix) {
            if(suffix.StartsWith("economy.",StringComparison.Ordinal) && currentWorld!=null)return Path.Combine(currentWorld.JournalDirectory(Path.Combine(root,"oxide","data")),suffix);
            return Path.Combine(root,"oxide","data","RustBotsAvatarSurvival."+suffix);
        }
        private RustBots.EconomyWorldIdentity ReadCurrentWorld() {
            // Installed World getters resolve procedural and custom map filenames; no test seed/coordinates here.
            string file=Path.GetFullPath(Path.Combine(World.MapFolderName,World.MapFileName));
            if(!file.StartsWith(Path.GetFullPath(root).TrimEnd('\\')+"\\",StringComparison.OrdinalIgnoreCase) || !File.Exists(file))
                throw new InvalidOperationException("UNKNOWN_MAP_IDENTITY: native map file outside isolated world or absent");
            var version=System.Text.RegularExpressions.Regex.Match(World.SaveFileName,@"\.([0-9]+)\.sav$");
            if(!version.Success)throw new InvalidOperationException("UNKNOWN_MAP_FORMAT");
            var identity=new RustBots.EconomyWorldIdentity {Kind=World.Procedural?"PROCEDURAL":"CUSTOM",Level=World.Name,Seed=World.Seed,Size=World.Size,
                MapVersion=version.Groups[1].Value,MapSHA256=RustBots.EconomyJournal.HashFile(file),WipeId=SaveRestore.WipeId};
            identity.WorldKey();return identity;
        }
        private void Log(string kind,object value) { Puts("RUSTBOTS_AVATAR_SURVIVAL_"+kind+" "+JsonConvert.SerializeObject(value)); }
        private Exception Balance(string reason) { economicFailure=true;return new InvalidOperationException(reason); }
        private void OnEntityLoaded(BaseNetworkable entity,BaseNetworkable.LoadInfo info) {
            HomeLoaded(entity,info);
            var e=entity as ResourceEntity;
            if(e==null || Environment.GetEnvironmentVariable("RUST_BOTS_WORLD_ECONOMY")!="1" || !info.fromDisk || !TestRoot() ||
                info.msg==null || info.msg.baseNetworkable==null || info.msg.resource==null)return;
            diskLoaded[e]=new DiskWitness {Uid=info.msg.baseNetworkable.uid.Value.ToString(),Prefab=info.msg.baseNetworkable.prefabID,Health=info.msg.resource.health};
        }
        private void OnEntityKill(BaseNetworkable entity) { var e=entity as ResourceEntity;if(e!=null)diskLoaded.Remove(e);var h=entity as BaseEntity;if(h!=null)homeDisk.Remove(h); }
        private EconomySource DescribeSource(ResourceEntity e,ResourceDispenser d,ItemAmount item) {
            var q=e.transform.rotation;var s=e.transform.localScale;var b=e.bounds;
            return new EconomySource {Incarnation=Guid.NewGuid().ToString("N"),SavedUid=Id(e),Prefab=e.PrefabName,Type=e.GetType().Name,Resource=item.itemDef.shortname,
                Population=e._spawnable==null || e._spawnable.Population==null?"NONE":e._spawnable.Population.name,
                Position=Point(e.transform.position),Rotation=new[] {q.x,q.y,q.z,q.w},Scale=Point(s),Bounds=new[] {b.center.x,b.center.y,b.center.z,b.extents.x,b.extents.y,b.extents.z},
                InitialPool=item.amount,InitialFraction=d.fractionRemaining,ExpectedPool=item.amount,ExpectedFraction=d.fractionRemaining,StartAmount=item.startAmount,Health=e.Health()};
        }
        private static bool Near(float[] a,float[] b,float tolerance) {
            return a!=null && b!=null && a.Length==b.Length && a.Zip(b,(x,y)=>!float.IsNaN(x)&&!float.IsNaN(y)&&!float.IsInfinity(x)&&!float.IsInfinity(y)&&Mathf.Abs(x-y)<=tolerance).All(x=>x);
        }
        private void EconomyWrite(string kind,string intent,string stage,object payload) {
            journal.Append(kind,intent,stage,JsonConvert.SerializeObject(payload));
        }
        private void PrepareEconomy(Snapshot snapshot) {
            economyState=JsonConvert.DeserializeObject<EconomyState>(File.ReadAllText(Data("economy.json")));
            string world=currentWorld.WorldKey();
            if(economyState==null || economyState.Schema!=2 || economyState.World==null || economyState.WorldKey!=world || economyState.ActorId!=snapshot.State.ActorId || economyState.RecipeHash!=RustBots.EconomyJournal.Hash(JsonConvert.SerializeObject(recipe)) ||
                economyState.InventoryHash!=RustBots.EconomyJournal.Hash(Key(snapshot.Inventory,false)) || economyState.CraftIntent!=snapshot.State.CraftIntent || economyState.ProductUid!=snapshot.State.ProductUid ||
                economyState.Sources==null || (firstHome?economyState.Sources.Count<2:economyState.Sources.Count!=2) || economyState.Sources.Select(x=>x.Incarnation).Distinct().Count()!=economyState.Sources.Count ||
                economyState.SnapshotHealth==null || economyState.SnapshotHealth.Count!=economyState.Sources.Count || economyState.Sources.Any(x=>!economyState.SnapshotHealth.ContainsKey(x.Incarnation)))
                throw new InvalidOperationException("Economy world/actor/recipe/UID binding mismatch");
            economyState.World.RequireSame(currentWorld);
            restoreInputHealth=new Dictionary<string,float>(economyState.SnapshotHealth);
            if(!File.Exists(Data("economy.journal")))throw new InvalidOperationException("Missing source journal");
            journal=new RustBots.EconomyJournal(Data("economy.journal"),world,snapshot.State.ActorId,economyState.RecipeHash);journal.RequireComplete();
            if(journal.RecoveryState(snapshot.State.CraftIntent)!="COMMITTED")throw new InvalidOperationException("IN_DOUBT craft cannot restore/retry");
        }
        private void RestoreEconomy() {
            var before=Key(Contents());
            // Both passes re-read native state. A flag is never sufficient evidence for NOOP.
            ApplySources(1);ApplySources(2);
            CraftGuard("stonehatchet","DUPLICATE_INTENT");
            economyReplay=new {CraftState=journal.RecoveryState(state.CraftIntent),DuplicateDenied=true,InventoryUnchanged=before==Key(Contents()),OutputUid=state.ProductUid};
            if(before!=Key(Contents()))throw Balance("Economy replay changed inventory");
        }
        private void ApplySources(int pass) {
            var plans=new List<Tuple<EconomySource,ResourceEntity,ResourceDispenser,ItemAmount,string,int>>();
            foreach(var expected in economyState.Sources) {
                var candidates=BaseNetworkable.serverEntities.OfType<ResourceEntity>().Where(candidate=>!candidate.IsDestroyed && candidate.GetType().Name==expected.Type && candidate.PrefabName==expected.Prefab && Near(Point(candidate.transform.position),expected.Position,0.001f)).ToArray();
                if(candidates.Length!=1)throw new InvalidOperationException("SOURCE_IDENTITY_AMBIGUOUS: geometric candidates="+candidates.Length);
                var e=candidates[0];var d=e.GetComponent<ResourceDispenser>();
                var positive=d==null || d.containedItems==null?new ItemAmount[0]:d.containedItems.Where(x=>x.amount>0).ToArray();
                if(positive.Length!=1 || positive[0].itemDef==null)throw new InvalidOperationException("Source categories incompatible");
                var actual=DescribeSource(e,d,positive[0]);DiskWitness witness;
                bool proven=diskLoaded.TryGetValue(e,out witness) && witness.Uid==expected.SavedUid && Id(e)==expected.SavedUid && witness.Prefab==e.prefabID &&
                    RustBots.EconomyJournal.LoadedHealthMatches(e is StagedResourceEntity,witness.Health,restoreInputHealth[expected.Incarnation],e.Health(),e.startHealth) && e.enableSaving && BaseEntity.saveList.Contains(e) && e.OwnerID==0 && !e.IsLocked() &&
                    actual.Resource==expected.Resource && actual.Population==expected.Population && Mathf.Abs(actual.StartAmount-expected.StartAmount)<0.001f &&
                    Near(actual.Rotation,expected.Rotation,0.001f) && Near(actual.Scale,expected.Scale,0.001f) && Near(actual.Bounds,expected.Bounds,0.001f);
                string decision=RustBots.EconomyJournal.PoolDecision(expected.InitialPool,expected.ExpectedPool,expected.InitialFraction,expected.ExpectedFraction,actual.ExpectedPool,actual.ExpectedFraction,proven,candidates.Length);
                plans.Add(Tuple.Create(expected,e,d,positive[0],decision,candidates.Length));
            }
            if(plans.Select(x=>x.Item2).Distinct().Count()!=plans.Count)throw new InvalidOperationException("Source mapping is not one-to-one");
            foreach(var plan in plans) {
                var expected=plan.Item1;var e=plan.Item2;var d=plan.Item3;var item=plan.Item4;float before=item.amount,fraction=d.fractionRemaining;
                sourceRecords[e]=expected;
                var neighbors=BaseNetworkable.serverEntities.OfType<ResourceEntity>().Where(x=>x!=e && !x.IsDestroyed && Vector3.Distance(x.transform.position,e.transform.position)<30).ToArray();
                Func<string> neighborKey=()=>JsonConvert.SerializeObject(neighbors.Select(x=>new {Id=Id(x),Pool=x.GetComponent<ResourceDispenser>()==null?null:x.GetComponent<ResourceDispenser>().containedItems.Select(i=>new {i.itemid,i.amount}).ToArray(),Fraction=x.GetComponent<ResourceDispenser>()==null?0:x.GetComponent<ResourceDispenser>().fractionRemaining}));
                string others=neighborKey();
                if(plan.Item5=="APPLY")d.DestroyFraction(before-expected.ExpectedPool);
                if(RustBots.EconomyJournal.PoolDecision(expected.InitialPool,expected.ExpectedPool,expected.InitialFraction,expected.ExpectedFraction,item.amount,d.fractionRemaining,true,1)!="NOOP" || others!=neighborKey())
                    throw Balance("Source reconciliation/neighbor conservation failed");
                var receipt=new {Pass=pass,expected.Incarnation,expected.SavedUid,expected.Prefab,expected.Position,expected.Rotation,expected.Scale,expected.Type,expected.Resource,expected.Population,
                    Candidates=plan.Item6,DiskWitness=true,Decision=plan.Item5,Before=before,After=item.amount,FractionBefore=fraction,FractionAfter=d.fractionRemaining,
                    expected.InitialPool,expected.ExpectedPool,expected.InitialFraction,expected.ExpectedFraction,Neighbors=neighbors.Length,NeighborsUnchanged=others==neighborKey(),ItemCredits=0,
                    SavedHealth=diskLoaded[e].Health,CheckpointHealth=restoreInputHealth[expected.Incarnation],CurrentHealth=e.Health(),StartHealth=e.startHealth,Staged=e is StagedResourceEntity,Actual=DescribeSource(e,d,item)};
                sourceReplays.Add(receipt);Log("SOURCE_REPLAY",receipt);
            }
        }
        private ItemContainer[] Containers() { return new[] {npc.inventory.containerMain,npc.inventory.containerBelt,npc.inventory.containerWear}; }
        private ItemRow Row(Item i) {
            var cs=Containers();int role=Array.IndexOf(cs,i.parent);
            return new ItemRow {Uid=i.uid.Value.ToString(),Shortname=i.info.shortname,Amount=i.amount,Condition=i.condition,MaxCondition=i.maxCondition,
                Slot=i.position,Role=role==0?"MAIN":role==1?"BELT":role==2?"WEAR":"FOREIGN",ContainerUid=i.parent==null?null:i.parent.uid.Value.ToString(),OwnerNetId=Id(i.GetOwnerPlayer())};
        }
        private List<ItemRow> Contents() { return npc==null?new List<ItemRow>():Containers().SelectMany(c=>c.itemList).Where(i=>i.amount>0).Select(Row).OrderBy(i=>i.Uid,StringComparer.Ordinal).ToList(); }
        private static string Key(IEnumerable<ItemRow> rows,bool owner=true) { return JsonConvert.SerializeObject(rows.OrderBy(i=>i.Uid,StringComparer.Ordinal).Select(i=>new {i.Uid,i.Shortname,i.Amount,i.Condition,i.MaxCondition,i.Role,i.Slot,i.ContainerUid,Owner=owner?i.OwnerNetId:null})); }
        private int Quantity(string name) { return Contents().Where(i=>i.Role!="WEAR" && i.Shortname==name).Sum(i=>i.Amount); }
        private int Required(string name) { return homeGather?(homeBudget.ContainsKey(name)?homeBudget[name]:0):recipe.Ingredients.Single(i=>i.Shortname==name).Amount; }
        private bool TestRoot() {
            root=Environment.GetEnvironmentVariable("RUST_BOTS_TEST_ROOT");token=Environment.GetEnvironmentVariable("RUST_BOTS_RUN_TOKEN");Guid guid;
            if(string.IsNullOrEmpty(root)||!Guid.TryParseExact(token,"N",out guid)||Environment.GetEnvironmentVariable("RUST_BOTS_SCENARIO")!="AVATAR_SURVIVAL")return false;
            var identity=Environment.GetEnvironmentVariable("RUST_BOTS_TEST_IDENTITY");
            return identity!=null && identity.StartsWith("rustbots_probe_",StringComparison.Ordinal) && ConVar.Server.identity==identity &&
                string.Equals(Path.GetFullPath(root).TrimEnd('\\'),Path.GetFullPath(Directory.GetCurrentDirectory()).TrimEnd('\\'),StringComparison.OrdinalIgnoreCase) &&
                File.Exists(Path.Combine(root,"rustbots-test.marker")) && File.ReadAllText(Path.Combine(root,"rustbots-test.marker"))==token;
        }
        private void OnServerInitialized() {
            if(!TestRoot()){Puts("Avatar survival inert: isolated marker/identity missing.");return;}
            firstHome=Environment.GetEnvironmentVariable("RUST_BOTS_FIRST_HOME")=="1";
            economy=Environment.GetEnvironmentVariable("RUST_BOTS_WORLD_ECONOMY")=="1";
            if(firstHome && !economy){Finish("BLOCKED","FirstHome requires world-bound native economy");return;}
            mode=Environment.GetEnvironmentVariable("RUST_BOTS_RESTORE")=="1"?"RESTORE":"JOURNEY";wait=Time.realtimeSinceStartup;
            Puts("RUSTBOTS_READY RustNavMeshAgent/RustNav");
            timer.Every(0.5f,()=> { try {
                string stop=Path.Combine(root,"rustbots-stop.request");
                if(File.Exists(stop)&&File.ReadAllText(stop)==token){Cleanup();Puts("RUSTBOTS_SHUTDOWN_ACK");ConsoleSystem.Run(ConsoleSystem.Option.Server,"quit");return;}
                if(finished)return;
                if(npc==null) {
                    var nav=RustNavigation.Instance;
                    if(ConVar.AI.useUnityNavmesh){Finish("BLOCKED","RustNav required");return;}
                    if(nav!=null && nav.IsDefaultNavmeshBuilt()){Begin();return;}
                    if(Time.realtimeSinceStartup-wait>600)Finish("BLOCKED","RustNav readiness timeout");
                } else if(active)Tick();
            }catch(Exception ex){PrintError(ex.ToString());Finish(economicFailure?"FAILED":"PARTIAL",ex.GetType().Name+": "+ex.Message);} });
        }
        private void Begin() {
            if(economy) {
                currentWorld=ReadCurrentWorld();
                if(mode=="JOURNEY")Directory.CreateDirectory(currentWorld.JournalDirectory(Path.Combine(root,"oxide","data")));
            }
            prefab=GameManifest.Current.entities.Where(p=>p.EndsWith("/scientistnpc_roam.prefab",StringComparison.OrdinalIgnoreCase)).FirstOrDefault();
            var obj=prefab==null?null:GameManager.server.FindPrefab(prefab);
            if(obj==null || obj.GetComponent<ScientistNPC>()==null || obj.GetComponent<PlayerInventory>()==null){Finish("BLOCKED","Installed Roam avatar absent");return;}
            Vector3 spawn;if(!FindSpawn(out spawn)){Finish("BLOCKED","No safe RustNav spawn");return;}
            npc=GameManager.server.CreateEntity(prefab,spawn,Quaternion.identity,true) as NPCPlayer;
            if(npc==null){Finish("BLOCKED","Roam creation failed");return;}
            spawns++;npc.enableSaving=false;npc.Spawn();timer.Once(1f,()=>{try{Setup();}catch(Exception ex){PrintError(ex.ToString());Finish(economicFailure?"FAILED":"PARTIAL","Setup: "+ex.Message);}});
        }
        private void Setup() {
            agent=npc.GetComponent<RustNavMeshAgent>();var fsm=npc.GetComponent<FSMComponent>();var brain=npc.GetComponent<BaseAIBrain>();
            if(fsm!=null)fsm.SetFsmActive(false);
            if(brain!=null){brain.SetThinkMode(AIThinkMode.None);brain.SetEnabled(false);brain.AllowedToSleep=false;
                foreach(var zone in AIInformationZone.zones)if(zone!=null)zone.UnregisterSleepableEntity(brain);
                if(brain.sleeping)((IAISleepable)brain).WakeAI();brain.CancelInvoke(brain.TickMovement);}
            if(!npc.IsNpc || npc.net.connection!=null || npc.userID==0 || npc.userID>=10000000 || agent==null || !agent.isOnNavMesh)throw new InvalidOperationException("Native actor/agent identity gate");
            actor=new {NetId=Id(npc),Type=npc.GetType().Name,Prefab=prefab,IsBasePlayer=npc is BasePlayer,IsNpc=npc.IsNpc,HasConnection=npc.net.connection!=null,NativeBotId=true,UserId=npc.userID.ToString()};
            Log("ACTOR",actor);
            agent.updatePosition=true;agent.updateRotation=true;agent.isStopped=false;agent.SetGait(RustNavMeshAgent.Speeds.Jog);agent.stoppingDistance=0.15f;
            var before=Contents();npc.UpdateActiveItem(default(ItemId));npc.inventory.Strip();
            bool absent=!ItemManager.GetAllItems().Any(i=>before.Any(b=>b.Uid==i.uid.Value.ToString()));
            normalization=new {Before=before,AfterStrip=Contents(),RemovedAbsent=absent};
            if(Contents().Count!=0 || !absent)throw new InvalidOperationException("Default loadout not irreversibly stripped");
            recipe=ReadRecipe("stonehatchet");if(recipe==null || !recipe.Known || recipe.Workbench!=0 || recipe.Ingredients.Count!=2 || !recipe.Ingredients.Any(i=>i.Shortname=="wood") || !recipe.Ingredients.Any(i=>i.Shortname=="stones"))throw new InvalidOperationException("Loaded recipe unsupported");
            if(firstHome)PrepareHome();
            if(mode=="RESTORE"){Restore();return;}
            state=new StateRow {ActorId="avatar-007-"+Guid.NewGuid().ToString("N"),Goal="NEED_RESOURCE"};
            if(economy) {
                economyState=new EconomyState {World=currentWorld,WorldKey=currentWorld.WorldKey(),ActorId=state.ActorId,RecipeHash=RustBots.EconomyJournal.Hash(JsonConvert.SerializeObject(recipe))};
                journal=new RustBots.EconomyJournal(Data("economy.journal"),economyState.WorldKey,state.ActorId,economyState.RecipeHash);
            }
            // Disclosed subset of installed PlayerInventory.GiveDefaultItems: one starter rock.
            rock=ItemManager.CreateByName("rock",1);
            if(rock==null || !rock.MoveToContainer(npc.inventory.containerBelt,0,false))throw new InvalidOperationException("Starter kit transfer failed");
            state.ToolUid=rock.uid.Value.ToString();starter.Add(Row(rock));
            if(!Activate(rock.uid))throw new InvalidOperationException("Starter rock native activation failed");melee=npc.GetHeldEntity() as BaseMelee;
            if(melee==null)throw new InvalidOperationException("Starter rock BaseMelee missing");
            CraftGuard("stonehatchet","MISSING_INGREDIENTS");CraftGuard("rustbots.invalid.recipe","RECIPE_UNAVAILABLE");CraftGuard("rifle.ak","WORKBENCH_REQUIRED");
            previous=npc.transform.position;previousTime=Time.realtimeSinceStartup;deadline=previousTime+900;Sample(previousTime);active=true;Discover();
        }
        private bool Ground(Vector3 p,out Vector3 foot,bool clear=true) {
            foot=p;RaycastHit hit;
            if(!Physics.Raycast(p+Vector3.up*4,Vector3.down,out hit,8,Physics.DefaultRaycastLayers,QueryTriggerInteraction.Ignore) ||
                Mathf.Abs(hit.point.y-p.y)>1 || Mathf.Abs(hit.point.y-TerrainMeta.HeightMap.GetHeight(hit.point))>0.8f || hit.normal.y<0.85f)return false;
            foot=hit.point+Vector3.up*0.05f;
            return WaterLevel.GetWaterSurface(foot,true,true,null)-foot.y<=0.15f && (!clear || Physics.OverlapCapsule(foot+Vector3.up*0.57f,foot+Vector3.up*1.55f,0.45f,Physics.DefaultRaycastLayers,QueryTriggerInteraction.Ignore).Length==0);
        }
        private bool NavSample(Vector3 p,out Vector3 foot) {
            NavHit hit;foot=Vector3.zero;
            return RustNavigation.Instance.DefaultNavmesh.SamplePosition(new NavVector3(p),out hit,new Vector3(2.5f,3,2.5f),false) && Ground(hit.position.Value,out foot);
        }
        private static float Halton(int i,int radix) { float f=1,v=0;while(i>0){f/=radix;v+=f*(i%radix);i/=radix;}return v; }
        private bool FindSpawn(out Vector3 spawn) {
            for(int i=1;i<=1024;i++) {
                Vector3 p=new Vector3((Halton(i,2)-0.5f)*TerrainMeta.Size.x*0.9f,0,(Halton(i,3)-0.5f)*TerrainMeta.Size.z*0.9f);p.y=TerrainMeta.HeightMap.GetHeight(p);
                Vector3 foot;if(!NavSample(p,out foot))continue;
                for(int j=0;j<12;j++) {
                    var q=foot+new Vector3(Mathf.Cos(j*Mathf.PI/6),0,Mathf.Sin(j*Mathf.PI/6))*36;q.y=TerrainMeta.HeightMap.GetHeight(q);Vector3 end;
                    if(!NavSample(q,out end))continue;var path=new RustNavMeshPath();
                    if(RustNavigation.Instance.DefaultNavmesh.CalculatePath(new NavVector3(foot),new NavVector3(end),path,false) && path.status==NavMeshPathStatus.PathComplete){spawn=foot;return true;}
                }
            }spawn=Vector3.zero;return false;
        }
        private bool Eligible(ResourceEntity e,out ResourceDispenser d,out ItemAmount item) {
            d=null;item=null;
            if(e==null || e.IsDestroyed || e.OwnerID!=0 || e.IsLocked() || (need=="wood"?!(e is TreeEntity):!(e is OreResourceEntity)))return false;
            if(economy && (!e.enableSaving || !BaseEntity.saveList.Contains(e)))return false;
            d=e.GetComponent<ResourceDispenser>();if(d==null || d.containedItems==null || d.fractionRemaining<=0)return false;
            var positive=d.containedItems.Where(i=>i.amount>0).ToArray();if(positive.Length!=1)return false;item=positive[0];
            if(economy) {
                var profile=melee.GetGatherInfoFromIndex(d.gatherType);
                if(!RustBots.EconomyJournal.CanSustainHarvest(item.amount,item.startAmount,e.Health(),e.MaxHealth(),profile.gatherDamage,profile.destroyFraction,homeGather?1:Required(need)-Quantity(need)))return false;
            }
            return item.itemDef!=null && item.itemDef.shortname==need && item.amount>(homeGather?1:Required(need)-Quantity(need))+50 && !float.IsNaN(item.amount) && !float.IsInfinity(item.amount);
        }
        private bool Approach(ResourceEntity e,out Vector3 position) {
            for(int i=0;i<24;i++) {
                float a=i*Mathf.PI/4,r=i<8?1.4f:i<16?1.8f:2.2f;var p=e.transform.position+new Vector3(Mathf.Cos(a),0,Mathf.Sin(a))*r;p.y=TerrainMeta.HeightMap.GetHeight(p);
                NavMeshHit hit;Vector3 foot;var path=new RustNavMeshPath();
                if(agent.SamplePosition(p,out hit,0.7f,false) && Ground(hit.position,out foot) && Vector3.Distance(foot,e.transform.position)<=Mathf.Min(2.3f,melee.maxDistance+0.25f) &&
                    agent.CalculatePath(foot,path) && path.status==NavMeshPathStatus.PathComplete && path.GetPathLength()<=500){position=foot;return true;}
            }position=Vector3.zero;return false;
        }
        private bool Reach(out float distance) {
            distance=Vector3.Distance(npc.transform.position,source.transform.position);
            if(distance>Mathf.Min(2.8f,melee.maxDistance+0.5f) || source.OwnerID!=0 || source.IsLocked()){Log("REACH_REJECT",new {Reason="RANGE_OR_OWNERSHIP",Distance=distance,MaxDistance=melee.maxDistance});return false;}
            // Ground() is for empty candidate points BEFORE spawn. Casting down through a live
            // BasePlayer hits its own capsule. Reuse 004's terrain/water + bound-agent action check.
            var foot=npc.transform.position;
            if(!agent.isOnNavMesh || Mathf.Abs(foot.y-TerrainMeta.HeightMap.GetHeight(foot))>=1 || WaterLevel.GetWaterSurface(foot,true,true,null)-foot.y>0.15f){Log("REACH_REJECT",new {Reason="GROUND_OR_WATER",Position=Point(foot)});return false;}
            var eye=npc.transform.position+Vector3.up*1.2f;var delta=source.transform.position+Vector3.up*0.6f-eye;
            bool blocked=Physics.RaycastAll(eye,delta.normalized,delta.magnitude,Physics.DefaultRaycastLayers,QueryTriggerInteraction.Ignore).Any(h=>{
                var e=h.collider.GetComponentInParent<BaseEntity>();return e!=npc && e!=source;
            });
            if(blocked)Log("REACH_REJECT",new {Reason="LOS",Distance=distance,SourceId=sourceId});return !blocked;
        }
        private void Discover() {
            need=Quantity("wood")<Required("wood")?"wood":Quantity("stones")<Required("stones")?"stones":null;
            if(need==null){if(homeGather)HomeMaterialsReady();else StartCraft();return;}
            if(discoveries++>=(homeGather?64:8))throw new InvalidOperationException("Bounded natural source discovery exhausted");
            foreach(var e in BaseNetworkable.serverEntities.OfType<ResourceEntity>().Where(e=>!e.IsDestroyed && (need=="wood"?e is TreeEntity:e is OreResourceEntity) && Vector3.Distance(e.transform.position,npc.transform.position)<=400)
                .OrderBy(e=>Vector3.Distance(e.transform.position,npc.transform.position)).Take(256)) {
                ResourceDispenser d;ItemAmount item;Vector3 approach;string id=Id(e);
                if(rejected.Contains(id) || !Eligible(e,out d,out item) || !Approach(e,out approach))continue;
                source=e;dispenser=d;pool=item;sourceId=id;goal=approach;gatherMechanism=null;nativeProbeZero=false;state.Goal="MOVE";
                Log("SOURCE",new {SourceId=id,Provenance="NATURAL",Type=e.GetType().Name,Prefab=e.PrefabName,Position=Point(e.transform.position),Approach=Point(goal),Pool=pool.amount,Resource=need});StartLeg();return;
            }Finish("PARTIAL","Natural reachable "+need+" unavailable");
        }
        private void StartLeg() {
            var path=new RustNavMeshPath();if(!agent.CalculatePath(goal,path) || path.status!=NavMeshPathStatus.PathComplete) {
                if(economy){RejectRoute("GOAL_PATH",new {Status=path.status.ToString()});return;}
                throw new InvalidOperationException("Incomplete natural-source route");
            }
            // WorldRoam's bounded 36/24/12 m progress candidates avoid rejecting an entire
            // complete route because one interpolated waypoint has no safe ground.
            Vector3 foot=Vector3.zero;bool chosen=false;string reason=null;object detail=null;
            foreach(float length in economy?new[] {36f,24f,12f}:new[] {30f}) {
                Vector3 cursor=npc.transform.position,candidate=goal;float remaining=length;
                foreach(var corner in path.corners){float d=Vector3.Distance(cursor,corner.Value);if(d>remaining){candidate=Vector3.Lerp(cursor,corner.Value,remaining/d);break;}remaining-=d;cursor=corner.Value;}
                NavMeshHit hit;var local=new RustNavMeshPath();
                bool sampled=agent.SamplePosition(candidate,out hit,economy?2.5f:1f,false);
                bool grounded=sampled && Ground(hit.position,out foot);
                bool complete=grounded && agent.CalculatePath(foot,local) && local.status==NavMeshPathStatus.PathComplete && (!economy || local.GetPathLength()<=80);
                if(complete){chosen=true;break;}
                reason=!sampled?"NAV_SAMPLE":!grounded?"GROUND":"LOCAL_PATH";
                detail=new {Candidate=Point(candidate),Length=length,Sampled=sampled,Grounded=grounded,LocalStatus=local.status.ToString()};
                if(economy)Log("WAYPOINT_REJECT",new {SourceId=sourceId,Reason=reason,Detail=detail});
            }
            if(!chosen) {
                if(economy){RejectRoute(reason,detail);return;}
                throw new InvalidOperationException("Local natural route unavailable");
            }
            legStart=progress=npc.transform.position;target=foot;legTime=progressTime=Time.realtimeSinceStartup;repaths=0;
            speedBefore=agent.speed;agent.isStopped=false;if(!agent.SetDestination(target))throw new InvalidOperationException("SetDestination rejected");
            // Installed native ResetPath clears speed; re-arm AFTER every SetDestination.
            agent.speed=3;issuedSpeed=agent.speed;navigating=true;
        }
        private void RejectRoute(string reason,object detail) {
            // Reuse Survival's bounded source rejection; never debit an unreachable source.
            Log("ROUTE_REJECT",new {SourceId=sourceId,Reason=reason,Detail=detail,Discoveries=discoveries});
            rejected.Add(sourceId);navigating=false;agent.isStopped=true;
            source=null;dispenser=null;pool=null;state.Goal="NEED_RESOURCE";Discover();
        }
        private void Sample(float time) { samples.Add(new {Time=time,Position=Point(npc.transform.position),ActorNetId=Id(npc),ActiveUid=npc.GetActiveItem()==null?null:npc.GetActiveItem().uid.Value.ToString(),Speed=agent.speed,PathStatus=agent.pathStatus.ToString(),HasPath=agent.hasPath}); }
        private void Tick() {
            if(firstHome && HomeTick())return;
            if(npc.IsDestroyed)throw new InvalidOperationException("Avatar destroyed");float now=Time.realtimeSinceStartup;
            if(mode=="RESTORE" || state.Goal=="EQUIP") {
                if(!EquipmentValid())throw new InvalidOperationException("Crafted native held selection lost");equipmentChecks++;
                if(mode=="RESTORE") {
                    if(JsonConvert.SerializeObject(HeldItems())!=stableHeld || !OldEntitiesUnchanged())throw Balance("Restored held changed or old entity mutated");
                    equipmentSamples.Add(new {Time=now,Equipment=Equipment()});
                }
                if(now>=holdTime){Save();Finish("GREEN",mode=="RESTORE"?"Independent exact PlayerInventory/identity/active held restore":"Natural survival, paid crafted UID native held by one avatar");}return;
            }
            float dt=now-previousTime,step=Vector3.Distance(previous,npc.transform.position);
            if(dt<=0 || dt>1.5f || step>5 || step>6*dt+1)throw new InvalidOperationException("Discontinuous physical trace");
            total+=step;previous=npc.transform.position;previousTime=now;Sample(now);
            if(now>deadline)throw new InvalidOperationException("Bounded gameplay deadline");
            if(state.Goal=="CRAFT"){PollCraft();return;}
            if(npc.GetActiveItem()!=(homeGather?product:rock) || npc.GetHeldEntity()!=melee)throw new InvalidOperationException("Real gathering tool selection lost");
            if(navigating) {
                float distance=Vector3.Distance(npc.transform.position,target);
                if(distance<=1.05f) {
                    legs.Add(new {Status="ARRIVED",SourceId=sourceId,Start=Point(legStart),End=Point(npc.transform.position),Target=Point(target),StartTime=legTime,EndTime=now,Planned="PathComplete",Arrival=agent.pathStatus.ToString(),HasPath=agent.hasPath,Remaining=agent.remainingDistance,SpeedBefore=speedBefore,IssuedSpeed=issuedSpeed,Repaths=repaths});navigating=false;
                    if(Vector3.Distance(npc.transform.position,goal)>1.05f){StartLeg();return;}
                    state.Goal="GATHER";nextAction=now;return;
                }
                if(!agent.hasPath || agent.pathStatus!=NavMeshPathStatus.PathComplete)throw new InvalidOperationException("Route lost before arrival");
                if(Vector3.Distance(progress,npc.transform.position)>=1){progress=npc.transform.position;progressTime=now;}
                if(now-progressTime>=10){if(repaths++>=1)throw new InvalidOperationException("Avatar stuck after bounded repath");if(!agent.SetDestination(target))throw new InvalidOperationException("Repath rejected");agent.speed=3;progressTime=now;}
                return;
            }
            if(now>=nextAction){nextAction=now+Mathf.Max(1,melee.repeatDelay);Harvest();}
        }
        private HitInfo Hit(bool gather) {
            var hit=new HitInfo(npc,source,Rust.DamageType.Blunt,0,source.transform.position);melee.GetAttackStats(hit);
            hit.Initiator=npc;hit.Weapon=melee;hit.WeaponPrefab=melee;hit.CanGather=gather;hit.DidGather=false;hit.DidHit=true;hit.gatherScale=gather?1:0;
            hit.PointStart=npc.transform.position;hit.PointEnd=source.transform.position;return hit;
        }
        private void Harvest() {
            var gatheringTool=homeGather?product:rock;
            ResourceDispenser d;ItemAmount item;float distance;
            if(!Eligible(source,out d,out item) || d!=dispenser || item!=pool || !Reach(out distance)) {
                rejected.Add(sourceId);navigating=false;Discover();return;
            }
            if(gatheringTool.condition<=0 || gatheringTool.GetOwnerPlayer()!=npc)throw new InvalidOperationException("Owned tool broken/missing");
            if(economy && !sourceRecords.ContainsKey(source)) {
                var record=DescribeSource(source,dispenser,pool);sourceRecords.Add(source,record);economyState.Sources.Add(record);
            }
            var before=Contents();float p=pool.amount,f=dispenser.fractionRemaining,c=gatheringTool.condition,h=source.Health();int quantity=Quantity(need);
            var drops=new HashSet<DroppedItem>(BaseNetworkable.serverEntities.OfType<DroppedItem>());
            HitInfo hit=null;int adapterCredit=0;
            string action=economy?"gather-"+Guid.NewGuid().ToString("N"):null;
            if(economy)EconomyWrite("GATHER",action,"PREPARED",new {Source=sourceRecords[source],ActorId=state.ActorId,Before=before,ToolUid=gatheringTool.uid.Value.ToString(),Condition=c});
            if(gatherMechanism!="SERVER_ACCOUNTED_TOOL") {
                hit=Hit(true);source.OnAttacked(hit);
                int gained=Quantity(need)-quantity;
                if(gained>0 && pool.amount<p && hit.InitiatorPlayer==npc && hit.DidGather)gatherMechanism="NATIVE_PLAYER_GATHER";
                else if(gatherMechanism==null && gained==0 && Mathf.Abs(pool.amount-p)<0.001f && Key(before)==Key(Contents()) &&
                    !BaseNetworkable.serverEntities.OfType<DroppedItem>().Any(x=>!drops.Contains(x))) {
                    if(economy)throw new InvalidOperationException("IN_DOUBT: native gather produced zero; economy adapter disabled");
                    nativeProbeZero=true;gatherMechanism="SERVER_ACCOUNTED_TOOL";
                    Log("NATIVE_GATHER_ZERO",new {InitiatorPlayer=hit.InitiatorPlayer==npc,WeaponOwned=melee.GetOwnerPlayer()==npc,hit.DidGather,PoolBefore=p,PoolAfter=pool.amount,
                        HealthBefore=h,HealthAfter=source.Health(),FractionBefore=f,FractionAfter=dispenser.fractionRemaining,InventoryUnchanged=true,NewDrops=0});
                } else if(gained>0)throw Balance("Ambiguous native yield/debit; no adapter retry");
                else throw new InvalidOperationException("Native debit without inventory yield; no adapter retry");
            }
            if(gatherMechanism=="SERVER_ACCOUNTED_TOOL") {
                var profile=melee.GetGatherInfoFromIndex(dispenser.gatherType);
                int amount=(int)Mathf.Min(10,Mathf.Floor(profile.gatherDamage),Required(need)-quantity);
                if(amount<=0 || profile.conditionLost<=0 || rock.condition<=profile.conditionLost)throw new InvalidOperationException("Adapter tool profile/wear gate");
                dispenser.DestroyFraction(amount);
                if(Mathf.Abs(p-pool.amount-amount)>0.001f)throw Balance("Native adapter source debit mismatch");
                rock.LoseCondition(profile.conditionLost);var output=ItemManager.Create(pool.itemDef,amount,0UL);
                if(output==null || !output.MoveToContainer(npc.inventory.containerMain,-1,true)){if(output!=null)output.Remove();throw new InvalidOperationException("Paid gather output failed; no retry");}
                adapterCredit=amount;
            }
            int delta=Quantity(need)-quantity;
            int newDrops=BaseNetworkable.serverEntities.OfType<DroppedItem>().Count(x=>!drops.Contains(x));
            var receipt=new {SourceId=sourceId,Resource=need,Provenance="NATURAL",SourceType=source.GetType().Name,SourcePrefab=source.PrefabName,
                SourcePosition=Point(source.transform.position),Actor=Point(npc.transform.position),ActorNetId=Id(npc),Time=Time.realtimeSinceStartup,
                Mechanism=gatherMechanism,Amount=delta,PoolBefore=p,PoolAfter=pool.amount,FractionBefore=f,FractionAfter=dispenser.fractionRemaining,HealthBefore=h,HealthAfter=source.Health(),
                ToolUid=gatheringTool.uid.Value.ToString(),ToolConditionBefore=c,ToolConditionAfter=gatheringTool.condition,InitiatorPlayer=hit!=null && hit.InitiatorPlayer==npc,
                WeaponOwned=melee.GetOwnerPlayer()==npc,DidGather=hit!=null && hit.DidGather,AdapterCredit=adapterCredit,NativeProbeZero=nativeProbeZero,
                Distance=distance,LineOfSight=true,Grounded=true,NewDrops=newDrops,Before=before,After=Contents()};
            harvests.Add(receipt);Log("HARVEST",receipt);
            if(firstHome)homeOperations.Add(new {Kind="GATHER",Before=before,After=Contents(),Harvest=receipt});
            if(delta<=0 || p-pool.amount<delta-0.01f || gatheringTool.condition>=c || newDrops!=0 || source.IsDestroyed)throw Balance("Native resource/tool conservation failed");
            if(economy) {
                if(gatherMechanism!="NATIVE_PLAYER_GATHER" || adapterCredit!=0)throw Balance("Economy requires native gather");
                var record=sourceRecords[source];record.ExpectedPool=pool.amount;record.ExpectedFraction=dispenser.fractionRemaining;record.Health=source.Health();
                EconomyWrite("GATHER",action,"APPLIED",receipt);EconomyWrite("GATHER",action,"COMMITTED",new {Source=record,After=Contents()});
            }
            if(Quantity(need)>=Required(need)){rejected.Add(sourceId);state.Goal="NEED_RESOURCE";Discover();}
        }
        private RecipeRow ReadRecipe(string name) {
            var def=ItemManager.FindItemDefinition(name);var bp=def==null?null:def.Blueprint;if(bp==null || bp.targetItem!=def || bp.amountToCreate!=1)return null;
            var costs=bp.GetIngredients();if(costs==null || costs.Count==0 || costs.Any(i=>i.itemDef==null || i.amount<=0 || i.amount!=Mathf.Floor(i.amount) || float.IsInfinity(i.amount)) || costs.Select(i=>i.itemid).Distinct().Count()!=costs.Count)return null;
            return new RecipeRow {Shortname=name,AmountToCreate=bp.amountToCreate,Workbench=bp.GetWorkbenchLevel(),Time=bp.GetCraftTime(),
                Known=bp.defaultBlueprint && ItemManager.defaultBlueprints.Contains(def.itemid) && !bp.NeedsSteamItem && !bp.NeedsSteamDLC && bp.RequireUnlockedItem==null,
                Allowed=bp.userCraftable && def.IsAllowed((Rust.EraRestriction)4),Ingredients=costs.Select(i=>new Cost{Shortname=i.itemDef.shortname,Amount=(int)i.amount}).ToList()};
        }
        private string CraftDenial(string name) {
            if(!string.IsNullOrEmpty(state.CraftIntent))return "DUPLICATE_INTENT";
            var r=ReadRecipe(name);if(r==null)return "RECIPE_UNAVAILABLE";
            if(r.Workbench>npc.currentCraftLevel)return "WORKBENCH_REQUIRED";
            if(!r.Known || !r.Allowed)return "BLUEPRINT_UNKNOWN";
            return r.Ingredients.Any(i=>Quantity(i.Shortname)<i.Amount)?"MISSING_INGREDIENTS":null;
        }
        private void CraftGuard(string name,string expected) {
            var before=Contents();string reason=CraftDenial(name);bool unchanged=Key(before)==Key(Contents());
            negatives.Add(new {Kind=expected,Accepted=reason==null,Unchanged=unchanged,Reason=reason,Before=before,After=Contents(),NativeApiCalled=false});
            if(!unchanged)throw Balance("Craft negative mutated inventory");
            if(reason!=expected)throw new InvalidOperationException("Craft negative gate "+expected);
        }
        private void StartCraft() {
            recipe=ReadRecipe("stonehatchet");if(CraftDenial("stonehatchet")!=null)throw new InvalidOperationException("Loaded craft gate changed");
            state.Goal="CRAFT";state.CraftIntent="avatar007-"+token;state.CraftStatus="DEBITTING";craftBefore=Contents();craftTime=Time.realtimeSinceStartup;
            if(economy)EconomyWrite("CRAFT",state.CraftIntent,"PREPARED",new {Actor=state.ActorId,Recipe=recipe,Before=craftBefore});
            var crafter=npc.inventory.crafting;var bp=ItemManager.FindItemDefinition("stonehatchet").Blueprint;
            bool available=crafter!=null && crafter.owner==npc && crafter.queue.Count==0 && crafter.containers.Contains(npc.inventory.containerMain) && crafter.containers.Contains(npc.inventory.containerBelt);
            if(economy && available)throw new InvalidOperationException("Unexpected native crafter; economy path requires reviewed accounted craft");
            bool accepted=available && crafter.CraftItem(bp,npc,null,1,0,null,false,0);
            Log("QUEUE",new {Available=available,Accepted=accepted,Before=craftBefore,After=Contents(),QueueCount=crafter==null?0:crafter.queue.Count,Recipe=recipe});
            if(accepted){craftMechanism="NATIVE_PLAYER_CRAFT";state.CraftStatus="QUEUED";return;}
            if(Key(craftBefore)!=Key(Contents()) || (crafter!=null && crafter.queue.Count!=0))throw Balance("Native queue refusal mutated payment; adapter forbidden");
            // Reuse 005's debit-first synchronous adapter only after a proven no-op refusal.
            craftMechanism="SERVER_ACCOUNTED_CRAFT";
            if(economy)EconomyWrite("CRAFT",state.CraftIntent,"DEBITTING",new {Before=craftBefore,Recipe=recipe});
            foreach(var cost in recipe.Ingredients){int remaining=cost.Amount;foreach(var i in Containers().Take(2).SelectMany(c=>c.itemList).Where(i=>i.info.shortname==cost.Shortname).ToArray()){
                int take=Math.Min(i.amount,remaining);int amount=i.amount;i.UseItem(take);if(amount-i.amount!=take)throw Balance("Native UseItem debit mismatch");if(i.amount==0)i.RemoveFromContainer();remaining-=take;if(remaining==0)break;
            }if(remaining!=0)throw new InvalidOperationException("Irreversible partial payment");}
            if(economy)EconomyWrite("CRAFT",state.CraftIntent,"DEBITED",new {Before=craftBefore,After=Contents()});
            var output=ItemManager.CreateByName("stonehatchet",recipe.AmountToCreate);
            if(output==null || !output.MoveToContainer(npc.inventory.containerMain,-1,false))throw new InvalidOperationException("Paid craft output failure");
            if(economy)EconomyWrite("CRAFT",state.CraftIntent,"OUTPUT_CREATED",new {Output=Row(output),After=Contents()});
            CompleteCraft();
        }
        private void PollCraft() {
            // NPCs have no connected-player inventory tick; run the installed time-based queue routine.
            // Its endTime remains native. Never call FinishCrafting directly or alter clocks.
            npc.inventory.crafting.ServerUpdate(0.5f);
            if(npc.inventory.crafting.queue.Count==0){CompleteCraft();return;}
            if(Time.realtimeSinceStartup-craftTime>Mathf.Max(60,recipe.Time*3))throw new InvalidOperationException("Native paid queue timeout; no retry/output");
        }
        private void CompleteCraft() {
            var after=Contents();var products=Containers().SelectMany(c=>c.itemList).Where(i=>i.info.shortname=="stonehatchet").ToArray();
            if(products.Length>1)throw Balance("Duplicate crafted output");
            if(products.Length!=1 || craftBefore.Any(i=>i.Uid==products[0].uid.Value.ToString()))throw new InvalidOperationException("Paid fresh output UID missing");product=products[0];
            var debits=craftBefore.Where(i=>i.Shortname=="wood" || i.Shortname=="stones").Select(i=>new {i.Uid,i.Shortname,Consumed=i.Amount-after.Where(a=>a.Uid==i.Uid).Sum(a=>a.Amount)}).Where(d=>d.Consumed>0).ToArray();
            foreach(var cost in recipe.Ingredients)if(debits.Where(d=>d.Shortname==cost.Shortname).Sum(d=>d.Consumed)!=cost.Amount)throw Balance("Exact native payment mismatch");
            craft=new {Mechanism=craftMechanism,Before=craftBefore,After=after,Output=Row(product),Debits=debits,NativeAccepted=craftMechanism=="NATIVE_PLAYER_CRAFT",QueueAfter=npc.inventory.crafting==null?0:npc.inventory.crafting.queue.Count,Elapsed=Time.realtimeSinceStartup-craftTime};
            Log("CRAFT",craft);state.ProductUid=product.uid.Value.ToString();state.CraftStatus="CRAFTED";
            if(firstHome)homeOperations.Add(new {Kind="CRAFT_TOOL",Before=craftBefore,After=after,Costs=recipe.Ingredients,Output=Row(product),Intent=state.CraftIntent});
            if(economy)EconomyWrite("CRAFT",state.CraftIntent,"COMMITTED",craft);
            CraftGuard("stonehatchet","DUPLICATE_INTENT");
            if((product.parent!=npc.inventory.containerBelt && !product.MoveToContainer(npc.inventory.containerBelt,1,false)) || !Activate(product.uid))throw new InvalidOperationException("Exact crafted UID native equip failed");
            state.ActiveUid=state.ProductUid;ActivationNegatives();state.Goal="EQUIP";holdTime=Time.realtimeSinceStartup+2;
            if(firstHome)BeginHomeGather();
        }
        private bool Activate(ItemId uid) {
            var item=npc.inventory.containerBelt.FindItemByUID(uid);
            if(item==null || item.parent!=npc.inventory.containerBelt || item.GetOwnerPlayer()!=npc)return false;
            npc.UpdateActiveItem(uid);return npc.GetActiveItem()==item;
        }
        private object Equipment() {
            var item=npc.GetActiveItem();var held=npc.GetHeldEntity();
            return new {ActorNetId=Id(npc),ActiveUid=item==null?null:item.uid.Value.ToString(),ItemUid=product==null?null:product.uid.Value.ToString(),
                OwnerNetId=item==null?null:Id(item.GetOwnerPlayer()),HeldOwnerNetId=held==null?null:Id(held.GetOwnerPlayer()),HeldParentNetId=held==null?null:Id(held.GetParentEntity()),
                HeldType=held==null?null:held.GetType().Name,HeldNetId=Id(held),HeldItemUid=held==null || held.GetItem()==null?null:held.GetItem().uid.Value.ToString(),IsHeld=held!=null && held.HasFlag((BaseEntity.Flags)1024)};
        }
        private bool EquipmentValid() {
            var held=npc.GetHeldEntity();return product!=null && product.parent==npc.inventory.containerBelt && npc.GetActiveItem()==product && product.GetOwnerPlayer()==npc &&
                held is BaseMelee && held.GetItem()==product && held.GetOwnerPlayer()==npc && held.GetParentEntity()==npc && held.HasFlag((BaseEntity.Flags)1024);
        }
        private void ActivationNegatives() {
            var foreign=BaseNetworkable.serverEntities.OfType<LootContainer>().Where(c=>c.inventory!=null).SelectMany(c=>c.inventory.itemList).FirstOrDefault(i=>i.GetOwnerPlayer()!=npc);
            if(foreign==null)throw new InvalidOperationException("Natural foreign item negative unavailable");
            foreach(var request in new[] {new {Kind="MISSING_UID",Uid=new ItemId(ulong.MaxValue),Item=(Item)null},new {Kind="FOREIGN_UID",Uid=foreign.uid,Item=foreign}}) {
                var before=Contents();var selected=npc.GetActiveItem();var foreignBefore=request.Item==null?null:JsonConvert.SerializeObject(Row(request.Item));
                if(request.Item==null && ItemManager.GetAllItems().Any(i=>i.uid==request.Uid))throw new InvalidOperationException("Missing UID is not absent");
                bool accepted=Activate(request.Uid);bool unchanged=Key(before)==Key(Contents()) && npc.GetActiveItem()==selected &&
                    (request.Item==null || foreignBefore==JsonConvert.SerializeObject(Row(request.Item)));
                negatives.Add(new {Kind=request.Kind,RequestedUid=request.Uid.Value.ToString(),Accepted=accepted,Unchanged=unchanged,Before=before,After=Contents(),
                    NativeApiCalled=false,ForeignUid=request.Item==null?null:request.Item.uid.Value.ToString(),ForeignUnchanged=unchanged});
                if(accepted || !unchanged)throw Balance("Activation guard mutation");
            }
        }
        private object EntityRow(NetworkableId id) {
            var e=BaseNetworkable.serverEntities.Find(id);var h=e as HeldEntity;
            var entity=e as BaseEntity;var item=entity==null?null:entity.GetItem();
            var parent=e==null?null:e.GetParentEntity();var owner=h==null?null:h.GetOwnerPlayer();
            return new {Found=e!=null,NetId=id.Value.ToString(),Type=e==null?null:e.GetType().Name,Prefab=e==null?null:e.PrefabName,
                ParentNetId=Id(parent),OwnerNetId=Id(owner),OwnerResolution=h==null?"UNKNOWN_NOT_HELD":"NATIVE_HELD_OWNER",ItemUid=item==null?null:item.uid.Value.ToString(),
                OwnerItemUid=h==null?null:h.ownerItemUID.Value.ToString(),IsDestroyed=e!=null && e.IsDestroyed,
                InTestWorld=e!=null,ProbeOwned=e!=null && (e==npc || parent==npc || owner==npc)};
        }
        private bool OldEntitiesUnchanged() { return oldEntities.All(p=>p.Value==JsonConvert.SerializeObject(EntityRow(p.Key))); }
        private object[] HeldItems() {
            return Containers().SelectMany(c=>c.itemList).Where(i=>i.info.shortname=="rock" || i.info.shortname=="stonehatchet" || firstHome && HomeHoldable(i.info.shortname)).OrderBy(i=>i.uid.Value).Select(i=>{
                var h=i.GetHeldEntity() as HeldEntity;
                if(h==null || h.IsDestroyed || h.GetItem()!=i || h.GetOwnerPlayer()!=npc || h.GetParentEntity()!=npc || oldEntities.ContainsKey(h.net.ID))
                    throw new InvalidOperationException("Missing, aliased or foreign native restored held entity");
                return (object)new {Uid=i.uid.Value.ToString(),HeldNetId=Id(h),HeldItemUid=h.GetItem().uid.Value.ToString(),OwnerNetId=Id(h.GetOwnerPlayer()),ParentNetId=Id(h.GetParentEntity())};
            }).ToArray();
        }
        private void Restore() {
            restoreAudit=new RestoreRow();
            byte[] sourceState=File.ReadAllBytes(Data("state.json")),sourceBinary=File.ReadAllBytes(Data("inventory.bin"));
            var snapshot=JsonConvert.DeserializeObject<Snapshot>(File.ReadAllText(Data("state.json")));
            if(snapshot==null || snapshot.State==null || snapshot.Inventory==null || snapshot.State.Goal!="COMPLETE" || snapshot.State.CraftStatus!="CRAFTED" ||
                snapshot.State.ActorId==null || !snapshot.State.ActorId.StartsWith("avatar-007-",StringComparison.Ordinal) || string.IsNullOrEmpty(snapshot.State.CraftIntent) || snapshot.State.ProductUid!=snapshot.State.ActiveUid ||
                snapshot.Inventory.Select(i=>i.Uid).Distinct().Count()!=snapshot.Inventory.Count || snapshot.Inventory.Count(i=>i.Uid==snapshot.State.ProductUid && i.Shortname=="stonehatchet" && i.Role=="BELT")!=1)
                throw new InvalidOperationException("Invalid avatar snapshot before inventory mutation");
            if(state!=null || restored || spawns!=1 || Contents().Count!=0)throw new InvalidOperationException("Duplicate logical actor or nonempty restore target");
            var occupied=new HashSet<string>();
            foreach(var row in snapshot.Inventory) {
                ulong uid;
                if(!ulong.TryParse(row.Uid,out uid) || uid==0 || row.Amount<=0 || row.Slot<0 || !occupied.Add(row.Role+":"+row.Slot) ||
                    float.IsNaN(row.Condition) || float.IsInfinity(row.Condition) || float.IsNaN(row.MaxCondition) || float.IsInfinity(row.MaxCondition) ||
                    row.Condition<0 || row.MaxCondition<row.Condition ||
                    !((row.Role=="BELT" && row.Amount==1 && ((row.Condition>0 && (row.Shortname=="rock" || row.Shortname=="stonehatchet")) || firstHome && (row.Shortname=="building.planner" || row.Shortname=="hammer"))) ||
                      (row.Role=="MAIN" && (row.Shortname=="wood" || row.Shortname=="stones"))))throw new InvalidOperationException("Unsupported native snapshot row");
            }
            if(snapshot.Inventory.Count(i=>i.Uid==snapshot.State.ToolUid && i.Shortname=="rock")!=1 || snapshot.Inventory.Select(i=>i.Shortname).Distinct().Count()!=snapshot.Inventory.Count)
                throw new InvalidOperationException("Invalid original tool or duplicate product");
            if(economy)PrepareEconomy(snapshot);
            if(firstHome)HomeRestorePreflight(snapshot);
            // No duplicate saved actor: enableSaving=false; refuse any saved UID already in this world.
            var worldItems=ItemManager.GetAllItems().ToArray();var worldKey=Key(worldItems.Select(Row));
            var savedHeld=new Dictionary<string,NetworkableId>();
            if(worldItems.Any(i=>snapshot.Inventory.Any(row=>row.Uid==i.uid.Value.ToString())))throw new InvalidOperationException("Snapshot item UID already exists in world");
            restoreAudit.IncomingAbsent=true;restoreAudit.ItemsBefore=worldItems.Length;restoreAudit.SourceInventory=snapshot.Inventory;
            using(var native=ProtoBuf.PlayerInventory.Deserialize(sourceBinary)) {
                if(native.invMain==null || native.invBelt==null || native.invWear==null)throw new InvalidOperationException("Incomplete native inventory snapshot");
                var nativeRows=new List<ItemRow>();var cs=new[] {native.invMain,native.invBelt,native.invWear};
                if(cs.Select(c=>c.UID.Value).Distinct().Count()!=3 || cs.Any(c=>c.UID.Value==0))throw new InvalidOperationException("Duplicate/zero container UID");
                var worldContainers=new List<ItemContainer>();
                foreach(var provider in BaseNetworkable.serverEntities.OfType<IInventoryProvider>())provider.GetAllInventories(worldContainers);
                worldContainers.AddRange(worldItems.SelectMany(i=>new[] {i.parent,i.contents}));
                if(worldContainers.Where(c=>c!=null && !Containers().Contains(c)).Any(c=>cs.Any(saved=>saved.UID.Value==c.uid.Value)))throw new InvalidOperationException("Snapshot container UID already exists");
                for(int r=0;r<cs.Length;r++)if(cs[r].slots!=Containers()[r].capacity)throw new InvalidOperationException("Native container capacity differs");
                restoreAudit.SourceContainers=cs.Select((c,r)=>(object)new {Role=r==0?"MAIN":r==1?"BELT":"WEAR",Uid=c.UID.Value.ToString(),Capacity=c.slots}).ToArray();
                for(int r=0;r<cs.Length;r++)foreach(var i in cs[r].contents ?? new List<ProtoBuf.Item>()) {
                    var def=ItemManager.FindItemDefinition(i.itemid);
                    if(def==null || i.worldEntity.Value!=0 || i.slot<0 || i.slot>=cs[r].slots || i.contents!=null)throw new InvalidOperationException("Foreign transient entity or unsupported nested snapshot");
                    nativeRows.Add(new ItemRow {Uid=i.UID.Value.ToString(),Shortname=def.shortname,Amount=i.amount,Slot=i.slot,Role=r==0?"MAIN":r==1?"BELT":"WEAR",
                        ContainerUid=cs[r].UID.Value.ToString(),Condition=i.conditionData==null?0:i.conditionData.condition,MaxCondition=i.conditionData==null?0:i.conditionData.maxCondition});
                }
                if(Key(nativeRows,false)!=Key(snapshot.Inventory,false))throw new InvalidOperationException("Native binary snapshot differs before Load");
                restoreAudit.NativeBefore=nativeRows;restoreAudit.Stage="DETACH_EPHEMERAL_COPY";
                foreach(var c in cs)foreach(var i in c.contents ?? new List<ProtoBuf.Item>()) {
                    if(i.heldEntity.Value==0)continue;
                    var row=nativeRows.Single(x=>x.Uid==i.UID.Value.ToString());
                    if(row.Role!="BELT" || (!HomeHoldable(row.Shortname) || !firstHome && row.Shortname!="rock" && row.Shortname!="stonehatchet") || oldEntities.ContainsKey(i.heldEntity))throw new InvalidOperationException("Unsupported/duplicate held reference");
                    var before=EntityRow(i.heldEntity);oldEntities.Add(i.heldEntity,JsonConvert.SerializeObject(before));
                    savedHeld.Add(row.Uid,i.heldEntity);
                    Log("OLD_HELD_REFERENCE",new {ItemUid=row.Uid,SavedHeldNetId=i.heldEntity.Value.ToString(),Resolved=before});
                    // Item.Load copies this into EntityRef. Never allow it to resolve/parent a current-world alias.
                    i.heldEntity=default(NetworkableId);
                }
                if(oldEntities.Count!=(firstHome?snapshot.Inventory.Count(i=>HomeHoldable(i.Shortname)):2))throw new InvalidOperationException("Incomplete source held references");
                restoreAudit.PreLoadHeldZero=cs.All(c=>(c.contents ?? new List<ProtoBuf.Item>()).All(i=>i.heldEntity.Value==0));
                restoreAudit.Stage="NATIVE_LOAD";restoreAudit.LoadCalled=true;
                npc.inventory.Load(native);
            }
            state=snapshot.State;
            if(Key(snapshot.Inventory,false)!=Key(Contents(),false))throw new InvalidOperationException("Native UID/amount/condition/slot restore differs");
            if(Containers().Any(c=>c.GetOwnerPlayer()!=npc) || Containers().SelectMany(c=>c.itemList).Any(i=>i.GetOwnerPlayer()!=npc))throw new InvalidOperationException("Restored inventory owner differs");
            // Load assigns raw parent fields. Replay the installed SetParent lifecycle through its public native helper.
            restoreAudit.Stage="NATIVE_PARENT";
            foreach(var i in Containers().SelectMany(c=>c.itemList).ToArray())i.RecalulateParentEntity(false);
            stableHeld=JsonConvert.SerializeObject(HeldItems());restoreAudit.ParentPasses++;
            foreach(var i in Containers().SelectMany(c=>c.itemList).ToArray())i.RecalulateParentEntity(false);
            restoreAudit.ParentPasses++;restoreAudit.HeldItems=HeldItems();restoreAudit.HeldStable=stableHeld==JsonConvert.SerializeObject(restoreAudit.HeldItems);
            var afterItems=ItemManager.GetAllItems().ToArray();restoreAudit.ItemsAfter=afterItems.Length;
            restoreAudit.ForeignItemsUnchanged=worldKey==Key(afterItems.Where(i=>!snapshot.Inventory.Any(row=>row.Uid==i.uid.Value.ToString())).Select(Row));
            restoreAudit.ForeignEntitiesUnchanged=OldEntitiesUnchanged();restoreAudit.Loaded=Contents();
            restoreAudit.SourceUnchanged=sourceState.SequenceEqual(File.ReadAllBytes(Data("state.json"))) && sourceBinary.SequenceEqual(File.ReadAllBytes(Data("inventory.bin")));
            foreach(var c in firstHome?new[] {"rock","stonehatchet","building.planner","hammer"}:new[] {"rock","stonehatchet"}) {
                var row=snapshot.Inventory.Single(i=>i.Shortname==c);var old=savedHeld[row.Uid];
                restoreAudit.TransientRefs.Add(new {ItemUid=row.Uid,SavedHeldNetId=old.Value.ToString(),Before=JsonConvert.DeserializeObject(oldEntities[old]),After=EntityRow(old)});
            }
            if(!restoreAudit.HeldStable || !restoreAudit.ForeignItemsUnchanged || !restoreAudit.ForeignEntitiesUnchanged || !restoreAudit.SourceUnchanged || afterItems.Length-worldItems.Length!=snapshot.Inventory.Count)
                throw Balance("Native restore item/entity conservation failure");
            rock=Containers().SelectMany(c=>c.itemList).SingleOrDefault(i=>i.uid.Value.ToString()==state.ToolUid);
            product=npc.inventory.containerBelt.itemList.SingleOrDefault(i=>i.uid.Value.ToString()==state.ProductUid);
            if(rock==null || product==null || !Activate(product.uid))throw new InvalidOperationException("Restored exact selected UID unavailable");
            if(economy)RestoreEconomy();
            restored=true;ActivationNegatives();holdTime=Time.realtimeSinceStartup+2;active=true;
            restoreAudit.Stage="COMPLETE";
            if(firstHome){previous=npc.transform.position;previousTime=Time.realtimeSinceStartup;deadline=previousTime+900;Sample(previousTime);HomeRestoreRebind();}
            Log("RESTORE",new {State=state,Expected=snapshot.Inventory,Actual=Contents(),Equipment=Equipment(),Restored=restored});
        }
        private void Save() {
            if(!EquipmentValid())throw new InvalidOperationException("Cannot snapshot missing held product");
            state.Goal="COMPLETE";
            if(economy) {
                journal.RequireComplete();
                if(sourceRecords.Count!=economyState.Sources.Count || sourceRecords.Keys.Any(e=>e==null || e.IsDestroyed))throw new InvalidOperationException("Source checkpoint incarnation missing");
                economyState.SnapshotHealth=sourceRecords.ToDictionary(x=>x.Value.Incarnation,x=>x.Key.Health());
                economyState.InventoryHash=RustBots.EconomyJournal.Hash(Key(Contents(),false));economyState.CraftIntent=state.CraftIntent;economyState.ProductUid=state.ProductUid;
                File.WriteAllText(Data("economy.json"),JsonConvert.SerializeObject(economyState,Formatting.Indented));
            }
            using(var native=npc.inventory.Save(true,true))File.WriteAllBytes(Data("inventory.bin"),native.ToProtoBytes());
            File.WriteAllText(Data("state.json"),JsonConvert.SerializeObject(new Snapshot {State=state,Inventory=Contents()},Formatting.Indented));
            if(firstHome)HomeSave();
            saved=true;
        }
        private void Finish(string status,string reason) {
            if(finished)return;finished=true;active=false;
            if(firstHome && status=="PARTIAL" && homeUpkeep!=null && homeIntent==null && !saved && equipmentChecks>=3) {
                try{if(Activate(product.uid))Save();}catch(Exception ex){Log("HOME_CHECKPOINT_REFUSED",ex.Message);}
            }
            // Terminal result: release the exclusive writer before Windows evidence readers open it.
            if(journal!=null){journal.Dispose();journal=null;}
            var containers=npc==null?new object[0]:Containers().Select((c,i)=>(object)new {Role=i==0?"MAIN":i==1?"BELT":"WEAR",Uid=c.uid.Value.ToString(),OwnerNetId=Id(c.GetOwnerPlayer()),Capacity=c.capacity}).ToArray();
            var result=new {RunId=token,Status=status,Reason=reason,Mode=mode,Actor=actor,State=state,SpawnCount=spawns,ManualPositionWrites=0,
                Backend="RustNavMeshAgent/RustNav",Containers=containers,Normalization=normalization,StarterKit=starter,Inventory=Contents(),Equipment=npc==null?null:Equipment(),
                EquipmentChecks=equipmentChecks,Recipe=recipe,Craft=craft,Harvests=harvests,Negatives=negatives,Samples=samples,Legs=legs,TotalTraveled=total,
                RestoreAudit=restoreAudit,EquipmentSamples=equipmentSamples,
                FirstHome=HomeResult(),
                Economy=economy?new {WorldKey=economyState==null?null:economyState.WorldKey,World=currentWorld,MapKey=currentWorld==null?null:currentWorld.MapKey(),State=economyState,InputSnapshotHealth=restoreInputHealth,Replays=sourceReplays,CraftReplay=economyReplay,
                    JournalSHA256=File.Exists(Data("economy.journal"))?RustBots.EconomyJournal.HashBytes(File.ReadAllBytes(Data("economy.journal"))):null,CrashAtomic="NOT_PROVEN",CrashRecovery="OFFLINE_ONLY"}:null,
                Persistence=new {Saved=saved,Restored=restored,SourcePools=economy?"BOUNDED_DISK_INCARNATION":"NOT_IMPLEMENTED",CrashJournal=economy?"FAIL_CLOSED":"NOT_IMPLEMENTED"},Conservation=new {Ok=status=="GREEN" || firstHome && saved && !economicFailure,EconomicFailure=economicFailure}};
            File.WriteAllText(Data("result.json")+".tmp",JsonConvert.SerializeObject(result,Formatting.Indented));File.Move(Data("result.json")+".tmp",Data("result.json"));
            Puts("RUSTBOTS_RESULT "+JsonConvert.SerializeObject(result));
        }
        private void Cleanup() { if(npc!=null && !npc.IsDestroyed){npc.UpdateActiveItem(default(ItemId));npc.inventory.Strip();npc.Kill();}npc=null; }
        private void Unload() { Cleanup();if(journal!=null)journal.Dispose(); }
    }
}
