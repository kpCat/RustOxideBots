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
                UnscaledDelta=Time.fixedUnscaledDeltaTime,TimeScale=Time.timeScale,
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
        private int traversalWarmupSamples,traversalWarmupResets;
        private Vector3 traversalWarmupPose;
        private RustBots.Navigation.ObstacleTraversal.TraversalClock? traversalWarmupClock;
        private object traversalWarmupReceipt;
        private readonly List<object> traversalScenes=new List<object>();
        private readonly List<object> traversalComponents=new List<object>();

        private void EnsureTraversal() {
            if(localMotion!=null)return;
            if(!traversalBench)throw new InvalidOperationException("Candidate traversal requires its explicit isolated bench until physical promotion");
            var scientist=npc as ScientistNPC;
            if(scientist==null)throw new InvalidOperationException("Traversal requires the original ScientistNPC");
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
                clock.TimeScale!=1 || clock.Delta<=0 || clock.Delta>0.1f || clock.UnscaledDelta!=clock.Delta) {
                TraversalStopScene("Stationary physics warmup unavailable");return;
            }
            traversalWarmupSamples++;
            if(traversalWarmupClock.HasValue) {
                var before=traversalWarmupClock.Value;double gap=clock.WallTime-before.WallTime;
                traversalMaxGap=Math.Max(traversalMaxGap,gap);
                if(gap<0 || gap>0.100001 || clock.Sequence!=before.Sequence+1 || clock.Frame<before.Frame ||
                    clock.Delta!=before.Delta || Math.Abs(clock.FixedTime-before.FixedTime-before.Delta)>0.000001 ||
                    Math.Abs(clock.FixedUnscaledTime-before.FixedUnscaledTime-before.UnscaledDelta)>0.000001) {
                    traversalStableSince=clock.WallTime;traversalWarmupResets++;
                }
            }else traversalStableSince=clock.WallTime;
            traversalWarmupClock=clock;
            if(clock.WallTime-traversalStableSince<2)return;
            traversalWarmupReceipt=new {Mode="STATIONARY_READ_ONLY",Start=traversalWarmupStart,End=clock.WallTime,
                StableSince=traversalStableSince,Samples=traversalWarmupSamples,Resets=traversalWarmupResets,
                MaxWallGap=traversalMaxGap,Position=Point(traversalWarmupPose),LastClock=clock};
            Log("TRAVERSAL_WARMUP",traversalWarmupReceipt);traversalPhase="HOME_START";
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
                if(Time.realtimeSinceStartup>traversalOutdoorWait){TraversalStopScene("Outdoor nav readiness after native door close timed out");return true;}
                var nav=RustNavigation.Instance;
                if(nav==null || !nav.IsDefaultNavmeshBuilt() || nav.HasPendingTiles())return true;
                TraversalOutdoorBegin();return true;
            }
            if(localMotion!=null && localMotion.Blocked && navigating && traversalPhase=="HOME") {
                TraversalStopScene(localMotion.Reason);return true;
            }
            if(traversalPhase!="OUTDOOR_UP" && traversalPhase!="OUTDOOR_DOWN")return false;
            float now=Time.realtimeSinceStartup;var p=npc.transform.position;float dt=now-previousTime,step=Vector3.Distance(previous,p);
            if(dt<=0 || dt>1.5f || step>6*dt+0.01f)throw new InvalidOperationException("Discontinuous traversal bench trace");
            total+=step;previous=p;previousTime=now;Sample(now);
            if(now>deadline){TraversalStopScene("Outdoor scene deadline");return true;}
            if(localMotion.Blocked){TraversalStopScene(localMotion.Reason);return true;}
            if(!localMotion.Arrived)return true;
            bool up=traversalPhase=="OUTDOOR_UP";
            float delta=npc.transform.position.y-traversalSceneStart.y;
            if(up?delta<=0:delta>=0){TraversalStopScene("Observed outdoor height transition absent");return true;}
            TraversalSceneEnd("PASSED",up?"Observed supported outdoor ascent":"Observed supported outdoor descent");
            if(up) {
                traversalPhase="OUTDOOR_DOWN";TraversalSceneBegin("SLOPE_DOWN","OUTDOOR_DOWN");
                if(!IssueTraversal(traversalOrigin,"OUTDOOR_DOWN"))TraversalStopScene(localMotion.Reason);
            }else{traversalComplete=true;Finish("PARTIAL","TRAVERSAL_BENCH_COMPLETE / independent validator decides physical acceptance");}
            return true;
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
            homePhase="TRAVERSAL_COMPLETE";traversalPhase="OUTDOOR_WAIT";traversalOutdoorWait=Time.realtimeSinceStartup+30f;return true;
        }
        private object TraversalResult() {
            return localMotion==null?null:new {Schema=1,Mode=traversalBench?"TRAVERSAL_BENCH":"SHARED_RUNTIME",World=(currentWorld??ReadCurrentWorld()).WorldKey(),
                Frames=localMotion.Evidence,Scenes=traversalScenes,Actuations=localMotion.Actuations,Components=traversalComponents,Warmup=traversalWarmupReceipt,SharedOutdoor=traversalOutdoor,SharedHome=traversalHome,Completed=traversalComplete};
        }
        private void StopTraversal(string reason) {
            if(motionDriver!=null)motionDriver.Step=null;
            if(localMotion!=null)localMotion.Stop(reason);
        }
    }
}
