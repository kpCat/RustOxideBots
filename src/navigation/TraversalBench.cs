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
            Step(ReadNativeClock(++sequence));
        }
        internal static ObstacleTraversal.TraversalClock ReadNativeClock(long observedSequence) {
            return new ObstacleTraversal.TraversalClock {
                ClockPolicy=ObstacleTraversal.ClockPolicy,
                WallTime=Time.realtimeSinceStartupAsDouble,FixedTime=Time.fixedTimeAsDouble,
                FixedUnscaledTime=Time.fixedUnscaledTimeAsDouble,Delta=Time.fixedDeltaTime,
                UnscaledDelta=Time.fixedUnscaledDeltaTime,TimeScale=Time.timeScale,MaximumDelta=Time.maximumDeltaTime,
                InFixedStep=Time.inFixedTimeStep,PhysicsMode=Physics.simulationMode.ToString(),Sequence=observedSequence,Frame=Time.frameCount
            };
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
        private const int MAX_BUILD_LEGS=3;
        private readonly Queue<Vector3> traversalBuildWaypoints=new Queue<Vector3>();
        private readonly List<object> traversalBuildPlans=new List<object>();
        private readonly List<object> traversalBuildRests=new List<object>();
        private string traversalBuildStage;
        private int traversalBuildLeg;
        private Vector3 traversalBuildFoundation;
        private Quaternion traversalBuildRotation;
        private float traversalFixtureReadyAt;
        private bool traversalG4Complete;
        private bool traversalRecoveryRequested;
        private readonly List<object> traversalFixtureTransitions=new List<object>();
        private readonly List<object> traversalFixtureStandAttempts=new List<object>();
        private Dictionary<string,object> traversalFoundationAdmission;
        private sealed class TraversalDestinationNativeReadiness {
            public double StartedWall,CompletedWall;
            public bool NavAvailable,DefaultMesh,DefaultBuilt,OnNavmesh,Ready;
            public bool? PendingTiles;
            public string Reason;
        }
        private sealed class TraversalDestinationWindow {
            internal int Id,BaseActuations,Samples,Restarts,SetDestinationCalls;
            internal string Stage,BodyKey,Reason,Outcome="QUEUED";
            internal Vector3 Goal,Position;
            internal double Start,StableSince,MaxGap,EndWall,GlobalDeadline;
            internal float Maximum;
            internal object Contract,Receipt,Commit,Handoff;
            internal RustBots.Navigation.ObstacleTraversal.TraversalClock? Previous,First;
            internal readonly List<object> Observations=new List<object>();
        }
        private sealed class TraversalDestinationHandoff {
            public bool Accepted;
            public RustBots.Navigation.ObstacleTraversal.TraversalClock ReadyClock,Clock;
            public float[] Position,Velocity;
            public object Body;
            public int MotorActuations;
            public double CheckedWall;
            public double? TickCompletedWall;
        }
        private readonly List<TraversalDestinationWindow> traversalDestinations=new List<TraversalDestinationWindow>();
        private TraversalDestinationWindow traversalDestination;
        private Dictionary<string,object> traversalLastAcceptedWitness;
        private Vector3 traversalLastWitnessNativeVelocity;
        private int traversalIssuedCommands,traversalAcceptedWitnesses;

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
                try{if(traversalPhase=="WARMUP")TraversalWarmup(clock);else if(traversalDestination!=null)TraversalDestinationObserve(clock);else localMotion.Tick(clock);}
                catch(Exception ex){localMotion.Stop("SENSOR_EXCEPTION");PrintError(ex.ToString());Finish("PARTIAL","Traversal sensor/actuator exception");}
            };
        }
        private void TraversalWitness(object row) {
            var frame=row as Dictionary<string,object>;
            if(frame!=null && traversalBuildStage!=null && ((string)frame["Event"]=="MOVE_DECISION" || (string)frame["Event"]=="MOTION_WITNESS")) {
                var f=homeEntities["FOUNDATION"].transform;var a=(float[])frame["From"];
                var b=(float[])frame[(string)frame["Event"]=="MOVE_DECISION"?"Requested":"Actual"];
                bool clear=f.position==traversalBuildFoundation && Quaternion.Angle(f.rotation,traversalBuildRotation)<=0.001f &&
                    TraversalBuildExteriorSegment(new Vector3(a[0],a[1],a[2]),new Vector3(b[0],b[1],b[2]),f.position,f.rotation,TraversalBuildBounds());
                frame["BuildExteriorWitness"]=new {Stage=traversalBuildStage,Leg=traversalBuildLeg,Foundation=Id(homeEntities["FOUNDATION"]),
                    FoundationPosition=Point(f.position),FoundationRotation=new[] {f.rotation.x,f.rotation.y,f.rotation.z,f.rotation.w},Outside=clear};
                // The evidence callback precedes the motor writer; an unsafe intent
                // throws into C's terminal guard and cannot actuate through the footprint.
                if(!clear)throw new InvalidOperationException("BUILD_EXTERIOR_FOOTPRINT_REFUSED");
            }
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
            if(frame!=null && !traversalRecoveryRequested && (string)frame["Event"]=="MOTION_WITNESS" && (string)frame["NativeResult"]=="OBSERVED" &&
                (string)frame["Stage"]=="HOME_SITE" && (float)frame["Speed"]>=0.4f && localMotion.QueueMeasuredReplan())traversalRecoveryRequested=true;
            if(frame==null)throw new InvalidOperationException("Traversal receipt is not a retained native frame");
            if((string)frame["Event"]=="MOVE_ISSUED")traversalIssuedCommands++;
            if((string)frame["Event"]=="MOTION_WITNESS" && (string)frame["NativeResult"]=="OBSERVED") {
                traversalAcceptedWitnesses++;traversalLastAcceptedWitness=frame;traversalLastWitnessNativeVelocity=npc.GetComponent<Rigidbody>().linearVelocity;
            }
            // C already retains this complete dictionary, including mutations
            // above and finally-recorded sink times. Optional console JSON/Puts
            // must not block the checked physics callback; primary is authoritative.
        }
        private bool CalculateRoute(Vector3 destination,RustNavMeshPath path) {
            return localMotion==null?agent.CalculatePath(destination,path):agent.CalculatePath(new NavVector3(npc.transform.position),new NavVector3(destination),path);
        }
        private bool IssueTraversal(Vector3 destination,string stage) {
            EnsureTraversal();var position=npc.transform.position;var velocity=npc.GetComponent<Rigidbody>().linearVelocity;var body=TraversalWarmupBody();
            if(traversalDestination!=null || traversalDestinations.Count>=64 || localMotion.Active || localMotion.Blocked || !TraversalExactZero(velocity) ||
                localMotion.Actuations!=traversalIssuedCommands || traversalIssuedCommands!=traversalAcceptedWitnesses ||
                JsonConvert.SerializeObject(body)!=traversalWarmupBodyKey || !HomeFinite(destination.x) || !HomeFinite(destination.y) || !HomeFinite(destination.z))return false;
            object prior=null;
            if(localMotion.Actuations==0) {
                if(traversalWarmupReceipt==null || !TraversalExactPose(position,traversalWarmupPose))return false;
            }else {
                if(!localMotion.Arrived || traversalLastAcceptedWitness==null || (float)traversalLastAcceptedWitness["Speed"]!=0 || !TraversalExactZero(traversalLastWitnessNativeVelocity))return false;
                var actual=(float[])traversalLastAcceptedWitness["Actual"];
                if(!TraversalExactPose(position,new Vector3(actual[0],actual[1],actual[2])))return false;
                prior=new {Command=traversalLastAcceptedWitness["Command"],Stage=traversalLastAcceptedWitness["Stage"],Time=traversalLastAcceptedWitness["Time"],
                    Clock=traversalLastAcceptedWitness["Clock"],Actual=actual,Speed=traversalLastAcceptedWitness["Speed"],NativeVelocity=Point(traversalLastWitnessNativeVelocity)};
            }
            var w=new TraversalDestinationWindow {Id=traversalDestinations.Count+1,Stage=stage,Goal=destination,Position=position,
                Start=Time.realtimeSinceStartupAsDouble,GlobalDeadline=deadline,Maximum=localMotion.NativeMaximumDeltaTime,BaseActuations=localMotion.Actuations,BodyKey=traversalWarmupBodyKey};
            if(w.Start>w.GlobalDeadline)return false;
            w.Contract=new {Start=w.Start,Position=Point(position),Body=body,NativeMaximumDelta=w.Maximum,MaxSeconds=20,MinWindowSeconds=2,MaxSamples=512,
                NativeReadinessPolicy="NATIVE_NEW_GOAL_READINESS_V1",ClockPolicy=RustBots.Navigation.ObstacleTraversal.ClockPolicy,
                GlobalDeadline=w.GlobalDeadline,Goal=Point(destination),Stage=stage,BaseActuations=w.BaseActuations,IssuedCommands=traversalIssuedCommands,AcceptedWitnesses=traversalAcceptedWitnesses,
                MotorActive=localMotion.Active,MotorBlocked=localMotion.Blocked,MotorArrived=localMotion.Arrived,Velocity=Point(velocity),PriorRest=prior};
            traversalDestinations.Add(w);traversalDestination=w;return true;
        }
        private static bool TraversalExactZero(Vector3 value) {return value.x==0 && value.y==0 && value.z==0;}
        private static bool TraversalExactPose(Vector3 a,Vector3 b) {return a.x==b.x && a.y==b.y && a.z==b.z;}
        private void TraversalBegin() {
            traversalPhase="WARMUP";traversalWarmupStart=Time.realtimeSinceStartupAsDouble;
            traversalWarmupPose=npc.transform.position;
            var body=TraversalWarmupBody();traversalWarmupBodyKey=JsonConvert.SerializeObject(body);traversalWarmupMaximum=localMotion.NativeMaximumDeltaTime;
            traversalWarmupContract=new {Start=traversalWarmupStart,Position=Point(traversalWarmupPose),Body=body,NativeMaximumDelta=traversalWarmupMaximum,
                MaxSeconds=20,MinWindowSeconds=2,MaxSamples=512,ClockPolicy=RustBots.Navigation.ObstacleTraversal.ClockPolicy};
        }
        private object TraversalWarmupBody() {
            var body=npc.GetComponent<Rigidbody>();
            return new {Actor=Id(npc),Capsules=npc.GetComponents<CapsuleCollider>().Select(c=>new {Instance=c.GetInstanceID(),Radius=c.radius,Height=c.height,Center=Point(c.center),
                Direction=c.direction,Scale=Point(c.transform.lossyScale),Up=Point(c.transform.up),Enabled=c.enabled,Trigger=c.isTrigger,Layer=c.gameObject.layer,Rigidbody=c.attachedRigidbody==null?0:c.attachedRigidbody.GetInstanceID()}).ToArray(),
                Rigidbody=body.GetInstanceID(),Kinematic=body.isKinematic,Gravity=body.useGravity,DetectCollisions=body.detectCollisions,CollisionMode=body.collisionDetectionMode.ToString(),
                Colliders=npc.GetComponentsInChildren<Collider>().Where(c=>c.enabled && !c.isTrigger).Select(c=>c.GetInstanceID()).OrderBy(i=>i).ToArray(),
                AgentStopped=agent.isStopped,AgentUpdatePosition=agent.updatePosition,AgentUpdateRotation=agent.updateRotation};
        }
        private string TraversalStationaryClockProblem(RustBots.Navigation.ObstacleTraversal.TraversalClock clock,double observed,double start,float maximum,
            RustBots.Navigation.ObstacleTraversal.TraversalClock? previous) {
            if(double.IsNaN(clock.WallTime) || double.IsInfinity(clock.WallTime) || double.IsNaN(clock.FixedTime) || double.IsInfinity(clock.FixedTime) ||
                double.IsNaN(clock.FixedUnscaledTime) || double.IsInfinity(clock.FixedUnscaledTime) || !HomeFinite(clock.Delta) ||
                clock.WallTime<start || clock.WallTime>observed || observed-clock.WallTime>0.1 || clock.FixedTime<0 || clock.FixedUnscaledTime<0 || clock.Sequence<=0 || clock.Frame<0 ||
                !clock.InFixedStep || clock.PhysicsMode!="FixedUpdate" || clock.TimeScale!=1 || clock.Delta<=0 || clock.Delta>0.1f ||
                clock.ClockPolicy!=RustBots.Navigation.ObstacleTraversal.ClockPolicy || !HomeFinite(clock.UnscaledDelta) || clock.UnscaledDelta<=0 || clock.UnscaledDelta>0.1f ||
                !HomeFinite(clock.MaximumDelta) || clock.MaximumDelta<clock.Delta || clock.MaximumDelta!=maximum || clock.MaximumDelta!=Time.maximumDeltaTime)return "CLOCK_ENVELOPE";
            if(previous.HasValue) {
                var before=previous.Value;double gap=clock.WallTime-before.WallTime;
                if(gap<0 || gap>1.500001 || clock.MaximumDelta!=before.MaximumDelta || clock.Sequence!=before.Sequence+1 || clock.Frame<before.Frame ||
                    clock.Delta!=before.Delta || Math.Abs(clock.FixedTime-before.FixedTime-before.Delta)>0.000001 ||
                    Math.Abs(clock.FixedUnscaledTime-before.FixedUnscaledTime-clock.UnscaledDelta)>0.000001)return "CLOCK_CONTINUITY";
            }
            return null;
        }
        private void TraversalWarmup(RustBots.Navigation.ObstacleTraversal.TraversalClock clock) {
            double observed=Time.realtimeSinceStartupAsDouble;var position=npc.transform.position;var velocity=npc.GetComponent<Rigidbody>().linearVelocity;var body=TraversalWarmupBody();
            var reasons=new List<string>();string outcome;
            bool fatal=double.IsNaN(observed) || double.IsInfinity(observed) || observed<traversalWarmupStart || observed-traversalWarmupStart>20 ||
                traversalWarmupObservations.Count>=511 || !HomeFinite(position.x) || !HomeFinite(position.y) || !HomeFinite(position.z) ||
                Vector3.Distance(position,traversalWarmupPose)>0.001f || velocity.sqrMagnitude!=0 ||
                JsonConvert.SerializeObject(body)!=traversalWarmupBodyKey || localMotion.Actuations!=0 || localMotion.Active || localMotion.Blocked;
            string clockProblem=TraversalStationaryClockProblem(clock,observed,traversalWarmupStart,traversalWarmupMaximum,traversalWarmupClock);
            bool invalid=clockProblem!=null;if(invalid)reasons.Add(clockProblem);
            else if(traversalWarmupClock.HasValue)traversalMaxGap=Math.Max(traversalMaxGap,clock.WallTime-traversalWarmupClock.Value.WallTime);
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
            Log("TRAVERSAL_WARMUP",traversalWarmupReceipt);traversalPhase="HOME_START";traversalOutdoorWait=Time.realtimeSinceStartup+30f;
        }
        private TraversalDestinationNativeReadiness TraversalReadDestinationNativeReadiness() {
            double started=Time.realtimeSinceStartupAsDouble;var nav=RustNavigation.Instance;
            bool available=nav!=null,mesh=available && nav.DefaultNavmesh!=null,built=available && nav.IsDefaultNavmeshBuilt();
            bool? pending=available?(bool?)nav.HasPendingTiles():null;bool onMesh=agent!=null && agent.isOnNavMesh;
            string reason=!available?"NATIVE_NAV_UNAVAILABLE":!mesh?"NATIVE_DEFAULT_MESH_UNAVAILABLE":!built?"NATIVE_DEFAULT_NOT_BUILT":
                pending!=false?"NATIVE_TILES_PENDING":!onMesh?"NATIVE_ACTOR_NOT_ON_NAVMESH":null;
            return new TraversalDestinationNativeReadiness {StartedWall=started,CompletedWall=Time.realtimeSinceStartupAsDouble,NavAvailable=available,
                DefaultMesh=mesh,DefaultBuilt=built,PendingTiles=pending,OnNavmesh=onMesh,Ready=reason==null,Reason=reason};
        }
        private void TraversalDestinationObserve(RustBots.Navigation.ObstacleTraversal.TraversalClock clock) {
            var w=traversalDestination;double observed=Time.realtimeSinceStartupAsDouble;var position=npc.transform.position;
            var velocity=npc.GetComponent<Rigidbody>().linearVelocity;var body=TraversalWarmupBody();var readiness=TraversalReadDestinationNativeReadiness();
            observed=Time.realtimeSinceStartupAsDouble;var reasons=new List<string>();string outcome;
            bool fatal=double.IsNaN(observed) || double.IsInfinity(observed) || observed<w.Start || observed-w.Start>20 || observed>w.GlobalDeadline || w.Observations.Count>=511 ||
                !TraversalExactPose(position,w.Position) || !TraversalExactZero(velocity) || JsonConvert.SerializeObject(body)!=w.BodyKey ||
                localMotion.Active || localMotion.Blocked || localMotion.Actuations!=w.BaseActuations || traversalIssuedCommands!=w.BaseActuations || traversalAcceptedWitnesses!=w.BaseActuations;
            string problem=TraversalStationaryClockProblem(clock,observed,w.Start,w.Maximum,w.Previous);
            if(fatal){outcome="FATAL";reasons.Add("DESTINATION_BODY_MOTOR_OR_TOTAL_BOUND");}
            else if(problem!=null || !readiness.Ready) {
                outcome="WAIT";if(problem!=null)reasons.Add(problem);if(!readiness.Ready)reasons.Add(readiness.Reason);if(w.Previous.HasValue)w.Restarts++;
                w.Previous=null;w.First=null;w.Samples=0;w.MaxGap=0;
            }else {
                outcome=w.Previous.HasValue?"WINDOW_ADVANCE":"WINDOW_START";
                if(w.Previous.HasValue)w.MaxGap=Math.Max(w.MaxGap,clock.WallTime-w.Previous.Value.WallTime);
                if(!w.First.HasValue){w.First=clock;w.StableSince=clock.WallTime;}w.Previous=clock;w.Samples++;
                var first=w.First.Value;
                if(clock.WallTime-first.WallTime>=2 && clock.FixedTime-first.FixedTime>=2 && clock.FixedUnscaledTime-first.FixedUnscaledTime>=2)outcome="READY";
            }
            w.Observations.Add(new {Observation=w.Observations.Count+1,ObservedWall=observed,Clock=clock,LiveMaximumDelta=Time.maximumDeltaTime,Position=Point(position),Velocity=Point(velocity),Body=body,NativeReadiness=readiness,
                MotorActuations=localMotion.Actuations,MotorActive=localMotion.Active,MotorBlocked=localMotion.Blocked,Outcome=outcome,Reasons=reasons.ToArray()});
            if(fatal){w.Outcome="FATAL";w.EndWall=observed;w.Reason="DESTINATION_BODY_MOTOR_OR_TOTAL_BOUND";traversalDestination=null;TraversalStopScene("Destination stationary qualification violated body/motor/deadline");return;}
            if(outcome!="READY")return;
            w.Receipt=new {Schema=2,Mode="STATIONARY_READ_ONLY",Start=w.Start,End=clock.WallTime,StableSince=w.StableSince,Samples=w.Samples,TotalObservations=w.Observations.Count,
                Resets=0,MotorResets=0,WindowRestarts=w.Restarts,MaxWallGap=w.MaxGap,Position=Point(w.Position),LastClock=clock};
            double commitStart=Time.realtimeSinceStartupAsDouble;w.SetDestinationCalls++;
            bool accepted=localMotion.SetDestination(w.Goal,w.Stage,w.GlobalDeadline);double commitEnd=Time.realtimeSinceStartupAsDouble;
            w.Commit=new {StartedWall=commitStart,CompletedWall=commitEnd,Accepted=accepted};
            var handoff=RustBots.Navigation.TraversalDriver.ReadNativeClock(clock.Sequence);
            position=npc.transform.position;velocity=npc.GetComponent<Rigidbody>().linearVelocity;body=TraversalWarmupBody();
            bool valid=accepted && handoff.WallTime>=commitEnd && handoff.WallTime<=w.Start+20 && handoff.WallTime<=w.GlobalDeadline && handoff.WallTime-clock.WallTime<=0.1 && handoff.Sequence==clock.Sequence && handoff.Frame==clock.Frame &&
                handoff.ClockPolicy==clock.ClockPolicy && handoff.FixedTime==clock.FixedTime && handoff.FixedUnscaledTime==clock.FixedUnscaledTime && handoff.Delta==clock.Delta && handoff.UnscaledDelta==clock.UnscaledDelta &&
                handoff.TimeScale==clock.TimeScale && handoff.MaximumDelta==clock.MaximumDelta && handoff.InFixedStep==clock.InFixedStep && handoff.PhysicsMode==clock.PhysicsMode &&
                TraversalStationaryClockProblem(handoff,Time.realtimeSinceStartupAsDouble,w.Start,w.Maximum,null)==null &&
                TraversalExactPose(position,w.Position) && TraversalExactZero(velocity) && JsonConvert.SerializeObject(body)==w.BodyKey && localMotion.Actuations==w.BaseActuations;
            var receipt=new TraversalDestinationHandoff {Accepted=valid,ReadyClock=clock,Clock=handoff,Position=Point(position),Velocity=Point(velocity),Body=body,MotorActuations=localMotion.Actuations};
            w.Handoff=receipt;
            traversalDestination=null;
            // All allocating body/receipt work is complete before this final read.
            // Keep the original READY callback horizon; never refresh its clocks.
            receipt.CheckedWall=Time.realtimeSinceStartupAsDouble;
            if(!valid || receipt.CheckedWall<clock.WallTime || receipt.CheckedWall-clock.WallTime>0.1 || receipt.CheckedWall>w.Start+20 || receipt.CheckedWall>w.GlobalDeadline) {
                receipt.Accepted=false;w.EndWall=receipt.CheckedWall;w.Outcome="REJECTED";w.Reason="DESTINATION_HANDOFF_REFUSED";
                localMotion.Stop("DESTINATION_HANDOFF_REFUSED");TraversalStopScene("Destination qualification could not admit a fresh native route or unchanged clock");return;
            }
            localMotion.Tick(handoff);
            double completed=Time.realtimeSinceStartupAsDouble;
            receipt.TickCompletedWall=completed;w.EndWall=completed;
            receipt.MotorActuations=localMotion.Actuations;
            bool actuated=receipt.MotorActuations!=w.BaseActuations;
            bool overrun=completed<receipt.CheckedWall || completed-clock.WallTime>0.1 || completed>w.Start+20 || completed>w.GlobalDeadline;
            if(overrun || actuated || localMotion.Blocked) {
                receipt.Accepted=false;w.Outcome="MOTOR_REFUSED";w.Reason=actuated?"DESTINATION_BASELINE_ACTUATED":overrun?"DESTINATION_BASELINE_OVERRUN":localMotion.Reason;
                localMotion.Stop(w.Reason);TraversalStopScene(w.Reason);return;
            }
            w.Outcome="ADMITTED"; // Baseline only: no writer or actuation is permitted in this Tick.
            progressTime=(float)completed; // Start the active-progress watchdog; original route/global deadlines stay unchanged.
        }
        private void TraversalDestinationWatchdog() {
            var w=traversalDestination;double observed=Time.realtimeSinceStartupAsDouble;
            if(w==null || observed-w.Start<=20 && observed<=w.GlobalDeadline)return;
            if(w.Observations.Count<512)w.Observations.Add(new {Observation=w.Observations.Count+1,ObservedWall=observed,
                Clock=(RustBots.Navigation.ObstacleTraversal.TraversalClock?)null,LiveMaximumDelta=Time.maximumDeltaTime,Position=Point(npc.transform.position),
                Velocity=Point(npc.GetComponent<Rigidbody>().linearVelocity),Body=TraversalWarmupBody(),MotorActuations=localMotion.Actuations,MotorActive=localMotion.Active,
                MotorBlocked=localMotion.Blocked,Outcome="FATAL",Reasons=new[] {"DESTINATION_CALLBACK_DEADLINE"}});
            w.Outcome="FATAL";w.EndWall=observed;w.Reason="DESTINATION_CALLBACK_DEADLINE";traversalDestination=null;TraversalStopScene("Destination qualification callback/global deadline expired");
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
            if(localMotion!=null)localMotion.PollStationaryReplanTimeout();
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
            if(traversalDestination!=null){TraversalIdleSample();TraversalDestinationWatchdog();return true;}
            if(traversalPhase=="HOME_START"){TraversalIdleSample();traversalPhase="HOME";StartCraft();return true;}
            if(traversalPhase=="FIXTURE_WAIT") {
                TraversalIdleSample();
                if(RustNavigation.Instance.HasPendingTiles()){if(Time.realtimeSinceStartup>homeWait)TraversalStopScene("Fixture native tiles pending timeout");return true;}
                if(Time.realtimeSinceStartup<traversalFixtureReadyAt)return true;
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
            if(traversalBuildStage!=null && TraversalBuildContinue(now))return true;
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
                traversalPhase="HOME";homePhase="BUILD_WAIT";homeWait=now;homeTilesDeadline=now+30;homeTilesPending=false;return true;
            }
            if(traversalPhase=="FIXTURE_FULL_HOME_RETURN") {traversalPhase="HOME";homePhase="NAV_WAIT";homeWait=now+30;return true;}
            if(traversalPhase=="OUTDOOR_DETOUR") {
                if(traversalDetourVia.HasValue) {
                    traversalDetourVia=null;
                    if(!IssueTraversal(traversalDetourGoal,"OUTDOOR_DETOUR"))TraversalStopScene(localMotion.Reason);
                    return true;
                }
                if(Vector3.Distance(npc.transform.position,traversalSceneStart)<=2 || traversalOutdoorDoor==null || traversalOutdoorDoor.IsOpen())
                {TraversalStopScene("Closed-door detour lacks physical distance/unchanged door");return true;}
                TraversalSceneEnd("PASSED","Observed supported exterior detour around paid native wall");
                traversalG4Complete=true;
                TraversalFixtureTransition("G4_COMPLETE_RESUME_HOME","TC");
                traversalPhase="HOME";homePhase="BUILD_WAIT";homeWait=now;homeTilesDeadline=now+30;homeTilesPending=false;return true;
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
        private Bounds TraversalBuildBounds() {
            var bounds=homeDefinitions["FOUNDATION"].bounds;
            bounds.Expand(new Vector3(1+Physics.defaultContactOffset*4,0,1+Physics.defaultContactOffset*4));return bounds;
        }
        private static bool TraversalBuildExteriorSegment(Vector3 from,Vector3 to,Vector3 position,Quaternion rotation,Bounds bounds) {
            var inverse=new Quaternion(-rotation.x,-rotation.y,-rotation.z,rotation.w);
            var a=inverse*(from-position);var b=inverse*(to-position);
            return a.x<=bounds.min.x && b.x<=bounds.min.x || a.x>=bounds.max.x && b.x>=bounds.max.x ||
                a.z<=bounds.min.z && b.z<=bounds.min.z || a.z>=bounds.max.z && b.z>=bounds.max.z;
        }
        private bool TraversalBuildOutside(Vector3 point) {
            var f=homeEntities["FOUNDATION"].transform;
            return TraversalBuildExteriorSegment(point,point,f.position,f.rotation,TraversalBuildBounds());
        }
        private bool TraversalBuildSample(Vector3 input,out Vector3 foot,Dictionary<string,object> diagnostic=null) {
            NavHit hit;foot=Vector3.zero;
            bool sampled=RustNavigation.Instance.DefaultNavmesh.SamplePosition(new NavVector3(input),out hit,new Vector3(0.25f,0.5f,0.25f),false);
            if(diagnostic!=null){diagnostic["Sampled"]=sampled;diagnostic["NavPoint"]=sampled?Point(hit.position.Value):null;diagnostic["Reason"]="NAV_SAMPLE";diagnostic["Queries"]=1;}
            if(!sampled)return false;
            var p=hit.position.Value;
            var hits=Physics.RaycastAll(p+Vector3.up*2,Vector3.down,4,-1,QueryTriggerInteraction.Ignore);
            var floors=hits.Where(h=>h.collider.GetComponentInParent<BaseEntity>()!=npc && h.collider is TerrainCollider && h.normal.y>=0.85f && Mathf.Abs(h.point.y-p.y)<=0.25f).OrderBy(h=>h.distance).ToArray();
            if(diagnostic!=null){diagnostic["RayHits"]=hits.Select(h=>new {Collider=HomeCollider(h.collider),Point=Point(h.point),Normal=Point(h.normal),Distance=h.distance}).ToArray();
                diagnostic["RayOrigin"]=Point(p+Vector3.up*2);diagnostic["Queries"]=2;diagnostic["Reason"]="TERRAIN_SUPPORT";}
            if(floors.Length==0)return false;foot=floors[0].point+Vector3.up*0.05f;
            var c=npc.GetComponent<CapsuleCollider>();var center=foot+c.center;float half=c.height*0.5f-c.radius;
            float water=WaterLevel.GetWaterSurface(foot,true,true,null)-foot.y;
            if(diagnostic!=null){diagnostic["Foot"]=Point(foot);diagnostic["Support"]=new {Collider=HomeCollider(floors[0].collider),Point=Point(floors[0].point),Normal=Point(floors[0].normal),Distance=floors[0].distance};
                diagnostic["A"]=Point(center-Vector3.up*half);diagnostic["B"]=Point(center+Vector3.up*half);diagnostic["Radius"]=c.radius;diagnostic["Height"]=c.height;diagnostic["WaterDepth"]=water;diagnostic["Reason"]="WATER";}
            if(!(water<=0.15f))return false;
            var overlaps=Physics.OverlapCapsule(center-Vector3.up*half,center+Vector3.up*half,c.radius,-1,QueryTriggerInteraction.Ignore);
            bool clear=!overlaps.Any(x=>x.GetComponentInParent<BaseEntity>()!=npc);
            if(diagnostic!=null){diagnostic["OverlapHits"]=overlaps.Select(HomeCollider).ToArray();diagnostic["OverlapClear"]=clear;diagnostic["Queries"]=3;diagnostic["Reason"]=clear?"ACCEPTED":"CAPSULE_OVERLAP";}
            return clear;
        }
        private bool TraversalBuildNativeLeg(Vector3 from,Vector3 to,Vector3 position,Quaternion rotation,Bounds bounds,out RustNavMeshPath path) {
            path=new RustNavMeshPath();
            if(!TraversalBuildExteriorSegment(from,from,position,rotation,bounds) || !TraversalBuildExteriorSegment(to,to,position,rotation,bounds) ||
                !agent.CalculatePath(new NavVector3(from),new NavVector3(to),path) || path.status!=NavMeshPathStatus.PathComplete || path.corners.Count<2 || path.corners.Count>=256)return false;
            var points=path.corners.Select(c=>c.Value).ToArray();
            return Vector3.Distance(points[0],from)<=0.5f && Vector3.Distance(points[points.Length-1],to)<=0.5f && path.GetPathLength()<=24 &&
                TraversalBuildExteriorSegment(from,points[0],position,rotation,bounds) && TraversalBuildExteriorSegment(points[points.Length-1],to,position,rotation,bounds) &&
                Enumerable.Range(1,points.Length-1).All(i=>TraversalBuildExteriorSegment(points[i-1],points[i],position,rotation,bounds));
        }
        private bool TraversalBuildPlan(Vector3 from,Vector3 goal,Vector3 position,Quaternion rotation,bool predicted,string label,out Vector3[] waypoints) {
            waypoints=new Vector3[0];var nav=RustNavigation.Instance;var mesh=nav.DefaultNavmesh;var bounds=TraversalBuildBounds();
            if(nav.HasPendingTiles() || !agent.isOnNavMesh)return false;
            int change=mesh.TileChangeVersion,data=mesh.TileDataVersion;double start=Time.realtimeSinceStartupAsDouble;
            var nodes=new Vector3[6];var valid=new bool[6];nodes[0]=from;nodes[1]=goal;valid[0]=valid[1]=true;
            for(int i=0;i<4;i++) {
                var local=new Vector3(i<2?bounds.min.x-0.6f:bounds.max.x+0.6f,0,i==0 || i==3?bounds.min.z-0.6f:bounds.max.z+0.6f);
                var input=position+rotation*local;input.y=TerrainMeta.HeightMap.GetHeight(input);
                valid[i+2]=TraversalBuildSample(input,out nodes[i+2]);
            }
            var candidates=new List<int[]> {new[] {0,1}};
            for(int i=2;i<6;i++) {
                candidates.Add(new[] {0,i,1});
                for(int j=2;j<6;j++)if(Math.Abs(i-j)==1 || Math.Abs(i-j)==3)candidates.Add(new[] {0,i,j,1});
            }
            var paths=new RustNavMeshPath[6,6];var checkedEdges=new bool[6,6];int[] best=null;float bestLength=float.PositiveInfinity;int queries=0;
            foreach(var candidate in candidates) {
                bool clear=true;float length=0;
                for(int j=1;j<candidate.Length;j++) {
                    int a=candidate[j-1],b=candidate[j];if(!valid[a] || !valid[b]){clear=false;break;}
                    if(!checkedEdges[a,b]) {
                        if(++queries>17 || Time.realtimeSinceStartupAsDouble-start>0.5)return false;
                        checkedEdges[a,b]=true;RustNavMeshPath path;
                        if(TraversalBuildNativeLeg(nodes[a],nodes[b],position,rotation,bounds,out path))paths[a,b]=path;
                    }
                    if(paths[a,b]==null){clear=false;break;}length+=paths[a,b].GetPathLength();
                }
                if(clear && length<bestLength && length<=24){best=candidate;bestLength=length;if(candidate.Length==2)break;}
            }
            bool accepted=best!=null && Time.realtimeSinceStartupAsDouble-start<=0.5 && nav.DefaultNavmesh==mesh && mesh.TileChangeVersion==change && mesh.TileDataVersion==data && !nav.HasPendingTiles();
            var legs=new List<object>();
            if(accepted) {
                waypoints=best.Skip(1).Select(i=>nodes[i]).ToArray();
                for(int i=1;i<best.Length;i++){var path=paths[best[i-1],best[i]];legs.Add(new {From=Point(nodes[best[i-1]]),To=Point(nodes[best[i]]),Status=path.status.ToString(),Length=path.GetPathLength(),Corners=path.corners.Select(c=>Point(c.Value)).ToArray()});}
            }
            var receipt=new {Kind="EXTERIOR_BUILD_PLAN_V1",Label=label,PredictedGeometry=predicted,ActualGeometry=!predicted,Accepted=accepted,Step=homeStep,
                FoundationPosition=Point(position),FoundationRotation=new[] {rotation.x,rotation.y,rotation.z,rotation.w},NativeFoundationBounds=new {Center=Point(homeDefinitions["FOUNDATION"].bounds.center),Size=Point(homeDefinitions["FOUNDATION"].bounds.size)},
                Radius=0.5f,Skin=Physics.defaultContactOffset*2,ExteriorMin=Point(bounds.min),ExteriorMax=Point(bounds.max),From=Point(from),Goal=Point(goal),
                MaxLegs=MAX_BUILD_LEGS,Waypoints=waypoints.Select(Point).ToArray(),Legs=legs,Length=accepted?bestLength:0,Queries=queries,Change=change,Data=data,Time=Time.realtimeSinceStartupAsDouble,Milliseconds=(Time.realtimeSinceStartupAsDouble-start)*1000};
            traversalBuildPlans.Add(receipt);Log("TRAVERSAL_BUILD_PLAN",receipt);return accepted;
        }
        private void TraversalBuildPreflight() {
            double started=Time.realtimeSinceStartupAsDouble;
            traversalFoundationAdmission=new Dictionary<string,object> {
                {"Policy","ACTUAL_FOUNDATION_READMISSION_V1"},{"Accepted",false},{"PrepayAccepted",false},{"PreflightAccepted",false},{"ReadmissionAccepted",false},{"MeasuredRest",false},
                {"StartedWall",started},{"GateTime",null},{"Reason",null},{"BeforeSite",homeSiteReceipt},{"AcceptedSite",null},{"PlannedHint",Point(homeOutside)},
                {"ActualPosition",Point(npc.transform.position)},{"NativeVelocity",Point(npc.GetComponent<Rigidbody>().linearVelocity)},{"Body",TraversalWarmupBody()},
                {"LastRestCommand",traversalLastAcceptedWitness==null?null:traversalLastAcceptedWitness["Command"]},
                {"LastRestClock",traversalLastAcceptedWitness==null?null:traversalLastAcceptedWitness["Clock"]},
                {"LastRestSupport",traversalLastAcceptedWitness==null?null:traversalLastAcceptedWitness["Support"]},
                {"GraphFrom",traversalBuildPlans.Count},{"GraphTo",traversalBuildPlans.Count},
                {"Clock",new {WallTime=started,FixedTime=Time.fixedTimeAsDouble,FixedUnscaledTime=Time.fixedUnscaledTimeAsDouble,Delta=Time.fixedDeltaTime,
                    UnscaledDelta=Time.fixedUnscaledDeltaTime,TimeScale=Time.timeScale,MaximumDelta=Time.maximumDeltaTime,InFixedStep=Time.inFixedTimeStep,PhysicsMode=Physics.simulationMode.ToString(),Frame=Time.frameCount}} };
            TraversalRequireFoundationRest();traversalFoundationAdmission["MeasuredRest"]=true;
            Construction.Placement before;bool beforeAccepted=HomeFoundationPreview(homeSite,npc.transform.position,out before,true);
            traversalFoundationAdmission["BeforePreview"]=homeFoundationPreview;
            traversalFoundationAdmission["BeforePositionDelta"]=beforeAccepted?(object)Vector3.Distance(before.position,homeSite):null;
            traversalFoundationAdmission["BeforeRotationDelta"]=beforeAccepted?(object)Quaternion.Angle(before.rotation,homeRotation):null;
            bool foreignUnchanged=homeForeign==ForeignHomeKey();traversalFoundationAdmission["ForeignUnchanged"]=foreignUnchanged;
            if(!foreignUnchanged)throw new InvalidOperationException("Foreign native structures changed before actual foundation admission");
            homeForeignStructures=BaseNetworkable.serverEntities.OfType<DecayEntity>().Where(HomeStructural).ToArray();
            bool readmitted=HomeCheckSite(homeSite,homeRotation,true);
            traversalFoundationAdmission["ReadmissionAccepted"]=readmitted;traversalFoundationAdmission["ActualStand"]=homeActualStandGate;
            if(!readmitted)throw new InvalidOperationException("Actual foundation site readmission rejected: "+homeAdmissionReason);
            traversalFoundationAdmission["AcceptedSite"]=homeSiteReceipt;
            var preview=TraversalFoundationPreviewCheck();
            var prior=npc.transform.position;var stands=new Dictionary<string,Vector3>();
            string[] roles={"WALL_N","WALL_E","WALL_W","DOORWAY"};int[] suffix={3,4,2,1};
            for(int i=0;i<roles.Length;i++) {
                var socket=PrefabAttribute.server.FindAll<Socket_Base>(homeDefinitions["FOUNDATION"].prefabID)
                    .Single(x=>x.female && !x.femaleDummy && !x.femaleNoStability && x.socketName.EndsWith("/wall-female/"+suffix[i],StringComparison.Ordinal));
                var place=preview.position+preview.rotation*socket.position;var outward=place-preview.position;outward.y=0;outward.Normalize();
                var input=place+outward*1.25f;input.y=TerrainMeta.HeightMap.GetHeight(input);Vector3 stand;
                if(!TraversalBuildSample(input,out stand))
                    throw new InvalidOperationException("Predicted exterior build graph unavailable before foundation: "+roles[i]);
                stands.Add(roles[i],stand);
            }
            var tcInput=preview.position+preview.rotation*new Vector3(homeDefinitions["FOUNDATION"].bounds.max.x+1.25f,0,0.6f);
            tcInput.y=TerrainMeta.HeightMap.GetHeight(tcInput);Vector3 tcStand;
            if(!TraversalBuildSample(tcInput,out tcStand))throw new InvalidOperationException("Predicted open-side TC stand unavailable before foundation");
            stands.Add("TC",tcStand);stands.Add("DOOR",stands["DOORWAY"]);stands.Add("ROOF",stands["WALL_N"]);
            // Future roof/TC/Door native placement remains a fresh actual-parent gate.
            foreach(var role in new[] {"WALL_N","DOORWAY","DOOR","TC","WALL_E","WALL_W","ROOF"}) {
                var stand=stands[role];Vector3[] points;
                if(Vector3.Distance(prior,stand)>0.12f && !TraversalBuildPlan(prior,stand,preview.position,preview.rotation,true,"PREDICTED_"+role,out points))
                    throw new InvalidOperationException("Predicted exterior build graph unavailable before foundation: "+role);
                prior=stand;
            }
            traversalFoundationAdmission["GraphTo"]=traversalBuildPlans.Count;
            TraversalRequireFoundationRest();
            if(Time.realtimeSinceStartupAsDouble-started>0.5)throw new InvalidOperationException("Actual foundation readmission/graph budget exceeded before payment");
            traversalFoundationAdmission["PreflightAccepted"]=true;
        }
        private void TraversalRequireFoundationRest() {
            if(traversalDestination!=null || localMotion.Active || localMotion.Blocked || !localMotion.Arrived || traversalLastAcceptedWitness==null ||
                (float)traversalLastAcceptedWitness["Speed"]!=0 || !TraversalExactZero(traversalLastWitnessNativeVelocity) ||
                !TraversalExactZero(npc.GetComponent<Rigidbody>().linearVelocity) || localMotion.Actuations!=traversalIssuedCommands || traversalIssuedCommands!=traversalAcceptedWitnesses ||
                JsonConvert.SerializeObject(TraversalWarmupBody())!=traversalWarmupBodyKey)throw new InvalidOperationException("Actual foundation readmission requires original observed rest/body and no pending writer");
            var actual=(float[])traversalLastAcceptedWitness["Actual"];
            if(!TraversalExactPose(npc.transform.position,new Vector3(actual[0],actual[1],actual[2])))throw new InvalidOperationException("Actual foundation stand changed after observed rest");
        }
        private Construction.Placement TraversalFoundationPreviewCheck() {
            Construction.Placement preview;bool found=HomeFoundationPreview(homeSite,npc.transform.position,out preview,true);
            float positionDelta=found?Vector3.Distance(preview.position,homeSite):float.PositiveInfinity;
            float rotationDelta=found?Quaternion.Angle(preview.rotation,homeRotation):float.PositiveInfinity;
            bool positionMatched=found && positionDelta<=0.05f,rotationMatched=found && rotationDelta<=0.05f;
            traversalFoundationAdmission["Preview"]=homeFoundationPreview;traversalFoundationAdmission["PreviewAccepted"]=found;
            traversalFoundationAdmission["PositionDelta"]=found?(object)positionDelta:null;traversalFoundationAdmission["RotationDelta"]=found?(object)rotationDelta:null;
            traversalFoundationAdmission["PositionMatched"]=positionMatched;traversalFoundationAdmission["RotationMatched"]=rotationMatched;
            if(!found || !positionMatched || !rotationMatched)throw new InvalidOperationException("Actual foundation preview differs from freshly admitted native site");
            return preview;
        }
        private void TraversalFoundationPaymentGuard(Construction.Target target) {
            if(traversalFoundationAdmission==null || !(bool)traversalFoundationAdmission["PreflightAccepted"])throw new InvalidOperationException("Foundation has no complete actual site/graph admission");
            TraversalRequireFoundationRest();TraversalFoundationPreviewCheck();
            var eye=npc.eyes.position;var ray=new Ray(eye,(homeSite-eye).normalized);
            bool rayMatched=TraversalExactPose(target.position,homeSite) && TraversalExactPose(eye,homeFoundationPreviewEyes) &&
                TraversalExactPose(target.ray.origin,homeFoundationPreviewRayOrigin) && TraversalExactPose(target.ray.direction,homeFoundationPreviewRayDirection) &&
                TraversalExactPose(target.ray.origin,ray.origin) && TraversalExactPose(target.ray.direction,ray.direction);
            traversalFoundationAdmission["PaymentEyes"]=Point(eye);traversalFoundationAdmission["PaymentTarget"]=Point(target.position);
            traversalFoundationAdmission["PaymentRayOrigin"]=Point(target.ray.origin);traversalFoundationAdmission["PaymentRayDirection"]=Point(target.ray.direction);
            traversalFoundationAdmission["PaymentRayMatched"]=rayMatched;
            if(!rayMatched)throw new InvalidOperationException("Actual foundation planner ray changed after admission");
            var nav=RustNavigation.Instance;bool navigationReady=nav!=null && nav.DefaultNavmesh!=null && nav.IsDefaultNavmeshBuilt() && !nav.HasPendingTiles() && agent.isOnNavMesh;
            traversalFoundationAdmission["NavigationReady"]=navigationReady;
            if(!navigationReady)throw new InvalidOperationException("Native foundation build readiness changed before payment");
            object traffic;
            bool trafficClear=RustBots.Navigation.ObstacleTraversal.ObserveTraffic(homeSite,homeSite,5,npc,0,out traffic);
            traversalFoundationAdmission["DynamicSite"]=traffic;
            if(!trafficClear)throw new InvalidOperationException("Foundation dynamic occupancy changed before payment");
            TraversalRequireFoundationRest();double gate=Time.realtimeSinceStartupAsDouble;traversalFoundationAdmission["GateTime"]=gate;
            if(gate-(double)traversalFoundationAdmission["StartedWall"]>0.5)throw new InvalidOperationException("Foundation prepay admission budget exceeded");
            traversalFoundationAdmission["PrepayAccepted"]=true;traversalFoundationAdmission["Accepted"]=true;Log("TRAVERSAL_FOUNDATION_ADMISSION",traversalFoundationAdmission);
        }
        private void TraversalFoundationAdmissionFailed(string reason) {
            if(traversalFoundationAdmission==null)return;
            traversalFoundationAdmission["Accepted"]=false;traversalFoundationAdmission["Reason"]=reason;
            traversalFoundationAdmission["FailureTime"]=Time.realtimeSinceStartupAsDouble;traversalFoundationAdmission["GraphTo"]=traversalBuildPlans.Count;
            Log("TRAVERSAL_FOUNDATION_ADMISSION",traversalFoundationAdmission);
        }
        private void TraversalBuildMove(Vector3 goal,string stage) {
            if(traversalBuildStage!=null || traversalBuildWaypoints.Count!=0)throw new InvalidOperationException("Previous exterior build route is incomplete");
            var f=homeEntities["FOUNDATION"].transform;Vector3[] waypoints;
            if(!TraversalBuildPlan(npc.transform.position,goal,f.position,f.rotation,false,stage,out waypoints) || waypoints.Length==0 || waypoints.Length>MAX_BUILD_LEGS)
                throw new InvalidOperationException("No native supported exterior build route: "+stage);
            foreach(var waypoint in waypoints)traversalBuildWaypoints.Enqueue(waypoint);
            traversalBuildStage=stage;traversalBuildLeg=0;traversalBuildFoundation=f.position;traversalBuildRotation=f.rotation;TraversalBuildIssue();
        }
        private void TraversalBuildIssue() {
            var f=homeEntities["FOUNDATION"].transform;var goal=traversalBuildWaypoints.Peek();RustNavMeshPath path;
            if(++traversalBuildLeg>MAX_BUILD_LEGS || !localMotion.Arrived || RustNavigation.Instance.HasPendingTiles() ||
                f.position!=traversalBuildFoundation || Quaternion.Angle(f.rotation,traversalBuildRotation)>0.001f ||
                !TraversalBuildNativeLeg(npc.transform.position,goal,f.position,f.rotation,TraversalBuildBounds(),out path))
                throw new InvalidOperationException("Exterior build leg lost actual rest/native geometry/path");
            traversalBuildWaypoints.Dequeue();HomeMoveLeg(goal,traversalBuildStage+"_EXTERIOR_"+traversalBuildLeg);
        }
        private bool TraversalBuildContinue(float now) {
            if(traversalDestination!=null)return false;
            if(traversalBuildStage==null)return false;
            if(!localMotion.Arrived || localMotion.Active || localMotion.Blocked || npc.GetComponent<Rigidbody>().linearVelocity.sqrMagnitude!=0)
                throw new InvalidOperationException("Exterior waypoint lacks actual supported rest");
            var rest=new {Stage=traversalBuildStage,Leg=traversalBuildLeg,Remaining=traversalBuildWaypoints.Count,Position=Point(npc.transform.position),
                NativeVelocity=Point(npc.GetComponent<Rigidbody>().linearVelocity),Actuations=localMotion.Actuations,Arrived=localMotion.Arrived,Active=localMotion.Active,Blocked=localMotion.Blocked,Time=now};
            traversalBuildRests.Add(rest);Log("TRAVERSAL_BUILD_REST",rest);
            if(traversalBuildWaypoints.Count!=0){TraversalBuildIssue();return true;}
            traversalBuildStage=null;navigating=false;return false;
        }
        private void TraversalFixtureMove(Vector3 destination,string phase) {
            traversalPhase=phase;
            TraversalBuildMove(destination,phase);
        }
        private bool TraversalFixtureStand(BaseEntity wall,string role,out Vector3 stand) {
            return TraversalFixtureStandAt(wall.transform.position,role,out stand);
        }
        private bool TraversalFixtureStandAt(Vector3 edge,string role,out Vector3 stand) {
            var foundation=homeEntities["FOUNDATION"];var outward=edge-foundation.transform.position;
            outward.y=0;outward.Normalize();
            // Relative native entity geometry only. Never install a fixture at fixed world coordinates.
            foreach(float offset in new[] {1.3f,1.5f,1.1f}) {
                var candidate=edge+outward*offset;candidate.y=TerrainMeta.HeightMap.GetHeight(candidate);
                if(traversalFixtureStandAttempts.Count>=9)throw new InvalidOperationException("Fixture stand query budget exhausted");
                var attempt=new Dictionary<string,object> { {"Role",role},{"Offset",offset},{"Input",Point(candidate)},{"Edge",Point(edge)},
                    {"ActorPosition",Point(npc.transform.position)},{"NativeVelocity",Point(npc.GetComponent<Rigidbody>().linearVelocity)},{"Body",TraversalWarmupBody()},
                    {"StartedWall",Time.realtimeSinceStartupAsDouble},{"SampleExtents",new[] {0.25f,0.5f,0.25f}},{"Mask",-1},{"Triggers","Ignore"},
                    {"FoundationPosition",Point(foundation.transform.position)},{"FoundationRotation",new[] {homeRotation.x,homeRotation.y,homeRotation.z,homeRotation.w}},
                    {"ExteriorMin",Point(traversalFootprint.min)},{"ExteriorMax",Point(traversalFootprint.max)} };
                bool sampled=TraversalBuildSample(candidate,out stand,attempt);bool outside=sampled && TraversalOutside(stand);
                attempt["SampleAccepted"]=sampled;attempt["Outside"]=sampled?(object)outside:null;attempt["Accepted"]=outside;
                if(sampled && !outside)attempt["Reason"]="FOUNDATION_EXTERIOR";
                attempt["CompletedWall"]=Time.realtimeSinceStartupAsDouble;traversalFixtureStandAttempts.Add(attempt);Log("TRAVERSAL_FIXTURE_STAND",attempt);
                if(outside)return true;
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
            TraversalRequireMinimalFixture();traversalOutdoorDoor=(Door)homeEntities["DOOR"];
            traversalWall=(BuildingBlock)homeEntities["WALL_N"];
            var nativeBounds=homeDefinitions["FOUNDATION"].bounds;traversalFootprint=nativeBounds;
            traversalFootprint.Expand(new Vector3(1+Physics.defaultContactOffset*4,0,1+Physics.defaultContactOffset*4));
            var east=HomeSocket(homeEntities["FOUNDATION"],"/wall-female/4");
            if(traversalOutdoorDoor.IsOpen() || !TraversalFixtureStand(traversalWall,"WALL_N",out traversalWallStand) ||
                !TraversalFixtureStandAt(homeEntities["FOUNDATION"].transform.TransformPoint(east.position),"DETOUR",out traversalDetourGoal) ||
                !TraversalFixtureStand(homeEntities["DOORWAY"],"DOORWAY",out traversalDoorStand)) {
                TraversalStopScene("Paid native fixture exists; no supported bounded exterior stands");return;
            }
            traversalFixture=new {Source="OWNED_NATIVE_TEST_FIXTURE",DiagnosticOnly=true,Stage="PAID_MINIMAL_G4",Structure=DescribeHome(),
                Wall=Id(traversalWall),Door=Id(traversalOutdoorDoor),Foundation=Id(homeEntities["FOUNDATION"]),
                WallStand=Point(traversalWallStand),DoorStand=Point(traversalDoorStand),DetourGoal=Point(traversalDetourGoal),
                FoundationPosition=Point(homeEntities["FOUNDATION"].transform.position),FoundationRotation=new[] {homeRotation.x,homeRotation.y,homeRotation.z,homeRotation.w},
                NativeFoundationBounds=new {Center=Point(nativeBounds.center),Size=Point(nativeBounds.size)},
                Radius=0.5f,Skin=Physics.defaultContactOffset*2,
                ExteriorMin=Point(traversalFootprint.min),ExteriorMax=Point(traversalFootprint.max),
                FoundationColliders=homeEntities["FOUNDATION"].GetComponentsInChildren<Collider>(true).Select(HomeCollider).ToArray(),Time=Time.realtimeSinceStartup};
            TraversalFixtureTransition("PAID_MINIMAL_READY","TC");
            Log("TRAVERSAL_NATIVE_FIXTURE",traversalFixture);TraversalFixtureMove(traversalWallStand,"FIXTURE_WALL");
        }
        private void TraversalRequireMinimalFixture() {
            var required=new[] {"DOOR","DOORWAY","FOUNDATION","WALL_N"};
            if(homeEntities.Count!=4 || homeEntities.Values.Distinct().Count()!=4 || !homeEntities.Keys.OrderBy(x=>x,StringComparer.Ordinal).SequenceEqual(required) || homeEntities.Values.Any(x=>x==null || x.IsDestroyed))
                throw new InvalidOperationException("Minimal G4 native fixture roles missing");
            var rows=DescribeHome();
            if(!rows.ForeignUnchanged || rows.Entities.Any(x=>x.Owner!=rows.Owner || x.BuildingId!=rows.BuildingId || !x.Registered || !x.Saving || !x.Support || x.Health<=0 || x.Type=="BuildingBlock" && (x.Grade!="Wood" || x.Links==0)) ||
                ((Door)homeEntities["DOOR"]).IsOpen())throw new InvalidOperationException("Minimal native paid fixture ownership/support/closed Door gate");
        }
        private void TraversalFixtureTransition(string action,string nextRole) {
            var transition=new {Event=action,Step=homeStep,NextRole=nextRole,Time=Time.realtimeSinceStartup,Structure=DescribeHome(),
                DoorClosed=!((Door)homeEntities["DOOR"]).IsOpen(),G4Complete=traversalG4Complete};
            traversalFixtureTransitions.Add(transition);Log("TRAVERSAL_FIXTURE_TRANSITION",transition);
        }
        private void TraversalFixturePause() {
            if(homeStep!=4 || HomeBuildRole()!="TC")throw new InvalidOperationException("G4 pause outside minimal paid fixture boundary");
            homePhase="FIXTURE";traversalPhase="FIXTURE_WAIT";traversalFixtureReadyAt=Time.realtimeSinceStartup+8;homeWait=Time.realtimeSinceStartup+30;
        }
        private void TraversalFixtureHomeReady() {
            HomeRequireStructure();
            if(!traversalG4Complete || homeStep!=8 || ((Door)homeEntities["DOOR"]).IsOpen())throw new InvalidOperationException("Full home continuation lacks prior G4/closed Door");
            TraversalFixtureTransition("FULL_HOME_READY","HOME_IN_OUT");homePhase="FIXTURE";TraversalFixtureMove(traversalDoorStand,"FIXTURE_FULL_HOME_RETURN");
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
                SourceSnapshotConsolePolicy="PRIMARY_ONLY_FIXED_CALLBACK_V1",
                Frames=localMotion.Evidence,Scenes=traversalScenes,Actuations=localMotion.Actuations,Components=traversalComponents,Warmup=traversalWarmupReceipt,SpawnSupport=traversalSpawnSupport,
                WarmupPolicy="STATIONARY_CLOCK_WINDOW_V1",WarmupContract=traversalWarmupContract,WarmupObservations=traversalWarmupObservations,WarmupObservationCount=traversalWarmupObservations.Count,
                Order="OWNED_NATIVE_TEST_FIXTURE",SequencePolicy="G4_PRIORITY_V1",DestinationPolicy="STATIONARY_DESTINATION_WINDOW_V1",TrafficPolicy="OBSERVED_TRAFFIC_V1",
                DestinationReadinessPolicy="NATIVE_NEW_GOAL_READINESS_V1",
                DestinationWindows=traversalDestinations.Select(w=>new {w.Id,w.Stage,Goal=Point(w.Goal),w.BaseActuations,w.Outcome,w.EndWall,w.Reason,w.SetDestinationCalls,Contract=w.Contract,
                    Observations=w.Observations,ObservationCount=w.Observations.Count,Receipt=w.Receipt,Commit=w.Commit,Handoff=w.Handoff}).ToArray(),
                FixturePolicy="MINIMAL_G4_BEFORE_TC_V1",FixtureTransitions=traversalFixtureTransitions,DiagnosticRecoveryRequested=traversalRecoveryRequested,
                FixtureStandPolicy="FULL_BODY_SELF_EXCLUDED_STANDS_V1",FixtureStandAttempts=traversalFixtureStandAttempts,
                FixtureForeignUnchanged=homeEntities.Count==0 || homeForeign==ForeignHomeKey(),
                FoundationAdmissionPolicy="ACTUAL_FOUNDATION_READMISSION_V1",FoundationAdmission=traversalFoundationAdmission,
                ReadinessPolicy=localMotion.ReadinessPolicy,Fixture=traversalFixture,Detour=traversalDetour,BuildPlans=traversalBuildPlans,BuildRests=traversalBuildRests,SharedOutdoor=traversalOutdoor,SharedHome=traversalHome,Completed=traversalComplete};
        }
        private void StopTraversal(string reason) {
            if(motionDriver!=null)motionDriver.Step=null;
            if(traversalDestination!=null){traversalDestination.Outcome="CANCELLED";traversalDestination.EndWall=Time.realtimeSinceStartupAsDouble;traversalDestination.Reason=reason;traversalDestination=null;}
            if(localMotion!=null)localMotion.Stop(reason);
        }
    }
}
