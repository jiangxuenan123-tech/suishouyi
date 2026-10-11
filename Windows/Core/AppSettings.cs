namespace Suishouyi.Core;
public sealed class AppSettings {
 public string SelectedModelId {get;set;}="hy3";
 public bool SetupCompleted {get;set;}
 public string ThemeId {get;set;}="refinedLight";
 public int TranslationKey {get;set;}=119;
 public int ExplanationKey {get;set;}=120;
 public uint TranslationModifiers {get;set;}=6;
 public uint ExplanationModifiers {get;set;}=6;
 public static AppSettings Load(string path) {
  if(!File.Exists(path))return new();
  try{return System.Text.Json.JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(path))??new();}
  catch(System.Text.Json.JsonException){File.Move(path,path+".invalid-"+Guid.NewGuid());return new();}
 }
 public void Save(string path) { Directory.CreateDirectory(Path.GetDirectoryName(path)!);File.WriteAllText(path+".tmp",System.Text.Json.JsonSerializer.Serialize(this));File.Move(path+".tmp",path,true); }
}
