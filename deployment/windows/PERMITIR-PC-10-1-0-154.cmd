@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Autorizar-VLAN.ps1" -Red "10.1.0.154/32"
if errorlevel 1 pause
