using System.IO.Compression;
namespace Suishouyi.Core;
public static class PayloadInstaller {
 public static void Install(Stream archive,string destination,Action? complete=null) {
  var staging=destination+".staging-"+Guid.NewGuid();var backup=destination+".previous";bool moved=false;
  Directory.CreateDirectory(Path.GetDirectoryName(destination)!);Directory.CreateDirectory(staging);
  try {
   using(var zip=new ZipArchive(archive,ZipArchiveMode.Read,true)) {
    var root=Path.GetFullPath(staging)+Path.DirectorySeparatorChar;
    foreach(var entry in zip.Entries) {
     var path=Path.GetFullPath(Path.Combine(staging,entry.FullName.Replace('\\',Path.DirectorySeparatorChar)));
     if(!path.StartsWith(root,StringComparison.OrdinalIgnoreCase))throw new InvalidDataException("安装文件路径无效。");
     if(entry.FullName.EndsWith('/')){Directory.CreateDirectory(path);continue;}Directory.CreateDirectory(Path.GetDirectoryName(path)!);entry.ExtractToFile(path);
    }
   }
   if(!File.Exists(Path.Combine(staging,"Suishouyi.exe")))throw new InvalidDataException("安装包缺少程序。");
   if(Directory.Exists(backup))Directory.Delete(backup,true);
   if(Directory.Exists(destination)){Directory.Move(destination,backup);moved=true;}
   try { Directory.Move(staging,destination);complete?.Invoke(); } catch { if(Directory.Exists(destination))Directory.Delete(destination,true);if(moved)Directory.Move(backup,destination);throw; }
  } finally { if(Directory.Exists(staging))Directory.Delete(staging,true); }
 }
}
