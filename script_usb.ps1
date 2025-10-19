# ==================================================================
# SafeNet AI - USB Device Connection Log Collector (Portable)
# Collects attach/detach events from Windows Event Logs
# Saves output to 'results' folder
# ==================================================================

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# --- Step 1: Determine script folder safely ---
$scriptDir = if ($MyInvocation.MyCommand.Definition -and $MyInvocation.MyCommand.Definition.Trim() -ne "") {
    Split-Path -Parent $MyInvocation.MyCommand.Definition
} else {
    Get-Location
}
Write-Host "[*] Using directory for results: $scriptDir" -ForegroundColor Cyan

# --- Step 2: Create 'results' folder if missing ---
$resultsDir = Join-Path $scriptDir "results"
if (-not (Test-Path $resultsDir)) {
    New-Item -ItemType Directory -Path $resultsDir | Out-Null
}

# --- CONFIGURATION ---
$DaysBack = 14
$Cutoff = (Get-Date).AddDays(-$DaysBack)

# --- EVENT SOURCES AND IDS ---
$EventFilters = @{
    "Microsoft-Windows-DriverFrameworks-UserMode/Operational" = @(20001, 21001)
    "Microsoft-Windows-Partition/Diagnostic"                   = @(1006, 1007)
    "System"                                                   = @(43)
}

# --- RESULT HOLDER ---
$USBEvents = @()

foreach ($log in $EventFilters.Keys) {
    $ids = $EventFilters[$log]
    try {
        $events = Get-WinEvent -FilterHashtable @{
            LogName   = $log
            Id        = $ids
            StartTime = $Cutoff
        } -ErrorAction SilentlyContinue

        foreach ($e in $events) {
            $Xml = [xml]$e.ToXml()

            # Extract device details
            $device = ($Xml.Event.EventData.Data | Where-Object {$_.Name -eq 'DeviceInstanceId'}).'#text'
            if (-not $device) { $device = ($Xml.Event.EventData.Data | Select-Object -First 1).'#text' }

            $friendly = ($e.Message -replace "`r`n",' ' -replace '\s{2,}',' ').Trim()

            $USBEvents += [PSCustomObject]@{
                TimeCreated = $e.TimeCreated
                EventID     = $e.Id
                LogName     = $log
                DeviceID    = $device
                Message     = $friendly
            }
        }
    }
    catch {
    }
}

# --- OUTPUT JSON ---
if ($USBEvents.Count -gt 0) {
    $OutputFile = Join-Path $resultsDir ("usb_activity_" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".json")
    $USBEvents | Sort-Object TimeCreated -Descending | ConvertTo-Json -Depth 4 | Out-File -FilePath $OutputFile -Encoding UTF8
} else {
}
