using System;
using System.Collections.Generic;
using System.IO;
namespace RainyHealth {
    public static class Tests {
        static void Assert(bool value,string message) { if(!value) throw new Exception(message); }
        public static void Run() {
            var f=new List<Finding> {new Finding {Category="security",State="unknown",Title="<script>alert(1)</script>",Summary="A & B",Detail="<private>",Service=""},new Finding {Category="apps",State="info",Title="App",Summary="Not malware",Detail="",Service=""}};
            Assert(Report.Attention(f)==0,"Unknown and informational results must not become risks");
            Assert(Report.Conclusion(f,false).Contains("Хэсэгчилсэн"),"Partial result needs explicit label");
            var html=Report.Html(f,true);
            Assert(!html.Contains("<script>"),"Report must HTML-encode system strings");
            Assert(html.Contains("&lt;script&gt;"),"Report must preserve escaped text");
            Assert(html.Contains("https://t.me/boroobro")&&html.Contains("https://www.facebook.com/rainysupport/"),"Contacts must match owner-provided URLs");
            f.Add(new Finding {Category="drivers",State="warning",Title="Driver",Summary="28",Detail="",Service="Driver суулгах"});
            Assert(Report.Attention(f)==1,"Warning count");
            Assert(Report.Html(f,true).Contains("Driver суулгах"),"Relevant service is included");
            var d=new Dictionary<string,object>{{"state","bad-provider-value"}};
            Assert(Finding.From(d).State=="unknown","Unexpected state must be unknown");
            File.WriteAllText("self-test.txt","PASS: unknown handling, partial status, HTML escaping, contacts, recommendations, parser states.");
        }
    }
}
