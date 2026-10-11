using Suishouyi.Core;
namespace Suishouyi.App;
internal sealed class SetupWindow:Form {
 readonly Label status=new(){Dock=DockStyle.Fill,TextAlign=ContentAlignment.MiddleLeft};readonly Button login=new(){Text="本人官方登录",AutoSize=true},check=new(){Text="验证连接并完成",AutoSize=true},retry=new(){Text="重试准备",AutoSize=true};readonly CancellationTokenSource cancellation=new();string? cli;readonly string work;
 public event Action<string>? Ready;
 public SetupWindow(string data,string model,string theme) {
  work=Path.Combine(data,"CLI-work");Text="随手译 · 首次使用";Size=new(510,300);StartPosition=FormStartPosition.CenterScreen;Font=new("Microsoft YaHei UI",10);Padding=new(22);
  var layout=new TableLayoutPanel{Dock=DockStyle.Fill,ColumnCount=1,RowCount=3};layout.RowStyles.Add(new(SizeType.Percent,100));layout.RowStyles.Add(new(SizeType.Absolute,45));layout.RowStyles.Add(new(SizeType.Absolute,70));Controls.Add(layout);layout.Controls.Add(status,0,0);
  var buttons=new FlowLayoutPanel{Dock=DockStyle.Fill};buttons.Controls.AddRange(new Control[]{login,check,retry});layout.Controls.Add(buttons,0,1);layout.Controls.Add(new Label{Dock=DockStyle.Fill,Text="登录请使用本人账号，在官方窗口中选择登录方式并确认浏览器授权。连接验证会向所选模型发送一次“你好”。实际可用性以当前账号为准。"},0,2);
  login.Enabled=check.Enabled=false;
  async Task Prepare(){retry.Enabled=false;login.Enabled=check.Enabled=false;status.Text="正在检查本机依赖…";try { cli=await DependencyInstaller.EnsureAsync(data,message=>status.Text=message,cancellation.Token);await DependencyInstaller.EnsureOcrAsync(message=>status.Text=message,cancellation.Token);status.Text="程序与中英文 OCR 已准备好。已有登录可直接验证；首次使用请点“本人官方登录”。";login.Enabled=check.Enabled=true;}catch(OperationCanceledException){}catch(Exception ex){status.Text=ex.Message;}finally{retry.Enabled=true;}}
  Shown+=async(_,_)=>await Prepare();retry.Click+=async(_,_)=>await Prepare();
  login.Click+=(_,_)=>{if(cli is null)return;System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(cli){UseShellExecute=true,WorkingDirectory=work});status.Text="请在 CodeBuddy 官方窗口完成登录，再回来验证连接。若官方窗口已登录，可直接验证。";};
  check.Click+=async(_,_)=>{if(cli is null)return;check.Enabled=login.Enabled=false;status.Text="正在验证本人账号与模型…";try{await new CodeBuddyClient(cli,work).RequestAsync("你好","仅回复：连接成功。",model,cancellation.Token);Ready?.Invoke(cli);Close();}catch(OperationCanceledException){}catch(Exception ex){status.Text=ex.Message;check.Enabled=login.Enabled=true;}};
  FormClosed+=(_,_)=>cancellation.Cancel();Theme.Get(theme).Apply(this);
 }
}
