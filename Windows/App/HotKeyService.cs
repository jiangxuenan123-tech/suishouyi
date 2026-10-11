using Suishouyi.Core;
namespace Suishouyi.App;
internal sealed class HotKeyService:NativeWindow,IDisposable {
 readonly Action<TaskMode,IntPtr> callback;
 public HotKeyService(Action<TaskMode,IntPtr> callback){this.callback=callback;CreateHandle(new CreateParams());}
 public bool Register(int id,uint modifiers,int key) => NativeMethods.RegisterHotKey(Handle,id,modifiers|0x4000,(uint)key);
 public void Unregister(int id)=>NativeMethods.UnregisterHotKey(Handle,id);
 protected override void WndProc(ref Message message){if(message.Msg==0x0312 && message.WParam.ToInt32() is 1 or 2) callback(message.WParam.ToInt32()==1?TaskMode.Translation:TaskMode.Explanation,NativeMethods.GetForegroundWindow());base.WndProc(ref message);}
 public void Dispose(){Unregister(1);Unregister(2);DestroyHandle();}
}
