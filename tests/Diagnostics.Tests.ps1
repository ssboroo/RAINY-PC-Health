$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\src\Diagnostics.ps1" -FunctionsOnly
function Assert($Value,$Name) { if(!$Value) { throw "FAIL: $Name" } }
Assert ((Get-LicenseState $null) -eq 'unknown') 'Missing activation is unknown'
Assert ((Get-LicenseState 1) -eq 'ok') 'Licensed'
Assert ((Get-LicenseState 0) -eq 'warning') 'Unlicensed'
Assert ((Get-LicenseState 99) -eq 'unknown') 'Unexpected activation code'
Assert ((Get-DiskState $null) -eq 'unknown') 'Missing disk data'
Assert ((Get-DiskState 4.9) -eq 'critical') 'Critical disk threshold'
Assert ((Get-DiskState 5) -eq 'warning') 'Warning boundary'
Assert ((Get-DiskState 15) -eq 'ok') 'Healthy boundary'
Assert ((Get-DiskState -1) -eq 'unknown') 'Invalid disk metric'
Assert ((Get-DriverState 28) -eq 'warning') 'Missing driver'
Assert ((Get-DriverState 22) -eq 'info') 'Disabled device is not a missing driver'
Assert ((Get-DriverState $null) -eq 'unknown') 'Missing driver code'
$sample="Product: O365ProPlusRetail`nLicense State: Licensed`nEmail: private@example.invalid`nState: Notification"
$states=@(Get-VNextStates $sample)
Assert ($states.Count -eq 2 -and $states[0] -eq 'Licensed' -and $states[1] -eq 'Notification') 'vNext state parsing'
Assert (($states -join '') -notmatch '@|private') 'Account details not retained'
Assert (@(Get-VNextStates 'Unknown localized format').Count -eq 0) 'Unrecognized Office output is not guessed'
Write-Host 'PASS: 15 diagnostic classification and privacy assertions.'
