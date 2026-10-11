using Tesseract;
namespace Suishouyi.App;
internal static class OcrService {
 public static async Task<string> RecognizeAsync(Bitmap image,CancellationToken token) {
  using var stream=new MemoryStream();image.Save(stream,System.Drawing.Imaging.ImageFormat.Png);var bytes=stream.ToArray();
  return await Task.Run(()=>{token.ThrowIfCancellationRequested();using var engine=new TesseractEngine(Path.Combine(AppContext.BaseDirectory,"Resources","tessdata"),"chi_sim+eng",EngineMode.LstmOnly);using var pix=Pix.LoadFromMemory(bytes);using var page=engine.Process(pix);var text=page.GetText().Trim();token.ThrowIfCancellationRequested();return text;},token);
 }
 public static void CheckResources(){using var engine=new TesseractEngine(Path.Combine(AppContext.BaseDirectory,"Resources","tessdata"),"chi_sim+eng",EngineMode.LstmOnly);}
}
