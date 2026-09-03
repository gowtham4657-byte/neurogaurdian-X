@echo off
setlocal

set "PORT=%~1"
set "FQBN=%~2"
if "%FQBN%"=="" set "FQBN=esp32:esp32:esp32s3"
set "SKETCH_DIR=%~dp0"
if "%SKETCH_DIR:~-1%"=="\" set "SKETCH_DIR=%SKETCH_DIR:~0,-1%"

if "%PORT%"=="" (
  echo Usage: upload_esp32_firmware.bat COM_PORT [FQBN]
  echo Example: upload_esp32_firmware.bat COM3
  echo Example for classic ESP32: upload_esp32_firmware.bat COM8 esp32:esp32:esp32
  exit /b 1
)

where arduino-cli >nul 2>nul
if errorlevel 1 (
  set "PATH=%ProgramFiles%\Arduino CLI;%LOCALAPPDATA%\Programs\Arduino CLI;%PATH%"
)

arduino-cli version
if errorlevel 1 exit /b 1

echo Compiling NeuroGuardian X firmware for %FQBN%...
arduino-cli compile --fqbn %FQBN% "%SKETCH_DIR%"
if errorlevel 1 exit /b 1

echo Uploading to %PORT%...
arduino-cli upload -p %PORT% --fqbn %FQBN% "%SKETCH_DIR%"
if errorlevel 1 (
  echo.
  echo Upload failed. If your ESP32 has a BOOT button, hold BOOT while upload starts,
  echo then release BOOT when you see "Connecting..." or upload progress.
  exit /b 1
)

echo.
echo Upload complete. Open the NeuroGuardian X app and connect to NeuroGuardianX.

