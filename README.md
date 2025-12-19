# Hosts Editor

A simple, lightweight command-line tool for managing the Windows `hosts` file. Built with Batch and PowerShell.

## Features

- **List**: View all active and inactive (commented) entries.
- **Add**: Add new IP-domain mappings.
- **Remove**: Remove entries by domain.
- **Toggle**: Enable or disable entries without deleting them.
- **Search**: Find specific entries.
- **Backup & Restore**: Safely backup your hosts file and restore when needed.

## Installation

### Quick Install (PowerShell)
Run the following command in PowerShell as Administrator:
```powershell
irm https://raw.githubusercontent.com/quickyyy/HostsEditor/main/install.ps1 | iex
```

### Manual Installation
1. Download the source code.
2. Right-click `install.cmd` and select **Run as administrator**.
3. The tool will be installed to your system path. You can now use the `hosts` command from any terminal (CMD, PowerShell).

## Usage

Open a terminal (CMD or PowerShell) as **Administrator** for commands that modify the file.

### List all entries
```bash
hosts list
```

### Add a new entry
```bash
hosts add 127.0.0.1 example.com
hosts add 0.0.0.0 ads.example.com
```

### Toggle an entry (Enable/Disable)
```bash
hosts toggle example.com
```

### Remove an entry
```bash
hosts remove example.com
```

### Search for an entry
```bash
hosts search google
```

### Backup and Restore
```bash
# Create a backup
hosts backup

# Restore from a specific backup file
hosts restore C:\Windows\System32\hosts_backups\hosts_backup_20230101_120000
```

## Uninstallation

1. Right-click `uninstall.cmd` and select **Run as administrator**.
2. Follow the prompts to remove the tool and optionally delete backups.
