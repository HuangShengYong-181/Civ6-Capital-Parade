@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\InstallCloseCamera.ps1" -Restore
if errorlevel 1 pause
