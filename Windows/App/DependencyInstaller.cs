using Suishouyi.Core;
using System.Security.Cryptography;
using System.IO.Compression;
namespace Suishouyi.App;
internal static class DependencyInstaller {
 const string Version="2.164.0";
 const string ArchiveHash="bdd13127c60eb5f02cdaabd10cc5a0b44b2f3f8c2b790036895fe61d3d31bd93";
 const string Repository="https://acc-1258344699.cos.accelerate.myqcloud.com/@tencent-ai/codebuddy-code/releases";
 public static async Task<bool> CompatibleAsync(string path,string work,CancellationToken token) {
  if(!File.Exists(path))return false;
  try { var version=await ProcessRunner.RunAsync(path,new[]{"--version"},"",work,token,TimeSpan.FromSeconds(10));if(version.ExitCode!=0||!System.Text.RegularExpressions.Regex.IsMatch(version.StandardOutput,@"\d+\.\d+\.\d+"))return false;var help=await ProcessRunner.RunAsync(path,new[]{"--help"},"",work,token,TimeSpan.FromSeconds(10));return help.ExitCode==0&&new[]{"--print","--output-format","--tools","--strict-mcp-config","--no-session-persistence","--model"}.All(help.StandardOutput.Contains); } catch(Exception ex) when(ex is not OperationCanceledException) { return false; }
 }
 public static IEnumerable<string> Candidates(string owned){yield return owned;yield return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"codebuddy","bin","codebuddy.exe");yield return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),".local","bin","codebuddy.exe");foreach(var directory in (Environment.GetEnvironmentVariable("PATH")??"").Split(Path.PathSeparator))yield return Path.Combine(directory,"codebuddy.exe");}
 public static async Task<string> EnsureAsync(string dataDirectory,Action<string> status,CancellationToken token) {
  var work=Path.Combine(dataDirectory,"CLI-work");Directory.CreateDirectory(work);
  var destination=Path.Combine(dataDirectory,"Dependencies","CodeBuddy",Version);var owned=Path.Combine(destination,"codebuddy.exe");
  foreach(var path in Candidates(owned).Distinct())if(await CompatibleAsync(path,work,token))return path;
  status("正在从 CodeBuddy 官方下载原生程序…");
  var staging=destination+".staging-"+Guid.NewGuid();Directory.CreateDirectory(staging);
  try {
   using var client=new HttpClient{Timeout=TimeSpan.FromMinutes(5)};var bytes=await client.GetByteArrayAsync($"{Repository}/download/{Version}/codebuddy-code_Windows_x86_64.zip",token);
   if(Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant()!=ArchiveHash)throw new InvalidDataException("CodeBuddy 下载校验失败，请重试。");
   using(var memory=new MemoryStream(bytes))using(var zip=new ZipArchive(memory)){foreach(var entry in zip.Entries){var path=Path.GetFullPath(Path.Combine(staging,entry.FullName));if(!path.StartsWith(Path.GetFullPath(staging)+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase))throw new InvalidDataException("CodeBuddy 安装文件路径无效。");if(entry.FullName.EndsWith('/')){Directory.CreateDirectory(path);continue;}Directory.CreateDirectory(Path.GetDirectoryName(path)!);entry.ExtractToFile(path);}}
   var executable=Path.Combine(staging,"codebuddy.exe");if(!await CompatibleAsync(executable,work,token))throw new InvalidDataException("下载的 CodeBuddy 无法运行，请重试。");
   token.ThrowIfCancellationRequested();Directory.CreateDirectory(Path.GetDirectoryName(destination)!);if(Directory.Exists(destination))Directory.Delete(destination,true);Directory.Move(staging,destination);return owned;
  } finally {if(Directory.Exists(staging))Directory.Delete(staging,true);}
 }
 public static async Task EnsureOcrAsync(Action<string> status,CancellationToken token) {
  try { OcrService.CheckResources();return; } catch(Exception) {}
  status("正在准备 OCR 运行库，请确认 Windows 安装提示…");
  var redist=Path.Combine(AppContext.BaseDirectory,"Resources","vc_redist.x64.exe");
  if(Convert.ToHexString(SHA256.HashData(await File.ReadAllBytesAsync(redist,token))).ToLowerInvariant()!="cc0ff0eb1dc3f5188ae6300faef32bf5beeba4bdd6e8e445a9184072096b713b")throw new InvalidDataException("OCR 运行库文件校验失败，请重新下载安装包。");
  using var process=System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(redist){UseShellExecute=true,Arguments="/install /passive /norestart"})??throw new IOException("无法启动 OCR 运行库安装。");
  await process.WaitForExitAsync(token);if(process.ExitCode is not (0 or 1638 or 3010))throw new IOException("OCR 运行库安装未完成，请重试。");try{OcrService.CheckResources();}catch(Exception ex){throw new InvalidDataException("中英文 OCR 无法初始化，请重新安装随手译后重试。",ex);}
 }
}
