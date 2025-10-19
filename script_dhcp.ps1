# --- Auto-set Execution Policy for the session ---
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# --- Define output path (same folder as script) ---
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-not $scriptDir) { $scriptDir = Get-Location }
$outputPath = Join-Path $scriptDir "dhcp_logs.json"

# --- DHCP Client log channel ---
$logName = "Microsoft-Windows-DHCP-Client/Operational"

# --- Ensure DHCP Client log is enabled ---
try {
    $logInfo = wevtutil get-log $logName 2>$null
    if ($logInfo -match "enabled:\s+false") {
        Write-Host "DHCP Client log is disabled. Enabling..."
        wevtutil set-log $logName /enabled:true
        Start-Sleep -Seconds 2
    }
} catch {
    Write-Host "Could not query or enable DHCP Client log. Exiting."
    exit
}

# --- Event IDs to collect ---
$eventIDs = @(500, 501, 502, 503, 505)

# --- Try getting events (safely) ---
try {
    $events = Get-WinEvent -LogName $logName -ErrorAction Stop | Where-Object { $eventIDs -contains $_.Id }
} catch {
    Write-Host "No DHCP events found. Exiting quietly."
    exit
}

# --- If no events, just exit silently ---
if (-not $events -or $events.Count -eq 0) {
    Write-Host "No DHCP events found. Exiting quietly."
    exit
}

# --- Parse events (excluding RawXML) ---
$parsedEvents = @()
foreach ($evt in $events) {
    $xml = [xml]$evt.ToXml()
    $data = @{}

    foreach ($n in $xml.Event.EventData.Data) {
        $nameAttr = $n.Attributes["Name"]
        if ($nameAttr) {
            $data[$nameAttr.Value] = $n."#text"
        } else {
            $data["Data"] = $n."#text"
        }
    }

    $parsedEvents += [PSCustomObject]@{
        TimeCreated = $evt.TimeCreated
        EventID     = $evt.Id
        Level       = $evt.LevelDisplayName
        Provider    = $evt.ProviderName
        Computer    = $evt.MachineName
        Message     = $evt.Message
        EventData   = $data
    }
}

# --- Beautify JSON and save ---
$jsonOutput = $parsedEvents | ConvertTo-Json -Depth 5 -Compress:$false
$jsonOutput | Out-File -FilePath $outputPath -Encoding UTF8

Write-Host $outputPath
