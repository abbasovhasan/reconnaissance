# --- File System Metadata Collector ---
# Collects metadata (no content) for recently accessed files.
# Automatically adapts to any user environment.
# ==================================================================

# --- EXECUTION POLICY BYPASS (SAFE) ---
try {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction Stop
    Write-Host "[+] ExecutionPolicy set to Bypass for this session."
}
catch {
    Write-Warning "[-] Could not set ExecutionPolicy (insufficient privileges). Continuing anyway..."
}

# --- CONFIGURATION ---
$UserName  = $env:USERNAME
$UserHome  = [Environment]::GetFolderPath('UserProfile')
$Desktop   = [Environment]::GetFolderPath('Desktop')

# --- OUTPUT DIRECTORY ---
# OPTION 1: Save results on user's Desktop
#$OutputDir = Join-Path $Desktop "Metadata_Collection_Results"

# OPTION 2: Save results to same drive/folder as script (recommended for USB use)
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$OutputDir = Join-Path $ScriptRoot "results"

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

# --- TARGET DIRECTORIES ---
$TargetDirs = @(
    (Join-Path $UserHome "Documents"),
    (Join-Path $UserHome "Desktop"),
    (Join-Path $UserHome "Downloads")
)

# --- TIME RANGE ---
$DaysBack = 7
$Cutoff   = (Get-Date).AddDays(-$DaysBack)

# --- RESULT HOLDER ---
$FileMetadata = @()

foreach ($Dir in $TargetDirs) {
    if (Test-Path $Dir) {
        try {
            Write-Host "Scanning: $Dir ..."
            $Files = Get-ChildItem -Path $Dir -Recurse -ErrorAction SilentlyContinue |
                     Where-Object { -not $_.PSIsContainer -and $_.LastAccessTime -ge $Cutoff }

            foreach ($f in $Files) {
                $FileMetadata += [PSCustomObject]@{
                    FileName       = $f.Name
                    FullPath       = $f.FullName
                    SizeKB         = [math]::Round($f.Length / 1KB, 2)
                    LastAccessTime = $f.LastAccessTime
                    LastWriteTime  = $f.LastWriteTime
                    CreationTime   = $f.CreationTime
                    Extension      = $f.Extension
                }
            }
        }
        catch {
            Write-Warning "Error scanning $Dir : $_"
        }
    } else {
        Write-Warning "Directory not found: $Dir"
    }
}

# --- OUTPUT JSON ---
if ($FileMetadata.Count -gt 0) {
    $JsonOutput = $FileMetadata | Sort-Object LastAccessTime -Descending | ConvertTo-Json -Depth 4
    $OutputFile = Join-Path $OutputDir ("filesystem_metadata_" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".json")
    $JsonOutput | Out-File -FilePath $OutputFile -Encoding UTF8
    Write-Host "[+] File system metadata saved to: $OutputFile"
} else {
    Write-Warning "[-] No recently accessed files found in the past $DaysBack days."
}

Write-Host "Script completed successfully."
