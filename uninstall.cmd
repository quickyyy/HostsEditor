@echo off
setlocal

echo Uninstalling hosts manager...

:: ─────────────────────────────────────────────
:: 1. Check for Administrator privileges
:: ─────────────────────────────────────────────
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] This uninstaller requires Administrator privileges.
    echo Please right-click and select "Run as administrator".
    pause
    exit /b 1
)

:: ─────────────────────────────────────────────
:: 2. Remove files from System32
:: ─────────────────────────────────────────────
echo Removing files from %SystemRoot%\System32...

if exist "%SystemRoot%\System32\hosts.cmd" (
    del /f /q "%SystemRoot%\System32\hosts.cmd"
    echo Removed hosts.cmd
) else (
    echo hosts.cmd not found.
)

if exist "%SystemRoot%\System32\hosts.ps1" (
    del /f /q "%SystemRoot%\System32\hosts.ps1"
    echo Removed hosts.ps1
) else (
    echo hosts.ps1 not found.
)

:: ─────────────────────────────────────────────
:: 3. Remove backup directory
:: ─────────────────────────────────────────────
set "BACKUP_DIR=%SystemRoot%\System32\hosts_backups"

if exist "%BACKUP_DIR%" (
    echo.
    echo Found backup directory: %BACKUP_DIR%
    set /p "DEL_BACKUPS=Do you want to delete the backup directory and all backups? (Y/N): "
    
    if /i "%DEL_BACKUPS%"=="Y" (
        rmdir /s /q "%BACKUP_DIR%"
        echo Removed backup directory.
    ) else (
        echo Backup directory kept.
    )
)

echo.
echo Uninstallation complete.
pause
