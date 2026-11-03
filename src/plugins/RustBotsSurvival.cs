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
    [Info("RustBotsSurvival", "RustOxideBots", "0.1.0")]
    [Description("Isolated natural harvesting with an explicitly accounted rock adapter.")]
    public class RustBotsSurvival : RustPlugin
    {
        // Identity, needs and real inventory survive independently of the concrete avatar.
        private sealed class SurvivorState
        {
            public string ActorId, Goal = "NEED_RESOURCE", ToolUid;
            public List<string> Completed = new List<string>(), Rejected = new List<string>();
        }
        private sealed class SurvivorActor
        {
            public BaseEntity Entity;
            public ItemContainer Inventory;
            public SurvivorState State;
        }
        private sealed class ItemRow
        {
            public string Uid, Shortname;
            public int Amount;
            public float Condition, MaxCondition;
        }
        private sealed class SavedState
        {
            public SurvivorState Actor;
            public List<ItemRow> StarterKit;
        }
        private readonly SurvivorActor actor = new SurvivorActor();
        private RustNavMeshAgent agent;
        private BaseMelee rockProfile;
        private Item rock;
        private ResourceEntity source;
        private ResourceDispenser dispenser;
        private ItemAmount pool;
        private string root, token, prefab, kind, sourceId, mode = "GATHER";
        private bool finished, active, navigating, restored, saved, probed;
        private float navWait, deadline, previousTime, total, legDistance, legTime, progressTime, nextHit;
        private int completedLegs, repaths, rejected, attempts, sourceHits;
        private Vector3 previous, goal, target, legStart, progress;
        private readonly List<ItemRow> starterKit = new List<ItemRow>();
        private readonly List<object> samples = new List<object>(), legs = new List<object>(), harvests = new List<object>(), sources = new List<object>();
        private readonly List<string> anomalies = new List<string>();
        private readonly Dictionary<string, string> parts = new Dictionary<string, string> {
            {"WOOD","BLOCKED"},{"ORE","BLOCKED"},{"TOOLS","BLOCKED"},{"NAVIGATION","BLOCKED"}
        };
        private List<ItemRow> expected = new List<ItemRow>();
        private SurvivorState expectedState;
        private static float[] Point(Vector3 p) { return new[] { p.x, p.y, p.z }; }
        private static ItemRow Row(Item i) { return new ItemRow { Uid=i.uid.Value.ToString(), Shortname=i.info.shortname, Amount=i.amount, Condition=i.condition, MaxCondition=i.maxCondition }; }
        private List<ItemRow> Contents() { return actor.Inventory == null ? new List<ItemRow>() : actor.Inventory.itemList.Select(Row).ToList(); }
        private static string Key(IEnumerable<ItemRow> items) { return JsonConvert.SerializeObject(items.OrderBy(i=>i.Uid,StringComparer.Ordinal)); }
        private string Data(string suffix) { return Path.Combine(root, "oxide", "data", "RustBotsSurvival."+suffix); }
        private void Log(string name, object value) { Puts("RUSTBOTS_SURVIVAL_"+name+" "+JsonConvert.SerializeObject(value)); }

        private bool IsTestRoot()
        {
            root=Environment.GetEnvironmentVariable("RUST_BOTS_TEST_ROOT");
            token=Environment.GetEnvironmentVariable("RUST_BOTS_RUN_TOKEN");
            Guid id;
            if (string.IsNullOrEmpty(root) || !Guid.TryParseExact(token,"N",out id)) return false;
            string cwd=Path.GetFullPath(Directory.GetCurrentDirectory()).TrimEnd('\\','/');
            string identity=Environment.GetEnvironmentVariable("RUST_BOTS_TEST_IDENTITY");
            string marker=Path.Combine(root,"rustbots-test.marker");
            return string.Equals(cwd,Path.GetFullPath(root).TrimEnd('\\','/'),StringComparison.OrdinalIgnoreCase) &&
                identity != null && identity.StartsWith("rustbots_probe_",StringComparison.Ordinal) && ConVar.Server.identity == identity &&
                File.Exists(marker) && File.ReadAllText(marker) == token && Environment.GetEnvironmentVariable("RUST_BOTS_SCENARIO") == "SURVIVAL_GATHER";
        }
        private void OnServerInitialized()
        {
            if (!IsTestRoot()) { Puts("Survival inert: isolated runner marker/identity missing."); return; }
            mode=Environment.GetEnvironmentVariable("RUST_BOTS_RESTORE") == "1" ? "RESTORE" : "GATHER";
            navWait=Time.realtimeSinceStartup;
            Puts("RUSTBOTS_READY RustNavMeshAgent/RustNav SURVIVAL_GATHER");
            timer.Every(0.5f,()=> {
                try {
                    string stop=Path.Combine(root,"rustbots-stop.request");
                    if (File.Exists(stop) && File.ReadAllText(stop) == token) {
                        Cleanup(); Puts("RUSTBOTS_SHUTDOWN_ACK"); ConsoleSystem.Run(ConsoleSystem.Option.Server,"quit"); return;
                    }
                    if (finished) return;
                    if (!active) {
                        if (ConVar.AI.useUnityNavmesh) { Finish("BLOCKED","RustNav required"); return; }
                        if (RustNavigation.Instance == null || !RustNavigation.Instance.IsDefaultNavmeshBuilt()) {
                            if (Time.realtimeSinceStartup-navWait > 600) Finish("BLOCKED","RustNav readiness timeout");
                            return;
                        }
                        Begin(); return;
                    }
                    Tick();
                } catch(Exception ex) { PrintError(ex.ToString()); Finish("BLOCKED","Survival exception: "+ex.Message); }
            });
        }
        private void Begin()
        {
            if (mode == "RESTORE") {
                var state=JsonConvert.DeserializeObject<SavedState>(File.ReadAllText(Data("state.json")));
                actor.State=state.Actor; starterKit.AddRange(state.StarterKit);
                actor.Inventory=new ItemContainer(); actor.Inventory.ServerInitialize(null,48);
                using(var snapshot=ProtoBuf.ItemContainer.Deserialize(File.ReadAllBytes(Data("inventory.bin")))) actor.Inventory.Load(snapshot);
                expected=JsonConvert.DeserializeObject<List<ItemRow>>(File.ReadAllText(Data("expected.json")));
                expectedState=JsonConvert.DeserializeObject<SurvivorState>(File.ReadAllText(Data("expected-state.json")));
                restored=Key(expected)==Key(Contents()) && JsonConvert.SerializeObject(expectedState)==JsonConvert.SerializeObject(actor.State);
                if (!restored) { Finish("PARTIAL","Native inventory or actor state mismatch"); return; }
            } else {
                actor.State=new SurvivorState { ActorId="survivor-004-"+Guid.NewGuid().ToString("N") };
                actor.Inventory=new ItemContainer(); actor.Inventory.ServerInitialize(null,48); actor.Inventory.GiveUID();
            }
            foreach(string path in GameManifest.Current.entities.Where(p=>p.EndsWith(".prefab",StringComparison.OrdinalIgnoreCase) && p.IndexOf("scientist",StringComparison.OrdinalIgnoreCase)>=0)
                .OrderBy(p=>p.IndexOf("heavy",StringComparison.OrdinalIgnoreCase)>=0).ThenBy(p=>p)) {
                var obj=GameManager.server.FindPrefab(path);
                if(obj != null && obj.GetComponent<ScientistNPC2>() != null && obj.GetComponent<RustNavMeshAgent>() != null) { prefab=path; break; }
            }
            if(prefab == null) { Finish("BLOCKED","No installed Gen2 scientist prefab"); return; }
            var settings=GameManager.server.FindPrefab(prefab).GetComponent<RustNavMeshAgent>();
            Vector3 spawn;
            if(!FindSpawn(settings,out spawn)) { Finish("BLOCKED","No safe grounded departure spawn"); return; }
            actor.Entity=GameManager.server.CreateEntity(prefab,spawn,Quaternion.identity,true);
            if(actor.Entity == null) { Finish("BLOCKED","CreateEntity returned null"); return; }
            actor.Entity.enableSaving=false; actor.Entity.Spawn();
            var fsm=actor.Entity.GetComponent<FSMComponent>(); if(fsm != null) fsm.SetFsmActive(false);
            var brain=actor.Entity.GetComponent<BaseAIBrain>(); if(brain != null) brain.SetThinkMode(AIThinkMode.None);
            agent=actor.Entity.GetComponent<RustNavMeshAgent>();
            if(agent == null || !agent.IsNavMeshBuilt || !agent.isOnNavMesh) { Finish("BLOCKED","Gen2 agent not bound"); return; }
            actor.Inventory.entityOwner=actor.Entity;
            agent.updatePosition=true; agent.isStopped=false; agent.SetGait(RustNavMeshAgent.Speeds.Jog);agent.speed=3f;agent.stoppingDistance=0.15f;
            if(mode != "RESTORE") {
                // Explicit subset of native GiveDefaultItems: one real starter rock, never yield.
                rock=ItemManager.CreateByName("rock",1);
                if(rock == null || !rock.MoveToContainer(actor.Inventory,-1,false)) { if(rock != null)rock.Remove(); Finish("BLOCKED","Starter rock unavailable"); return; }
                actor.State.ToolUid=rock.uid.Value.ToString();starterKit.Add(Row(rock));
            } else rock=actor.Inventory.itemList.SingleOrDefault(i=>i.uid.Value.ToString()==actor.State.ToolUid && i.info.shortname=="rock");
            var mod=rock == null ? null : rock.info.GetComponent<ItemModEntity>();
            var heldPrefab=mod == null ? null : GameManager.server.FindPrefab(mod.entityPrefab.resourcePath);
            rockProfile=heldPrefab == null ? null : heldPrefab.GetComponent<BaseMelee>();
            if(rockProfile == null) { Finish("BLOCKED","Installed rock BaseMelee profile unavailable"); return; }
            Log("ACTOR",new { ActorId=actor.State.ActorId, Type=actor.Entity.GetType().FullName, Prefab=prefab, Position=Point(spawn), IsBasePlayer=actor.Entity is BasePlayer,
                PlayerInventoryComponent=actor.Entity.GetComponent<PlayerInventory>() != null, Fsm=fsm==null?null:fsm.GetType().FullName, FsmControl="SetFsmActive(false)", NativeEquipment="NOT_NATIVE_EQUIPPED", ToolMode="SERVER_ACCOUNTED_TOOL", Tool=Row(rock), ToolPrefab=mod.entityPrefab.resourcePath, MaxDistance=rockProfile.maxDistance });
            if(mode == "RESTORE") { Log("RESTORE",new { Expected=expected,Actual=Contents(),State=actor.State,Restored=restored }); Finish(restored?"GREEN":"PARTIAL","Independent native inventory and survivor identity/goal/tool restore");return; }
            previous=actor.Entity.transform.position;previousTime=Time.realtimeSinceStartup;
            samples.Add(new { Time=previousTime,Position=Point(previous),Stage="NEED_RESOURCE" });
            deadline=previousTime+600f;active=true;
            DiscoverNeed();
        }

        private bool Ground(Vector3 nav,out Vector3 foot,bool clearance)
        {
            foot=nav;RaycastHit hit;
            if(!Physics.Raycast(nav+Vector3.up*4f,Vector3.down,out hit,8f,Physics.DefaultRaycastLayers,QueryTriggerInteraction.Ignore))return false;
            if(Mathf.Abs(hit.point.y-nav.y)>1f || Mathf.Abs(hit.point.y-TerrainMeta.HeightMap.GetHeight(hit.point))>0.8f || hit.normal.y<0.85f)return false;
            foot=hit.point+Vector3.up*0.05f;
            if(WaterLevel.GetWaterSurface(foot,true,true,null)-foot.y>0.15f)return false;
            if(clearance && Physics.OverlapCapsule(foot+Vector3.up*0.57f,foot+Vector3.up*1.55f,0.45f,Physics.DefaultRaycastLayers,QueryTriggerInteraction.Ignore).Length!=0)return false;
            return true;
        }
        private bool Sample(RustNavMeshAgent settings,Vector3 candidate,out Vector3 foot)
        {
            NavHit hit;foot=Vector3.zero;
            return RustNavigation.Instance.DefaultNavmesh.SamplePosition(new NavVector3(candidate),out hit,new Vector3(2.5f,3f,2.5f),false) && Ground(hit.position.Value,out foot,true);
        }
        private static float Halton(int index,int radix)
        {
            float f=1,v=0;while(index>0){f/=radix;v+=f*(index%radix);index/=radix;}return v;
        }
        private bool FindSpawn(RustNavMeshAgent settings,out Vector3 chosen)
        {
            for(int i=1;i<=1024;i++) {
                var p=new Vector3((Halton(i,2)-0.5f)*TerrainMeta.Size.x*0.9f,0,(Halton(i,3)-0.5f)*TerrainMeta.Size.z*0.9f);p.y=TerrainMeta.HeightMap.GetHeight(p);
                Vector3 foot;if(!Sample(settings,p,out foot))continue;
                for(int j=0;j<12;j++) {
                    float a=j*Mathf.PI/6;var q=foot+new Vector3(Mathf.Cos(a),0,Mathf.Sin(a))*36f;q.y=TerrainMeta.HeightMap.GetHeight(q);
                    Vector3 end;if(!Sample(settings,q,out end))continue;
                    var path=new RustNavMeshPath();
                    if(RustNavigation.Instance.DefaultNavmesh.CalculatePath(new NavVector3(foot),new NavVector3(end),path,false) && path.status==NavMeshPathStatus.PathComplete){chosen=foot;Log("SPAWN",new{Position=Point(foot),Grounded=true,Departure="PathComplete"});return true;}
                }
            }
            chosen=Vector3.zero;return false;
        }
        private bool Eligible(ResourceEntity e,string need,out ResourceDispenser d,out ItemAmount item)
        {
            d=null;item=null;
            if(e == null || e.IsDestroyed || e.OwnerID!=0 || e.IsLocked() || (need=="WOOD" ? !(e is TreeEntity) : !(e is OreResourceEntity)))return false;
            d=e.GetComponent<ResourceDispenser>();if(d == null || d.containedItems==null)return false;
            if(d.containedItems.Any(i=>float.IsNaN(i.amount)||float.IsInfinity(i.amount)||i.amount<0)||float.IsNaN(d.fractionRemaining)||d.fractionRemaining<=0)return false;
            var positive=d.containedItems.Where(i=>i.amount>0).ToArray();
            if(positive.Length!=1)return false;item=positive[0];
            return item.itemDef!=null && item.startAmount>0 && !float.IsNaN(item.startAmount) && !float.IsInfinity(item.startAmount) && item.amount>=3 &&
                (need=="WOOD" ? item.itemDef.shortname=="wood" : item.itemDef.shortname=="stones");
        }
        private bool Reach(ResourceEntity entity,out float distance)
        {
            distance=entity == null ? float.MaxValue : Vector3.Distance(actor.Entity.transform.position,entity.transform.position);
            float reach=Mathf.Min(2.8f,rockProfile.maxDistance+0.5f);
            if(entity == null || entity.IsDestroyed || entity.OwnerID!=0 || entity.IsLocked() || distance>reach)return false;
            var eye=actor.Entity.transform.position+Vector3.up*1.2f;var end=entity.transform.position+Vector3.up*0.6f;var delta=end-eye;
            foreach(var h in Physics.RaycastAll(eye,delta.normalized,delta.magnitude,Physics.DefaultRaycastLayers,QueryTriggerInteraction.Ignore)) {
                var owner=h.collider.GetComponentInParent<BaseEntity>();if(owner!=actor.Entity && owner!=entity)return false;
            }
            return Mathf.Abs(actor.Entity.transform.position.y-TerrainMeta.HeightMap.GetHeight(actor.Entity.transform.position))<1f &&
                WaterLevel.GetWaterSurface(actor.Entity.transform.position,true,true,null)-actor.Entity.transform.position.y<=0.15f;
        }
        private bool Approach(ResourceEntity entity,out Vector3 position)
        {
            position=Vector3.zero;
            for(int i=0;i<24;i++) {
                float a=i*Mathf.PI/4f;float radius=i<8?1.4f:i<16?1.8f:2.2f;
                var p=entity.transform.position+new Vector3(Mathf.Cos(a),0,Mathf.Sin(a))*radius;p.y=TerrainMeta.HeightMap.GetHeight(p);
                NavMeshHit hit;Vector3 foot;
                if(!agent.SamplePosition(p,out hit,0.7f,false)||!Ground(hit.position,out foot,true)||Vector3.Distance(foot,entity.transform.position)>Mathf.Min(2.3f,rockProfile.maxDistance+0.25f))continue;
                var path=new RustNavMeshPath();
                if(!agent.CalculatePath(foot,path)||path.status!=NavMeshPathStatus.PathComplete||path.GetPathLength()>500f)continue;
                position=foot;return true;
            }
            return false;
        }
        private void DiscoverNeed()
        {
            kind=actor.Inventory.itemList.Where(i=>i.info.shortname=="wood").Sum(i=>i.amount)<20?"WOOD":actor.Inventory.itemList.Where(i=>i.info.shortname=="stones").Sum(i=>i.amount)<20?"ORE":null;
            if(kind==null){Complete();return;}
            actor.State.Goal="DISCOVER_"+kind;
            if(attempts++>=6){Complete();return;}
            source=null;
            // One bounded discovery per need/recovery, never a scan on every movement tick.
            var candidates=BaseNetworkable.serverEntities.OfType<ResourceEntity>().Where(e=> !e.IsDestroyed &&
                (kind=="WOOD" ? e is TreeEntity : e is OreResourceEntity) && Vector3.Distance(e.transform.position,actor.Entity.transform.position)<=400f)
                .OrderBy(e=>Vector3.Distance(e.transform.position,actor.Entity.transform.position)).Take(64).ToArray();
            foreach(var e in candidates) {
                string id=e.net.ID.ToString();ResourceDispenser d;ItemAmount item;Vector3 approach;
                if(actor.State.Rejected.Contains(id)||!Eligible(e,kind,out d,out item))continue;
                if(!Approach(e,out approach)){actor.State.Rejected.Add(id);rejected++;continue;}
                source=e;dispenser=d;pool=item;sourceId=id;goal=approach;probed=false;sourceHits=0;break;
            }
            if(source==null){parts[kind]="BLOCKED";Log("DISCOVERY_BLOCKED",new{Kind=kind,Candidates=candidates.Length,Rejected=rejected});Complete();return;}
            Log("DISCOVER",new{Kind=kind,Provenance="NATURAL",SourceId=sourceId,Type=source.GetType().FullName,Prefab=source.PrefabName,Position=Point(source.transform.position),Approach=Point(goal),Pool=pool.amount,Resource=pool.itemDef.shortname});
            actor.State.Goal="NAVIGATE_"+kind;StartLeg();
        }
        private void StartLeg()
        {
            if(completedLegs>=40){Complete();return;}
            var full=new RustNavMeshPath();if(!agent.CalculatePath(goal,full)||full.status!=NavMeshPathStatus.PathComplete){RejectSource("Goal path incomplete");return;}
            Vector3 cursor=actor.Entity.transform.position,candidate=goal;float remaining=30f;
            foreach(var corner in full.corners){float d=Vector3.Distance(cursor,corner.Value);if(d>remaining){candidate=Vector3.Lerp(cursor,corner.Value,remaining/d);break;}remaining-=d;cursor=corner.Value;}
            NavMeshHit hit;Vector3 foot;var local=new RustNavMeshPath();
            if(!agent.SamplePosition(candidate,out hit,1f,false)||!Ground(hit.position,out foot,true)||!agent.CalculatePath(foot,local)||local.status!=NavMeshPathStatus.PathComplete){RejectSource("Local approach path/ground unavailable");return;}
            target=foot;legStart=progress=actor.Entity.transform.position;legTime=progressTime=Time.realtimeSinceStartup;legDistance=0;repaths=0;navigating=true;
            agent.isStopped=false;if(!agent.SetDestination(target)){RejectSource("Agent destination rejected");return;}
            Log("LEG",new{Start=Point(legStart),Target=Point(target),PathStatus=local.status.ToString(),Length=local.GetPathLength(),Kind=kind});
        }
        private void Tick()
        {
            if(actor.Entity==null||actor.Entity.IsDestroyed){Finish("BLOCKED","Actor lost");return;}
            float now=Time.realtimeSinceStartup,dt=now-previousTime;Vector3 pos=actor.Entity.transform.position;float step=Vector3.Distance(previous,pos);
            if(dt<=0)return;
            if(dt>1.5f||step>5f||step>6f*dt+1f){Finish("BLOCKED","Discontinuous position evidence");return;}
            total+=step;if(navigating)legDistance+=step;previous=pos;previousTime=now;
            samples.Add(new{Time=now,Position=Point(pos),Stage=actor.State.Goal,Destination=Point(agent.destinationWS),Stopped=agent.isStopped,HasPath=agent.hasPath,Remaining=agent.remainingDistance,PathStatus=agent.pathStatus.ToString()});
            if(now>deadline){Complete();return;}
            if(!navigating){if(now>=nextHit)Harvest();return;}
            if(Vector3.Distance(pos,target)<=0.55f){
                legs.Add(new{Status="ARRIVED",PathStatus="PathComplete",Start=Point(legStart),End=Point(pos),Target=Point(target),Traveled=legDistance,Net=Vector3.Distance(legStart,pos),Repaths=repaths,Kind=kind});
                completedLegs++;navigating=false;
                if(Vector3.Distance(pos,goal)>0.6f){StartLeg();return;}
                agent.isStopped=true;actor.State.Goal="HARVEST_"+kind;nextHit=now+0.5f;return;
            }
            if(Vector3.Distance(pos,progress)>=1){progress=pos;progressTime=now;}
            if(now-progressTime>10){if(repaths++>=1){RejectSource("Stuck after bounded repath");return;}agent.SetDestination(target);progressTime=now;}
            if(now-legTime>60)RejectSource("Segment timeout");
        }
        private void RejectSource(string reason)
        {
            Log("REJECT",new{SourceId=sourceId,Reason=reason});
            if(sourceId!=null&&!actor.State.Rejected.Contains(sourceId))actor.State.Rejected.Add(sourceId);
            // A failed journey remains PARTIAL; never erase a failed leg to manufacture GREEN.
            if(navigating){Finish("PARTIAL",reason);return;}
            agent.isStopped=true;DiscoverNeed();
        }
        private HitInfo DamageHit(bool nativeProbe)
        {
            var hit=new HitInfo(actor.Entity,source,Rust.DamageType.Blunt,0f,source.transform.position);
            rockProfile.GetAttackStats(hit);
            float damage=hit.damageTypes.Total();float cap=Mathf.Min(10f,Mathf.Max(0,source.Health()-2f));
            if(damage>cap && damage>0)hit.damageTypes.ScaleAll(cap/damage);
            hit.DidHit=true;hit.CanGather=nativeProbe;hit.DidGather=false;hit.gatherScale=nativeProbe?1f:0f;hit.Weapon=null;hit.WeaponPrefab=null;
            hit.PointStart=actor.Entity.transform.position;hit.PointEnd=source.transform.position;
            return hit;
        }
        private void Harvest()
        {
            float distance;ResourceDispenser current;ItemAmount currentPool;
            if(!Eligible(source,kind,out current,out currentPool)||current!=dispenser||currentPool!=pool||!Reach(source,out distance)){RejectSource("Source/range/LOS/ground unavailable");return;}
            if(rock==null||rock.parent!=actor.Inventory||rock.uid.Value.ToString()!=actor.State.ToolUid||(rock.hasCondition&&rock.condition<=0)){Finish("BLOCKED","Real starter tool missing/broken");return;}
            if(!probed){
                float p=pool.amount,h=source.Health();int inv=actor.Inventory.itemList.Sum(i=>i.amount);
                var before=new HashSet<DroppedItem>(BaseNetworkable.serverEntities.OfType<DroppedItem>());
                var hit=DamageHit(true);source.OnAttacked(hit);
                int drops=BaseNetworkable.serverEntities.OfType<DroppedItem>().Count(d=>!before.Contains(d)&&Vector3.Distance(d.transform.position,source.transform.position)<5f);
                var probe=new{PoolBefore=p,PoolAfter=pool.amount,HealthBefore=h,HealthAfter=source.Health(),NewDrops=drops,InitiatorPlayer=hit.InitiatorPlayer!=null,InventoryDelta=actor.Inventory.itemList.Sum(i=>i.amount)-inv,CanGather=true};
                sources.Add(new{Id=sourceId,Kind=kind,Provenance="NATURAL",Type=source.GetType().FullName,Prefab=source.PrefabName,Position=Point(source.transform.position),NativeProbe=probe});Log("NATIVE_PROBE",probe);
                if(Mathf.Abs(pool.amount-p)>0.001f||drops!=0||probe.InventoryDelta!=0){Finish("BLOCKED","Unexpected native gather output; adapter disabled to prevent double award");return;}
                probed=true;
            }
            var gather=rockProfile.GetGatherInfoFromIndex(dispenser.gatherType);
            float quantity=gather.gatherDamage,cost=gather.conditionLost;
            if(float.IsNaN(quantity)||float.IsInfinity(quantity)||quantity<=0||float.IsNaN(cost)||float.IsInfinity(cost)||cost<0){Finish("BLOCKED","Invalid installed rock gathering profile");return;}
            int amount=(int)Mathf.Min(10f,Mathf.Floor(quantity),Mathf.Floor(pool.amount)-1);
            if(amount<=0||sourceHits>=10){RejectSource("Source exhausted/bounded strikes");return;}
            float beforePool=pool.amount,beforeFraction=dispenser.fractionRemaining,beforeHealth=source.Health(),beforeCondition=rock.condition;
            if(rock.hasCondition && (cost<=0 || beforeCondition<=cost)){Finish("PARTIAL","Tool cannot pay verified wear");return;}
            // No native gather runs inside this adapter hit; only bounded health damage.
            var damageHit=DamageHit(false);source.OnAttacked(damageHit);
            if(source.IsDestroyed||source.Health()<=0||Mathf.Abs(pool.amount-beforePool)>0.001f){Finish("BLOCKED","Unexpected damage/debit side effect");return;}
            if(rock.hasCondition)rock.LoseCondition(cost);
            if(rock.hasCondition && (rock.condition>=beforeCondition||rock.condition<=0)){Finish("BLOCKED","Native tool wear did not apply");return;}
            // Sole award path. DestroyFraction is a native AMOUNT debit, verified by IL.
            // Debit first; output failure keeps the debit and ends the run, never retries credit.
            dispenser.DestroyFraction(amount);
            if(Mathf.Abs(beforePool-pool.amount-amount)>0.001f||dispenser.fractionRemaining>=beforeFraction){anomalies.Add("Native source debit mismatch");Finish("FAILED","Source debit mismatch");return;}
            Item output=ItemManager.Create(pool.itemDef,amount,0UL);
            if(output==null||!output.MoveToContainer(actor.Inventory,-1,false)){if(output!=null)output.Remove();Finish("PARTIAL","Source debited but output transfer failed; no recredit");return;}
            var receipt=new{Transaction=token+"-"+(harvests.Count+1),Time=previousTime,Kind=kind,Provenance="NATURAL",SourceId=sourceId,Resource=pool.itemDef.shortname,
                PoolBefore=beforePool,PoolAfter=pool.amount,FractionBefore=beforeFraction,FractionAfter=dispenser.fractionRemaining,HealthBefore=beforeHealth,HealthAfter=source.Health(),Damage=damageHit.damageTypes.Total(),
                Amount=amount,Uid=output.uid.Value.ToString(),ToolUid=actor.State.ToolUid,ToolConditionBefore=beforeCondition,ToolConditionAfter=rock.condition,ToolHasCondition=rock.hasCondition,ToolCost=cost,
                GatherDamage=quantity,DestroyFraction=gather.destroyFraction,MaxDistance=rockProfile.maxDistance,Mechanism="SERVER_ACCOUNTED_TOOL/ResourceDispenser.DestroyFraction(amount)",CanGather=false,
                Distance=distance,LineOfSight=true,Grounded=true,PathStatus="PathComplete",Actor=Point(actor.Entity.transform.position),SourcePosition=Point(source.transform.position)};
            harvests.Add(receipt);Log("DEBIT_YIELD",receipt);sourceHits++;parts["TOOLS"]="GREEN";nextHit=Time.realtimeSinceStartup+1f;
            if(actor.Inventory.itemList.Where(i=>i.info.shortname==pool.itemDef.shortname).Sum(i=>i.amount)>=20){
                parts[kind]="GREEN";actor.State.Completed.Add(kind);actor.State.Rejected.Add(sourceId);DiscoverNeed();
            }
        }
        private void Complete()
        {
            if(finished)return;
            actor.State.Goal="CARRY_SAVE";
            parts["NAVIGATION"]=total>=3f&&completedLegs>0&&!navigating?"GREEN":"PARTIAL";
            if(actor.Inventory!=null&&Contents().Count>0&&anomalies.Count==0){
                using(var snapshot=actor.Inventory.Save())File.WriteAllBytes(Data("inventory.bin"),snapshot.ToProtoBytes());
                File.WriteAllText(Data("state.json"),JsonConvert.SerializeObject(new SavedState{Actor=actor.State,StarterKit=starterKit},Formatting.Indented));saved=true;
            }
            Finish(parts.Values.All(v=>v=="GREEN")?"GREEN":"PARTIAL","Bounded natural gather complete; independent restart required for persistence");
        }
        private void Finish(string status,string reason)
        {
            if(finished)return;finished=true;active=false;
            if(actor.Entity!=null&&navigating)legs.Add(new{Status="FAILED",PathStatus=agent.pathStatus.ToString(),Start=Point(legStart),End=Point(actor.Entity.transform.position),Target=Point(target),Traveled=legDistance,Net=Vector3.Distance(legStart,actor.Entity.transform.position)});
            var result=new{RunId=token,Status=status,Reason=reason,Mode=mode,ActorType=actor.Entity==null?null:actor.Entity.GetType().FullName,Prefab=prefab,Backend="RustNavMeshAgent/RustNav",
                ToolMode="SERVER_ACCOUNTED_TOOL",NativeEquipment="NOT_NATIVE_EQUIPPED",ActorState=actor.State,StarterKit=starterKit,Inventory=Contents(),Parts=parts,
                Samples=samples,Legs=legs,TotalTraveled=total,Harvests=harvests,Sources=sources,Rejected=rejected,
                Conservation=new{Ok=anomalies.Count==0,Anomalies=anomalies},Persistence=new{Saved=saved,Restored=restored,Expected=expected,ExpectedState=expectedState}};
            if(root!=null){string path=Data("result.json");File.WriteAllText(path+".tmp",JsonConvert.SerializeObject(result,Formatting.Indented));File.Move(path+".tmp",path);}
            Log("RESULT",result);Cleanup();
        }
        private void Cleanup()
        {
            if(actor.Entity!=null&&!actor.Entity.IsDestroyed)actor.Entity.Kill();actor.Entity=null;
            if(actor.Inventory!=null){actor.Inventory.Kill();actor.Inventory=null;}
        }
        private void Unload(){Cleanup();}
    }
}
