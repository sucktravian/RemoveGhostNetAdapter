# RemoveGhostNetAdapter

**RemoveGhostNetAdapter** is a simple PowerShell module that helps you clean up "ghost" (non-present) network adapters from your system — including their leftover registry traces — and optionally resets your network stack to ensure a fresh start.

---

## What It Does

Windows sometimes leaves behind old network adapters when devices are removed, virtual switches are changed, or drivers are uninstalled. These ghost adapters can clutter Device Manager, cause odd naming like "Ethernet 2", and even lead to connectivity issues.

This module:

- Finds and removes ghost network adapters using `Get-PnpDevice`
- Cleans related entries from the registry
- Optionally performs a network reset (`netsh int ip reset` or advanced `netsh trace diagnose`)
- Can export a JSON log of all changes

---

## Installation

```powershell
Install-Module RemoveGhostNetAdapter
```

## How to use
```powershell
Remove-GhostNetAdapter [-UseAdvancedReset] [-ExportLogPath "C:\path\to\log.json"]
```
### Examples

```powershell
# Just remove ghost adapters
Remove-GhostNetAdapter

# Remove ghost adapters and save a log of what was cleaned up
Remove-GhostNetAdapter -ExportLogPath "$env:TEMP\cleanup_log.json"

# Do everything, including a full network stack reset
Remove-GhostNetAdapter -UseAdvancedReset

```

## Requirement

-Windows 10 or newer

-PowerShell 5.1+

-Must be run as Administrator

-Requires Get-PnpDevice (built-in on most modern systems)

## Testing

Run unit tests with Pester:
```Powershell
Invoke-Pester -Path tests
```

## License
Licensed under the MIT License