using Suishouyi.Core;
namespace Suishouyi.App;
internal sealed class SettingsWindow:Form {
 ComboBox model=new();bool changing;
 public void UpdateModel(string id){changing=true;if(!model.Items.Contains(id))model.Items.Add(id);model.SelectedItem=id;changing=false;}
 public SettingsWindow(AppSettings settings,IReadOnlyList<string> catalog,Action<string> modelChanged,Action<string> themeChanged,Func<int,uint,int,uint,bool> hotkeysChanged,Action refresh,Action<bool> parallelChanged) {
  Text="随手译设置";AutoScaleMode=AutoScaleMode.Dpi;AutoScaleDimensions=new(96,96);Size=new(760,640);MinimumSize=new(620,540);MaximizeBox=false;StartPosition=FormStartPosition.CenterScreen;Font=new("Microsoft YaHei UI",11);
  var scroll=new Panel{Dock=DockStyle.Fill,AutoScroll=true};Controls.Add(scroll);
  var list=new TableLayoutPanel{Dock=DockStyle.Top,AutoSize=true,ColumnCount=1,Padding=new(26)};list.ColumnStyles.Add(new(SizeType.Percent,100));scroll.Controls.Add(list);
  Label TextLabel(string text,float size=11)=>new(){Text=text,AutoSize=true,Dock=DockStyle.Top,Font=new(Font.FontFamily,size),Margin=new(0,0,0,10)};
  list.Controls.Add(TextLabel("设置",22));list.Controls.Add(TextLabel("按你的习惯选择外观、模型和快捷键。"));
  var sections=new List<TableLayoutPanel>();
  TableLayoutPanel Section(string title,TableLayoutPanel? container=null){var card=new TableLayoutPanel{Dock=DockStyle.Top,AutoSize=true,ColumnCount=1,Padding=new(16),Margin=new(0,10,0,6)};card.ColumnStyles.Add(new(SizeType.Percent,100));card.Controls.Add(TextLabel(title,13));(container??list).Controls.Add(card);sections.Add(card);return card;}
  var appearance=Section("外观");
  var previews=new TableLayoutPanel{Dock=DockStyle.Top,Height=104,ColumnCount=2,RowCount=1,Margin=new(0,2,0,0)};previews.ColumnStyles.Add(new(SizeType.Percent,50));previews.ColumnStyles.Add(new(SizeType.Percent,50));previews.RowStyles.Add(new(SizeType.Percent,100));appearance.Controls.Add(previews);
  string selectedTheme=settings.ThemeId;
  foreach(var id in new[]{"refinedLight","techDark"}){
   var themeId=id;var preview=new Button{Dock=DockStyle.Fill,FlatStyle=FlatStyle.Flat,Cursor=Cursors.Hand,Margin=id=="refinedLight"?new(0,0,8,0):new(8,0,0,0),AccessibleName=id=="techDark"?"深色科技":"简洁精致",AccessibleDescription="选择后立即生效并自动保存"};preview.FlatAppearance.BorderSize=0;previews.Controls.Add(preview);
   preview.Paint+=(_,e)=>{
    var colors=Theme.Get(themeId);var scale=preview.DeviceDpi/96f;int inset=(int)(16*scale),width=preview.ClientSize.Width,height=preview.ClientSize.Height;
    e.Graphics.Clear(colors.Background);using var cardBrush=new SolidBrush(colors.Card);using var accentBrush=new SolidBrush(colors.Accent);using var mutedBrush=new SolidBrush(colors.Muted);
    e.Graphics.FillRectangle(cardBrush,inset,inset,width-2*inset,(int)(38*scale));e.Graphics.FillRectangle(accentBrush,inset+(int)(10*scale),inset+(int)(10*scale),(int)(46*scale),(int)(6*scale));e.Graphics.FillRectangle(mutedBrush,inset+(int)(10*scale),inset+(int)(23*scale),width-2*inset-(int)(40*scale),(int)(4*scale));
    using var labelFont=new Font(Font.FontFamily,11);var title=(themeId=="techDark"?"深色科技":"简洁精致")+(selectedTheme==themeId?"  ✓ 已选":"");TextRenderer.DrawText(e.Graphics,title,labelFont,new Rectangle(inset,(int)(66*scale),width-2*inset,height-(int)(66*scale)),colors.Foreground,TextFormatFlags.Left|TextFormatFlags.VerticalCenter|TextFormatFlags.EndEllipsis);
    if(selectedTheme==themeId){using var pen=new Pen(colors.Accent,2*scale);e.Graphics.DrawRectangle(pen,scale,scale,width-2*scale-1,height-2*scale-1);}
   };
   preview.Click+=(_,_)=>{selectedTheme=themeId;themeChanged(themeId);ApplyColors();};
  }
  var columns=new TableLayoutPanel{Dock=DockStyle.Top,AutoSize=true,ColumnCount=2};columns.ColumnStyles.Add(new(SizeType.Percent,50));columns.ColumnStyles.Add(new(SizeType.Percent,50));list.Controls.Add(columns);
  var ai=Section("AI 模型与生成",columns);ai.Margin=new(0,10,8,6);ai.Controls.Add(TextLabel("AI 模型（实际可用性以当前账号为准）"));
  model=new ComboBox{Dock=DockStyle.Top,DropDownStyle=ComboBoxStyle.DropDownList,Margin=new(0,0,0,10)};model.Items.AddRange(catalog.Append(settings.SelectedModelId).Distinct().Cast<object>().ToArray());model.SelectedItem=settings.SelectedModelId;model.SelectedIndexChanged+=(_,_)=>{if(!changing&&model.SelectedItem is string id)modelChanged(id);};ai.Controls.Add(model);
  if(!catalog.Contains(settings.SelectedModelId))ai.Controls.Add(TextLabel("保存的模型未出现在目录中，请刷新或重新确认。"));
  var modelButtons=new FlowLayoutPanel{Dock=DockStyle.Top,AutoSize=true,Margin=new(0,0,0,12)};
  Button ActionButton(string title)=>new(){Text=title,AutoSize=true,Padding=new(12,5,12,5),Margin=new(0,0,12,0),Cursor=Cursors.Hand};
  var reload=ActionButton("刷新模型列表");reload.Click+=(_,_)=>refresh();var reset=ActionButton("恢复 hy3");reset.Click+=(_,_)=>{if(!model.Items.Contains("hy3"))model.Items.Add("hy3");model.SelectedItem="hy3";};modelButtons.Controls.AddRange(new Control[]{reload,reset});ai.Controls.Add(modelButtons);
  var parallel=new CheckBox{Text="同时生成翻译和解释",AutoSize=true,Dock=DockStyle.Top,Checked=settings.ParallelGeneration,Margin=new(0,0,0,6)};parallel.CheckedChanged+=(_,_)=>parallelChanged(parallel.Checked);ai.Controls.Add(parallel);ai.Controls.Add(TextLabel("切换时可直接查看结果；开启后会增加模型用量。",10));
  var shortcuts=Section("快捷键",columns);shortcuts.Margin=new(8,10,0,6);shortcuts.Controls.Add(TextLabel("选中文字后使用；没有选中文字时进入截图。",10));
  var rows=new List<(ComboBox key,CheckBox ctrl,CheckBox shift,CheckBox alt)>();
  void Row(string title,int key,uint modifiers){
   var row=new TableLayoutPanel{Dock=DockStyle.Top,AutoSize=true,ColumnCount=2,Margin=new(0,0,0,12)};row.ColumnStyles.Add(new(SizeType.Absolute,54));row.ColumnStyles.Add(new(SizeType.Percent,100));
   row.Controls.Add(new Label{Text=title,AutoSize=true,Anchor=AnchorStyles.Left,Margin=new(0,0,12,0)});
   var keys=new ComboBox{Dock=DockStyle.Top,DropDownStyle=ComboBoxStyle.DropDownList,Margin=new(0)};keys.Items.AddRange(Enumerable.Range(65,26).Concat(Enumerable.Range(112,12)).Select(v=>((Keys)v).ToString()).Cast<object>().ToArray());keys.SelectedItem=((Keys)key).ToString();
   CheckBox Modifier(string name,uint flag)=>new(){Text=name,AutoSize=true,Anchor=AnchorStyles.Left,Checked=(modifiers&flag)!=0,Margin=new(0,0,16,0)};
   var ctrl=Modifier("Ctrl",2);var shift=Modifier("Shift",4);var alt=Modifier("Alt",1);row.Controls.Add(keys);var modifiersRow=new FlowLayoutPanel{Dock=DockStyle.Top,AutoSize=true,Margin=new(0,10,0,0)};modifiersRow.Controls.AddRange(new Control[]{ctrl,shift,alt});row.Controls.Add(modifiersRow,0,1);row.SetColumnSpan(modifiersRow,2);shortcuts.Controls.Add(row);rows.Add((keys,ctrl,shift,alt));
  }
  Row("翻译",settings.TranslationKey,settings.TranslationModifiers);Row("解释",settings.ExplanationKey,settings.ExplanationModifiers);
  var save=ActionButton("应用快捷键");save.Click+=(_,_)=>{uint Mods(int i)=>(uint)((rows[i].ctrl.Checked?2:0)|(rows[i].shift.Checked?4:0)|(rows[i].alt.Checked?1:0));if(Mods(0)==0||Mods(1)==0){MessageBox.Show("请选择 Ctrl、Shift 或 Alt 修饰键。");return;}var a=(int)Enum.Parse<Keys>((string)rows[0].key.SelectedItem!);var b=(int)Enum.Parse<Keys>((string)rows[1].key.SelectedItem!);if(hotkeysChanged(a,Mods(0),b,Mods(1)))MessageBox.Show("快捷键已保存。");else MessageBox.Show("快捷键已被占用，请换一组；托盘菜单仍可使用。");};
  var defaults=ActionButton("恢复默认快捷键");defaults.Click+=(_,_)=>{rows[0].key.SelectedItem="F8";rows[1].key.SelectedItem="F9";foreach(var row in rows){row.ctrl.Checked=row.shift.Checked=true;row.alt.Checked=false;}save.PerformClick();};
  var actions=new FlowLayoutPanel{Dock=DockStyle.Top,AutoSize=true,Margin=new(0)};actions.Controls.AddRange(new Control[]{save,defaults});shortcuts.Controls.Add(actions);
  list.Controls.Add(TextLabel("外观和模型选择自动保存；快捷键修改后请点击“应用快捷键”。",10));
  void ApplyColors(){var colors=Theme.Get(selectedTheme);colors.Apply(this);scroll.BackColor=list.BackColor=colors.Background;foreach(Control child in list.Controls)if(child is Label label){label.BackColor=colors.Background;label.ForeColor=label.Font.Size>16?colors.Foreground:colors.Muted;}foreach(var section in sections)foreach(Control child in section.Controls)if(child is Label label&&label.Font.Size<=11)label.ForeColor=colors.Muted;foreach(Control preview in previews.Controls)preview.Invalidate();}
  ApplyColors();
 }
}
