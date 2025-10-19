# Recon Tool (Simple)

A small reconnaissance toolset. Python scripts were packaged into a Windows executable with PyInstaller. The executable runs a PowerShell (`.ps1`) helper/script as part of its workflow.

> **Note:** This repository contains tools intended for authorized security testing and learning. Do **not** use them on systems you do not own or do not have explicit permission to test.

## What it does
- Runs pre-built reconnaissance scripts (Python → PyInstaller → .exe).
- Triggers a PowerShell helper script (`.ps1`) when executed.
- Collects basic target information (configurable within the scripts).

## Requirements
- Windows 10/11 (or compatible Windows host)
- PowerShell (built-in)
- If you want to rebuild from source:
  - Python 3.8+ installed
  - PyInstaller
  - Any Python dependencies listed in the script(s)

## Usage
1. **Run the packaged executable** (recommended):
   - Double-click the `.exe` or run from command line:
     ```powershell
     .\recon-tool.exe
     ```
   - The EXE will call the included PowerShell script as needed.

2. **Run the PowerShell script directly** (if needed):
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\helper-script.ps1
