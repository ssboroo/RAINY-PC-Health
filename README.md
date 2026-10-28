<p align="center"><img src="assets/rainy.svg" width="104" alt="RAINY shield and pulse icon"></p>
<h1 align="center">RAINY PC Health</h1>
<p align="center">Үнэгүй оношилгоо. Бодит мэдээлэл. Хэрэгтэй үед тусламж.</p>
<p align="center"><a href="https://github.com/ssboroo/RAINY-PC-Health/releases/latest">Portable EXE татах</a> · <a href="https://t.me/boroobro">Telegram</a> · <a href="https://www.facebook.com/rainysupport/">Facebook</a></p>

![Windows build](https://github.com/ssboroo/RAINY-PC-Health/actions/workflows/build.yml/badge.svg)

Монгол интерфэйстэй, суулгалт шаардахгүй Windows desktop програм. Native WPF интерфэйс, нэг EXE, гуравдагч runtime багцлахгүй. Windows-ийн .NET Framework 4.8 болон Windows PowerShell 5.1-ийг ашиглана. Build хэмжээний дээд хязгаар 2 MB; release дээр бодит хэмжээ нь харагдана.

![Native desktop preview — жишээ өгөгдөл](https://github.com/ssboroo/RAINY-PC-Health/releases/latest/download/preview.png)

## Татаж ажиллуулах

1. [Latest release](https://github.com/ssboroo/RAINY-PC-Health/releases/latest)-ээс **RAINY-PC-Health.exe** татна. ZIP сонговол эхлээд задална.
2. EXE-г энгийн хэрэглэгчээр нээгээд **Шалгалт эхлүүлэх** дарна.
3. Үр дүнг ангиллаар үзэж, **Дэлгэрэнгүй** хэсгийг дэлгэнэ. Хайлт эсвэл **Анхаарах** шүүлтүүр ашиглаж болно.
4. **Тайлан хадгалах** нь HTML эсвэл JSON файл үүсгэнэ. HTML-ийг browser-оос PDF болгож хэвлэж болно.
5. Засвар, driver, лиценз, програм суулгалтын тусламж авах бол Telegram/Facebook товчийг дарна. Үнэ, ажлын хүрээг холбогдож тохиролцоно.

**Шаардлага:** Windows 10/11, .NET Framework 4.8, Windows PowerShell 5.1. Windows on ARM-ийн нийцэл тусад нь баталгаажаагүй. Windows 10-ийн support/ESU эрхийг энэ програм баталгаажуулахгүй. Байгууллагын AppLocker/WDAC/PowerShell бодлогоор хязгаарлагдсан бол бодлогыг сулруулахын оронд IT админтайгаа зөвлөлдөнө. Програм code-sign хийгдээгүй; анх татахад Windows SmartScreen reputation мэдэгдэл гарч болно. Release-ийн SHA256SUMS.txt-ээр файлаа тулгаж болно.

## Юу шалгах вэ?

| Хэсэг | Бодит эх сурвалж / дүгнэлт |
|---|---|
| Төхөөрөмж | Model, CPU, OS, RAM багтаамж/агшны ашиглалт, uptime |
| Диск | Сул зай, Windows storage provider-ийн health |
| Driver | Одоо байгаа PnP төхөөрөмжийн ConfigManagerErrorCode; Code 28 бол driver суулгаагүй |
| Windows activation | Локал SoftwareLicensingProduct төлөв; бүтээгдэхүүний key-г харуулахгүй |
| Office | Volume/legacy лицензийн бүртгэл; боломжтой, баталгаатай Microsoft vnextdiag-аар M365 төлөв |
| Антивирус | Security Center-д бүртгэлтэй бүтээгдэхүүн; Defender real-time, signature age, quick scan түүх |
| Илрүүлэлт | Defender-ийн идэвхтэй threat түүх; бусад антивирусын түүхийг уншихгүй |
| Хамгаалалт | Firewall profiles, UAC, Secure Boot, Defender PUA mode |
| Windows | Hotfix огноо, servicing/update restart хүсэлт, 7 хоногийн Kernel-Power 41 түүх |
| Програм | Uninstall registry inventory, алсын хандалтын програмын мэдээлэл, startup нэрс |

**Нэн түрүүнд / Анхаарах / Хэвийн / Тодорхойгүй / Мэдээлэл** гэсэн төлөвүүдтэй. Тодорхойгүй мэдээллийг эрсдэл гэж тооцохгүй. Хуурамч “health score” ашиглахгүй. Үйлчилгээний санал зөвхөн бодитоор гарсан warning/critical шалгалттай холбогдоно. Төлбөртэй үйлчилгээ заавал авах шаардлагагүй.

## Хамрах хүрээ

- Энэ нь бүх эвдрэл, malware, CVE, батерей/температур, дискний элэгдлийг илрүүлдэг бүрэн лабораторийн тест биш.
- **Вирус шалгах** товч Windows Security-г нээнэ. Шинэ сканыг хэрэглэгч өөрөө эхлүүлнэ. Энэ програм antivirus engine багцлахгүй, файл цэвэрлэхгүй.
- Driver огноогоор “хуучирсан” гэж дүгнэхгүй; online driver catalog татахгүй. Code 22 идэвхгүй төхөөрөмжийг “driver дутуу” гэж тэмдэглэхгүй.
- Идэвхжсэн гэдэг нь лиценз худалдан авалтын хууль ёсны эрхийн баталгаа биш. KMS/байгууллагын лицензийг хуурамч гэж ангилахгүй.
- Office-ийн бүх retail/subscription хувилбар дэмжигдэхгүй. M365 шалгалт одоогийн хэрэглэгчид хамаарна. Microsoft-ийн script олдохгүй, гарын үсгийг батлахгүй эсвэл output танигдахгүй бол Word → File → Account-оор шалгахыг зөвлөнө.
- Remote access програм суусан байх нь вирусын нотолгоо биш. Програмын нэрээр malware гэж ангилахгүй.
- “Хэвийн” нь зөвхөн тухайн шалгалтанд хамаарна; компьютер бүхэлдээ асуудалгүй гэсэн баталгаа биш.

## Нууцлал ба portable ажиллагаа

- Телеметр, сервер upload, account, төлбөрийн SDK байхгүй. Оношилгоо интернетээр өгөгдөл илгээхгүй. Windows provider-ийн өөрийн үйлдлийг програм удирдахгүй.
- Serial number, product key, хэрэглэгчийн email, лиценз/tenant ID, startup command line, хувийн файлын замыг тайланд оруулахгүй.
- Windows/Office/antivirus-ийн тохиргоог өөрчлөхгүй; засвар, download, install, delete, restart автоматаар хийхгүй.
- Оношилгооны embedded PowerShell код RAM-аас ажиллана. `ExecutionPolicy Bypass` нь зөвхөн тухайн child process-д үйлчилнэ, системийн execution policy-г өөрчлөхгүй.
- EXE нь өөрийн config, log, scan файлуудыг үлдээхгүй. Тайланг зөвхөн **Хадгалах** дээр дарж, өөрийн сонгосон замд үүсгэнэ. Хуулах үйлдэл зөвхөн таны товч дарснаар clipboard-д бичнэ.
- Холбоо барих товч нь зөвхөн таны browser-оор тогтмол URL нээнэ; тайланг автоматаар хавсаргахгүй, мессеж илгээхгүй.
- Скан UI-г түгжихгүй, зогсоох боломжтой, 4 минутын нийт timeout-той. Зогссон/алдаатай сканыг **хэсэгчилсэн** гэж тодорхой тэмдэглэнэ.

## Build / validation

Windows PowerShell 5.1 дээр:

```powershell
.\build.ps1
.\dist\RAINY-PC-Health.exe
```

.NET Framework-ийн өөрийн `csc.exe`-г ашигладаг; NuGet/Node/Electron хэрэггүй. XAML, collector, icon бүгд EXE дотор embedded. Build-ийн үед PowerShell syntax болон classification tests, C# тайлангийн escaping/summary тест ажиллана.

GitHub Actions нь native WPF цонхыг sample data-тай render хийж, runner дээр бодит collector smoke test ажиллуулсны дараа EXE, ZIP, SHA256, preview-ийг Release болгоно. Preview дээрх **ЖИШЭЭ ӨГӨГДӨЛ** нь дизайн шалгах зориулалттай; хэрэглэгчийн бодит төхөөрөмж биш.

Runner дээрх smoke test нь хэрэглэгчийн Windows 10/11 төхөөрөмжүүдийн compatibility баталгаа биш. Нийтэд өргөн түгээхийн өмнө дараах matrix-ийг шалгах хэрэгтэй:

- Windows 10/11, стандарт хэрэглэгч/админ, 100/125/150% DPI, 1366×768 дэлгэц.
- Defender/өөр антивирус/бодлогоор хориглосон provider.
- Windows идэвхтэй/идэвхгүй; Office байхгүй/LTSC/M365, олон хэрэглэгч.
- Дутуу/унтраасан driver, дискний сул зай бага, storage provider дэмжигдээгүй.
- Сканыг зогсоох, цонх хаах, тайлан хадгалах боломжгүй хавтас, Монгол/зайтай зам.

## Эх сурвалж

- [Win32_PnPEntity / driver codes](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-pnpentity)
- [SoftwareLicensingProduct](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/sppwmi/softwarelicensingproduct)
- [Microsoft 365 vnextdiag](https://learn.microsoft.com/en-us/microsoft-365-apps/licensing-activation/vnextdiag)
- [Defender status](https://learn.microsoft.com/en-us/powershell/module/defender/get-mpcomputerstatus)
- [Defender threat history](https://learn.microsoft.com/en-us/powershell/module/defender/get-mpthreat)

---
**RAINY Support** · [t.me/boroobro](https://t.me/boroobro) · [facebook.com/rainysupport](https://www.facebook.com/rainysupport/)
