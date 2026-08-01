@echo off
REM ============================================
REM Start Mossy Review ADO Monitoring System
REM ============================================
REM This enables the scheduled task that runs every 2 minutes

echo.
echo ========================================
echo Starting Mossy Review Monitoring
echo ========================================
echo.

schtasks /Change /TN "Mossy Review ADO Monitor" /Enable

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [SUCCESS] Mossy Review monitoring is now ENABLED
    echo.
    echo The system will check for new work items every 2 minutes.
    echo Maximum 2 concurrent reviews will be processed.
    echo.
    echo To verify:
    echo   Get-ScheduledTask -TaskName "Mossy Review ADO Monitor"
    echo.
    echo To test immediately:
    echo   Start-ScheduledTask -TaskName "Mossy Review ADO Monitor"
    echo.
) else (
    echo.
    echo [ERROR] Failed to enable monitoring task
    echo Check if the scheduled task exists with:
    echo   Get-ScheduledTask -TaskName "Mossy Review ADO Monitor"
    echo.
)

pause
