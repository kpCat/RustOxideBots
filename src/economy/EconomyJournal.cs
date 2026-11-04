// BCL-only helper appended to the isolated Oxide source by the probe runner.
namespace RustBots
{
    public sealed class EconomyJournal : System.IDisposable
    {
        public sealed class Entry
        {
            public string Kind, Intent, Stage, Payload;
        }
        private readonly System.IO.FileStream stream;
        private readonly System.Collections.Generic.List<Entry> entries = new System.Collections.Generic.List<Entry>();
        private readonly System.Collections.Generic.Dictionary<string, Entry> latest = new System.Collections.Generic.Dictionary<string, Entry>(System.StringComparer.Ordinal);
        private readonly System.Collections.Generic.HashSet<string> recovered = new System.Collections.Generic.HashSet<string>(System.StringComparer.Ordinal);
        private string previous = new string('0', 64);
        private int sequence;
        public Entry[] Entries { get { return entries.ToArray(); } }
        public static string Hash(string value) { return HashBytes(System.Text.Encoding.UTF8.GetBytes(value)); }
        public static string HashBytes(byte[] value)
        {
            using (var sha = System.Security.Cryptography.SHA256.Create())
                return System.BitConverter.ToString(sha.ComputeHash(value)).Replace("-", "");
        }
        private static void Require(bool condition, string reason) { if (!condition) throw new System.IO.InvalidDataException(reason); }
        public EconomyJournal(string path, string world, string actor, string recipe)
        {
            Require(!string.IsNullOrEmpty(world) && !string.IsNullOrEmpty(actor) && !string.IsNullOrEmpty(recipe), "Missing economy binding");
            bool existed = System.IO.File.Exists(path);
            stream = new System.IO.FileStream(path, existed ? System.IO.FileMode.Open : System.IO.FileMode.CreateNew, System.IO.FileAccess.ReadWrite, System.IO.FileShare.Read);
            try
            {
                Require(stream.Length <= 16000000, "Journal size bound");
                if (!existed) Write(new Entry { Kind = "HEADER", Intent = world, Stage = actor, Payload = recipe });
                else
                {
                    Require(stream.Length > 0, "Empty existing journal; quarantined");
                    byte[] all = new byte[(int)stream.Length]; int offset = 0;
                    while (offset < all.Length) { int count = stream.Read(all, offset, all.Length - offset); Require(count > 0, "Short journal read"); offset += count; }
                    Require(all[all.Length - 1] == 10, "Torn journal tail; quarantined");
                    var text = new System.Text.UTF8Encoding(false, true).GetString(all);
                    foreach (var line in text.Split('\n'))
                    {
                        if (line.Length == 0) continue;
                        Require(line.Length <= 1000000 && line.Length > 65 && line[64] == '|', "Invalid journal frame");
                        var bytes = System.Convert.FromBase64String(line.Substring(65));
                        Require(HashBytes(bytes) == line.Substring(0, 64), "Corrupt journal checksum");
                        Entry e;
                        using (var memory = new System.IO.MemoryStream(bytes))
                        using (var reader = new System.IO.BinaryReader(memory, new System.Text.UTF8Encoding(false, true)))
                        {
                            Require(reader.ReadInt32() == 1 && reader.ReadInt32() == sequence && reader.ReadString() == previous, "Journal schema/sequence/chain mismatch");
                            e = new Entry { Kind = reader.ReadString(), Intent = reader.ReadString(), Stage = reader.ReadString(), Payload = reader.ReadString() };
                            Require(memory.Position == memory.Length, "Unexpected journal bytes");
                        }
                        if (sequence == 0) Require(e.Kind == "HEADER" && e.Intent == world && e.Stage == actor && e.Payload == recipe, "Wrong world/actor/recipe binding");
                        else { Validate(e); latest[e.Intent] = e; }
                        entries.Add(e); previous = line.Substring(0, 64); sequence++;
                    }
                    Require(sequence > 0, "Missing journal header");
                    foreach (var intent in latest.Keys) recovered.Add(intent);
                }
            }
            catch { stream.Dispose(); throw; }
        }
        private void Validate(Entry e)
        {
            Require(!string.IsNullOrEmpty(e.Intent) && !string.IsNullOrEmpty(e.Payload), "Missing action identity/receipt");
            Require(e.Kind == "GATHER" || e.Kind == "CRAFT", "Unknown economic action");
            Entry old; latest.TryGetValue(e.Intent, out old);
            Require(!recovered.Contains(e.Intent), "Recovered intent cannot execute: IN_DOUBT or already committed");
            var stages = e.Kind == "GATHER" ? new[] { "PREPARED", "APPLIED", "COMMITTED" } : new[] { "PREPARED", "DEBITTING", "DEBITED", "OUTPUT_CREATED", "COMMITTED" };
            int next = old == null ? 0 : System.Array.IndexOf(stages, old.Stage) + 1;
            Require((old == null || old.Kind == e.Kind) && next < stages.Length && stages[next] == e.Stage, "Duplicate intent or invalid economic transition");
        }
        public void Append(string kind, string intent, string stage, string payload)
        {
            var e = new Entry { Kind = kind, Intent = intent, Stage = stage, Payload = payload };
            Validate(e); Write(e); latest[intent] = e;
        }
        private void Write(Entry e)
        {
            byte[] body;
            using (var memory = new System.IO.MemoryStream())
            {
                using (var writer = new System.IO.BinaryWriter(memory, System.Text.Encoding.UTF8, true))
                {
                    writer.Write(1); writer.Write(sequence); writer.Write(previous);
                    writer.Write(e.Kind); writer.Write(e.Intent); writer.Write(e.Stage); writer.Write(e.Payload);
                }
                body = memory.ToArray();
            }
            Require(body.Length < 700000 && stream.Length + body.Length * 2 < 16000000, "Journal size bound");
            var checksum = HashBytes(body);
            var line = System.Text.Encoding.UTF8.GetBytes(checksum + "|" + System.Convert.ToBase64String(body) + "\n");
            stream.Seek(0, System.IO.SeekOrigin.End); stream.Write(line, 0, line.Length); stream.Flush(true);
            previous = checksum; sequence++; entries.Add(e);
        }
        public string RecoveryState(string intent)
        {
            Entry e; return !latest.TryGetValue(intent, out e) ? "UNSEEN" : e.Stage == "COMMITTED" ? "COMMITTED" : "IN_DOUBT";
        }
        public void RequireComplete()
        {
            foreach (var e in latest.Values) Require(e.Stage == "COMMITTED", "IN_DOUBT: automatic recovery/reward forbidden");
        }
        public static bool LoadedHealthMatches(bool staged, double saved, double expected, double actual, double startHealth)
        {
            // Installed StagedResourceEntity.Load deliberately resets health/stage from disk.
            return System.Math.Abs(saved - expected) < 0.001 && System.Math.Abs(actual - (staged ? startHealth : expected)) < 0.001;
        }
        public static bool CanSustainHarvest(double pool, double startAmount, double health, double maxHealth, double gatherDamage, double destroyFraction, int remaining)
        {
            foreach (var v in new[] { pool, startAmount, health, maxHealth, gatherDamage, destroyFraction })
                if (double.IsNaN(v) || double.IsInfinity(v)) return false;
            if (pool <= 0 || startAmount <= 0 || health <= 0 || maxHealth <= 0 || gatherDamage <= 0 || destroyFraction < 0 || remaining <= 0) return false;
            // IL: reward is rounded startAmount * damage/maxHealth; extra native destruction
            // is reward * 2 * destroyFraction. Reserve two hits and round upward for admission.
            // This is a conservative selection gate, never an execution/reward calculation.
            // Installed tree/ore bonus paths can raise gatherScale up to 2/3 respectively.
            double reserve = (remaining + 2 * System.Math.Ceiling(startAmount * gatherDamage * 3 / maxHealth) + 2) * (1 + 2 * destroyFraction);
            return System.Math.Min(pool, startAmount * health / maxHealth) > reserve;
        }
        public static string PoolDecision(double initial, double expected, double initialFraction, double expectedFraction, double actual, double fraction, bool diskIncarnation, int matches)
        {
            foreach (double v in new[] { initial, expected, initialFraction, expectedFraction, actual, fraction }) Require(!double.IsNaN(v) && !double.IsInfinity(v), "Nonfinite pool");
            Require(diskIncarnation && matches == 1, "SOURCE_IDENTITY_AMBIGUOUS");
            Require(initial > expected && expected > 0 && initialFraction > expectedFraction && expectedFraction > 0 && initialFraction <= 1.001, "Invalid depletion receipt");
            if (System.Math.Abs(actual - expected) < 0.001 && System.Math.Abs(fraction - expectedFraction) < 0.00001) return "NOOP";
            Require(System.Math.Abs(actual - initial) < 0.001 && System.Math.Abs(fraction - initialFraction) < 0.00001, "Incompatible pool: neither exact depletion nor proven full reset");
            return "APPLY";
        }
        public void Dispose() { stream.Dispose(); }
    }
}
