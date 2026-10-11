namespace Suishouyi.Installer;
internal static class Program {
 [STAThread]static void Main(string[] args){Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);if(!OperatingSystem.IsWindowsVersionAtLeast(10,0,19041)||!Environment.Is64BitOperatingSystem){MessageBox.Show("需要 Windows 10 2004 或更新系统（x64）。");return;}Application.Run(new InstallerForm(args.Contains("--uninstall")));}
}
