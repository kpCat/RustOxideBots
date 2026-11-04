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
        private const int HomeJourneySeconds=2100,HomeSmokeSeconds=900,HomeBuildReserve=360,HomeGatherReserve=1350;
        private bool firstHome,homeGather,homeRestored,homeNavComplete,homeSmoke;
        private string homeAdmissionReason,homeObservedPhase;
        private bool homeTcAttempted,homeDoorAttempted;
        private readonly List<object> homeApproaches=new List<object>(),homeTileStates=new List<object>();
        private float homeTilesDeadline;
        private bool homeTilesPending;
        private readonly List<object> homeTcPreviews=new List<object>();
        private sealed class HomeTcDiagnostic {
            public bool OnTerrain,NativePreview,NativeLos,InsideObject,DeployBlocked,CanBuild,HookDenied,Unchanged,LegacyUnchanged;
            public int MaleSockets;
            public string Socket,Parent,SurfaceParent;
            public float Reach,MaxReach;
            public object Evidence;
        }
        private readonly List<object> homeFixture=new List<object>(),homePlacements=new List<object>(),homePhases=new List<object>();
        private string homePhase,homeIntent,homeForeign;
        private float homeWait,homeLegTime,homeTravelSeconds;
        private int homeStep,homeNavStage,homeSearchIndex;
        private Vector3 homeSite,homeOutside,homeInside,homeNavStart,homeSearchOrigin;
        private DecayEntity[] homeForeignStructures;
        private const int HomeSearchLimit=(512+4096)*4;
        private Quaternion homeRotation;
        private HomeSnapshot homeSnapshot;
        private readonly Dictionary<string,Construction> homeDefinitions=new Dictionary<string,Construction>();
        private readonly Dictionary<string,RecipeRow> homeRecipes=new Dictionary<string,RecipeRow>();
        private readonly Dictionary<string,int> homeBudget=new Dictionary<string,int>();
        private readonly Dictionary<string,List<Cost>> homeGradeCosts=new Dictionary<string,List<Cost>>();
        private readonly Dictionary<string,DecayEntity> homeEntities=new Dictionary<string,DecayEntity>();
        private readonly Dictionary<BaseEntity,string> homeDisk=new Dictionary<BaseEntity,string>();
        private readonly List<object> homeSites=new List<object>(),homeOperations=new List<object>(),homeNav=new List<object>();
        private readonly List<object> homeToolSwitches=new List<object>();
        private Item homeGatherTool;
        private object homeSiteReceipt,homeUpkeep,homeRebind,homePortal,homeDoorClosed,homeTcAuthorization;
        private readonly Dictionary<string,Item> homeTools=new Dictionary<string,Item>();
        private string HomeData { get { return Data("economy.home.json"); } }
        private void HomeIssueFixture() {
            if(!homeSmoke || mode!="BUILD_SMOKE" || homeFixture.Count!=0 || Contents().Any(x=>x.Shortname!="rock"))throw new InvalidOperationException("Fixture issuance outside diagnostic-only empty inventory");
            var budget=new Dictionary<string,int>(homeBudget);
            foreach(var cost in recipe.Ingredients){if(!budget.ContainsKey(cost.Shortname))budget[cost.Shortname]=0;budget[cost.Shortname]+=cost.Amount;}
            foreach(var cost in budget) {
                int left=cost.Value;
                while(left>0) {
                    int amount=Math.Min(left,1000);var item=ItemManager.CreateByName(cost.Key,amount);
                    if(item==null || !item.MoveToContainer(npc.inventory.containerMain,-1,false))throw new InvalidOperationException("Diagnostic fixture native transfer failed");
                    var receipt=new {Source=cost.Key=="wood"?"TEST_FIXTURE_WOOD":"TEST_FIXTURE_STONES",DiagnosticOnly=true,Item=Row(item),Amount=amount};
                    homeFixture.Add(receipt);Log("TEST_FIXTURE",receipt);left-=amount;
                }
            }
        }
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
        private static bool HomeStructural(DecayEntity e) { return e is BuildingBlock || e is BuildingPrivlidge || e is Door; }
        private string ForeignHomeKey() {
            return JsonConvert.SerializeObject(BaseNetworkable.serverEntities.OfType<DecayEntity>().Where(x=>HomeStructural(x) && !homeEntities.Values.Contains(x)).OrderBy(x=>x.net.ID.Value)
                .Select(x=>new {Id=Id(x),x.OwnerID,x.buildingID,Position=Point(x.transform.position)}));
        }
        private void BeginHomeGather() {
            agent.isStopped=true;navigating=false;homeSearchOrigin=npc.transform.position;homeSearchIndex=0;
            homeForeignStructures=BaseNetworkable.serverEntities.OfType<DecayEntity>().Where(HomeStructural).ToArray();
            homePhase="SITE_SEARCH";state.Goal="HOME_SITE";
        }
        private void HomeGatherAtSelectedSite() {
            if(homeSmoke){HomeMaterialsReady();return;}
            homeGather=true;homePhase="GATHER";state.Goal="NEED_RESOURCE";discoveries=0;rejected.Clear();
            homeGatherTool=product;
            if(!Activate(product.uid))throw new InvalidOperationException("Home earned axe missing");melee=npc.GetHeldEntity() as BaseMelee;
            if(melee==null)throw new InvalidOperationException("Home gathering requires paid held axe");Discover();
        }
        private bool HomeSwitchGatherTool() {
            if(dispenser==null || homeGatherTool==null)throw new InvalidOperationException("Home gathering tool/source missing");
            float wear=melee.GetGatherInfoFromIndex(dispenser.gatherType).conditionLost;
            if(wear<=0 || float.IsNaN(wear) || float.IsInfinity(wear))throw new InvalidOperationException("Unknown loaded tool wear");
            if(homeGatherTool.condition>wear+1)return false;
            if(homeGatherTool!=product || product.condition<=0 || rock==null || rock.GetOwnerPlayer()!=npc || rock.parent!=npc.inventory.containerBelt || homeToolSwitches.Count!=0)
                throw new InvalidOperationException("Bounded home tool durability unavailable before native debit");
            var before=Contents();
            if(!Activate(rock.uid))throw new InvalidOperationException("Original rock activation refused");
            melee=npc.GetHeldEntity() as BaseMelee;
            if(melee==null || melee.GetItem()!=rock || melee.GetOwnerPlayer()!=npc || rock.condition<=melee.GetGatherInfoFromIndex(dispenser.gatherType).conditionLost+1)
                throw new InvalidOperationException("Original rock cannot sustain home gather");
            homeGatherTool=rock;
            var receipt=new {FromUid=product.uid.Value.ToString(),ToUid=rock.uid.Value.ToString(),Wear=wear,Reserve=1,Before=before,After=Contents(),Equipment=Equipment(rock)};
            homeToolSwitches.Add(receipt);Log("HOME_TOOL_SWITCH",receipt);
            // A rock has a shorter reach. Reuse discovery/physical approach with its actual loaded profile.
            navigating=false;agent.isStopped=true;state.Goal="NEED_RESOURCE";nextAction=Time.realtimeSinceStartup+Mathf.Max(1,melee.repeatDelay);Discover();return true;
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
            homeForeignStructures=BaseNetworkable.serverEntities.OfType<DecayEntity>().Where(HomeStructural).ToArray();
            // Revalidate the selected footprint BEFORE any home craft payment. Never buy tools then choose a different site.
            if(!HomeCheckSite(homeSite,homeRotation))throw new InvalidOperationException("Home admission rejected before paid home craft: "+homeAdmissionReason);
            homeTools["building.planner"]=HomeCraft("building.planner",2);
            homeTools["hammer"]=HomeCraft("hammer",3);
            homeTools["door.hinged.wood"]=HomeCraft("door.hinged.wood",4);
            homeTools["cupboard.tool"]=HomeCraft("cupboard.tool",5);
            homeForeign=ForeignHomeKey();HomeMove(homeOutside,"SITE");homePhase="TRAVEL";
        }
        private void HomeSearchBatch() {
            float start=Time.realtimeSinceStartup;
            for(int count=0;count<64 && homeSearchIndex<HomeSearchLimit;count++) {
                int index=homeSearchIndex++,i=index/4+1;var rot=Quaternion.Euler(0,Mathf.Floor(Halton(i<=512?i:i-512,5)*8)*45+(index%4)*90,0);Vector3 p;
                if(i<=512) {
                    float angle=Halton(i,2)*Mathf.PI*2,r=8+Halton(i,3)*160;
                    p=homeSearchOrigin+new Vector3(Mathf.Cos(angle),0,Mathf.Sin(angle))*r;
                }else {
                    i-=512;p=TerrainMeta.Position+new Vector3((0.05f+Halton(i,2)*0.9f)*TerrainMeta.Size.x,0,(0.05f+Halton(i,3)*0.9f)*TerrainMeta.Size.z);
                }
                p.y=TerrainMeta.HeightMap.GetHeight(p);
                if(Vector3.Distance(p,npc.transform.position)>800)homeSites.Add(new {Candidate=Point(p),Reasons=new[] {"APPROACH_BOUND"}});
                else if(HomeCheckSite(p,rot)){HomeGatherAtSelectedSite();return;}
                if(Time.realtimeSinceStartup-start>0.03f)break;
            }
            if(homeSearchIndex>=HomeSearchLimit)throw new InvalidOperationException("Bounded safe home site unavailable before materials");
        }
        private bool HomeCheckSite(Vector3 p,Quaternion rot) {
                var reasons=new List<string>();
                float min,max;bool water;HomeSurface(p,rot,out min,out max,out water);p.y=max+0.12f;
                Vector3 foot=Vector3.zero;bool sampled=false;
                Construction.Placement preview=default(Construction.Placement);bool nativePreview=false;
                // Native terrain yaw follows the planning ray. Recompute the -Z doorway approach after each prediction.
                for(int pass=0;pass<4;pass++) {
                    var outside=p+rot*new Vector3(0,0,-3);outside.y=TerrainMeta.HeightMap.GetHeight(outside);NavHit navHit;
                    sampled=RustNavigation.Instance.DefaultNavmesh.SamplePosition(new NavVector3(outside),out navHit,new Vector3(0.25f,0.5f,0.25f),false) && Ground(navHit.position.Value,out foot);
                    if(!sampled || !HomeFoundationPreview(p,foot,out preview))break;
                    float turn=Quaternion.Angle(preview.rotation,rot);rot=preview.rotation;
                    HomeSurface(p,rot,out min,out max,out water);float height=max+0.12f;
                    nativePreview=turn<0.05f && Mathf.Abs(height-p.y)<0.01f && Vector3.Distance(preview.position,p)<0.05f;
                    p.y=height;if(nativePreview)break;
                }
                float depth=homeDefinitions["FOUNDATION"].bounds.size.y;
                float entryDelta=p.y-TerrainMeta.HeightMap.GetHeight(p+rot*new Vector3(0,0,-1.5f));
                float outsideDelta=p.y-TerrainMeta.HeightMap.GetHeight(foot);
                if(water)reasons.Add("WATER");
                if(depth<=0 || max-min>depth*0.5f)reasons.Add("FOUNDATION_DEPTH");
                if(Mathf.Abs(entryDelta)>0.25f || !sampled || Mathf.Abs(outsideDelta)>0.25f)reasons.Add("ENTRANCE_HEIGHT");
                if(!nativePreview)reasons.Add("NATIVE_FOUNDATION_PREVIEW");
                var siteObb=new OBB(p,rot,new Bounds(new Vector3(0,0.1f,0),new Vector3(5,6,5)));
                var nearest=homeForeignStructures.Where(x=>x!=null && !x.IsDestroyed).OrderBy(x=>x.WorldSpaceBounds().Distance(siteObb)).FirstOrDefault();
                float foreignDistance=nearest==null?float.MaxValue:nearest.WorldSpaceBounds().Distance(siteObb);
                if(foreignDistance<45)reasons.Add("FOREIGN_BUILDING_OR_TC");
                float monumentOrigin=float.MaxValue,monumentBounds=float.MaxValue;
                foreach(var monument in TerrainMeta.Path.Monuments) {
                    monumentOrigin=Math.Min(monumentOrigin,Vector3.Distance(monument.transform.position,p));monumentBounds=Math.Min(monumentBounds,monument.Distance(siteObb));
                }
                bool preventBuilding=GamePhysics.CheckOBB(siteObb,Rust.Layers.Mask.Prevent_Building,QueryTriggerInteraction.Collide);
                if(monumentOrigin<120 || monumentBounds<6 || preventBuilding)reasons.Add("MONUMENT_OR_PREVENT_BUILDING");
                int deny=(int)(TerrainTopology.Enum.Cliff|TerrainTopology.Enum.Cliffside|TerrainTopology.Enum.Mountain|TerrainTopology.Enum.Monument|TerrainTopology.Enum.Road|TerrainTopology.Enum.Roadside|
                    TerrainTopology.Enum.Rail|TerrainTopology.Enum.Railside|TerrainTopology.Enum.Building|TerrainTopology.Enum.Swamp|TerrainTopology.Enum.Ocean|TerrainTopology.Enum.Oceanside|
                    TerrainTopology.Enum.Offshore|TerrainTopology.Enum.River|TerrainTopology.Enum.Riverside|TerrainTopology.Enum.Lake|TerrainTopology.Enum.Lakeside);
                int topology=TerrainMeta.TopologyMap.GetTopology(p,6f);
                if((topology&deny)!=0)reasons.Add("TOPOLOGY");
                float roadDistance=float.MaxValue;
                foreach(var road in TerrainMeta.Path.Roads) {
                    var points=road.Path.Points;
                    for(int j=1;j<points.Length;j++) {
                        var a=points[j-1];var d=points[j]-a;float t=d.sqrMagnitude>0?Mathf.Clamp01(Vector3.Dot(p-a,d)/d.sqrMagnitude):0;
                        roadDistance=Math.Min(roadDistance,Vector3.Distance(p,a+d*t));
                    }
                }
                if(roadDistance<25)reasons.Add("ROAD");
                // Reject every above-ground collider, including natural resources. Never delete it to fit.
                int collisions=Physics.OverlapBox(p+Vector3.up*1.6f,new Vector3(2.5f,1.45f,2.5f),rot,Physics.DefaultRaycastLayers,QueryTriggerInteraction.Ignore).Count(c=>c.GetComponentInParent<BaseEntity>()!=npc);
                if(collisions!=0)reasons.Add("COLLISION");
                var privilege=npc.GetBuildingPrivilege(siteObb,false,1f,null,false);bool permission=npc.CanBuild(siteObb,false);
                if(privilege!=null || !permission)reasons.Add("BUILD_PERMISSION_OR_FOREIGN_TC");
                var path=new RustNavMeshPath();bool complete=false;float pathLength=0,travelSeconds=0,remaining=deadline-Time.realtimeSinceStartup,reserve=homePhase=="SITE_SEARCH" && !homeSmoke?HomeGatherReserve:HomeBuildReserve;
                if(reasons.Count==0) {
                    complete=agent.CalculatePath(foot,path) && path.status==NavMeshPathStatus.PathComplete;
                    if(!complete)reasons.Add("NAV_PATH");
                    else {
                        pathLength=path.GetPathLength();travelSeconds=Mathf.Ceil(pathLength/3+30);
                        if(pathLength>800 || travelSeconds>300)reasons.Add("TRAVEL_BUDGET");
                        if(remaining<travelSeconds+reserve)reasons.Add("TIME_BUDGET");
                    }
                }
                homeAdmissionReason=string.Join(",",reasons.ToArray());
                if(reasons.Count!=0){homeSites.Add(new {Phase=homePhase,Candidate=Point(p),Reasons=reasons,PathLength=pathLength,TravelSeconds=travelSeconds,DeadlineRemaining=remaining,PhaseReserve=reserve,HeightRange=max-min,FoundationDepth=depth,EntryDelta=entryDelta,OutsideDelta=outsideDelta,Water=water,Topology=topology,NativePreview=nativePreview,Sampled=sampled,Path=path.status.ToString(),Complete=complete,Collisions=collisions,
                    MonumentOriginDistance=monumentOrigin,MonumentBoundsDistance=monumentBounds,PreventBuilding=preventBuilding,ForeignDistance=foreignDistance,ForeignId=Id(nearest),ForeignType=nearest==null?null:nearest.GetType().Name,PrivilegeId=Id(privilege),RoadDistance=roadDistance});return false;}
                homeSite=p;homeRotation=rot;homeOutside=foot;
                homeSiteReceipt=new {Position=Point(p),Rotation=new[] {rot.x,rot.y,rot.z,rot.w},HeightRange=max-min,FoundationDepth=depth,EntryDelta=entryDelta,OutsideDelta=outsideDelta,NativePreview=nativePreview,
                    Water=false,Topology=topology,ForbiddenTopology=deny,Monument=false,Road=false,Foreign=false,Collision=false,Permission=true,Path=path.status.ToString(),
                    MonumentOriginDistance=monumentOrigin,MonumentBoundsDistance=monumentBounds,PreventBuilding=preventBuilding,ForeignDistance=foreignDistance,RoadDistance=roadDistance,
                    PrivilegeChecked=true,PermissionCached=false,PrivilegeId=Id(privilege),PathLength=pathLength,TravelSeconds=travelSeconds,DeadlineRemaining=remaining,PhaseReserve=reserve,SearchLimit=HomeSearchLimit,SearchIndex=homeSearchIndex};
                Log("HOME_SITE",homeSiteReceipt);return true;
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
            homeTravelSeconds=Mathf.Ceil(path.GetPathLength()/3+30);
            if(homeTravelSeconds>300)throw new InvalidOperationException("HOME_NAV travel bound exceeds300 seconds");
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
            if(now-homeLegTime>homeTravelSeconds)throw new InvalidOperationException("HOME_NAV physical travel timeout");
            if(now-progressTime>12){if(repaths++>=1)throw new InvalidOperationException("HOME_NAV bounded stuck");if(!agent.SetDestination(target))throw new InvalidOperationException("Home repath failed");agent.speed=3;progressTime=now;}
            return false;
        }
        private Socket_Base HomeSocket(BaseEntity entity,string suffix) {
            var list=PrefabAttribute.server.FindAll<Socket_Base>(entity.prefabID).Where(x=>x.female && !x.femaleDummy && !x.femaleNoStability && x.socketName.EndsWith(suffix,StringComparison.Ordinal)).ToArray();
            if(list.Length!=1)throw new InvalidOperationException("Ambiguous native home socket "+suffix);return list[0];
        }
        private Construction.Target HomeTarget(Construction c,BaseEntity parent,Socket_Base socket,Vector3 position) {
            // Socket_Free.TestTarget reads onTerrain even on a building surface. A female socket uses false.
            var target=new Construction.Target {valid=true,player=npc,entity=parent,socket=socket,onTerrain=socket==null,position=position,normal=Vector3.up,
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
        private HomeTcDiagnostic HomePreviewTc(Construction c,Construction.Target t,string label,bool hookDenied,bool priorUnchanged=true) {
            var before=JsonConvert.SerializeObject(Contents());int entities=BaseNetworkable.serverEntities.Count;
            var oldPhrase=Construction.lastPlacementError;var oldDebug=Construction.lastPlacementErrorDebug;
            bool oldDetailed=Construction.lastPlacementErrorIsDetailed;var oldBlock=Construction.lastBuildingBlockError;var oldHit=DeployVolume.LastDeployHit;
            var scratch=new GameObject("RustBots012ReadOnlyPlacement");
            try {
                var male=new List<Socket_Base>();c.FindMaleSockets(t,male);
                var predictions=new List<object>();bool los=false,blocked=false;
                foreach(var socket in male) {
                    var p=socket.DoPlacement(t);bool populated=p.isPopulated,mods=populated && socket.CheckSocketMods(ref p);
                    bool sight=populated && Planner.HasLineOfSight(ref p,c,t);
                    bool volume=populated && DeployVolume.Check(p.position,p.rotation,PrefabAttribute.server.FindAll<DeployVolume>(c.prefabID),-1);
                    predictions.Add(new {Socket=socket.socketName,Type=socket.GetType().Name,Populated=populated,Mods=mods,Position=Point(p.position),Rotation=Point(p.rotation.eulerAngles),NativeLos=sight,DeployBlocked=volume,DeployHit=DeployVolume.LastDeployHit==null?null:DeployVolume.LastDeployHit.name});
                    los=sight;blocked=volume;
                }
                Construction.lastPlacementError="";Construction.lastPlacementErrorDebug="";Construction.lastPlacementErrorIsDetailed=false;Construction.lastBuildingBlockError=null;
                var trial=t;bool preview=c.UpdatePlacement(scratch.transform,c,ref trial);
                var phrase=Construction.lastPlacementError==null?null:Construction.lastPlacementError.translated;
                var debug=Construction.lastPlacementErrorDebug;
                var surface=Physics.RaycastAll(t.position+Vector3.up*0.1f,Vector3.down,0.2f,Physics.DefaultRaycastLayers,QueryTriggerInteraction.Ignore)
                    .Where(x=>x.normal.y>=0.85f).OrderBy(x=>x.distance).ToArray();
                var obb=new OBB(scratch.transform.position,scratch.transform.rotation,c.bounds);
                bool inside=AntiHack.TestIsBuildingInsideSomething(t,t.position);
                var result=new HomeTcDiagnostic {OnTerrain=t.onTerrain,Socket=t.socket==null?null:t.socket.socketName,Parent=Id(t.entity),SurfaceParent=surface.Length==0?null:Id(surface[0].collider.GetComponentInParent<BaseEntity>()),
                    MaleSockets=male.Count,NativePreview=preview,NativeLos=los,InsideObject=inside,DeployBlocked=blocked,CanBuild=npc.CanBuild() && npc.CanBuild(scratch.transform.position,scratch.transform.rotation,c.bounds),HookDenied=hookDenied,
                    Reach=Vector3.Distance(npc.eyes.position,t.position),MaxReach=c.maxplaceDistance,Unchanged=entities==BaseNetworkable.serverEntities.Count && before==JsonConvert.SerializeObject(Contents()),LegacyUnchanged=priorUnchanged,
                    Evidence=new {Label=label,Valid=t.valid,Player=Id(npc),ActiveUid=npc.GetActiveItem()==null?null:npc.GetActiveItem().uid.Value.ToString(),Held=Id(npc.GetHeldEntity()),Deployable=c.deployable==null?null:c.deployable.fullName,
                        Position=Point(t.position),Normal=Point(t.normal),Rotation=Point(t.rotation),RayOrigin=Point(t.ray.origin),RayDirection=Point(t.ray.direction),t.shouldParent,t.isSnapped,t.snappingMode,
                        ParentPosition=t.entity==null?null:Point(t.entity.transform.position),ParentRotation=t.entity==null?null:Point(t.entity.transform.rotation.eulerAngles),Predictions=predictions,Phrase=phrase,ErrorDebug=debug,Detailed=Construction.lastPlacementErrorIsDetailed,
                        PreviewPosition=Point(scratch.transform.position),PreviewRotation=Point(scratch.transform.rotation.eulerAngles),BoundsCenter=Point(obb.position),BoundsExtents=Point(obb.extents),
                        Surface=surface.Select(x=>new {Entity=Id(x.collider.GetComponentInParent<BaseEntity>()),Name=x.collider.name,Type=x.collider.GetType().Name,Layer=x.collider.gameObject.layer,Position=Point(x.point),Normal=Point(x.normal)}).ToArray(),
                        Overlaps=Physics.OverlapBox(obb.position,obb.extents,scratch.transform.rotation,Physics.DefaultRaycastLayers,QueryTriggerInteraction.Ignore).Select(x=>new {Entity=Id(x.GetComponentInParent<BaseEntity>()),Name=x.name,Layer=x.gameObject.layer}).ToArray(),
                        Capsule=npc.GetComponents<Collider>().Select(x=>new {Type=x.GetType().Name,x.enabled,x.isTrigger,Center=Point(x.bounds.center),Extents=Point(x.bounds.extents)}).ToArray(),
                        Nearby=BaseNetworkable.serverEntities.OfType<DecayEntity>().Where(x=>HomeStructural(x) && Vector3.Distance(x.transform.position,t.position)<6).Select(x=>HomeRow("NEARBY",x)).ToArray(),
                        CanPlacePrivilege=npc.CanPlaceBuildingPrivilege(scratch.transform.position,scratch.transform.rotation,c.bounds,null),Privilege=Id(npc.GetBuildingPrivilege(obb,false,0,null,true))}};
                homeTcPreviews.Add(result);Log("HOME_TC_PREVIEW",result);return result;
            }finally {
                UnityEngine.Object.Destroy(scratch);Construction.lastPlacementError=oldPhrase;Construction.lastPlacementErrorDebug=oldDebug;Construction.lastPlacementErrorIsDetailed=oldDetailed;Construction.lastBuildingBlockError=oldBlock;DeployVolume.LastDeployHit=oldHit;
            }
        }
        private BaseEntity HomePlace(string role,string definition,string tool,BaseEntity parent,Socket_Base socket,Vector3 position) {
            Item item=homeTools[tool];if(!Activate(item.uid))throw new InvalidOperationException("Paid planner activation failed");
            var planner=npc.GetHeldEntity() as Planner;var c=homeDefinitions[definition];
            if(planner==null || planner.GetItem()!=item || planner.GetOwnerPlayer()!=npc || planner.GetDeployable()!=c.deployable || !planner.CanAffordToPlace(c) ||
                !npc.CanBuild() || !npc.CanBuild(position,homeRotation,c.bounds) || Vector3.Distance(npc.eyes.position,position)>c.maxplaceDistance+0.01f)
                throw new InvalidOperationException("Native home ownership/permission/affordability/reach gate "+role);
            var t=HomeTarget(c,parent,socket,position);
            if(!t.valid)throw new InvalidOperationException("Native placement support surface unavailable");
            bool hookDenied=Oxide.Core.Interface.CallHook("CanBuild",planner,c,t)!=null;
            if(hookDenied)throw new InvalidOperationException("Native CanBuild hook denied home");
            HomeTcDiagnostic diagnostic=null;
            if(role=="TC") {
                if(homeTcAttempted)throw new InvalidOperationException("TC paid retry forbidden");
                var legacy=t;legacy.onTerrain=false;var legacyPreview=HomePreviewTc(c,legacy,"011_TARGET_NO_SOCKET",false);
                if(!legacyPreview.Unchanged)throw new InvalidOperationException("Legacy TC preview changed native state; no paid attempt");
                diagnostic=HomePreviewTc(c,t,"012_FREE_SURFACE",hookDenied,legacyPreview.Unchanged);
                if(!diagnostic.NativePreview || !diagnostic.NativeLos || diagnostic.InsideObject || diagnostic.DeployBlocked || !diagnostic.CanBuild || !diagnostic.Unchanged || diagnostic.MaleSockets!=1 || diagnostic.SurfaceParent!=Id(parent))
                    throw new InvalidOperationException("PLACEMENT_TC_BLOCKED native preview; see HOME_TC_PREVIEW; no paid attempt");
                homeTcAttempted=true;
            }
            if(role=="DOOR") {
                if(homeDoorAttempted)throw new InvalidOperationException("Door paid retry forbidden");
                homeDoorAttempted=true;
            }
            var costs=definition=="DOOR" || definition=="TC"?new List<Cost>{new Cost {Shortname=tool,Amount=1}}:HomeCosts(c.defaultGrade.CostToBuild((BuildingGrade.Enum)(-1)));
            var before=Contents();HomeStartPayment("BUILD_"+role,new {Target=Point(position),Socket=socket==null?null:socket.socketName,Costs=costs});
            Log("HOME_NATIVE_ATTEMPT",new {Role=role,Definition=definition,Target=Point(t.position),RayOrigin=Point(t.ray.origin),Socket=socket==null?null:socket.socketName,Parent=Id(parent),Owner=npc.userID.ToString(),Time=Time.realtimeSinceStartup});
            var created=planner.DoBuild(t,c) as DecayEntity;
            string nativeDebug=Construction.lastPlacementErrorDebug,nativePhrase=Construction.lastPlacementError==null?null:Construction.lastPlacementError.translated;
            var placement=new {Role=role,NativeCall="Planner.DoBuild(Construction.Target,Construction)",Target=Point(t.position),Socket=socket==null?null:socket.socketName,Parent=Id(parent),Entity=Id(created),Error=nativeDebug,Phrase=nativePhrase,Detailed=Construction.lastPlacementErrorIsDetailed,Diagnostic=diagnostic,Before=before,After=Contents(),Time=Time.realtimeSinceStartup};
            homePlacements.Add(placement);Log("HOME_NATIVE_RESULT",placement);
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
                var prior=tc.authorizedPlayers.OrderBy(x=>x).ToArray();bool automatic=tc.IsAuthed(npc);var row=HomeRow("TC",tc);
                Log("HOME_TC_NEW_STATE",new {Owner=tc.OwnerID.ToString(),Actor=npc.userID.ToString(),Authorized=prior,Inventory=HomeTcItems(),Structure=row,NativeAutoauth=automatic});
                if(tc.OwnerID!=npc.userID || tc.buildingID!=foundation.buildingID || !row.Registered || tc.inventory==null || tc.inventory.itemList.Count!=0 || prior.Any(x=>x!=npc.userID))
                    throw new InvalidOperationException("New TC has foreign auth/items or invalid owner/building registration");
                // Installed ItemModDeployable.OnDeployed already authorizes the actual deploying player.
                // Only a missing self authorization may be added, with the same native hook gate.
                bool hookAllowed=automatic || Oxide.Core.Interface.CallHook("OnCupboardAuthorize",tc,npc)==null;
                if(!hookAllowed)throw new InvalidOperationException("Native TC authorization hook denied self");
                if(!automatic)tc.AddPlayer(npc,npc.userID);
                homeTcAuthorization=new {TcNetId=Id(tc),Owner=tc.OwnerID.ToString(),Actor=npc.userID.ToString(),BeforeAuthorized=prior,AfterAuthorized=tc.authorizedPlayers.OrderBy(x=>x).ToArray(),InventoryCount=tc.inventory.itemList.Count,
                    NativeAutoauth=automatic,NativeAddCalled=!automatic,AuthorizationHookAllowed=hookAllowed,Authed=tc.IsAuthed(npc),CanBuild=tc.CanBuild(npc),Registered=row.Registered,BuildingId=tc.buildingID.ToString(),ExpectedBuildingId=foundation.buildingID.ToString()};
                Log("HOME_TC_AUTH",homeTcAuthorization);
                if(!tc.IsAuthed(npc) || !tc.CanBuild(npc) || tc.authorizedPlayers.Any(x=>x!=npc.userID))throw new InvalidOperationException("Native TC auth refused before final door");homeStep++;return;
            }
            if(homeStep==7){var wall=homeEntities["DOORWAY"];var socket=HomeSocket(wall,"/doorway-female/1");HomePlace("DOOR","DOOR","door.hinged.wood",wall,socket,wall.transform.TransformPoint(socket.position));homeStep++;homeWait=Time.realtimeSinceStartup+8;homePhase="VERIFY";return;}
        }
        private Vector3 HomeBuildStand() {
            var foundation=homeEntities["FOUNDATION"];BaseEntity parent=foundation;Socket_Base socket=null;
            string definition;Vector3 place;
            if(homeStep<=4) {
                int[] suffix={3,4,2,1};socket=HomeSocket(foundation,"/wall-female/"+suffix[homeStep-1]);
                definition=homeStep==4?"DOORWAY":"WALL";place=foundation.transform.TransformPoint(socket.position);
            }else if(homeStep==5) {
                parent=homeEntities["WALL_N"];socket=HomeRoofSocket(parent);definition="ROOF";place=parent.transform.TransformPoint(socket.position);
            }else if(homeStep==6) {
                definition="TC";place=foundation.transform.TransformPoint(new Vector3(0.65f,0,0.6f));
            }else {
                definition="DOOR";parent=homeEntities["DOORWAY"];socket=HomeSocket(parent,"/doorway-female/1");place=parent.transform.TransformPoint(socket.position);
            }
            var c=homeDefinitions[definition];Vector3 foot;
            // Observe the exact old composite at the post-TC boundary before evaluating new candidates.
            if(homeStep==7)HomeLegacyApproach();
            if(HomeApproach(npc.transform.position,"CURRENT",c,parent,place,out foot))return npc.transform.position;
            var outward=place-foundation.transform.position;outward.y=0;
            if(homeStep>=6)outward=homeEntities["DOORWAY"].transform.position-foundation.transform.position;
            outward.y=0;if(outward.sqrMagnitude<0.01f)outward=foundation.transform.forward;outward.Normalize();
            var edge=homeStep>=6?homeEntities["DOORWAY"].transform.position:place;
            foreach(float distance in new[] {0.75f,1.25f,1.75f,2.25f})foreach(float side in new[] {0f,-0.6f,0.6f}) {
                var candidate=edge+outward*distance+Vector3.Cross(Vector3.up,outward)*side;
                candidate.y=TerrainMeta.HeightMap.GetHeight(candidate);
                if(HomeApproach(candidate,"GEOMETRY",c,parent,place,out foot))return foot;
            }
            throw new InvalidOperationException("No physical building approach; see HOME_APPROACH subreasons step="+homeStep);
        }
        private object HomeCollider(Collider c) {
            var e=c.GetComponentInParent<BaseEntity>();
            return new {Instance=c.GetInstanceID(),Name=c.name,Type=c.GetType().FullName,Layer=c.gameObject.layer,LayerName=LayerMask.LayerToName(c.gameObject.layer),Entity=Id(e),Owner=e==null?null:e.OwnerID.ToString(),Prefab=e==null?null:e.PrefabName,
                OwnerFlag=e==npc?"SELF":e==null?"NONE":e.OwnerID==npc.userID?"OWN":"FOREIGN",EntityType=e==null?null:e.GetType().FullName,
                Self=e==npc,Own=e!=null && homeEntities.Values.Contains(e as DecayEntity),Center=Point(c.bounds.center),Extents=Point(c.bounds.extents),Position=Point(c.transform.position),
                Rotation=new[] {c.transform.rotation.x,c.transform.rotation.y,c.transform.rotation.z,c.transform.rotation.w},Scale=Point(c.transform.lossyScale),c.enabled,c.isTrigger};
        }
        private void HomeLegacyApproach() {
            var input=homeSite+homeRotation*new Vector3(0,0,-3);input.y=TerrainMeta.HeightMap.GetHeight(input);NavHit hit;
            bool sampled=RustNavigation.Instance.DefaultNavmesh.SamplePosition(new NavVector3(input),out hit,new Vector3(2.5f,3,2.5f),false);
            var p=sampled?hit.position.Value:input;RaycastHit ray;
            bool rayHit=Physics.Raycast(p+Vector3.up*4,Vector3.down,out ray,8,Physics.DefaultRaycastLayers,QueryTriggerInteraction.Ignore);
            var foot=rayHit?ray.point+Vector3.up*0.05f:p;
            var overlaps=Physics.OverlapCapsule(foot+Vector3.up*0.57f,foot+Vector3.up*1.55f,0.45f,Physics.DefaultRaycastLayers,QueryTriggerInteraction.Ignore);
            float terrainDelta=rayHit?ray.point.y-TerrainMeta.HeightMap.GetHeight(ray.point):0,delta=rayHit?ray.point.y-p.y:0,water=WaterLevel.GetWaterSurface(foot,true,true,null)-foot.y;
            string reason=!sampled?"NAV_SAMPLE":!rayHit?"RAY_MISS":Mathf.Abs(delta)>1?"RAY_SAMPLE_HEIGHT":Mathf.Abs(terrainDelta)>0.8f?"RAY_TERRAIN_HEIGHT":ray.normal.y<0.85f?"SLOPE":water>0.15f?"WATER":overlaps.Length>0?"CAPSULE_OVERLAP":"ACCEPTED";
            var receipt=new {Label="LEGACY_COMPOSITE",Step=homeStep,Actor=Point(npc.transform.position),ActorNetId=Id(npc),Input=Point(input),Extents=new[] {2.5f,3,2.5f},Sampled=sampled,NavPoint=sampled?Point(p):null,
                Pending=RustNavigation.Instance.HasPendingTiles(),OnNavmesh=agent.isOnNavMesh,Reason=reason,RayHit=rayHit,FirstHit=rayHit?HomeCollider(ray.collider):null,RayPoint=rayHit?Point(ray.point):null,
                Normal=rayHit?Point(ray.normal):null,SampleDelta=delta,TerrainDelta=terrainDelta,WaterDepth=water,Overlaps=overlaps.Select(HomeCollider).ToArray(),Time=Time.realtimeSinceStartup};
            homeApproaches.Add(receipt);Log("HOME_APPROACH_LEGACY",receipt);
        }
        private bool HomeApproach(Vector3 input,string label,Construction c,BaseEntity parent,Vector3 place,out Vector3 foot) {
            bool pending=RustNavigation.Instance.HasPendingTiles();NavHit nav;
            var extents=new Vector3(0.25f,0.5f,0.25f);
            bool sampled=RustNavigation.Instance.DefaultNavmesh.SamplePosition(new NavVector3(input),out nav,extents,false);
            var p=sampled?nav.position.Value:input;
            // A current stand is evaluated at the real actor, never moved to a sampled point.
            var surfacePoint=label=="CURRENT"?input:p;var foundation=homeEntities["FOUNDATION"];
            var hits=Physics.RaycastAll(surfacePoint+Vector3.up*4,Vector3.down,8,Physics.DefaultRaycastLayers,QueryTriggerInteraction.Ignore).OrderBy(x=>x.distance).ToArray();
            var floors=hits.Where(x=>x.collider.GetComponentInParent<BaseEntity>()!=npc && Mathf.Abs(x.point.y-surfacePoint.y)<=0.25f &&
                (x.collider.GetComponentInParent<BaseEntity>()==foundation || x.collider.GetComponentInParent<BaseEntity>()==null && Mathf.Abs(x.point.y-TerrainMeta.HeightMap.GetHeight(x.point))<=0.1f)).ToArray();
            bool supported=floors.Length>0;var floor=supported?floors[0]:default(RaycastHit);
            foot=supported?floor.point+Vector3.up*0.05f:surfacePoint;
            var actualFoot=label=="CURRENT"?input:foot;
            var overlaps=Physics.OverlapCapsule(actualFoot+Vector3.up*0.5f,actualFoot+Vector3.up*1.3f,0.5f,Physics.DefaultRaycastLayers,QueryTriggerInteraction.Ignore);
            var blocking=overlaps.Where(x=>x.GetComponentInParent<BaseEntity>()!=npc &&
                !(supported && x.GetComponentInParent<BaseEntity>()==foundation && x.bounds.max.y<=actualFoot.y+0.03f)).ToArray();
            bool ownBlock=blocking.Any(x=>homeEntities.Values.Contains(x.GetComponentInParent<BaseEntity>() as DecayEntity));
            float water=WaterLevel.GetWaterSurface(actualFoot,true,true,null)-actualFoot.y;
            var eye=actualFoot+(npc.eyes.position-npc.transform.position);var delta=place-eye;
            var sight=Physics.RaycastAll(eye,delta.normalized,delta.magnitude,Physics.DefaultRaycastLayers,QueryTriggerInteraction.Ignore);
            bool los=!sight.Any(x=>x.collider.GetComponentInParent<BaseEntity>()!=npc && x.collider.GetComponentInParent<BaseEntity>()!=parent);
            float reach=Vector3.Distance(eye,place);
            bool permission=npc.CanBuild() && npc.CanBuild(place,homeRotation,c.bounds);
            var path=new RustNavMeshPath();bool calculated=false,complete=false;
            string reason=pending?"PENDING_TILES":!sampled?"NAV_SAMPLE":!supported?"GROUND_TERRAIN":floor.normal.y<0.85f?"SLOPE":
                Mathf.Abs(p.y-floor.point.y)>0.25f?"OWN_FOUNDATION_FLOOR":water>0.15f?"WATER":blocking.Length>0?(ownBlock?"CAPSULE_OWN_STRUCTURE":"CAPSULE_FOREIGN"):
                reach>c.maxplaceDistance?"DOOR_RANGE":!los?"DOOR_LOS":!permission?"PERMISSION":!agent.isOnNavMesh?"NAV_SAMPLE":"ACCEPTED";
            if(reason=="ACCEPTED") {
                calculated=agent.CalculatePath(actualFoot,path);complete=calculated && path.status==NavMeshPathStatus.PathComplete;
                if(!complete)reason="PATH_PARTIAL";
                else if(Time.realtimeSinceStartup+Mathf.Ceil(path.GetPathLength()/3+30)>deadline)reason="TIME_BUDGET";
            }
            var receipt=new {Step=homeStep,Label=label,ActorNetId=Id(npc),Actor=Point(npc.transform.position),Eyes=Point(npc.eyes.position),Candidate=Point(input),NavInput=Point(input),NavExtents=Point(extents),Sampled=sampled,NavPoint=sampled?Point(p):null,Foot=Point(actualFoot),
                Foundation=Id(foundation),FoundationPosition=Point(foundation.transform.position),FoundationRotation=Point(foundation.transform.rotation.eulerAngles),Doorway=homeEntities.ContainsKey("DOORWAY")?Point(homeEntities["DOORWAY"].transform.position):null,
                Surface=!supported?null:floor.collider.GetComponentInParent<BaseEntity>()==foundation?"OWN_FOUNDATION_FLOOR":"GROUND_TERRAIN",SurfaceEntity=supported?Id(floor.collider.GetComponentInParent<BaseEntity>()):null,
                SampleDelta=supported?p.y-floor.point.y:0,TerrainDelta=supported?floor.point.y-TerrainMeta.HeightMap.GetHeight(floor.point):0,NormalY=supported?floor.normal.y:0,
                RayHits=hits.Select(x=>new {Collider=HomeCollider(x.collider),Position=Point(x.point),Normal=Point(x.normal),x.distance}).ToArray(),WaterDepth=water,Overlaps=overlaps.Select(HomeCollider).ToArray(),Blocking=blocking.Select(HomeCollider).ToArray(),CapsuleClear=blocking.Length==0,
                Pending=pending,OnNavmesh=agent.isOnNavMesh,AgentPath=agent.pathStatus.ToString(),PathCalculated=calculated,Path=calculated?path.status.ToString():"NOT_CALCULATED",PathLength=complete?path.GetPathLength():0,
                CanBuild=permission,Los=los,LosHits=sight.Select(x=>HomeCollider(x.collider)).ToArray(),Reach=reach,MaxReach=c.maxplaceDistance,Place=Point(place),Parent=Id(parent),Accepted=reason=="ACCEPTED",Reason=reason,Time=Time.realtimeSinceStartup};
            homeApproaches.Add(receipt);Log("HOME_APPROACH",receipt);return reason=="ACCEPTED";
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
            var nativeRate=costs.Select(x=>new {Shortname=x.itemDef.shortname,Amount=x.amount}).ToArray();
            float beforeMinutes=tc.GetProtectedMinutes(true),period=tc.CalculateUpkeepPeriodMinutes();
            if(period<=0 || beforeMinutes!=0 || rate.Any(x=>Quantity(x.Shortname)<x.Amount))throw new InvalidOperationException("Native upkeep reserve insufficient or unaccounted protection");
            var before=Contents();var moved=new List<ItemRow>();
            HomeStartPayment("UPKEEP_TRANSFER",new {Rate=rate,Period=period,BeforeMinutes=beforeMinutes});
            foreach(var item in Containers().Take(2).SelectMany(x=>x.itemList).Where(x=>rate.Any(c=>c.Shortname==x.info.shortname)).ToArray()) {
                var row=Row(item);
                if(!item.MoveToContainer(tc.inventory,-1,false,false,npc,false))throw new InvalidOperationException("Native paid TC transfer refused; no retry");moved.Add(row);
            }
            var after=Contents();var tcItems=HomeTcItems();
            if(moved.Count==0 || moved.Any(x=>after.Any(y=>y.Uid==x.Uid) || !tcItems.Any(y=>y.Uid==x.Uid && y.Shortname==x.Shortname && y.Amount==x.Amount)))throw Balance("Native upkeep transfer UID mismatch");
            float minutes=tc.GetProtectedMinutes(true);
            homeUpkeep=new {Before=before,After=after,Transferred=moved,TcInventory=tcItems,Rate=rate,NativeRate=nativeRate,Period=period,MinutesBefore=beforeMinutes,MinutesAfter=minutes,Authed=tc.IsAuthed(npc),Privilege=true,DecayEnabled=ConVar.Decay.upkeep};
            Log("HOME_UPKEEP_MEASURED",homeUpkeep);
            if(float.IsNaN(minutes) || float.IsInfinity(minutes) || minutes<=beforeMinutes || minutes<60)throw new InvalidOperationException("Native TC protection >=60 minutes not proven");
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
            var a=p+Vector3.up*0.5f;var b=p+Vector3.up*1.3f;
            var overlaps=Physics.OverlapCapsule(a,b,0.5f,Physics.DefaultRaycastLayers,QueryTriggerInteraction.Ignore).OrderBy(x=>x.GetInstanceID()).ToArray();
            var collisions=overlaps.Where(x=>x.GetComponentInParent<BaseEntity>()!=npc && x.GetComponentInParent<BaseEntity>()!=foundation).ToArray();
            var local=foundation.transform.InverseTransformPoint(p);bool inside=Mathf.Abs(local.x)<1.4f && Mathf.Abs(local.z)<1.4f;
            var rays=Physics.RaycastAll(p+Vector3.up*0.3f,Vector3.down,0.6f,Physics.DefaultRaycastLayers,QueryTriggerInteraction.Ignore).OrderBy(x=>x.distance).ToArray();
            var hits=rays.Where(x=>x.collider.GetComponentInParent<BaseEntity>()==foundation && Mathf.Abs(x.point.y-p.y)<0.15f && x.normal.y>0.85f).ToArray();
            var bodies=npc.GetComponents<Collider>().OfType<CapsuleCollider>().ToArray();NavHit nav;Vector3 ground;
            bool sampled=RustNavigation.Instance.DefaultNavmesh.SamplePosition(new NavVector3(p),out nav,new Vector3(0.25f,0.5f,0.25f),false);
            bool grounded=Ground(p,out ground,false);var path=new RustNavMeshPath();bool calculated=agent.CalculatePath(target,path);
            var receipt=new {Event="PHYSICS",Schema=2,Time=now,ActorNetId=Id(npc),Position=Point(p),Previous=Point(previous),Velocity=Point(agent.velocity.Value),
                Clear=collisions.Length==0,LegacyClear=collisions.Length==0,Inside=inside,OwnedFloor=hits.Length>0,FoundationLocal=Point(local),
                CapsuleA=Point(a),CapsuleB=Point(b),Radius=0.5f,Height=1.8f,Mask=Physics.DefaultRaycastLayers,Triggers="Ignore",OverlapCount=overlaps.Length,
                Overlaps=overlaps.Select(c=>HomeContact(c,p,rays,bodies)).ToArray(),
                FloorRays=rays.Select(x=>new {Collider=HomeCollider(x.collider),Position=Point(x.point),Normal=Point(x.normal),x.distance,FootDelta=p.y-x.point.y}).ToArray(),
                WaterDepth=WaterLevel.GetWaterSurface(p,true,true,null)-p.y,TerrainHeight=TerrainMeta.HeightMap.GetHeight(p),Ground=grounded,GroundPoint=Point(ground),NativeGrounded=npc.IsOnGround(),
                NavSampled=sampled,NavPosition=sampled?Point(nav.position.Value):null,Pending=RustNavigation.Instance.HasPendingTiles(),OnNavmesh=agent.isOnNavMesh,
                Path=agent.pathStatus.ToString(),agent.hasPath,agent.pathPending,agent.remainingDistance,Calculated=calculated,CalculatedPath=calculated?path.status.ToString():"NOT_CALCULATED",Target=Point(target),
                NativeRadius=BasePlayer.GetRadius(),NativeHeight=npc.GetHeight(),NativeCapsules=bodies.Select(HomeNativeCapsule).ToArray(),AgentHeight=agent.height,AgentBaseOffset=agent.baseOffset,
                DoorOpen=((Door)homeEntities["DOOR"]).IsOpen(),DoorPosition=Point(homeEntities["DOOR"].transform.position),DoorColliders=DoorColliders(),Portal=homePortal,
                Guard=collisions.Length!=0?"OVERLAP":inside && hits.Length==0?"OWNED_FLOOR":"ACCEPTED"};
            homeNav.Add(receipt);Log("HOME_PHYSICS",receipt);
            if(collisions.Length!=0 || inside && hits.Length==0)throw new InvalidOperationException("HOME_NAV physical collider/support clearance failed");
        }
        private object HomeNativeCapsule(CapsuleCollider c) {
            var axis=c.direction==0?Vector3.right:c.direction==1?Vector3.up:Vector3.forward;
            float segment=Mathf.Max(0,c.height*0.5f-c.radius);var s=c.transform.lossyScale;
            float radiusScale=c.direction==0?Mathf.Max(Mathf.Abs(s.y),Mathf.Abs(s.z)):c.direction==1?Mathf.Max(Mathf.Abs(s.x),Mathf.Abs(s.z)):Mathf.Max(Mathf.Abs(s.x),Mathf.Abs(s.y));
            return new {Instance=c.GetInstanceID(),Radius=c.radius,Height=c.height,Direction=c.direction,Center=Point(c.center),Scale=Point(s),Enabled=c.enabled,Trigger=c.isTrigger,
                A=Point(c.transform.TransformPoint(c.center-axis*segment)),B=Point(c.transform.TransformPoint(c.center+axis*segment)),WorldRadius=c.radius*radiusScale,Collider=HomeCollider(c)};
        }
        private object HomeContact(Collider c,Vector3 p,RaycastHit[] rays,CapsuleCollider[] bodies) {
            var e=c.GetComponentInParent<BaseEntity>();var role=homeEntities.FirstOrDefault(x=>x.Value==e).Key;
            string category=e==npc?"NPC_SELF":c is TerrainCollider?"TERRAIN":role=="DOOR"?(((Door)e).IsOpen()?"DOOR_OPEN":"DOOR_CLOSED"):role??(e==null?"ENVIRONMENT":"FOREIGN");
            bool legacy=e!=npc && e!=homeEntities["FOUNDATION"];
            bool closestSupported=c is BoxCollider || c is SphereCollider || c is CapsuleCollider || c is MeshCollider && ((MeshCollider)c).convex;
            var measurements=new List<object>();
            foreach(var body in bodies) {
                Vector3 direction=Vector3.zero;float distance=0;bool intersects=false;string error=null;
                if(body!=c) {
                    try { intersects=Physics.ComputePenetration(body,body.transform.position,body.transform.rotation,c,c.transform.position,c.transform.rotation,out direction,out distance); }
                    catch(Exception ex) { error=ex.GetType().Name; }
                }
                measurements.Add(new {ActorCollider=body.GetInstanceID(),Intersects=intersects,Distance=distance,Direction=Point(direction),Error=error});
            }
            return new {Collider=HomeCollider(c),Category=category,LegacyBlocking=legacy,Decision=e==npc?"SELF":legacy?"BLOCKING_BODY_CONTACT":"LEGACY_FOUNDATION_EXCLUSION",
                RelativeToActor=Point(c.bounds.center-p),RelativeToDoor=Point(c.bounds.center-homeEntities["DOOR"].transform.position),
                ClosestSupported=closestSupported,Closest=closestSupported?Point(c.ClosestPoint(p+Vector3.up*0.9f)):null,BoundsClosest=Point(c.ClosestPointOnBounds(p+Vector3.up*0.9f)),
                FloorHits=rays.Where(x=>x.collider==c).Select(x=>new {Position=Point(x.point),Normal=Point(x.normal),FootDelta=p.y-x.point.y}).ToArray(),Penetrations=measurements};
        }
        private void HomeCrossing(Vector3 from,Vector3 to,float now,bool accept) {
            var door=(Door)homeEntities["DOOR"];Bounds aperture;Matrix4x4 matrix;
            if(!door.TryGetNavDoorwayVolume(out aperture,out matrix))throw new InvalidOperationException("Native doorway aperture unavailable");
            var obb=new OBB(door.transform,aperture);Vector3 normal=obb.extents.x<=obb.extents.z?obb.right:obb.forward;
            if(Vector3.Dot(normal,homeInside-homeOutside)<0)normal=-normal;
            float a=Vector3.Dot(from-obb.position,normal),b=Vector3.Dot(to-obb.position,normal);
            bool enter=a<0 && b>=0,leave=a>0 && b<=0;
            if(!enter && !leave)return;
            var crossing=Vector3.Lerp(from,to,Mathf.Abs(a)/(Mathf.Abs(a)+Mathf.Abs(b)));
            var local=matrix.inverse.MultiplyPoint3x4(crossing+Vector3.up*0.9f);
            if(!accept) {
                homeNav.Add(new {Event="CROSSING_CANDIDATE",Direction=enter?"IN":"OUT",Time=now,From=Point(from),To=Point(to),Position=Point(crossing),A=a,B=b,Open=door.IsOpen(),Local=Point(local),
                    ApertureContains=aperture.Contains(local),RequiredHalfWidth=Mathf.Abs(obb.extents.x<=obb.extents.z?local.z-aperture.center.z:local.x-aperture.center.x)+0.5f,
                    RequiredHalfHeight=Mathf.Abs(local.y-aperture.center.y)+0.9f,Accepted=false});return;
            }
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
            if(homeObservedPhase!=homePhase){var phase=new {Phase=homePhase,Time=now,Remaining=deadline-now};homePhases.Add(phase);Log("HOME_PHASE",phase);homeObservedPhase=homePhase;}
            if(EquipmentValid()) {
                equipmentChecks++;
                if(mode=="RESTORE") {
                    if(JsonConvert.SerializeObject(HeldItems())!=stableHeld || !OldEntitiesUnchanged())throw Balance("Restored home held ownership/foreign refs changed");
                    equipmentSamples.Add(new {Time=now,Equipment=Equipment()});
                }
            }
            if(dt<=0 || dt>1.5f || step>5 || step>6*dt+1)throw new InvalidOperationException("Discontinuous HOME_NAV trace");
            if(homePhase=="NAV"){HomeCrossing(previous,position,now,false);HomePhysicalSample(now);HomeCrossing(previous,position,now,true);}
            total+=step;previous=position;previousTime=now;Sample(now);
            if(now>deadline)throw new InvalidOperationException("Bounded FirstHome deadline");
            if(homePhase=="SITE_SEARCH"){HomeSearchBatch();return true;}
            if(homePhase=="TRAVEL" || homePhase=="BUILD_TRAVEL" || homePhase=="RESTORE_TRAVEL") {
                if(HomeArrived(now))homePhase=homePhase=="RESTORE_TRAVEL"?"NAV_WAIT":"BUILD";
                if(homePhase=="NAV_WAIT")homeWait=now+30;return true;
            }
            if(homePhase=="BUILD"){
                HomeBuildStep();
                if(homePhase=="BUILD") {
                    homePhase="BUILD_WAIT";homeWait=now+2;homeTilesDeadline=now+30;homeTilesPending=false;
                    var built=homeEntities.Values.Select(x=>x.WorldSpaceBounds().ToBounds()).ToArray();var bounds=built[0];
                    foreach(var b in built)bounds.Encapsulate(b);
                    bool before=RustNavigation.Instance.HasPendingTiles();RustNavigation.Instance.RebuildTilesInBounds(bounds,false);
                    var tiles=new {Step=homeStep,Event="REBUILD_REQUEST",Before=before,After=RustNavigation.Instance.HasPendingTiles(),Center=Point(bounds.center),Size=Point(bounds.size),Time=now};
                    homeTileStates.Add(tiles);Log("HOME_TILES",tiles);
                }return true;
            }
            if(homePhase=="BUILD_WAIT") {
                bool pending=RustNavigation.Instance.HasPendingTiles();
                if(homeTilesPending!=pending || now>=homeWait && !pending) {
                    var tiles=new {Step=homeStep,Event="READINESS",Pending=pending,Deadline=homeTilesDeadline,Time=now};homeTileStates.Add(tiles);Log("HOME_TILES",tiles);homeTilesPending=pending;
                }
                if(pending){if(now>=homeTilesDeadline)throw new InvalidOperationException("PENDING_TILES_TIMEOUT step="+homeStep);return true;}
                if(now<homeWait)return true;
                var stand=HomeBuildStand();if(Vector3.Distance(npc.transform.position,stand)<=0.3f)homePhase="BUILD";else{HomeMove(stand,"BUILD_"+homeStep);homePhase="BUILD_TRAVEL";}return true;
            }
            if(homePhase=="VERIFY"){if(now>=homeWait)HomeAuthorizeAndUpkeep();return true;}
            if(homePhase=="NAV_WAIT") {
                if(RustNavigation.Instance.HasPendingTiles()){if(now>=homeWait)throw new InvalidOperationException("Native home rebuild pending timeout");return true;}
                if(!HomeInterior(out homeInside)){if(now>=homeWait)throw new InvalidOperationException("HOME_NAV native floor/clearance/sample unavailable after rebuild");return true;}
                // Door placement may have used a proven current stand closer than the original site stand.
                homeOutside=npc.transform.position;
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
                    if(!Activate(product.uid) || !EquipmentValid())throw new InvalidOperationException("Home paid held axe lost");
                    if(homeSmoke)Finish("PARTIAL","BUILD_SMOKE_GREEN / DIAGNOSTIC_BUILD_ONLY; fixture is not natural survival or restore proof");
                    else{Save();Finish("GREEN","Native paid home/TC/upkeep and physical RustNav "+mode);}
                }
            }
            return true;
        }
        private object HomeResult() {
            return !firstHome?null:new {Schema=1,Stage=homePhase,DiagnosticOnly=homeSmoke,Fixture=homeFixture,NativePlacements=homePlacements,TcPreviews=homeTcPreviews,Approaches=homeApproaches,Tiles=homeTileStates,Phases=homePhases,Schedule=new {JourneySeconds=HomeJourneySeconds,SmokeSeconds=HomeSmokeSeconds,BuildReserve=HomeBuildReserve,GatherReserve=HomeGatherReserve},AdmissionReason=homeAdmissionReason,Placement="SERVER_ACCOUNTED_BUILD",Site=homeSiteReceipt,RejectedSites=homeSites,Budget=homeBudget,Recipes=homeRecipes,GradeCosts=homeGradeCosts,
                Operations=homeOperations,ToolSwitches=homeToolSwitches,Home=homeEntities.Count==8?DescribeHome():null,PartialEntities=homeEntities.Select(x=>HomeRow(x.Key,x.Value)).ToArray(),
                Decay=new {Enabled=ConVar.Decay.upkeep,Scale=ConVar.Decay.scale,WoodDuration=ConVar.Decay.duration_wood},
                TcAuthorization=homeTcAuthorization,Upkeep=homeUpkeep,Portal=homePortal,Navigation=homeNav,NavigationComplete=homeNavComplete,CrossedIn=homeCrossedIn,CrossedOut=homeCrossedOut,Restored=homeRestored,Rebind=homeRebind,
                Snapshot=homeSnapshot,Source=homeRestoreSource,PendingIntent=homeIntent,SaveReady=homeSnapshot!=null,
                NativeCapsule=npc==null?new object[0]:npc.GetComponents<Collider>().Select(x=>(object)new {Type=x.GetType().Name,x.enabled,x.isTrigger}).ToArray()};
        }
    }
}
