using System.Windows.Automation;
using Suishouyi.Core;
namespace Suishouyi.App;
internal static class SelectionReader {
 public static async Task<string?> ReadAsync(IntPtr source,CancellationToken token) {
  if(source==IntPtr.Zero)return null;
  try {
   var element=AutomationElement.FromHandle(source);if(element.Current.ProcessId==Environment.ProcessId)return null;var focused=AutomationElement.FocusedElement;
   if(focused is not null && focused.Current.ProcessId==element.Current.ProcessId && focused.TryGetCurrentPattern(TextPattern.Pattern,out var value)) {
    var text=string.Join("\n",((TextPattern)value).GetSelection().Select(r=>r.GetText(-1))).Trim();if(text.Length>0)return text;
   }
  } catch(System.Runtime.InteropServices.COMException) {} catch(ElementNotAvailableException) {}
  var data=Clipboard.GetDataObject();var snapshot=new DataObject();
  if(data is not null)foreach(var format in data.GetFormats(false)) {
   var value=data.GetData(format,false);
   if(value is MemoryStream stream)value=new MemoryStream(stream.ToArray());
   if(value is Bitmap bitmap)value=new Bitmap(bitmap);
   if(value is null)return null;snapshot.SetData(format,false,value);
  }
  var copy=new ClipboardCopyState(NativeMethods.GetClipboardSequenceNumber());NativeMethods.SetForegroundWindow(source);
  await Task.Delay(80,token);if(NativeMethods.GetForegroundWindow()!=source)return null;
  // Release shortcut modifiers before Ctrl+C so Ctrl+Shift+C is never sent.
  foreach(var key in new byte[]{0x10,0x12,0x11})NativeMethods.keybd_event(key,0,2,UIntPtr.Zero);
  try {
   NativeMethods.keybd_event(0x11,0,0,UIntPtr.Zero);NativeMethods.keybd_event(0x43,0,0,UIntPtr.Zero);NativeMethods.keybd_event(0x43,0,2,UIntPtr.Zero);NativeMethods.keybd_event(0x11,0,2,UIntPtr.Zero);
   for(int i=0;i<20;i++){await Task.Delay(40,token);if(NativeMethods.GetForegroundWindow()!=source)return null;var stamp=NativeMethods.GetClipboardSequenceNumber();if(!copy.Observe(stamp,true))continue;var text=Clipboard.ContainsText()?Clipboard.GetText().Trim():null;if(NativeMethods.GetClipboardSequenceNumber()!=stamp||NativeMethods.GetForegroundWindow()!=source)return null;return text;}
   return null;
  } finally { if(copy.ShouldRestore(NativeMethods.GetClipboardSequenceNumber())){if(data is null)Clipboard.Clear();else Clipboard.SetDataObject(snapshot,true);} }
 }
}
