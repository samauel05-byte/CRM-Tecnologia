@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Autorizar-VLAN.ps1"
if errorlevel 1 pause
