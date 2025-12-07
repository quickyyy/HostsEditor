@echo off
setlocal

echo Installing hosts manager...

:: ─────────────────────────────────────────────
:: 1. Check for Administrator privileges
:: ─────────────────────────────────────────────
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] This installer requires Administrator privileges.
    echo Please right-click and select "Run as administrator".
    pause
    exit /b 1
)

:: ─────────────────────────────────────────────
:: 2. Copy files to System32
:: ─────────────────────────────────────────────
echo Copying files to %SystemRoot%\System32...

if not exist "%~dp0hosts.cmd" (
    echo [ERROR] hosts.cmd not found in source directory.
    pause
    exit /b 1
)
if not exist "%~dp0hosts.ps1" (
    echo [ERROR] hosts.ps1 not found in source directory.
    pause
    exit /b 1
)

copy /y "%~dp0hosts.cmd" "%SystemRoot%\System32\" >nul
if errorlevel 1 (
    echo [ERROR] Failed to copy hosts.cmd.
    pause
    exit /b 1
)

copy /y "%~dp0hosts.ps1" "%SystemRoot%\System32\" >nul
if errorlevel 1 (
    echo [ERROR] Failed to copy hosts.ps1.
    pause
    exit /b 1
)

:: ─────────────────────────────────────────────
:: 3. Create backup directory and initial backup
:: ─────────────────────────────────────────────
set "BACKUP_DIR=%SystemRoot%\System32\hosts_backups"

if not exist "%BACKUP_DIR%" (
    mkdir "%BACKUP_DIR%"
    echo Created backup directory: %BACKUP_DIR%
)

echo Creating initial backup of hosts file...

powershell -NoLogo -NoProfile -Command ^
    "$ts = Get-Date -Format 'yyyyMMdd_HHmmss'; " ^
    "$backupFile = Join-Path '%BACKUP_DIR%' ('hosts_initial_backup_' + $ts); " ^
    "Copy-Item -LiteralPath '%SystemRoot%\System32\drivers\etc\hosts' -Destination $backupFile -Force; " ^
    "Write-Host 'Saved initial backup to:' $backupFile"

if errorlevel 1 (
    echo [WARNING] Failed to create initial backup.
)

echo.
echo Installation complete.
echo You can now use the 'hosts' command from anywhere.
echo.
pause
