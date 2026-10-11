namespace Suishouyi.App;
internal sealed record Theme(Color Background,Color Card,Color Foreground,Color Muted,Color Accent) {
 public static Theme Get(string id)=>id=="techDark" ? new(Color.FromArgb(24,26,35),Color.FromArgb(34,37,49),Color.FromArgb(235,238,247),Color.FromArgb(170,178,198),Color.FromArgb(139,132,255)) : new(Color.FromArgb(241,244,251),Color.White,Color.FromArgb(35,40,58),Color.FromArgb(101,111,133),Color.FromArgb(95,83,226));
 public void Apply(Control control){control.BackColor=control is Form?Background:Card;control.ForeColor=Foreground;foreach(Control child in control.Controls)Apply(child);if(control is Button b){b.FlatStyle=FlatStyle.Flat;b.FlatAppearance.BorderColor=Accent;b.BackColor=Card;b.ForeColor=Accent;}}
}
