@echo off
echo Generating game launchers from your config.json...
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\Create-Launchers.ps1"
echo.
echo Done.
