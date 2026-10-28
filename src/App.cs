using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Markup;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Shell;
using System.Windows.Threading;
using Microsoft.Win32;

[assembly: AssemblyTitle("RAINY PC Health")]
[assembly: AssemblyDescription("Free portable Windows diagnostics • RAINY Support")]
[assembly: AssemblyCompany("RAINY Support")]
[assembly: AssemblyProduct("RAINY PC Health")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

namespace RainyHealth {
    public sealed class ScanResult { public bool Complete; public string Message; }
    public sealed class Scanner {
        private readonly object gate=new object();
        private Process process;
        private bool cancelled;
        public void Cancel() { lock(gate) { cancelled=true; if(process!=null) { try { if(!process.HasExited) process.Kill(); } catch(InvalidOperationException) {} catch(System.ComponentModel.Win32Exception) {} } } }
        public ScanResult Run(Action<Dictionary<string,object>> receive) {
            bool complete=false, malformed=false;
            try {
                string bootstrap="[Console]::InputEncoding=New-Object Text.UTF8Encoding($false);[Console]::OutputEncoding=New-Object Text.UTF8Encoding($false);$s=[Console]::In.ReadToEnd(); & ([ScriptBlock]::Create($s))";
                var psi=new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),@"WindowsPowerShell\v1.0\powershell.exe"),"-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand "+Convert.ToBase64String(Encoding.Unicode.GetBytes(bootstrap))) {
                    UseShellExecute=false, CreateNoWindow=true, RedirectStandardInput=true, RedirectStandardOutput=true, RedirectStandardError=true,
                    StandardOutputEncoding=new UTF8Encoding(false), StandardErrorEncoding=new UTF8Encoding(false)
                };
                using(var p=new Process {StartInfo=psi}) {
                    p.OutputDataReceived+=(s,e)=> {
                        if(String.IsNullOrWhiteSpace(e.Data)) return;
                        try {
                            var d=new JavaScriptSerializer {MaxJsonLength=4*1024*1024}.Deserialize<Dictionary<string,object>>(e.Data);
                            if(d==null || !d.ContainsKey("kind")) { malformed=true; return; }
                            if(Finding.Get(d,"kind")=="complete") complete=true;
                            receive(d);
                        } catch { malformed=true; }
                    };
                    // Drain stderr to prevent pipe deadlocks; raw diagnostics may contain private paths.
                    p.ErrorDataReceived+=(s,e)=> {};
                    lock(gate) { if(cancelled) return new ScanResult {Message="Шалгалтыг зогсоолоо."}; p.Start();process=p; }
                    p.BeginOutputReadLine();p.BeginErrorReadLine();
                    var bytes=new UTF8Encoding(false).GetBytes(Program.ResourceText("Diagnostics.ps1"));
                    p.StandardInput.BaseStream.Write(bytes,0,bytes.Length);p.StandardInput.BaseStream.Flush();p.StandardInput.Close();
                    bool exited=p.WaitForExit(240000);
                    if(!exited) { try { p.Kill(); } catch {} p.WaitForExit(); }
                    else p.WaitForExit(); // Drain asynchronous output handlers before consuming completion.
                    lock(gate) { process=null; }
                    if(cancelled) return new ScanResult {Message="Шалгалтыг зогсоолоо. Хэсэгчилсэн тайланг хадгалж болно."};
                    if(!exited) return new ScanResult {Message="4 минутын хугацаа дууслаа. Хэсэгчилсэн үр дүнг харуулж байна."};
                    if(!complete || malformed || p.ExitCode!=0) return new ScanResult {Message="Шалгалт бүрэн дуусаагүй. Windows PowerShell эсвэл байгууллагын бодлого хязгаарласан байж болно."};
                    return new ScanResult {Complete=true,Message="Шалгалт дууслаа"};
                }
            } catch { return new ScanResult {Message=cancelled ? "Шалгалтыг зогсоолоо." : "Оношилгоог эхлүүлж чадсангүй. Windows PowerShell 5.1 болон байгууллагын бодлогоо шалгана уу."}; }
            finally { lock(gate) { process=null; } }
        }
    }
    public static class Program {
        public static Stream Resource(string name) { return Assembly.GetExecutingAssembly().GetManifestResourceStream(name); }
        public static string ResourceText(string name) { using(var r=new StreamReader(Resource(name),Encoding.UTF8,true)) return r.ReadToEnd(); }
        [STAThread]
        public static int Main(string[] args) {
            try {
                if(args.Contains("--self-test")) { Tests.Run(); return 0; }
                if(args.Contains("--diagnostics-test")) {
                    var findings=new List<Finding>();var scanner=new Scanner();
                    var result=scanner.Run(d=> { if(Finding.Get(d,"kind")=="finding") findings.Add(Finding.From(d)); });
                    File.WriteAllText("diagnostics-test.json",new JavaScriptSerializer().Serialize(new {complete=result.Complete,count=findings.Count,categories=findings.Select(x=>x.Category).Distinct().ToArray(),unknown=findings.Count(x=>x.State=="unknown")}),Encoding.UTF8);
                    if(!result.Complete || findings.Count<10 || findings.All(x=>x.State=="unknown") || findings.Select(x=>x.Category).Distinct().Count()!=6) return 2;
                    return 0;
                }
                var app=new Application();
                var controller=new MainController(args.Contains("--smoke-test"));
                app.Run(controller.Window);
                return Environment.ExitCode;
            } catch(Exception ex) {
                if(args.Length>0) { File.WriteAllText("test-error.txt",ex.ToString());return 1; }
                MessageBox.Show("RAINY PC Health нээгдэж чадсангүй. Windows 10/11 болон .NET Framework 4.8 шаардлагатай.\n\n"+ex.Message,"RAINY",MessageBoxButton.OK,MessageBoxImage.Error);
                return 1;
            }
        }
    }
    public sealed class MainController {
        public Window Window {get;private set;}
        private readonly List<Finding> findings=new List<Finding>();
        private Scanner scanner;
        private bool scanning,complete,closing;
        private string category="all";
        private readonly string[] navigation={"NavAll","NavHardware","NavDrivers","NavLicense","NavSecurity","NavSystem","NavApps"};
        private readonly bool demo;
        private T UI<T>(string name) where T:FrameworkElement { return (T)Window.FindName(name); }
        public MainController(bool demoMode) {
            demo=demoMode;
            using(var stream=Program.Resource("MainWindow.xaml")) Window=(Window)XamlReader.Load(stream);
            WindowChrome.SetWindowChrome(Window,new WindowChrome { CaptionHeight=0,ResizeBorderThickness=new Thickness(6),GlassFrameThickness=new Thickness(0),CornerRadius=new CornerRadius(0),UseAeroCaptionButtons=false });
            using(var s=Program.Resource("rainy.ico")) {
                var decoder=new IconBitmapDecoder(s,BitmapCreateOptions.PreservePixelFormat,BitmapCacheOption.OnLoad);
                Window.Icon=decoder.Frames[decoder.Frames.Count-1];UI<Image>("BrandIcon").Source=Window.Icon;
            }
            UI<Button>("MinimizeButton").Click+=(s,e)=>Window.WindowState=WindowState.Minimized;
            UI<Button>("MaximizeButton").Click+=(s,e)=>ToggleMaximize();
            UI<Button>("CloseButton").Click+=(s,e)=>Window.Close();
            UI<Border>("TitleBar").MouseLeftButtonDown+=(s,e)=> { if(e.ClickCount==2) ToggleMaximize(); else { try { Window.DragMove(); } catch(InvalidOperationException) {} } };
            Window.Closing+=(s,e)=> { closing=true;if(scanner!=null) scanner.Cancel(); };
            UI<Button>("ScanButton").Click+=async(s,e)=>await StartScan();
            UI<Button>("CancelButton").Click+=(s,e)=> { if(scanner!=null) scanner.Cancel();UI<Button>("CancelButton").IsEnabled=false; };
            UI<Button>("TelegramSide").Click+=(s,e)=>Open("https://t.me/boroobro");
            UI<Button>("FacebookSide").Click+=(s,e)=>Open("https://www.facebook.com/rainysupport/");
            UI<Button>("SecurityButton").Click+=(s,e)=>Open("windowsdefender://threat");
            UI<Button>("UpdateButton").Click+=(s,e)=>Open("ms-settings:windowsupdate");
            UI<Button>("ExportButton").Click+=(s,e)=>Export();
            UI<Button>("CopyButton").Click+=(s,e)=> { try { Clipboard.SetText(Report.Plain(findings,complete));UI<TextBlock>("ScanStatus").Text="Дүгнэлтийг хууллаа"; } catch { MessageBox.Show(Window,"Clipboard завгүй байна. Дахин оролдоно уу.","RAINY"); } };
            foreach(var name in navigation) { var b=UI<Button>(name);b.Click+=(s,e)=> { category=(string)((Button)s).Tag;Refresh();UI<ScrollViewer>("ResultsScroll").ScrollToTop(); }; }
            UI<TextBox>("SearchBox").TextChanged+=(s,e)=>Refresh();
            UI<CheckBox>("IssuesOnly").Checked+=(s,e)=>Refresh();UI<CheckBox>("IssuesOnly").Unchecked+=(s,e)=>Refresh();
            Window.PreviewKeyDown+=(s,e)=> { if(e.Key==Key.Escape&&scanning&&scanner!=null) { scanner.Cancel();e.Handled=true; } if(e.Key==Key.F&&Keyboard.Modifiers==ModifierKeys.Control) { UI<TextBox>("SearchBox").Focus();e.Handled=true; } };
            Refresh();
            if(demo) Window.Loaded+=(s,e)=> {
                LoadDemo();
                UI<Button>("NavDrivers").RaiseEvent(new RoutedEventArgs(Button.ClickEvent));
                if(UI<ItemsControl>("ResultList").Items.Count!=1) throw new Exception("Category filtering failed");
                UI<TextBox>("SearchBox").Text="no-matching-result-123";
                if(UI<ItemsControl>("ResultList").Items.Count!=0||UI<Border>("EmptyState").Visibility!=Visibility.Visible) throw new Exception("Search empty state failed");
                UI<TextBox>("SearchBox").Text="";UI<Button>("NavAll").RaiseEvent(new RoutedEventArgs(Button.ClickEvent));
                UI<CheckBox>("IssuesOnly").IsChecked=true;
                if(UI<ItemsControl>("ResultList").Items.Count!=2) throw new Exception("Issue filtering failed");
                UI<CheckBox>("IssuesOnly").IsChecked=false;
                Window.Dispatcher.BeginInvoke(new Action(()=> {
                    try {
                        var root=(FrameworkElement)Window.Content;Window.Content=null;
                        foreach(var size in new [] {new Size(1180,810),new Size(960,640)}) {
                            root.Width=size.Width;root.Height=size.Height;root.Measure(size);root.Arrange(new Rect(new Point(0,0),size));root.UpdateLayout();
                            var bitmap=new RenderTargetBitmap((int)size.Width,(int)size.Height,96,96,PixelFormats.Pbgra32);bitmap.Render(root);
                            var encoder=new PngBitmapEncoder();encoder.Frames.Add(BitmapFrame.Create(bitmap));
                            using(var output=File.Create(size.Width==1180?"preview.png":"preview-compact.png")) encoder.Save(output);
                        }
                        File.WriteAllText("smoke-test.txt","PASS: WPF load, category/search/issue filters, empty state, 1180x810 and 960x640 layouts rendered. SAMPLE DATA ONLY.");
                    } catch(Exception ex) { File.WriteAllText("test-error.txt",ex.ToString());Environment.ExitCode=1; }
                    Window.Close();
                }),DispatcherPriority.ApplicationIdle);
            };
        }
        private void ToggleMaximize() { Window.MaxHeight=SystemParameters.WorkArea.Height;Window.WindowState=Window.WindowState==WindowState.Maximized?WindowState.Normal:WindowState.Maximized; }
        private void Open(string uri) {
            if(!new [] {"https://t.me/boroobro","https://www.facebook.com/rainysupport/","windowsdefender://threat","ms-settings:windowsupdate"}.Contains(uri)) return;
            try { Process.Start(new ProcessStartInfo(uri){UseShellExecute=true}); } catch { MessageBox.Show(Window,"Хаягийг нээж чадсангүй:\n"+uri,"RAINY",MessageBoxButton.OK,MessageBoxImage.Information); }
        }
        private async Task StartScan() {
            if(scanning) return;
            scanning=true;complete=false;findings.Clear();scanner=new Scanner();category="all";
            UI<TextBox>("SearchBox").Text="";UI<CheckBox>("IssuesOnly").IsChecked=false;
            UI<Button>("ScanButton").IsEnabled=false;UI<Button>("CancelButton").Visibility=Visibility.Visible;UI<Button>("CancelButton").IsEnabled=true;
            UI<TextBlock>("HeroTitle").Text="Компьютерийг шалгаж байна…";UI<TextBlock>("HeroSubtitle").Text="18 бүлэг шалгалт · зарим мэдээлэлд нэмэлт эрх шаардагдаж болно.";
            UI<ProgressBar>("ScanProgress").Value=0;Refresh();
            var result=await Task.Run(()=>scanner.Run(d=> {
                if(closing) return;
                Window.Dispatcher.BeginInvoke(new Action(()=> {
                    if(closing) return;
                    string kind=Finding.Get(d,"kind");
                    if(kind=="finding") { findings.Add(Finding.From(d));Refresh(); }
                    if(kind=="progress") { double value;Double.TryParse(Finding.Get(d,"value"),out value);UI<ProgressBar>("ScanProgress").Value=value;UI<TextBlock>("ScanStatus").Text=Finding.Get(d,"title"); }
                }));
            }));
            if(closing) return;
            scanning=false;complete=result.Complete;
            UI<Button>("ScanButton").IsEnabled=true;UI<Button>("ScanButton").Content="Дахин шалгах  ↻";UI<Button>("CancelButton").Visibility=Visibility.Collapsed;
            UI<TextBlock>("HeroTitle").Text=complete?"Таны тайлан бэлэн боллоо":"Шалгалт хэсэгчлэн дууслаа";
            UI<TextBlock>("HeroSubtitle").Text=result.Message;
            UI<TextBlock>("ScanStatus").Text=DateTime.Now.ToString("HH:mm")+" · "+(complete?"Дууссан":"Хэсэгчилсэн");
            if(complete) UI<ProgressBar>("ScanProgress").Value=100;
            Refresh();
        }
        private void Refresh() {
            if(Window==null) return;
            bool any=findings.Count>0;
            UI<TextBlock>("TotalCount").Text=any?findings.Count.ToString():"—";
            UI<TextBlock>("OkCount").Text=any?findings.Count(x=>x.State=="ok").ToString():"—";
            UI<TextBlock>("IssueCount").Text=any?Report.Attention(findings).ToString():"—";
            UI<TextBlock>("UnknownCount").Text=any?findings.Count(x=>x.State=="unknown").ToString():"—";
            UI<Button>("ExportButton").IsEnabled=any&&!scanning;UI<Button>("CopyButton").IsEnabled=any&&!scanning;
            string query=UI<TextBox>("SearchBox").Text??"";
            var list=findings.Where(x=>(category=="all"||x.Category==category)&&(!(UI<CheckBox>("IssuesOnly").IsChecked??false)||x.State=="warning"||x.State=="critical")&&((x.Title+" "+x.Summary+" "+x.Detail).IndexOf(query,StringComparison.CurrentCultureIgnoreCase)>=0)).OrderBy(x=>x.Priority).ToList();
            UI<ItemsControl>("ResultList").ItemsSource=list;
            UI<Border>("EmptyState").Visibility=list.Count>0?Visibility.Collapsed:Visibility.Visible;
            UI<TextBlock>("EmptyTitle").Text=any?"Тохирох үр дүн алга":scanning?"Мэдээлэл уншиж байна…":"Таны тайлан энд харагдана";
            UI<TextBlock>("EmptyText").Text=any?"Хайлт эсвэл шүүлтүүрээ өөрчилнө үү.":scanning?"Windows-оос бодит мэдээлэл авч байна.\nТа хүссэн үедээ зогсоож болно.":"Шалгалт эхлүүлэх товчийг дарна уу.\nТохиргоо өөрчлөхгүй, програм устгахгүй.";
            UI<TextBlock>("ResultsTitle").Text=(category=="all"?"Шалгалтын үр дүн":Finding.CategoryName(category))+ (any?"  ·  "+list.Count:"");
            string conclusion=Report.Conclusion(findings,complete);
            var offers=findings.Where(x=>(x.State=="critical"||x.State=="warning")&&!String.IsNullOrWhiteSpace(x.Service)).Select(x=>x.Service).Distinct().Take(2).ToArray();
            if(offers.Length>0) conclusion+="\nТусламж: "+String.Join(" · ",offers)+". Холбогдож үнэ, хүрээг тохиролцоно.";
            UI<TextBlock>("ConclusionText").Text=conclusion;
            foreach(string name in navigation) { var b=UI<Button>(name);bool selected=(string)b.Tag==category;b.Background=new SolidColorBrush((Color)ColorConverter.ConvertFromString(selected?"#1A3935":"#101827"));b.Foreground=new SolidColorBrush((Color)ColorConverter.ConvertFromString(selected?"#86E8CA":"#A9B8D0")); }
        }
        private void Export() {
            var dialog=new SaveFileDialog {Title="RAINY тайлан хадгалах",FileName="RAINY-Health-"+DateTime.Now.ToString("yyyyMMdd-HHmm"),Filter="HTML тайлан (*.html)|*.html|JSON өгөгдөл (*.json)|*.json",DefaultExt=".html",AddExtension=true};
            if(dialog.ShowDialog(Window)!=true) return;
            try {
                string data=dialog.FilterIndex==2?new JavaScriptSerializer {MaxJsonLength=8*1024*1024}.Serialize(new {app="RAINY PC Health",version="1.0",createdAt=DateTimeOffset.Now.ToString("o"),complete=complete,conclusion=Report.Conclusion(findings,complete),findings=findings}):Report.Html(findings,complete);
                File.WriteAllText(dialog.FileName,data,new UTF8Encoding(false));UI<TextBlock>("ScanStatus").Text="Тайлан хадгалагдлаа";
            } catch { MessageBox.Show(Window,"Файл хадгалж чадсангүй. Өөр хавтас сонгоно уу.","RAINY",MessageBoxButton.OK,MessageBoxImage.Warning); }
        }
        private void LoadDemo() {
            findings.AddRange(new [] {
                new Finding {Category="drivers",State="warning",Title="Network Controller",Summary="Driver суулгаагүй · Code 28",Detail="ЖИШЭЭ ӨГӨГДӨЛ. Device Manager-ийн алдааны код.",Service="Driver суулгах"},
                new Finding {Category="hardware",State="warning",Title="Диск C:",Summary="18.4 GB сул · 7%",Detail="ЖИШЭЭ ӨГӨГДӨЛ. Багтаамжийн зөвлөмж.",Service="Диск цэвэрлэх"},
                new Finding {Category="license",State="unknown",Title="Office-ийн ашиглаж буй эрх",Summary="Word → File → Account хэсгээс баталгаажуулна",Detail="ЖИШЭЭ ӨГӨГДӨЛ."},
                new Finding {Category="license",State="ok",Title="Windows activation",Summary="Windows 11 Pro · Идэвхжсэн",Detail="ЖИШЭЭ ӨГӨГДӨЛ."},
                new Finding {Category="security",State="ok",Title="Бодит цагийн хамгаалалт",Summary="Microsoft Defender ажиллаж байна",Detail="ЖИШЭЭ ӨГӨГДӨЛ."},
                new Finding {Category="hardware",State="ok",Title="Санах ой · RAM",Summary="16 GB · одоо 42% ашиглаж байна",Detail="ЖИШЭЭ ӨГӨГДӨЛ."},
                new Finding {Category="system",State="info",Title="Сүүлийн hotfix",Summary="Шинэчлэлтийн бүртгэл",Detail="ЖИШЭЭ ӨГӨГДӨЛ."},
                new Finding {Category="apps",State="info",Title="Суулгасан програмууд",Summary="24 програмын бүртгэл",Detail="ЖИШЭЭ ӨГӨГДӨЛ."}
            });
            complete=true;UI<Button>("ScanButton").Content="Дахин шалгах  ↻";UI<TextBlock>("HeroTitle").Text="Таны тайлан бэлэн боллоо";UI<TextBlock>("HeroSubtitle").Text="ЗАГВАР ХАРАГДАЦ · ЖИШЭЭ ӨГӨГДӨЛ";UI<ProgressBar>("ScanProgress").Value=100;UI<TextBlock>("ScanStatus").Text="UI preview · бодит оношилгоо биш";Refresh();
        }
    }
}
