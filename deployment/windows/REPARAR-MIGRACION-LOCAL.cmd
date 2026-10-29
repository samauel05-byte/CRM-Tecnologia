@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Reparar-Migracion-Local.ps1"
if errorlevel 1 pause
