using System.Text.RegularExpressions;
using System.Text.Json;
namespace Suishouyi.Core;
public static class ModelCatalog {
 public static IReadOnlyList<string> Parse(string help) {
  var match=Regex.Match(help,@"--model[\s\S]*?(?:choices|available|supported)(?: models)?\s*:\s*([^)\r\n]+)",RegexOptions.IgnoreCase);
  if(!match.Success) throw new InvalidDataException("模型列表格式变化，请刷新重试。");
  var models=match.Groups[1].Value.Split(',',StringSplitOptions.TrimEntries|StringSplitOptions.RemoveEmptyEntries).Select(s=>s.Trim('\"','\'', '[',']','(',')')).Where(s=>Regex.IsMatch(s,@"^[A-Za-z0-9][A-Za-z0-9._/-]*$")).Distinct().ToArray();
  if(models.Length==0)throw new InvalidDataException("未找到支持模型。");return models;
 }
 public static async Task<IReadOnlyList<string>> LoadAsync(string cli,string cachePath,string workDirectory,bool refresh,CancellationToken token) {
  if(!refresh&&File.Exists(cachePath)) {
   try{var cached=JsonSerializer.Deserialize<string[]>(File.ReadAllText(cachePath));if(cached is {Length:>0}&&cached.All(id=>id is not null&&Regex.IsMatch(id,@"^[A-Za-z0-9][A-Za-z0-9._/-]*$")))return cached;}
   catch(JsonException){}
  }
  var output=await ProcessRunner.RunAsync(cli,new[]{"--help"},"",workDirectory,token,TimeSpan.FromSeconds(10));
  if(output.ExitCode!=0)throw new InvalidDataException("模型列表读取失败，可重试。");
  var models=Parse(output.StandardOutput);File.WriteAllText(cachePath,JsonSerializer.Serialize(models));return models;
 }
}
