namespace Suishouyi.Core;
public sealed class ClipboardCopyState(uint initialStamp) {
 uint? copiedStamp;
 public bool Observe(uint stamp,bool sourceIsForeground){if(!sourceIsForeground||stamp==initialStamp)return false;copiedStamp=stamp;return true;}
 public bool ShouldRestore(uint currentStamp)=>copiedStamp.HasValue&&copiedStamp.Value==currentStamp;
}
