@echo off
title OMNIX-Shield Launcher
cd /d "%~dp0"

:menu
cls
echo ========================================================
echo               OMNIX-SHIELD LAUNCHER
echo ========================================================
echo.
echo   [1] Start Background (Tray Icon)
echo   [2] Start Foreground (Console Debug)
echo   [3] Open Web Dashboard (Browser)
echo   [4] Check Status
echo   [5] Stop OMNIX-Shield
echo   [0] Exit
echo.
echo ========================================================
set /p choice="Pilih nomor (1-5, 0): "

if "%choice%"=="1" goto bg_tray
if "%choice%"=="2" goto foreground
if "%choice%"=="3" goto dashboard
if "%choice%"=="4" goto status
if "%choice%"=="5" goto stop
if "%choice%"=="0" exit
goto menu

:bg_tray
echo.
echo Starting OMNIX-Shield in background...
start "" wscript.exe "%~dp0start-hidden.vbs"
ping 127.0.0.1 -n 3 >nul
node start.js status
pause
goto menu

:foreground
echo.
echo Starting in foreground (Ctrl+C to stop)...
node index.js --port 20129 --no-tray
pause
goto menu

:dashboard
start http://127.0.0.1:20129/ui
goto menu

:status
echo.
node start.js status
pause
goto menu

:stop
echo.
node start.js stop
pause
goto menu
