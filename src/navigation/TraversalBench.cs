// Shared caller integration and isolated diagnostic scenes; no construction/economy implementation here.
namespace RustBots.Navigation
{
    using System;
    using UnityEngine;
    public sealed class TraversalDriver : MonoBehaviour
    {
        public Action<ObstacleTraversal.TraversalClock> Step;
        private long sequence;
        private void FixedUpdate() {
            if(Step==null)return;
            Step(new ObstacleTraversal.TraversalClock {
                WallTime=Time.realtimeSinceStartupAsDouble,FixedTime=Time.fixedTimeAsDouble,
                FixedUnscaledTime=Time.fixedUnscaledTimeAsDouble,Delta=Time.fixedDeltaTime,
                UnscaledDelta=Time.fixedUnscaledDeltaTime,TimeScale=Time.timeScale,MaximumDelta=Time.maximumDeltaTime,
                InFixedStep=Time.inFixedTimeStep,PhysicsMode=Physics.simulationMode.ToString(),Sequence=++sequence,Frame=Time.frameCount
            });
        }
    }
}
namespace Oxide.Plugins
{
    using System;
    using System.Collections.Generic;
    using System.Linq;
    using Rust.Ai.Gen2;
    using Rust.Ai.Gen2.Nav;
    using UnityEngine;
    using UnityEngine.AI;

    public partial class RustBotsAvatarSurvival
    {
        private RustBots.Navigation.ObstacleTraversal localMotion;
        private RustBots.Navigation.TraversalDriver motionDriver;
        private bool traversalBench,traversalComplete,traversalOutdoor,traversalHome;
        private string traversalPhase,traversalSceneKind,traversalSceneStage;
        private Vector3 traversalOrigin,traversalSceneStart;
        private float traversalSceneTime;
        private float traversalOutdoorWait;
        private int traversalSceneFrom;
        private double traversalWarmupStart,traversalStableSince,traversalMaxGap;
        private int traversalWarmupSamples,traversalDoorCollider;
        private Vector3 traversalWarmupPose;
        private RustBots.Navigation.ObstacleTraversal.TraversalClock? traversalWarmupClock;
        private object traversalWarmupReceipt;
        private readonly List<object> traversalScenes=new List<object>();
        private readonly List<object> traversalComponents=new List<object>();
        private readonly List<object> traversalSpawnSupport=new List<object>();
        private Door traversalOutdoorDoor;
        private Vector3 traversalDetourGoal;
        private Vector3 traversalDoorPlanePoint,traversalDoorPlaneNormal,traversalDoorBoundsCenter,traversalDoorBoundsSize;

        private void TraversalSpawnSupport(string phase,Vector3 position,CapsuleCollider c,bool actual) {
            if(c==null)throw new InvalidOperationException("Original spawn capsule missing");
            var lower=actual?c.transform.TransformPoint(c.center-Vector3.up*(c.height*0.5f-c.radius)):
                position+c.center-Vector3.up*(c.height*0.5f-c.radius);
            var origin=lower+Vector3.up*0.57f;
            var hits=Physics.SphereCastAll(origin,c.radius,Vector3.down,1.14f,-1,QueryTriggerInteraction.Ignore)
                .Where(h=>npc==null || h.collider.GetComponentInParent<BaseEntity>()!=npc).OrderBy(h=>h.distance).ToArray();
            var rayOrigin=position+Vector3.up*4f;
            var rays=Physics.RaycastAll(rayOrigin,Vector3.down,8f,Physics.DefaultRaycastLayers,QueryTriggerInteraction.Ignore)
                .Where(h=>npc==null || h.collider.GetComponentInParent<BaseEntity>()!=npc).OrderBy(h=>h.distance).ToArray();
            var row=new {Phase=phase,Time=Time.realtimeSinceStartupAsDouble,ActualBody=actual,Position=Point(position),
                Radius=c.radius,Height=c.height,Center=Point(c.center),Lower=Point(lower),SphereOrigin=Point(origin),
                RayOrigin=Point(rayOrigin),RayHits=rays.Select(h=>new {Collider=h.collider.GetInstanceID(),Type=h.collider.GetType().Name,Point=Point(h.point),Normal=Point(h.normal),Distance=h.distance}).ToArray(),
                SphereHits=hits.Select(h=>new {Collider=h.collider.GetInstanceID(),Type=h.collider.GetType().Name,Point=Point(h.point),Normal=Point(h.normal),Distance=h.distance,
                    FullSphereGap=lower.y-(origin.y-h.distance)}).ToArray()};
            traversalSpawnSupport.Add(row);Log("TRAVERSAL_SPAWN_SUPPORT",row);
        }

        private void EnsureTraversal() {
            if(localMotion!=null)return;
            if(!traversalBench)throw new InvalidOperationException("Candidate traversal requires its explicit isolated bench until physical promotion");
            var scientist=npc as ScientistNPC;
            if(scientist==null)throw new InvalidOperationException("Traversal requires the original ScientistNPC");
            TraversalSpawnSupport("BEFORE_CONTROLLER_BIND",npc.transform.position,npc.GetComponent<CapsuleCollider>(),true);
            var navigator=npc.GetComponent<NPCPlayerNavigator>();
            if(navigator!=null)navigator.enabled=false;
            var world=currentWorld??ReadCurrentWorld();
            localMotion=new RustBots.Navigation.ObstacleTraversal(scientist,agent,world.WorldKey(),TraversalWitness);
            foreach(var component in npc.GetComponentsInChildren<Component>(true)) {
                if(component==null)continue;
                var c=component as Collider;
                var behaviour=component as Behaviour;
                traversalComponents.Add(new {Type=component.GetType().FullName,Instance=component.GetInstanceID(),Enabled=behaviour==null?(bool?)null:behaviour.enabled,
                    Collider=c==null?null:(object)new {c.enabled,c.isTrigger,Scale=Point(c.transform.lossyScale)}});
            }
            motionDriver=npc.gameObject.AddComponent<RustBots.Navigation.TraversalDriver>();
            motionDriver.Step=clock=> {
                if(finished || npc==null || npc.IsDestroyed)return;
                try{if(traversalPhase=="WARMUP")TraversalWarmup(clock);else localMotion.Tick(clock);}
                catch(Exception ex){localMotion.Stop("SENSOR_EXCEPTION");PrintError(ex.ToString());Finish("PARTIAL","Traversal sensor/actuator exception");}
            };
        }
        private void TraversalWitness(object row) {
            var frame=row as Dictionary<string,object>;
            if(frame!=null && (string)frame["Event"]=="MOTION_WITNESS" && traversalPhase=="OUTDOOR_DETOUR") {
                var door=traversalOutdoorDoor;
                frame["DetourDoorWitness"]=door==null?null:new {Door=Id(door),Open=door.IsOpen(),Position=Point(door.transform.position),
                    Collider=traversalDoorCollider,PlanePoint=Point(traversalDoorPlanePoint),PlaneNormal=Point(traversalDoorPlaneNormal),
                    BoundsCenter=Point(traversalDoorBoundsCenter),BoundsSize=Point(traversalDoorBoundsSize)};
            }
            if(frame!=null && (string)frame["Event"]=="MOTION_WITNESS" && (string)frame["NativeResult"]=="OBSERVED" &&
                traversalPhase=="HOME" && traversalSceneKind=="NATIVE_BUILDING_STEP" && homePhase=="NAV" && homePortal!=null) {
                var door=(Door)homeEntities["DOOR"];
                float now=(float)frame["Time"];
                frame["DoorWitness"]=new {Actor=Id(npc),Door=Id(door),Time=now,Open=door.IsOpen(),Position=Point(door.transform.position),Colliders=DoorColliders()};
                var from=(float[])frame["From"];var actual=(float[])frame["Actual"];
                var a=new Vector3(from[0],from[1],from[2]);var b=new Vector3(actual[0],actual[1],actual[2]);
                HomeCrossing(a,b,now,false);HomeCrossing(a,b,now,true);
            }
            Log("TRAVERSAL",row);
        }
        private bool CalculateRoute(Vector3 destination,RustNavMeshPath path) {
            return localMotion==null?agent.CalculatePath(destination,path):agent.CalculatePath(new NavVector3(npc.transform.position),new NavVector3(destination),path);
        }
        private bool IssueTraversal(Vector3 destination,string stage) {
            EnsureTraversal();return localMotion.SetDestination(destination,stage);
        }
        private void TraversalBegin() {
            traversalPhase="WARMUP";traversalWarmupStart=Time.realtimeSinceStartupAsDouble;
            traversalWarmupPose=npc.transform.position;
        }
        private void TraversalWarmup(RustBots.Navigation.ObstacleTraversal.TraversalClock clock) {
            if(double.IsNaN(clock.WallTime) || double.IsInfinity(clock.WallTime) || double.IsNaN(clock.FixedTime) || double.IsInfinity(clock.FixedTime) ||
                double.IsNaN(clock.FixedUnscaledTime) || double.IsInfinity(clock.FixedUnscaledTime) || !HomeFinite(clock.Delta) ||
                clock.WallTime<traversalWarmupStart || clock.FixedTime<0 || clock.FixedUnscaledTime<0 || clock.Sequence<=0 || clock.Frame<0 ||
                clock.WallTime-traversalWarmupStart>20 || Vector3.Distance(npc.transform.position,traversalWarmupPose)>0.001f ||
                npc.GetComponent<Rigidbody>().linearVelocity.sqrMagnitude!=0 || !clock.InFixedStep || clock.PhysicsMode!="FixedUpdate" ||
                clock.TimeScale!=1 || clock.Delta<=0 || clock.Delta>0.1f || clock.UnscaledDelta!=clock.Delta ||
                !HomeFinite(clock.MaximumDelta) || clock.MaximumDelta<clock.Delta || clock.MaximumDelta!=Time.maximumDeltaTime) {
                TraversalStopScene("Stationary physics warmup unavailable");return;
            }
            traversalWarmupSamples++;
            if(traversalWarmupClock.HasValue) {
                var before=traversalWarmupClock.Value;double gap=clock.WallTime-before.WallTime;
                traversalMaxGap=Math.Max(traversalMaxGap,gap);
                if(gap<0 || gap>1.500001 || clock.MaximumDelta!=before.MaximumDelta || clock.Sequence!=before.Sequence+1 || clock.Frame<before.Frame ||
                    clock.Delta!=before.Delta || Math.Abs(clock.FixedTime-before.FixedTime-before.Delta)>0.000001 ||
                    Math.Abs(clock.FixedUnscaledTime-before.FixedUnscaledTime-before.UnscaledDelta)>0.000001) {
                    TraversalStopScene("Stationary warmup native clock discontinuity/long stall");return;
                }
            }else traversalStableSince=clock.WallTime;
            traversalWarmupClock=clock;
            if(clock.WallTime-traversalStableSince<2)return;
            traversalWarmupReceipt=new {Mode="STATIONARY_READ_ONLY",Start=traversalWarmupStart,End=clock.WallTime,
                StableSince=traversalStableSince,Samples=traversalWarmupSamples,Resets=0,
                MaxWallGap=traversalMaxGap,Position=Point(traversalWarmupPose),LastClock=clock};
            Log("TRAVERSAL_WARMUP",traversalWarmupReceipt);traversalPhase="OUTDOOR_WAIT";traversalOutdoorWait=Time.realtimeSinceStartup+30f;
        }
        private void TraversalOutdoorBegin() {
            traversalOrigin=npc.transform.position;Vector3 destination;
            if(!TraversalFindSlope(out destination)){Finish("PARTIAL","TRAVERSAL_BENCH: no bounded nearby outdoor incline discovered");return;}
            traversalPhase="OUTDOOR_UP";traversalOutdoor=true;
            TraversalSceneBegin("OUTDOOR_STEP","OUTDOOR_UP");
            if(!IssueTraversal(destination,"OUTDOOR_UP"))TraversalStopScene("Outdoor route refused");
        }
        private bool TraversalFindSlope(out Vector3 destination) {
            var start=npc.transform.position;float radius=BasePlayer.GetRadius();
            foreach(float distance in new[] {radius*12,radius*24,radius*48}) {
                for(int i=0;i<24;i++) {
                    float angle=i*Mathf.PI/12;var candidate=start+new Vector3(Mathf.Cos(angle),0,Mathf.Sin(angle))*distance;
                    candidate.y=TerrainMeta.HeightMap.GetHeight(candidate);Vector3 foot;var path=new RustNavMeshPath();
                    if(!NavSample(candidate,out foot) || foot.y-start.y<radius*0.15f || foot.y-start.y>distance*0.4f)continue;
                    if(CalculateRoute(foot,path) && path.status==NavMeshPathStatus.PathComplete && path.GetPathLength()<=distance*2){destination=foot;return true;}
                }
            }
            destination=Vector3.zero;return false;
        }
        private void TraversalSceneBegin(string kind,string stage) {
            if(traversalSceneKind!=null)throw new InvalidOperationException("Traversal scene already active");
            traversalSceneKind=kind;traversalSceneStage=stage;traversalSceneStart=npc.transform.position;
            traversalSceneTime=Time.realtimeSinceStartup;traversalSceneFrom=localMotion.Evidence.Count;
        }
        private void TraversalSceneEnd(string status,string reason) {
            if(traversalSceneKind==null)return;
            var receipt=new {Kind=traversalSceneKind,Stage=traversalSceneStage,Status=status,Reason=reason,Start=Point(traversalSceneStart),End=Point(npc.transform.position),
                StartTime=traversalSceneTime,EndTime=Time.realtimeSinceStartup,FramesFrom=traversalSceneFrom,FramesTo=localMotion.Evidence.Count};
            traversalScenes.Add(receipt);Log("TRAVERSAL_SCENE",receipt);traversalSceneKind=null;
        }
        private void TraversalStopScene(string reason) {
            TraversalSceneEnd("NOT_PROVEN",reason);Finish("PARTIAL","PARTIAL_TRAVERSAL / "+reason);
        }
        private void TraversalIdleSample() {
            float now=Time.realtimeSinceStartup;var position=npc.transform.position;
            float dt=now-previousTime,step=Vector3.Distance(previous,position);
            if(dt<=0 || dt>1.5f || step>5 || step>6*dt+1)throw new InvalidOperationException("Discontinuous traversal wait trace");
            total+=step;previous=position;previousTime=now;Sample(now);
        }
        private bool TraversalTick() {
            if(!traversalBench)return false;
            if(traversalPhase=="WARMUP"){TraversalIdleSample();return true;}
            if(traversalPhase=="HOME_START"){TraversalIdleSample();traversalPhase="HOME";StartCraft();return true;}
            if(traversalPhase=="OUTDOOR_WAIT") {
                TraversalIdleSample();
                if(Time.realtimeSinceStartup>traversalOutdoorWait){TraversalStopScene("Initial outdoor nav readiness timed out");return true;}
                var nav=RustNavigation.Instance;
                if(nav==null || !nav.IsDefaultNavmeshBuilt() || nav.HasPendingTiles())return true;
                TraversalOutdoorBegin();return true;
            }
            if(localMotion!=null && localMotion.Blocked && navigating && traversalPhase=="HOME") {
                TraversalStopScene(localMotion.Reason);return true;
            }
            if(traversalPhase!="OUTDOOR_UP" && traversalPhase!="OUTDOOR_DOWN" && traversalPhase!="NEGATIVE_APPROACH" && traversalPhase!="OUTDOOR_DETOUR")return false;
            float now=Time.realtimeSinceStartup;var p=npc.transform.position;float dt=now-previousTime,step=Vector3.Distance(previous,p);
            if(dt<=0 || dt>1.5f || step>6*dt+0.01f)throw new InvalidOperationException("Discontinuous traversal bench trace");
            total+=step;previous=p;previousTime=now;Sample(now);
            if(now>deadline){TraversalStopScene("Outdoor scene deadline");return true;}
            if(localMotion.Blocked){TraversalStopScene(localMotion.Reason);return true;}
            if(!localMotion.Arrived)return true;
            if(traversalPhase=="NEGATIVE_APPROACH") { TraversalOutdoorRefusals();return true; }
            if(traversalPhase=="OUTDOOR_DETOUR") {
                if(Vector3.Distance(npc.transform.position,traversalSceneStart)<BasePlayer.GetRadius()*2 || traversalOutdoorDoor==null || traversalOutdoorDoor.IsOpen())
                {TraversalStopScene("Closed-door detour lacks physical distance/unchanged door");return true;}
                TraversalSceneEnd("PASSED","Observed supported detour around discovered closed geometry");traversalPhase="HOME_START";return true;
            }
            bool up=traversalPhase=="OUTDOOR_UP";
            float delta=npc.transform.position.y-traversalSceneStart.y;
            if(up?delta<=0:delta>=0){TraversalStopScene("Observed outdoor height transition absent");return true;}
            TraversalSceneEnd("PASSED",up?"Observed supported outdoor ascent":"Observed supported outdoor descent");
            if(up) {
                traversalPhase="OUTDOOR_DOWN";TraversalSceneBegin("SLOPE_DOWN","OUTDOOR_DOWN");
                if(!IssueTraversal(traversalOrigin,"OUTDOOR_DOWN"))TraversalStopScene(localMotion.Reason);
            }else TraversalOutdoorNegativeBegin();
            return true;
        }
        private void TraversalOutdoorNegativeBegin() {
            // Discover real native geometry; never construct the house merely to unlock outdoor tests.
            var start=npc.transform.position;float r=BasePlayer.GetRadius();
            foreach(var door in BaseNetworkable.serverEntities.OfType<Door>().Where(d=>!d.IsDestroyed && !d.IsOpen() &&
                d.OwnerID!=npc.userID && Vector3.Distance(start,d.transform.position)<=48f).OrderBy(d=>Vector3.Distance(start,d.transform.position)).Take(16)) {
                for(int sign=-1;sign<=1;sign+=2) {
                    Vector3 stand,goal;var axis=door.transform.forward;axis.y=0;axis.Normalize();
                    if(!NavSample(door.transform.position+axis*sign*r*3,out stand) || !NavSample(door.transform.position-axis*sign*r*3,out goal))continue;
                    var a=new RustNavMeshPath();var b=new RustNavMeshPath();
                    if(!CalculateRoute(stand,a) || a.status!=NavMeshPathStatus.PathComplete || a.GetPathLength()>60 ||
                        !agent.CalculatePath(new NavVector3(stand),new NavVector3(goal),b) || b.status!=NavMeshPathStatus.PathComplete || b.GetPathLength()>24)continue;
                    traversalOutdoorDoor=door;traversalDetourGoal=goal;traversalPhase="NEGATIVE_APPROACH";
                    Log("TRAVERSAL_DISCOVERED_OBSTACLE",new {Door=Id(door),door.PrefabName,Owner=door.OwnerID.ToString(),Position=Point(door.transform.position),Stand=Point(stand),Goal=Point(goal),PathLength=b.GetPathLength(),Source="EXISTING_ISOLATED_WORLD"});
                    if(!IssueTraversal(stand,"NEGATIVE_APPROACH"))TraversalStopScene(localMotion.Reason);return;
                }
            }
            TraversalStopScene("Outdoor up/down completed; no safe bounded discovered closed-door and detour site. Home not started.");
        }
        private void TraversalOutdoorRefusals() {
            var door=traversalOutdoorDoor;if(door==null || door.IsDestroyed || door.IsOpen()){TraversalStopScene("Discovered door changed");return;}
            float r=BasePlayer.GetRadius();var position=npc.transform.position;
            var wall=Physics.OverlapCapsule(position+Vector3.up*0.5f,position+Vector3.up*1.3f,r*4,-1,QueryTriggerInteraction.Ignore)
                .Where(c=>c.GetComponentInParent<BaseEntity>()!=npc && c.GetComponentInParent<Door>()==null && !(c is TerrainCollider) && c.attachedRigidbody==null)
                .OrderBy(c=>Vector3.Distance(c.bounds.ClosestPoint(position+Vector3.up*0.9f),position+Vector3.up*0.9f)).FirstOrDefault();
            if(wall==null){TraversalStopScene("Discovered closed-door site has no nearby static wall");return;}
            var direction=wall.bounds.ClosestPoint(position+Vector3.up*0.9f)-position;direction.y=0;
            TraversalSceneBegin("SOLID_WALL","OUTDOOR_FOREIGN_WALL");
            bool clear=localMotion.ProbeDisplacement(direction.normalized*r*4,"OUTDOOR_FOREIGN_WALL");
            TraversalSceneEnd(clear?"NOT_PROVEN":"BLOCKED","Discovered foreign/world solid geometry full-body refusal");
            if(clear){TraversalStopScene("Outdoor wall refusal not proven");return;}
            var wallHits=Physics.CapsuleCastAll(position+Vector3.up*0.5f,position+Vector3.up*1.3f,r,direction.normalized,r*4,-1,QueryTriggerInteraction.Ignore);
            if(!wallHits.Any(h=>h.collider==wall && Mathf.Abs(h.normal.y)<Mathf.Cos(60*Mathf.Deg2Rad)) || localMotion.Reason!="READ_ONLY_REFUSED")
            {TraversalStopScene("Outdoor refusal lacks target-wall side contact");return;}
            var delta=door.transform.position-position;delta.y=0;
            if(delta.magnitude>r*4){TraversalStopScene("Discovered closed door beyond bounded probe");return;}
            TraversalSceneBegin("DOOR_CLOSED","OUTDOOR_CLOSED_DOOR");clear=localMotion.ProbeDisplacement(delta,"OUTDOOR_CLOSED_DOOR");
            TraversalSceneEnd(clear?"NOT_PROVEN":"BLOCKED","Discovered native closed-door full-body refusal");
            if(clear){TraversalStopScene("Outdoor closed-door refusal not proven");return;}
            var contacts=Physics.CapsuleCastAll(position+Vector3.up*0.5f,position+Vector3.up*1.3f,r,delta.normalized,delta.magnitude,-1,QueryTriggerInteraction.Ignore)
                .Where(h=>h.collider.GetComponentInParent<Door>()==door && Mathf.Abs(h.normal.y)<0.1f).OrderBy(h=>h.distance).ToArray();
            if(contacts.Length==0){TraversalStopScene("Closed-door refusal lacks target-door physical contact");return;}
            var hit=contacts[0];traversalDoorPlanePoint=hit.point;traversalDoorPlaneNormal=hit.normal;
            traversalDoorCollider=hit.collider.GetInstanceID();
            traversalDoorBoundsCenter=hit.collider.bounds.center;traversalDoorBoundsSize=hit.collider.bounds.size;
            float side=Vector3.Dot(position-traversalDoorBoundsCenter,hit.normal),other=Vector3.Dot(traversalDetourGoal-traversalDoorBoundsCenter,hit.normal);
            float extent=Vector3.Dot(new Vector3(Mathf.Abs(hit.normal.x),Mathf.Abs(hit.normal.y),Mathf.Abs(hit.normal.z)),traversalDoorBoundsSize)*0.5f;
            if(side*other>=0 || Mathf.Abs(side)<r+extent || Mathf.Abs(other)<r+extent)
            {TraversalStopScene("Discovered detour endpoints do not clear opposite sides of actual closed-door volume");return;}
            traversalPhase="OUTDOOR_DETOUR";TraversalSceneBegin("SAFE_DETOUR","OUTDOOR_DETOUR");
            if(!IssueTraversal(traversalDetourGoal,"OUTDOOR_DETOUR"))TraversalStopScene(localMotion.Reason);
        }
        private bool TraversalDoorNegative() {
            if(!traversalBench)return true;
            var door=(Door)homeEntities["DOOR"];
            if(door.IsOpen())throw new InvalidOperationException("Negative door fixture must really be closed");
            TraversalSceneBegin("DOOR_CLOSED","NEGATIVE_CLOSED_DOOR");
            var delta=door.transform.position-npc.transform.position;delta.y=0;
            if(delta.magnitude>BasePlayer.GetRadius()*4){TraversalSceneEnd("NOT_PROVEN","Closed door outside bounded probe range");return false;}
            bool clear=localMotion.ProbeDisplacement(delta,"NEGATIVE_CLOSED_DOOR");
            TraversalSceneEnd(clear?"NOT_PROVEN":"BLOCKED",clear?"Closed-door sweep unexpectedly clear":"Native closed-door direction refused before actuation");
            return !clear;
        }
        private bool TraversalWallNegative() {
            if(!traversalBench)return true;
            var position=npc.transform.position;
            var walls=homeEntities.Where(x=>x.Key.StartsWith("WALL_",StringComparison.Ordinal)).SelectMany(x=>x.Value.GetComponentsInChildren<Collider>(true))
                .Where(x=>x.enabled && !x.isTrigger).OrderBy(x=>Vector3.Distance(x.bounds.ClosestPoint(position+Vector3.up*0.9f),position+Vector3.up*0.9f)).ToArray();
            if(walls.Length==0)throw new InvalidOperationException("Native wall fixture collider absent");
            var delta=walls[0].bounds.ClosestPoint(position+Vector3.up*0.9f)-position;delta.y=0;
            if(delta.sqrMagnitude==0)throw new InvalidOperationException("Wall direction ambiguous");
            delta=delta.normalized*BasePlayer.GetRadius()*4;
            TraversalSceneBegin("SOLID_WALL","NEGATIVE_SOLID_WALL");
            bool clear=localMotion.ProbeDisplacement(delta,"NEGATIVE_SOLID_WALL");
            TraversalSceneEnd(clear?"NOT_PROVEN":"BLOCKED",clear?"Wall not within bounded full-body probe":"Native wall direction refused before actuation");
            return !clear;
        }
        private void TraversalHomeBegin() {
            if(!traversalBench)return;
            traversalHome=true;TraversalSceneBegin("NATIVE_BUILDING_STEP","HOME_IN_OUT");
        }
        private bool TraversalHomeComplete() {
            if(!traversalBench)return false;
            TraversalSceneEnd("PASSED","Observed native doorway in/out with original body");
            homePhase="TRAVERSAL_COMPLETE";traversalComplete=true;Finish("PARTIAL","TRAVERSAL_BENCH_COMPLETE / independent validator decides physical acceptance");return true;
        }
        private object TraversalResult() {
            return localMotion==null?null:new {Schema=1,Mode=traversalBench?"TRAVERSAL_BENCH":"SHARED_RUNTIME",World=(currentWorld??ReadCurrentWorld()).WorldKey(),
                Frames=localMotion.Evidence,Scenes=traversalScenes,Actuations=localMotion.Actuations,Components=traversalComponents,Warmup=traversalWarmupReceipt,SpawnSupport=traversalSpawnSupport,Order="OUTDOOR_FIRST",SharedOutdoor=traversalOutdoor,SharedHome=traversalHome,Completed=traversalComplete};
        }
        private void StopTraversal(string reason) {
            if(motionDriver!=null)motionDriver.Step=null;
            if(localMotion!=null)localMotion.Stop(reason);
        }
    }
}
