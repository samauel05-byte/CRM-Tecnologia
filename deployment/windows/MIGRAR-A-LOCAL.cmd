@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Migrar-A-Local.ps1"
if errorlevel 1 pause
