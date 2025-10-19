import os
import subprocess
from pathlib import Path
import sys

def main():
    # --- 1. Exe və ya script-in yerləşdiyi qovluğu dinamik tapırıq ---
    if getattr(sys, 'frozen', False):
        # PyInstaller ilə exe olarsa
        base_path = Path(sys.executable).parent.resolve()
    else:
        # Normal Python script olarsa
        base_path = Path(__file__).parent.resolve()

    print(f"Running from: {base_path}")

    # --- 2. Altında olan script_event_logs.ps1 faylının yolu ---
    ps_script = base_path / "script_event_logs.ps1"

    if not ps_script.exists():
        print(f"Error: Target script not found: {ps_script}")
        return

    # --- 3. PowerShell ilə icra et ---
    ps_command = [
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", str(ps_script)
    ]

    try:
        subprocess.run(ps_command, check=True)
        print("script_event_logs.ps1 successfully executed.")
    except subprocess.CalledProcessError as e:
        print("PowerShell execution failed:", e)
        return

if __name__ == "__main__":
    main()
