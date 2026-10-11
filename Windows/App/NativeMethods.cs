using System.Runtime.InteropServices;
namespace Suishouyi.App;
internal static class NativeMethods {
 [DllImport("user32.dll")]internal static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")]internal static extern bool SetForegroundWindow(IntPtr window);
 [DllImport("user32.dll")]internal static extern uint GetClipboardSequenceNumber();
 [DllImport("user32.dll")]internal static extern bool RegisterHotKey(IntPtr window,int id,uint modifiers,uint key);
 [DllImport("user32.dll")]internal static extern bool UnregisterHotKey(IntPtr window,int id);
 [DllImport("user32.dll")]internal static extern void keybd_event(byte key,byte scan,uint flags,UIntPtr extra);
 [DllImport("user32.dll")]internal static extern bool GetCursorPos(out POINT point);
 [StructLayout(LayoutKind.Sequential)] internal struct POINT {public int X; public int Y;}
}
