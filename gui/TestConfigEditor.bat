@echo off
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "ConfigEditor.ps1"
pause