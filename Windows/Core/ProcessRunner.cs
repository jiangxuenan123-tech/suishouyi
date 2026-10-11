using System.Diagnostics;
namespace Suishouyi.Core;
public record ProcessOutput(int ExitCode,string StandardOutput,string StandardError);
public static class ProcessRunner {
 public static async Task<ProcessOutput> RunAsync(string executable,IEnumerable<string> args,string input,string workDirectory,CancellationToken token,TimeSpan? timeout=null) {
  token.ThrowIfCancellationRequested();Directory.CreateDirectory(workDirectory);
  var start=new ProcessStartInfo(executable) { UseShellExecute=false,CreateNoWindow=true,RedirectStandardInput=true,RedirectStandardOutput=true,RedirectStandardError=true,WorkingDirectory=workDirectory,StandardOutputEncoding=System.Text.Encoding.UTF8,StandardErrorEncoding=System.Text.Encoding.UTF8 };
  foreach(var arg in args) start.ArgumentList.Add(arg);
  start.Environment["DISABLE_AUTOUPDATER"]="1";
  using var process=Process.Start(start)??throw new IOException("无法启动 CodeBuddy。");
  using var job=OperatingSystem.IsWindows()?WindowsProcessJob.Create(process):null;
  var stdout=process.StandardOutput.ReadToEndAsync();var stderr=process.StandardError.ReadToEndAsync();
  using var limit=new CancellationTokenSource(timeout??TimeSpan.FromSeconds(45));using var linked=CancellationTokenSource.CreateLinkedTokenSource(token,limit.Token);
  try {
   await process.StandardInput.WriteAsync(input.AsMemory(),linked.Token);process.StandardInput.Close();
   await process.WaitForExitAsync(linked.Token);await Task.WhenAll(stdout,stderr).WaitAsync(linked.Token);
  } catch(OperationCanceledException) {
   job?.Dispose();if(!process.HasExited)process.Kill(entireProcessTree:true);
   await process.WaitForExitAsync();await Task.WhenAll(stdout,stderr);
   if(token.IsCancellationRequested)throw new OperationCanceledException(token);throw new TimeoutException("请求超过 45 秒，请检查网络后重试。");
  } catch { job?.Dispose();if(!process.HasExited)process.Kill(entireProcessTree:true);await process.WaitForExitAsync();await Task.WhenAll(stdout,stderr);throw; }
  return new(process.ExitCode,await stdout,await stderr);
 }
}
