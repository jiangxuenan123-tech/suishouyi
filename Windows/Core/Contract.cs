using System.Globalization;
using System.Text.Json;
namespace Suishouyi.Core;
public enum TaskMode { Translation, Explanation }
public record Explanation(string Status, string Kind, string Subject, string Body);
public record CodeBuddyResponse(string Text, string? ActualModelId);
public record AIResult(string Body,string OriginalText,string RequestedModelId,string? ActualModelId,TaskMode Mode,string? Kind=null,string? Status=null) {
 public string Source => ActualModelId is { } actual && actual!=RequestedModelId ? $"{actual}（请求：{RequestedModelId}）" : RequestedModelId;
}
public static class ExplanationPolicy {
 public static int VisibleCount(string text) => new StringInfo(text).LengthInTextElements;
 public static Explanation Decode(string text) {
  try {
   using var d=JsonDocument.Parse(text);var r=d.RootElement;
   string Get(string key) => r.GetProperty(key).GetString() ?? throw new InvalidDataException("解释字段为空");
   var e=new Explanation(Get("status"),Get("kind"),Get("subject").Trim(),Get("body").Trim());
   if(e.Status is not ("ok" or "uncertain" or "needs_selection") || e.Kind is not ("term" or "sentence" or "paragraph") || e.Body.Length==0 || e.Subject.Length==0) throw new InvalidDataException("解释格式无效，请重试。");
   return e;
  } catch(Exception ex) when(ex is JsonException or KeyNotFoundException or InvalidOperationException) { throw new InvalidDataException("解释格式无效，请重试。",ex); }
 }
}
public static class CodeBuddyEnvelope {
 public static CodeBuddyResponse Parse(string text,bool preservingUserQueryTags=false) {
  try {
   JsonElement final;
   try { using var d=JsonDocument.Parse(text); final=d.RootElement.ValueKind==JsonValueKind.Array ? d.RootElement.EnumerateArray().Last().Clone() : d.RootElement.Clone(); }
   catch(JsonException) { using var d=JsonDocument.Parse(text.Split('\n',StringSplitOptions.RemoveEmptyEntries|StringSplitOptions.TrimEntries).Last()); final=d.RootElement.Clone(); }
   if(final.ValueKind!=JsonValueKind.Object || !final.TryGetProperty("type",out var type) || type.GetString()!="result" || !final.TryGetProperty("subtype",out var subtype) || subtype.GetString()!="success" || !final.TryGetProperty("is_error",out var error) || error.ValueKind!=JsonValueKind.False || !final.TryGetProperty("result",out var result) || result.ValueKind!=JsonValueKind.String || string.IsNullOrWhiteSpace(result.GetString())) throw new InvalidDataException("AI 未返回最终成功结果，请重试。");
   string? model=final.TryGetProperty("model",out var m)&&m.ValueKind==JsonValueKind.String?m.GetString():null;
   if(model is null && final.TryGetProperty("providerData",out var provider) && provider.ValueKind==JsonValueKind.Object && provider.TryGetProperty("model",out var pm) && pm.ValueKind==JsonValueKind.String) model=pm.GetString();
   var body=result.GetString()!;
   if(!preservingUserQueryTags)body=body.Replace("<user_query>","").Replace("</user_query>","");
   if(string.IsNullOrWhiteSpace(body))throw new InvalidDataException("AI 未返回有效正文，请重试。");
   return new(body.Trim(),model);
  } catch(Exception ex) when(ex is JsonException or InvalidOperationException) { throw new InvalidDataException("AI 返回格式无效，请重试。",ex); }
 }
}
