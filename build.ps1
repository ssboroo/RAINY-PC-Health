param([switch]$SkipTests)
$ErrorActionPreference='Stop'
Set-Location $PSScriptRoot
New-Item -ItemType Directory -Force dist | Out-Null
$framework=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
if(!(Test-Path "$framework\csc.exe")) { $framework=Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319' }
$wpf=Join-Path $framework 'WPF'
if(!(Test-Path "$wpf\PresentationFramework.dll")) { throw '.NET Framework 4.8 with WPF is required.' }
# Reject PowerShell syntax errors before embedding the collector.
$tokens=$null;$errors=$null
[System.Management.Automation.Language.Parser]::ParseFile("$PSScriptRoot\src\Diagnostics.ps1",[ref]$tokens,[ref]$errors) | Out-Null
if($errors.Count) { throw ($errors | Out-String) }
& "$framework\csc.exe" /nologo /target:winexe /platform:anycpu /optimize+ /codepage:65001 /out:dist\RAINY-PC-Health.exe /win32icon:assets\rainy.ico /win32manifest:app.manifest /reference:System.dll /reference:System.Core.dll /reference:System.Web.Extensions.dll /reference:System.Xaml.dll "/reference:$wpf\WindowsBase.dll" "/reference:$wpf\PresentationCore.dll" "/reference:$wpf\PresentationFramework.dll" /resource:src\MainWindow.xaml,MainWindow.xaml /resource:src\Diagnostics.ps1,Diagnostics.ps1 /resource:assets\rainy.ico,rainy.ico src\Models.cs src\App.cs src\Tests.cs
if($LASTEXITCODE -ne 0) { throw "C# compilation failed: $LASTEXITCODE" }
if(!$SkipTests) {
    & "$PSScriptRoot\tests\Diagnostics.Tests.ps1"
    $p=Start-Process "$PSScriptRoot\dist\RAINY-PC-Health.exe" -ArgumentList '--self-test' -Wait -PassThru
    if($p.ExitCode -ne 0) { throw 'C# report tests failed.' }
}
$size=(Get-Item dist\RAINY-PC-Health.exe).Length
if($size -gt 2MB) { throw "Portable size budget exceeded: $size" }
Write-Host "Portable EXE: $size bytes. No installer, NuGet, Electron, or bundled runtime."
Get-FileHash dist\RAINY-PC-Health.exe -Algorithm SHA256 | Format-List
