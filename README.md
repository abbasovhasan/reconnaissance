# Reconnaissance and Data Collection Agent

This repository contains a set of scripts and binaries designed to perform system reconnaissance and collect data for security analysis. The collected information is exfiltrated to a central web application where it is processed and analyzed by an AI engine to assign a security score.

## Key Components and Functionality

The core functionality is centered around:

1.  **Persistence Mechanism:** Ensuring the agent runs upon system start or trigger.
2.  **Reconnaissance Scripts:** Collecting detailed system and network intelligence.
3.  **Data Exfiltration:** Securely transmitting collected data to the web server for AI analysis.

### Persistence Mechanism

| File Name | Description |
| :--- | :--- |
| `autorun.py` | The main Python source script for the agent logic. |
| `autorun.spec` | Specification file used by PyInstaller to bundle the script. |
| `autorun.exe` | The compiled Windows executable version of the agent. |
| `autorun.inf` | Configuration file, typically used on removable media for auto-execution, demonstrating a common persistence method. |

**Example Flow:** The `autorun.exe` (compiled from `autorun.py`) is configured to run automatically. Upon execution, it performs its primary function, such as triggering the data collection scripts. *As a demonstration, the current `autorun.py` is configured to run the `script_event_logs.ps1` file.*

### Reconnaissance PowerShell Scripts (`*.ps1`)

Each PowerShell script is meticulously designed to execute a specific reconnaissance task, gathering a piece of intelligence about the host machine:

| File Name | Reconnaissance Function |
| :--- | :--- |
| `script_browser_data.ps1` | Collects data from web browsers (e.g., history, cookies, credentials, depending on implementation). |
| `script_network_dhcp.ps1` | Collects current DHCP and network configuration information. |
| `script_network_dns.ps1` | Gathers DNS-related data, such as local DNS cache entries. |
| `script_event_logs.ps1` | Collects and filters critical Windows Event Log entries for security analysis. |
| `script_file_metadata.ps1` | Extracts file metadata from specific system directories or files. |
| `script_running_processes.ps1` | Gathers a list of all currently running processes and their properties. |
| `script_telemetry.ps1` | Collects general system or usage telemetry for behavioral analysis. |
| `script_usb_history.ps1` | Enumerates historical or currently connected USB devices. |

### Data Management and Analysis

| File Name | Description |
| :--- | :--- |
| `sqlite3.exe` | A lightweight, self-contained database engine used as a dependency to temporarily manage or aggregate the collected reconnaissance data before exfiltration. |

**AI Analysis & Scoring:**
The combined data from all reconnaissance files is securely sent to our central web platform. On the server side, an **Artificial Intelligence (AI)** engine analyzes this data. The AI scores the system's security posture and flags potential threats, with the final score and findings displayed within the web application.
