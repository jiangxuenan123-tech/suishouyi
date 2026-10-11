namespace Suishouyi.App;
internal static class Program {
 [STAThread] static void Main(string[] args) {
  Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);
  if(!OperatingSystem.IsWindowsVersionAtLeast(10,0,19041)){MessageBox.Show("随手译需要 Windows 10 2004 或更新系统。");return;}
  using var mutex=new Mutex(true,"Local\\Suishouyi.CurrentUser."+Environment.UserName,out var first);
  if(!first){MessageBox.Show("随手译已在托盘运行。");return;}
  Application.Run(new TrayApplication());
 }
}
