<#
.SYNOPSIS
  Collect Event ID 4625 (Failed Logon) and 4674 (Privileged Service Call) logs
  from Security, Application, and System logs.
  Beautify and export structured JSON to a "results" subfolder.
#>
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

# --- Step 1: Automatically allow script execution for this session ---
try {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction Stop
} catch {}

# --- Step 2: Predefined parameters ---
$EventIDs   = @(4625, 4674)
$LogNames   = @("Security", "Application", "System")
$StartTime = (Get-Date).AddDays(-30)  # last 30 days
$EndTime    = Get-Date

# --- Step 3: Script folder and results folder ---
$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-not $scriptDir) { $scriptDir = Get-Location }

$resultsDir = Join-Path $scriptDir "results"
if (-not (Test-Path $resultsDir)) {
    New-Item -ItemType Directory -Path $resultsDir | Out-Null
}

# --- Step 4: Timestamp for file naming ---
$Timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")

# --- Step 5: Endpoint URI ---
$endpointUri = "https://backlify-v2.onrender.com/api/analysis"  # <-- Replace with your actual endpoint

# --- Step 6: Query event logs ---
$filter = @{
    LogName   = $LogNames
    Id        = $EventIDs
    StartTime = $StartTime
    EndTime   = $EndTime
}

try {
    $events = Get-WinEvent -FilterHashtable $filter -ErrorAction Stop
} catch {
    Write-Error "Failed to collect events: $_"
    exit 1
}

if (-not $events -or $events.Count -eq 0) {
    Write-Host "No events found."
    return
}

# --- Step 7: Convert event to structured object ---
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
        UserId           = if ($evt.UserId) { $evt.UserId.ToString() } else { $null }
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
                $name = if ($n.Attributes['Name']) { $n.Attributes['Name'].Value } else { $null }
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

# --- Step 8: Process events ---
$allObjects = @()
foreach ($e in $events) {
    $allObjects += Convert-EventToObject -evt $e
}

# --- Step 9: Convert to JSON ---
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$jsonBody = $allObjects | ConvertTo-Json -Depth 10 -Compress

# --- Step 10: Save JSON locally ---
$outFile = Join-Path $resultsDir "results_$Timestamp.json"
$jsonBody | Out-File -FilePath $outFile -Encoding UTF8

# --- Step 11: POST JSON to endpoint ---
try {
    $response = Invoke-RestMethod -Uri $endpointUri -Method Post -Body $jsonBody -ContentType "application/json" -ErrorAction Stop
    $respFile = Join-Path $resultsDir "response_$Timestamp.txt"
    ($response | Out-String) | Out-File -FilePath $respFile -Encoding UTF8
    Write-Host "POST successful, response saved to $respFile"
} catch {
    $errFile = Join-Path $resultsDir "error_$Timestamp.txt"
    $_ | Out-File -FilePath $errFile -Encoding UTF8
    Write-Host "POST failed, error saved to $errFile"
}
