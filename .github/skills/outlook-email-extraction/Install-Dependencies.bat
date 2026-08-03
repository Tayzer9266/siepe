@echo off
REM ============================================================================
REM Install Dependencies for Outlook Email Extraction & Automated Processing
REM ============================================================================
REM This script installs all required dependencies for the email processing skill
REM - Azure CLI
REM - Azure DevOps CLI extension
REM - Microsoft Graph PowerShell module
REM - Required PowerShell modules
REM ============================================================================

echo.
echo ============================================================================
echo   Installing Dependencies for Email Processing Skill
echo ============================================================================
echo.

REM Check if running as Administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script must be run as Administrator
    echo Right-click and select "Run as administrator"
    pause
    exit /b 1
)

echo [1/5] Checking Azure CLI installation...
az version >nul 2>&1
if %errorLevel% neq 0 (
    echo Azure CLI not found. Installing...
    echo Please download and install Azure CLI from:
    echo https://aka.ms/installazurecliwindows
    echo.
    echo After installation, re-run this script.
    pause
    exit /b 1
) else (
    echo Azure CLI is already installed.
    az version
)

echo.
echo [2/5] Installing Azure DevOps CLI extension...
call az extension add --name azure-devops --yes
if %errorLevel% neq 0 (
    echo WARNING: Failed to install Azure DevOps extension
    echo You may need to install it manually: az extension add --name azure-devops
) else (
    echo Azure DevOps extension installed successfully.
)

echo.
echo [3/5] Logging into Azure CLI...
echo Please sign in with your Azure/ADO credentials...
call az login
if %errorLevel% neq 0 (
    echo WARNING: Azure login failed. You can login later with: az login
) else (
    echo Azure login successful.
)

echo.
echo [4/5] Configuring Azure DevOps defaults...
call az devops configure --defaults organization=https://siepe.visualstudio.com project=Siepe.Software
if %errorLevel% neq 0 (
    echo WARNING: Failed to set ADO defaults. You can set them manually.
) else (
    echo Azure DevOps defaults configured.
)

echo.
echo [5/5] Installing PowerShell modules...
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { Write-Host 'Installing Microsoft.Graph module...' -ForegroundColor Cyan; if (!(Get-Module -ListAvailable -Name Microsoft.Graph)) { Install-Module -Name Microsoft.Graph -Scope CurrentUser -Force -AllowClobber; Write-Host 'Microsoft.Graph installed.' -ForegroundColor Green } else { Write-Host 'Microsoft.Graph already installed.' -ForegroundColor Green }; Write-Host 'Installing Microsoft.Graph.Mail module...' -ForegroundColor Cyan; if (!(Get-Module -ListAvailable -Name Microsoft.Graph.Mail)) { Install-Module -Name Microsoft.Graph.Mail -Scope CurrentUser -Force -AllowClobber; Write-Host 'Microsoft.Graph.Mail installed.' -ForegroundColor Green } else { Write-Host 'Microsoft.Graph.Mail already installed.' -ForegroundColor Green } }"

echo.
echo ============================================================================
echo   Installation Complete!
echo ============================================================================
echo.
echo Next steps:
echo 1. Create folder structure (will auto-create on first run):
echo    - C:\source\Outlook\emails\
echo    - C:\source\Outlook\emails\Archive\
echo.
echo 2. Drop .eml email files into C:\source\Outlook\emails\
echo.
echo 3. Run the processing:
echo    - Double-click Run-Email-Processing.bat
echo    - OR say "@Mossy process the emails" in VS Code
echo.
echo ============================================================================
pause
