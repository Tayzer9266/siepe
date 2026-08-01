@echo off
REM ============================================
REM Stop Mossy Review ADO Monitoring System
REM ============================================
REM This disables the scheduled task (does not delete it)

echo.
echo ========================================
echo Stopping Mossy Review Monitoring
echo ========================================
echo.

schtasks /Change /TN "Mossy Review ADO Monitor" /Disable

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [SUCCESS] Mossy Review monitoring is now DISABLED
    echo.
    echo The scheduled task will no longer run automatically.
    echo The task still exists and can be re-enabled with Start-MossyReview.bat
    echo.
    echo To verify:
    echo   Get-ScheduledTask -TaskName "Mossy Review ADO Monitor"
    echo.
    echo To re-enable later:
    echo   Double-click Start-MossyReview.bat
    echo.
) else (
    echo.
    echo [ERROR] Failed to disable monitoring task
    echo Check if the scheduled task exists with:
    echo   Get-ScheduledTask -TaskName "Mossy Review ADO Monitor"
    echo.
)

pause
