using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Text;

namespace RainyHealth {
    public sealed class Finding {
        public string Category { get; set; }
        public string State { get; set; }
        public string Title { get; set; }
        public string Summary { get; set; }
        public string Detail { get; set; }
        public string Service { get; set; }
        public string Badge { get { return State == "critical" ? "НЭН ТҮРҮҮНД" : State == "warning" ? "АНХААРАХ" : State == "ok" ? "ХЭВИЙН" : State == "unknown" ? "ТОДОРХОЙГҮЙ" : "МЭДЭЭЛЭЛ"; } }
        public string Accent { get { return State == "critical" ? "#FB8796" : State == "warning" ? "#F4C175" : State == "ok" ? "#61DEC0" : State == "unknown" ? "#B9ACED" : "#93ACCE"; } }
        public string CategoryLabel { get { return CategoryName(Category); } }
        public int Priority { get { return State == "critical" ? 0 : State == "warning" ? 1 : State == "unknown" ? 2 : State == "ok" ? 3 : 4; } }
        public static string CategoryName(string category) {
            switch(category) { case "hardware": return "Төхөөрөмж"; case "drivers": return "Driver"; case "license": return "Лиценз"; case "security": return "Хамгаалалт"; case "system": return "Windows"; case "apps": return "Програмууд"; default: return "Ерөнхий"; }
        }
        public static Finding From(Dictionary<string, object> d) {
            var f = new Finding { Category=Get(d,"category"), State=Get(d,"state"), Title=Get(d,"title"), Summary=Get(d,"summary"), Detail=Get(d,"detail"), Service=Get(d,"service") };
            if (!new [] {"critical","warning","ok","unknown","info"}.Contains(f.State)) f.State="unknown";
            return f;
        }
        public static string Get(Dictionary<string, object> d, string key) { object v; return d.TryGetValue(key, out v) && v != null ? Convert.ToString(v) : ""; }
    }
    public static class Report {
        public static int Attention(IEnumerable<Finding> f) { return f.Count(x => x.State == "critical" || x.State == "warning"); }
        public static string Conclusion(IList<Finding> f, bool complete) {
            if(f.Count==0) return "Шалгалт эхлүүлэхэд таны компьютерийн бодит үр дүн энд харагдана.";
            int urgent=f.Count(x=>x.State=="critical"), attention=Attention(f), unknown=f.Count(x=>x.State=="unknown");
            string text=!complete ? "Хэсэгчилсэн үр дүн. " : "Шалгалт дууслаа. ";
            text += urgent>0 ? urgent+" нэн түрүүнд шалгах зүйл байна. " : attention>0 ? "Анхаарах тохиргоо эсвэл асуудал илэрлээ. " : "Гүйцэтгэсэн шалгалтаар анхааруулга илрээгүй. ";
            if(unknown>0) text += unknown+" үр дүн тодорхойгүй. ";
            return text+"Энэ нь бүрэн hardware тест, вирусын скан эсвэл бүх асуудлыг үгүйсгэх баталгаа биш.";
        }
        public static string Plain(IList<Finding> f, bool complete) {
            var b=new StringBuilder("RAINY PC Health\r\n"+DateTime.Now.ToString("yyyy-MM-dd HH:mm")+"\r\n"+Conclusion(f,complete)+"\r\n\r\n");
            foreach(var x in f.OrderBy(x=>x.Priority)) b.AppendLine("["+x.Badge+"] "+x.Title+" — "+x.Summary);
            return b.ToString();
        }
        public static string Html(IList<Finding> f, bool complete) {
            Func<string,string> e=x=>WebUtility.HtmlEncode(x??"");
            var b=new StringBuilder("<!doctype html><html lang='mn'><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>RAINY PC Health</title><style>body{background:#0c1320;color:#e6edf7;font:16px/1.6 Segoe UI,sans-serif;max-width:960px;margin:auto;padding:40px 24px}h1{font-size:36px}article,header,footer{background:#141f30;border:1px solid #29374c;border-radius:16px;padding:22px;margin:14px 0}p,pre{color:#bac8dc}pre{white-space:pre-wrap;overflow-wrap:anywhere;font:14px/1.7 Segoe UI,sans-serif}small{color:#7bdcc0}a{color:#7bdcc0;margin-right:18px}@media print{body,article,header,footer{background:white;color:black}p,pre{color:#333}}</style><header><small>RAINY / ҮНЭГҮЙ PC ОНОШИЛГОО</small><h1>Таны компьютерийн тайлан</h1><p>"+e(DateTime.Now.ToString("yyyy-MM-dd HH:mm"))+"</p><p>"+e(Conclusion(f,complete))+"</p></header>");
            foreach(var x in f.OrderBy(x=>x.Priority)) b.Append("<article><small style='color:"+x.Accent+"'>"+e(x.Badge)+" · "+e(x.CategoryLabel)+"</small><h2>"+e(x.Title)+"</h2><p>"+e(x.Summary)+"</p><pre>"+e(x.Detail)+"</pre></article>");
            var services=f.Where(x=>(x.State=="critical"||x.State=="warning")&&!String.IsNullOrWhiteSpace(x.Service)).Select(x=>x.Service).Distinct().ToList();
            b.Append("<footer><h2>Танд тохирох тусламж</h2>");
            if(services.Count==0) b.Append("<p>Төлбөртэй үйлчилгээ зайлшгүй хэрэгтэй гэж тогтоогоогүй.</p>");
            foreach(var s in services) b.Append("<p>• "+e(s)+"</p>");
            b.Append("<p>Үнэ, ажлын хүрээг холбогдож тохиролцоно. Тайлан автоматаар илгээгдэхгүй.</p><a href='https://t.me/boroobro'>Telegram ↗</a><a href='https://www.facebook.com/rainysupport/'>Facebook ↗</a></footer></html>");
            return b.ToString();
        }
    }
}
