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
        private int traversalWarmupSamples;
        private int traversalWindowRestarts;
        private float traversalWarmupMaximum;
        private object traversalWarmupContract;
        private string traversalWarmupBodyKey;
        private readonly List<object> traversalWarmupObservations=new List<object>();
        private RustBots.Navigation.ObstacleTraversal.TraversalClock? traversalWindowFirst;
        private Vector3 traversalWarmupPose;
        private RustBots.Navigation.ObstacleTraversal.TraversalClock? traversalWarmupClock;
        private object traversalWarmupReceipt;
        private readonly List<object> traversalScenes=new List<object>();
        private readonly List<object> traversalComponents=new List<object>();
        private readonly List<object> traversalSpawnSupport=new List<object>();
        private Door traversalOutdoorDoor;
        private Vector3 traversalDetourGoal,traversalWallStand,traversalDoorStand;
        private BuildingBlock traversalWall;
        private Bounds traversalFootprint;
        private Vector3? traversalDetourVia;
        private object traversalFixture,traversalDetour;

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
                var door=traversalOutdoorDoor;var foundation=homeEntities["FOUNDATION"];
                frame["FixtureDetourWitness"]=new {Door=Id(door),Open=door.IsOpen(),DoorPosition=Point(door.transform.position),
                    Foundation=Id(foundation),LocalPosition=Point(foundation.transform.InverseTransformPoint(npc.transform.position)),
                    Outside=TraversalOutside(npc.transform.position),Plan=traversalDetour};
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
            var body=TraversalWarmupBody();traversalWarmupBodyKey=JsonConvert.SerializeObject(body);traversalWarmupMaximum=localMotion.NativeMaximumDeltaTime;
            traversalWarmupContract=new {Start=traversalWarmupStart,Position=Point(traversalWarmupPose),Body=body,NativeMaximumDelta=traversalWarmupMaximum,
                MaxSeconds=20,MinWindowSeconds=2,MaxSamples=512};
        }
        private object TraversalWarmupBody() {
            var body=npc.GetComponent<Rigidbody>();
            return new {Actor=Id(npc),Capsules=npc.GetComponents<CapsuleCollider>().Select(c=>new {Instance=c.GetInstanceID(),Radius=c.radius,Height=c.height,Center=Point(c.center),
                Direction=c.direction,Scale=Point(c.transform.lossyScale),Up=Point(c.transform.up),Enabled=c.enabled,Trigger=c.isTrigger,Layer=c.gameObject.layer,Rigidbody=c.attachedRigidbody==null?0:c.attachedRigidbody.GetInstanceID()}).ToArray(),
                Rigidbody=body.GetInstanceID(),Kinematic=body.isKinematic,Gravity=body.useGravity,DetectCollisions=body.detectCollisions,CollisionMode=body.collisionDetectionMode.ToString(),
                Colliders=npc.GetComponentsInChildren<Collider>().Where(c=>c.enabled && !c.isTrigger).Select(c=>c.GetInstanceID()).OrderBy(i=>i).ToArray(),
                AgentStopped=agent.isStopped,AgentUpdatePosition=agent.updatePosition,AgentUpdateRotation=agent.updateRotation};
        }
        private void TraversalWarmup(RustBots.Navigation.ObstacleTraversal.TraversalClock clock) {
            double observed=Time.realtimeSinceStartupAsDouble;var position=npc.transform.position;var velocity=npc.GetComponent<Rigidbody>().linearVelocity;var body=TraversalWarmupBody();
            var reasons=new List<string>();string outcome;
            bool fatal=double.IsNaN(observed) || double.IsInfinity(observed) || observed<traversalWarmupStart || observed-traversalWarmupStart>20 ||
                traversalWarmupObservations.Count>=511 || !HomeFinite(position.x) || !HomeFinite(position.y) || !HomeFinite(position.z) ||
                Vector3.Distance(position,traversalWarmupPose)>0.001f || velocity.sqrMagnitude!=0 ||
                JsonConvert.SerializeObject(body)!=traversalWarmupBodyKey || localMotion.Actuations!=0 || localMotion.Active || localMotion.Blocked;
            bool invalid=double.IsNaN(clock.WallTime) || double.IsInfinity(clock.WallTime) || double.IsNaN(clock.FixedTime) || double.IsInfinity(clock.FixedTime) ||
                double.IsNaN(clock.FixedUnscaledTime) || double.IsInfinity(clock.FixedUnscaledTime) || !HomeFinite(clock.Delta) ||
                clock.WallTime<traversalWarmupStart || clock.WallTime>observed || observed-clock.WallTime>0.1 || clock.FixedTime<0 || clock.FixedUnscaledTime<0 || clock.Sequence<=0 || clock.Frame<0 ||
                !clock.InFixedStep || clock.PhysicsMode!="FixedUpdate" ||
                clock.TimeScale!=1 || clock.Delta<=0 || clock.Delta>0.1f || clock.UnscaledDelta!=clock.Delta ||
                !HomeFinite(clock.MaximumDelta) || clock.MaximumDelta<clock.Delta || clock.MaximumDelta!=traversalWarmupMaximum || clock.MaximumDelta!=Time.maximumDeltaTime;
            if(invalid)reasons.Add("CLOCK_ENVELOPE");
            if(!invalid && traversalWarmupClock.HasValue) {
                var before=traversalWarmupClock.Value;double gap=clock.WallTime-before.WallTime;
                if(gap<0 || gap>1.500001 || clock.MaximumDelta!=before.MaximumDelta || clock.Sequence!=before.Sequence+1 || clock.Frame<before.Frame ||
                    clock.Delta!=before.Delta || Math.Abs(clock.FixedTime-before.FixedTime-before.Delta)>0.000001 ||
                    Math.Abs(clock.FixedUnscaledTime-before.FixedUnscaledTime-before.UnscaledDelta)>0.000001) {
                    invalid=true;reasons.Add("CLOCK_CONTINUITY");
                }else traversalMaxGap=Math.Max(traversalMaxGap,gap);
            }
            if(fatal){outcome="FATAL";reasons.Add("BODY_MOTOR_OR_TOTAL_WARMUP_BOUND");}
            else if(invalid) {
                outcome="WAIT";if(traversalWarmupClock.HasValue)traversalWindowRestarts++;
                traversalWarmupClock=null;traversalWindowFirst=null;traversalWarmupSamples=0;traversalMaxGap=0;
            }else {
                outcome=traversalWarmupClock.HasValue?"WINDOW_ADVANCE":"WINDOW_START";
                if(!traversalWindowFirst.HasValue){traversalWindowFirst=clock;traversalStableSince=clock.WallTime;}
                traversalWarmupClock=clock;traversalWarmupSamples++;
                var first=traversalWindowFirst.Value;
                if(clock.WallTime-first.WallTime>=2 && clock.FixedTime-first.FixedTime>=2 && clock.FixedUnscaledTime-first.FixedUnscaledTime>=2)outcome="READY";
            }
            var observation=new {Observation=traversalWarmupObservations.Count+1,ObservedWall=observed,Clock=clock,LiveMaximumDelta=Time.maximumDeltaTime,Position=Point(position),Velocity=Point(velocity),Body=body,
                MotorActuations=localMotion.Actuations,MotorActive=localMotion.Active,MotorBlocked=localMotion.Blocked,Outcome=outcome,Reasons=reasons.ToArray()};
            traversalWarmupObservations.Add(observation);
            if(outcome!="WINDOW_ADVANCE")Log("TRAVERSAL_WARMUP_OBSERVATION",observation);
            if(fatal){TraversalStopScene("Stationary readiness body/motor/deadline violated; clock evidence retained");return;}
            if(outcome!="READY")return;
            traversalWarmupReceipt=new {Schema=2,Mode="STATIONARY_READ_ONLY",Start=traversalWarmupStart,End=clock.WallTime,
                StableSince=traversalStableSince,Samples=traversalWarmupSamples,TotalObservations=traversalWarmupObservations.Count,Resets=0,MotorResets=0,WindowRestarts=traversalWindowRestarts,
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
            foreach(float distance in new[] {radius*8,radius*10}) {
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
            if(traversalPhase=="WARMUP"){
                TraversalIdleSample();
                if(Time.realtimeSinceStartupAsDouble-traversalWarmupStart>20) {
                    var observation=new {Observation=traversalWarmupObservations.Count+1,ObservedWall=Time.realtimeSinceStartupAsDouble,
                        Clock=(RustBots.Navigation.ObstacleTraversal.TraversalClock?)null,LiveMaximumDelta=Time.maximumDeltaTime,
                        Position=Point(npc.transform.position),Velocity=Point(npc.GetComponent<Rigidbody>().linearVelocity),Body=TraversalWarmupBody(),
                        MotorActuations=localMotion.Actuations,MotorActive=localMotion.Active,MotorBlocked=localMotion.Blocked,Outcome="FATAL",Reasons=new[] {"WARMUP_CALLBACK_DEADLINE"}};
                    if(traversalWarmupObservations.Count<512)traversalWarmupObservations.Add(observation);
                    Log("TRAVERSAL_WARMUP_OBSERVATION",observation);TraversalStopScene("Original twenty-second stationary-readiness deadline expired");
                }
                return true;
            }
            if(traversalPhase=="HOME_START"){TraversalIdleSample();traversalPhase="HOME";StartCraft();return true;}
            if(traversalPhase=="FIXTURE_WAIT") {
                TraversalIdleSample();
                if(RustNavigation.Instance.HasPendingTiles()){if(Time.realtimeSinceStartup>homeWait)TraversalStopScene("Fixture native tiles pending timeout");return true;}
                TraversalFixtureBegin();return true;
            }
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
            if(traversalPhase!="OUTDOOR_UP" && traversalPhase!="OUTDOOR_DOWN" && !traversalPhase.StartsWith("FIXTURE_",StringComparison.Ordinal) && traversalPhase!="OUTDOOR_DETOUR")return false;
            float now=Time.realtimeSinceStartup;var p=npc.transform.position;float dt=now-previousTime,step=Vector3.Distance(previous,p);
            if(dt<=0 || dt>1.5f || step>6*dt+0.01f)throw new InvalidOperationException("Discontinuous traversal bench trace");
            total+=step;previous=p;previousTime=now;Sample(now);
            if(now>deadline){TraversalStopScene("Outdoor scene deadline");return true;}
            if(localMotion.Blocked){TraversalStopScene(localMotion.Reason);return true;}
            if(!localMotion.Arrived)return true;
            if(traversalPhase=="FIXTURE_WALL") {
                if(!TraversalFixtureProbe(traversalWall,"SOLID_WALL","FIXTURE_WALL_REFUSAL"))return true;
                TraversalFixtureMove(traversalDoorStand,"FIXTURE_DOOR");return true;
            }
            if(traversalPhase=="FIXTURE_DOOR") {
                if(!TraversalFixtureProbe(traversalOutdoorDoor,"DOOR_CLOSED","FIXTURE_DOOR_REFUSAL"))return true;
                TraversalFixtureMove(traversalWallStand,"FIXTURE_DETOUR_START");return true;
            }
            if(traversalPhase=="FIXTURE_DETOUR_START"){TraversalFixtureDetour();return true;}
            if(traversalPhase=="FIXTURE_HOME_RETURN") {
                traversalPhase="HOME";homePhase="NAV_WAIT";homeWait=now+30;return true;
            }
            if(traversalPhase=="OUTDOOR_DETOUR") {
                if(traversalDetourVia.HasValue) {
                    traversalDetourVia=null;
                    if(!IssueTraversal(traversalDetourGoal,"OUTDOOR_DETOUR"))TraversalStopScene(localMotion.Reason);
                    return true;
                }
                if(Vector3.Distance(npc.transform.position,traversalSceneStart)<=2 || traversalOutdoorDoor==null || traversalOutdoorDoor.IsOpen())
                {TraversalStopScene("Closed-door detour lacks physical distance/unchanged door");return true;}
                TraversalSceneEnd("PASSED","Observed supported exterior detour around paid native wall");
                TraversalFixtureMove(traversalDoorStand,"FIXTURE_HOME_RETURN");return true;
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
            // Paid TEST_FIXTURE construction follows the short regression immediately.
            traversalPhase="HOME_START";
        }
        private void TraversalFixtureMove(Vector3 destination,string phase) {
            traversalPhase=phase;
            if(!IssueTraversal(destination,phase))TraversalStopScene(localMotion.Reason);
        }
        private bool TraversalFixtureStand(BaseEntity wall,out Vector3 stand) {
            var foundation=homeEntities["FOUNDATION"];var outward=wall.transform.position-foundation.transform.position;
            outward.y=0;outward.Normalize();
            // Relative native entity geometry only. Never install a fixture at fixed world coordinates.
            foreach(float offset in new[] {1.3f,1.5f,1.1f}) {
                var candidate=wall.transform.position+outward*offset;candidate.y=TerrainMeta.HeightMap.GetHeight(candidate);
                if(NavSample(candidate,out stand) && TraversalOutside(stand))return true;
            }
            stand=Vector3.zero;return false;
        }
        private bool TraversalOutside(Vector3 position) {
            var local=homeEntities["FOUNDATION"].transform.InverseTransformPoint(position);
            return local.x<=traversalFootprint.min.x || local.x>=traversalFootprint.max.x || local.z<=traversalFootprint.min.z || local.z>=traversalFootprint.max.z;
        }
        private bool TraversalExteriorSegment(Vector3 from,Vector3 to) {
            var f=homeEntities["FOUNDATION"].transform;var a=f.InverseTransformPoint(from);var b=f.InverseTransformPoint(to);
            return a.x<=traversalFootprint.min.x && b.x<=traversalFootprint.min.x || a.x>=traversalFootprint.max.x && b.x>=traversalFootprint.max.x ||
                a.z<=traversalFootprint.min.z && b.z<=traversalFootprint.min.z || a.z>=traversalFootprint.max.z && b.z>=traversalFootprint.max.z;
        }
        private void TraversalFixtureBegin() {
            HomeRequireStructure();traversalOutdoorDoor=(Door)homeEntities["DOOR"];
            traversalWall=(BuildingBlock)homeEntities["WALL_N"];
            var nativeBounds=homeDefinitions["FOUNDATION"].bounds;traversalFootprint=nativeBounds;
            traversalFootprint.Expand(new Vector3(1+Physics.defaultContactOffset*4,0,1+Physics.defaultContactOffset*4));
            if(traversalOutdoorDoor.IsOpen() || !TraversalFixtureStand(traversalWall,out traversalWallStand) ||
                !TraversalFixtureStand(homeEntities["WALL_E"],out traversalDetourGoal) ||
                !TraversalFixtureStand(homeEntities["DOORWAY"],out traversalDoorStand)) {
                TraversalStopScene("Paid native fixture exists; no supported bounded exterior stands");return;
            }
            traversalFixture=new {Source="OWNED_NATIVE_TEST_FIXTURE",DiagnosticOnly=true,Structure=DescribeHome(),
                Wall=Id(traversalWall),Door=Id(traversalOutdoorDoor),Foundation=Id(homeEntities["FOUNDATION"]),
                WallStand=Point(traversalWallStand),DoorStand=Point(traversalDoorStand),DetourGoal=Point(traversalDetourGoal),
                FoundationPosition=Point(homeEntities["FOUNDATION"].transform.position),FoundationRotation=new[] {homeRotation.x,homeRotation.y,homeRotation.z,homeRotation.w},
                NativeFoundationBounds=new {Center=Point(nativeBounds.center),Size=Point(nativeBounds.size)},
                Radius=0.5f,Skin=Physics.defaultContactOffset*2,
                ExteriorMin=Point(traversalFootprint.min),ExteriorMax=Point(traversalFootprint.max),
                FoundationColliders=homeEntities["FOUNDATION"].GetComponentsInChildren<Collider>(true).Select(HomeCollider).ToArray(),Time=Time.realtimeSinceStartup};
            Log("TRAVERSAL_NATIVE_FIXTURE",traversalFixture);TraversalFixtureMove(traversalWallStand,"FIXTURE_WALL");
        }
        private bool TraversalFixtureProbe(BaseEntity targetEntity,string kind,string stage,Vector3? direction=null) {
            var position=npc.transform.position;
            var colliders=targetEntity.GetComponentsInChildren<Collider>(true).Where(c=>c.enabled && !c.isTrigger && c.GetComponentInParent<BaseEntity>()==targetEntity).ToArray();
            var nearest=colliders.OrderBy(c=>Vector3.Distance(c.bounds.center,position+Vector3.up*0.9f)).FirstOrDefault();
            if(nearest==null){TraversalStopScene("Fixture target native collider absent");return false;}
            var delta=direction??(nearest.bounds.center-position);delta.y=0;
            if(delta.sqrMagnitude==0){TraversalStopScene("Fixture target direction ambiguous");return false;}
            delta=delta.normalized*2;
            TraversalSceneBegin(kind,stage);int first=localMotion.Evidence.Count;
            bool clear=localMotion.ProbeDisplacement(delta,stage,Id(targetEntity));
            var contact=Physics.CapsuleCastAll(position+Vector3.up*0.5f,position+Vector3.up*1.3f,0.5f,delta.normalized,delta.magnitude,-1,QueryTriggerInteraction.Ignore)
                .Where(h=>colliders.Contains(h.collider) && Mathf.Abs(h.normal.y)<0.5f).ToArray();
            bool proof=!clear && contact.Length>0 && !localMotion.Blocked && !localMotion.Active &&
                localMotion.Evidence.Skip(first).OfType<Dictionary<string,object>>().Any(f=>(string)f["Event"]=="PROBE_REFUSED");
            TraversalSceneEnd(proof?"BLOCKED":"NOT_PROVEN",proof?"Target-bound native full-body observation; motor state preserved":"Intended native target refusal not established");
            if(!proof)TraversalStopScene("Fixture "+kind+" lacks intended collider or nondestructive refusal");
            return proof;
        }
        private void TraversalFixtureDetour() {
            var position=npc.transform.position;var delta=traversalDetourGoal-position;
            // The bounded prefix is on the actual start→goal line and must hit our named wall.
            if(!TraversalFixtureProbe(traversalWall,"SOLID_WALL","FIXTURE_DIRECT_REFUSAL",delta))return;
            var paths=new List<RustNavMeshPath>();RustNavMeshPath path;
            traversalDetourVia=null;
            if(TraversalExteriorPath(position,traversalDetourGoal,out path))paths.Add(path);
            else {
                // RustNav's shortest rounded corner may be too close for our full-body margin.
                // Ask the same native planner for two supported exterior legs, never inject fake corners.
                var f=homeEntities["FOUNDATION"].transform;
                var a=f.InverseTransformPoint(position);var b=f.InverseTransformPoint(traversalDetourGoal);
                var relative=new Vector3(a.x+b.x>=0?traversalFootprint.max.x+0.6f:traversalFootprint.min.x-0.6f,0,
                    a.z+b.z>=0?traversalFootprint.max.z+0.6f:traversalFootprint.min.z-0.6f);
                var candidate=f.TransformPoint(relative);candidate.y=TerrainMeta.HeightMap.GetHeight(candidate);Vector3 via;RustNavMeshPath second;
                if(!NavSample(candidate,out via) || !TraversalExteriorPath(position,via,out path) || !TraversalExteriorPath(via,traversalDetourGoal,out second)) {
                    TraversalStopScene("No legal bounded native exterior corner detour");return;
                }
                paths.Add(path);paths.Add(second);traversalDetourVia=via;
            }
            float length=paths.Sum(p=>p.GetPathLength());
            if(length>24 || length<=delta.magnitude+0.1f){TraversalStopScene("Exterior detour length is not a bounded alternate");return;}
            var corners=paths.SelectMany((p,i)=>i==0?p.corners:p.corners.Skip(1)).Select(c=>Point(c.Value)).ToArray();
            traversalDetour=new {Source="OWNED_NATIVE_TEST_FIXTURE",Wall=Id(traversalWall),Door=Id(traversalOutdoorDoor),
                Start=Point(position),Goal=Point(traversalDetourGoal),Corners=corners,
                Legs=paths.Select(p=>new {Status=p.status.ToString(),Length=p.GetPathLength(),Corners=p.corners.Select(c=>Point(c.Value)).ToArray()}).ToArray(),
                Status=paths[0].status.ToString(),Length=length,DirectLength=delta.magnitude,Time=Time.realtimeSinceStartup};
            Log("TRAVERSAL_EXTERIOR_PLAN",traversalDetour);traversalPhase="OUTDOOR_DETOUR";TraversalSceneBegin("SAFE_DETOUR","OUTDOOR_DETOUR");
            if(!IssueTraversal(traversalDetourVia??traversalDetourGoal,"OUTDOOR_DETOUR"))TraversalStopScene(localMotion.Reason);
        }
        private bool TraversalExteriorPath(Vector3 from,Vector3 to,out RustNavMeshPath path) {
            path=new RustNavMeshPath();
            if(!agent.CalculatePath(new NavVector3(from),new NavVector3(to),path) || path.status!=NavMeshPathStatus.PathComplete || path.corners.Count<2)return false;
            var corners=path.corners.Select(c=>c.Value).ToArray();
            return corners.All(TraversalOutside) && Enumerable.Range(1,corners.Length-1).All(i=>TraversalExteriorSegment(corners[i-1],corners[i]));
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
                Frames=localMotion.Evidence,Scenes=traversalScenes,Actuations=localMotion.Actuations,Components=traversalComponents,Warmup=traversalWarmupReceipt,SpawnSupport=traversalSpawnSupport,
                WarmupPolicy="STATIONARY_CLOCK_WINDOW_V1",WarmupContract=traversalWarmupContract,WarmupObservations=traversalWarmupObservations,WarmupObservationCount=traversalWarmupObservations.Count,
                Order="OWNED_NATIVE_TEST_FIXTURE",ReadinessPolicy=localMotion.ReadinessPolicy,Fixture=traversalFixture,Detour=traversalDetour,SharedOutdoor=traversalOutdoor,SharedHome=traversalHome,Completed=traversalComplete};
        }
        private void StopTraversal(string reason) {
            if(motionDriver!=null)motionDriver.Step=null;
            if(localMotion!=null)localMotion.Stop(reason);
        }
    }
}
