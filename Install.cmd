@echo off
setlocal
cd /d "%~dp0"
title claude-config setup
rem Downloaded ZIPs are marked "from the internet"; clear the mark so PowerShell will run the scripts.
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath %~dp0 -Recurse -File | Unblock-File" >nul 2>&1
where pwsh >nul 2>&1
if errorlevel 1 (
  echo Installing PowerShell 7 ...
  winget install -e --id Microsoft.PowerShell --accept-source-agreements --accept-package-agreements --silent
  set "PATH=%PATH%;%ProgramFiles%\PowerShell\7"
)
where pwsh >nul 2>&1 || (echo PowerShell 7 could not be installed. Install it from the Microsoft Store, then run this again. & pause & exit /b 1)
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup\setup.ps1" %*
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" echo Setup finished with problems ^(exit %RC%^). Scroll up to see what failed.
rem Keep the window open when double-clicked (no arguments).
if "%~1"=="" pause
exit /b %RC%
