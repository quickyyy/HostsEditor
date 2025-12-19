param(
    [string]$BaseUrl = "https://raw.githubusercontent.com/quickyyy/HostsEditor/refs/heads/master"
)

$ErrorActionPreference = 'Stop'

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Administrator privileges are required to install to System32."
    Write-Warning "Please run PowerShell as Administrator."
    exit 1
}

$TargetDir = "$env:SystemRoot\System32"
$Files = @("hosts.cmd", "hosts.ps1")

Write-Host "Installing Hosts Editor..." -ForegroundColor Cyan

foreach ($file in $Files) {
    $url = "$BaseUrl/$file"
    $dest = Join-Path $TargetDir $file
    try {
        Write-Host "Downloading $file..."
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
    } catch {
        Write-Error "Failed to download $file from $url. Error: $_"
        exit 1
    }
}

$BackupDir = Join-Path $TargetDir "hosts_backups"
if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir | Out-Null
    Write-Host "Created backup directory: $BackupDir"
}

Write-Host "Installation successful!" -ForegroundColor Green
Write-Host "You can now use the 'hosts' command."
