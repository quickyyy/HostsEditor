param(
    [string]$Action = "list",
    [string]$Arg1 = "",
    [string]$Arg2 = ""
)

$HostsPath = Join-Path $env:SystemRoot "System32\drivers\etc\hosts"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$BackupsDir = Join-Path $ScriptDir "hosts_backups"
if (-not (Test-Path $BackupsDir)) { New-Item -ItemType Directory -Path $BackupsDir | Out-Null }

function Timestamp() { (Get-Date).ToString("yyyyMMdd_HHmmss") }

function Backup-Hosts {
    $ts = Timestamp
    $dest = Join-Path $BackupsDir ("hosts_backup_$ts")
    Copy-Item -Path $HostsPath -Destination $dest -Force
    return $dest
}

function Restore-Hosts([string]$file) {
    if (-not (Test-Path $file)) { throw "Backup not found: $file" }
    Copy-Item -Path $file -Destination $HostsPath -Force
}

function Read-HostsLines {
    Get-Content -Path $HostsPath -Raw -ErrorAction Stop -Encoding UTF8 -Force |
        ForEach-Object { $_ -split "`r?`n" }
}

function Parse-Line([string]$line) {
    $trim = $line.Trim()
    if ($trim -eq "") { return @{Raw=$line; IsEmpty=$true} }

    $active = -not ($trim.StartsWith("#"))
    $working = $trim
    if (-not $active) { $working = $trim.Substring(1).Trim() }

    $comment = ""
    $parts = $working -split "\s+#\s*",2
    if ($parts.Count -ge 2) { $working = $parts[0].Trim(); $comment = $parts[1].Trim() }

    $fields = $working -split "\s+"
    if ($fields.Count -ge 2) {
        $ip = $fields[0]
        $domains = $fields[1..($fields.Count-1)]
        return @{Raw=$line; Active=$active; IP=$ip; Domains=$domains; Comment=$comment}
    } else {
        return @{Raw=$line; Active=$active; Unknown=$true}
    }
}

function ColorWrite($text, $colorCode) {
    $esc = [char]27
    Write-Host "$esc[$colorCode$text$esc[0m" -NoNewline
    Write-Host ""
}

function List-Rules {
    $lines = Read-HostsLines
    foreach ($l in $lines) {
        $p = Parse-Line $l
        if ($p.IsEmpty) { continue }
        if ($p.Unknown) { Write-Host $p.Raw; continue }
        if ($p.Active) {
            $ip = $p.IP
            $domains = ($p.Domains -join " ")
            Write-Host ("{0,-15} {1}" -f $ip, $domains) -ForegroundColor Green
        } else {
            $ip = ($p.IP -as [string])
            $domains = if ($p.Domains) { $p.Domains -join " " } else { "" }
            Write-Host ("# {0,-15} {1}" -f $ip, $domains) -ForegroundColor DarkYellow
        }
    }
}

function Search-Rules($query) {
    $lines = Read-HostsLines
    $found = $false
    foreach ($l in $lines) {
        if ($l -match [regex]::Escape($query)) {
            $found = $true
            Write-Host $l
        }
    }
    if (-not $found) { Write-Host "No matches for '$query'." -ForegroundColor Yellow }
}

function Add-Rule($ip, $domain) {
    if (-not $ip -or -not $domain) { throw "add requires <ip> <domain>" }
    $lines = Get-Content $HostsPath -ErrorAction Stop
    
    foreach ($line in $lines) {
        $p = Parse-Line $line
        if ($p.IP -eq $ip -and $p.Domains -contains $domain) {
            Write-Host "Entry already exists." -ForegroundColor Yellow
            return
        }
    }
    
    $content = Get-Content $HostsPath -Raw -ErrorAction SilentlyContinue
    if ($content -and -not $content.EndsWith("`n")) {
        "`r`n" | Out-File -FilePath $HostsPath -Encoding UTF8 -Append -NoNewline
    }

    "$ip`t$domain" | Out-File -FilePath $HostsPath -Encoding UTF8 -Append
    Write-Host "Added $ip $domain" -ForegroundColor Green
}

function Remove-Rule($domain) {
    if (-not $domain) { throw "remove requires <domain>" }
    $lines = Read-HostsLines
    $new = @()
    $removed = $false
    foreach ($l in $lines) {
        if ($l -match "\b$([regex]::Escape($domain))\b") {
            $p = Parse-Line $l
            if ($p.Domains) {
                $remain = $p.Domains | Where-Object { $_ -ne $domain }
                if ($remain.Count -eq 0) {
                    $removed = $true
                    continue
                } else {
                    $newline = ($p.IP + " " + ($remain -join " "))
                    if (-not $p.Active) { $newline = "# " + $newline }
                    $new += $newline
                    $removed = $true
                    continue
                }
            } else {
                $removed = $true
                continue
            }
        } else {
            $new += $l
        }
    }
    if ($removed) {
        $new -join "`r`n" | Out-File -FilePath $HostsPath -Encoding UTF8
        Write-Host "Removed domain: $domain" -ForegroundColor Green
    } else {
        Write-Host "Domain not found: $domain" -ForegroundColor Yellow
    }
}

function Toggle-Rule($domain) {
    if (-not $domain) { throw "toggle requires <domain>" }
    $lines = Read-HostsLines
    $new = @()
    $changed = $false
    foreach ($l in $lines) {
        if ($l -match "\b$([regex]::Escape($domain))\b") {
            if ($l.TrimStart().StartsWith("#")) {
                $new += $l.TrimStart().Substring(1).TrimStart()
            } else {
                $new += ("# " + $l)
            }
            $changed = $true
        } else {
            $new += $l
        }
    }
    if ($changed) {
        $new -join "`r`n" | Out-File -FilePath $HostsPath -Encoding UTF8
        Write-Host "Toggled: $domain" -ForegroundColor Green
    } else {
        Write-Host "Domain not found: $domain" -ForegroundColor Yellow
    }
}

try {
    switch ($Action.ToLower()) {
        "list" { List-Rules }
        "search" { if (-not $Arg1) { throw "search requires <string>" } else { Search-Rules $Arg1 } }
        "add" { Add-Rule $Arg1 $Arg2 }
        "remove" { Remove-Rule $Arg1 }
        "toggle" { Toggle-Rule $Arg1 }
        "backup" { $f = Backup-Hosts; Write-Host "Backup saved to: $f" -ForegroundColor Cyan }
        "restore" { if (-not $Arg1) { throw "restore requires <backup-file>" } else { Restore-Hosts $Arg1; Write-Host "Restored from $Arg1" -ForegroundColor Cyan } }
        default { Write-Host "Unknown action: $Action" -ForegroundColor Red }
    }
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}
