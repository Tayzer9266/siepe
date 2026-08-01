@echo off
REM ================================================================
REM Stop Mossy Review Queue Processor
REM Disables the automated investigation scheduled task
REM ================================================================

echo.
echo ========================================
echo Mossy Review Queue Processor - STOP
echo ========================================
echo.

schtasks /Change /TN "Mossy Review Queue Processor" /Disable

if %ERRORLEVEL% EQU 0 (
    echo [OK] Queue processor DISABLED
    echo.
    echo The processor has been stopped and will no longer run automatically.
    echo.
    echo Queue items will remain in "pending" status until you:
    echo   - Re-enable the processor with Start-MossyReview-Processor.bat
    echo   - OR manually invoke investigations with: @Mossy investigate task #ID
    echo.
    echo To restart: Run Start-MossyReview-Processor.bat
) else (
    echo [ERROR] Failed to disable queue processor
    echo.
    echo Possible causes:
    echo   1. Task not yet created - nothing to stop
    echo   2. Insufficient permissions - task name may be incorrect
    echo.
    echo Run this command to check task status:
    echo   Get-ScheduledTaskInfo -TaskName "Mossy Review Queue Processor"
)

echo.
pause
