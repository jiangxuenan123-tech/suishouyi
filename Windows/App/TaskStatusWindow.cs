namespace Suishouyi.App;
internal sealed class TaskStatusWindow:Form {
 readonly Label status=new(){Dock=DockStyle.Fill,TextAlign=ContentAlignment.MiddleLeft};bool finished;
 public event Action? CancelRequested;
 public TaskStatusWindow(string theme){Text="随手译";Size=new(360,155);ShowInTaskbar=false;TopMost=true;StartPosition=FormStartPosition.CenterScreen;Font=new("Microsoft YaHei UI",10);Padding=new(18);var cancel=new Button{Text="取消",Dock=DockStyle.Bottom,Height=32};cancel.Click+=(_,_)=>CancelRequested?.Invoke();Controls.Add(status);Controls.Add(cancel);FormClosing+=(_,_)=>{if(!finished)CancelRequested?.Invoke();};Theme.Get(theme).Apply(this);}
 public void SetStatus(string message)=>status.Text=message;
 public void Finish(){finished=true;Close();}
 protected override bool ShowWithoutActivation=>true;
}
