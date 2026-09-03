param(
  [Parameter(Mandatory = $true)]
  [string] $BackendUrl,

  [string] $BackendToken = ""
)

$ErrorActionPreference = "Stop"

$app = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$envPath = Join-Path $app "backend\.env"
$adb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"

if (!(Test-Path -LiteralPath $adb)) {
  throw "ADB was not found at $adb"
}

if (!$BackendToken -and (Test-Path -LiteralPath $envPath)) {
  foreach ($line in Get-Content -LiteralPath $envPath) {
    if ($line -match "^\s*NGX_DEVICE_TOKEN\s*=\s*(.+)\s*$") {
      $BackendToken = $matches[1].Trim().Trim('"').Trim("'")
      break
    }
  }
}

$BackendUrl = $BackendUrl.Trim().TrimEnd("/")
if (!$BackendUrl.StartsWith("https://") -and !$BackendUrl.StartsWith("http://")) {
  throw "BackendUrl must start with https:// or http://"
}

Write-Output "Checking connected Android device..."
$devices = & $adb devices
$devices | Write-Output
$connectedDevice = $devices | Where-Object { $_ -match "\tdevice$" } | Select-Object -First 1
if (!$connectedDevice) {
  throw "No Android phone is connected. Connect USB debugging, unlock the phone, and allow the computer."
}

Write-Output "Checking backend health from phone..."
$health = & $adb shell "curl -sS --connect-timeout 10 $BackendUrl/health"
if ($LASTEXITCODE -ne 0 -or $health -notmatch '"ok"\s*:\s*true') {
  throw "The phone could not reach $BackendUrl/health. Check mobile data/Wi-Fi and the Render service."
}
$health | Write-Output

Write-Output "Saving hidden backend settings inside the app..."
& $adb shell am force-stop com.neuroguardian.neuroguardian_app | Out-Null
& $adb shell am start `
  -n com.neuroguardian.neuroguardian_app/.MainActivity `
  -a com.neuroguardian.neuroguardian_app.SET_EMERGENCY_CONFIG `
  --es backendUrl "$BackendUrl" `
  --es backendToken "$BackendToken" | Write-Output
if ($LASTEXITCODE -ne 0) {
  throw "Could not save backend settings inside the Android app."
}

Write-Output "Done. Phone app now points to $BackendUrl"
