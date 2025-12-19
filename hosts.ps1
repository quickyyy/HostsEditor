param(
    [string]$Action = "list",
    [string]$Arg1 = "",
    [string]$Arg2 = ""
)

$ErrorActionPreference = 'Stop'
$HostsPath = Join-Path $env:SystemRoot "System32\drivers\etc\hosts"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$BackupsDir = Join-Path $ScriptDir "hosts_backups"

# Ensure backup directory exists
if (-not (Test-Path $BackupsDir)) { 
    New-Item -ItemType Directory -Path $BackupsDir | Out-Null 
}

class HostEntry {
    [string]$IP
    [System.Collections.Generic.List[string]]$Domains
    [string]$Comment
    [bool]$IsActive
    [string]$RawLine
    [bool]$IsParsed

    HostEntry([string]$line) {
        $this.RawLine = $line
        $this.Domains = [System.Collections.Generic.List[string]]::new()
        $this.Parse()
    }

    [void]Parse() {
        if ([string]::IsNullOrWhiteSpace($this.RawLine)) { 
            $this.IsParsed = $false
            return 
        }

        $trimmed = $this.RawLine.Trim()
        $this.IsActive = -not $trimmed.StartsWith("#")
        
        $working = $trimmed
        if (-not $this.IsActive) {
            $working = $working.TrimStart('#').Trim()
        }

        if ([string]::IsNullOrWhiteSpace($working)) { 
            $this.IsParsed = $false
            return 
        }

        $parts = $working -split "#", 2
        $entryPart = $parts[0].Trim()
        if ($parts.Length -gt 1) { 
            $this.Comment = $parts[1].Trim() 
        }

        if ([string]::IsNullOrWhiteSpace($entryPart)) { 
            $this.IsParsed = $false
            return 
        }

        $fields = $entryPart -split "\s+"
        if ($fields.Length -ge 2) {
            $this.IP = $fields[0]
            for ($i = 1; $i -lt $fields.Length; $i++) {
                $this.Domains.Add($fields[$i])
            }
            $this.IsParsed = $true
        } else {
            $this.IsParsed = $false
        }
    }

    [string]ToString() {
        if (-not $this.IsParsed) { return $this.RawLine }

        $line = "$($this.IP)`t$($this.Domains -join ' ')"
        if (-not [string]::IsNullOrWhiteSpace($this.Comment)) {
            $line += " # $($this.Comment)"
        }

        if (-not $this.IsActive) {
            return "# $line"
        }
        return $line
    }
}

function Get-HostsContent {
    return Get-Content -Path $HostsPath -Raw -Encoding UTF8 -Force
}

function Get-HostsLines {
    $content = Get-HostsContent
    if ($null -eq $content) { return @() }
    return $content -split "`r?`n"
}

function Backup-Hosts {
    $ts = (Get-Date).ToString("yyyyMMdd_HHmmss")
    $dest = Join-Path $BackupsDir ("hosts_backup_$ts")
    Copy-Item -Path $HostsPath -Destination $dest -Force
    return $dest
}

function Restore-Hosts([string]$file) {
    if (-not (Test-Path $file)) { 
        $fileInDir = Join-Path $BackupsDir $file
        if (Test-Path $fileInDir) {
            $file = $fileInDir
        } else {
            throw "Backup not found: $file" 
        }
    }
    Copy-Item -Path $file -Destination $HostsPath -Force
}

function List-Rules {
    $lines = Get-HostsLines
    foreach ($line in $lines) {
        $entry = [HostEntry]::new($line)
        if ($entry.IsParsed) {
            $domains = $entry.Domains -join " "
            $output = "{0,-15} {1}" -f $entry.IP, $domains
            if ($entry.IsActive) {
                Write-Host $output -ForegroundColor Green
            } else {
                Write-Host "# $output" -ForegroundColor DarkYellow
            }
        } elseif (-not [string]::IsNullOrWhiteSpace($line) -and $line.Trim().StartsWith("#")) {
             # Write-Host $line -ForegroundColor Gray 
        }
    }
}

function Search-Rules($query) {
    $lines = Get-HostsLines
    $found = $false
    foreach ($line in $lines) {
        if ($line -match [regex]::Escape($query)) {
            $found = $true
            Write-Host $line
        }
    }
    if (-not $found) { Write-Host "No matches for '$query'." -ForegroundColor Yellow }
}

function Add-Rule($ip, $domain) {
    if (-not $ip -or -not $domain) { throw "Usage: hosts add <ip> <domain>" }
    
    # Check for duplicates
    $lines = Get-HostsLines
    foreach ($line in $lines) {
        $entry = [HostEntry]::new($line)
        if ($entry.IsParsed -and $entry.IP -eq $ip -and $entry.Domains -contains $domain) {
            Write-Host "Entry already exists: $line" -ForegroundColor Yellow
            return
        }
    }

    $newLine = "$ip`t$domain"
    $content = Get-HostsContent
    
    if ($content -and -not $content.EndsWith("`n")) {
        "`r`n" | Out-File -FilePath $HostsPath -Encoding UTF8 -Append -NoNewline
    }

    $newLine | Out-File -FilePath $HostsPath -Encoding UTF8 -Append
    Write-Host "Added: $newLine" -ForegroundColor Green
}

function Remove-Rule($domain) {
    if (-not $domain) { throw "Usage: hosts remove <domain>" }
    
    $lines = Get-HostsLines
    $newLines = @()
    $removed = $false

    foreach ($line in $lines) {
        $entry = [HostEntry]::new($line)
        
        if ($entry.IsParsed -and $entry.Domains -contains $domain) {
            $entry.Domains.Remove($domain) | Out-Null
            $removed = $true
            
            if ($entry.Domains.Count -gt 0) {
                $newLines += $entry.ToString()
            }
        } else {
            $newLines += $line
        }
    }

    if ($removed) {
        $newLines -join "`r`n" | Out-File -FilePath $HostsPath -Encoding UTF8
        Write-Host "Removed domain: $domain" -ForegroundColor Green
    } else {
        Write-Host "Domain not found: $domain" -ForegroundColor Yellow
    }
}

function Toggle-Rule($domain) {
    if (-not $domain) { throw "Usage: hosts toggle <domain>" }

    $lines = Get-HostsLines
    $newLines = @()
    $toggled = $false

    foreach ($line in $lines) {
        $entry = [HostEntry]::new($line)

        if ($entry.IsParsed -and $entry.Domains -contains $domain) {
            $toggled = $true
            
            if ($entry.Domains.Count -eq 1) {
                $entry.IsActive = -not $entry.IsActive
                $newLines += $entry.ToString()
            } 
            else {
                
                # Remove target from current entry list
                $entry.Domains.Remove($domain) | Out-Null
                
                # Create new entry for the target domain
                $newEntry = [HostEntry]::new("")
                $newEntry.IP = $entry.IP
                $newEntry.Domains = [System.Collections.Generic.List[string]]::new()
                $newEntry.Domains.Add($domain)
                $newEntry.IsActive = -not $entry.IsActive # Toggle state
                $newEntry.IsParsed = $true
                
                # Add the remaining domains (original line modified)
                $newLines += $entry.ToString()
                # Add the new toggled domain
                $newLines += $newEntry.ToString()
            }
        } else {
            $newLines += $line
        }
    }

    if ($toggled) {
        $newLines -join "`r`n" | Out-File -FilePath $HostsPath -Encoding UTF8
        Write-Host "Toggled domain: $domain" -ForegroundColor Green
    } else {
        Write-Host "Domain not found: $domain" -ForegroundColor Yellow
    }
}

try {
    switch ($Action.ToLower()) {
        "list"    { List-Rules }
        "search"  { if (-not $Arg1) { throw "search requires <string>" } else { Search-Rules $Arg1 } }
        "add"     { Add-Rule $Arg1 $Arg2 }
        "remove"  { Remove-Rule $Arg1 }
        "toggle"  { Toggle-Rule $Arg1 }
        "backup"  { $f = Backup-Hosts; Write-Host "Backup saved to: $f" -ForegroundColor Cyan }
        "restore" { 
            if (-not $Arg1) { throw "restore requires <backup-file>" } 
            Restore-Hosts $Arg1
            Write-Host "Restored from $Arg1" -ForegroundColor Cyan 
        }
        default   { 
            Write-Host "Hosts Editor" -ForegroundColor Cyan
            Write-Host "Usage: hosts <action> [args]"
            Write-Host "Actions: list, add, remove, toggle, search, backup, restore"
        }
    }
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}
