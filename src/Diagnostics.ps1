param([switch]$FunctionsOnly)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'
$InformationPreference = 'SilentlyContinue'

function Get-LicenseState($Code) {
    if ($null -eq $Code) { return 'unknown' }
    if ([int]$Code -eq 1) { return 'ok' }
    if ([int]$Code -in @(0,2,3,4,5,6)) { return 'warning' }
    return 'unknown'
}
function Get-DiskState([Nullable[double]]$Percent) {
    if ($null -eq $Percent -or $Percent -lt 0 -or $Percent -gt 100) { return 'unknown' }
    if ($Percent -lt 5) { return 'critical' }
    if ($Percent -lt 15) { return 'warning' }
    return 'ok'
}
function Get-DriverState($Code) {
    if ($null -eq $Code) { return 'unknown' }
    if ($Code -eq 0) { return 'ok' }
    if ($Code -in @(22,45)) { return 'info' }
    return 'warning'
}
function Get-VNextStates([string]$Output) {
    # Only the state is retained. Email, tenant IDs, license IDs and keys are discarded.
    @([regex]::Matches($Output, '(?im)^\s*(?:License\s*State|State)\s*:\s*([A-Za-z]+)\s*$') | ForEach-Object { $_.Groups[1].Value })
}
if ($FunctionsOnly) { return }
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$script:step = 0
$script:total = 18
function Emit($Object) { [Console]::WriteLine(($Object | ConvertTo-Json -Depth 5 -Compress)) }
function Finding($Category,$State,$Title,$Summary,$Detail='',$Service='') {
    Emit ([ordered]@{kind='finding';category=$Category;state=$State;title=$Title;summary=[string]$Summary;detail=[string]$Detail;service=$Service})
}
function Check($Category,$Title,[scriptblock]$Body) {
    Emit @{kind='progress';title=$Title;value=[int](100*$script:step/$script:total)}
    try { & $Body } catch {
        Finding $Category 'unknown' $Title 'Мэдээллийг бүрэн уншиж чадсангүй.' 'Эрх хүрэлцэхгүй, provider дэмжигдээгүй эсвэл Windows үйлчилгээ ажиллахгүй байж болно. Энэ төлөвийг асуудал гэж тооцоогүй.'
    }
    $script:step++
}
function Cim($Class,$Namespace='root/cimv2') { Get-CimInstance -ClassName $Class -Namespace $Namespace -OperationTimeoutSec 12 }
$script:apps = @()
Check 'hardware' 'Төхөөрөмжийн мэдээлэл' {
    $pc = Cim 'Win32_ComputerSystem'
    $os = Cim 'Win32_OperatingSystem'
    $cpu = @(Cim 'Win32_Processor')
    Finding 'hardware' 'info' "$($pc.Manufacturer) $($pc.Model)" "$($os.Caption) · Build $($os.BuildNumber)" (($cpu.Name -join ', ') + "`nАрхитектур: $($os.OSArchitecture)")
    if (!$pc.TotalPhysicalMemory -or !$os.TotalVisibleMemorySize) { throw 'Memory unavailable' }
    $ram = [math]::Round($pc.TotalPhysicalMemory/1GB,1)
    $used = [math]::Round(100*(1-$os.FreePhysicalMemory/$os.TotalVisibleMemorySize))
    $state='ok'; $service=''
    if ($ram -lt 8) { $state='warning';$service='RAM нэмэх боломжийг шалгуулах' }
    Finding 'hardware' $state 'Санах ой · RAM' "$ram GB · одоо $used% ашиглаж байна" '8 GB-аас бага RAM нь олон програм зэрэг ажиллуулахад хүрэлцэхгүй байж болно. Энэ бол багтаамжийн зөвлөмж, гэмтлийн онош биш. Ашиглалт нь тухайн агшны утга.' $service
    if ($os.LastBootUpTime) {
        $days=[math]::Floor(((Get-Date)-$os.LastBootUpTime).TotalDays)
        Finding 'hardware' 'info' 'Ажилласан хугацаа' "$days өдөр асаалттай" 'Fast Startup ашигладаг бол унтрааж асаахад энэ тоо тэглэгдэхгүй байж болно.'
    }
}
Check 'hardware' 'Дискний сул зай' {
    $ds=@(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -OperationTimeoutSec 12)
    if (!$ds.Count) { throw 'No disk data' }
    foreach($d in $ds) {
        if (!$d.Size) { Finding 'hardware' 'unknown' "Диск $($d.DeviceID)" 'Багтаамж тодорхойгүй';continue }
        $pct=100*$d.FreeSpace/$d.Size; $state=Get-DiskState $pct; $service=''
        if($state -in @('critical','warning')) { $service='Диск цэвэрлэх / SSD багтаамж нэмэх' }
        Finding 'hardware' $state "Диск $($d.DeviceID)" "$([math]::Round($d.FreeSpace/1GB,1)) GB сул · $([math]::Round($pct))%" "Нийт $([math]::Round($d.Size/1GB,1)) GB. 15%-аас бага сул зайг анхаарах, 5%-аас багыг нэн түрүүнд шийдэхээр тэмдэглэнэ." $service
    }
}
Check 'hardware' 'Дискний health төлөв' {
    $ds=@(Get-PhysicalDisk -ErrorAction Stop)
    if(!$ds.Count) { throw 'No physical disks' }
    foreach($d in $ds) {
        $state='unknown';$service=''
        if ([string]$d.HealthStatus -eq 'Healthy') { $state='ok' }
        elseif ([string]$d.HealthStatus -in @('Warning','Unhealthy')) { $state='critical';$service='Өгөгдөл нөөцлөх / диск оношлуулах' }
        Finding 'hardware' $state ([string]$d.FriendlyName) "Storage health: $($d.HealthStatus)" 'Windows storage provider-ийн төлөв. Бүрэн SMART, температур, элэгдэл, surface test эсвэл ирээдүйн эвдрэлийн баталгаа биш.' $service
    }
}
Check 'drivers' 'Driver ба төхөөрөмжүүд' {
    $devices=@(Cim 'Win32_PnPEntity' | Where-Object { $_.Present -ne $false })
    if(!$devices.Count) { throw 'No device data' }
    $unknown=@($devices | Where-Object { $null -eq $_.ConfigManagerErrorCode })
    $bad=@($devices | Where-Object { $null -ne $_.ConfigManagerErrorCode -and $_.ConfigManagerErrorCode -ne 0 })
    if(!$bad.Count -and !$unknown.Count) { Finding 'drivers' 'ok' 'Driver-ийн алдаа бүртгэгдээгүй' "$($devices.Count) төхөөрөмж шалгалаа" 'Device Manager-ийн төлөвт тулгуурлав. Driver хамгийн сүүлийн хувилбар эсэхийг интернеттэй тулгаж шалгаагүй.' }
    if($unknown.Count) { Finding 'drivers' 'unknown' 'Төлөвгүй төхөөрөмж' "$($unknown.Count) төхөөрөмжийн алдааны код тодорхойгүй" }
    foreach($d in $bad) {
        $code=[int]$d.ConfigManagerErrorCode; $state=Get-DriverState $code
        $label=switch($code) { 28 {'Driver суулгаагүй'} 22 {'Төхөөрөмж идэвхгүй'} 10 {'Төхөөрөмж эхлэхгүй'} 14 {'Restart шаардлагатай'} 18 {'Driver дахин суулгах шаардлагатай'} 31 {'Driver ачаалж чадахгүй'} 43 {'Төхөөрөмж алдаа мэдээлсэн'} 45 {'Төхөөрөмж холбоогүй'} default {'Төхөөрөмжийн алдаа'} }
        $service='';if($state -eq 'warning') { $service='Driver суулгах / төхөөрөмжийн алдаа засах' }
        Finding 'drivers' $state ([string]$d.Name) "$label · Code $code" "Ангилал: $($d.PNPClass). Code 22 нь зориуд унтраасан төхөөрөмж байж болно. Хуучин driver огноогоор шинэчлэлт шаардлагатай гэж дүгнээгүй." $service
    }
}
$script:lic=@()
Check 'license' 'Windows идэвхжүүлэлт' {
    $script:lic=@(Cim 'SoftwareLicensingProduct' | Where-Object { $_.PartialProductKey })
    $win=@($script:lic | Where-Object { $_.ApplicationID -eq '55c92734-d682-4d71-983e-d6ec3f16059f' -and !$_.LicenseIsAddon })
    if(!$win.Count) { throw 'No Windows license state' }
    $labels=@('Идэвхжээгүй','Идэвхжсэн','Анхны grace хугацаа','Grace хугацаа','Non-genuine grace','Notification төлөв','Сунгасан grace хугацаа')
    foreach($l in $win) {
        $state=Get-LicenseState $l.LicenseStatus;$label='Төлөв тодорхойгүй';$service=''
        if($state -ne 'unknown') { $label=$labels[[int]$l.LicenseStatus] }
        if($state -eq 'warning') { $service='Windows лиценз / activation алдаа засах' }
        Finding 'license' $state 'Windows activation' $label "$($l.Name)`n$($l.Description)`nИдэвхжсэн төлөв нь лиценз худалдан авалтын хууль ёсны эрхийг батлахгүй. Байгууллагын KMS лицензийг хуурамч гэж үзэхгүй." $service
    }
}
Check 'apps' 'Суулгасан програмууд' {
    $keys=@('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')
    $readable=0
    foreach($key in $keys) {
        if(Test-Path ($key -replace '\\\*$','')) {
            $items=@(Get-ItemProperty $key -ErrorAction Stop | Where-Object { $_.DisplayName -and !$_.SystemComponent })
            $script:apps += $items;$readable++
        }
    }
    if(!$readable) { throw 'Registry unavailable' }
    $script:apps=@($script:apps | Sort-Object DisplayName,DisplayVersion -Unique)
    $list=($script:apps | ForEach-Object { "$($_.DisplayName)  $($_.DisplayVersion)" }) -join "`n"
    Finding 'apps' 'info' 'Суулгасан програмууд' "$($script:apps.Count) програмын бүртгэл" ($list + "`n`nЗөвхөн uninstall registry. Portable, Store болон бусад хэрэглэгчийн програм бүрэн багтахгүй. CVE/эмзэг байдлын онлайн шалгалт хийгээгүй.")
    $remote=@($script:apps | Where-Object { $_.DisplayName -match 'AnyDesk|TeamViewer|RustDesk|UltraViewer|Remote Utilities|ScreenConnect' })
    if($remote.Count) { Finding 'apps' 'info' 'Алсын хандалтын програм' ($remote.DisplayName -join ', ') 'Эдгээр нь хууль ёсны тусламжийн хэрэгслүүд; вирус гэж ангилаагүй. Танихгүй хүн суулгасан эсэх, unattended access зөвшөөрлийг өөрөө шалгана.' }
}
Check 'license' 'Office / Microsoft 365' {
    $office=@($script:apps | Where-Object { $_.DisplayName -match 'Microsoft (365|Office)' })
    $records=@($script:lic | Where-Object { $_.Name -match 'Office' })
    try { $records += @(Cim 'OfficeSoftwareProtectionProduct' | Where-Object { $_.PartialProductKey }) } catch { }
    $records=@($records | Sort-Object ID -Unique)
    foreach($l in $records) {
        $label='Тодорхойгүй';$code=$l.LicenseStatus
        if($null -ne $code) { $label=@{0='Идэвхжээгүй';1='Идэвхжсэн';2='Grace';3='Grace';4='Non-genuine grace';5='Notification';6='Extended grace'}[[int]$code] }
        Finding 'license' 'info' 'Office лицензийн бүртгэл' "$($l.Name): $label" 'Одоогийн болон хуучин лицензийн үлдэгдэл зэрэг байж болно. Word → File → Account дахь ашиглаж буй бүтээгдэхүүнтэй тулган баталгаажуулна.'
    }
    $paths=@()
    foreach($root in @($env:ProgramFiles,${env:ProgramFiles(x86)})) {
        if($root) { $paths += (Join-Path $root 'Microsoft Office\Office16\vnextdiag.ps1');$paths += (Join-Path $root 'Microsoft Office\root\Office16\vnextdiag.ps1') }
    }
    $diag=$paths | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if($diag) {
        $sig=Get-AuthenticodeSignature -LiteralPath $diag
        if($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') { throw 'Unverified Office diagnostic script' }
        $raw=(& $diag -action list 2>&1 6>&1 | Out-String)
        $states=@(Get-VNextStates $raw)
        $raw=$null
        if(!$states.Count) { Finding 'license' 'unknown' 'Microsoft 365 activation' 'Лицензийн төлөвийг автоматаар тайлбарлаж чадсангүй.' 'Word → File → Account хэсгээс шалгана. Одоогийн Windows хэрэглэгчийн эрхийг л шалгасан.' }
        else {
            foreach($s in $states) {
                $state='unknown';$service=''
                if($s -eq 'Licensed') { $state='ok' }
                elseif($s -in @('Unlicensed','Notification','Grace','Expired')) { $state='warning';$service='Office лиценз / суулгалтын тусламж' }
                Finding 'license' $state 'Microsoft 365 activation' $s 'Microsoft-ийн vnextdiag -action list үр дүн. Одоогийн хэрэглэгчид хамаарна. Account, email болон license ID-г тайланд оруулаагүй.' $service
            }
        }
    } elseif($records.Count -or $office.Count) {
        Finding 'license' 'unknown' 'Office-ийн ашиглаж буй эрх' 'Word → File → Account хэсгээс баталгаажуулна.' 'Office бүртгэл илэрсэн ч бүх төрлийн retail, volume, subscription эрхийг нэг аргаар баталгаажуулах боломжгүй.'
    } else {
        Finding 'license' 'info' 'Office' 'Дэмжигдсэн Office бүртгэл олдсонгүй.' 'Office байхгүй гэдэг нь компьютерийн гэмтэл биш. Store, portable эсвэл өөр хэрэглэгчийн суулгалт энэ шалгалтад харагдахгүй байж болно.'
    }
}
Check 'security' 'Антивирусын бүртгэл' {
    $av=@(Cim 'AntiVirusProduct' 'root/SecurityCenter2')
    if($av.Count) { Finding 'security' 'info' 'Суулгасан антивирус' ($av.displayName -join ', ') 'Security Center-д бүртгэлтэй бүтээгдэхүүнүүд. Бүртгэл байгаа нь идэвхтэй эсвэл шинэчлэгдсэн хамгаалалтын баталгаа биш. Гуравдагч антивирусын дотоод төлөвийг өөрийн цонхноос нь шалгана.' }
    else { Finding 'security' 'unknown' 'Антивирусын бүртгэл' 'Security Center-д антивирус харагдсангүй.' 'Windows Security нээж хамгаалалтын provider-аа шалгана.' }
}
Check 'security' 'Microsoft Defender' {
    $m=Get-MpComputerStatus -ErrorAction Stop
    if($null -eq $m.AntivirusEnabled -or $null -eq $m.RealTimeProtectionEnabled) { throw 'Missing Defender fields' }
    if($m.AntivirusEnabled) {
        if($m.RealTimeProtectionEnabled) { Finding 'security' 'ok' 'Бодит цагийн хамгаалалт' 'Microsoft Defender ажиллаж байна' 'Энэ нь компьютер вирусгүй гэсэн баталгаа биш.' }
        else { Finding 'security' 'warning' 'Бодит цагийн хамгаалалт' 'Microsoft Defender real-time хамгаалалт унтраалттай' 'Windows Security хэсгээс бодлого, хамгаалалтын provider-аа шалгана.' 'Антивирус тохируулах / аюулгүй байдлын оношилгоо' }
        if($null -eq $m.AntivirusSignatureAge) { Finding 'security' 'unknown' 'Вирусын мэдээллийн сан' 'Шинэчлэлтийн огноо тодорхойгүй' }
        elseif($m.AntivirusSignatureAge -gt 7) { Finding 'security' 'warning' 'Вирусын мэдээллийн сан' "$($m.AntivirusSignatureAge) хоног шинэчлэгдээгүй" 'Windows Security → Protection updates.' 'Антивирус шинэчлэх / тохируулах' }
        else { Finding 'security' 'ok' 'Вирусын мэдээллийн сан' "$($m.AntivirusSignatureAge) хоногийн өмнө шинэчлэгдсэн" }
        if($null -eq $m.QuickScanAge -or $m.QuickScanAge -gt 30) { Finding 'security' 'info' 'Сүүлийн quick scan' 'Сүүлийн 30 хоногт quick scan бүртгэл алга' 'Вирус шалгах товч Windows Security-г нээнэ. Скан эхлүүлэх эсэхийг та шийднэ.' }
        else { Finding 'security' 'info' 'Сүүлийн quick scan' "$($m.QuickScanAge) хоногийн өмнө" 'Шинэ скан энэ оношилгоогоор ажиллуулаагүй.' }
    } else { Finding 'security' 'info' 'Microsoft Defender' 'Идэвхтэй antivirus provider биш байна' 'Өөр антивирус суусан эсвэл байгууллагын бодлого үйлчилж байж болно. Үүнийг дангаар нь вирусын эрсдэл гэж тооцохгүй.' }
}
Check 'security' 'Defender илрүүлэлтийн түүх' {
    $threats=@(Get-MpThreat -ErrorAction Stop)
    $active=@($threats | Where-Object { $_.IsActive -eq $true })
    if($active.Count) {
        foreach($t in $active) { Finding 'security' 'critical' 'Идэвхтэй илрүүлэлт' ([string]$t.ThreatName) 'Microsoft Defender-ийн түүхэнд IsActive=True гэж бүртгэгдсэн. Windows Security → Protection history хэсгээс арга хэмжээ авна.' 'Вирусын дэлгэрэнгүй шалгалт / цэвэрлэгээ' }
    } else { Finding 'security' 'info' 'Defender илрүүлэлтийн түүх' 'Идэвхтэй илрүүлэлт бүртгэгдээгүй' "Түүхэнд нийт $($threats.Count) бичлэг байна. Шинэ скан хийгээгүй тул вирусгүй гэж дүгнээгүй; бусад антивирусын түүхийг уншаагүй." }
}
Check 'security' 'Firewall' {
    $profiles=@(Get-NetFirewallProfile -PolicyStore ActiveStore -ErrorAction Stop)
    if(!$profiles.Count) { throw 'No firewall data' }
    foreach($p in $profiles) {
        if($null -eq $p.Enabled) { Finding 'security' 'unknown' "Firewall · $($p.Name)" 'Төлөв тодорхойгүй';continue }
        if([string]$p.Enabled -eq 'True') { Finding 'security' 'ok' "Firewall · $($p.Name)" 'Асаалттай' }
        elseif([string]$p.Enabled -eq 'False') { Finding 'security' 'warning' "Firewall · $($p.Name)" 'Унтраалттай' 'Энэ нь тухайн profile-ийн тохиргоо. Байгууллагын эсвэл гуравдагч firewall ашигладаг бол админтайгаа тулгана.' 'Firewall / хамгаалалт тохируулах' }
        else { Finding 'security' 'unknown' "Firewall · $($p.Name)" ([string]$p.Enabled) }
    }
}
Check 'security' 'UAC хамгаалалт' {
    $u=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name EnableLUA
    if($u.EnableLUA -eq 1) { Finding 'security' 'ok' 'UAC' 'Хэрэглэгчийн эрхийн хяналт асаалттай' }
    elseif($u.EnableLUA -eq 0) { Finding 'security' 'warning' 'UAC' 'Хэрэглэгчийн эрхийн хяналт унтраалттай' 'Администраторын эрх шаардсан өөрчлөлтийн хамгаалалт буурна.' 'Windows хамгаалалтын тохиргоо' }
    else { throw 'No UAC state' }
}
Check 'security' 'Secure Boot' {
    $secure=Confirm-SecureBootUEFI -ErrorAction Stop
    if($secure) { Finding 'security' 'ok' 'Secure Boot' 'Асаалттай' }
    else { Finding 'security' 'info' 'Secure Boot' 'Унтраалттай' 'UEFI тохиргоо, үйлдлийн системийн нийцлийг шалгасны дараа өөрчилнө. Унтраалттай байх нь вирусын нотолгоо биш.' }
}
Check 'system' 'Windows Update түүх' {
    $updates=@(Get-HotFix -ErrorAction Stop | Where-Object { $_.InstalledOn } | Sort-Object InstalledOn -Descending)
    if(!$updates.Count) { throw 'No hotfix date' }
    $last=$updates[0];$age=[math]::Floor(((Get-Date)-$last.InstalledOn).TotalDays)
    $state='info';$service=''
    if($age -gt 45) { $state='warning';$service='Windows Update алдаа засах / шинэчлэх' }
    Finding 'system' $state 'Сүүлийн hotfix' "$($last.HotFixID) · $($last.InstalledOn.ToString('yyyy-MM-dd'))" '45-аас олон хоногийн өмнөх hotfix бол Windows Update нээж шалгах зөвлөмж. Бүх update history-г хамрахгүй, шинэ update байгаа эсэхийг онлайнаар шалгаагүй; support/ESU эрхийг батлахгүй.' $service
}
Check 'system' 'Restart шаардлагатай эсэх' {
    $paths=@('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending','HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
    $pending=$false
    foreach($p in $paths) { if(Test-Path $p -ErrorAction Stop) { $pending=$true } }
    if($pending) { Finding 'system' 'warning' 'Restart хүлээгдэж байна' 'Windows servicing / update restart хүссэн' 'Ажлаа хадгалаад Restart хийнэ. Програм автоматаар restart хийхгүй.' }
    else { Finding 'system' 'ok' 'Restart төлөв' 'Шалгасан хоёр бүртгэлд restart хүсэлт алга' 'Бусад програмын pending restart төлөв багтаагүй.' }
}
Check 'apps' 'Автоматаар эхэлдэг програм' {
    $startup=@(Cim 'Win32_StartupCommand')
    Finding 'apps' 'info' 'Startup програмууд' "$($startup.Count) бүртгэл" (($startup.Name -join "`n") + "`n`nTask Manager → Startup apps хэсгээс шаардлагагүйг шалгана. Тоо их байх нь дангаараа гэмтэл эсвэл вирусын нотолгоо биш. Command line болон хэрэглэгчийн замыг хадгалаагүй.")
}
Check 'system' 'Системийн алдааны түүх' {
    $start=(Get-Date).AddDays(-7)
    $events=@(Get-WinEvent -FilterHashtable @{LogName='System';Id=41;StartTime=$start} -MaxEvents 30 -ErrorAction SilentlyContinue)
    # Validate log access separately: no matches and access denied must not look identical.
    Get-WinEvent -ListLog System -ErrorAction Stop | Out-Null
    if($events.Count) { Finding 'system' 'warning' 'Гэнэтийн унтралт' "7 хоногт $($events.Count) Kernel-Power 41 бичлэг (дээд тал нь 30)" 'Цахилгаан тасрах, хүчээр унтраах зэрэг олон шалтгаантай. Энэ нь PSU эсвэл hardware эвдэрснийг шууд батлахгүй.' 'Гэнэтийн унтралт / системийн тогтворжилт оношлуулах' }
    else { Finding 'system' 'info' 'Гэнэтийн унтралтын түүх' 'Сүүлийн 7 хоногт Kernel-Power 41 харагдсангүй' 'Зөвхөн хадгалагдсан System event log-ийг шалгасан.' }
}
Check 'security' 'PUA хамгаалалт' {
    $p=Get-MpPreference -ErrorAction Stop
    if($null -eq $p.PUAProtection) { throw 'No PUA state' }
    $value=[int]$p.PUAProtection
    if($value -eq 1) { Finding 'security' 'ok' 'Хүсээгүй програмын хамгаалалт' 'Defender PUA blocking асаалттай' }
    else { Finding 'security' 'info' 'Хүсээгүй програмын хамгаалалт' "Defender PUA mode: $value" '0=унтраалттай, 2=audit. Өөр антивирус ашигладаг бол түүний тохиргоог шалгана. Энэ тохиргоо нь хүсээгүй програм илэрсэн гэсэн үг биш.' }
}
Emit @{kind='complete';value=100;steps=$script:step}
