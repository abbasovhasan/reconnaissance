# ==================================================================
# SafeNet AI - Network Flow Summary Collector (Portable)
# Captures lightweight flow metadata (no packet payloads)
# Saves output to 'results' folder
# ==================================================================

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# --- Step 1: Determine script folder safely ---
$scriptDir = if ($MyInvocation.MyCommand.Definition -and $MyInvocation.MyCommand.Definition.Trim() -ne "") {
    Split-Path -Parent $MyInvocation.MyCommand.Definition
} else {
    Get-Location
}

# --- Step 2: Create 'results' folder if missing ---
$resultsDir = Join-Path $scriptDir "results"
if (-not (Test-Path $resultsDir)) {
    New-Item -ItemType Directory -Path $resultsDir | Out-Null
    Write-Host "[+] Created results folder: $resultsDir" -ForegroundColor Green
}

# --- CONFIGURATION ---
$SampleDurationSeconds = 60   # How long to observe live flows (if using Get-NetTCPConnection snapshots)
$CollectInterfaceStats = $true

# --- FUNCTION: Get Active TCP/UDP Flows ---
function Get-NetworkFlows {
    $tcp = Get-NetTCPConnection -ErrorAction SilentlyContinue | ForEach-Object {
        [PSCustomObject]@{
            Protocol      = "TCP"
            LocalAddress  = $_.LocalAddress
            LocalPort     = $_.LocalPort
            RemoteAddress = $_.RemoteAddress
            RemotePort    = $_.RemotePort
            State         = $_.State
            Direction     = if ($_.OwningProcess -eq $PID) {"Outbound"} else {"Unknown"}
            ProcessId     = $_.OwningProcess
            ProcessName   = (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName
            Timestamp     = (Get-Date)
        }
    }

    $udp = Get-NetUDPEndpoint -ErrorAction SilentlyContinue | ForEach-Object {
        [PSCustomObject]@{
            Protocol      = "UDP"
            LocalAddress  = $_.LocalAddress
            LocalPort     = $_.LocalPort
            RemoteAddress = "-"
            RemotePort    = "-"
            State         = "-"
            Direction     = "Unknown"
            ProcessId     = $_.OwningProcess
            ProcessName   = (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName
            Timestamp     = (Get-Date)
        }
    }

    return $tcp + $udp
}

# --- FUNCTION: Summarize Interface Traffic ---
function Get-InterfaceStats {
    Get-NetAdapterStatistics -ErrorAction SilentlyContinue | ForEach-Object {
        [PSCustomObject]@{
            Interface   = $_.Name
            BytesSent   = $_.SentBytes
            BytesRecv   = $_.ReceivedBytes
            PacketsSent = $_.SentUnicastPackets
            PacketsRecv = $_.ReceivedUnicastPackets
            Timestamp   = (Get-Date)
        }
    }
}

# --- CAPTURE SNAPSHOT(S) ---
Write-Host "Collecting network flow metadata for $SampleDurationSeconds seconds..."
$AllFlows = @()
$Start = Get-Date

while ((Get-Date) -lt $Start.AddSeconds($SampleDurationSeconds)) {
    $AllFlows += Get-NetworkFlows
    Start-Sleep -Seconds 5
}

# --- REMOVE DUPLICATES (same 5-tuple within 1-minute window) ---
$AllFlows = $AllFlows |
    Sort-Object LocalAddress,LocalPort,RemoteAddress,RemotePort,Protocol,Timestamp -Unique

# --- INCLUDE INTERFACE STATS IF ENABLED ---
if ($CollectInterfaceStats) {
    $IfaceStats = Get-InterfaceStats
} else {
    $IfaceStats = @()
}

# --- COMBINE EVERYTHING ---
$Result = [PSCustomObject]@{
    Hostname       = $env:COMPUTERNAME
    CaptureTime    = (Get-Date)
    DurationSec    = $SampleDurationSeconds
    FlowCount      = $AllFlows.Count
    Flows          = $AllFlows
    InterfaceStats = $IfaceStats
}

# --- OUTPUT CLEAN JSON ---
if ($AllFlows.Count -gt 0 -or $IfaceStats.Count -gt 0) {
    $OutputFile = Join-Path $resultsDir ("network_flows_" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".json")
    $Result | ConvertTo-Json -Depth 6 | Out-File -FilePath $OutputFile -Encoding UTF8
    Write-Host "[+] Network flow summary saved to: $OutputFile" -ForegroundColor Green
} else {
    Write-Warning "No network flow data collected."
}
