// Appended only to the existing isolated avatar probe. No production registration.
namespace Oxide.Plugins
{
    using System;
    using System.Collections.Generic;
    using System.IO;
    using System.Linq;
    using Newtonsoft.Json;
    using Rust.Ai.Gen2;
    using Rust.Ai.Gen2.Nav;
    using UnityEngine;
    using UnityEngine.AI;

    public partial class RustBotsAvatarSurvival
    {
        private sealed class HomeEntityRow {
            public string Role,NetId,Type,Prefab,Owner,BuildingId,Grade;
            public float Health,Stability;
            public bool Saving,Registered,Support,Grounded;
            public int Links;
            public float[] Position,Rotation;
            public string[] Connected;
        }
        private sealed class HomeStructure {
            public string Placement="SERVER_ACCOUNTED_BUILD",Owner,BuildingId;
            public bool ForeignUnchanged;
            public List<HomeEntityRow> Entities=new List<HomeEntityRow>();
        }
        private sealed class HomeSnapshot {
            public int Schema=1;
            public string WorldKey,ActorId,InventorySHA256;
            public HomeStructure Home;
            public List<ItemRow> TcInventory;
            public ulong[] Authorized;
        }
        private bool firstHome,homeGather,homeRestored,homeNavComplete;
        private string homePhase,homeIntent,homeForeign;
        private float homeWait,homeLegTime;
        private int homeStep,homeNavStage;
        private Vector3 homeSite,homeOutside,homeInside,homeNavStart;
        private Quaternion homeRotation;
        private HomeSnapshot homeSnapshot;
        private readonly Dictionary<string,Construction> homeDefinitions=new Dictionary<string,Construction>();
        private readonly Dictionary<string,RecipeRow> homeRecipes=new Dictionary<string,RecipeRow>();
        private readonly Dictionary<string,int> homeBudget=new Dictionary<string,int>();
        private readonly Dictionary<string,List<Cost>> homeGradeCosts=new Dictionary<string,List<Cost>>();
        private readonly Dictionary<string,DecayEntity> homeEntities=new Dictionary<string,DecayEntity>();
        private readonly Dictionary<BaseEntity,string> homeDisk=new Dictionary<BaseEntity,string>();
        private readonly List<object> homeSites=new List<object>(),homeOperations=new List<object>(),homeNav=new List<object>();
        private object homeSiteReceipt,homeUpkeep,homeRebind,homePortal,homeDoorClosed;
        private readonly Dictionary<string,Item> homeTools=new Dictionary<string,Item>();
        private string HomeData { get { return Data("economy.home.json"); } }
        private static bool HomeHoldable(string name) { return name=="rock" || name=="stonehatchet" || name=="building.planner" || name=="hammer"; }
        private void HomeLoaded(BaseNetworkable value,BaseNetworkable.LoadInfo info) {
            var e=value as DecayEntity;
            if(e!=null && Environment.GetEnvironmentVariable("RUST_BOTS_FIRST_HOME")=="1" && info.fromDisk && TestRoot() && info.msg!=null && info.msg.baseNetworkable!=null)
                homeDisk[e]=info.msg.baseNetworkable.uid.Value.ToString()+"/"+info.msg.baseNetworkable.prefabID;
        }
        private List<Cost> HomeCosts(IEnumerable<ItemAmount> values) {
            if(values==null)throw new InvalidOperationException("Unknown native home costs");
            var list=values.Select(x=>new Cost {Shortname=x.itemDef==null?null:x.itemDef.shortname,Amount=(int)Math.Ceiling(x.amount)}).ToList();
            if(list.Count==0 || list.Any(x=>x.Shortname!="wood" || x.Amount<=0) || list.Select(x=>x.Shortname).Distinct().Count()!=list.Count)
                throw new InvalidOperationException("Unsupported native building budget");
            return list;
        }
        private void HomeAddBudget(IEnumerable<Cost> costs,int count=1) { foreach(var c in costs){if(!homeBudget.ContainsKey(c.Shortname))homeBudget[c.Shortname]=0;homeBudget[c.Shortname]+=checked(c.Amount*count);} }
        private void PrepareHome() {
            if(!ConVar.Decay.upkeep || ConVar.Decay.scale<=0 || ConVar.Decay.duration_wood<=0 || float.IsNaN(ConVar.Decay.scale) || float.IsInfinity(ConVar.Decay.scale))
                throw new InvalidOperationException("Native decay/upkeep must be enabled");
            int reserve=0;
            var paths=new Dictionary<string,string> {
                {"FOUNDATION","assets/prefabs/building core/foundation/foundation.prefab"},{"WALL","assets/prefabs/building core/wall/wall.prefab"},
                {"DOORWAY","assets/prefabs/building core/wall.doorway/wall.doorway.prefab"},{"ROOF","assets/prefabs/building core/floor/floor.prefab"},
                {"DOOR","assets/prefabs/building/door.hinged/door.hinged.wood.prefab"},{"TC","assets/prefabs/deployable/tool cupboard/cupboard.tool.deployed.prefab"}};
            foreach(var pair in paths) {
                var c=PrefabAttribute.server.Find<Construction>(StringPool.Get(pair.Value));
                if(c==null || c.holdToPlaceDuration!=0 || c.maxplaceDistance<=0)throw new InvalidOperationException("Unsupported loaded construction "+pair.Key);
                homeDefinitions.Add(pair.Key,c);
                if(pair.Key=="DOOR" || pair.Key=="TC")continue;
                var wood=c.GetGrade(BuildingGrade.Enum.Wood,0);
                if(c.defaultGrade==null || wood==null)throw new InvalidOperationException("Native grade absent");
                int count=pair.Key=="WALL"?3:1;
                HomeAddBudget(HomeCosts(c.defaultGrade.CostToBuild((BuildingGrade.Enum)(-1))),count);
                HomeAddBudget(HomeCosts(wood.CostToBuild(BuildingGrade.Enum.Twigs)),count);
                reserve+=HomeCosts(wood.CostToBuild(BuildingGrade.Enum.Twigs)).Sum(x=>x.Amount)*count;
                foreach(var role in pair.Key=="WALL"?new[] {"WALL_N","WALL_E","WALL_W"}:new[] {pair.Key}) {
                    homeGradeCosts.Add("BUILD_"+role,HomeCosts(c.defaultGrade.CostToBuild((BuildingGrade.Enum)(-1))));
                    homeGradeCosts.Add("UPGRADE_"+role,HomeCosts(wood.CostToBuild(BuildingGrade.Enum.Twigs)));
                }
            }
            foreach(var name in new[] {"building.planner","hammer","door.hinged.wood","cupboard.tool"}) {
                var r=ReadRecipe(name);
                if(r==null || !r.Known || !r.Allowed || r.Workbench!=0)throw new InvalidOperationException("Home recipe not payable "+name);
                homeRecipes.Add(name,r);HomeAddBudget(r.Ingredients);
            }
            // Reserve one native day conservatively at the full Wood build cost (native tax <= full cost).
            // Actual TC rates/minutes are measured later; this reserve is never an invented yield.
            homeBudget["wood"]+=reserve;homePhase="TOOL";
            Log("HOME_PLAN",new {Budget=homeBudget,UpkeepReserve=reserve,Recipes=homeRecipes,Placement="SERVER_ACCOUNTED_BUILD"});
        }
        private string ForeignHomeKey() {
            return JsonConvert.SerializeObject(BaseNetworkable.serverEntities.OfType<DecayEntity>().Where(x=>(x is BuildingBlock || x is BuildingPrivlidge || x is Door) && !homeEntities.Values.Contains(x)).OrderBy(x=>x.net.ID.Value)
                .Select(x=>new {Id=Id(x),x.OwnerID,x.buildingID,Position=Point(x.transform.position)}));
        }
        private void BeginHomeGather() {
            if(!FindHomeSite())throw new InvalidOperationException("Bounded safe home site unavailable before materials");
            homeGather=true;homePhase="GATHER";state.Goal="NEED_RESOURCE";discoveries=0;rejected.Clear();
            if(!Activate(product.uid))throw new InvalidOperationException("Home earned axe missing");melee=npc.GetHeldEntity() as BaseMelee;
            if(melee==null)throw new InvalidOperationException("Home gathering requires paid held axe");Discover();
        }
        private void HomeWriteIntent(string stage,object payload) {
            // Per-operation durable receipt. An existing non-complete file blocks retry; no compensation.
            string path=Path.Combine(Path.GetDirectoryName(HomeData),"home-"+homeIntent+"-"+stage+".json");
            byte[] bytes=System.Text.Encoding.UTF8.GetBytes(JsonConvert.SerializeObject(new {Intent=homeIntent,Stage=stage,WorldKey=currentWorld.WorldKey(),ActorId=state.ActorId,Payload=payload}));
            using(var f=new FileStream(path,FileMode.CreateNew,FileAccess.Write,FileShare.Read)){f.Write(bytes,0,bytes.Length);f.Flush(true);}
        }
        private void HomeStartPayment(string kind,object payload) {
            if(homeIntent!=null)throw new InvalidOperationException("IN_DOUBT home operation; retry forbidden");
            homeIntent=Guid.NewGuid().ToString("N");HomeWriteIntent("PREPARED",new {Kind=kind,Before=Contents(),Detail=payload});
        }
        private void HomeEndPayment(string kind,List<ItemRow> before,List<Cost> costs,ItemRow output=null,string entity=null) {
            var after=Contents();
            foreach(var name in before.Select(x=>x.Shortname).Concat(after.Select(x=>x.Shortname)).Concat(costs.Select(x=>x.Shortname)).Distinct()) {
                int b=before.Where(x=>x.Shortname==name).Sum(x=>x.Amount),a=after.Where(x=>x.Shortname==name).Sum(x=>x.Amount),c=costs.Where(x=>x.Shortname==name).Sum(x=>x.Amount);
                if(b-a+(output!=null && output.Shortname==name?output.Amount:0)!=c)throw Balance("HOME exact payment mismatch "+name);
            }
            var receipt=new {Kind=kind,Intent=homeIntent,Before=before,After=after,Costs=costs,Output=output,EntityId=entity,ActorNetId=Id(npc),Position=Point(npc.transform.position),Time=Time.realtimeSinceStartup};
            HomeWriteIntent("COMMITTED",receipt);homeOperations.Add(receipt);Log("HOME_PAYMENT",receipt);homeIntent=null;
        }
        private Item HomeCraft(string name,int slot) {
            var r=ReadRecipe(name);
            if(r==null || JsonConvert.SerializeObject(r)!=JsonConvert.SerializeObject(homeRecipes[name]) || r.Ingredients.Any(c=>Quantity(c.Shortname)<c.Amount))throw new InvalidOperationException("Loaded home craft budget changed");
            var before=Contents();HomeStartPayment("CRAFT_"+name,r);
            foreach(var c in r.Ingredients) {
                int left=c.Amount;
                foreach(var i in Containers().Take(2).SelectMany(x=>x.itemList).Where(x=>x.info.shortname==c.Shortname).ToArray()) {
                    int take=Math.Min(i.amount,left),old=i.amount;i.UseItem(take);
                    if(old-i.amount!=take)throw Balance("Home UseItem debit mismatch");if(i.amount==0)i.RemoveFromContainer();left-=take;if(left==0)break;
                }
                if(left!=0)throw new InvalidOperationException("IRREVERSIBLE_PARTIAL home craft");
            }
            HomeWriteIntent("DEBITED",new {After=Contents()});
            var item=ItemManager.CreateByName(name,1);
            if(item==null || !item.MoveToContainer(npc.inventory.containerBelt,slot,false))throw new InvalidOperationException("Paid home item transfer failed");
            HomeEndPayment("CRAFT_"+name,before,r.Ingredients,Row(item));return item;
        }
        private void HomeMaterialsReady() {
            homeGather=false;homePhase="SITE";agent.isStopped=true;navigating=false;
            if(homeBudget.Any(x=>Quantity(x.Key)<x.Value))throw new InvalidOperationException("Incomplete full home/upkeep budget");
            homeTools["building.planner"]=HomeCraft("building.planner",2);
            homeTools["hammer"]=HomeCraft("hammer",3);
            homeTools["door.hinged.wood"]=HomeCraft("door.hinged.wood",4);
            homeTools["cupboard.tool"]=HomeCraft("cupboard.tool",5);
            if(!FindHomeSite())throw new InvalidOperationException("Bounded safe home site unavailable");
            homeForeign=ForeignHomeKey();HomeMove(homeOutside,"SITE");homePhase="TRAVEL";
        }
        private bool FindHomeSite() {
            for(int i=1;i<=512;i++) {
                float angle=Halton(i,2)*Mathf.PI*2,r=8+Halton(i,3)*160;
                var p=npc.transform.position+new Vector3(Mathf.Cos(angle),0,Mathf.Sin(angle))*r;p.y=TerrainMeta.HeightMap.GetHeight(p);
                var rot=Quaternion.Euler(0,Mathf.Floor(Halton(i,5)*8)*45,0);var reasons=new List<string>();
                float min,max;bool water;HomeSurface(p,rot,out min,out max,out water);p.y=max+0.12f;
                var outside=p+rot*new Vector3(0,0,-3);outside.y=TerrainMeta.HeightMap.GetHeight(outside);Vector3 foot=Vector3.zero;NavHit navHit;
                bool sampled=RustNavigation.Instance.DefaultNavmesh.SamplePosition(new NavVector3(outside),out navHit,new Vector3(0.25f,0.5f,0.25f),false) && Ground(navHit.position.Value,out foot);
                Construction.Placement preview=default(Construction.Placement);bool nativePreview=false;
                if(sampled && HomeFoundationPreview(p,foot,out preview)) {
                    rot=preview.rotation;HomeSurface(p,rot,out min,out max,out water);p.y=max+0.12f;
                    nativePreview=HomeFoundationPreview(p,foot,out preview) && Vector3.Distance(preview.position,p)<0.05f && Quaternion.Angle(preview.rotation,rot)<0.05f;
                }
                float depth=homeDefinitions["FOUNDATION"].bounds.size.y;
                float entryDelta=p.y-TerrainMeta.HeightMap.GetHeight(p+rot*new Vector3(0,0,-1.5f));
                float outsideDelta=p.y-TerrainMeta.HeightMap.GetHeight(foot);
                if(water)reasons.Add("WATER");
                if(depth<=0 || max-min>depth*0.5f)reasons.Add("FOUNDATION_DEPTH");
                if(Mathf.Abs(entryDelta)>0.25f || !sampled || Mathf.Abs(outsideDelta)>0.25f)reasons.Add("ENTRANCE_HEIGHT");
                if(!nativePreview)reasons.Add("NATIVE_FOUNDATION_PREVIEW");
                if(BaseNetworkable.serverEntities.OfType<DecayEntity>().Any(x=>Vector3.Distance(x.transform.position,p)<45))reasons.Add("FOREIGN_BUILDING_OR_TC");
                if(TerrainMeta.Path.Monuments.Any(x=>Vector3.Distance(x.transform.position,p)<120))reasons.Add("MONUMENT");
                int deny=(int)(TerrainTopology.Enum.Cliff|TerrainTopology.Enum.Cliffside|TerrainTopology.Enum.Mountain|TerrainTopology.Enum.Monument|TerrainTopology.Enum.Road|TerrainTopology.Enum.Roadside|
                    TerrainTopology.Enum.Rail|TerrainTopology.Enum.Railside|TerrainTopology.Enum.Building|TerrainTopology.Enum.Swamp|TerrainTopology.Enum.Ocean|TerrainTopology.Enum.Oceanside|
                    TerrainTopology.Enum.Offshore|TerrainTopology.Enum.River|TerrainTopology.Enum.Riverside|TerrainTopology.Enum.Lake|TerrainTopology.Enum.Lakeside);
                int topology=TerrainMeta.TopologyMap.GetTopology(p,6f);
                if((topology&deny)!=0)reasons.Add("TOPOLOGY");
                if(TerrainMeta.Path.Roads.Any(x=>x.Path.Points.Any(q=>Vector3.Distance(q,p)<25)))reasons.Add("ROAD");
                // Reject every above-ground collider, including natural resources. Never delete it to fit.
                int collisions=Physics.OverlapBox(p+Vector3.up*1.6f,new Vector3(2.5f,1.45f,2.5f),rot,Physics.DefaultRaycastLayers,QueryTriggerInteraction.Ignore).Count(c=>c.GetComponentInParent<BaseEntity>()!=npc);
                if(collisions!=0)reasons.Add("COLLISION");
                if(!npc.CanBuild(p,rot,new Bounds(Vector3.zero,new Vector3(5,4,5))))reasons.Add("BUILD_PERMISSION");
                var path=new RustNavMeshPath();bool complete=sampled && agent.CalculatePath(foot,path) && path.status==NavMeshPathStatus.PathComplete && path.GetPathLength()<=400;
                if(!complete)reasons.Add("RUSTNAV");
                if(reasons.Count!=0){homeSites.Add(new {Candidate=Point(p),Reasons=reasons,HeightRange=max-min,FoundationDepth=depth,EntryDelta=entryDelta,OutsideDelta=outsideDelta,Water=water,Topology=topology,NativePreview=nativePreview,Sampled=sampled,Path=path.status.ToString(),Complete=complete,Collisions=collisions});continue;}
                homeSite=p;homeRotation=rot;homeOutside=foot;
                homeSiteReceipt=new {Position=Point(p),Rotation=new[] {rot.x,rot.y,rot.z,rot.w},HeightRange=max-min,FoundationDepth=depth,EntryDelta=entryDelta,OutsideDelta=outsideDelta,NativePreview=nativePreview,
                    Water=false,Topology=topology,ForbiddenTopology=deny,Monument=false,Road=false,Foreign=false,Collision=false,Permission=true,Path=path.status.ToString()};
                Log("HOME_SITE",homeSiteReceipt);return true;
            }
            return false;
        }
        private void HomeSurface(Vector3 p,Quaternion rotation,out float min,out float max,out bool water) {
            min=float.MaxValue;max=float.MinValue;water=false;
            for(int z=-1;z<=1;z++)for(int x=-1;x<=1;x++) {
                var q=p+rotation*new Vector3(x*2,0,z*2);float h=TerrainMeta.HeightMap.GetHeight(q);min=Math.Min(min,h);max=Math.Max(max,h);
                if(WaterLevel.GetWaterSurface(q,true,true,null)>h-0.1f)water=true;
            }
        }
        private bool HomeFoundationPreview(Vector3 position,Vector3 stand,out Construction.Placement selected) {
            var c=homeDefinitions["FOUNDATION"];var t=HomeTarget(c,null,null,position);
            if(!t.valid){selected=default(Construction.Placement);return false;}
            // Planning ray from the proposed approach, not the distant actor. Actual Planner still uses real eyes.
            var eye=stand+(npc.eyes.position-npc.transform.position);t.ray=new Ray(eye,(position-eye).normalized);
            var male=new List<Socket_Base>();c.FindMaleSockets(t,male);var valid=new List<Construction.Placement>();
            foreach(var socket in male.Where(x=>!x.maleDummy)) {
                var p=socket.DoPlacement(t);if(p.isPopulated && socket.CheckSocketMods(ref p))valid.Add(p);
            }
            selected=valid.Count==1?valid[0]:default(Construction.Placement);return valid.Count==1;
        }
        private void HomeMove(Vector3 destination,string stage) {
            var path=new RustNavMeshPath();
            if(!agent.CalculatePath(destination,path) || path.status!=NavMeshPathStatus.PathComplete)throw new InvalidOperationException("HOME_NAV "+stage+" "+path.status);
            homeNavStart=npc.transform.position;target=destination;homeLegTime=progressTime=Time.realtimeSinceStartup;progress=homeNavStart;repaths=0;
            if(!agent.SetDestination(destination))throw new InvalidOperationException("Home SetDestination rejected");agent.isStopped=false;agent.speed=3;
            navigating=true;homeNav.Add(new {Event="ISSUED",Stage=stage,Start=Point(homeNavStart),Target=Point(destination),Path=path.status.ToString(),Length=path.GetPathLength(),Time=homeLegTime});
        }
        private bool HomeArrived(float now) {
            float distance=Vector3.Distance(npc.transform.position,target);
            if(distance<=0.3f) {
                homeNav.Add(new {Event="ARRIVED",Start=Point(homeNavStart),Position=Point(npc.transform.position),Target=Point(target),Time=now,Path=agent.pathStatus.ToString(),agent.hasPath,agent.remainingDistance});
                navigating=false;agent.isStopped=true;return true;
            }
            if(!agent.hasPath || agent.pathStatus!=NavMeshPathStatus.PathComplete)throw new InvalidOperationException("HOME_NAV lost before physical arrival: "+agent.pathStatus+" distance="+distance);
            if(Vector3.Distance(progress,npc.transform.position)>0.5f){progress=npc.transform.position;progressTime=now;}
            if(now-homeLegTime>150 || now-progressTime>12){if(repaths++>=1)throw new InvalidOperationException("HOME_NAV bounded stuck");if(!agent.SetDestination(target))throw new InvalidOperationException("Home repath failed");agent.speed=3;progressTime=now;}
            return false;
        }
        private Socket_Base HomeSocket(BaseEntity entity,string suffix) {
            var list=PrefabAttribute.server.FindAll<Socket_Base>(entity.prefabID).Where(x=>x.female && !x.femaleDummy && !x.femaleNoStability && x.socketName.EndsWith(suffix,StringComparison.Ordinal)).ToArray();
            if(list.Length!=1)throw new InvalidOperationException("Ambiguous native home socket "+suffix);return list[0];
        }
        private Construction.Target HomeTarget(Construction c,BaseEntity parent,Socket_Base socket,Vector3 position) {
            var target=new Construction.Target {valid=true,player=npc,entity=parent,socket=socket,onTerrain=parent==null,position=position,normal=Vector3.up,
                rotation=Vector3.zero,ray=new Ray(npc.eyes.position,(position-npc.eyes.position).normalized),
                shouldParent=parent!=null && parent.SupportsChildDeployables() && (parent.ForceDeployableSetParent() || c.deployable!=null && c.deployable.setSocketParent),
                isHoldingShift=false,snappingMode=0,isSnapped=false};
            if(socket==null) {
                var hits=Physics.RaycastAll(position+Vector3.up*2,Vector3.down,6,Physics.DefaultRaycastLayers,QueryTriggerInteraction.Ignore)
                    .Where(x=>x.normal.y>=0.85f && (parent==null?x.collider.GetComponentInParent<BaseEntity>()==null && Mathf.Abs(x.point.y-TerrainMeta.HeightMap.GetHeight(x.point))<0.1f:x.collider.GetComponentInParent<BaseEntity>()==parent))
                    .OrderBy(x=>x.distance).ToArray();
                if(hits.Length==0)target.valid=false;
                else{target.normal=hits[0].normal;if(parent!=null)target.position=hits[0].point;}
            }
            target.ray=new Ray(npc.eyes.position,(target.position-npc.eyes.position).normalized);return target;
        }
        private Socket_Base HomeRoofSocket(BaseEntity wall) {
            var c=homeDefinitions["ROOF"];var wanted=homeEntities["FOUNDATION"].transform.position+Vector3.up*3;
            var candidates=new List<Socket_Base>();
            foreach(var suffix in new[] {"/floor-female/1","/floor-female/2"}) {
                var socket=HomeSocket(wall,suffix);var target=HomeTarget(c,wall,socket,wall.transform.TransformPoint(socket.position));
                var male=new List<Socket_Base>();c.FindMaleSockets(target,male);
                var placements=new List<Construction.Placement>();
                foreach(var input in male.Where(x=>!x.maleDummy)) {
                    var placement=input.DoPlacement(target);if(placement.isPopulated && input.CheckSocketMods(ref placement))placements.Add(placement);
                }
                bool centered=placements.Count>0 && placements.All(x=>Vector3.Distance(x.position,wanted)<0.05f);
                Log("HOME_ROOF_PREVIEW",new {Socket=socket.socketName,Centered=centered,Predicted=placements.Select(x=>Point(x.position)).ToArray(),Wanted=Point(wanted)});
                if(centered)candidates.Add(socket);
            }
            if(candidates.Count!=1)throw new InvalidOperationException("No unique native roof socket centered above own foundation");return candidates[0];
        }
        private BaseEntity HomePlace(string role,string definition,string tool,BaseEntity parent,Socket_Base socket,Vector3 position) {
            Item item=homeTools[tool];if(!Activate(item.uid))throw new InvalidOperationException("Paid planner activation failed");
            var planner=npc.GetHeldEntity() as Planner;var c=homeDefinitions[definition];
            if(planner==null || planner.GetItem()!=item || planner.GetOwnerPlayer()!=npc || planner.GetDeployable()!=c.deployable || !planner.CanAffordToPlace(c) ||
                !npc.CanBuild() || !npc.CanBuild(position,homeRotation,c.bounds) || Vector3.Distance(npc.eyes.position,position)>c.maxplaceDistance+0.01f)
                throw new InvalidOperationException("Native home ownership/permission/affordability/reach gate "+role);
            var t=HomeTarget(c,parent,socket,position);
            if(!t.valid)throw new InvalidOperationException("Native placement support surface unavailable");
            if(Oxide.Core.Interface.CallHook("CanBuild",planner,c,t)!=null)throw new InvalidOperationException("Native CanBuild hook denied home");
            var costs=definition=="DOOR" || definition=="TC"?new List<Cost>{new Cost {Shortname=tool,Amount=1}}:HomeCosts(c.defaultGrade.CostToBuild((BuildingGrade.Enum)(-1)));
            var before=Contents();HomeStartPayment("BUILD_"+role,new {Target=Point(position),Socket=socket==null?null:socket.socketName,Costs=costs});
            var created=planner.DoBuild(t,c) as DecayEntity;
            if(created==null)throw new InvalidOperationException("Native placement rejected "+role+": "+Construction.lastPlacementErrorDebug+"; no retry");
            homeEntities.Add(role,created);HomeEndPayment("BUILD_"+role,before,costs,null,Id(created));
            if(created.OwnerID!=npc.userID || !created.enableSaving || !BaseEntity.saveList.Contains(created))throw new InvalidOperationException("Native home ownership/save registration failed");
            var block=created as BuildingBlock;
            if(block!=null) {
                if(!Activate(homeTools["hammer"].uid) || !block.CanChangeToGrade(BuildingGrade.Enum.Wood,0,npc) || !block.CanAffordUpgrade(BuildingGrade.Enum.Wood,0,npc) || block.SecondsSinceAttacked<30)
                    throw new InvalidOperationException("Native Wood upgrade guard rejected");
                var grade=block.blockDefinition.GetGrade(BuildingGrade.Enum.Wood,0);var upgrade=HomeCosts(grade.CostToBuild(block.grade));before=Contents();HomeStartPayment("UPGRADE_"+role,upgrade);
                block.PayForUpgrade(grade,npc);HomeWriteIntent("DEBITED",new {After=Contents()});block.ChangeGrade(BuildingGrade.Enum.Wood,true,true);
                HomeEndPayment("UPGRADE_"+role,before,upgrade,null,Id(block));
                if(block.grade!=BuildingGrade.Enum.Wood)throw new InvalidOperationException("Paid native Wood grade missing");
            }
            return created;
        }
        private void HomeBuildStep() {
            if(homeStep==0){var block=HomePlace("FOUNDATION","FOUNDATION","building.planner",null,null,homeSite);homeSite=block.transform.position;homeRotation=block.transform.rotation;homeStep++;return;}
            var foundation=(BuildingBlock)homeEntities["FOUNDATION"];
            if(homeStep>=1 && homeStep<=4) {
                string[] roles={"WALL_N","WALL_E","WALL_W","DOORWAY"};int[] sockets={3,4,2,1};string role=roles[homeStep-1];
                var socket=HomeSocket(foundation,"/wall-female/"+sockets[homeStep-1]);var p=foundation.transform.TransformPoint(socket.position);
                HomePlace(role,role=="DOORWAY"?"DOORWAY":"WALL","building.planner",foundation,socket,p);homeStep++;return;
            }
            if(homeStep==5){var wall=homeEntities["WALL_N"];var socket=HomeRoofSocket(wall);HomePlace("ROOF","ROOF","building.planner",wall,socket,wall.transform.TransformPoint(socket.position));homeStep++;return;}
            if(homeStep==6){
                var tc=(BuildingPrivlidge)HomePlace("TC","TC","cupboard.tool",foundation,null,foundation.transform.TransformPoint(new Vector3(0.65f,0,0.6f)));
                if(tc.authorizedPlayers.Count!=0 || tc.inventory.itemList.Count!=0)throw new InvalidOperationException("New TC is occupied");
                tc.AddPlayer(npc,npc.userID);if(!tc.IsAuthed(npc) || !tc.CanBuild(npc))throw new InvalidOperationException("Native TC auth refused before final door");homeStep++;return;
            }
            if(homeStep==7){var wall=homeEntities["DOORWAY"];var socket=HomeSocket(wall,"/doorway-female/1");HomePlace("DOOR","DOOR","door.hinged.wood",wall,socket,wall.transform.TransformPoint(socket.position));homeStep++;homeWait=Time.realtimeSinceStartup+8;homePhase="VERIFY";return;}
        }
        private Vector3 HomeBuildStand() {
            Vector3 offset=homeStep==1 || homeStep==5?new Vector3(0,0,3):homeStep==2?new Vector3(3,0,0):homeStep==3?new Vector3(-3,0,0):new Vector3(0,0,-3);
            var p=homeSite+homeRotation*offset;p.y=TerrainMeta.HeightMap.GetHeight(p);Vector3 foot;
            if(!NavSample(p,out foot))throw new InvalidOperationException("No physical building approach");return foot;
        }
        private HomeEntityRow HomeRow(string role,DecayEntity e) {
            var block=e as BuildingBlock;var group=e.GetBuilding();var q=e.transform.rotation;var links=e.GetEntityLinks(true);
            var connected=links.SelectMany(x=>x.connections).Select(x=>Id(x.owner)).Where(x=>x!=null).Distinct().OrderBy(x=>x,StringComparer.Ordinal).ToArray();
            bool registered=group!=null && group.decayEntities.Contains(e) && (block==null || group.buildingBlocks.Contains(block)) && (!(e is BuildingPrivlidge) || group.buildingPrivileges.Contains((BuildingPrivlidge)e)) && (!(e is Door) || group.doors.Contains((Door)e));
            return new HomeEntityRow {Role=role,NetId=Id(e),Type=e.GetType().Name,Prefab=e.PrefabName,Owner=e.OwnerID.ToString(),BuildingId=e.buildingID.ToString(),Grade=block==null?null:block.grade.ToString(),
                Health=e.Health(),Stability=block==null?0:block.cachedStability,Grounded=block!=null && block.grounded,Support=block==null || block.cachedStability>0,
                Saving=e.enableSaving && BaseEntity.saveList.Contains(e),Registered=registered,Links=connected.Length,Connected=connected,Position=Point(e.transform.position),Rotation=new[] {q.x,q.y,q.z,q.w}};
        }
        private HomeStructure DescribeHome() {
            return new HomeStructure {Owner=npc.userID.ToString(),BuildingId=homeEntities["FOUNDATION"].buildingID.ToString(),ForeignUnchanged=homeForeign==ForeignHomeKey(),
                Entities=homeEntities.OrderBy(x=>x.Key,StringComparer.Ordinal).Select(x=>HomeRow(x.Key,x.Value)).ToList()};
        }
        private void HomeRequireStructure(string expectedOwner=null) {
            if(homeEntities.Count!=8 || homeEntities.Values.Distinct().Count()!=8 || homeEntities.Values.Any(x=>x==null || x.IsDestroyed))throw new InvalidOperationException("Missing native home element");
            var rows=DescribeHome();
            if(expectedOwner!=null)rows.Owner=expectedOwner;
            if(!rows.ForeignUnchanged || rows.Entities.Any(x=>x.Owner!=rows.Owner || x.BuildingId!=rows.BuildingId || !x.Registered || !x.Saving || !x.Support || x.Health<=0 || (x.Type=="BuildingBlock" && (x.Grade!="Wood" || x.Links==0))))
                throw new InvalidOperationException("Native home group/grade/support/ownership/link/foreign gate");
            var foundation=homeEntities["FOUNDATION"];
            if(homeEntities.Where(x=>x.Key.StartsWith("WALL",StringComparison.Ordinal) || x.Key=="DOORWAY").Any(x=>Vector3.Distance(x.Value.transform.position,foundation.transform.position)>2) ||
                Vector3.Distance(homeEntities["ROOF"].transform.position,foundation.transform.position+Vector3.up*3)>0.15f)
                throw new InvalidOperationException("Native construction did not form relative 1x1 shelter");
        }
        private List<ItemRow> HomeTcItems() { return ((BuildingPrivlidge)homeEntities["TC"]).inventory.itemList.Where(x=>x.amount>0).Select(Row).OrderBy(x=>x.Uid,StringComparer.Ordinal).ToList(); }
        private void HomeAuthorizeAndUpkeep() {
            HomeRequireStructure();var tc=(BuildingPrivlidge)homeEntities["TC"];
            if(tc.OwnerID!=npc.userID || tc.authorizedPlayers.Any(x=>x!=npc.userID) || tc.inventory==null || tc.inventory.itemList.Count!=0)throw new InvalidOperationException("TC ownership/auth/inventory is not fresh");
            if(!tc.IsAuthed(npc))tc.AddPlayer(npc,npc.userID);
            if(!tc.IsAuthed(npc) || !tc.CanBuild(npc) || homeEntities["FOUNDATION"].GetBuildingPrivilege()!=tc)throw new InvalidOperationException("Native TC bot authorization/privilege failed");
            var costs=new List<ItemAmount>();tc.CalculateUpkeepCostAmounts(costs);var rate=HomeCosts(costs);
            float beforeMinutes=tc.GetProtectedMinutes(true),period=tc.CalculateUpkeepPeriodMinutes();
            if(period<=0 || rate.Any(x=>Quantity(x.Shortname)<x.Amount))throw new InvalidOperationException("Native upkeep reserve insufficient");
            var before=Contents();var moved=new List<ItemRow>();
            HomeStartPayment("UPKEEP_TRANSFER",new {Rate=rate,Period=period,BeforeMinutes=beforeMinutes});
            foreach(var item in Containers().Take(2).SelectMany(x=>x.itemList).Where(x=>rate.Any(c=>c.Shortname==x.info.shortname)).ToArray()) {
                var row=Row(item);
                if(!item.MoveToContainer(tc.inventory,-1,false,false,npc,false))throw new InvalidOperationException("Native paid TC transfer refused; no retry");moved.Add(row);
            }
            var after=Contents();var tcItems=HomeTcItems();
            if(moved.Count==0 || moved.Any(x=>after.Any(y=>y.Uid==x.Uid) || !tcItems.Any(y=>y.Uid==x.Uid && y.Shortname==x.Shortname && y.Amount==x.Amount)))throw Balance("Native upkeep transfer UID mismatch");
            float minutes=tc.GetProtectedMinutes(true);
            if(float.IsNaN(minutes) || float.IsInfinity(minutes) || minutes<=beforeMinutes || minutes<period)throw new InvalidOperationException("Native TC protection period not proven");
            homeUpkeep=new {Before=before,After=after,Transferred=moved,TcInventory=tcItems,Rate=rate,Period=period,MinutesBefore=beforeMinutes,MinutesAfter=minutes,Authed=tc.IsAuthed(npc),Privilege=true};
            HomeWriteIntent("COMMITTED",homeUpkeep);homeIntent=null;Log("HOME_UPKEEP",homeUpkeep);
            Activate(product.uid);homePhase="NAV_WAIT";homeWait=Time.realtimeSinceStartup+30;
        }
        private bool HomeInterior(out Vector3 point) {
            var foundation=homeEntities["FOUNDATION"];point=Vector3.zero;
            foreach(var relative in new[] {new Vector3(0,0,-0.65f),new Vector3(-0.65f,0,-0.4f),new Vector3(-0.65f,0,0.25f)}) {
                var expected=foundation.transform.TransformPoint(relative);
                var hits=Physics.RaycastAll(expected+Vector3.up*0.5f,Vector3.down,1,Physics.DefaultRaycastLayers,QueryTriggerInteraction.Ignore)
                    .Where(x=>x.collider.GetComponentInParent<BaseEntity>()==foundation && x.normal.y>0.85f).OrderBy(x=>x.distance).ToArray();
                if(hits.Length==0)continue;expected=hits[0].point+Vector3.up*0.05f;NavHit hit;
                if(!RustNavigation.Instance.DefaultNavmesh.SamplePosition(new NavVector3(expected),out hit,new Vector3(0.2f,0.15f,0.2f),false))continue;
                var candidate=hit.position.Value;
                if(Mathf.Abs(candidate.y-expected.y)<0.15f && !Physics.OverlapCapsule(candidate+Vector3.up*0.5f,candidate+Vector3.up*1.3f,0.5f,Physics.DefaultRaycastLayers,QueryTriggerInteraction.Ignore)
                    .Any(c=>c.GetComponentInParent<BaseEntity>()!=npc && c.GetComponentInParent<BaseEntity>()!=foundation)){point=candidate;return true;}
            }
            return false;
        }
        private bool homeCrossedIn,homeCrossedOut;
        private object DoorColliders() {
            return homeEntities["DOOR"].GetComponentsInChildren<Collider>(true).Where(x=>!x.isTrigger).Select(x=>new {x.enabled,Name=x.name,Center=Point(x.bounds.center),Extents=Point(x.bounds.extents),
                Rotation=new[] {x.transform.rotation.x,x.transform.rotation.y,x.transform.rotation.z,x.transform.rotation.w}}).ToArray();
        }
        private void HomeReadPortal() {
            var door=(Door)homeEntities["DOOR"];Bounds aperture;Matrix4x4 matrix;
            if(!door.TryGetNavDoorwayVolume(out aperture,out matrix))throw new InvalidOperationException("Native home portal unavailable");
            var obb=new OBB(door.transform,aperture);bool thinX=obb.extents.x<=obb.extents.z;var normal=thinX?obb.right:obb.forward;
            if(Vector3.Dot(normal,homeInside-homeOutside)<0)normal=-normal;
            homePortal=new {DoorNetId=Id(door),LocalCenter=Point(aperture.center),LocalExtents=Point(aperture.extents),Scale=Point(door.transform.lossyScale),
                Center=Point(obb.position),Normal=Point(normal),Right=Point(thinX?obb.forward:obb.right),Up=Point(obb.up),HalfWidth=thinX?obb.extents.z:obb.extents.x,HalfHeight=obb.extents.y,
                Radius=0.5f,Height=1.8f,Outside=Point(homeOutside),Inside=Point(homeInside)};
        }
        private void HomePhysicalSample(float now) {
            var p=npc.transform.position;var foundation=homeEntities["FOUNDATION"];
            var collisions=Physics.OverlapCapsule(p+Vector3.up*0.5f,p+Vector3.up*1.3f,0.5f,Physics.DefaultRaycastLayers,QueryTriggerInteraction.Ignore)
                .Where(x=>x.GetComponentInParent<BaseEntity>()!=npc && x.GetComponentInParent<BaseEntity>()!=foundation).ToArray();
            var local=foundation.transform.InverseTransformPoint(p);bool inside=Mathf.Abs(local.x)<1.4f && Mathf.Abs(local.z)<1.4f;
            var hits=Physics.RaycastAll(p+Vector3.up*0.3f,Vector3.down,0.6f,Physics.DefaultRaycastLayers,QueryTriggerInteraction.Ignore)
                .Where(x=>x.collider.GetComponentInParent<BaseEntity>()==foundation && Mathf.Abs(x.point.y-p.y)<0.15f && x.normal.y>0.85f).ToArray();
            var receipt=new {Event="PHYSICS",Time=now,Position=Point(p),Clear=collisions.Length==0,Inside=inside,OwnedFloor=hits.Length>0,Radius=0.5f,Height=1.8f,DoorOpen=((Door)homeEntities["DOOR"]).IsOpen()};
            homeNav.Add(receipt);
            if(collisions.Length!=0 || inside && hits.Length==0)throw new InvalidOperationException("HOME_NAV physical collider/support clearance failed");
        }
        private void HomeCrossing(Vector3 from,Vector3 to,float now) {
            var door=(Door)homeEntities["DOOR"];Bounds aperture;Matrix4x4 matrix;
            if(!door.TryGetNavDoorwayVolume(out aperture,out matrix))throw new InvalidOperationException("Native doorway aperture unavailable");
            var obb=new OBB(door.transform,aperture);Vector3 normal=obb.extents.x<=obb.extents.z?obb.right:obb.forward;
            if(Vector3.Dot(normal,homeInside-homeOutside)<0)normal=-normal;
            float a=Vector3.Dot(from-obb.position,normal),b=Vector3.Dot(to-obb.position,normal);
            bool enter=a<0 && b>=0,leave=a>0 && b<=0;
            if(!enter && !leave)return;
            var crossing=Vector3.Lerp(from,to,Mathf.Abs(a)/(Mathf.Abs(a)+Mathf.Abs(b)));
            var local=matrix.inverse.MultiplyPoint3x4(crossing+Vector3.up*0.9f);
            if(!door.IsOpen() || !aperture.Contains(local))throw new InvalidOperationException("Home crossing outside native open aperture");
            if(enter)homeCrossedIn=true;if(leave)homeCrossedOut=true;
            homeNav.Add(new {Event=enter?"CROSSED_IN":"CROSSED_OUT",Time=now,Position=Point(crossing),A=a,B=b,Open=door.IsOpen(),Local=Point(local)});
        }
        private void HomeOpenDoor(bool open) {
            var door=(Door)homeEntities["DOOR"];var tc=(BuildingPrivlidge)homeEntities["TC"];
            if(door.OwnerID!=npc.userID || !tc.IsAuthed(npc) || !door.GetPlayerLockPermission(npc) || door.HasLock() || door.IsBusy() || Vector3.Distance(npc.transform.position,door.transform.position)>3)
                throw new InvalidOperationException("Native door owner/auth/range/lock refused");
            Bounds aperture;Matrix4x4 matrix;if(!door.TryGetNavDoorwayVolume(out aperture,out matrix))throw new InvalidOperationException("Door interaction aperture absent");
            var eye=npc.eyes.position;var aim=matrix.MultiplyPoint3x4(aperture.center);var delta=aim-eye;
            if(Physics.RaycastAll(eye,delta.normalized,delta.magnitude,Physics.DefaultRaycastLayers,QueryTriggerInteraction.Ignore).Any(x=>x.collider.GetComponentInParent<BaseEntity>()!=npc && x.collider.GetComponentInParent<BaseEntity>()!=door))
                throw new InvalidOperationException("Native door interaction LOS refused");
            if(open)homeDoorClosed=DoorColliders();
            bool before=door.IsOpen();door.SetOpen(open,false);
            homeNav.Add(new {Event="DOOR",Before=before,After=door.IsOpen(),Requested=open,Time=Time.realtimeSinceStartup,
                Colliders=DoorColliders(),LineOfSight=true,Busy=false,Owner=true,Authed=true});
            if(door.IsOpen()!=open)throw new InvalidOperationException("Native physical door transition refused");
        }
        private void HomeSave() {
            HomeRequireStructure();var tc=(BuildingPrivlidge)homeEntities["TC"];
            if(homeIntent!=null || !tc.IsAuthed(npc) || tc.authorizedPlayers.Count!=1 || tc.GetProtectedMinutes(true)<=0)throw new InvalidOperationException("Cannot checkpoint uncertain home");
            homeSnapshot=new HomeSnapshot {WorldKey=currentWorld.WorldKey(),ActorId=state.ActorId,InventorySHA256=RustBots.EconomyJournal.Hash(Key(Contents(),false)),
                Home=DescribeHome(),TcInventory=HomeTcItems(),Authorized=tc.authorizedPlayers.OrderBy(x=>x).ToArray()};
            File.WriteAllText(HomeData,JsonConvert.SerializeObject(homeSnapshot,Formatting.Indented));
        }
        private HomeSnapshot homeRestoreSource;
        private void HomeRestorePreflight(Snapshot snapshot) {
            homeRestoreSource=JsonConvert.DeserializeObject<HomeSnapshot>(File.ReadAllText(HomeData));var s=homeRestoreSource;
            if(s==null || s.Schema!=1 || s.WorldKey!=currentWorld.WorldKey() || s.ActorId!=snapshot.State.ActorId || s.InventorySHA256!=RustBots.EconomyJournal.Hash(Key(snapshot.Inventory,false)) ||
                s.Home==null || s.Home.Entities==null || s.Home.Entities.Count!=8 || !s.Home.ForeignUnchanged || s.Home.Entities.Select(x=>x.NetId).Distinct().Count()!=8 ||
                s.Authorized==null || s.Authorized.Length!=1 || s.Authorized[0].ToString()!=s.Home.Owner)throw new InvalidOperationException("Home world/actor/payment binding denied");
            foreach(var expected in s.Home.Entities) {
                ulong id;if(!ulong.TryParse(expected.NetId,out id))throw new InvalidOperationException("Invalid saved home ID");
                var e=BaseNetworkable.serverEntities.Find(new NetworkableId(id)) as DecayEntity;string witness;
                if(e==null || e.IsDestroyed || !homeDisk.TryGetValue(e,out witness) || witness!=expected.NetId+"/"+e.prefabID || e.PrefabName!=expected.Prefab || e.GetType().Name!=expected.Type ||
                    e.OwnerID.ToString()!=s.Home.Owner || e.buildingID.ToString()!=expected.BuildingId || !Near(Point(e.transform.position),expected.Position,0.001f))
                    throw new InvalidOperationException("Missing/foreign/non-disk home; no rebuild");
                var q=e.transform.rotation;if(!Near(new[] {q.x,q.y,q.z,q.w},expected.Rotation,0.001f))throw new InvalidOperationException("Home rotation changed");
                var block=e as BuildingBlock;if(block!=null && block.grade.ToString()!=expected.Grade)throw new InvalidOperationException("Saved home grade changed");
                homeEntities.Add(expected.Role,e);
            }
            homeForeign=ForeignHomeKey();HomeRequireStructure(s.Home.Owner);
            var tc=(BuildingPrivlidge)homeEntities["TC"];
            if(tc.authorizedPlayers.Count!=1 || !tc.authorizedPlayers.Contains(s.Authorized[0]) || Key(HomeTcItems(),false)!=Key(s.TcInventory,false) || tc.GetProtectedMinutes(true)<=0)
                throw new InvalidOperationException("TC captured/inventory changed/upkeep absent; no rebind");
            // Engine IDs are transient, and a current foreign bot alias must not gain or lose permission.
            var alias=BasePlayer.FindBot(s.Authorized[0]);if(alias!=null && alias!=npc)throw new InvalidOperationException("Old TC bot identity currently belongs to another native actor");
            homeForeign=ForeignHomeKey();homeSite=homeEntities["FOUNDATION"].transform.position;homeRotation=homeEntities["FOUNDATION"].transform.rotation;
        }
        private void HomeRestoreRebind() {
            var tc=(BuildingPrivlidge)homeEntities["TC"];ulong old=homeRestoreSource.Authorized[0];
            foreach(var e in homeEntities.Values)e.OwnerID=npc.userID;
            if(old!=npc.userID){tc.RemovePlayer(npc,old);tc.AddPlayer(npc,npc.userID);}
            if(!tc.IsAuthed(npc) || !tc.CanBuild(npc) || tc.authorizedPlayers.Count!=1)throw new InvalidOperationException("Native TC rebind refused");
            homeRebind=new {SourceOwner=old.ToString(),CurrentOwner=npc.userID.ToString(),WorldValidated=true,DiskWitnesses=homeEntities.Count,ForeignAuth=false,ItemCredits=0,Builds=0};
            homeRestored=true;HomeRequireStructure();
            homeUpkeep=new {Restored=true,TcInventory=HomeTcItems(),ProtectedMinutes=tc.GetProtectedMinutes(true),ItemCredits=0};
            var door=homeEntities["DOOR"];var outside=door.transform.position+(door.transform.position-homeSite).normalized*1.6f;outside.y=TerrainMeta.HeightMap.GetHeight(outside);Vector3 foot;
            if(!NavSample(outside,out foot))throw new InvalidOperationException("Restored outside path unavailable");homeOutside=foot;homePhase="RESTORE_TRAVEL";HomeMove(foot,"RESTORE_OUTSIDE");
        }
        private bool HomeTick() {
            if(!firstHome || homePhase==null || homePhase=="TOOL" || homePhase=="GATHER")return false;
            float now=Time.realtimeSinceStartup;var position=npc.transform.position;float dt=now-previousTime,step=Vector3.Distance(previous,position);
            if(EquipmentValid()) {
                equipmentChecks++;
                if(mode=="RESTORE") {
                    if(JsonConvert.SerializeObject(HeldItems())!=stableHeld || !OldEntitiesUnchanged())throw Balance("Restored home held ownership/foreign refs changed");
                    equipmentSamples.Add(new {Time=now,Equipment=Equipment()});
                }
            }
            if(dt<=0 || dt>1.5f || step>5 || step>6*dt+1)throw new InvalidOperationException("Discontinuous HOME_NAV trace");
            if(homePhase=="NAV"){HomePhysicalSample(now);HomeCrossing(previous,position,now);}
            total+=step;previous=position;previousTime=now;Sample(now);
            if(now>deadline)throw new InvalidOperationException("Bounded FirstHome deadline");
            if(homePhase=="TRAVEL" || homePhase=="BUILD_TRAVEL" || homePhase=="RESTORE_TRAVEL") {
                if(HomeArrived(now))homePhase=homePhase=="RESTORE_TRAVEL"?"NAV_WAIT":"BUILD";
                if(homePhase=="NAV_WAIT")homeWait=now+30;return true;
            }
            if(homePhase=="BUILD"){HomeBuildStep();if(homePhase=="BUILD"){homePhase="BUILD_WAIT";homeWait=now+2;}return true;}
            if(homePhase=="BUILD_WAIT") {
                if(now<homeWait || RustNavigation.Instance.HasPendingTiles())return true;
                var stand=HomeBuildStand();if(Vector3.Distance(npc.transform.position,stand)<=0.3f)homePhase="BUILD";else{HomeMove(stand,"BUILD_"+homeStep);homePhase="BUILD_TRAVEL";}return true;
            }
            if(homePhase=="VERIFY"){if(now>=homeWait)HomeAuthorizeAndUpkeep();return true;}
            if(homePhase=="NAV_WAIT") {
                if(RustNavigation.Instance.HasPendingTiles()){if(now>=homeWait)throw new InvalidOperationException("Native home rebuild pending timeout");return true;}
                if(!HomeInterior(out homeInside)){if(now>=homeWait)throw new InvalidOperationException("HOME_NAV native floor/clearance/sample unavailable after rebuild");return true;}
                HomeReadPortal();HomeOpenDoor(true);homePhase="DOOR_WAIT";homeWait=now+1.5f;return true;
            }
            if(homePhase=="DOOR_WAIT") {
                if(now<homeWait)return true;
                var current=DoorColliders();bool changed=JsonConvert.SerializeObject(homeDoorClosed)!=JsonConvert.SerializeObject(current);
                homeNav.Add(new {Event="DOOR_COLLIDER",Time=now,Changed=changed,Closed=homeDoorClosed,Open=current});
                if(!changed)throw new InvalidOperationException("Native door hinge collider did not move");
                HomePhysicalSample(now);HomeMove(homeInside,"INSIDE_TC");homePhase="NAV";homeNavStage=0;return true;
            }
            if(homePhase=="NAV" && HomeArrived(now)) {
                if(homeNavStage==0) {
                    var tc=homeEntities["TC"];float range=Vector3.Distance(position,tc.transform.position);
                    bool los=!Physics.RaycastAll(position+Vector3.up*1.2f,(tc.transform.position+Vector3.up*0.6f-position-Vector3.up*1.2f).normalized,range,Physics.DefaultRaycastLayers,QueryTriggerInteraction.Ignore)
                        .Any(x=>x.collider.GetComponentInParent<BaseEntity>()!=npc && x.collider.GetComponentInParent<BaseEntity>()!=tc);
                    if(!homeCrossedIn || range>2 || !los)throw new InvalidOperationException("Physical doorway/TC arrival LOS/range not proven");
                    homeNav.Add(new {Event="TC_REACHED",Range=range,LineOfSight=los,Time=now,Position=Point(position)});HomeMove(homeOutside,"OUTSIDE");homeNavStage=1;
                }else {
                    if(!homeCrossedOut)throw new InvalidOperationException("Physical exit portal crossing missing");HomeOpenDoor(false);homeNavComplete=true;
                    if(!Activate(product.uid) || !EquipmentValid())throw new InvalidOperationException("Home paid held axe lost");Save();Finish("GREEN","Native paid home/TC/upkeep and physical RustNav "+mode);
                }
            }
            return true;
        }
        private object HomeResult() {
            return !firstHome?null:new {Schema=1,Stage=homePhase,Placement="SERVER_ACCOUNTED_BUILD",Site=homeSiteReceipt,RejectedSites=homeSites,Budget=homeBudget,Recipes=homeRecipes,GradeCosts=homeGradeCosts,
                Operations=homeOperations,Home=homeEntities.Count==8?DescribeHome():null,PartialEntities=homeEntities.Select(x=>HomeRow(x.Key,x.Value)).ToArray(),
                Decay=new {Enabled=ConVar.Decay.upkeep,Scale=ConVar.Decay.scale,WoodDuration=ConVar.Decay.duration_wood},
                Upkeep=homeUpkeep,Portal=homePortal,Navigation=homeNav,NavigationComplete=homeNavComplete,CrossedIn=homeCrossedIn,CrossedOut=homeCrossedOut,Restored=homeRestored,Rebind=homeRebind,
                Snapshot=homeSnapshot,Source=homeRestoreSource,PendingIntent=homeIntent,SaveReady=homeSnapshot!=null,
                NativeCapsule=npc==null?new object[0]:npc.GetComponents<Collider>().Select(x=>(object)new {Type=x.GetType().Name,x.enabled,x.isTrigger}).ToArray()};
        }
    }
}
