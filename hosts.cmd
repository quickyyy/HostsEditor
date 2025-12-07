@echo off
setlocal

set "SCRIPT_DIR=%~dp0"

if not exist "%SCRIPT_DIR%hosts.ps1" (
    echo [ERROR] hosts.ps1 not found in %SCRIPT_DIR%
    exit /b 1
)

set "ACTION=%~1"
if "%ACTION%"=="" set "ACTION=list"

set "NEED_ADMIN=add remove toggle backup restore"
set "IS_ADMIN_REQ="
for %%A in (%NEED_ADMIN%) do (
    if /i "%%A"=="%ACTION%" set "IS_ADMIN_REQ=1"
)

if defined IS_ADMIN_REQ (
    net session >nul 2>&1
    if %errorlevel% neq 0 (
        echo [ERROR] The '%ACTION%' command requires Administrator privileges.
        echo Please run as Administrator.
        exit /b 1
    )
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "& '%SCRIPT_DIR%hosts.ps1' %*"
exit /b %errorlevel%
