
function Remove-GhostNetAdapter {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [switch]$UseAdvancedReset,
        [string]$ExportLogPath
    )

    $logEntries = @()

    Write-Host "Cleaning up ghost (non-present) network adapters..." -ForegroundColor Cyan
    $env:devmgr_show_nonpresent_devices = 1

    # Get hidden (non-present) network adapters
    $hiddenAdapters = Get-PnpDevice -Class Net | Where-Object { $_.Status -eq "Unknown" }

    if ($hiddenAdapters.Count -eq 0) {
        Write-Host "No hidden adapters found." -ForegroundColor Green
    }
    else {
        foreach ($adapter in $hiddenAdapters) {
            $instanceId = $adapter.InstanceId
            $friendlyName = $adapter.FriendlyName
            Write-Host "Removing: $friendlyName" -ForegroundColor Yellow

            $logEntry = [PSCustomObject]@{
                Timestamp    = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                Adapter      = $friendlyName
                InstanceId   = $instanceId
                RegistryKeys = @()
            }

            try {
                if ($PSCmdlet.ShouldProcess("Adapter $friendlyName", "Disable device")) {
                    Disable-PnpDevice -InstanceId $instanceId -Confirm:$false -ErrorAction SilentlyContinue
                }

                if ($PSCmdlet.ShouldProcess("Adapter $friendlyName", "Remove device")) {
                    $removalResult = & pnputil /remove-device "$instanceId"
                    if ($LASTEXITCODE -ne 0) {
                        Write-Host "Failed to remove $friendlyName via pnputil" -ForegroundColor Red
                    }
                    else {
                        Write-Host "Removed $friendlyName via pnputil" -ForegroundColor Green
                    }
                }
            }
            catch {
                Write-Host "Could not remove $friendlyName" -ForegroundColor Red
            }

            # Clean registry entries
            $connectionBase = "HKLM:\SYSTEM\ControlSet001\Control\Network\{4D36E972-E325-11CE-BFC1-08002BE10318}"
            $networkCardsBase = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkCards"

            $subKeys = Get-ChildItem -Path $connectionBase -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer }

            foreach ($subKey in $subKeys) {
                $adapterGuid = $subKey.PSChildName
                $connectionKeyPath = "$connectionBase\$adapterGuid\Connection"

                if (Test-Path $connectionKeyPath) {
                    try {
                        $pnpId = (Get-ItemProperty -Path $connectionKeyPath -ErrorAction SilentlyContinue).PnPInstanceID
                        if ($pnpId -and $pnpId -eq $instanceId) {

                            if ($PSCmdlet.ShouldProcess("Registry key $connectionBase\$adapterGuid", "Remove")) {
                                $logEntry.RegistryKeys += "$connectionBase\$adapterGuid"
                                Remove-Item -LiteralPath "$connectionBase\$adapterGuid" -Recurse -Force -ErrorAction SilentlyContinue
                            }

                            # Delete corresponding NetworkCards key
                            $netCardKeys = Get-ChildItem $networkCardsBase -ErrorAction SilentlyContinue
                            foreach ($cardKey in $netCardKeys) {
                                $svcName = (Get-ItemProperty -Path $cardKey.PSPath -ErrorAction SilentlyContinue).ServiceName
                                if ($svcName -and $svcName -eq $adapterGuid) {
                                    if ($PSCmdlet.ShouldProcess("Registry key $cardKey.PSPath", "Remove")) {
                                        $logEntry.RegistryKeys += $cardKey.PSPath
                                        Remove-Item -LiteralPath $cardKey.PSPath -Recurse -Force -ErrorAction SilentlyContinue
                                    }
                                }
                            }
                        }
                    }
                    catch {
                        Write-Host "Error processing $connectionKeyPath" -ForegroundColor Red
                    }
                }
            }

            $logEntries += $logEntry
        }
    }

    # Export log if path is specified
    if ($ExportLogPath) {
        $exportDir = Split-Path -Parent $ExportLogPath
        if (-not (Test-Path $exportDir)) {
            Write-Host "Export path directory does not exist: $exportDir" -ForegroundColor Red
            return
        }
        try {
            $logEntries | ConvertTo-Json -Depth 4 | Out-File -FilePath $ExportLogPath -Encoding UTF8
            Write-Host "`nExported log to: $ExportLogPath" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to write log to $ExportLogPath" -ForegroundColor Red
        }
    }

    # Step 3: Reset Network Stack
    Write-Host "`nPerforming network reset..." -ForegroundColor Cyan

    if ($UseAdvancedReset) {
        $confirm = Read-Host "Advanced reset will generate trace logs in %LOCALAPPDATA%\Temp\NetTraces. Continue? (Y/N)"
        if ($confirm -match '^[Yy]$') {
            try {
                if ($PSCmdlet.ShouldProcess("Network stack", "Run advanced network reset")) {
                    netsh trace diagnose scenario=NetworkReset | Out-Null
                    Write-Host "Advanced network reset complete. Logs saved. Reboot recommended." -ForegroundColor Green
                }
            }
            catch {
                Write-Host "Failed to run advanced reset." -ForegroundColor Red
            }
        }
        else {
            Write-Host "Skipped advanced reset by user choice." -ForegroundColor Yellow
        }
    }
    else {
        try {
            if ($PSCmdlet.ShouldProcess("Network stack", "Run standard network reset")) {
                netsh int ip reset | Out-Null
                ipconfig /flushdns | Out-Null
                Write-Host "Standard network reset complete. Reboot recommended." -ForegroundColor Green
            }
        }
        catch {
            Write-Host "Failed to perform standard reset." -ForegroundColor Red
        }
    }
}

Export-ModuleMember -Function Remove-GhostNetAdapter
