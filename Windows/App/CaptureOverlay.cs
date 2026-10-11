namespace Suishouyi.App;
internal sealed class CaptureOverlay:Form {
 readonly Rectangle desktop=SystemInformation.VirtualScreen;readonly Bitmap image;Point start;Rectangle selection;bool dragging;
 public Bitmap? CapturedImage {get;private set;}
 public CaptureOverlay(){FormBorderStyle=FormBorderStyle.None;StartPosition=FormStartPosition.Manual;Bounds=desktop;TopMost=true;ShowInTaskbar=false;KeyPreview=true;Cursor=Cursors.Cross;DoubleBuffered=true;AutoScaleMode=AutoScaleMode.None;
  image=new Bitmap(desktop.Width,desktop.Height);using(var g=Graphics.FromImage(image))g.CopyFromScreen(desktop.Location,Point.Empty,desktop.Size);
  KeyDown+=(_,e)=>{if(e.KeyCode==Keys.Escape){DialogResult=DialogResult.Cancel;Close();}};
  MouseDown+=(_,e)=>{if(e.Button==MouseButtons.Left){start=e.Location;dragging=true;}};
  MouseMove+=(_,e)=>{if(dragging){selection=Rectangle.FromLTRB(Math.Min(start.X,e.X),Math.Min(start.Y,e.Y),Math.Max(start.X,e.X),Math.Max(start.Y,e.Y));Invalidate();}};
  MouseUp+=(_,e)=>{if(!dragging)return;dragging=false;selection.Intersect(new Rectangle(Point.Empty,image.Size));if(selection.Width>2&&selection.Height>2)CapturedImage=image.Clone(selection,image.PixelFormat);DialogResult=CapturedImage is null?DialogResult.Cancel:DialogResult.OK;Close();};
 }
 protected override void OnDpiChanged(DpiChangedEventArgs e){e.Cancel=true;base.OnDpiChanged(e);}
 protected override void OnPaint(PaintEventArgs e){e.Graphics.DrawImageUnscaled(image,Point.Empty);using var dim=new SolidBrush(Color.FromArgb(90,20,20,30));e.Graphics.FillRectangle(dim,ClientRectangle);if(selection.Width>0){e.Graphics.DrawImage(image,selection,selection,GraphicsUnit.Pixel);using var pen=new Pen(Color.FromArgb(110,100,255),2);e.Graphics.DrawRectangle(pen,selection);}e.Graphics.DrawString("拖动框选文字 · Esc 取消",Font,Brushes.White,20,20);}
 protected override void Dispose(bool disposing){if(disposing)image.Dispose();base.Dispose(disposing);}
}
