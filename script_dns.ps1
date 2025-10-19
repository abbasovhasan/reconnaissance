<#
.SYNOPSIS
  Collect DNS Client lookup logs and export them to structured, beautified JSON.
  Automatically enables DNS Client Operational log if disabled.
  Works on any computer and saves output to a "results" subfolder.
#>

# --- Step 1: Automatically allow script execution for this session ---
try {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction Stop
} catch {
    Write-Warning "[-] Unable to set execution policy. You may need to run as Administrator."
}

# --- Step 2: Predefined parameters ---
$LogName = "Microsoft-Windows-DNS-Client/Operational"
$StartTime = (Get-Date).AddDays(-7)
$EndTime = Get-Date

# Determine output folder (same as script or current working dir)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-not $scriptDir) { $scriptDir = Get-Location }

# Create "results" folder if it doesn’t exist
$resultsDir = Join-Path $scriptDir "results"
if (-not (Test-Path $resultsDir)) {
    New-Item -ItemType Directory -Path $resultsDir | Out-Null
}

# Generate timestamped filename inside results folder
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$OutputPath = Join-Path $resultsDir ("dns-client-logs-$Timestamp.json")


# --- Step 3: Check if the log is enabled ---
try {
    $logStatus = wevtutil get-log $LogName | Select-String "enabled"
    if ($logStatus -match "false") {
        wevtutil set-log $LogName /enabled:true
        Start-Sleep -Seconds 2
    } else {
    }
} catch {
    exit 1
}

# --- Step 4: Query event logs ---
$filter = @{
    LogName   = $LogName
    StartTime = $StartTime
    EndTime   = $EndTime
}

try {
    $events = Get-WinEvent -FilterHashtable $filter -ErrorAction Stop
} catch {
    exit 1
}

# --- Step 5: If no events found, exit silently ---
if (-not $events -or $events.Count -eq 0) {
    return
}

# --- Step 6: Convert event to structured object (no RawXml) ---
function Convert-EventToObject {
    param($evt)

    $obj = [PSCustomObject]@{
        TimeCreated      = $evt.TimeCreated.ToUniversalTime().ToString("o")
        LogName          = $evt.LogName
        ProviderName     = $evt.ProviderName
        Id               = $evt.Id
        LevelDisplayName = $evt.LevelDisplayName
        RecordId         = $evt.RecordId
        MachineName      = $evt.MachineName
        Message          = ($evt.Message -replace "`r`n", " ")
        ParsedFields     = @{}
    }

    try {
        $xml = [xml]$evt.ToXml()
        $ns = @{ev='http://schemas.microsoft.com/win/2004/08/events/event'}
        $dataNodes = $xml.SelectNodes("//ev:Event/ev:EventData/ev:Data", $ns)

        if ($dataNodes -and $dataNodes.Count -gt 0) {
            $fields = @{}
            foreach ($n in $dataNodes) {
                if ($n.Attributes['Name']) {
                    $name = $n.Attributes['Name'].Value
                } else {
                    $name = $null
                }

                if ($name) {
                    $fields[$name] = $n.'#text'
                } else {
                    $idx = ($fields.Keys.Count + 1)
                    $fields["Data$idx"] = $n.'#text'
                }
            }
            $obj.ParsedFields = $fields
        }
    } catch {
        # Ignore XML parse errors
    }

    return $obj
}

# --- Step 7: Process and export beautified JSON ---
$allObjects = @()

foreach ($e in $events) {
    $allObjects += Convert-EventToObject -evt $e
}

$allObjects | ConvertTo-Json -Depth 8 | Out-File -FilePath $OutputPath -Encoding UTF8


