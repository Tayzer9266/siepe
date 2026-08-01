@echo off
REM ================================================================
REM Start Mossy Review Queue Processor
REM Enables the automated investigation scheduled task
REM ================================================================

echo.
echo ========================================
echo Mossy Review Queue Processor - START
echo ========================================
echo.

schtasks /Change /TN "Mossy Review Queue Processor" /Enable

if %ERRORLEVEL% EQU 0 (
    echo [OK] Queue processor ENABLED
    echo.
    echo The processor will now run every 5 minutes automatically.
    echo It will investigate pending work items and post assessments to ADO.
    echo.
    echo To stop: Run Stop-MossyReview-Processor.bat
) else (
    echo [ERROR] Failed to enable queue processor
    echo.
    echo Possible causes:
    echo   1. Task not yet created - run Setup-MossyReview-Processor.ps1 first
    echo   2. Insufficient permissions - task name may be incorrect
    echo.
    echo Run this command to check if task exists:
    echo   Get-ScheduledTask -TaskName "Mossy Review Queue Processor"
)

echo.
pause
