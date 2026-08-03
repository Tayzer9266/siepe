@echo off
REM ================================================================
REM Fix Mossy Review ADO Monitor - Run as Administrator
REM ================================================================

echo.
echo ================================================================
echo FIXING MOSSY REVIEW AUTOMATION
echo ================================================================
echo.

REM Check for admin privileges
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo ERROR: This script must be run as Administrator
    echo.
    echo Right-click this file and select "Run as administrator"
    echo.
    pause
    exit /b 1
)

echo Running with Administrator privileges...
echo.

REM Run the setup script
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0Setup-MossyReview-Monitor.ps1'"

echo.
echo ================================================================
echo DONE!
echo ================================================================
echo.
echo The Mossy Review monitor is now configured to check every 2 minutes.
echo It will automatically investigate work items tagged "Mossy Review".
echo.
pause
