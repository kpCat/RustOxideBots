namespace RustBots.Navigation
{
    using System;
    using System.Collections.Generic;
    using System.Diagnostics;
    using System.Linq;
    using Rust.Ai.Gen2;
    using Rust.Ai.Gen2.Nav;
    using UnityEngine;
    using UnityEngine.AI;

    // RustNav is a route oracle only. This controller never changes the original
    // body's configuration; even kinematic MovePosition is treated as unchecked
    // until the following physics tick supplies an independent actual witness.
    public sealed class ObstacleTraversal
    {
        public struct TraversalClock
        {
            public double WallTime, FixedTime, FixedUnscaledTime;
            public float Delta, UnscaledDelta, TimeScale, MaximumDelta;
            public bool InFixedStep;
            public string PhysicsMode;
            public long Sequence;
            public int Frame;
        }

        private const int Mask = -1, MaxEvidence = 16384, MaxCasts = 64;
        private const float Numerical = 0.001f, MaxTick = 0.1f, MaxAcceleration = 4f;
        private const double ClockPrecision = 0.000001;
        private const string NativeAdmissionPolicy = "NATIVE_CURRENT_ROUTE_V1";
        private const string RecoveryPolicy = "MEASURED_BRAKE_V1";
        private const int MaxBrakeSteps = 8;
        private const float BrakeAcceleration = 3f, MaxBrakeSeconds = 1f;
        private const int NativePathCapacity = 256; // Installed RustNavMeshPath constructor.
        private readonly ScientistNPC npc;
        private readonly RustNavMeshAgent agent;
        private readonly string world, actor;
        private readonly Action<object> sink;
        private readonly CapsuleCollider capsule;
        private readonly Rigidbody body;
        private readonly Vector3 originalCenter, originalScale;
        private readonly float radius, height, maxStep, maxDrop, maxSlope, maxSpeed, skin, supportTolerance;
        // Same operational event-loop bound as the existing caller trace. It is
        // never a physics horizon or an automatic acceptance of delayed motion.
        private const float maxWallStall = 1.5f;
        private readonly float nativeMaximumDelta;
        private readonly float navClimb, navSlope, navRadius, navHeight;
        private readonly bool originalKinematic, originalGravity;
        private readonly string originalCollisionMode;
        private readonly int originalLayer;
        private readonly object profile;
        private readonly List<Vector3> route = new List<Vector3>();
        private ulong[] routePolys = new ulong[0];
        private object[] routePlanLegs = new object[0];
        private bool routeFilter;
        private string nativePathReason;
        private sealed class NativeRouteReceipt
        {
            public RustNavmesh Mesh;
            public IntPtr Handle;
            public Vector3 From, Requested;
            public bool Filter;
            public int Change, Data;
            public long Sequence;
            public double Started, Completed;
            public ulong[] Polys;
            public Dictionary<string, object> Row;
        }
        private NativeRouteReceipt nativeAdmission;
        private sealed class NativeEpochProof
        {
            public RustNavmesh Mesh;
            public IntPtr Handle;
            public int Session, Command, Index, OldChange, OldData, Change, Data, Suffix, Ordinal, PreviousOrdinal, PreviousCommand, PriorChange, PriorData, BeforeStep;
            public long PreviousSequence;
            public double PreviousCompleted;
            public bool Filter, Sealed, StartsBrake;
            public bool? PendingBefore, PendingAfterNative, PendingAtSeal;
            public bool? OriginalObjectMatched, CurrentObjectMatched;
            public double Started, NativeCompleted, Completed, RouteStarted;
            public float Required;
            public TraversalClock Clock, BrakeClock;
            public Vector3 From, Goal, Actual, Velocity, NativeVelocity, FloorCenter, FloorSize, BrakeOrigin, BrakeVelocity;
            public int RecoveryAttempt;
            public Vector3[] Corners, CurrentCorners, CorridorPoints;
            public ulong[] Polys, CurrentPolys;
            public Collider Floor;
            public SupportResult Anchor;
            public string FloorFingerprint, Failure;
            public object Body, FloorRow, OriginalQuery, CurrentQuery, Row, BuildBefore, BuildAfter;
            public object[] CommittedPlan, OldRefsBefore, OldRefsAfter, CurrentRefsBefore, CurrentRefsAfter, Corridor;
        }
        private NativeEpochProof epochProof;
        private int epochProofAttempts;
        private long lastEpochAttemptSequence;
        private readonly List<object> epochProofJournal = new List<object>();
        private sealed class BrakeRestContext
        {
            public int Session, Step, Attempt, Command;
            public TraversalClock Clock, StartClock;
            public Vector3 Actual, RigidbodyPosition, Goal, Origin, Velocity;
            public object Admission, LastGuard;
            public FrozenStationaryBody FrozenBody;
        }
        private sealed class StationaryNativeState
        {
            public RustNavmesh Mesh;
            public IntPtr Handle;
            public int? Change, Data;
            public bool? Available, MeshAvailable, Built, Pending, OnMesh, ProfileMatched, FilterMatched, SameSpanObject;
            public bool Ready, ComparedToSpan;
            public double Started, Completed;
            public string Reason;
        }
        private sealed class StationaryReplanContext
        {
            public int Session, Command, BaseActuations, RetryBefore, Observation, Span, SpanRestarts, OriginalIndex;
            public string Entry, State, FloorFingerprint, PlanPhase;
            public double Started, RouteStarted, GlobalDeadline, Deadline, PlanStarted, PlanCompleted;
            public bool HasFirst, PlanAccepted, NativeQueriesStarted;
            public int PlanCalls, FirstWriterCommand;
            public TraversalClock EntryClock, FirstClock;
            public Vector3 Actual, RigidbodyPosition, Goal, FloorCenter, FloorSize, AnchorPoint, AnchorNormal;
            public Quaternion Rotation;
            public Collider Floor;
            public RustNavmesh OriginalMesh;
            public IntPtr OriginalHandle;
            public int OriginalChange, OriginalData;
            public bool Filter;
            public object[] OriginalPlan;
            public object OriginalNavigation, NewNavigation, OriginalBody, FloorRow, Anchor, Ready, LastGuard, PlanGuard, Failure;
            public BrakeRestContext BrakeRest;
            public StationaryNativeState First, Last;
            public FrozenStationaryBody FrozenBody;
        }
        private sealed class FrozenStationaryBody
        {
            public Vector3 Position, RigidbodyPosition, CapsulePosition, Scale, Center, A, B;
            public Quaternion Rotation, CapsuleRotation;
            public float Radius, Height;
            public int Capsule, Rigidbody, Direction, Layer;
            public bool Enabled, Trigger, Kinematic, Gravity, Detect, AgentStopped, AgentPosition, AgentRotation;
            public string CollisionMode;
        }
        private StationaryReplanContext stationary;
        private double? sessionGlobalDeadline;
        private int sessionBaseActuations, sessionBaseCommand;
        private TraversalClock? sessionBaselineClock;
        private object sessionBaselineBody;
        private FrozenStationaryBody sessionBaselineFrozenBody;
        private FrozenStationaryBody acceptedBrakeZeroBody;
        private int acceptedBrakeZeroSession, acceptedBrakeZeroCommand;
        private long acceptedBrakeZeroSequence;
        private Vector3 sessionBaselinePosition, sessionBaselineRigidbodyPosition;
        private object finalNativeAdmission;
        private readonly Stopwatch queryClock = new Stopwatch();
        private readonly List<object> evidence = new List<object>();
        private int routeIndex, ticks, casts, command, retries, actuations, heightWitnesses, unchangedWitnesses, motionSession;
        private float lastTime, commandTime;
        private double startWallTime;
        private TraversalClock currentClock, previousClock, commandClock, acquisitionRestClock;
        private bool clockReady, clockContext;
        private Vector3 destination, lastPosition, lastVelocity, commanded, commandFrom;
        private Vector3 routeFrom;
        private RustNavmesh routeMesh;
        private IntPtr routeMeshHandle;
        private int routeTileChangeVersion, routeTileDataVersion;
        private Vector3 supportDirection;
        private string routeStatus = "NOT_CALCULATED";
        private string stage = "UNINITIALIZED", reason = "NOT_STARTED", commandClass, heightClass;
        private bool active, arrived, blocked, pending, closedDoorHit, dynamicHit, unobservedTerminal, commandHold;
        private bool acquisitionEligible = true, acquiring, commandAcquisition;
        private Vector3 acquisitionStart, acquisitionNormal, acquisitionPoint;
        private float acquisitionStartTime, acquisitionStartGap, acquisitionFloorY, acquisitionRestTime;
        private Collider acquisitionFloor;
        private Dictionary<string, object> pendingFrame;
        private bool braking, commandBraking, replanAfterRest;
        private int recoveryAttempts, brakeStep;
        private TraversalClock brakeClock;
        private Vector3 brakeOrigin, brakeVelocity, brakeFloorCenter, brakeFloorSize;
        private Collider brakeFloor;
        private string brakeFloorFingerprint;
        private object brakeFloorRow;
        private string brakeClassification, brakeReason;
        private object brakeReceipt;
        private bool diagnosticRecoveryQueued;
        private long diagnosticRecoverySequence;

        private sealed class SupportResult
        {
            public bool Found;
            public Collider Collider;
            public Vector3 Origin, Point, Normal, Center;
            public float Length, Distance, FootY, Gap, PlaneClearance;
            public string Kind = "SURFACE";
            public object EdgeSource, EdgeTop;
            public object[] Hits = new object[0];
        }

        public ObstacleTraversal(ScientistNPC npc, RustNavMeshAgent agent, string world, Action<object> sink)
        {
            this.npc = npc; this.agent = agent; this.world = world; this.sink = sink;
            if (npc == null || agent == null || npc.net == null || string.IsNullOrEmpty(world))
                throw new ArgumentException("Traversal requires a live native actor, agent and world identity");
            actor = npc.net.ID.Value.ToString();
            var capsules = npc.GetComponents<CapsuleCollider>();
            if (capsules.Length != 1) throw new InvalidOperationException("Traversal original capsule is ambiguous");
            capsule = capsules[0]; body = npc.GetComponent<Rigidbody>();
            if (body == null) throw new InvalidOperationException("Traversal original Rigidbody missing");
            radius = capsule.radius; height = capsule.height;
            originalCenter = capsule.center; originalScale = capsule.transform.lossyScale;
            originalKinematic = body.isKinematic; originalGravity = body.useGravity;
            originalCollisionMode = body.collisionDetectionMode.ToString();
            originalLayer = capsule.gameObject.layer;
            var nav = RustNavigation.Instance;
            if (nav == null || nav.DefaultNavmesh == null) throw new InvalidOperationException("Traversal nav profile unavailable");
            var build = nav.DefaultNavmesh.BuildParams;
            navClimb = build.agentMaxClimb; navSlope = build.agentMaxSlope; navRadius = build.agentRadius; navHeight = build.agentHeight;
            // These are declared limits of this custom controller, not proof that
            // a native body can step. Every commanded trajectory is still queried.
            maxStep = Mathf.Min(radius, Mathf.Min(build.agentMaxClimb, BaseNavigator.maxStepUpDistance));
            maxDrop = maxStep; maxSlope = Mathf.Min(build.agentMaxSlope, 60f);
            maxSpeed = Mathf.Min(1.2f, agent.walkSpeed);
            skin = Physics.defaultContactOffset * 2f;
            nativeMaximumDelta = Time.maximumDeltaTime;
            supportTolerance = skin + 0.05f; // Initial terrain spawn may be 5 cm above ground.
            profile = new { MaxStep = maxStep, MaxDrop = maxDrop, MaxSlope = maxSlope, MaxSpeed = maxSpeed,
                MaxAcceleration = MaxAcceleration, MaxTick = MaxTick, MaxWallStall = maxWallStall, NativeMaximumDelta = nativeMaximumDelta, Skin = skin, SupportTolerance = supportTolerance,
                NavClimb = build.agentMaxClimb, NavSlope = build.agentMaxSlope, NavRadius = build.agentRadius,
                NavHeight = build.agentHeight, NativeStepCeiling = BaseNavigator.maxStepUpDistance,
                Capability = "CUSTOM_CHECKED_CONTROLLER_NOT_NATIVE_STEP_PROOF", NativeAdmissionPolicy = NativeAdmissionPolicy, FinalVelocityPolicy = "NATIVE_POST_SINK_VELOCITY_V1",
                EpochRevalidationPolicy = "SAME_COMMITTED_ROUTE_EPOCH_V2", StationaryReplanPolicy = "MEASURED_STATIONARY_NATIVE_V1" };
            agent.isStopped = true; agent.updatePosition = false; agent.updateRotation = false; agent.ResetPath();
            string invalid = BodyProblem();
            if (invalid != null || !Finite(maxStep) || maxStep <= 0 || !Finite(maxSlope) || maxSlope <= 0 ||
                !Finite(maxSpeed) || maxSpeed <= 0 || !Finite(skin) || skin <= 0 || skin > 0.05f ||
                !Finite(nativeMaximumDelta) || nativeMaximumDelta < Time.fixedDeltaTime || nativeMaximumDelta > 120f)
                throw new InvalidOperationException("Traversal profile UNKNOWN: " + (invalid ?? "INVALID_NATIVE_LIMITS"));
        }

        public bool Arrived { get { return arrived; } }
        public bool Blocked { get { return blocked; } }
        public bool Active { get { return active; } }
        public string Reason { get { return reason; } }
        public List<object> Evidence { get { return evidence; } }
        public int Actuations { get { return actuations; } }
        public string ReadinessPolicy { get { return NativeAdmissionPolicy; } }
        public float NativeMaximumDeltaTime { get { return nativeMaximumDelta; } }

        private bool StationaryWaiting { get { return stationary != null && stationary.State != "COMMITTED" && stationary.State != "WRITTEN" && stationary.State != "TERMINAL"; } }

        // Existing caller heartbeat only. Never a physics callback or a planner retry.
        public void PollStationaryReplanTimeout()
        {
            if (!StationaryWaiting || !ControlCurrent()) return;
            double now = Time.realtimeSinceStartupAsDouble;
            if (!Finite(now) || now < stationary.Started || now > stationary.Deadline) {
                StationaryFailure("STATIONARY_REPLAN_DEADLINE", "TIMEOUT_HEARTBEAT");
                Stop("STATIONARY_REPLAN_DEADLINE");
            }
        }

        private void StationaryFailure(string why, string phase)
        {
            var s = stationary;
            if (s == null || s.FirstWriterCommand != 0 || pending || actuations != s.BaseActuations) return;
            if (s.Failure == null) s.Failure = new { Reason = why, Phase = phase, Time = Time.realtimeSinceStartupAsDouble,
                Clock = clockContext ? ClockRow(currentClock) : null, Actual = P(npc.transform.position), Body = BodyRow() };
            s.State = "TERMINAL";
        }

        private StationaryNativeState ReadStationaryNative(StationaryReplanContext s)
        {
            var n = new StationaryNativeState { Started = Time.realtimeSinceStartupAsDouble };
            try {
                var nav = RustNavigation.Instance; n.Available = nav != null;
                n.Mesh = nav == null ? null : nav.DefaultNavmesh;
                n.MeshAvailable = n.Mesh != null;
                n.Built = nav == null ? (bool?)null : nav.IsDefaultNavmeshBuilt();
                n.Pending = nav == null ? (bool?)null : nav.HasPendingTiles(); n.OnMesh = agent.isOnNavMesh;
                n.FilterMatched = agent.npcDoorsWillOpen == (s == null ? routeFilter : s.Filter);
                if (n.Mesh != null) {
                    n.Handle = n.Mesh.NavMeshHandle; n.Change = n.Mesh.TileChangeVersion; n.Data = n.Mesh.TileDataVersion;
                    var p = n.Mesh.BuildParams;
                    n.ProfileMatched = p.agentMaxClimb == navClimb && p.agentMaxSlope == navSlope && p.agentRadius == navRadius && p.agentHeight == navHeight;
                }
                n.ComparedToSpan = s != null && s.HasFirst;
                n.SameSpanObject = n.ComparedToSpan ? (bool?)object.ReferenceEquals(n.Mesh, s.First.Mesh) : null;
                n.Ready = n.Available == true && n.Mesh != null && n.Handle != IntPtr.Zero && n.Built == true && n.Pending == false &&
                    n.OnMesh == true && n.ProfileMatched == true && n.FilterMatched == true;
                n.Reason = n.Ready ? null : n.Available != true ? "NATIVE_UNAVAILABLE" : n.Mesh == null ? "NATIVE_MESH_UNKNOWN" :
                    n.Built != true ? "NATIVE_UNBUILT" : n.Pending != false ? "NATIVE_PENDING_OR_UNKNOWN" : n.OnMesh != true ? "NATIVE_OFFMESH" : "NATIVE_PROFILE_FILTER_OR_HANDLE";
            } catch (Exception ex) { n.Ready = false; n.Reason = "NATIVE_OBSERVATION_EXCEPTION:" + ex.GetType().Name; }
            n.Completed = Time.realtimeSinceStartupAsDouble; return n;
        }

        private object StationaryNativeRow(StationaryNativeState n)
        {
            return n == null ? null : new { StartedWall = n.Started, CompletedWall = n.Completed, Available = n.Available,
                DefaultMesh = n.MeshAvailable, Handle = n.Handle == IntPtr.Zero ? null : n.Handle.ToString(), Built = n.Built, PendingTiles = n.Pending,
                OnMesh = n.OnMesh, ProfileMatched = n.ProfileMatched, FilterMatched = n.FilterMatched, Change = n.Change, Data = n.Data,
                ComparedToSpan = n.ComparedToSpan, SameSpanObject = n.SameSpanObject, Ready = n.Ready, Reason = n.Reason };
        }

        private bool SameStationaryNative(StationaryReplanContext s, StationaryNativeState n)
        {
            return s.HasFirst && n.Ready && object.ReferenceEquals(n.Mesh, s.First.Mesh) && n.Handle == s.First.Handle &&
                n.Change == s.First.Change && n.Data == s.First.Data && n.ProfileMatched == true && n.FilterMatched == true;
        }

        private FrozenStationaryBody CaptureStationaryBody()
        {
            Vector3 a, b; Endpoints(npc.transform.position, out a, out b);
            return new FrozenStationaryBody { Position = npc.transform.position, RigidbodyPosition = body.position, CapsulePosition = capsule.transform.position,
                Rotation = npc.transform.rotation, CapsuleRotation = capsule.transform.rotation, Scale = capsule.transform.lossyScale, Center = capsule.center,
                A = a, B = b, Radius = capsule.radius, Height = capsule.height, Capsule = capsule.GetInstanceID(), Rigidbody = body.GetInstanceID(),
                Direction = capsule.direction, Layer = capsule.gameObject.layer, Enabled = capsule.enabled, Trigger = capsule.isTrigger,
                Kinematic = body.isKinematic, Gravity = body.useGravity, Detect = body.detectCollisions, CollisionMode = body.collisionDetectionMode.ToString(),
                AgentStopped = agent.isStopped, AgentPosition = agent.updatePosition, AgentRotation = agent.updateRotation };
        }

        private static bool ExactVector(Vector3 a, Vector3 b) { return a.x == b.x && a.y == b.y && a.z == b.z; }
        private static bool ExactRotation(Quaternion a, Quaternion b) { return a.x == b.x && a.y == b.y && a.z == b.z && a.w == b.w; }
        private bool SameStationaryBody(FrozenStationaryBody f)
        {
            if (f == null || BodyProblem() != null) return false;
            Vector3 a, b; Endpoints(npc.transform.position, out a, out b);
            return ExactVector(f.Position, npc.transform.position) && ExactVector(f.RigidbodyPosition, body.position) &&
                ExactVector(f.CapsulePosition, capsule.transform.position) && ExactRotation(f.Rotation, npc.transform.rotation) &&
                ExactRotation(f.CapsuleRotation, capsule.transform.rotation) && ExactVector(f.Scale, capsule.transform.lossyScale) &&
                ExactVector(f.Center, capsule.center) && ExactVector(f.A, a) && ExactVector(f.B, b) &&
                f.Radius == capsule.radius && f.Height == capsule.height && f.Capsule == capsule.GetInstanceID() && f.Rigidbody == body.GetInstanceID() &&
                f.Direction == capsule.direction && f.Layer == capsule.gameObject.layer && f.Enabled == capsule.enabled && f.Trigger == capsule.isTrigger &&
                f.Kinematic == body.isKinematic && f.Gravity == body.useGravity && f.Detect == body.detectCollisions &&
                f.CollisionMode == body.collisionDetectionMode.ToString() && f.AgentStopped == agent.isStopped &&
                f.AgentPosition == agent.updatePosition && f.AgentRotation == agent.updateRotation;
        }

        private object StationaryBodyRow(FrozenStationaryBody f)
        {
            return f == null ? null : new { Position = P(f.Position), RigidbodyPosition = P(f.RigidbodyPosition), CapsulePosition = P(f.CapsulePosition),
                Rotation = new[] { f.Rotation.x, f.Rotation.y, f.Rotation.z, f.Rotation.w },
                CapsuleRotation = new[] { f.CapsuleRotation.x, f.CapsuleRotation.y, f.CapsuleRotation.z, f.CapsuleRotation.w },
                Scale = P(f.Scale), Center = P(f.Center), A = P(f.A), B = P(f.B), Radius = f.Radius, Height = f.Height,
                Capsule = f.Capsule, Rigidbody = f.Rigidbody, Direction = f.Direction, Layer = f.Layer, Enabled = f.Enabled, Trigger = f.Trigger,
                Kinematic = f.Kinematic, Gravity = f.Gravity, Detect = f.Detect, CollisionMode = f.CollisionMode,
                AgentStopped = f.AgentStopped, AgentPosition = f.AgentPosition, AgentRotation = f.AgentRotation };
        }

        private bool BeginStationaryReplan(Dictionary<string, object> frame, SupportResult support, object[] overlaps, bool clear, bool permission, float water, BrakeRestContext rest = null)
        {
            if (!sessionGlobalDeadline.HasValue || stationary != null || !ControlCurrent() || pending || acquiring ||
                !ExactZero(lastVelocity) || !ExactZero(body.linearVelocity) || retries >= 1 || support.Collider == null || support.Collider.attachedRigidbody != null ||
                !Supported(support)) return false;
            bool baseline = rest == null;
            if (baseline && (braking || !sessionBaselineClock.HasValue || actuations != sessionBaseActuations || command != sessionBaseCommand ||
                !SameStationaryBody(sessionBaselineFrozenBody) ||
                (npc.transform.position - sessionBaselinePosition).sqrMagnitude != 0 || (body.position - sessionBaselineRigidbodyPosition).sqrMagnitude != 0)) return false;
            if (!baseline && (rest.Admission == null || rest.Session != motionSession || rest.Command != command || !SameStationaryBody(rest.FrozenBody) || !BrakeFloorCurrent(support) ||
                (npc.transform.position - rest.Actual).sqrMagnitude != 0 || (body.position - rest.RigidbodyPosition).sqrMagnitude != 0)) return false;
            var entity = support.Collider.GetComponentInParent<BaseEntity>();
            if (entity is Door || entity is BasePlayer || entity is BaseVehicle) return false;
            double started = Time.realtimeSinceStartupAsDouble;
            stationary = new StationaryReplanContext { Session = motionSession, Command = command, BaseActuations = actuations, RetryBefore = retries++,
                Entry = baseline ? "BASELINE_BEFORE_FIRST_WRITER" : "ACKNOWLEDGED_BRAKE_REST", State = "WAITING", Started = started,
                RouteStarted = startWallTime, GlobalDeadline = sessionGlobalDeadline.Value,
                Deadline = Math.Min(started + 20, Math.Min(startWallTime + 120, sessionGlobalDeadline.Value)), EntryClock = currentClock,
                Actual = npc.transform.position, RigidbodyPosition = body.position, Rotation = npc.transform.rotation, Goal = destination,
                Floor = support.Collider, FloorFingerprint = BrakeFloorFingerprint(support.Collider), FloorCenter = support.Collider.bounds.center,
                FloorSize = support.Collider.bounds.size, AnchorPoint = support.Point, AnchorNormal = support.Normal,
                OriginalBody = BodyRow(), FrozenBody = baseline ? sessionBaselineFrozenBody : rest.FrozenBody,
                FloorRow = ColliderRow(support.Collider), Anchor = SupportRow(support), OriginalNavigation = NavigationRow(),
                OriginalMesh = routeMesh, OriginalHandle = routeMeshHandle, OriginalChange = routeTileChangeVersion, OriginalData = routeTileDataVersion,
                OriginalPlan = routePlanLegs, OriginalIndex = routeIndex, Filter = routeFilter, BrakeRest = rest };
            if (!baseline) { braking = commandBraking = false; replanAfterRest = true; }
            if (!StationaryContextCurrent(stationary, "ENTRY", support, overlaps, clear, permission, water)) {
                Block(frame, "UNKNOWN", "STATIONARY_ENTRY_CONTEXT_OR_CLOCK"); return false;
            }
            frame["NativeResult"] = "STATIONARY_OBSERVATION"; frame["WriterCalled"] = false;
            Emit("STATIONARY_REPLAN_STARTED", frame); return ControlCurrent();
        }

        private bool StationaryContextCurrent(StationaryReplanContext s, string phase, SupportResult support, object[] overlaps, bool clear, bool permission, float water)
        {
            var actual = npc.transform.position; var rigid = body.position; var q = npc.transform.rotation;
            var measured = (actual - s.Actual) / currentClock.Delta;
            bool context = ControlCurrent() && s.Session == motionSession && s.Command == command && s.BaseActuations == actuations && !pending &&
                !acquiring && !braking && retries == s.RetryBefore + 1 && s.RouteStarted == startWallTime && sessionGlobalDeadline == s.GlobalDeadline &&
                routePlanLegs == s.OriginalPlan && routeMesh == s.OriginalMesh && routeMeshHandle == s.OriginalHandle &&
                routeTileChangeVersion == s.OriginalChange && routeTileDataVersion == s.OriginalData && routeIndex == s.OriginalIndex && routeFilter == s.Filter &&
                (destination - s.Goal).sqrMagnitude == 0 && (actual - s.Actual).sqrMagnitude == 0 && (rigid - s.RigidbodyPosition).sqrMagnitude == 0 &&
                q.x == s.Rotation.x && q.y == s.Rotation.y && q.z == s.Rotation.z && q.w == s.Rotation.w &&
                ExactZero(measured) && ExactZero(lastVelocity) && ExactZero(body.linearVelocity) && SameStationaryBody(s.FrozenBody);
            bool floor = s.Floor != null && s.Floor.attachedRigidbody == null && BrakeFloorFingerprint(s.Floor) == s.FloorFingerprint &&
                (s.Floor.bounds.center - s.FloorCenter).sqrMagnitude == 0 && (s.Floor.bounds.size - s.FloorSize).sqrMagnitude == 0 &&
                support.Collider == s.Floor && Supported(support) && (support.Point - s.AnchorPoint).sqrMagnitude == 0 && (support.Normal - s.AnchorNormal).sqrMagnitude == 0;
            var bodyRow = BodyRow(); double checkedWall = Time.realtimeSinceStartupAsDouble;
            bool clock = ClockProblem(currentClock) == null;
            bool accepted = context && floor && clear && permission && Finite(water) && water <= 0.15f && clock && checkedWall >= s.Started &&
                checkedWall <= s.Deadline && checkedWall >= currentClock.WallTime && checkedWall - currentClock.WallTime <= MaxTick;
            s.LastGuard = new { Phase = phase, Accepted = accepted, CheckedWall = checkedWall, Clock = ClockRow(currentClock), Body = bodyRow,
                FrozenBody = StationaryBodyRow(CaptureStationaryBody()),
                Actual = P(actual), RigidbodyPosition = P(rigid), NativeVelocity = P(body.linearVelocity), MeasuredVelocity = P(measured), ContextMatched = context,
                FloorCurrent = floor, Support = SupportRow(support), Overlaps = overlaps, QueriesExecuted = true, OverlapClear = clear, Permission = permission, WaterDepth = water, ClockAccepted = clock,
                ControlActive = active, ControlBlocked = blocked, ControlArrived = arrived, UnobservedTerminal = unobservedTerminal };
            return accepted;
        }

        private bool StationaryQueryGuard(StationaryReplanContext s, string phase)
        {
            var actual = npc.transform.position; var support = Support(actual); var overlaps = new List<object>();
            bool clear = Overlaps(actual, support, overlaps); bool permission = Permission(actual);
            float water = WaterLevel.GetWaterSurface(actual, true, true, null) - actual.y;
            bool physical = StationaryContextCurrent(s, phase, support, overlaps.ToArray(), clear, permission, water); var physicalRow = s.LastGuard;
            s.Last = ReadStationaryNative(s);
            bool native = SameStationaryNative(s, s.Last), unchanged = StationaryPoseCurrent(s); var row = BodyRow();
            bool clock = ClockProblem(currentClock) == null; double checkedWall = Time.realtimeSinceStartupAsDouble;
            bool accepted = physical && native && unchanged && clock && checkedWall >= currentClock.WallTime && checkedWall - currentClock.WallTime <= MaxTick && checkedWall <= s.Deadline;
            s.LastGuard = new { Phase = phase, Accepted = accepted, CheckedWall = checkedWall, Clock = ClockRow(currentClock), Body = row,
                Physical = physicalRow, Native = StationaryNativeRow(s.Last), NativeAccepted = native, Unchanged = unchanged, ClockAccepted = clock };
            return accepted;
        }

        private bool StationaryPoseCurrent(StationaryReplanContext s)
        {
            var q = npc.transform.rotation;
            return ControlCurrent() && !pending && actuations == s.BaseActuations && command == s.Command && motionSession == s.Session &&
                (npc.transform.position - s.Actual).sqrMagnitude == 0 && (body.position - s.RigidbodyPosition).sqrMagnitude == 0 &&
                q.x == s.Rotation.x && q.y == s.Rotation.y && q.z == s.Rotation.z && q.w == s.Rotation.w &&
                ExactZero(lastVelocity) && ExactZero(body.linearVelocity) && SameStationaryBody(s.FrozenBody) && s.Floor != null && s.Floor.attachedRigidbody == null &&
                BrakeFloorFingerprint(s.Floor) == s.FloorFingerprint && (s.Floor.bounds.center - s.FloorCenter).sqrMagnitude == 0 &&
                (s.Floor.bounds.size - s.FloorSize).sqrMagnitude == 0;
        }

        private void ObserveStationaryReplan(Dictionary<string, object> frame, SupportResult support, object[] overlaps, bool clear, bool permission, float water)
        {
            var s = stationary;
            if (!StationaryWaiting || !ControlCurrent()) return;
            if (s.Observation >= 512 || !StationaryContextCurrent(s, "OBSERVATION", support, overlaps, clear, permission, water)) {
                Block(frame, "UNKNOWN", "STATIONARY_REPLAN_CONTEXT_OR_BOUND"); return;
            }
            s.Observation++; var n = ReadStationaryNative(s); s.Last = n; string outcome;
            bool changed = s.HasFirst && !SameStationaryNative(s, n);
            if (!n.Ready || changed) {
                outcome = "WAIT";
                if (s.HasFirst) s.SpanRestarts++;
                s.HasFirst = false; s.First = null;
            } else {
                outcome = s.HasFirst ? "WINDOW_ADVANCE" : "WINDOW_START";
                if (!s.HasFirst) { s.HasFirst = true; s.First = n; s.FirstClock = currentClock; s.Span++; }
                if (currentClock.WallTime - s.FirstClock.WallTime >= 2 && currentClock.FixedTime - s.FirstClock.FixedTime >= 2 &&
                    currentClock.FixedUnscaledTime - s.FirstClock.FixedUnscaledTime >= 2 && n.Completed - s.First.Completed >= 2) outcome = "READY";
            }
            if (ClockProblem(currentClock) != null || Time.realtimeSinceStartupAsDouble > s.Deadline) {
                Block(frame, "UNKNOWN", "STATIONARY_REPLAN_OBSERVATION_STALE"); return;
            }
            frame["NativeResult"] = "STATIONARY_OBSERVATION"; frame["WriterCalled"] = false; frame["MotionMode"] = "STATIONARY_NATIVE_WAIT";
            frame["ObservedVelocity"] = P((npc.transform.position - s.Actual) / currentClock.Delta);
            frame["StationaryObservation"] = new { Outcome = outcome, Reason = changed && n.Ready ? "NATIVE_OBJECT_OR_VERSION_CHANGED" : n.Reason,
                Native = StationaryNativeRow(n), Guard = s.LastGuard };
            if (outcome == "READY") {
                s.State = "READY"; s.Ready = new { Clock = ClockRow(currentClock), FirstClock = ClockRow(s.FirstClock), Observation = s.Observation,
                    Span = s.Span, SpanRestarts = s.SpanRestarts, FirstNative = StationaryNativeRow(s.First), LastNative = StationaryNativeRow(n) };
            }
            Emit("STATIONARY_REPLAN_OBSERVATION", frame);
            if (!ControlCurrent()) return;
            if (!StationaryPoseCurrent(s) || ClockProblem(currentClock) != null || Time.realtimeSinceStartupAsDouble > s.Deadline) {
                Block(frame, "UNKNOWN", "STATIONARY_REPLAN_CHANGED_AFTER_OBSERVATION"); return;
            }
            if (outcome != "READY") return;
            s.State = "PLANNING"; s.PlanStarted = Time.realtimeSinceStartupAsDouble; s.PlanCalls++;
            bool accepted = Plan(s.Goal, null, s);
            s.PlanCompleted = Time.realtimeSinceStartupAsDouble; s.PlanAccepted = accepted; s.PlanGuard = s.LastGuard;
            if (!accepted) { Block(frame, "UNKNOWN", "STATIONARY_SINGLE_NATIVE_PLAN_REFUSED"); return; }
            s.NewNavigation = NavigationRow(); s.Last = ReadStationaryNative(s);
            if (!StationaryPoseCurrent(s) || !SameStationaryNative(s, s.Last) || ClockProblem(currentClock) != null || Time.realtimeSinceStartupAsDouble > s.Deadline) {
                Block(frame, "UNKNOWN", "STATIONARY_COMMIT_CONTEXT_CHANGED"); return;
            }
            s.State = "COMMITTED"; frame["Navigation"] = s.NewNavigation;
            frame["NativeResult"] = "ROUTE_REBOUND"; frame["Reason"] = "STATIONARY_NATIVE_ELIGIBILITY";
            Emit("STATIONARY_REPLAN_COMMITTED", frame); if (!ControlCurrent()) return;
            if (s.BrakeRest != null) {
                frame["RestAdmission"] = s.BrakeRest.Admission;
                frame["Recovery"] = brakeReceipt; // Original completed physical brake, never an extended recovery.
                frame["RestReplan"] = new { Kind = "STATIONARY_PLAN", Accepted = true, Guard = s.PlanGuard, Time = s.PlanCompleted };
                Emit("REPATH_AFTER_REST", frame); if (!ControlCurrent()) return; replanAfterRest = false;
            }
            Emit("REPATH", frame); // The next real FixedUpdate owns the first checked writer.
        }

        private object StationaryReplanSnapshot()
        {
            var s = stationary;
            if (s == null) return null;
            return new { Policy = "MEASURED_STATIONARY_NATIVE_V1", Id = s.Session, Entry = s.Entry, State = s.State, Session = s.Session,
                Command = s.Command, BaseActuations = s.BaseActuations, CurrentCommand = command, CurrentActuations = actuations, CurrentPending = pending,
                RetryBefore = s.RetryBefore, RetryAfter = s.RetryBefore + 1,
                StartedWall = s.Started, RouteStartedWall = s.RouteStarted, RouteDeadline = s.RouteStarted + 120, GlobalDeadline = s.GlobalDeadline,
                Deadline = s.Deadline, MaxSeconds = 20, MinStableSeconds = 2, MaxSamples = 512, Observation = s.Observation, Span = s.Span, SpanRestarts = s.SpanRestarts,
                EntryClock = ClockRow(s.EntryClock), BaselineClock = sessionBaselineClock.HasValue ? ClockRow(sessionBaselineClock.Value) : null,
                BaselineBody = sessionBaselineBody, BaselineFrozenBody = StationaryBodyRow(sessionBaselineFrozenBody), OriginalBody = s.OriginalBody,
                FrozenBody = StationaryBodyRow(s.FrozenBody), Actual = P(s.Actual), RigidbodyPosition = P(s.RigidbodyPosition),
                Goal = P(s.Goal), Floor = s.FloorRow, FloorCenter = P(s.FloorCenter), FloorSize = P(s.FloorSize), Anchor = s.Anchor,
                OriginalNavigation = s.OriginalNavigation, OriginalBrakeRest = s.BrakeRest == null ? null : s.BrakeRest.Admission,
                Ready = s.Ready, Native = StationaryNativeRow(s.Last), LastGuard = s.LastGuard,
                Plan = s.PlanCalls == 0 ? null : new { CallCount = s.PlanCalls, NativeQueriesStarted = s.NativeQueriesStarted, Phase = s.PlanPhase,
                    StartedWall = s.PlanStarted, CompletedWall = s.PlanCompleted, Accepted = s.PlanAccepted, Guard = s.PlanGuard, Navigation = s.NewNavigation },
                FirstWriterCommand = s.FirstWriterCommand, Failure = s.Failure };
        }

        // Bench-only caller may request one measured recovery from its accepted
        // moving witness callback. This queues intent and never actuates, plans,
        // changes destination or resets a clock/velocity/budget.
        public bool QueueMeasuredReplan()
        {
            if (!clockContext || pending || !active || arrived || blocked || acquiring || braking || diagnosticRecoveryQueued || recoveryAttempts != 0 ||
                command <= 0 || commandClock.Sequence + 1 != currentClock.Sequence || body.linearVelocity.sqrMagnitude == 0 || ClockProblem(currentClock) != null)
                return false;
            diagnosticRecoveryQueued = true; diagnosticRecoverySequence = currentClock.Sequence; return true;
        }

        // A bounded read-only production probe, also usable before door actions.
        // It cannot move, manufacture a successful witness or resolve a step.
        public bool ProbeDisplacement(Vector3 displacement, string stage, string targetEntity = null)
        {
            // Detached sensing has its own receipts, never a motor lifecycle event.
            // Reserve the entire receipt set without invoking Emit's terminal budget path.
            if (evidence.Count > MaxEvidence - 3) return false;
            var actual = npc.transform.position; var frame = Frame(Time.realtimeSinceStartup, actual);
            frame["Stage"] = stage ?? "UNSPECIFIED";
            frame["TargetEntity"] = targetEntity;
            frame["ControlBefore"] = ProbeState();
            if (active || pending || acquiring || unobservedTerminal || lastVelocity.sqrMagnitude != 0 || body.linearVelocity.sqrMagnitude != 0)
            {
                frame["NativeResult"] = "NOT_EXECUTED"; frame["Reason"] = "PROBE_REQUIRES_STATIONARY";
                frame["ControlAfter"] = ProbeState(); PublishProbe("PROBE_SKIPPED", frame, 0, 0); return false;
            }
            int savedCasts = casts; var savedDirection = supportDirection;
            bool savedDoor = closedDoorHit, savedDynamic = dynamicHit, safe = false;
            casts = 0; queryClock.Restart(); supportDirection = Horizontal(displacement).normalized;
            try
            {
                if (BodyProblem() != null || !Finite(displacement) || displacement.magnitude > radius * 4f)
                    throw new InvalidOperationException("PROBE_INVALID_BODY_OR_VECTOR");
                var support = Support(actual); var landing = Support(actual + displacement);
                var sweeps = new List<object>(); var overlaps = new List<object>(); var endOverlaps = new List<object>();
                bool currentClear = Overlaps(actual, support, overlaps);
                bool sweepClear = Sweep(actual, actual + displacement, support, sweeps);
                bool endpointClear = Overlaps(actual + displacement, landing, endOverlaps);
                bool permission = Permission(actual), landingPermission = Permission(actual + displacement);
                float waterDepth = WaterLevel.GetWaterSurface(actual, true, true, null) - actual.y;
                float landingWater = WaterLevel.GetWaterSurface(actual + displacement, true, true, null) - (actual + displacement).y;
                safe = currentClear && sweepClear && endpointClear && Supported(support) && SupportedAt(landing, actual + displacement) &&
                    permission && landingPermission && Finite(waterDepth) && waterDepth <= 0.15f && Mathf.Abs(displacement.y) <= (displacement.y >= 0 ? maxStep : maxDrop) &&
                    Finite(landingWater) && landingWater <= 0.15f;
                frame["Requested"] = P(actual + displacement); frame["Support"] = SupportRow(support); frame["Landing"] = SupportRow(landing);
                frame["Sweeps"] = sweeps.ToArray(); frame["Overlaps"] = overlaps.ToArray(); frame["LandingOverlaps"] = endOverlaps.ToArray();
                frame["Classification"] = safe ? Classify(actual, actual + displacement, support, landing) : closedDoorHit ? "DOOR_CLOSED" : dynamicHit ? "DYNAMIC_BLOCKED" : "SOLID_BLOCKED";
                frame["NativeResult"] = "PROBE_ONLY"; frame["Reason"] = safe ? "READ_ONLY_CHECKED" : "READ_ONLY_REFUSED";
                Conditions(frame, actual, support, currentClear, permission, waterDepth);
                frame["LandingPermission"] = landingPermission; frame["LandingWaterDepth"] = landingWater;
                frame["LandingSupportAccepted"] = Supported(landing);
            }
            catch (Exception ex) { frame["NativeResult"] = "NOT_EXECUTED"; frame["Reason"] = "PROBE_NATIVE_FAILURE:" + ex.GetType().Name; }
            finally
            {
                queryClock.Stop(); int probeCasts = casts; double milliseconds = queryClock.Elapsed.TotalMilliseconds;
                casts = savedCasts; supportDirection = savedDirection; closedDoorHit = savedDoor; dynamicHit = savedDynamic;
                frame["ControlAfter"] = ProbeState(); frame["Actual"] = P(npc.transform.position);
                bool measured = (string)frame["NativeResult"] == "PROBE_ONLY";
                PublishProbe(measured ? safe ? "PROBE_CLEAR" : "PROBE_REFUSED" : "PROBE_SKIPPED", frame, probeCasts, milliseconds);
                if (measured && !safe) PublishProbe("PHYSICAL_CONTACT", frame, probeCasts, milliseconds);
            }
            return safe;
        }

        private object ProbeState()
        {
            return new { Active = active, Arrived = arrived, Blocked = blocked, Pending = pending, Acquiring = acquiring,
                UnobservedTerminal = unobservedTerminal, Command = command, Actuations = actuations, Retry = retries,
                Velocity = P(lastVelocity), NativeVelocity = P(body.linearVelocity), Position = P(npc.transform.position),
                LastPosition = P(lastPosition), Destination = P(destination), Stage = stage, Reason = reason,
                RouteIndex = routeIndex, RouteCount = route.Count, RouteStatus = routeStatus, PendingDecision = pendingFrame };
        }
        private void PublishProbe(string name, Dictionary<string, object> frame, int count, double milliseconds)
        {
            var row = Copy(frame); row["Event"] = name; row["Casts"] = count; row["QueryMilliseconds"] = milliseconds;
            evidence.Add(row); if (sink != null) sink(row);
        }

        public bool SetDestination(Vector3 destination, string stage)
        {
            return SetDestinationCore(destination, stage, null);
        }

        public bool SetDestination(Vector3 destination, string stage, double absoluteGlobalDeadline)
        {
            if (!Finite(absoluteGlobalDeadline) || absoluteGlobalDeadline <= Time.realtimeSinceStartupAsDouble)
                throw new ArgumentOutOfRangeException("absoluteGlobalDeadline", "EXPLICIT_GLOBAL_DEADLINE_INVALID");
            return SetDestinationCore(destination, stage, absoluteGlobalDeadline);
        }

        private bool SetDestinationCore(Vector3 destination, string stage, double? absoluteGlobalDeadline)
        {
            if (StationaryWaiting) return false; // Reject another intent before any state/budget mutation.
            if (pending || unobservedTerminal) { Stop("UNOBSERVED_COMMAND"); return false; }
            if (acquiring) { Stop("ACQUISITION_ALREADY_ACTIVE_OR_FAILED"); return false; }
            if (braking || lastVelocity.sqrMagnitude != 0 || body.linearVelocity.sqrMagnitude != 0) { Stop("DESTINATION_CHANGE_BEFORE_OBSERVED_REST"); return false; }
            this.destination = destination; this.stage = stage ?? "UNSPECIFIED";
            active = true; arrived = blocked = false; reason = "ROUTE"; retries = 0; heightWitnesses = 0; unchangedWitnesses = 0;
            startWallTime = Time.realtimeSinceStartupAsDouble; lastTime = (float)startWallTime; lastPosition = npc.transform.position;
            clockReady = false; // A destination can be issued outside a physics callback.
            sessionGlobalDeadline = absoluteGlobalDeadline; stationary = null; sessionBaselineClock = null; sessionBaselineBody = null; sessionBaselineFrozenBody = null;
            acceptedBrakeZeroBody = null; acceptedBrakeZeroSession = acceptedBrakeZeroCommand = 0; acceptedBrakeZeroSequence = 0;
            sessionBaseActuations = actuations; sessionBaseCommand = command;
            nativeAdmission = null;
            motionSession++;
            epochProofAttempts = 0; lastEpochAttemptSequence = 0; epochProofJournal.Clear(); epochProof = null;
            recoveryAttempts = brakeStep = 0; braking = commandBraking = replanAfterRest = false; brakeReceipt = null;
            diagnosticRecoveryQueued = false;
            if (!Finite(destination) || BodyProblem() != null || !Plan(destination))
            { Stop("UNKNOWN_ROUTE_OR_BODY"); return false; }
            supportDirection = Horizontal(route[routeIndex] - lastPosition).normalized;
            return true;
        }

        public void Stop(string reason)
        {
            StationaryFailure(reason, "STOP");
            agent.isStopped = true; agent.updatePosition = false; agent.updateRotation = false;
            if (pending) { reason = "UNOBSERVED_COMMAND:" + reason; unobservedTerminal = true; }
            active = false; arrived = false; blocked = true; this.reason = reason;
            var frame = Frame(clockContext ? (float)currentClock.WallTime : (float)Time.realtimeSinceStartupAsDouble, npc.transform.position);
            if (pending) { frame["IssuedClock"] = ClockRow(commandClock); frame["PendingDecision"] = pendingFrame; }
            frame["Actual"] = P(npc.transform.position); frame["Reason"] = reason;
            frame["NativeResult"] = pending ? "UNOBSERVED" : "STOPPED";
            Emit("BLOCKED", frame);
            pending = false; pendingFrame = null;
        }

        public void Tick(TraversalClock clock)
        {
            if (!active) return; // No physics sensor work at idle.
            currentClock = clock; clockContext = true;
            nativeAdmission = null; // A native certificate never survives a physics callback.
            casts = 0; queryClock.Restart(); ticks++;
            try
            {
                string wallProblem = WallProblem(clock), physicsProblem = PhysicsClockProblem(clock);
                if (wallProblem != null || physicsProblem != null)
                {
                    if (physicsProblem == null && pending) ObserveLatePending();
                    Stop("CLOCK_CONTRACT:" + (wallProblem ?? physicsProblem) +
                        (wallProblem != null && physicsProblem != null ? ";PHYSICS:" + physicsProblem : ""));
                    return;
                }
                if (!clockReady)
                {
                    var actual = npc.transform.position;
                    var frame = Frame((float)clock.WallTime, actual);
                    string problem = BodyProblem();
                    if (problem != null || (actual - lastPosition).sqrMagnitude != 0 || lastVelocity.sqrMagnitude != 0 || body.linearVelocity.sqrMagnitude != 0)
                    { Block(frame, "UNKNOWN", problem ?? "CLOCK_BASELINE_NOT_STATIONARY"); return; }
                    frame["Classification"] = "CLEAR"; frame["NativeResult"] = "CLOCK_BASELINE";
                    frame["PosePrevious"] = P(lastPosition); frame["PosePreviousTime"] = lastTime; frame["ObservedVelocity"] = P(Vector3.zero);
                    sessionBaselineClock = clock; sessionBaselineBody = BodyRow(); sessionBaselineFrozenBody = CaptureStationaryBody();
                    sessionBaselinePosition = actual; sessionBaselineRigidbodyPosition = body.position;
                    Emit("CLOCK_BASELINE", frame);
                    if (!ControlCurrent()) return;
                    lastPosition = actual; lastTime = (float)clock.WallTime; clockReady = true; return;
                }
                TickCore((float)clock.WallTime);
            }
            catch (Exception ex)
            {
                Stop("UNKNOWN_NATIVE_FAILURE:" + ex.GetType().Name + ":" + ex.Message);
            }
            finally { previousClock = clock; clockContext = false; queryClock.Stop(); }
        }

        private void TickCore(float now)
        {
            Vector3 actual = npc.transform.position;
            // Current declared future physics step; never the prior wall gap.
            float dt = currentClock.Delta;
            var frame = Frame(now, actual);
            string invalid = BodyProblem();
            if (invalid != null || !Finite(now) || dt <= 0 || dt > MaxTick || currentClock.WallTime - startWallTime > 120.0 || ticks > 6000)
            { Block(frame, "UNKNOWN", invalid ?? "TIME_OR_TICK_BUDGET"); return; }
            if (!pending && Vector3.Distance(actual, lastPosition) > Numerical)
            { Block(frame, "UNKNOWN", "COMPETING_WRITER"); return; }
            if (!pending && lastVelocity.sqrMagnitude != 0)
            {
                // A recovery callback that issued no target must not carry a
                // previous moving velocity over an unobserved physics hold.
                frame["ObservedVelocity"] = P((actual - lastPosition) / (float)(currentClock.FixedTime - previousClock.FixedTime));
                Block(frame, "UNKNOWN", "CLOCK_UNOBSERVED_ACTIVE_HOLD"); return;
            }
            supportDirection = pending ? Horizontal(commanded - commandFrom).normalized : routeIndex < route.Count ? Horizontal(route[routeIndex] - actual).normalized : Horizontal(destination - actual).normalized;
            var support = Support(actual);
            frame["Support"] = SupportRow(support);
            var overlaps = new List<object>();
            bool overlapClear = Overlaps(actual, support, overlaps);
            frame["Overlaps"] = overlaps.ToArray();
            // Evaluate and report independent reasons even when support is false.
            bool permission = Permission(actual);
            float waterDepth = WaterLevel.GetWaterSurface(actual, true, true, null) - actual.y;
            Conditions(frame, actual, support, overlapClear, permission, waterDepth);
            bool environmentSafe = overlapClear && permission && Finite(waterDepth) && waterDepth <= 0.15f;
            bool currentSafe = environmentSafe && (acquiring ? AcquisitionSupported(actual, support) : Supported(support));
            if (!pending && !acquiring && !currentSafe && acquisitionEligible && actuations == 0 && environmentSafe &&
                AcquisitionFloor(support) && support.Gap > supportTolerance && support.Gap <= maxDrop && lastVelocity.sqrMagnitude == 0 &&
                (actual - lastPosition).sqrMagnitude == 0 && body.linearVelocity.sqrMagnitude == 0 && NavEpochMatches() &&
                !RustNavigation.Instance.HasPendingTiles() && agent.isOnNavMesh)
            {
                acquiring = true; acquisitionEligible = false; acquisitionStart = actual; acquisitionStartTime = now;
                acquisitionRestTime = now; acquisitionStartGap = support.Gap; acquisitionFloor = support.Collider;
                acquisitionRestClock = currentClock;
                acquisitionFloorY = support.FootY; acquisitionNormal = support.Normal; acquisitionPoint = support.Point;
                frame["SupportPhase"] = "FLOOR_ACQUISITION"; frame["Acquisition"] = AcquisitionRow(actual, support);
                frame["MotionMode"] = "FLOOR_ACQUISITION"; frame["NativeResult"] = "STATIONARY_OBSERVATION";
                frame["Classification"] = "CLEAR"; // Obstacle-clear observation; SupportAccepted remains false.
                frame["PosePrevious"] = P(lastPosition); frame["PosePreviousTime"] = lastTime;
                frame["ObservedVelocity"] = P((actual - lastPosition) / (float)(currentClock.FixedTime - previousClock.FixedTime));
                Emit("FLOOR_ACQUISITION_OBSERVE", frame);
                lastPosition = actual; lastTime = now; return; // No command on the observation tick.
            }
            if (!pending && !currentSafe)
            {
                if (!overlapClear) Emit("PHYSICAL_CONTACT", frame);
                Block(frame, !overlapClear ? "UNKNOWN" : "UNSUPPORTED_GAP", !overlapClear ? "CURRENT_OVERLAP" : !permission ? "CURRENT_PERMISSION" :
                    !Finite(waterDepth) || waterDepth > 0.15f ? "CURRENT_WATER" : acquiring ? "ACQUISITION_FLOOR_INVALID" : "CURRENT_SUPPORT"); return;
            }
            if (pending)
            {
                if (commandBraking) frame["Recovery"] = brakeReceipt;
                var observedSweeps = new List<object>();
                bool clear = Sweep(commandFrom, actual, support, observedSweeps);
                float elapsed = (float)(currentClock.FixedTime - commandClock.FixedTime);
                Vector3 velocity = (actual - commandFrom) / elapsed;
                float speed = velocity.magnitude, acceleration = (velocity - lastVelocity).magnitude / elapsed;
                frame["Command"] = command; frame["From"] = P(commandFrom); frame["Requested"] = P(commanded);
                frame["PreviousTime"] = commandTime; frame["Dt"] = elapsed;
                frame["FixedDt"] = currentClock.FixedTime - commandClock.FixedTime;
                frame["WallDt"] = currentClock.WallTime - commandClock.WallTime;
                frame["IssuedClock"] = ClockRow(commandClock);
                frame["Distance"] = Vector3.Distance(commandFrom, actual); frame["Speed"] = speed; frame["Acceleration"] = acceleration;
                frame["Sweeps"] = observedSweeps.ToArray(); frame["Classification"] = commandClass;
                frame["NativeResult"] = "OBSERVED";
                frame["MotionMode"] = commandAcquisition ? commandHold ? "ACQUISITION_BRAKE_HOLD" : "FLOOR_ACQUISITION" : commandHold ? "BRAKE_HOLD" : commandBraking ? "ACTUAL_BRAKE" : "SUPPORTED_ADVANCE";
                frame["ObservedVelocity"] = P(velocity);
                float nativeVelocityError = Vector3.Distance(body.linearVelocity, velocity);
                bool nativeVelocityMatches = Finite(body.linearVelocity) && nativeVelocityError <= Numerical;
                frame["NativeVelocityError"] = nativeVelocityError; frame["NativeVelocityMatches"] = nativeVelocityMatches;
                if (!currentSafe || commandBraking && !BrakeFloorCurrent(support) || !clear || elapsed <= 0 || elapsed > MaxTick || Vector3.Distance(actual, commanded) > Numerical ||
                    !Finite(speed) || speed > maxSpeed + Numerical || acceleration > MaxAcceleration + Numerical ||
                    !nativeVelocityMatches || currentClock.Sequence != commandClock.Sequence + 1 ||
                    Math.Abs(currentClock.FixedTime - commandClock.FixedTime - commandClock.Delta) > ClockPrecision ||
                    commandAcquisition && (actual.x != commandFrom.x || actual.z != commandFrom.z || actual.y > commandFrom.y))
                {
                    pending = false; pendingFrame = null; frame["NativeResult"] = "OBSERVED_UNSAFE";
                    Emit("MOTION_WITNESS", frame); if (!ControlCurrent()) return;
                    Emit("PHYSICAL_CONTACT", frame); if (!ControlCurrent()) return;
                    Block(frame, "UNKNOWN", commandBraking && !BrakeFloorCurrent(support) ? "BRAKE_SUPPORT_CHANGED" : !clear || !overlapClear ? "KINEMATIC_CLIP" : !currentSafe ? "ACTUAL_SUPPORT_OR_PERMISSION_LOST" :
                        !nativeVelocityMatches ? "NATIVE_VELOCITY_HORIZON_MISMATCH" : "ACTUATOR_DIVERGENCE_OR_CONTINUITY"); return;
                }
                string witnessClockProblem = ClockProblem(currentClock);
                if (witnessClockProblem != null) { Stop("CLOCK_BEFORE_WITNESS_ACCEPT:" + witnessClockProblem); return; }
                pending = false; pendingFrame = null;
                if (sessionGlobalDeadline.HasValue && commandBraking && ExactZero(velocity) && ExactZero(body.linearVelocity) && acceptedBrakeZeroBody == null) {
                    acceptedBrakeZeroBody = CaptureStationaryBody(); acceptedBrakeZeroSession = motionSession; acceptedBrakeZeroCommand = command;
                    acceptedBrakeZeroSequence = currentClock.Sequence;
                    frame["AcceptedBrakeZeroBody"] = StationaryBodyRow(acceptedBrakeZeroBody);
                }
                Emit("MOTION_WITNESS", frame);
                lastVelocity = velocity; lastPosition = actual; lastTime = now;
                if (!ControlCurrent()) return;
                if (currentClock.WallTime - previousClock.WallTime > MaxTick + ClockPrecision) {
                    Emit("SCHEDULER_LAG_ACCEPTED_PHYSICS_WITNESS", frame); if (!ControlCurrent()) return;
                }
                unchangedWitnesses = !commandHold && Vector3.Distance(actual, commandFrom) <= 0.00001f ? unchangedWitnesses + 1 : 0;
                if (unchangedWitnesses >= 3)
                { Block(frame, "UNKNOWN", "STUCK_ACTUAL_POSE"); return; }
                float dy = actual.y - commandFrom.y;
                if ((commandClass == "SMALL_STEP_UP" || commandClass == "STEP_DOWN" || commandClass == "SLOPE") && Mathf.Abs(dy) > Numerical)
                {
                    if (heightClass != commandClass) { heightClass = commandClass; heightWitnesses = 0; }
                    heightWitnesses++;
                    if (heightWitnesses == 2) { Emit("STEP_RESOLVED", frame); if (!ControlCurrent()) return; }
                }
                else { heightWitnesses = 0; heightClass = null; }
                if (commandBraking) { Emit("BRAKE_WITNESSED", frame); if (!ControlCurrent()) return; }
                // A command's witness is the only work that can precede the next
                // command; the initial decision below uses fresh sensor results.
            }
            if (braking && commandBraking && ExactZero(lastVelocity)) {
                AcknowledgeBrakeRest(frame, actual); return;
            }
            if (StationaryWaiting) {
                ObserveStationaryReplan(frame, support, overlaps.ToArray(), overlapClear, permission, waterDepth); return;
            }
            if (sessionGlobalDeadline.HasValue && stationary == null && sessionBaselineClock.HasValue && !braking && !acquiring &&
                command == sessionBaseCommand && actuations == sessionBaseActuations && ExactZero(lastVelocity) && ExactZero(body.linearVelocity)) {
                var readiness = ReadStationaryNative(null);
                if (!readiness.Ready || !NavEpochMatches()) {
                    if (!BeginStationaryReplan(frame, support, overlaps.ToArray(), overlapClear, permission, waterDepth)) { if (ControlCurrent()) Block(frame, "UNKNOWN", "STATIONARY_BASELINE_ENTRY_REFUSED"); return; }
                    ObserveStationaryReplan(frame, support, overlaps.ToArray(), overlapClear, permission, waterDepth); return;
                }
            }
            if (RustNavigation.Instance == null || RustNavigation.Instance.DefaultNavmesh == null ||
                !RustNavigation.Instance.IsDefaultNavmeshBuilt() || !agent.isOnNavMesh)
            { Block(frame, "UNKNOWN", "NAV_INVALIDATED"); return; }
            if (!NavEpochMatches())
            {
                frame["NavigationEpoch"] = new { OldChange = routeTileChangeVersion, OldData = routeTileDataVersion,
                    NewChange = RustNavigation.Instance.DefaultNavmesh.TileChangeVersion, NewData = RustNavigation.Instance.DefaultNavmesh.TileDataVersion };
                if (lastVelocity.sqrMagnitude != 0 || braking) {
                    RequestEpochBrake(frame, actual, support);
                    return;
                }
                if (retries++ >= 1 || !Plan(destination)) { Block(frame, "UNKNOWN", "NAV_EPOCH_REPATH_FAILED_OR_EXHAUSTED"); return; }
                frame["Navigation"] = NavigationRow(); frame["Reason"] = "NATIVE_NAV_EPOCH_CHANGED"; Emit("REPATH", frame);
                if (!ControlCurrent()) return;
            }
            if (diagnosticRecoveryQueued)
            {
                diagnosticRecoveryQueued = false;
                if (diagnosticRecoverySequence != currentClock.Sequence || pending || lastVelocity.sqrMagnitude == 0 || !currentSafe)
                { UnsafeBrake(frame, "DIAGNOSTIC_RECOVERY_WITNESS_CONTEXT_LOST"); return; }
                frame["Reason"] = "DIAGNOSTIC_PLANNED_REPLAN"; Emit("DIAGNOSTIC_REPLAN_CONSUMED", frame);
                if (!ControlCurrent()) return;
                RequestBrake(frame, "UNKNOWN", "DIAGNOSTIC_PLANNED_REPLAN"); return;
            }
            if (braking)
            {
                // Retain a genuinely accepted physical witness above, but never
                // turn a late recovery completion into rest/replan success.
                if (currentClock.WallTime - brakeClock.WallTime > MaxBrakeSeconds)
                { Block(frame, "UNKNOWN", "BRAKE_RECOVERY_TIME_BUDGET"); return; }
                IssueBrake(now, dt, actual); return;
            }
            if (acquiring)
            {
                if (lastVelocity.sqrMagnitude == 0 && Supported(support) && support.Gap <= skin + Numerical && commandAcquisition)
                {
                    frame["NativeResult"] = "OBSERVED"; frame["Reason"] = "ACTUAL_SUPPORTED_REST";
                    Emit("FLOOR_ACQUIRED", frame);
                    if (!ControlCurrent()) return;
                    acquiring = false; commandAcquisition = false;
                    // This is the one initial route binding after floor capture,
                    // not a new recovery/repath budget or a cached surface.
                    if (!Plan(destination)) { Block(frame, "UNKNOWN", "ACQUIRED_ROUTE_BINDING_FAILED"); return; }
                    var rebound = Frame(now, actual); rebound["Support"] = SupportRow(support); rebound["Overlaps"] = overlaps.ToArray();
                    Conditions(rebound, actual, support, overlapClear, permission, waterDepth);
                    rebound["Reason"] = "INITIAL_FLOOR_ACQUISITION_ROUTE_BINDING"; rebound["NativeResult"] = "ROUTE_REBOUND";
                    Emit("REPATH", rebound); return;
                }
                IssueAcquisition(now, dt, actual, support, overlaps, permission, waterDepth);
                return;
            }
            if (Vector3.Distance(actual, destination) <= 0.12f && lastVelocity.sqrMagnitude == 0)
            {
                active = false; arrived = true; blocked = false; reason = "ACTUAL_SUPPORTED_DESTINATION";
                frame["Reason"] = reason; Emit("ARRIVED", frame); return;
            }
            // Every native corner is approached with braking distance and a
            // measured stationary command. Only then may a new direction begin.
            // This deliberately chooses a conservative stop at corners instead
            // of inventing an instantaneous 90-degree velocity change.
            while (routeIndex < route.Count && Horizontal(route[routeIndex] - actual).magnitude < 0.12f && lastVelocity.magnitude <= Numerical) routeIndex++;
            if (routeIndex >= route.Count) { Block(frame, "UNKNOWN", "ROUTE_EXHAUSTED_BEFORE_ACTUAL_DESTINATION"); return; }
            Vector3 direction = Horizontal(route[routeIndex] - actual).normalized;
            supportDirection = direction;
            float remaining = Horizontal(route[routeIndex] - actual).magnitude;
            float horizontalAcceleration = MaxAcceleration * 0.5f; // Reserve vector budget for observed support height.
            float available = Mathf.Max(0, remaining - 0.08f);
            // v*dt + v^2/(2*a) <= available: include this issued segment in
            // braking distance rather than waiting until the stopping point.
            float safeSpeed = horizontalAcceleration * (Mathf.Sqrt(dt * dt + 2f * available / horizontalAcceleration) - dt);
            float targetSpeed = Mathf.Min(maxSpeed, safeSpeed);
            float proposedSpeed = Mathf.MoveTowards(Horizontal(lastVelocity).magnitude, targetSpeed, horizontalAcceleration * dt);
            if (remaining <= 0.12f && Horizontal(lastVelocity).magnitude <= horizontalAcceleration * dt) proposedSpeed = 0;
            float horizontalDistance = Mathf.Min(proposedSpeed * dt, Horizontal(route[routeIndex] - actual).magnitude);
            Vector3 requested = actual;
            SupportResult landing = null;
            bool candidate = false;
            // Shrink distance, never the body. Each retry is a fresh exact geometry query.
            for (int attempt = 0; attempt < 6; attempt++)
            {
                Vector3 probe = actual + direction * horizontalDistance;
                landing = Support(probe);
                if (landing.Found)
                {
                    // Preserve an existing safe gap, slowly settle toward the
                    // policy skin, and never fabricate support by snapping.
                    float gap = Mathf.Max(skin, support.Gap - MaxAcceleration * dt * dt * 0.25f);
                    // A body already exactly touching its floor needs no lift.
                    // Do not introduce artificial vertical impulse to reach skin.
                    if (support.Gap < skin) gap = Mathf.Max(0, support.Gap);
                    float y = landing.FootY + Mathf.Max(0, gap);
                    requested = new Vector3(probe.x, y, probe.z);
                    Vector3 velocity = (requested - actual) / dt;
                    // A small slope can exceed the full-vector speed ceiling by
                    // very little. Scale toward that ceiling before the coarse
                    // fallback; halving may instead require impossible braking.
                    // This changes only the next queried candidate, not a limit.
                    // Reserve the witness's Numerical speed margin for actual
                    // quantization; do not spend it on the planned command.
                    if (SupportedAt(landing, requested) && Mathf.Abs(requested.y - actual.y) <= (requested.y >= actual.y ? maxStep : maxDrop) &&
                        Finite(velocity) && velocity.magnitude > maxSpeed)
                    { horizontalDistance *= Mathf.Max(0f, maxSpeed - Numerical) / velocity.magnitude; continue; }
                    if (SupportedAt(landing, requested) && Mathf.Abs(requested.y - actual.y) <= (requested.y >= actual.y ? maxStep : maxDrop) &&
                        velocity.magnitude <= maxSpeed && (velocity - lastVelocity).magnitude / dt <= MaxAcceleration + Numerical)
                    { candidate = true; break; }
                }
                horizontalDistance *= 0.5f;
            }
            if (!candidate)
            { frame["Landing"] = landing == null ? null : SupportRow(landing); Obstacle(frame, "UNSUPPORTED_GAP", "NO_BOUNDED_SUPPORTED_TRAJECTORY"); return; }
            bool hold = Vector3.Distance(actual, requested) < 0.00001f && lastVelocity.magnitude <= MaxAcceleration * dt;
            if (hold) requested = actual; // Issue and witness exact rest, including vertical velocity.
            IssueSupportedMotion(now, dt, actual, requested, support, overlaps, overlapClear, permission, waterDepth, hold, false);
        }

        private void IssueSupportedMotion(float now, float dt, Vector3 actual, Vector3 requested, SupportResult support,
            List<object> overlaps, bool overlapClear, bool permission, float waterDepth, bool hold, bool brakingMotion)
        {
            var frame = Frame(now, actual);
            // Rebind the landing measurement to the final commanded pose rather
            // than retaining the exploratory same-height sphere-cast origin.
            var landing = Support(requested);
            if (!Supported(landing)) { frame["Landing"] = SupportRow(landing); Obstacle(frame, "UNSUPPORTED_GAP", "FINAL_LANDING_INVALID"); return; }
            var sweeps = new List<object>(); var landingOverlaps = new List<object>();
            bool sweptClear = Sweep(actual, requested, support, sweeps);
            bool endClear = Overlaps(requested, landing, landingOverlaps);
            string classification = Classify(actual, requested, support, landing);
            frame = Frame(now, actual);
            frame["From"] = P(actual); frame["Requested"] = P(requested); frame["Support"] = SupportRow(support);
            frame["Landing"] = SupportRow(landing); frame["Sweeps"] = sweeps.ToArray(); frame["Overlaps"] = overlaps.ToArray();
            Conditions(frame, actual, support, overlapClear, permission, waterDepth);
            frame["LandingOverlaps"] = landingOverlaps.ToArray(); frame["Classification"] = classification;
            frame["Dt"] = dt; frame["Distance"] = Vector3.Distance(actual, requested);
            frame["Speed"] = (requested - actual).magnitude / dt;
            frame["Acceleration"] = ((requested - actual) / dt - lastVelocity).magnitude / dt;
            frame["Command"] = command + 1;
            bool landingPermission = Permission(requested);
            float landingWater = WaterLevel.GetWaterSurface(requested, true, true, null) - requested.y;
            frame["LandingPermission"] = landingPermission; frame["LandingWaterDepth"] = landingWater;
            frame["LandingSupportAccepted"] = Supported(landing);
            if (brakingMotion) frame["Recovery"] = brakeReceipt;
            double probeSinkStarted = Time.realtimeSinceStartupAsDouble;
            Emit("OBSTACLE_PROBE", frame);
            double probeSinkSeconds = Time.realtimeSinceStartupAsDouble - probeSinkStarted;
            if (!ControlCurrent()) return;
            if (!sweptClear || !endClear || !landingPermission || !Finite(landingWater) || landingWater > 0.15f)
            {
                Emit("PHYSICAL_CONTACT", frame);
                if (!ControlCurrent()) return;
                Obstacle(frame, closedDoorHit ? "DOOR_CLOSED" : dynamicHit ? "DYNAMIC_BLOCKED" : "SOLID_BLOCKED", "FULL_VOLUME_OR_PERMISSION_BLOCKED"); return;
            }
            if (Vector3.Distance(actual, requested) < 0.00001f && !hold) { Block(frame, "UNKNOWN", "NO_PROGRESS"); return; }
            if (classification != "CLEAR") { Emit("STEP_ATTEMPT", frame); if (!ControlCurrent()) return; }
            if (evidence.Count >= MaxEvidence - 8) { Block(frame, "UNKNOWN", "EVIDENCE_BUDGET"); return; }
            string probeClockProblem = ClockProblem(currentClock);
            if (probeClockProblem != null) {
                frame["NativeAdmissionFailure"] = new { Reason = "CLOCK_AFTER_PROBE:" + probeClockProblem, ProbeSinkSeconds = probeSinkSeconds,
                    CheckedWall = Time.realtimeSinceStartupAsDouble, NativeQueryStarted = false };
                Block(frame, "UNKNOWN", "CLOCK_AFTER_PROBE:" + probeClockProblem); return;
            }
            if (!NavEpochMatches()) { Block(frame, "UNKNOWN", "NAV_EPOCH_CHANGED_DURING_PROBE"); return; }
            if (!PrepareNativeAdmission(frame, actual, requested)) { frame["ProbeSinkSeconds"] = probeSinkSeconds; Block(frame, "UNKNOWN", "NATIVE_ROUTE_ADMISSION:" + nativePathReason); return; }
            string issueClockProblem = ClockProblem(currentClock);
            if (issueClockProblem != null) { Block(frame, "UNKNOWN", "CLOCK_BEFORE_ISSUE:" + issueClockProblem); return; }
            if (!Finite(body.linearVelocity) || Vector3.Distance(body.linearVelocity, lastVelocity) > Numerical)
            { Block(frame, "UNKNOWN", "NATIVE_VELOCITY_BEFORE_ISSUE"); return; }
            frame["NativeResult"] = "PRECHECKED";
            frame["IssuedClock"] = ClockRow(currentClock);
            frame["MotionMode"] = hold ? "BRAKE_HOLD" : brakingMotion ? "ACTUAL_BRAKE" : "SUPPORTED_ADVANCE";
            frame["DecisionPublishedWall"] = Time.realtimeSinceStartupAsDouble;
            if (!PublishDecision(frame, actual, requested)) return;
            if (!NativeAdmissionCurrent(actual, requested, true)) { RejectNativeIntent(frame, "NATIVE_ROUTE_CHANGED_BEFORE_WRITER"); return; }
            frame["FinalAdmission"] = finalNativeAdmission;
            command++; commanded = requested; commandFrom = actual; commandTime = now; commandClass = classification; commandHold = hold; commandAcquisition = false; commandBraking = brakingMotion;
            commandClock = currentClock;
            pendingFrame = Copy(frame); pending = true;
            // This is the sole position actuator. No native collision response is
            // assumed; full pre-query and next-tick actual geometry are mandatory.
            // Subtract first to avoid cancellation of large world coordinates.
            body.MovePosition(body.position + (requested - actual)); actuations++;
            PublishNativeIssue(frame);
            acquisitionEligible = false;
            lastPosition = actual; lastTime = now;
        }

        private object RecoveryRow(object[] corridor = null, float required = 0)
        {
            return new { Kind = RecoveryPolicy, Trigger = brakeReason, Session = motionSession, Attempt = recoveryAttempts, StartSequence = brakeClock.Sequence, StartWall = brakeClock.WallTime,
                StartPosition = P(brakeOrigin), StartVelocity = P(brakeVelocity), Step = brakeStep, MaxSteps = MaxBrakeSteps, MaxSeconds = MaxBrakeSeconds,
                Deceleration = BrakeAcceleration, Floor = brakeFloor == null ? 0 : brakeFloor.GetInstanceID(),
                FloorCenter = P(brakeFloorCenter), FloorSize = P(brakeFloorSize), FloorCollider = brakeFloorRow, Corridor = corridor ?? new object[0], RequiredDistance = required };
        }

        private void UnsafeBrake(Dictionary<string, object> frame, string why)
        {
            frame["Recovery"] = brakeReceipt ?? RecoveryRow(); frame["Reason"] = why;
            frame["NativeResult"] = "NOT_ISSUED"; frame["RetainedVelocity"] = P(lastVelocity);
            Emit("BLOCKED_UNSAFE_BRAKING", frame);
            braking = false;
            if (!ControlCurrent()) return;
            Block(frame, "UNKNOWN", "NO_SAFE_BRAKING_TRAJECTORY:" + why);
        }

        private void RequestBrake(Dictionary<string, object> frame, string classification, string why)
        {
            if (!ControlCurrent()) return;
            if (braking || recoveryAttempts != 0 || acquiring || !clockContext || pending || !NavEpochMatches())
            { UnsafeBrake(frame, "RECOVERY_CONTEXT_OR_BUDGET_EXHAUSTED"); return; }
            CaptureBrakeContext(classification, why, Support(npc.transform.position));
            frame["Recovery"] = brakeReceipt; frame["Reason"] = "ROUTE_NO_SAFE_CANDIDATE:" + why; Emit("BRAKE_REQUESTED", frame);
            if (!ControlCurrent()) return;
            braking = true;
            IssueBrake((float)currentClock.WallTime, currentClock.Delta, brakeOrigin);
        }

        private void CaptureBrakeContext(string classification, string why, SupportResult support)
        {
            brakeClock = currentClock; brakeOrigin = npc.transform.position; brakeVelocity = lastVelocity;
            brakeStep = 0; recoveryAttempts++; brakeClassification = classification; brakeReason = why;
            brakeFloor = support.Collider;
            if (brakeFloor != null) { brakeFloorCenter = brakeFloor.bounds.center; brakeFloorSize = brakeFloor.bounds.size; }
            brakeFloorFingerprint = BrakeFloorFingerprint(brakeFloor); brakeFloorRow = ColliderRow(brakeFloor);
            brakeReceipt = RecoveryRow();
        }

        private void RequestEpochBrake(Dictionary<string, object> frame, Vector3 actual, SupportResult support)
        {
            if (!ControlCurrent()) return;
            bool starts = !braking;
            if (epochProofAttempts >= MaxBrakeSteps || lastEpochAttemptSequence == currentClock.Sequence || acquiring || !clockContext || pending ||
                ExactZero(lastVelocity) || ClockProblem(currentClock) != null || commandClock.Sequence + 1 != currentClock.Sequence ||
                (starts ? recoveryAttempts != 0 : recoveryAttempts != 1 || !commandBraking || brakeStep < 1 || brakeStep >= MaxBrakeSteps ||
                    currentClock.Sequence != brakeClock.Sequence + brakeStep || currentClock.WallTime - brakeClock.WallTime > MaxBrakeSeconds))
            { UnsafeBrake(frame, "EPOCH_PROOF_CONTEXT_OR_BUDGET_EXHAUSTED"); return; }
            if (starts) CaptureBrakeContext("UNKNOWN", "NATIVE_EPOCH_REVALIDATED_BRAKE", support);
            epochProofAttempts++; lastEpochAttemptSequence = currentClock.Sequence;
            var p = new NativeEpochProof { Mesh = routeMesh, Handle = routeMeshHandle, Session = motionSession, Command = command, Index = routeIndex,
                OldChange = routeTileChangeVersion, OldData = routeTileDataVersion, Filter = routeFilter, From = routeFrom, Goal = destination,
                Actual = actual, Velocity = lastVelocity, NativeVelocity = body.linearVelocity, Corners = route.ToArray(), Polys = routePolys.ToArray(),
                CommittedPlan = routePlanLegs, Started = Time.realtimeSinceStartupAsDouble, RouteStarted = startWallTime, Clock = currentClock,
                Body = BodyRow(), Floor = brakeFloor, FloorCenter = brakeFloorCenter, FloorSize = brakeFloorSize,
                FloorFingerprint = brakeFloorFingerprint, FloorRow = brakeFloorRow, Anchor = support, StartsBrake = starts, BeforeStep = brakeStep,
                Ordinal = epochProofAttempts, PreviousOrdinal = epochProof == null ? 0 : epochProof.Ordinal,
                PreviousCommand = epochProof == null ? 0 : epochProof.Command, PreviousSequence = epochProof == null ? 0 : epochProof.Clock.Sequence,
                PreviousCompleted = epochProof == null ? 0 : epochProof.Completed, PriorChange = AdmissionChange, PriorData = AdmissionData,
                BrakeClock = brakeClock, BrakeOrigin = brakeOrigin, BrakeVelocity = brakeVelocity, RecoveryAttempt = recoveryAttempts };
            string failure = null;
            try { if (!PrepareEpochProof(p)) failure = p.Failure ?? nativePathReason; }
            catch (Exception ex) { failure = "EPOCH_NATIVE_EXCEPTION:" + ex.GetType().Name; }
            if (failure != null) { RefuseEpochProof(frame, p, failure); return; }
            braking = true;
            IssueBrake((float)currentClock.WallTime, currentClock.Delta, actual, p);
        }

        private bool EpochProofContextMatches(NativeEpochProof p)
        {
            return ControlCurrent() && p != null && p.Session == motionSession && p.Mesh == routeMesh && p.Handle == routeMeshHandle &&
                p.OldChange == routeTileChangeVersion && p.OldData == routeTileDataVersion && p.Filter == routeFilter && p.Index == routeIndex &&
                p.CommittedPlan == routePlanLegs && p.RouteStarted == startWallTime && p.RecoveryAttempt == recoveryAttempts &&
                p.BrakeClock.Sequence == brakeClock.Sequence && p.BrakeClock.WallTime == brakeClock.WallTime && p.BrakeClock.FixedTime == brakeClock.FixedTime &&
                (p.BrakeOrigin - brakeOrigin).sqrMagnitude == 0 && (p.BrakeVelocity - brakeVelocity).sqrMagnitude == 0 && (p.From - routeFrom).sqrMagnitude == 0 &&
                (p.Goal - destination).sqrMagnitude == 0 && p.Polys.SequenceEqual(routePolys) && p.Corners.SequenceEqual(route) &&
                p.Floor != null && p.Floor.attachedRigidbody == null && p.Floor == brakeFloor && BrakeFloorFingerprint(p.Floor) == p.FloorFingerprint &&
                (p.Floor.bounds.center - p.FloorCenter).sqrMagnitude == 0 && (p.Floor.bounds.size - p.FloorSize).sqrMagnitude == 0;
        }

        private bool EpochNativeStateCurrent(NativeEpochProof p, bool initial)
        {
            var nav = RustNavigation.Instance;
            p.OriginalObjectMatched = p.Mesh == routeMesh; p.CurrentObjectMatched = nav != null && nav.DefaultNavmesh == p.Mesh;
            if (!EpochProofContextMatches(p) || nav == null || nav.DefaultNavmesh != p.Mesh || p.Handle == IntPtr.Zero ||
                p.Mesh.NavMeshHandle != p.Handle || !nav.IsDefaultNavmeshBuilt() || !agent.isOnNavMesh || agent.npcDoorsWillOpen != p.Filter ||
                p.Mesh.TileChangeVersion != p.Change || p.Mesh.TileDataVersion != p.Data || BodyProblem() != null || ClockProblem(currentClock) != null) return false;
            var build = p.Mesh.BuildParams;
            if (build.agentMaxClimb != navClimb || build.agentMaxSlope != navSlope || build.agentRadius != navRadius || build.agentHeight != navHeight) return false;
            return !initial || currentClock.Sequence == p.Clock.Sequence && (npc.transform.position - p.Actual).sqrMagnitude == 0 &&
                (lastVelocity - p.Velocity).sqrMagnitude == 0 && (body.linearVelocity - p.NativeVelocity).sqrMagnitude == 0;
        }

        private object[] EpochRefs(RustNavmesh mesh, ulong[] refs, out bool valid)
        {
            var rows = new List<object>(); valid = true;
            foreach (var r in refs) { bool current = r != 0 && mesh.IsValidPolyRef(r); valid &= current; rows.Add(new { Ref = r.ToString(), Valid = current }); }
            return rows.ToArray();
        }

        private bool PrepareEpochProof(NativeEpochProof p)
        {
            p.Failure = "EPOCH_COMMITTED_CONTEXT_UNKNOWN";
            var nav = RustNavigation.Instance;
            if (p.Mesh == null || nav == null || nav.DefaultNavmesh != p.Mesh || p.Handle == IntPtr.Zero || p.Mesh.NavMeshHandle != p.Handle ||
                p.CommittedPlan.Length != 1 || p.Polys.Length == 0 || p.Polys.Length >= NativePathCapacity || p.Index < 1 || p.Index >= p.Corners.Length ||
                !BrakeFloorCurrent(p.Anchor)) return false;
            p.Change = p.Mesh.TileChangeVersion; p.Data = p.Mesh.TileDataVersion; p.PendingBefore = nav.HasPendingTiles();
            var build = p.Mesh.BuildParams; p.BuildBefore = new { Climb = build.agentMaxClimb, Slope = build.agentMaxSlope, Radius = build.agentRadius, Height = build.agentHeight };
            if (!EpochNativeStateCurrent(p, true)) return false;
            RustNavMeshPath original, actorOriginal, current, actorCurrent;
            p.Failure = "EPOCH_ORIGINAL_NATIVE_QUERY";
            if (!ReadNativePath(p.Mesh, p.From, p.Goal, p.Filter, out original, out actorOriginal)) return false;
            p.OriginalQuery = NativePlanLeg(p.Mesh, p.From, p.Goal, p.Filter, p.Change, p.Data, original, actorOriginal);
            bool oldValid, currentValid; p.OldRefsBefore = EpochRefs(p.Mesh, p.Polys, out oldValid);
            p.Failure = "EPOCH_COMMITTED_GEOMETRY_CHANGED";
            if (!original.polyRefs.Take(original.polyRefCount).SequenceEqual(p.Polys) || !original.corners.Select(c => c.Value).SequenceEqual(p.Corners) ||
                !oldValid) return false;
            p.Failure = "EPOCH_CURRENT_NATIVE_QUERY";
            if (!ReadNativePath(p.Mesh, p.Actual, p.Goal, p.Filter, out current, out actorCurrent)) return false;
            p.CurrentQuery = NativePlanLeg(p.Mesh, p.Actual, p.Goal, p.Filter, p.Change, p.Data, current, actorCurrent);
            p.CurrentPolys = current.polyRefs.Take(current.polyRefCount).ToArray(); p.CurrentCorners = current.corners.Select(c => c.Value).ToArray();
            p.CurrentRefsBefore = EpochRefs(p.Mesh, p.CurrentPolys, out currentValid); p.Suffix = p.Polys.Length - p.CurrentPolys.Length;
            p.Failure = "EPOCH_CURRENT_COMMITTED_SUFFIX_CHANGED";
            if (!currentValid || p.Suffix < 0 || !p.Polys.Skip(p.Suffix).SequenceEqual(p.CurrentPolys) || !p.Corners.Skip(p.Index).SequenceEqual(p.CurrentCorners.Skip(1))) return false;
            p.NativeCompleted = Time.realtimeSinceStartupAsDouble; p.PendingAfterNative = nav.HasPendingTiles();
            p.Failure = "EPOCH_CHANGED_DURING_NATIVE_PROOF";
            return EpochNativeStateCurrent(p, true);
        }

        private bool EpochCorridorOnFirstLeg(NativeEpochProof p, Vector3[] points)
        {
            var leg = Horizontal(p.CurrentCorners[1] - p.Actual); float length = leg.magnitude;
            if (length <= Numerical || points.Length < 3) return false;
            foreach (var point in points) {
                var delta = Horizontal(point - p.Actual); float along = Vector3.Dot(delta, leg.normalized);
                if (along < -Numerical || along > length + Numerical || (delta - leg.normalized * along).magnitude > Numerical) return false;
            }
            return true;
        }

        private object EpochProofRow(NativeEpochProof p, bool accepted, string phase)
        {
            return new { Kind = "SAME_COMMITTED_ROUTE_EPOCH_V2", Accepted = accepted, Phase = phase, Actor = actor, World = world, Session = p.Session,
                Attempt = p.Ordinal, Ordinal = p.Ordinal, MaxAttempts = MaxBrakeSteps, StartsBrake = p.StartsBrake, BeforeStep = p.BeforeStep, NextStep = p.BeforeStep + 1,
                PreviousOrdinal = p.PreviousOrdinal, PreviousCommand = p.PreviousCommand, PreviousSequence = p.PreviousSequence, PreviousCompletedWall = p.PreviousCompleted,
                PreviousAdmissionChange = p.PriorChange, PreviousAdmissionData = p.PriorData, BrakeClock = ClockRow(p.BrakeClock),
                BrakeOrigin = P(p.BrakeOrigin), BrakeVelocity = P(p.BrakeVelocity), RecoveryAttempt = p.RecoveryAttempt,
                Command = p.Command, Clock = ClockRow(p.Clock), StartedWall = p.Started, NativeCompletedWall = p.NativeCompleted, CompletedWall = p.Completed,
                Mesh = p.Handle.ToString(), OriginalObjectMatched = p.OriginalObjectMatched, CurrentObjectMatched = p.CurrentObjectMatched,
                ControlActive = active, ControlBlocked = blocked, ControlArrived = arrived, UnobservedTerminal = unobservedTerminal,
                OldChange = p.OldChange, OldData = p.OldData, NewChange = p.Change, NewData = p.Data, Filter = p.Filter, OriginalIndex = p.Index,
                RouteStartedWall = p.RouteStarted, From = P(p.From), Goal = P(p.Goal), Actual = P(p.Actual), Velocity = P(p.Velocity), NativeVelocity = P(p.NativeVelocity),
                CommittedPlan = p.CommittedPlan, CommittedPolys = p.Polys.Select(r => r.ToString()).ToArray(), CommittedCorners = p.Corners.Select(P).ToArray(),
                OriginalQuery = p.OriginalQuery, CurrentQuery = p.CurrentQuery, CurrentSuffix = p.Suffix, OldRefsBefore = p.OldRefsBefore, OldRefsAfter = p.OldRefsAfter,
                CurrentRefsBefore = p.CurrentRefsBefore, CurrentRefsAfter = p.CurrentRefsAfter, GlobalPendingBefore = p.PendingBefore, GlobalPendingAfterNative = p.PendingAfterNative,
                GlobalPendingAtSeal = p.PendingAtSeal, BuildBefore = p.BuildBefore, BuildAfter = p.BuildAfter, Body = p.Body, Floor = p.FloorRow, FloorCenter = P(p.FloorCenter), FloorSize = P(p.FloorSize),
                Anchor = SupportRow(p.Anchor), RequiredDistance = p.Required, Corridor = p.Corridor, CorridorPoints = p.CorridorPoints == null ? null : p.CorridorPoints.Select(P).ToArray() };
        }

        private void RefuseEpochProof(Dictionary<string, object> frame, NativeEpochProof p, string why)
        {
            p.Completed = Time.realtimeSinceStartupAsDouble; p.Row = EpochProofRow(p, false, why);
            RecordEpochProof(p);
            frame["EpochRevalidation"] = p.Row; UnsafeBrake(frame, why);
        }

        private void RecordEpochProof(NativeEpochProof p)
        {
            if (epochProofJournal.Count != p.Ordinal - 1 || epochProofJournal.Count >= MaxBrakeSteps) throw new InvalidOperationException("EPOCH_JOURNAL_BUDGET_OR_ORDER");
            epochProofJournal.Add(p.Row); // Flat immutable rows, never a nested previous-proof object.
        }

        private void AcknowledgeBrakeRest(Dictionary<string, object> frame, Vector3 actual)
        {
            var r = new BrakeRestContext { Session = motionSession, Step = brakeStep, Attempt = recoveryAttempts, Command = command,
                Clock = currentClock, StartClock = brakeClock, Actual = actual, RigidbodyPosition = body.position, Goal = destination,
                Origin = brakeOrigin, Velocity = brakeVelocity, FrozenBody = sessionGlobalDeadline.HasValue && acceptedBrakeZeroSession == motionSession &&
                    acceptedBrakeZeroCommand == command && acceptedBrakeZeroSequence == currentClock.Sequence ? acceptedBrakeZeroBody : null };
            if (!braking || !commandBraking || !RestContextCurrent(r, "REST_ACK")) {
                frame["RestReplanGuard"] = r.LastGuard; BlockRest(frame, "BRAKE_REST_CONTEXT_UNCERTAIN"); return;
            }
            r.Admission = new { Policy = "EXACT_BRAKE_REST_V1", Session = r.Session, Command = r.Command, Step = r.Step, Attempt = r.Attempt,
                Clock = ClockRow(r.Clock), BrakeClock = ClockRow(r.StartClock), Actual = P(r.Actual), RigidbodyPosition = P(r.RigidbodyPosition),
                Goal = P(r.Goal), BrakeOrigin = P(r.Origin), BrakeVelocity = P(r.Velocity), Floor = brakeFloorRow, Guard = r.LastGuard, FrozenBody = StationaryBodyRow(r.FrozenBody) };
            frame["RestAdmission"] = r.Admission; frame["Recovery"] = brakeReceipt; frame["Reason"] = "MEASURED_SUPPORTED_NATIVE_REST";
            Emit("ACTUAL_REST", frame);
            if (!RestContextCurrent(r, "AFTER_REST_SINK")) {
                frame["RestReplanGuard"] = r.LastGuard; BlockRest(frame, "BRAKE_REST_CHANGED_AFTER_SINK"); return;
            }
            bool freshPlan = epochProofJournal.Count != 0 || !NavEpochMatches() || brakeReason == "DIAGNOSTIC_PLANNED_REPLAN";
            if (freshPlan && sessionGlobalDeadline.HasValue) {
                var current = Support(actual); var contacts = new List<object>(); bool clear = Overlaps(actual, current, contacts);
                bool permission = Permission(actual); float water = WaterLevel.GetWaterSurface(actual, true, true, null) - actual.y;
                if (!clear || !permission || !Finite(water) || water > 0.15f || !BeginStationaryReplan(frame, current, contacts.ToArray(), clear, permission, water, r)) {
                    if (ControlCurrent()) BlockRest(frame, "STATIONARY_BRAKE_REST_ENTRY_REFUSED"); return;
                }
                ObserveStationaryReplan(frame, current, contacts.ToArray(), clear, permission, water); return;
            }
            braking = commandBraking = false; replanAfterRest = true;
            if (freshPlan) {
                bool planned = Plan(r.Goal, r);
                if (!planned) RestContextCurrent(r, "REST_PLAN_REFUSED");
                frame["RestReplan"] = new { Kind = "PLAN", Accepted = planned, Guard = r.LastGuard, Time = Time.realtimeSinceStartupAsDouble };
                if (!planned) { BlockRest(frame, "BRAKE_REST_NATIVE_REPLAN_INVALID"); return; }
                frame["Navigation"] = NavigationRow(); frame["Reason"] = brakeReason;
                Emit("REPATH_AFTER_REST", frame); if (!ControlCurrent()) return;
                replanAfterRest = false; Emit("REPATH", frame); return;
            }
            Obstacle(frame, brakeClassification, brakeReason, r);
        }

        private void BlockRest(Dictionary<string, object> frame, string why)
        {
            frame["NativeResult"] = "NOT_ISSUED"; frame["WriterCalled"] = false; frame["PendingDecision"] = null;
            Block(frame, "UNKNOWN", why);
        }

        private bool RestContextCurrent(BrakeRestContext r, string phase)
        {
            var actual = npc.transform.position; var rigid = body.position; var native = body.linearVelocity;
            bool bodyValid = BodyProblem() == null;
            bool context = ControlCurrent() && r.Session == motionSession && r.Command == command && r.Step == brakeStep && r.Attempt == recoveryAttempts && r.Attempt == 1 &&
                r.Step >= 1 && r.Step <= MaxBrakeSteps && !pending && commandClock.Sequence + 1 == currentClock.Sequence &&
                r.Clock.Sequence == currentClock.Sequence && currentClock.Sequence == brakeClock.Sequence + brakeStep &&
                r.StartClock.Sequence == brakeClock.Sequence && r.StartClock.WallTime == brakeClock.WallTime &&
                (r.Origin - brakeOrigin).sqrMagnitude == 0 && (r.Velocity - brakeVelocity).sqrMagnitude == 0 && (r.Goal - destination).sqrMagnitude == 0 &&
                (actual - r.Actual).sqrMagnitude == 0 && (rigid - r.RigidbodyPosition).sqrMagnitude == 0 && ExactZero(lastVelocity) && ExactZero(native) && bodyValid &&
                (!sessionGlobalDeadline.HasValue || SameStationaryBody(r.FrozenBody));
            SupportResult support = null; var overlaps = new List<object>(); bool clear = false, floor = false, permission = false; float? water = null;
            if (context) {
                support = Support(actual); clear = Overlaps(actual, support, overlaps); floor = BrakeFloorCurrent(support);
                permission = Permission(actual); water = WaterLevel.GetWaterSurface(actual, true, true, null) - actual.y;
            }
            bool clock = ClockProblem(currentClock) == null && currentClock.WallTime - brakeClock.WallTime <= MaxBrakeSeconds &&
                currentClock.FixedTime - brakeClock.FixedTime <= MaxBrakeSeconds;
            bool unchanged = ControlCurrent() && (npc.transform.position - r.Actual).sqrMagnitude == 0 && (body.position - r.RigidbodyPosition).sqrMagnitude == 0 &&
                ExactZero(body.linearVelocity) && ExactZero(lastVelocity) && BodyProblem() == null &&
                (!sessionGlobalDeadline.HasValue || SameStationaryBody(r.FrozenBody)) &&
                brakeFloor != null && brakeFloor.attachedRigidbody == null && BrakeFloorFingerprint(brakeFloor) == brakeFloorFingerprint &&
                (brakeFloor.bounds.center - brakeFloorCenter).sqrMagnitude == 0 && (brakeFloor.bounds.size - brakeFloorSize).sqrMagnitude == 0;
            double checkedWall = Time.realtimeSinceStartupAsDouble;
            bool accepted = context && clear && floor && permission && water.HasValue && Finite(water.Value) && water.Value <= 0.15f && clock && unchanged &&
                checkedWall >= r.Clock.WallTime && checkedWall - r.Clock.WallTime <= MaxTick;
            r.LastGuard = new { Policy = "EXACT_BRAKE_REST_V1", Phase = phase, Accepted = accepted, Session = r.Session, Command = r.Command, Step = r.Step,
                CheckedWall = checkedWall, Clock = ClockRow(r.Clock), Actual = P(npc.transform.position), RigidbodyPosition = P(body.position),
                NativeVelocity = P(body.linearVelocity), MeasuredVelocity = P(lastVelocity), BodyValid = bodyValid, ContextMatched = context,
                AcceptedBrakeZeroBody = StationaryBodyRow(r.FrozenBody), CurrentFrozenBody = sessionGlobalDeadline.HasValue ? StationaryBodyRow(CaptureStationaryBody()) : null,
                ControlActive = active, ControlBlocked = blocked, ControlArrived = arrived, UnobservedTerminal = unobservedTerminal,
                QueriesExecuted = context, FloorCurrent = context ? (bool?)floor : null, Support = support == null ? null : SupportRow(support), Overlaps = overlaps.ToArray(),
                OverlapClear = context ? (bool?)clear : null, Permission = context ? (bool?)permission : null, WaterDepth = water, ClockAccepted = clock, Unchanged = unchanged };
            return accepted;
        }

        private bool BrakeFloorCurrent(SupportResult s)
        {
            var entity = brakeFloor == null ? null : brakeFloor.GetComponentInParent<BaseEntity>();
            return brakeFloor != null && brakeFloor.attachedRigidbody == null && !(entity is Door) && !(entity is BasePlayer) && !(entity is BaseVehicle) &&
                s.Collider == brakeFloor && Supported(s) &&
                BrakeFloorFingerprint(brakeFloor) == brakeFloorFingerprint &&
                brakeFloor.bounds.center == brakeFloorCenter && brakeFloor.bounds.size == brakeFloorSize;
        }

        private string BrakeFloorFingerprint(Collider c)
        {
            if (c == null) return null;
            var entity = c.GetComponentInParent<BaseEntity>();
            return c.GetInstanceID() + "|" + c.GetType().FullName + "|" + c.gameObject.layer + "|" + c.enabled + "|" + c.isTrigger + "|" +
                (entity == null ? "STATIC" : entity.GetType().FullName + ":" + (entity.net == null ? "NO_NET" : entity.net.ID.Value.ToString()) + ":" + entity.OwnerID + ":" + entity.PrefabName);
        }

        // No support projection is used to manufacture a new velocity. Each
        // candidate follows the measured three-dimensional momentum and reduces
        // it by 3m/s², leaving the original 4m/s² bound for float quantization.
        private bool CheckBrakeCorridor(Vector3 actual, float dt, out Vector3 requested, out object[] corridor, out float required, out Vector3[] corridorPoints)
        {
            requested = actual; required = lastVelocity.sqrMagnitude / (2f * BrakeAcceleration) + lastVelocity.magnitude * dt + skin;
            var points = new List<Vector3> { actual }; corridorPoints = new Vector3[0];
            var rows = new List<object>(); corridor = new object[0];
            Vector3 position = actual, velocity = lastVelocity; float length = 0; bool stopped = false;
            for (int i = 0; i < MaxBrakeSteps - brakeStep; i++)
            {
                Vector3 nextVelocity = Vector3.MoveTowards(velocity, Vector3.zero, BrakeAcceleration * dt);
                Vector3 next = position + nextVelocity * dt;
                Vector3 measured = (next - position) / dt;
                if (!Finite(measured) || measured.magnitude >= velocity.magnitude || measured.magnitude > maxSpeed ||
                    (measured - velocity).magnitude / dt > MaxAcceleration + Numerical || Vector3.Dot(measured, lastVelocity) < 0 ||
                    currentClock.FixedTime - brakeClock.FixedTime + (i + 1) * dt > MaxBrakeSeconds)
                    return false;
                object row;
                points.Add(next);
                if (!BrakeSegment(position, next, velocity, measured, dt, "DECELERATION", out row)) { rows.Add(row); corridor = rows.ToArray(); corridorPoints = points.ToArray(); return false; }
                rows.Add(row); length += Vector3.Distance(position, next);
                if (i == 0) requested = next;
                position = next; velocity = measured;
                if (velocity.sqrMagnitude == 0) { stopped = true; break; }
            }
            if (!stopped) { corridor = rows.ToArray(); return false; }
            // Include v²/2a + one future dt + native skin, rather than checking
            // only the first deceleration point and discovering a wall too late.
            Vector3 reserve = position + lastVelocity.normalized * (Mathf.Max(0, required - length) + Numerical);
            object reserveRow;
            bool clear = BrakeSegment(position, reserve, Vector3.zero, Vector3.zero, dt, "RESERVE", out reserveRow);
            rows.Add(reserveRow); corridor = rows.ToArray(); points.Add(reserve); corridorPoints = points.ToArray();
            return clear && length + Vector3.Distance(position, reserve) + Numerical >= required;
        }

        private bool BrakeSegment(Vector3 from, Vector3 to, Vector3 prior, Vector3 velocity, float dt, string kind, out object row)
        {
            var support = Support(from); var landing = Support(to);
            var overlaps = new List<object>(); var landingOverlaps = new List<object>(); var sweeps = new List<object>();
            bool currentClear = Overlaps(from, support, overlaps), endClear = Overlaps(to, landing, landingOverlaps);
            bool sweptClear = Sweep(from, to, support, sweeps), permission = Permission(from), landingPermission = Permission(to);
            float water = WaterLevel.GetWaterSurface(from, true, true, null) - from.y, landingWater = WaterLevel.GetWaterSurface(to, true, true, null) - to.y;
            row = new { Kind = kind, From = P(from), Requested = P(to), PriorVelocity = P(prior), Velocity = P(velocity), Dt = dt,
                Support = SupportRow(support), Landing = SupportRow(landing), Sweeps = sweeps.ToArray(), Overlaps = overlaps.ToArray(), LandingOverlaps = landingOverlaps.ToArray(),
                Permission = permission, WaterDepth = water, SupportAccepted = Supported(support), OverlapClear = currentClear,
                LandingPermission = landingPermission, LandingWaterDepth = landingWater, LandingSupportAccepted = Supported(landing) };
            return BrakeFloorCurrent(support) && BrakeFloorCurrent(landing) && currentClear && endClear && sweptClear && permission && landingPermission &&
                Finite(water) && water <= 0.15f && Finite(landingWater) && landingWater <= 0.15f &&
                Mathf.Abs(to.y - from.y) <= (to.y >= from.y ? maxStep : maxDrop);
        }

        private void IssueBrake(float now, float dt, Vector3 actual, NativeEpochProof staged = null)
        {
            var frame = Frame(now, actual);
            if (!braking || pending || brakeStep >= MaxBrakeSteps || currentClock.Sequence != brakeClock.Sequence + brakeStep ||
                currentClock.WallTime - brakeClock.WallTime > MaxBrakeSeconds || (staged == null ? !NavEpochMatches() : !EpochNativeStateCurrent(staged, true)) || !Finite(lastVelocity) || lastVelocity.sqrMagnitude == 0 ||
                !Finite(body.linearVelocity) || Vector3.Distance(body.linearVelocity, lastVelocity) > Numerical)
            { if (staged != null) RefuseEpochProof(frame, staged, "EPOCH_BRAKE_CONTEXT_CHANGED_OR_EXHAUSTED"); else UnsafeBrake(frame, "BRAKE_CONTEXT_CHANGED_OR_EXHAUSTED"); return; }
            supportDirection = Horizontal(lastVelocity).normalized;
            Vector3 requested; object[] corridor; float required; Vector3[] corridorPoints;
            bool clear = CheckBrakeCorridor(actual, dt, out requested, out corridor, out required, out corridorPoints);
            if (staged != null) { staged.Corridor = corridor; staged.CorridorPoints = corridorPoints; staged.Required = required; }
            if (!clear) { brakeReceipt = RecoveryRow(corridor, required); if (staged != null) RefuseEpochProof(frame, staged, "BRAKE_INSUFFICIENT_SUPPORTED_SPACE"); else UnsafeBrake(frame, "BRAKE_INSUFFICIENT_SUPPORTED_SPACE"); return; }
            if (staged == null) brakeStep++;
            brakeReceipt = RecoveryRow(corridor, required);
            var support = Support(actual); var overlaps = new List<object>(); bool overlapClear = Overlaps(actual, support, overlaps);
            bool permission = Permission(actual); float water = WaterLevel.GetWaterSurface(actual, true, true, null) - actual.y;
            if (!BrakeFloorCurrent(support) || !overlapClear || !permission || !Finite(water) || water > 0.15f)
            { if (staged != null) RefuseEpochProof(frame, staged, "BRAKE_CURRENT_GEOMETRY_CHANGED"); else UnsafeBrake(frame, "BRAKE_CURRENT_GEOMETRY_CHANGED"); return; }
            if (staged != null) {
                if (!SealEpochProof(staged)) { RefuseEpochProof(frame, staged, staged.Failure); return; }
                RecordEpochProof(staged);
                epochProof = staged; nativeAdmission = null;
                frame["EpochRevalidation"] = staged.Row; frame["Navigation"] = NavigationRow(); frame["Recovery"] = brakeReceipt; frame["Support"] = SupportRow(support); frame["Overlaps"] = overlaps.ToArray();
                Conditions(frame, actual, support, overlapClear, permission, water);
                frame["WriterCalled"] = false; frame["UnobservedCommand"] = false; frame["PendingDecision"] = null;
                frame["Reason"] = "SAME_COMMITTED_ROUTE_BRAKE_ONLY"; frame["NativeResult"] = "REVALIDATED"; Emit("NATIVE_ROUTE_EPOCH_REVALIDATED", frame);
                if (!ControlCurrent()) return;
                if (staged.StartsBrake) { frame["Reason"] = "ROUTE_NO_SAFE_CANDIDATE:NATIVE_EPOCH_REVALIDATED_BRAKE"; Emit("BRAKE_REQUESTED", frame); }
                if (!ControlCurrent()) return;
                brakeStep++; brakeReceipt = RecoveryRow(corridor, required);
            }
            IssueSupportedMotion(now, dt, actual, requested, support, overlaps, overlapClear, permission, water, (requested - actual).sqrMagnitude == 0, true);
        }

        private bool SealEpochProof(NativeEpochProof p)
        {
            try {
                p.Failure = "EPOCH_BRAKE_OUTSIDE_COMMITTED_FIRST_LEG";
                if (!EpochCorridorOnFirstLeg(p, p.CorridorPoints)) return false;
                bool oldValid, currentValid; p.OldRefsAfter = EpochRefs(p.Mesh, p.Polys, out oldValid); p.CurrentRefsAfter = EpochRefs(p.Mesh, p.CurrentPolys, out currentValid);
                p.Failure = "EPOCH_CHANGED_DURING_CORRIDOR_PROOF";
                if (!oldValid || !currentValid || !EpochNativeStateCurrent(p, true)) return false;
                p.PendingAtSeal = RustNavigation.Instance.HasPendingTiles();
                var build = p.Mesh.BuildParams; p.BuildAfter = new { Climb = build.agentMaxClimb, Slope = build.agentMaxSlope, Radius = build.agentRadius, Height = build.agentHeight };
                if (!EpochNativeStateCurrent(p, true)) return false;
                p.Completed = Time.realtimeSinceStartupAsDouble;
                if (p.Completed - p.Clock.WallTime > MaxTick) return false;
                p.Sealed = true; p.Row = EpochProofRow(p, true, "SEALED_BRAKE_ONLY"); return true;
            } catch (Exception ex) { p.Failure = "EPOCH_SEAL_EXCEPTION:" + ex.GetType().Name; return false; }
        }

        private bool AcquisitionFloor(SupportResult s)
        {
            var entity = s.Collider == null ? null : s.Collider.GetComponentInParent<BaseEntity>();
            return s.Found && s.Kind == "SURFACE" && s.Collider != null && s.Collider.enabled && !s.Collider.isTrigger &&
                !(entity is Door) && !(entity is BasePlayer) && !(entity is BaseVehicle) &&
                s.Collider.attachedRigidbody == null && s.Hits.Length == 1 && s.Normal.y >= Mathf.Cos(maxSlope * Mathf.Deg2Rad) &&
                s.PlaneClearance >= 0;
        }

        private bool AcquisitionSupported(Vector3 actual, SupportResult s)
        {
            return AcquisitionFloor(s) && s.Collider == acquisitionFloor && Mathf.Abs(s.FootY - acquisitionFloorY) <= Numerical &&
                Vector3.Distance(s.Normal, acquisitionNormal) <= Numerical && Vector3.Distance(s.Point, acquisitionPoint) <= Numerical &&
                actual.x == acquisitionStart.x && actual.z == acquisitionStart.z && actual.y <= acquisitionStart.y &&
                acquisitionStart.y - actual.y <= maxDrop && s.Gap >= skin - Numerical && s.Gap <= acquisitionStartGap + Numerical;
        }

        private object AcquisitionRow(Vector3 actual, SupportResult s)
        {
            return new { Start = P(acquisitionStart), StartTime = acquisitionStartTime, StartGap = acquisitionStartGap,
                TotalDrop = acquisitionStart.y - actual.y, FloorId = acquisitionFloor == null ? 0 : acquisitionFloor.GetInstanceID(),
                InitialFloorY = acquisitionFloorY, InitialNormal = P(acquisitionNormal), InitialPoint = P(acquisitionPoint),
                Remaining = Mathf.Max(0, s.Gap - skin), RestObservationTime = acquisitionRestTime, RestObservationPose = P(acquisitionStart),
                RestObservationClock = ClockRow(acquisitionRestClock) };
        }

        private void Conditions(Dictionary<string, object> frame, Vector3 actual, SupportResult support, bool overlapClear, bool permission, float waterDepth)
        {
            frame["Permission"] = permission; frame["WaterDepth"] = waterDepth;
            frame["SupportAccepted"] = Supported(support); frame["OverlapClear"] = overlapClear;
            frame["SupportPhase"] = acquiring ? "FLOOR_ACQUISITION" : "NORMAL";
            frame["Acquisition"] = acquiring ? AcquisitionRow(actual, support) : null;
        }

        private void IssueAcquisition(float now, float dt, Vector3 actual, SupportResult support, List<object> overlaps, bool permission, float waterDepth)
        {
            var frame = Frame(now, actual);
            frame["Support"] = SupportRow(support); frame["Overlaps"] = overlaps.ToArray();
            Conditions(frame, actual, support, true, permission, waterDepth);
            if (currentClock.Sequence <= acquisitionRestClock.Sequence || currentClock.FixedTime <= acquisitionRestClock.FixedTime ||
                !AcquisitionSupported(actual, support) || lastVelocity.x != 0 || lastVelocity.z != 0 || lastVelocity.y > 0)
            { Block(frame, "UNKNOWN", "ACQUISITION_REST_OR_FLOOR_LOST"); return; }
            float remaining = Mathf.Max(0, support.Gap - skin);
            float acceleration = MaxAcceleration * 0.5f;
            float safeSpeed = acceleration * (Mathf.Sqrt(dt * dt + 2f * remaining / acceleration) - dt);
            float speed = Mathf.MoveTowards(-lastVelocity.y, Mathf.Min(maxSpeed, safeSpeed), acceleration * dt);
            if (remaining <= Numerical && -lastVelocity.y <= acceleration * dt) speed = 0;
            Vector3 requested = actual - Vector3.up * Mathf.Min(remaining, speed * dt);
            Vector3 velocity = (requested - actual) / dt;
            bool hold = requested.y == actual.y;
            frame["Requested"] = P(requested); frame["Classification"] = "CLEAR";
            frame["Distance"] = Vector3.Distance(actual, requested); frame["Dt"] = dt;
            frame["Speed"] = velocity.magnitude; frame["Acceleration"] = (velocity - lastVelocity).magnitude / dt;
            frame["Command"] = command + 1;
            frame["MotionMode"] = hold ? "ACQUISITION_BRAKE_HOLD" : "FLOOR_ACQUISITION";
            if (!Finite(velocity) || velocity.magnitude > maxSpeed + Numerical || (velocity - lastVelocity).magnitude / dt > MaxAcceleration + Numerical)
            { Block(frame, "UNKNOWN", "ACQUISITION_BOUNDED_CONTROL_FAILED"); return; }
            var landing = Support(requested); var endOverlaps = new List<object>(); var sweeps = new List<object>();
            bool sweepClear = Sweep(actual, requested, support, sweeps);
            bool endpointClear = Overlaps(requested, landing, endOverlaps);
            bool landingPermission = Permission(requested);
            float landingWater = WaterLevel.GetWaterSurface(requested, true, true, null) - requested.y;
            frame["Landing"] = SupportRow(landing); frame["Sweeps"] = sweeps.ToArray(); frame["LandingOverlaps"] = endOverlaps.ToArray();
            frame["LandingPermission"] = landingPermission; frame["LandingWaterDepth"] = landingWater;
            frame["LandingSupportAccepted"] = Supported(landing);
            Emit("OBSTACLE_PROBE", frame);
            if (!ControlCurrent()) return;
            if (!sweepClear || !endpointClear || !AcquisitionSupported(requested, landing) || !landingPermission || !Finite(landingWater) || landingWater > 0.15f)
            { Emit("PHYSICAL_CONTACT", frame); if (!ControlCurrent()) return; Block(frame, "UNKNOWN", "ACQUISITION_TRAJECTORY_UNSAFE"); return; }
            if (!NavEpochMatches() || evidence.Count >= MaxEvidence - 8)
            { Block(frame, "UNKNOWN", "ACQUISITION_NAV_OR_EVIDENCE_BUDGET"); return; }
            if (!PrepareNativeAdmission(frame, actual, requested)) { Block(frame, "UNKNOWN", "ACQUISITION_NATIVE_ROUTE_ADMISSION:" + nativePathReason); return; }
            string issueClockProblem = ClockProblem(currentClock);
            if (issueClockProblem != null) { Block(frame, "UNKNOWN", "CLOCK_BEFORE_ACQUISITION_ISSUE:" + issueClockProblem); return; }
            if (!Finite(body.linearVelocity) || Vector3.Distance(body.linearVelocity, lastVelocity) > Numerical)
            { Block(frame, "UNKNOWN", "NATIVE_VELOCITY_BEFORE_ACQUISITION_ISSUE"); return; }
            frame["NativeResult"] = "PRECHECKED"; frame["IssuedClock"] = ClockRow(currentClock);
            frame["DecisionPublishedWall"] = Time.realtimeSinceStartupAsDouble;
            if (!PublishDecision(frame, actual, requested)) return;
            if (!NativeAdmissionCurrent(actual, requested, true)) { RejectNativeIntent(frame, "ACQUISITION_NATIVE_ROUTE_CHANGED_BEFORE_WRITER"); return; }
            frame["FinalAdmission"] = finalNativeAdmission;
            command++; commanded = requested; commandFrom = actual; commandTime = now; commandClass = "CLEAR";
            commandClock = currentClock;
            commandHold = hold; commandAcquisition = true; pendingFrame = Copy(frame); pending = true;
            body.MovePosition(body.position + (requested - actual)); actuations++;
            PublishNativeIssue(frame);
            lastPosition = actual; lastTime = now;
        }

        private string ClockProblem(TraversalClock c)
        {
            return WallProblem(c) ?? PhysicsClockProblem(c);
        }

        private void ObserveLatePending()
        {
            // Terminal diagnostic only. Watchdog/deadline/stale work never earns credit.
            if (!pending || !clockReady || BodyProblem() != null || currentClock.Sequence != commandClock.Sequence + 1 ||
                Math.Abs(currentClock.FixedTime - commandClock.FixedTime - commandClock.Delta) > ClockPrecision) return;
            Vector3 actual = npc.transform.position;
            var frame = Frame((float)currentClock.WallTime, actual);
            frame["IssuedClock"] = ClockRow(commandClock); frame["From"] = P(commandFrom);
            frame["Requested"] = P(commanded); frame["Classification"] = "UNKNOWN";
            frame["Reason"] = "WALL_STOP_DIAGNOSTIC"; frame["TerminalOnly"] = true; frame["UnobservedCommand"] = true;
            frame["NativeResult"] = "OBSERVATION_FAILED";
            try
            {
                var support = Support(actual); var overlaps = new List<object>(); var sweeps = new List<object>();
                bool overlapClear = Overlaps(actual, support, overlaps);
                bool sweepClear = Sweep(commandFrom, actual, support, sweeps);
                bool permission = Permission(actual);
                float waterDepth = WaterLevel.GetWaterSurface(actual, true, true, null) - actual.y;
                frame["Support"] = SupportRow(support); frame["Overlaps"] = overlaps.ToArray(); frame["Sweeps"] = sweeps.ToArray();
                Conditions(frame, actual, support, overlapClear, permission, waterDepth);
                double fixedElapsed = currentClock.FixedTime - commandClock.FixedTime;
                Vector3 velocity = (actual - commandFrom) / (float)fixedElapsed;
                frame["PreviousTime"] = commandTime; frame["Dt"] = (float)fixedElapsed; frame["FixedDt"] = fixedElapsed;
                frame["WallDt"] = currentClock.WallTime - commandClock.WallTime;
                frame["Distance"] = Vector3.Distance(commandFrom, actual); frame["Speed"] = velocity.magnitude;
                frame["Acceleration"] = (velocity - lastVelocity).magnitude / (float)fixedElapsed;
                frame["ObservedVelocity"] = P(velocity); frame["TargetError"] = Vector3.Distance(actual, commanded);
                float error = Vector3.Distance(body.linearVelocity, velocity);
                frame["NativeVelocityError"] = error; frame["NativeVelocityMatches"] = Finite(body.linearVelocity) && error <= Numerical;
                frame["SweepClear"] = sweepClear;
                frame["TerminalSupportValid"] = acquiring ? AcquisitionSupported(actual, support) : Supported(support);
                frame["MotionMode"] = commandAcquisition ? commandHold ? "ACQUISITION_BRAKE_HOLD" : "FLOOR_ACQUISITION" : commandHold ? "BRAKE_HOLD" : commandBraking ? "ACTUAL_BRAKE" : "SUPPORTED_ADVANCE";
                frame["NativeResult"] = "OBSERVED_WALL_LATE";
            }
            catch (Exception ex) { frame["ObservationError"] = ex.GetType().Name + ":" + ex.Message; }
            Emit("TERMINAL_OBSERVATION", frame);
            // Deliberately do not clear pending or update velocity, pose, arrival,
            // acquisition, retries or any accepted-motion counters here.
        }

        private string WallProblem(TraversalClock c)
        {
            double wallNow = Time.realtimeSinceStartupAsDouble;
            if (!Finite(c.WallTime) || !Finite(wallNow)) return "INVALID_WALL_CLOCK";
            if (c.WallTime < startWallTime || wallNow < c.WallTime || clockReady && c.WallTime < previousClock.WallTime)
                return "WALL_REGRESSION";
            if (c.WallTime - startWallTime > 120.0) return "WALL_DEADLINE";
            if (sessionGlobalDeadline.HasValue && (c.WallTime > sessionGlobalDeadline.Value || wallNow > sessionGlobalDeadline.Value)) return "GLOBAL_DEADLINE";
            if (wallNow - c.WallTime > MaxTick + ClockPrecision) return "CALLBACK_EXECUTION_STALE";
            if (clockReady && c.WallTime - previousClock.WallTime > maxWallStall + ClockPrecision)
                return "LONG_STALL_UNSAFE";
            return null;
        }

        private string PhysicsClockProblem(TraversalClock c)
        {
            if (!Finite(c.FixedTime) || !Finite(c.FixedUnscaledTime) || !Finite(c.Delta) || !Finite(c.UnscaledDelta) || !Finite(c.TimeScale) ||
                c.FixedTime < 0 || c.FixedUnscaledTime < 0 || c.Delta <= 0 || c.Delta > MaxTick || c.UnscaledDelta <= 0 || c.UnscaledDelta > MaxTick ||
                c.TimeScale != 1f || Math.Abs(c.Delta - c.UnscaledDelta) > ClockPrecision || !c.InFixedStep || c.Sequence <= 0 || c.Frame < 0 ||
                c.PhysicsMode != "FixedUpdate" || !Finite(c.MaximumDelta) || c.MaximumDelta != nativeMaximumDelta)
                return "INVALID_DECLARED_PHYSICS_CLOCK";
            // The driver reports the native callback; independently bind its
            // immutable step values to this actual invocation, not an arbitrary
            // synthetic clock or an OnTick/render callback.
            if (!Time.inFixedTimeStep || c.InFixedStep != Time.inFixedTimeStep ||
                Math.Abs(c.FixedTime - Time.fixedTimeAsDouble) > ClockPrecision ||
                Math.Abs(c.FixedUnscaledTime - Time.fixedUnscaledTimeAsDouble) > ClockPrecision ||
                c.Delta != Time.fixedDeltaTime || c.UnscaledDelta != Time.fixedUnscaledDeltaTime || c.TimeScale != Time.timeScale ||
                c.Frame != Time.frameCount || c.PhysicsMode != Physics.simulationMode.ToString() ||
                c.MaximumDelta != Time.maximumDeltaTime) return "NATIVE_CLOCK_BINDING";
            if (!clockReady) return null;
            if (previousClock.Sequence == long.MaxValue || c.Sequence != previousClock.Sequence + 1 || c.Frame < previousClock.Frame ||
                c.Delta != previousClock.Delta || c.UnscaledDelta != previousClock.UnscaledDelta || c.TimeScale != previousClock.TimeScale ||
                c.PhysicsMode != previousClock.PhysicsMode ||
                c.FixedTime <= previousClock.FixedTime || c.FixedUnscaledTime <= previousClock.FixedUnscaledTime ||
                Math.Abs(c.FixedTime - previousClock.FixedTime - previousClock.Delta) > ClockPrecision ||
                Math.Abs(c.FixedUnscaledTime - previousClock.FixedUnscaledTime - previousClock.UnscaledDelta) > ClockPrecision)
                return "SKIPPED_CHANGED_OR_NONADVANCING_PHYSICS_STEP";
            return null;
        }

        private object ClockRow(TraversalClock c)
        {
            return new { Schema = 2, WallTime = c.WallTime, FixedTime = c.FixedTime, FixedUnscaledTime = c.FixedUnscaledTime,
                Delta = c.Delta, UnscaledDelta = c.UnscaledDelta, TimeScale = c.TimeScale, InFixedStep = c.InFixedStep,
                Sequence = c.Sequence, Frame = c.Frame, PhysicsMode = c.PhysicsMode, MaximumDelta = c.MaximumDelta };
        }

        private bool Plan(Vector3 end, BrakeRestContext rest = null, StationaryReplanContext stationaryPlan = null)
        {
            if (!ControlCurrent()) return false;
            if (stationaryPlan != null) {
                stationaryPlan.PlanPhase = "READY_PREQUERY";
                if (!StationaryQueryGuard(stationaryPlan, "READY_PREQUERY")) return false;
            }
            var nav = RustNavigation.Instance;
            if (nav == null || nav.DefaultNavmesh == null || !nav.IsDefaultNavmeshBuilt() || nav.HasPendingTiles()) return false;
            var mesh = nav.DefaultNavmesh; var build = mesh.BuildParams;
            if (build.agentMaxClimb != navClimb || build.agentMaxSlope != navSlope || build.agentRadius != navRadius || build.agentHeight != navHeight) return false;
            int change = mesh.TileChangeVersion, data = mesh.TileDataVersion; IntPtr handle = mesh.NavMeshHandle;
            if (handle == IntPtr.Zero) return false;
            var plannedFrom = npc.transform.position;
            RustNavMeshPath path, corroboration; bool filter = agent.npcDoorsWillOpen;
            if (stationaryPlan != null) { stationaryPlan.NativeQueriesStarted = true; stationaryPlan.PlanPhase = "NATIVE_QUERY"; }
            bool calculated = ReadNativePath(mesh, plannedFrom, end, filter, out path, out corroboration);
            routeStatus = calculated ? path.status.ToString() : "NATIVE_QUERY_FAILED:" + nativePathReason;
            if (!calculated || nav.HasPendingTiles() || agent.npcDoorsWillOpen != filter ||
                nav.DefaultNavmesh != mesh || mesh.NavMeshHandle != handle || mesh.TileChangeVersion != change || mesh.TileDataVersion != data) return false;
            var planRow = NativePlanLeg(mesh, plannedFrom, end, filter, change, data, path, corroboration);
            if (stationaryPlan != null) {
                stationaryPlan.PlanPhase = "READY_PRECOMMIT";
                if (!StationaryQueryGuard(stationaryPlan, "READY_PRECOMMIT") || nav.HasPendingTiles() || nav.DefaultNavmesh != mesh ||
                    mesh.NavMeshHandle != handle || mesh.TileChangeVersion != change || mesh.TileDataVersion != data || agent.npcDoorsWillOpen != filter || ClockProblem(currentClock) != null) return false;
            }
            if (rest != null && (!RestContextCurrent(rest, "REST_PLAN_PRECOMMIT") || nav.HasPendingTiles() || nav.DefaultNavmesh != mesh ||
                mesh.NavMeshHandle != handle || mesh.TileChangeVersion != change || mesh.TileDataVersion != data || agent.npcDoorsWillOpen != filter || ClockProblem(currentClock) != null)) return false;
            if (!ControlCurrent()) return false;
            routeMesh = mesh; routeTileChangeVersion = change; routeTileDataVersion = data;
            routeFrom = plannedFrom;
            routeMeshHandle = handle;
            routePolys = path.polyRefs.Take(path.polyRefCount).ToArray();
            routeFilter = filter;
            epochProof = null;
            routePlanLegs = new[] { planRow };
            route.Clear(); route.AddRange(path.corners.Select(x => x.Value)); routeIndex = 1;
            if (stationaryPlan != null) stationaryPlan.PlanPhase = "COMMITTED_NATIVE";
            return true;
        }

        private object NativePlanLeg(RustNavmesh mesh, Vector3 from, Vector3 to, bool filter, int change, int data, RustNavMeshPath path, RustNavMeshPath corroboration)
        {
            return new { Kind = "DEFAULT_NATIVE_PATH_V1", Mesh = mesh.NavMeshHandle.ToString(), From = P(from), To = P(to), Filter = filter,
                ChangeBefore = change, ChangeAfter = mesh.TileChangeVersion, DataBefore = data, DataAfter = mesh.TileDataVersion,
                NativeCalculated = true, ActorCalculated = true, NativeStatus = path.status.ToString(), ActorStatus = corroboration.status.ToString(),
                Capacity = path.polyRefs.Length, NativePolys = path.polyRefs.Take(path.polyRefCount).Select(p => p.ToString()).ToArray(),
                ActorPolys = corroboration.polyRefs.Take(corroboration.polyRefCount).Select(p => p.ToString()).ToArray(),
                NativeCorners = path.corners.Select(c => P(c.Value)).ToArray(), ActorCorners = corroboration.corners.Select(c => P(c.Value)).ToArray() };
        }

        private bool ReadNativePath(RustNavmesh mesh, Vector3 from, Vector3 to, bool filter,
            out RustNavMeshPath path, out RustNavMeshPath corroboration)
        {
            // The exact mesh is the provenance of refs. IsValidPolyRef alone
            // cannot establish which mesh an agent's private binding used.
            path = new RustNavMeshPath(); corroboration = new RustNavMeshPath(); nativePathReason = "DEFAULT_PATH_NOT_COMPLETE";
            if (!mesh.CalculatePath(new NavVector3(from), new NavVector3(to), path, filter) || path.status != NavMeshPathStatus.PathComplete) return false;
            nativePathReason = "ACTOR_PATH_NOT_COMPLETE";
            if (!agent.CalculatePath(new NavVector3(from), new NavVector3(to), corroboration) || corroboration.status != NavMeshPathStatus.PathComplete) return false;
            nativePathReason = "NATIVE_PATH_EMPTY_OR_SATURATED";
            foreach (var p in new[] { path, corroboration })
                if (p.polyRefs.Length != NativePathCapacity || p.polyRefCount <= 0 || p.polyRefCount >= NativePathCapacity ||
                    p.corners.Count < 2 || p.corners.Count >= NativePathCapacity || p.corners.Any(c => !Finite(c.Value))) return false;
            nativePathReason = "DEFAULT_ACTOR_PATH_MISMATCH";
            if (path.polyRefCount != corroboration.polyRefCount || path.corners.Count != corroboration.corners.Count ||
                !path.polyRefs.Take(path.polyRefCount).SequenceEqual(corroboration.polyRefs.Take(corroboration.polyRefCount))) return false;
            for (int i = 0; i < path.corners.Count; i++)
                if (Vector3.Distance(path.corners[i].Value, corroboration.corners[i].Value) > Numerical) return false;
            nativePathReason = "NATIVE_PATH_ENDPOINT_BINDING";
            // Preserve the existing native projection bound; the physical body
            // stays at the exact query origin, never at a projected nav corner.
            if (Vector3.Distance(path.corners[0].Value, from) > 0.5f || Vector3.Distance(path.corners[path.corners.Count - 1].Value, to) > 0.5f) return false;
            nativePathReason = "INVALID_NATIVE_POLY";
            if (path.polyRefs.Take(path.polyRefCount).Any(p => p == 0 || !mesh.IsValidPolyRef(p))) return false;
            nativePathReason = "VERIFIED_NATIVE_PATH"; return true;
        }

        private bool PrepareNativeAdmission(Dictionary<string, object> frame, Vector3 from, Vector3 requested)
        {
            nativeAdmission = null;
            var nav = RustNavigation.Instance; var mesh = nav == null ? null : nav.DefaultNavmesh;
            nativePathReason = "MESH_OR_ROUTE_EPOCH_UNKNOWN";
            if (mesh == null || !nav.IsDefaultNavmeshBuilt() || !agent.isOnNavMesh || !NavEpochMatches() ||
                routePolys.Length == 0 || routePolys.Length >= NativePathCapacity || (npc.transform.position - from).sqrMagnitude != 0) return false;
            var build = mesh.BuildParams;
            if (build.agentMaxClimb != navClimb || build.agentMaxSlope != navSlope || build.agentRadius != navRadius || build.agentHeight != navHeight) return false;
            int change = mesh.TileChangeVersion, data = mesh.TileDataVersion; IntPtr handle = mesh.NavMeshHandle; bool filter = agent.npcDoorsWillOpen;
            if (filter != routeFilter) { nativePathReason = "NATIVE_ROUTE_FILTER_CHANGED"; return false; }
            double started = Time.realtimeSinceStartupAsDouble; bool globalBefore = nav.HasPendingTiles();
            RustNavMeshPath path, corroboration;
            if (!ReadNativePath(mesh, from, destination, filter, out path, out corroboration)) {
                frame["NativeAdmissionFailure"] = new { Reason = nativePathReason, GlobalPending = globalBefore,
                    StartedWall = started, CompletedWall = Time.realtimeSinceStartupAsDouble, NativePhaseSeconds = Time.realtimeSinceStartupAsDouble - started,
                    NativeStatus = path.status.ToString(), ActorStatus = corroboration.status.ToString(), path.polyRefCount, Corners = path.corners.Count };
                return false;
            }
            double nativeCompleted = Time.realtimeSinceStartupAsDouble;
            var polys = path.polyRefs.Take(path.polyRefCount).ToArray();
            var oldRows = new List<object>(); var freshRows = new List<object>(); bool valid = true;
            foreach (var p in routePolys) { bool v = p != 0 && mesh.IsValidPolyRef(p); oldRows.Add(new { Ref = p.ToString(), Valid = v }); valid &= v; }
            foreach (var p in polys) { bool v = p != 0 && mesh.IsValidPolyRef(p); freshRows.Add(new { Ref = p.ToString(), Valid = v }); valid &= v; }
            var delta = Horizontal(requested - from); var leg = Horizontal(path.corners[1].Value - from);
            float along = leg.sqrMagnitude == 0 ? 0 : Vector3.Dot(delta, leg.normalized);
            nativePathReason = "FRESH_NATIVE_FIRST_LEG_MISMATCH";
            if (delta.magnitude > Numerical && (leg.magnitude <= Numerical || along < -Numerical ||
                along > leg.magnitude + Numerical || (delta - leg.normalized * along).magnitude > Numerical)) return false;
            bool globalAfter = nav.HasPendingTiles(); double completed = Time.realtimeSinceStartupAsDouble;
            nativePathReason = "NATIVE_ROUTE_CHANGED_DURING_CHECK";
            bool contextMatches = valid && handle != IntPtr.Zero && nav.DefaultNavmesh == mesh && mesh.NavMeshHandle == handle &&
                mesh.TileChangeVersion == change && mesh.TileDataVersion == data && agent.npcDoorsWillOpen == filter && (npc.transform.position - from).sqrMagnitude == 0;
            bool fresh = started >= currentClock.WallTime && completed >= started && completed - currentClock.WallTime <= MaxTick;
            if (!contextMatches || !fresh) {
                if (contextMatches && !fresh) nativePathReason = "NATIVE_ROUTE_CHECK_STALE";
                frame["NativeAdmissionFailure"] = new { Reason = nativePathReason, StartedWall = started, NativeCompletedWall = nativeCompleted, CompletedWall = completed,
                    NativePhaseSeconds = nativeCompleted - started, ValidationPhaseSeconds = completed - nativeCompleted, ReadDelay = completed - currentClock.WallTime,
                    ContextMatches = contextMatches, Fresh = fresh, ValidPolys = valid, MeshMatches = nav.DefaultNavmesh == mesh && mesh.NavMeshHandle == handle,
                    ChangeBefore = change, ChangeAfter = mesh.TileChangeVersion, DataBefore = data, DataAfter = mesh.TileDataVersion,
                    FilterBefore = filter, FilterAfter = agent.npcDoorsWillOpen, PoseMatches = (npc.transform.position - from).sqrMagnitude == 0,
                    GlobalPendingBefore = globalBefore, GlobalPendingAfter = globalAfter };
                return false;
            }
            nativeAdmission = new NativeRouteReceipt { Mesh = mesh, Handle = handle, From = from, Requested = requested, Filter = filter, Change = change, Data = data,
                Sequence = currentClock.Sequence, Started = started, Completed = completed, Polys = polys };
            nativeAdmission.Row = new Dictionary<string, object> {
                { "Kind", NativeAdmissionPolicy }, { "From", P(from) }, { "To", P(destination) }, { "Requested", P(requested) },
                { "Sequence", currentClock.Sequence }, { "StartedWall", started }, { "CompletedWall", completed }, { "CheckedWall", completed },
                { "Mesh", handle.ToString() }, { "ChangeBefore", change }, { "ChangeAfter", mesh.TileChangeVersion },
                { "DataBefore", data }, { "DataAfter", mesh.TileDataVersion }, { "FilterBefore", filter }, { "FilterAfter", agent.npcDoorsWillOpen },
                { "NativeCalculated", true }, { "ActorCalculated", true }, { "NativeStatus", path.status.ToString() }, { "ActorStatus", corroboration.status.ToString() },
                { "Capacity", path.polyRefs.Length }, { "NativeCorners", path.corners.Select(c => P(c.Value)).ToArray() },
                { "ActorCorners", corroboration.corners.Select(c => P(c.Value)).ToArray() }, { "NativePolys", freshRows.ToArray() },
                { "ActorPolys", corroboration.polyRefs.Take(corroboration.polyRefCount).Select(p => p.ToString()).ToArray() }, { "RoutePolys", oldRows.ToArray() },
                { "GlobalPendingBefore", globalBefore }, { "GlobalPendingAfter", globalAfter } };
            frame["Navigation"] = NavigationRow(); nativePathReason = "VERIFIED_NATIVE_PATH";
            return NativeAdmissionCurrent(from, requested);
        }

        private bool NativeAdmissionCurrent(Vector3 from, Vector3 requested, bool final = false)
        {
            double started = Time.realtimeSinceStartupAsDouble; Vector3 measured = from;
            try
            {
                var nav = RustNavigation.Instance; var a = nativeAdmission;
                if (a == null || nav == null) throw new InvalidOperationException("NATIVE_CONTEXT_MISSING");
                measured = npc.transform.position;
                var before = nav.DefaultNavmesh; var build = a.Mesh.BuildParams;
                string meshBefore = before == null ? null : before.NavMeshHandle.ToString();
                int changeBefore = before == null ? -1 : before.TileChangeVersion, dataBefore = before == null ? -1 : before.TileDataVersion;
                bool filterBefore = agent.npcDoorsWillOpen, globalBefore = nav.HasPendingTiles();
                bool built = nav.IsDefaultNavmeshBuilt(), onMesh = agent.isOnNavMesh, bodyValid = BodyProblem() == null;
                bool profileMatches = build.agentMaxClimb == navClimb && build.agentMaxSlope == navSlope && build.agentRadius == navRadius && build.agentHeight == navHeight;
                bool valid = true; var oldRows = new List<object>(); var freshRows = new List<object>();
                foreach (var p in routePolys) { bool v = p != 0 && a.Mesh.IsValidPolyRef(p); oldRows.Add(new { Ref = p.ToString(), Valid = v }); valid &= v; }
                foreach (var p in a.Polys) { bool v = p != 0 && a.Mesh.IsValidPolyRef(p); freshRows.Add(new { Ref = p.ToString(), Valid = v }); valid &= v; }
                var after = nav.DefaultNavmesh; bool filterAfter = agent.npcDoorsWillOpen, globalAfter = nav.HasPendingTiles();
                var expectedVelocity = lastVelocity; var nativeVelocity = body.linearVelocity;
                bool expectedFinite = Finite(expectedVelocity), nativeFinite = Finite(nativeVelocity);
                float? velocityError = expectedFinite && nativeFinite ? (float?)Vector3.Distance(nativeVelocity, expectedVelocity) : null;
                bool velocityMatches = velocityError.HasValue && velocityError.Value <= Numerical;
                double velocityCheckedWall = Time.realtimeSinceStartupAsDouble;
                bool stationaryBodyRequired = stationary != null && stationary.FirstWriterCommand == 0 && actuations == stationary.BaseActuations;
                bool stationaryBodyMatched = !stationaryBodyRequired || stationary.State == "COMMITTED" && stationary.PlanAccepted && StationaryPoseCurrent(stationary);
                var currentStationaryBody = stationaryBodyRequired ? StationaryBodyRow(CaptureStationaryBody()) : null;
                bool clock = ClockProblem(currentClock) == null; double checkedWall = Time.realtimeSinceStartupAsDouble;
                bool accepted = active && before == a.Mesh && after == a.Mesh && a.Mesh.NavMeshHandle == a.Handle && NavEpochMatches() &&
                    changeBefore == a.Change && dataBefore == a.Data && a.Mesh.TileChangeVersion == a.Change && a.Mesh.TileDataVersion == a.Data &&
                    built && onMesh && bodyValid && profileMatches && valid && filterBefore == a.Filter && filterAfter == a.Filter &&
                    a.Sequence == currentClock.Sequence && (a.From - from).sqrMagnitude == 0 && (a.Requested - requested).sqrMagnitude == 0 &&
                    (measured - from).sqrMagnitude == 0 && (npc.transform.position - measured).sqrMagnitude == 0 && velocityMatches && stationaryBodyMatched && clock &&
                    checkedWall >= a.Completed && checkedWall - currentClock.WallTime <= MaxTick;
                if (final) finalNativeAdmission = new { Kind = "POST_SINK_NATIVE_GUARD_V1", Accepted = accepted, Error = (string)null,
                    Sequence = currentClock.Sequence, StartedWall = started, CheckedWall = checkedWall, From = P(measured), Requested = P(requested),
                    MeshBefore = meshBefore, MeshAfter = after == null ? null : after.NavMeshHandle.ToString(),
                    ChangeBefore = changeBefore, ChangeAfter = after == null ? -1 : after.TileChangeVersion,
                    DataBefore = dataBefore, DataAfter = after == null ? -1 : after.TileDataVersion,
                    FilterBefore = filterBefore, FilterAfter = filterAfter, DefaultBuilt = built, OnNavMesh = onMesh, ProfileMatches = profileMatches,
                    BodyValid = bodyValid, ClockAccepted = clock, ControlActive = active, RoutePolys = oldRows.ToArray(), NativePolys = freshRows.ToArray(),
                    StationaryBodyRequired = stationaryBodyRequired, StationaryBodyMatched = stationaryBodyRequired ? (bool?)stationaryBodyMatched : null, StationaryBody = currentStationaryBody,
                    VelocityPolicy = "NATIVE_POST_SINK_VELOCITY_V1", ExpectedVelocity = P(expectedVelocity), NativeVelocity = P(nativeVelocity),
                    ExpectedVelocityFinite = expectedFinite, NativeVelocityFinite = nativeFinite, VelocityError = velocityError, VelocityMatches = velocityMatches, VelocityCheckedWall = velocityCheckedWall,
                    GlobalPendingBefore = globalBefore, GlobalPendingAfter = globalAfter };
                return accepted;
            }
            catch (Exception ex)
            {
                if (final) finalNativeAdmission = new { Kind = "POST_SINK_NATIVE_GUARD_V1", Accepted = false, Error = "NATIVE_EXCEPTION:" + ex.GetType().Name,
                    Sequence = currentClock.Sequence, StartedWall = started, CheckedWall = Time.realtimeSinceStartupAsDouble, From = P(measured), Requested = P(requested),
                    VelocityPolicy = "NATIVE_POST_SINK_VELOCITY_V1", ExpectedVelocity = P(lastVelocity), NativeVelocity = (float[])null,
                    ExpectedVelocityFinite = Finite(lastVelocity), NativeVelocityFinite = (bool?)null, VelocityError = (float?)null,
                    VelocityMatches = false, VelocityCheckedWall = (double?)null };
                return false;
            }
        }

        private void RejectNativeIntent(Dictionary<string, object> frame, string why)
        {
            frame["FinalAdmission"] = finalNativeAdmission; frame["NativeResult"] = "NOT_ISSUED";
            frame["WriterCalled"] = false; frame["Actuations"] = actuations; frame["Reason"] = why;
            Emit("MOVE_REJECTED", frame); Block(frame, "UNKNOWN", why);
        }
        private bool PublishDecision(Dictionary<string, object> frame, Vector3 actual, Vector3 requested)
        {
            try { Emit("MOVE_DECISION", frame); return ControlCurrent(); }
            catch (Exception ex)
            {
                // A scene admission/evidence sink may refuse an intent. Retain
                // that published intent and explicitly cancel it before any
                // pending metadata, writer call or actuation credit exists.
                double observed = Time.realtimeSinceStartupAsDouble;
                finalNativeAdmission = new { Kind = "POST_SINK_NATIVE_GUARD_V1", Accepted = false, Error = "DECISION_SINK_REFUSED:" + ex.GetType().Name,
                    Sequence = currentClock.Sequence, StartedWall = observed, CheckedWall = observed, From = P(npc.transform.position), Requested = P(requested) };
                RejectNativeIntent(frame, "DECISION_SINK_REFUSED"); return false;
            }
        }
        private void PublishNativeIssue(Dictionary<string, object> frame)
        {
            // MovePosition returned; actual movement still needs the next native witness.
            var issued = Copy(frame); issued["NativeResult"] = "ISSUED"; issued["WriterCalled"] = true; issued["Actuations"] = actuations;
            Emit("MOVE_ISSUED", issued);
            if (!ControlCurrent()) return;
            if (commandBraking) Emit("BRAKE_ISSUED", issued);
        }

        private bool NavEpochMatches()
        {
            var nav = RustNavigation.Instance;
            return nav != null && nav.DefaultNavmesh != null && nav.DefaultNavmesh == routeMesh && routeMesh.NavMeshHandle == routeMeshHandle && routeMeshHandle != IntPtr.Zero &&
                (epochProof == null || epochProof.Sealed && EpochProofContextMatches(epochProof)) &&
                routeMesh.TileChangeVersion == AdmissionChange && routeMesh.TileDataVersion == AdmissionData;
        }

        private int AdmissionChange { get { return epochProof == null ? routeTileChangeVersion : epochProof.Change; } }
        private int AdmissionData { get { return epochProof == null ? routeTileDataVersion : epochProof.Data; } }

        private object NavigationRow()
        {
            var nav = RustNavigation.Instance; var mesh = nav == null ? null : nav.DefaultNavmesh;
            return new { OnNavMesh = agent.isOnNavMesh, PendingTiles = nav == null || nav.HasPendingTiles(), RouteStatus = routeStatus,
                AdmissionPolicy = NativeAdmissionPolicy, DefaultBuilt = nav != null && nav.IsDefaultNavmeshBuilt(),
                RoutePolys = routePolys.Select(p => p.ToString()).ToArray(), RouteFilter = routeFilter, RoutePlan = routePlanLegs,
                Admission = nativeAdmission == null ? null : nativeAdmission.Row,
                RouteFrom = P(routeFrom), RouteTo = P(destination), Corners = route.Select(P).ToArray(),
                PlannedTileChangeVersion = routeTileChangeVersion, PlannedTileDataVersion = routeTileDataVersion,
                AdmissionTileChangeVersion = AdmissionChange, AdmissionTileDataVersion = AdmissionData, EpochRevalidation = epochProof == null ? null : epochProof.Row,
                TileChangeVersion = mesh == null ? -1 : mesh.TileChangeVersion, TileDataVersion = mesh == null ? -1 : mesh.TileDataVersion,
                PlannedMesh = routeMesh == null ? null : routeMeshHandle.ToString(), Mesh = mesh == null ? null : mesh.NavMeshHandle.ToString() };
        }

        private void Obstacle(Dictionary<string, object> frame, string classification, string why, BrakeRestContext rest = null)
        {
            if (!ControlCurrent()) return;
            frame["Classification"] = classification; frame["Reason"] = why;
            if (pending) { Block(frame, classification, why); return; }
            if (braking) { UnsafeBrake(frame, "BRAKING_COMMAND_REFUSED:" + why); return; }
            if (lastVelocity.sqrMagnitude != 0) { RequestBrake(frame, classification, why); return; }
            if (retries++ == 0)
            {
                Vector3 actual = npc.transform.position;
                Vector3 forward = Horizontal(destination - actual).normalized;
                Vector3 side = Vector3.Cross(Vector3.up, forward) * (radius * 3f);
                List<Vector3> best = null; ulong[] bestPolys = null; object[] bestLegs = null; float bestLength = float.PositiveInfinity;
                var nav = RustNavigation.Instance; var mesh = routeMesh;
                if (nav == null || mesh == null || !NavEpochMatches() || agent.npcDoorsWillOpen != routeFilter)
                { if (rest != null) { frame["RestReplan"] = new { Kind = "OBSTACLE", Accepted = false, Guard = rest.LastGuard, Time = Time.realtimeSinceStartupAsDouble }; BlockRest(frame, why + ":NATIVE_REPATH_CONTEXT_UNKNOWN"); }
                    else Block(frame, classification, why + ":NATIVE_REPATH_CONTEXT_UNKNOWN"); return; }
                int change = mesh.TileChangeVersion, data = mesh.TileDataVersion; var handle = mesh.NavMeshHandle; bool filter = routeFilter;
                for (int sign = -1; sign <= 1; sign += 2)
                {
                    RustNavMeshPath a, b, actorA, actorB; Vector3 detour = actual + side * sign + forward * radius;
                    if (ReadNativePath(mesh, actual, detour, filter, out a, out actorA) && ReadNativePath(mesh, detour, destination, filter, out b, out actorB) &&
                        Vector3.Distance(a.corners[a.corners.Count - 1].Value, b.corners[0].Value) <= Numerical &&
                        a.polyRefs[a.polyRefCount - 1] == b.polyRefs[0])
                    {
                        float length = a.GetPathLength() + b.GetPathLength(); var polys = a.polyRefs.Take(a.polyRefCount).Concat(b.polyRefs.Take(b.polyRefCount)).ToArray();
                        var corners = a.corners.Select(x => x.Value).Concat(b.corners.Skip(1).Select(x => x.Value)).ToList();
                        if (length < bestLength && polys.Length < NativePathCapacity && corners.Count < NativePathCapacity) {
                            bestLength = length; best = corners; bestPolys = polys;
                            bestLegs = new[] { NativePlanLeg(mesh, actual, detour, filter, change, data, a, actorA), NativePlanLeg(mesh, detour, destination, filter, change, data, b, actorB) };
                        }
                    }
                }
                frame["Retry"] = retries; frame["Route"] = best == null ? new float[0][] : best.Select(P).ToArray();
                if (best != null && NavEpochMatches() && nav.DefaultNavmesh == mesh && mesh.NavMeshHandle == handle &&
                    mesh.TileChangeVersion == change && mesh.TileDataVersion == data && agent.npcDoorsWillOpen == filter && bestPolys.All(p => p != 0 && mesh.IsValidPolyRef(p))) {
                    if (rest != null && (!RestContextCurrent(rest, "REST_OBSTACLE_PRECOMMIT") || !NavEpochMatches() || nav.DefaultNavmesh != mesh ||
                        mesh.NavMeshHandle != handle || mesh.TileChangeVersion != change || mesh.TileDataVersion != data || agent.npcDoorsWillOpen != filter || ClockProblem(currentClock) != null)) {
                        RestContextCurrent(rest, "REST_OBSTACLE_REFUSED");frame["RestReplanGuard"] = rest.LastGuard; BlockRest(frame, "BRAKE_REST_CHANGED_DURING_NATIVE_REPATH"); return;
                    }
                    if (!ControlCurrent()) return;
                    route.Clear(); route.AddRange(best); routePolys = bestPolys; routePlanLegs = bestLegs; routeIndex = 1; routeFrom = actual;
                    routeStatus = "PathComplete"; lastTime = (float)frame["Time"]; frame["Navigation"] = NavigationRow();
                    if (rest != null) frame["RestReplan"] = new { Kind = "OBSTACLE", Accepted = true, Guard = rest.LastGuard, Time = Time.realtimeSinceStartupAsDouble };
                    if (replanAfterRest) { frame["Recovery"] = brakeReceipt; Emit("REPATH_AFTER_REST", frame); if (!ControlCurrent()) return; replanAfterRest = false; }
                    Emit("REPATH", frame); return;
                }
                if (rest != null) frame["RestReplan"] = new { Kind = "OBSTACLE", Accepted = false, Guard = rest.LastGuard, Time = Time.realtimeSinceStartupAsDouble };
                Emit("REPATH", frame);
                if (!ControlCurrent()) return;
            }
            if (rest != null) { frame["RestReplan"] = new { Kind = "OBSTACLE", Accepted = false, Guard = rest.LastGuard, Time = Time.realtimeSinceStartupAsDouble }; BlockRest(frame, why + ":BOUNDED_REPATH_EXHAUSTED"); }
            else Block(frame, classification, why + ":BOUNDED_REPATH_EXHAUSTED");
        }

        private SupportResult Support(Vector3 position)
        {
            CountCast(); Vector3 a, b; Endpoints(position, out a, out b);
            var result = new SupportResult { Origin = a + Vector3.up * (maxStep + skin + 0.05f), Length = maxStep + maxDrop + 2f * skin + 0.1f };
            var hits = Physics.SphereCastAll(result.Origin, radius, Vector3.down, result.Length, Mask, QueryTriggerInteraction.Ignore)
                .Where(h => !Self(h.collider)).OrderBy(h => h.distance).ToArray();
            result.Hits = hits.Select(h => (object)new { Collider = ColliderRow(h.collider), Point = P(h.point), Normal = P(h.normal), Distance = h.distance }).ToArray();
            foreach (var hit in hits)
            {
                if (!Finite(hit.normal) || !Finite(hit.point) || !Finite(hit.distance) || hit.distance <= 0 || hit.normal.y <= 0) continue;
                Vector3 center = result.Origin - Vector3.up * hit.distance;
                if (Mathf.Abs(hit.normal.sqrMagnitude - 1f) > Numerical || Vector3.Distance(center - hit.point, hit.normal * radius) > Numerical)
                    return result; // Native contact geometry cannot be established.
                if (hit.normal.y < Mathf.Cos(maxSlope * Mathf.Deg2Rad) && !StepEdge(position, hit, result)) continue;
                result.Found = true; result.Collider = hit.collider; result.Point = hit.point; result.Normal = hit.normal;
                result.Distance = hit.distance; result.Center = center;
                result.FootY = result.Center.y - (a.y - position.y); result.Gap = a.y - result.Center.y;
                result.PlaneClearance = Vector3.Dot(a - result.Point, result.Normal) - radius;
                break; // Never skip the highest walkable surface to invent a lower floor.
            }
            return result;
        }

        private bool StepEdge(Vector3 position, RaycastHit corner, SupportResult result)
        {
            // The same independently measured geometry must support both entry
            // and departure. For a descent the finite top is behind the actor.
            return StepEdgeSide(position, corner, result, supportDirection) || StepEdgeSide(position, corner, result, -supportDirection);
        }

        private bool StepEdgeSide(Vector3 position, RaycastHit corner, SupportResult result, Vector3 topDirection)
        {
            // A spherical capsule can roll over a finite low edge even when its
            // instantaneous contact normal is steeper than a walkable plane.
            // Distinguish that geometry from a slope/wall by measuring both a
            // source floor and a walkable top on this very collider. The later
            // full-volume sweep still vetoes every chord that enters the edge.
            if (topDirection.sqrMagnitude < 0.99f) return false;
            float lift = maxStep + skin + 0.05f, length = maxStep + maxDrop + skin + 0.1f;
            Vector3 sourceOrigin = position + Vector3.up * lift;
            Vector3 topOrigin = position + topDirection * radius + Vector3.up * lift;
            CountCast();
            var sourceHits = Physics.RaycastAll(sourceOrigin, Vector3.down, length, Mask, QueryTriggerInteraction.Ignore)
                .Where(h => !Self(h.collider)).OrderBy(h => h.distance).ToArray();
            CountCast();
            var topHits = Physics.RaycastAll(topOrigin, Vector3.down, length, Mask, QueryTriggerInteraction.Ignore)
                .Where(h => !Self(h.collider)).OrderBy(h => h.distance).ToArray();
            var source = sourceHits.FirstOrDefault(h => h.normal.y >= Mathf.Cos(maxSlope * Mathf.Deg2Rad) && h.point.y <= position.y + Numerical);
            var top = topHits.FirstOrDefault(); // An intervening surface is never skipped.
            if (source.collider == null || top.collider != corner.collider || top.normal.y < Mathf.Cos(maxSlope * Mathf.Deg2Rad) ||
                !Finite(source.point) || !Finite(top.point) || Mathf.Abs(source.normal.sqrMagnitude - 1) > Numerical || Mathf.Abs(top.normal.sqrMagnitude - 1) > Numerical ||
                top.point.y <= source.point.y || top.point.y - source.point.y > maxStep ||
                Mathf.Abs(top.point.y - corner.point.y) > Numerical || position.y - source.point.y > maxDrop + supportTolerance) return false;
            result.Kind = "STEP_EDGE";
            result.EdgeSource = new { Origin = P(sourceOrigin), Length = length, Point = P(source.point), Normal = P(source.normal), Distance = source.distance,
                Collider = ColliderRow(source.collider), Hits = sourceHits.Select(RayRow).ToArray() };
            result.EdgeTop = new { Origin = P(topOrigin), Length = length, Point = P(top.point), Normal = P(top.normal), Distance = top.distance,
                Collider = ColliderRow(top.collider), Hits = topHits.Select(RayRow).ToArray(), Direction = P(topDirection) };
            return true;
        }

        private object RayRow(RaycastHit h) { return new { Collider = ColliderRow(h.collider), Point = P(h.point), Normal = P(h.normal), Distance = h.distance }; }

        private bool Supported(SupportResult s) { return s.Found && s.Gap >= -Numerical && s.Gap <= supportTolerance && s.PlaneClearance >= -Numerical; }
        private bool SupportedAt(SupportResult s, Vector3 p)
        {
            Vector3 a, b; Endpoints(p, out a, out b);
            float gap = p.y - s.FootY;
            return s.Found && gap >= 0 && gap <= supportTolerance && Vector3.Dot(a - s.Point, s.Normal) - radius >= -Numerical;
        }

        private bool Overlaps(Vector3 position, SupportResult support, List<object> rows)
        {
            CountCast(); Vector3 a, b; Endpoints(position, out a, out b); bool clear = true;
            foreach (var c in Physics.OverlapCapsule(a, b, radius, Mask, QueryTriggerInteraction.Ignore).Where(c => !Self(c)).OrderBy(c => c.GetInstanceID()))
            {
                CountCast(); Vector3 direction; float depth;
                bool intersects = Physics.ComputePenetration(capsule, capsule.transform.position + position - npc.transform.position,
                    capsule.transform.rotation, c, c.transform.position, c.transform.rotation, out direction, out depth);
                float plane = support.Found ? Vector3.Dot(a - support.Point, support.Normal) - radius : float.NaN;
                // Exact tangency only: not a depth tolerance, and never an own
                // foundation exclusion. Any positive penetration remains blocking.
                bool tangent = !intersects && support.Found && c == support.Collider && Mathf.Abs(plane) <= Numerical &&
                    (support.Normal.y >= Mathf.Cos(maxSlope * Mathf.Deg2Rad) || support.Kind == "STEP_EDGE");
                rows.Add(new { Collider = ColliderRow(c), Intersects = intersects, Distance = depth, Direction = P(direction), Error = (string)null, SupportTangent = tangent,
                    QueryPosition = P(capsule.transform.position + position - npc.transform.position), ActorCollider = capsule.GetInstanceID() });
                if (!tangent) clear = false;
            }
            return clear;
        }

        private bool Sweep(Vector3 from, Vector3 to, SupportResult support, List<object> rows)
        {
            closedDoorHit = dynamicHit = false;
            CountCast(); Vector3 a, b; Endpoints(from, out a, out b); Vector3 delta = to - from;
            bool clear = true;
            var hits = delta.sqrMagnitude <= 0 ? new RaycastHit[0] : Physics.CapsuleCastAll(a, b, radius, delta.normalized, delta.magnitude, Mask, QueryTriggerInteraction.Ignore);
            var hitRows = new List<object>();
            foreach (var h in hits.Where(h => !Self(h.collider)).OrderBy(h => h.distance))
            {
                // A zero-distance support tangent is safe only while moving away
                // or along its measured plane, with no initial penetration. All
                // wall/side contacts, however shallow, are blocking.
                Vector3 mtd; float depth; CountCast();
                bool intersects = Physics.ComputePenetration(capsule, capsule.transform.position + from - npc.transform.position, capsule.transform.rotation,
                    h.collider, h.collider.transform.position, h.collider.transform.rotation, out mtd, out depth);
                float plane = Vector3.Dot(a - h.point, h.normal) - radius;
                bool tangent = !intersects && support.Found && h.collider == support.Collider && h.distance <= Numerical &&
                    (h.normal.y >= Mathf.Cos(maxSlope * Mathf.Deg2Rad) || support.Kind == "STEP_EDGE" && Vector3.Distance(h.normal, support.Normal) <= Numerical) &&
                    Mathf.Abs(plane) <= Numerical && Vector3.Dot(delta, h.normal) >= -0.00001f;
                bool blocking = !tangent;
                var door = h.collider.GetComponentInParent<Door>();
                if (blocking && door != null && !door.IsOpen()) closedDoorHit = true;
                if (blocking && h.collider.attachedRigidbody != null && h.collider.attachedRigidbody != body) dynamicHit = true;
                hitRows.Add(new { Collider = ColliderRow(h.collider), Point = P(h.point), Normal = P(h.normal), Distance = h.distance, Blocking = blocking,
                    InitialIntersects = intersects, InitialDepth = depth, InitialDirection = P(mtd), PlaneClearance = plane, SupportTangent = tangent });
                if (blocking) clear = false;
            }
            rows.Add(new { From = P(from), To = P(to), A = P(a), B = P(b), Radius = radius, Distance = delta.magnitude, Mask = Mask, Triggers = "Ignore", Hits = hitRows.ToArray() });
            return clear;
        }

        private string Classify(Vector3 from, Vector3 to, SupportResult a, SupportResult b)
        {
            float change = to.y - from.y;
            float supportChange = b.FootY - a.FootY;
            // Settling an initial safe spawn gap is motion, not evidence of a
            // terrain step or descent. The support itself must change height.
            if (Mathf.Abs(change) <= Numerical || Mathf.Abs(supportChange) <= Numerical || change * supportChange <= 0) return "CLEAR";
            if (a.Kind != "STEP_EDGE" && b.Kind != "STEP_EDGE" && a.Normal.y < 0.9999f && b.Normal.y < 0.9999f && a.Collider == b.Collider) return "SLOPE";
            return change > 0 ? "SMALL_STEP_UP" : "STEP_DOWN";
        }

        private string BodyProblem()
        {
            if (npc == null || npc.IsDestroyed || npc.net == null || npc.net.ID.Value.ToString() != actor || capsule == null || body == null) return "ACTOR_CHANGED";
            if (!Finite(npc.transform.position) || capsule.direction != 1 || !capsule.enabled || capsule.isTrigger || capsule.attachedRigidbody != body ||
                Mathf.Abs(radius - 0.5f) > Numerical || Mathf.Abs(height - 1.8f) > Numerical || capsule.radius != radius || capsule.height != height ||
                capsule.center != originalCenter || Vector3.Distance(originalCenter, new Vector3(0, 0.9f, 0)) > Numerical ||
                Vector3.Distance(capsule.transform.lossyScale, originalScale) > Numerical || Vector3.Distance(originalScale, Vector3.one) > Numerical ||
                Vector3.Dot(capsule.transform.up, Vector3.up) < 0.99999f || body.isKinematic != originalKinematic || body.useGravity != originalGravity ||
                !body.detectCollisions || capsule.gameObject.layer != originalLayer || body.collisionDetectionMode.ToString() != originalCollisionMode ||
                Vector3.Distance(body.position, npc.transform.position) > Numerical) return "ORIGINAL_BODY_CHANGED";
            if (!agent.isStopped || agent.updatePosition || agent.updateRotation) return "COMPETING_NAV_WRITER";
            var navigator = npc.GetComponent<BaseNavigator>();
            if (navigator != null && navigator.enabled) return "COMPETING_BASE_NAVIGATOR";
            if (npc.GetComponentsInChildren<Collider>().Any(c => c != capsule && c.enabled && !c.isTrigger)) return "UNMODELLED_ACTOR_COLLIDER";
            return null;
        }

        private bool Permission(Vector3 p) { return npc.CanBuild(p, Quaternion.identity, new Bounds(Vector3.up * height * 0.5f, new Vector3(radius * 2, height, radius * 2))); }
        private bool Self(Collider c) { return c != null && c.GetComponentInParent<BaseEntity>() == npc; }
        private void Endpoints(Vector3 p, out Vector3 a, out Vector3 b)
        {
            float segment = height * 0.5f - radius; Vector3 shift = p - npc.transform.position;
            a = capsule.transform.TransformPoint(capsule.center - Vector3.up * segment) + shift;
            b = capsule.transform.TransformPoint(capsule.center + Vector3.up * segment) + shift;
        }
        private object BodyRow()
        {
            Vector3 a, b; Endpoints(npc.transform.position, out a, out b);
            var q = capsule.transform.rotation;
            return new { Actor = actor, Instance = capsule.GetInstanceID(), Radius = capsule.radius, Height = capsule.height, Center = P(capsule.center),
                Direction = capsule.direction, Scale = P(capsule.transform.lossyScale), Enabled = capsule.enabled, Trigger = capsule.isTrigger,
                A = P(a), B = P(b), WorldRadius = radius, Position = P(npc.transform.position), Rotation = new[] { q.x, q.y, q.z, q.w },
                RigidbodyInstance = body.GetInstanceID(), RigidbodyPosition = P(body.position), Kinematic = body.isKinematic, Gravity = body.useGravity,
                Velocity = P(body.linearVelocity),
                DetectCollisions = body.detectCollisions, Layer = capsule.gameObject.layer, CollisionMode = body.collisionDetectionMode.ToString(),
                AgentStopped = agent.isStopped, AgentUpdatePosition = agent.updatePosition, AgentUpdateRotation = agent.updateRotation };
        }
        private object SupportRow(SupportResult s)
        {
            return new { Found = s.Found, Collider = s.Found ? ColliderRow(s.Collider) : null, Origin = P(s.Origin), Radius = radius, Length = s.Length,
                Point = P(s.Point), Normal = P(s.Normal), Distance = s.Distance, Center = P(s.Center), FootY = s.FootY, Gap = s.Gap, PlaneClearance = s.PlaneClearance,
                Kind = s.Kind, EdgeSource = s.EdgeSource, EdgeTop = s.EdgeTop, Hits = s.Hits };
        }
        private object ColliderRow(Collider c)
        {
            if (c == null) return null; var entity = c.GetComponentInParent<BaseEntity>(); var door = entity as Door; var rigid = c.attachedRigidbody;
            return new { Instance = c.GetInstanceID(), Type = c.GetType().Name, Entity = entity == null || entity.net == null ? null : entity.net.ID.Value.ToString(),
                EntityType = entity == null ? null : entity.GetType().Name, MovingEntity = entity is Door || entity is BasePlayer || entity is BaseVehicle,
                Prefab = entity == null ? null : entity.PrefabName, Owner = entity == null ? null : entity.OwnerID.ToString(), Enabled = c.enabled, Trigger = c.isTrigger, Layer = c.gameObject.layer,
                BoundsCenter = P(c.bounds.center), BoundsSize = P(c.bounds.size), DoorOpen = door == null ? (bool?)null : door.IsOpen(),
                RigidbodyInstance = rigid == null ? (int?)null : rigid.GetInstanceID(), Kinematic = rigid == null ? (bool?)null : rigid.isKinematic };
        }
        private Dictionary<string, object> Frame(float now, Vector3 actual)
        {
            return new Dictionary<string, object> { { "Schema", 2 }, { "RecoveryPolicy", RecoveryPolicy }, { "MotionSession", motionSession }, { "Actor", actor }, { "World", world }, { "Stage", stage }, { "Time", now }, { "Tick", ticks },
                { "Command", command }, { "Classification", "UNKNOWN" }, { "Reason", reason }, { "Body", BodyRow() }, { "Profile", profile },
                { "From", P(actual) }, { "Requested", P(actual) }, { "Actual", P(actual) }, { "PreviousTime", lastTime },
                { "Dt", clockContext ? (object)currentClock.Delta : null }, { "FixedDt", clockContext ? (object)(double)currentClock.Delta : null },
                { "WallDt", clockContext ? (object)(currentClock.WallTime - (clockReady ? previousClock.WallTime : startWallTime)) : null },
                { "Clock", clockContext ? ClockRow(currentClock) : null }, { "PreviousClock", clockContext && clockReady ? ClockRow(previousClock) : null }, { "IssuedClock", null },
                { "WallTelemetry", clockContext ? new { CallbackGap = currentClock.WallTime - (clockReady ? previousClock.WallTime : startWallTime),
                    ReadDelay = Time.realtimeSinceStartupAsDouble - currentClock.WallTime, MaxWallStall = maxWallStall,
                    NativeMaximumDelta = nativeMaximumDelta, NativeCatchupExceeded = clockReady && currentClock.WallTime - previousClock.WallTime > nativeMaximumDelta + ClockPrecision,
                    State = PhysicsClockProblem(currentClock) != null ? "PHYSICS_SKIPPED_OR_CHANGED" :
                        clockReady && currentClock.WallTime - previousClock.WallTime > maxWallStall + ClockPrecision ? "LONG_STALL_UNSAFE" :
                        clockReady && currentClock.WallTime - previousClock.WallTime > MaxTick + ClockPrecision ? "PHYSICS_CONTIGUOUS_WITH_WALL_LAG" : "ON_TIME" } : null },
                { "Support", null }, { "Sweeps", new object[0] }, { "Overlaps", new object[0] }, { "Mask", Mask }, { "Triggers", "Ignore" },
                { "Permission", null }, { "WaterDepth", null }, { "SupportAccepted", null }, { "OverlapClear", null },
                { "SupportPhase", acquiring ? "FLOOR_ACQUISITION" : "NORMAL" }, { "Acquisition", null },
                { "Navigation", NavigationRow() },
                { "Actuator", "Rigidbody.MovePosition" }, { "NativeResult", "NOT_ISSUED" }, { "Retry", retries } };
        }
        private void Block(Dictionary<string, object> frame, string classification, string why)
        {
            StationaryFailure(why, "BLOCK");
            if (stationary != null && stationary.FirstWriterCommand == 0 && !pending && actuations == stationary.BaseActuations) {
                frame["NativeResult"] = "NOT_ISSUED"; frame["WriterCalled"] = false; frame["PendingDecision"] = null;
            }
            active = false; arrived = false; blocked = true; reason = why;
            frame["Classification"] = classification; frame["Reason"] = why; frame["UnobservedCommand"] = pending;
            Emit("BLOCKED", frame); agent.isStopped = true;
        }
        private void Emit(string name, Dictionary<string, object> frame)
        {
            if (evidence.Count >= MaxEvidence) { active = false; blocked = true; arrived = false; reason = "EVIDENCE_BUDGET"; return; }
            var row = Copy(frame); row["Event"] = name; row["Casts"] = casts; row["QueryMilliseconds"] = queryClock.Elapsed.TotalMilliseconds;
            if (name == "MOVE_ISSUED" && stationary != null && stationary.FirstWriterCommand == 0 && actuations > stationary.BaseActuations) {
                stationary.FirstWriterCommand = command; stationary.State = "WRITTEN";
            }
            row["GlobalDeadline"] = sessionGlobalDeadline;
            row["StationaryReplan"] = StationaryReplanSnapshot();
            if (clockContext) {
                var telemetry = new Dictionary<string, object> {
                    { "CallbackGap", currentClock.WallTime - (clockReady ? previousClock.WallTime : startWallTime) },
                    { "ReadDelay", Time.realtimeSinceStartupAsDouble - currentClock.WallTime }, { "MaxWallStall", maxWallStall },
                    { "NativeMaximumDelta", nativeMaximumDelta }, { "NativeCatchupExceeded", currentClock.WallTime - (clockReady ? previousClock.WallTime : startWallTime) > nativeMaximumDelta + ClockPrecision },
                    { "State", PhysicsClockProblem(currentClock) != null ? "PHYSICS_SKIPPED_OR_CHANGED" :
                        clockReady && currentClock.WallTime - previousClock.WallTime > maxWallStall + ClockPrecision ? "LONG_STALL_UNSAFE" :
                        clockReady && currentClock.WallTime - previousClock.WallTime > MaxTick + ClockPrecision ? "PHYSICS_CONTIGUOUS_WITH_WALL_LAG" : "ON_TIME" } };
                row["WallTelemetry"] = telemetry;
            }
            evidence.Add(row); if (sink != null) sink(row);
        }
        private void CountCast() { if (++casts > MaxCasts) throw new InvalidOperationException("PHYSICS_QUERY_BUDGET"); }
        private static Dictionary<string, object> Copy(Dictionary<string, object> row) { return new Dictionary<string, object>(row); }
        private static Vector3 Horizontal(Vector3 v) { v.y = 0; return v; }
        private static float[] P(Vector3 v) { return new[] { v.x, v.y, v.z }; }
        private static bool Finite(float v) { return !float.IsNaN(v) && !float.IsInfinity(v); }
        private static bool Finite(double v) { return !double.IsNaN(v) && !double.IsInfinity(v); }
        private static bool Finite(Vector3 v) { return Finite(v.x) && Finite(v.y) && Finite(v.z); }
        private static bool ExactZero(Vector3 v) { return Finite(v) && v.x == 0 && v.y == 0 && v.z == 0; }
        private bool ControlCurrent() { return active && !blocked && !arrived && !unobservedTerminal; }
    }
}
