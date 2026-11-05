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
        private const int Mask = -1, MaxEvidence = 16384, MaxCasts = 64;
        private const float Numerical = 0.001f, MaxTick = 0.1f, MaxAcceleration = 4f;
        private readonly ScientistNPC npc;
        private readonly RustNavMeshAgent agent;
        private readonly string world, actor;
        private readonly Action<object> sink;
        private readonly CapsuleCollider capsule;
        private readonly Rigidbody body;
        private readonly Vector3 originalCenter, originalScale;
        private readonly float radius, height, maxStep, maxDrop, maxSlope, maxSpeed, skin, supportTolerance;
        private readonly float navClimb, navSlope, navRadius, navHeight;
        private readonly bool originalKinematic, originalGravity;
        private readonly string originalCollisionMode;
        private readonly int originalLayer;
        private readonly object profile;
        private readonly List<Vector3> route = new List<Vector3>();
        private readonly Stopwatch queryClock = new Stopwatch();
        private readonly List<object> evidence = new List<object>();
        private int routeIndex, ticks, casts, command, retries, actuations, heightWitnesses, unchangedWitnesses;
        private float lastTime, startTime, commandTime;
        private Vector3 destination, lastPosition, lastVelocity, commanded, commandFrom;
        private Vector3 routeFrom;
        private RustNavmesh routeMesh;
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
            supportTolerance = skin + 0.05f; // Initial terrain spawn may be 5 cm above ground.
            profile = new { MaxStep = maxStep, MaxDrop = maxDrop, MaxSlope = maxSlope, MaxSpeed = maxSpeed,
                MaxAcceleration = MaxAcceleration, MaxTick = MaxTick, Skin = skin, SupportTolerance = supportTolerance,
                NavClimb = build.agentMaxClimb, NavSlope = build.agentMaxSlope, NavRadius = build.agentRadius,
                NavHeight = build.agentHeight, NativeStepCeiling = BaseNavigator.maxStepUpDistance,
                Capability = "CUSTOM_CHECKED_CONTROLLER_NOT_NATIVE_STEP_PROOF" };
            agent.isStopped = true; agent.updatePosition = false; agent.updateRotation = false; agent.ResetPath();
            string invalid = BodyProblem();
            if (invalid != null || !Finite(maxStep) || maxStep <= 0 || !Finite(maxSlope) || maxSlope <= 0 ||
                !Finite(maxSpeed) || maxSpeed <= 0 || !Finite(skin) || skin <= 0 || skin > 0.05f)
                throw new InvalidOperationException("Traversal profile UNKNOWN: " + (invalid ?? "INVALID_NATIVE_LIMITS"));
        }

        public bool Arrived { get { return arrived; } }
        public bool Blocked { get { return blocked; } }
        public bool Active { get { return active; } }
        public string Reason { get { return reason; } }
        public List<object> Evidence { get { return evidence; } }
        public int Actuations { get { return actuations; } }

        // A bounded read-only production probe, also usable before door actions.
        // It cannot move, manufacture a successful witness or resolve a step.
        public bool ProbeDisplacement(Vector3 displacement, string stage)
        {
            this.stage = stage ?? "UNSPECIFIED"; casts = 0; queryClock.Restart();
            supportDirection = Horizontal(displacement).normalized;
            var actual = npc.transform.position; var frame = Frame(Time.realtimeSinceStartup, actual);
            try
            {
                if (pending || acquiring || unobservedTerminal || BodyProblem() != null || !Finite(displacement) || displacement.magnitude > radius * 4f)
                { Block(frame, "UNKNOWN", "PROBE_INVALID_OR_PENDING"); return false; }
                var support = Support(actual); var landing = Support(actual + displacement);
                var sweeps = new List<object>(); var overlaps = new List<object>(); var endOverlaps = new List<object>();
                bool currentClear = Overlaps(actual, support, overlaps);
                bool sweepClear = Sweep(actual, actual + displacement, support, sweeps);
                bool endpointClear = Overlaps(actual + displacement, landing, endOverlaps);
                bool permission = Permission(actual), landingPermission = Permission(actual + displacement);
                float waterDepth = WaterLevel.GetWaterSurface(actual, true, true, null) - actual.y;
                float landingWater = WaterLevel.GetWaterSurface(actual + displacement, true, true, null) - (actual + displacement).y;
                bool safe = currentClear && sweepClear && endpointClear && Supported(support) && SupportedAt(landing, actual + displacement) &&
                    permission && landingPermission && Finite(waterDepth) && waterDepth <= 0.15f && Mathf.Abs(displacement.y) <= (displacement.y >= 0 ? maxStep : maxDrop) &&
                    Finite(landingWater) && landingWater <= 0.15f;
                frame["Requested"] = P(actual + displacement); frame["Support"] = SupportRow(support); frame["Landing"] = SupportRow(landing);
                frame["Sweeps"] = sweeps.ToArray(); frame["Overlaps"] = overlaps.ToArray(); frame["LandingOverlaps"] = endOverlaps.ToArray();
                frame["Classification"] = safe ? Classify(actual, actual + displacement, support, landing) : closedDoorHit ? "DOOR_CLOSED" : dynamicHit ? "DYNAMIC_BLOCKED" : "SOLID_BLOCKED";
                frame["NativeResult"] = "PROBE_ONLY"; frame["Reason"] = safe ? "READ_ONLY_CHECKED" : "READ_ONLY_REFUSED";
                Conditions(frame, actual, support, currentClear, permission, waterDepth);
                frame["LandingPermission"] = landingPermission; frame["LandingWaterDepth"] = landingWater;
                frame["LandingSupportAccepted"] = Supported(landing);
                Emit("OBSTACLE_PROBE", frame);
                if (!safe) { Emit("PHYSICAL_CONTACT", frame); Block(frame, (string)frame["Classification"], "READ_ONLY_REFUSED"); }
                return safe;
            }
            catch (Exception ex) { Block(frame, "UNKNOWN", "PROBE_NATIVE_FAILURE:" + ex.GetType().Name); return false; }
            finally { queryClock.Stop(); }
        }

        public bool SetDestination(Vector3 destination, string stage)
        {
            if (pending || unobservedTerminal) { Stop("UNOBSERVED_COMMAND"); return false; }
            if (acquiring) { Stop("ACQUISITION_ALREADY_ACTIVE_OR_FAILED"); return false; }
            if (lastVelocity.magnitude > Numerical) { Stop("DESTINATION_CHANGE_BEFORE_OBSERVED_REST"); return false; }
            this.destination = destination; this.stage = stage ?? "UNSPECIFIED";
            active = true; arrived = blocked = false; reason = "ROUTE"; retries = 0; heightWitnesses = 0; unchangedWitnesses = 0;
            lastTime = startTime = Time.realtimeSinceStartup; lastPosition = npc.transform.position;
            if (!Finite(destination) || BodyProblem() != null || !Plan(destination))
            { Stop("UNKNOWN_ROUTE_OR_BODY"); return false; }
            supportDirection = Horizontal(route[routeIndex] - lastPosition).normalized;
            return true;
        }

        public void Stop(string reason)
        {
            agent.isStopped = true; agent.updatePosition = false; agent.updateRotation = false;
            if (pending) { reason = "UNOBSERVED_COMMAND:" + reason; unobservedTerminal = true; }
            active = false; arrived = false; blocked = true; this.reason = reason;
            var frame = pendingFrame == null ? Frame(Time.realtimeSinceStartup, npc.transform.position) : Copy(pendingFrame);
            frame["Actual"] = P(npc.transform.position); frame["Reason"] = reason;
            frame["NativeResult"] = pending ? "UNOBSERVED" : "STOPPED";
            Emit("BLOCKED", frame);
            pending = false; pendingFrame = null;
        }

        public void Tick(float now)
        {
            if (!active) return; // No physics sensor work at idle.
            casts = 0; queryClock.Restart(); ticks++;
            try { TickCore(now); }
            catch (Exception ex)
            {
                Stop("UNKNOWN_NATIVE_FAILURE:" + ex.GetType().Name + ":" + ex.Message);
            }
            finally { queryClock.Stop(); }
        }

        private void TickCore(float now)
        {
            Vector3 actual = npc.transform.position;
            float dt = now - lastTime;
            var frame = Frame(now, actual);
            string invalid = BodyProblem();
            if (invalid != null || !Finite(now) || dt <= 0 || dt > MaxTick || now - startTime > 120f || ticks > 6000)
            { Block(frame, "UNKNOWN", invalid ?? "TIME_OR_TICK_BUDGET"); return; }
            if (!pending && Vector3.Distance(actual, lastPosition) > Numerical)
            { Block(frame, "UNKNOWN", "COMPETING_WRITER"); return; }
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
                acquisitionFloorY = support.FootY; acquisitionNormal = support.Normal; acquisitionPoint = support.Point;
                frame["SupportPhase"] = "FLOOR_ACQUISITION"; frame["Acquisition"] = AcquisitionRow(actual, support);
                frame["MotionMode"] = "FLOOR_ACQUISITION"; frame["NativeResult"] = "STATIONARY_OBSERVATION";
                frame["Classification"] = "CLEAR"; // Obstacle-clear observation; SupportAccepted remains false.
                frame["PosePrevious"] = P(lastPosition); frame["PosePreviousTime"] = lastTime;
                frame["ObservedVelocity"] = P((actual - lastPosition) / dt);
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
                var observedSweeps = new List<object>();
                bool clear = Sweep(commandFrom, actual, support, observedSweeps);
                float elapsed = now - commandTime;
                Vector3 velocity = (actual - commandFrom) / elapsed;
                float speed = velocity.magnitude, acceleration = (velocity - lastVelocity).magnitude / elapsed;
                frame["Command"] = command; frame["From"] = P(commandFrom); frame["Requested"] = P(commanded);
                frame["PreviousTime"] = commandTime; frame["Dt"] = elapsed;
                frame["Distance"] = Vector3.Distance(commandFrom, actual); frame["Speed"] = speed; frame["Acceleration"] = acceleration;
                frame["Sweeps"] = observedSweeps.ToArray(); frame["Classification"] = commandClass;
                frame["NativeResult"] = "OBSERVED";
                frame["MotionMode"] = commandAcquisition ? commandHold ? "ACQUISITION_BRAKE_HOLD" : "FLOOR_ACQUISITION" : commandHold ? "BRAKE_HOLD" : "SUPPORTED_ADVANCE";
                frame["ObservedVelocity"] = P(velocity);
                if (!currentSafe || !clear || elapsed <= 0 || elapsed > MaxTick || Vector3.Distance(actual, commanded) > Numerical ||
                    !Finite(speed) || speed > maxSpeed + Numerical || acceleration > MaxAcceleration + Numerical ||
                    commandAcquisition && (actual.x != commandFrom.x || actual.z != commandFrom.z || actual.y > commandFrom.y))
                {
                    pending = false; pendingFrame = null; frame["NativeResult"] = "OBSERVED_UNSAFE";
                    Emit("MOTION_WITNESS", frame); Emit("PHYSICAL_CONTACT", frame);
                    Block(frame, "UNKNOWN", !clear || !overlapClear ? "KINEMATIC_CLIP" : !currentSafe ? "ACTUAL_SUPPORT_OR_PERMISSION_LOST" : "ACTUATOR_DIVERGENCE_OR_CONTINUITY"); return;
                }
                pending = false; pendingFrame = null;
                Emit("MOTION_WITNESS", frame);
                unchangedWitnesses = !commandHold && Vector3.Distance(actual, commandFrom) <= 0.00001f ? unchangedWitnesses + 1 : 0;
                if (unchangedWitnesses >= 3)
                { Block(frame, "UNKNOWN", "STUCK_ACTUAL_POSE"); return; }
                float dy = actual.y - commandFrom.y;
                if ((commandClass == "SMALL_STEP_UP" || commandClass == "STEP_DOWN" || commandClass == "SLOPE") && Mathf.Abs(dy) > Numerical)
                {
                    if (heightClass != commandClass) { heightClass = commandClass; heightWitnesses = 0; }
                    heightWitnesses++;
                    if (heightWitnesses == 2) Emit("STEP_RESOLVED", frame);
                }
                else { heightWitnesses = 0; heightClass = null; }
                lastVelocity = velocity; lastPosition = actual; lastTime = now;
                // A command's witness is the only work that can precede the next
                // command; the initial decision below uses fresh sensor results.
            }
            if (RustNavigation.Instance == null || RustNavigation.Instance.DefaultNavmesh == null ||
                RustNavigation.Instance.HasPendingTiles() || !agent.isOnNavMesh)
            { Block(frame, "UNKNOWN", "NAV_INVALIDATED"); return; }
            if (!NavEpochMatches())
            {
                frame["NavigationEpoch"] = new { OldChange = routeTileChangeVersion, OldData = routeTileDataVersion,
                    NewChange = RustNavigation.Instance.DefaultNavmesh.TileChangeVersion, NewData = RustNavigation.Instance.DefaultNavmesh.TileDataVersion };
                if (retries++ >= 1 || !Plan(destination)) { Block(frame, "UNKNOWN", "NAV_EPOCH_REPATH_FAILED_OR_EXHAUSTED"); return; }
                frame["Navigation"] = NavigationRow(); frame["Reason"] = "NATIVE_NAV_EPOCH_CHANGED"; Emit("REPATH", frame);
            }
            if (acquiring)
            {
                if (lastVelocity.sqrMagnitude == 0 && Supported(support) && support.Gap <= skin + Numerical && commandAcquisition)
                {
                    frame["NativeResult"] = "OBSERVED"; frame["Reason"] = "ACTUAL_SUPPORTED_REST";
                    Emit("FLOOR_ACQUIRED", frame);
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
                    if (SupportedAt(landing, requested) && Mathf.Abs(requested.y - actual.y) <= (requested.y >= actual.y ? maxStep : maxDrop) &&
                        Finite(velocity) && velocity.magnitude > maxSpeed + Numerical)
                    { horizontalDistance *= maxSpeed / velocity.magnitude; continue; }
                    if (SupportedAt(landing, requested) && Mathf.Abs(requested.y - actual.y) <= (requested.y >= actual.y ? maxStep : maxDrop) &&
                        velocity.magnitude <= maxSpeed + Numerical && (velocity - lastVelocity).magnitude / dt <= MaxAcceleration + Numerical)
                    { candidate = true; break; }
                }
                horizontalDistance *= 0.5f;
            }
            if (!candidate)
            { frame["Landing"] = landing == null ? null : SupportRow(landing); Obstacle(frame, "UNSUPPORTED_GAP", "NO_BOUNDED_SUPPORTED_TRAJECTORY"); return; }
            bool hold = Vector3.Distance(actual, requested) < 0.00001f && lastVelocity.magnitude <= MaxAcceleration * dt;
            if (hold) requested = actual; // Issue and witness exact rest, including vertical velocity.
            // Rebind the landing measurement to the final commanded pose rather
            // than retaining the exploratory same-height sphere-cast origin.
            landing = Support(requested);
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
            Emit("OBSTACLE_PROBE", frame);
            if (!sweptClear || !endClear || !landingPermission || !Finite(landingWater) || landingWater > 0.15f)
            {
                Emit("PHYSICAL_CONTACT", frame);
                Obstacle(frame, closedDoorHit ? "DOOR_CLOSED" : dynamicHit ? "DYNAMIC_BLOCKED" : "SOLID_BLOCKED", "FULL_VOLUME_OR_PERMISSION_BLOCKED"); return;
            }
            if (Vector3.Distance(actual, requested) < 0.00001f && !hold) { Block(frame, "UNKNOWN", "NO_PROGRESS"); return; }
            if (classification != "CLEAR") Emit("STEP_ATTEMPT", frame);
            if (evidence.Count >= MaxEvidence - 8) { Block(frame, "UNKNOWN", "EVIDENCE_BUDGET"); return; }
            if (!NavEpochMatches()) { Block(frame, "UNKNOWN", "NAV_EPOCH_CHANGED_DURING_PROBE"); return; }
            frame["NativeResult"] = "PRECHECKED";
            frame["MotionMode"] = hold ? "BRAKE_HOLD" : "SUPPORTED_ADVANCE";
            Emit("MOVE_DECISION", frame);
            if (!active) return; // Receipt/cast budgets fail closed before actuation.
            command++; commanded = requested; commandFrom = actual; commandTime = now; commandClass = classification; commandHold = hold; commandAcquisition = false;
            pendingFrame = Copy(frame); pending = true;
            // This is the sole position actuator. No native collision response is
            // assumed; full pre-query and next-tick actual geometry are mandatory.
            body.MovePosition(body.position + requested - actual); actuations++;
            acquisitionEligible = false;
            lastPosition = actual; lastTime = now;
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
                Remaining = Mathf.Max(0, s.Gap - skin), RestObservationTime = acquisitionRestTime, RestObservationPose = P(acquisitionStart) };
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
            if (now <= acquisitionRestTime || !AcquisitionSupported(actual, support) || lastVelocity.x != 0 || lastVelocity.z != 0 || lastVelocity.y > 0)
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
            if (!sweepClear || !endpointClear || !AcquisitionSupported(requested, landing) || !landingPermission || !Finite(landingWater) || landingWater > 0.15f)
            { Emit("PHYSICAL_CONTACT", frame); Block(frame, "UNKNOWN", "ACQUISITION_TRAJECTORY_UNSAFE"); return; }
            if (!NavEpochMatches() || evidence.Count >= MaxEvidence - 8)
            { Block(frame, "UNKNOWN", "ACQUISITION_NAV_OR_EVIDENCE_BUDGET"); return; }
            frame["NativeResult"] = "PRECHECKED"; Emit("MOVE_DECISION", frame);
            if (!active) return;
            command++; commanded = requested; commandFrom = actual; commandTime = now; commandClass = "CLEAR";
            commandHold = hold; commandAcquisition = true; pendingFrame = Copy(frame); pending = true;
            body.MovePosition(body.position + requested - actual); actuations++;
            lastPosition = actual; lastTime = now;
        }

        private bool Plan(Vector3 end)
        {
            var nav = RustNavigation.Instance;
            if (nav == null || nav.DefaultNavmesh == null || nav.HasPendingTiles()) return false;
            var mesh = nav.DefaultNavmesh; var build = mesh.BuildParams;
            if (build.agentMaxClimb != navClimb || build.agentMaxSlope != navSlope || build.agentRadius != navRadius || build.agentHeight != navHeight) return false;
            int change = mesh.TileChangeVersion, data = mesh.TileDataVersion;
            var path = new RustNavMeshPath();
            routeFrom = npc.transform.position;
            bool calculated = agent.CalculatePath(new NavVector3(routeFrom), new NavVector3(end), path);
            routeStatus = calculated ? path.status.ToString() : "CALCULATE_FAILED";
            if (!calculated || path.status != NavMeshPathStatus.PathComplete || path.corners.Count < 2)
                return false;
            if (nav.DefaultNavmesh != mesh || mesh.TileChangeVersion != change || mesh.TileDataVersion != data) return false;
            routeMesh = mesh; routeTileChangeVersion = change; routeTileDataVersion = data;
            route.Clear(); route.AddRange(path.corners.Select(x => x.Value)); routeIndex = 1; return true;
        }

        private bool NavEpochMatches()
        {
            var nav = RustNavigation.Instance;
            return nav != null && nav.DefaultNavmesh != null && nav.DefaultNavmesh == routeMesh &&
                routeMesh.TileChangeVersion == routeTileChangeVersion && routeMesh.TileDataVersion == routeTileDataVersion;
        }

        private object NavigationRow()
        {
            var nav = RustNavigation.Instance; var mesh = nav == null ? null : nav.DefaultNavmesh;
            return new { OnNavMesh = agent.isOnNavMesh, PendingTiles = nav == null || nav.HasPendingTiles(), RouteStatus = routeStatus,
                RouteFrom = P(routeFrom), RouteTo = P(destination), Corners = route.Select(P).ToArray(),
                PlannedTileChangeVersion = routeTileChangeVersion, PlannedTileDataVersion = routeTileDataVersion,
                TileChangeVersion = mesh == null ? -1 : mesh.TileChangeVersion, TileDataVersion = mesh == null ? -1 : mesh.TileDataVersion,
                PlannedMesh = routeMesh == null ? null : routeMesh.NavMeshHandle.ToString(), Mesh = mesh == null ? null : mesh.NavMeshHandle.ToString() };
        }

        private void Obstacle(Dictionary<string, object> frame, string classification, string why)
        {
            frame["Classification"] = classification; frame["Reason"] = why;
            if (pending) { Block(frame, classification, why); return; }
            if (retries++ == 0)
            {
                Vector3 actual = npc.transform.position;
                Vector3 forward = Horizontal(destination - actual).normalized;
                Vector3 side = Vector3.Cross(Vector3.up, forward) * (radius * 3f);
                List<Vector3> best = null; float bestLength = float.PositiveInfinity;
                for (int sign = -1; sign <= 1; sign += 2)
                {
                    var a = new RustNavMeshPath(); var b = new RustNavMeshPath(); Vector3 detour = actual + side * sign + forward * radius;
                    if (agent.CalculatePath(new NavVector3(actual), new NavVector3(detour), a) && a.status == NavMeshPathStatus.PathComplete &&
                        agent.CalculatePath(new NavVector3(detour), new NavVector3(destination), b) && b.status == NavMeshPathStatus.PathComplete && a.corners.Count > 1 && b.corners.Count > 1)
                    {
                        float length = a.GetPathLength() + b.GetPathLength();
                        if (length < bestLength) { bestLength = length; best = a.corners.Select(x => x.Value).Concat(b.corners.Skip(1).Select(x => x.Value)).ToList(); }
                    }
                }
                frame["Retry"] = retries; frame["Route"] = best == null ? new float[0][] : best.Select(P).ToArray();
                Emit("REPATH", frame);
                if (best != null) { route.Clear(); route.AddRange(best); routeIndex = 1; routeFrom = actual; routeStatus = "PathComplete"; lastTime = (float)frame["Time"]; return; }
            }
            Block(frame, classification, why + ":BOUNDED_REPATH_EXHAUSTED");
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
                Prefab = entity == null ? null : entity.PrefabName, Enabled = c.enabled, Trigger = c.isTrigger, Layer = c.gameObject.layer,
                BoundsCenter = P(c.bounds.center), BoundsSize = P(c.bounds.size), DoorOpen = door == null ? (bool?)null : door.IsOpen(),
                RigidbodyInstance = rigid == null ? (int?)null : rigid.GetInstanceID(), Kinematic = rigid == null ? (bool?)null : rigid.isKinematic };
        }
        private Dictionary<string, object> Frame(float now, Vector3 actual)
        {
            return new Dictionary<string, object> { { "Schema", 1 }, { "Actor", actor }, { "World", world }, { "Stage", stage }, { "Time", now }, { "Tick", ticks },
                { "Command", command }, { "Classification", "UNKNOWN" }, { "Reason", reason }, { "Body", BodyRow() }, { "Profile", profile },
                { "From", P(actual) }, { "Requested", P(actual) }, { "Actual", P(actual) }, { "PreviousTime", lastTime }, { "Dt", now - lastTime },
                { "Support", null }, { "Sweeps", new object[0] }, { "Overlaps", new object[0] }, { "Mask", Mask }, { "Triggers", "Ignore" },
                { "Permission", null }, { "WaterDepth", null }, { "SupportAccepted", null }, { "OverlapClear", null },
                { "SupportPhase", acquiring ? "FLOOR_ACQUISITION" : "NORMAL" }, { "Acquisition", null },
                { "Navigation", NavigationRow() },
                { "Actuator", "Rigidbody.MovePosition" }, { "NativeResult", "NOT_ISSUED" }, { "Retry", retries } };
        }
        private void Block(Dictionary<string, object> frame, string classification, string why)
        {
            active = false; arrived = false; blocked = true; reason = why;
            frame["Classification"] = classification; frame["Reason"] = why; frame["UnobservedCommand"] = pending;
            Emit("BLOCKED", frame); agent.isStopped = true;
        }
        private void Emit(string name, Dictionary<string, object> frame)
        {
            if (evidence.Count >= MaxEvidence) { active = false; blocked = true; arrived = false; reason = "EVIDENCE_BUDGET"; return; }
            var row = Copy(frame); row["Event"] = name; row["Casts"] = casts; row["QueryMilliseconds"] = queryClock.Elapsed.TotalMilliseconds;
            evidence.Add(row); if (sink != null) sink(row);
        }
        private void CountCast() { if (++casts > MaxCasts) throw new InvalidOperationException("PHYSICS_QUERY_BUDGET"); }
        private static Dictionary<string, object> Copy(Dictionary<string, object> row) { return new Dictionary<string, object>(row); }
        private static Vector3 Horizontal(Vector3 v) { v.y = 0; return v; }
        private static float[] P(Vector3 v) { return new[] { v.x, v.y, v.z }; }
        private static bool Finite(float v) { return !float.IsNaN(v) && !float.IsInfinity(v); }
        private static bool Finite(Vector3 v) { return Finite(v.x) && Finite(v.y) && Finite(v.z); }
    }
}
