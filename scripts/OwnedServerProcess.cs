// Windows 10+ Job Object ownership: atomic assignment at creation, then resume.
using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

namespace RustBots
{
    public sealed class OwnedServerProcess : IDisposable
    {
        private IntPtr job;
        public Process Process { get; private set; }
        private OwnedServerProcess() { }

        public static OwnedServerProcess Start(string exe, string arguments, string cwd)
        {
            var owned = new OwnedServerProcess();
            var pi = new ProcessInformation();
            IntPtr attributes = IntPtr.Zero, jobValue = IntPtr.Zero;
            bool attributesReady = false;
            try
            {
                owned.job = CreateJobObject(IntPtr.Zero, null);
                if (owned.job == IntPtr.Zero) throw new Win32Exception();
                var limits = new ExtendedLimits();
                limits.Basic.LimitFlags = 0x2000; // JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
                if (!SetInformationJobObject(owned.job, 9, ref limits, (uint)Marshal.SizeOf(limits)))
                    throw new Win32Exception();
                // Atomic job assignment closes the suspended-but-unowned window.
                // Unsupported Windows versions fail before any process is created.
                IntPtr required = IntPtr.Zero;
                InitializeProcThreadAttributeList(IntPtr.Zero, 1, 0, ref required);
                if (required == IntPtr.Zero) throw new Win32Exception();
                attributes = Marshal.AllocHGlobal(required);
                if (!InitializeProcThreadAttributeList(attributes, 1, 0, ref required)) throw new Win32Exception();
                attributesReady = true;
                jobValue = Marshal.AllocHGlobal(IntPtr.Size);
                Marshal.WriteIntPtr(jobValue, owned.job);
                if (!UpdateProcThreadAttribute(attributes, 0, new IntPtr(0x0002000D), jobValue,
                    new IntPtr(IntPtr.Size), IntPtr.Zero, IntPtr.Zero)) throw new Win32Exception();
                var si = new StartupInfoEx();
                si.Startup.Size = Marshal.SizeOf(si);
                si.Startup.Flags = 1; // STARTF_USESHOWWINDOW, hidden
                si.Attributes = attributes;
                var command = new StringBuilder("\"" + exe + "\" " + arguments);
                if (!CreateProcess(exe, command, IntPtr.Zero, IntPtr.Zero, false,
                    0x08080004, IntPtr.Zero, cwd, ref si, out pi)) // NO_WINDOW | EXTENDED_STARTUPINFO | SUSPENDED
                    throw new Win32Exception();
                owned.Process = Process.GetProcessById((int)pi.ProcessId);
                // Retain a real process handle before the suspended process can exit.
                var retainedHandle = owned.Process.Handle;
                if (ResumeThread(pi.Thread) == uint.MaxValue) throw new Win32Exception();
                return owned;
            }
            catch
            {
                owned.Dispose();
                throw;
            }
            finally
            {
                if (pi.Thread != IntPtr.Zero) CloseHandle(pi.Thread);
                if (pi.Process != IntPtr.Zero) CloseHandle(pi.Process);
                if (attributesReady) DeleteProcThreadAttributeList(attributes);
                if (attributes != IntPtr.Zero) Marshal.FreeHGlobal(attributes);
                if (jobValue != IntPtr.Zero) Marshal.FreeHGlobal(jobValue);
            }
        }

        public void Dispose()
        {
            if (job == IntPtr.Zero) return;
            CloseHandle(job); // kills only this job's processes, including owned children
            job = IntPtr.Zero;
            if (Process != null && !Process.WaitForExit(10000))
                throw new InvalidOperationException("Owned process did not exit after job close");
        }

        [StructLayout(LayoutKind.Sequential)] private struct BasicLimits
        {
            public long ProcessTime, JobTime;
            public uint LimitFlags;
            public UIntPtr MinWorkingSet, MaxWorkingSet;
            public uint ActiveProcessLimit;
            public UIntPtr Affinity;
            public uint PriorityClass, SchedulingClass;
        }
        [StructLayout(LayoutKind.Sequential)] private struct IoCounters
        { public ulong ReadOps, WriteOps, OtherOps, ReadBytes, WriteBytes, OtherBytes; }
        [StructLayout(LayoutKind.Sequential)] private struct ExtendedLimits
        {
            public BasicLimits Basic;
            public IoCounters Io;
            public UIntPtr ProcessMemory, JobMemory, PeakProcessMemory, PeakJobMemory;
        }
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] private struct StartupInfo
        {
            public int Size;
            public string Reserved, Desktop, Title;
            public uint X, Y, XSize, YSize, XChars, YChars, Fill, Flags;
            public ushort ShowWindow, Reserved2Length;
            public IntPtr Reserved2, Input, Output, Error;
        }
        [StructLayout(LayoutKind.Sequential)] private struct ProcessInformation
        { public IntPtr Process, Thread; public uint ProcessId, ThreadId; }
        [StructLayout(LayoutKind.Sequential)] private struct StartupInfoEx
        { public StartupInfo Startup; public IntPtr Attributes; }
        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        private static extern IntPtr CreateJobObject(IntPtr attributes, string name);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool SetInformationJobObject(IntPtr job, int info, ref ExtendedLimits limits, uint size);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool InitializeProcThreadAttributeList(IntPtr list, int count, int flags, ref IntPtr size);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool UpdateProcThreadAttribute(IntPtr list, uint flags, IntPtr attribute,
            IntPtr value, IntPtr size, IntPtr previous, IntPtr returnedSize);
        [DllImport("kernel32.dll")] private static extern void DeleteProcThreadAttributeList(IntPtr list);
        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        private static extern bool CreateProcess(string exe, StringBuilder command, IntPtr pa, IntPtr ta,
            bool inherit, uint flags, IntPtr environment, string cwd, ref StartupInfoEx startup, out ProcessInformation pi);
        [DllImport("kernel32.dll", SetLastError = true)] private static extern uint ResumeThread(IntPtr thread);
        [DllImport("kernel32.dll", SetLastError = true)] private static extern bool CloseHandle(IntPtr handle);
    }
}
