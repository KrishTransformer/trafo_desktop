@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath PowerShell.exe -Verb RunAs -Wait -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','%~dp0Install-InvoiceApp.ps1'"
if errorlevel 1 (
  echo Installation was canceled or failed.
  pause
)
