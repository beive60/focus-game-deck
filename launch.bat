@echo off
setlocal

:: --- Configuration ---
:: Set the path to the main PowerShell script
set "SCRIPT_PATH=src\Invoke-FocusGameDeck.ps1"
:: -------------------

echo Select the game to launch:
echo.

:: Read game IDs from config.json.sample and create a menu
:: NOTE: This is a simple parser. It works if the format is consistent.
set "CONFIG_FILE=config\config.json.sample"
set /a count=0
for /f "tokens=2 delims=:," %%a in ('findstr /r /c:"\"name\":" %CONFIG_FILE%') do (
    set /a count+=1
    set "game_name_!count!=%%~a"
    for /f "tokens=2 delims={, " %%b in ('find /i "steamAppId" %%a') do (
       set "game_id_!count!=%%b"
    )
    call echo !count!. %%game_name_!count!%%
)
echo.

:choice
set /p "CHOICE=Enter number: "
if not defined CHOICE (goto choice)

:: Validate user input
if %CHOICE% GTR %count% (
    echo Invalid number. Please try again.
    goto choice
)
if %CHOICE% LSS 1 (
    echo Invalid number. Please try again.
    goto choice
)

:: Get the corresponding GameId
call set "GAME_ID=%%game_id_!CHOICE!%%"

echo.
echo Launching %GAME_ID%...
echo.

:: Execute the PowerShell script with the selected GameId
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PATH%" -GameId %GAME_ID%

echo.
echo The script has finished. Press any key to exit.
pause > nul
