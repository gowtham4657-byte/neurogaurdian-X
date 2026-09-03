$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$webRoot = Join-Path $root "build\web"
$port = 8765
$url = "http://127.0.0.1:$port"

function Test-PortOpen {
  param([int]$Port)
  $client = New-Object System.Net.Sockets.TcpClient
  try {
    $result = $client.BeginConnect("127.0.0.1", $Port, $null, $null)
    if (-not $result.AsyncWaitHandle.WaitOne(250)) { return $false }
    $client.EndConnect($result)
    return $true
  } catch {
    return $false
  } finally {
    $client.Close()
  }
}

function Find-Browser {
  $paths = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
  )
  foreach ($path in $paths) {
    if ($path -and (Test-Path $path)) { return $path }
  }
  return $null
}

if (-not (Test-Path $webRoot)) {
  Write-Host "Release web build missing. Run: ..\flutter_sdk_backup\bin\flutter.bat build web --release"
  exit 1
}

if (-not (Test-PortOpen -Port $port)) {
  $python = (Get-Command py -ErrorAction SilentlyContinue)
  if ($python) {
    Start-Process -FilePath $python.Source -ArgumentList @("-3", "-m", "http.server", "$port", "--bind", "127.0.0.1") -WorkingDirectory $webRoot -WindowStyle Hidden
  } else {
    $python = Get-Command python -ErrorAction Stop
    Start-Process -FilePath $python.Source -ArgumentList @("-m", "http.server", "$port", "--bind", "127.0.0.1") -WorkingDirectory $webRoot -WindowStyle Hidden
  }
  Start-Sleep -Seconds 2
}

$browser = Find-Browser
if ($browser) {
  Start-Process -FilePath $browser -ArgumentList @("--app=$url", "--user-data-dir=$root\.app_profile")
} else {
  Start-Process $url
}
