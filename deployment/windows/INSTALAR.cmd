@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Instalar-CRM.ps1"
if errorlevel 1 pause
