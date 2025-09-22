@echo off
chcp 65001 >nul
echo Focus Game Deck - 設定エディタを起動しています...
cd /d "%~dp0"
powershell.exe -ExecutionPolicy Bypass -Command "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; $OutputEncoding = [System.Text.Encoding]::UTF8; & '.\ConfigEditor.ps1'"
pause