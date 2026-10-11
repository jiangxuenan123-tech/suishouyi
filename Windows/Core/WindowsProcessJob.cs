using System.Diagnostics;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
namespace Suishouyi.Core;
internal sealed class WindowsProcessJob:IDisposable {
 readonly SafeFileHandle handle;
 WindowsProcessJob(SafeFileHandle handle){this.handle=handle;}
 public static WindowsProcessJob Create(Process process){var handle=CreateJobObject(IntPtr.Zero,null);var limits=new ExtendedLimits{Basic=new BasicLimits{LimitFlags=0x2000}};if(handle.IsInvalid||!SetInformationJobObject(handle,9,ref limits,(uint)Marshal.SizeOf<ExtendedLimits>())||!AssignProcessToJobObject(handle,process.Handle)){handle.Dispose();if(!process.HasExited)process.Kill(true);throw new IOException("无法建立请求进程清理范围。");}return new(handle);}
 public void Dispose()=>handle.Dispose();
 [StructLayout(LayoutKind.Sequential)]struct BasicLimits {public long ProcessTime,JobTime;public uint LimitFlags;public UIntPtr MinWorkingSet,MaxWorkingSet;public uint ActiveProcessLimit;public UIntPtr Affinity;public uint PriorityClass,SchedulingClass;}
 [StructLayout(LayoutKind.Sequential)]struct IoCounters {public ulong ReadOps,WriteOps,OtherOps,ReadBytes,WriteBytes,OtherBytes;}
 [StructLayout(LayoutKind.Sequential)]struct ExtendedLimits {public BasicLimits Basic;public IoCounters Io;public UIntPtr ProcessMemory,JobMemory,PeakProcessMemory,PeakJobMemory;}
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode)]static extern SafeFileHandle CreateJobObject(IntPtr attributes,string? name);
 [DllImport("kernel32.dll")]static extern bool SetInformationJobObject(SafeFileHandle job,int infoClass,ref ExtendedLimits info,uint length);
 [DllImport("kernel32.dll")]static extern bool AssignProcessToJobObject(SafeFileHandle job,IntPtr process);
}
