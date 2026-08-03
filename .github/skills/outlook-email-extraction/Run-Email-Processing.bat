@echo off
REM ============================================================================
REM Run Outlook Email Processing Skill
REM ============================================================================
REM This script triggers the automated email processing workflow:
REM 1. Scans C:\source\Outlook\emails\ for .eml files
REM 2. Parses emails and analyzes screenshots
REM 3. Invokes Mossy investigations
REM 4. Creates Azure DevOps work items
REM 5. Archives processed emails
REM ============================================================================

echo.
echo ============================================================================
echo   Outlook Email Processing - Automated Workflow
echo ============================================================================
echo.

REM Define email folders
set EMAIL_FOLDER=C:\source\Outlook\emails
set ARCHIVE_FOLDER=%EMAIL_FOLDER%\Archive

echo [1/3] Checking folder structure...

REM Create email folder if it doesn't exist
if not exist "%EMAIL_FOLDER%" (
    echo Creating email folder: %EMAIL_FOLDER%
    mkdir "%EMAIL_FOLDER%"
    echo Folder created successfully.
) else (
    echo Email folder exists: %EMAIL_FOLDER%
)

REM Create archive folder if it doesn't exist
if not exist "%ARCHIVE_FOLDER%" (
    echo Creating archive folder: %ARCHIVE_FOLDER%
    mkdir "%ARCHIVE_FOLDER%"
    echo Archive folder created successfully.
) else (
    echo Archive folder exists: %ARCHIVE_FOLDER%
)

echo.
echo [2/3] Checking for emails to process...

REM Count .eml files
set EMAIL_COUNT=0
for %%f in ("%EMAIL_FOLDER%\*.eml") do set /a EMAIL_COUNT+=1

if %EMAIL_COUNT% equ 0 (
    echo.
    echo WARNING: No .eml files found in %EMAIL_FOLDER%
    echo.
    echo To use this skill:
    echo 1. Save emails as .eml files
    echo 2. Copy them to: %EMAIL_FOLDER%
    echo 3. Re-run this script
    echo.
    echo OR use in VS Code:
    echo - Say: "@Mossy process the emails"
    echo.
    pause
    exit /b 0
)

echo Found %EMAIL_COUNT% email(s) to process.

echo.
echo [3/3] Starting automated processing...
echo.
echo ============================================================================
echo.
echo INSTRUCTIONS:
echo.
echo This batch file prepares the environment. For full automation, use your
echo AI assistant to invoke the skill.
echo.
echo To process emails:
echo 1. Use Claude Desktop:
echo    "process the emails using outlook-email-extraction skill"
echo.
echo 2. Use GitHub Copilot in VS Code:
echo    "@workspace process the emails"
echo.
echo 3. Or run manual PowerShell processing (advanced)
echo.
echo The skill will:
echo - Parse all %EMAIL_COUNT% email(s)
echo - Analyze attachments with AI vision
echo - Investigate issues via database queries
echo - Create ADO work items with estimates
echo - Assign to you automatically
echo - Archive processed emails
echo.
echo ============================================================================
echo.
echo Press any key to open VS Code in the AdminTools folder...
pause >nul

REM Open VS Code in the AdminTools directory
cd /d "C:\source\MD\AdminTools"
code .

echo.
echo VS Code opened. Now invoke the skill via your AI assistant.
echo.
pause
