# Remove-Cygwin 🧹

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**A robust PowerShell script to completely uninstall Cygwin.**

Uninstalling Cygwin involves Windows Services, Registry keys, Environment Variables, and potentially active Authentication Packages (`cyglsa`) that can break your system login if removed incorrectly.

**Remove-Cygwin** handles these dependencies for you, offering a safe **Interactive Mode** for humans and a strict **Silent Mode** for automation.

---

## ⚠️ Critical Safety Warnings

**Please read this before running the script.**

1.  **🚫 No Undo:** Files, registry keys, and shortcuts are deleted permanently.
2.  **🔐 LSA & Rebooting:** If you installed the `cyglsa` package (common with SSHD setups), this script will remove it. **You MUST reboot your computer immediately after the script finishes.** Failure to reboot can cause Windows login failures.
    *   *Safety Feature:* The script will **refuse** to delete the main Cygwin directory if it detects `cyglsa` is active but was not successfully reset.
3.  **💾 Back Up Data:** Any data stored *inside* your Cygwin folder (e.g., `C:\cygwin64\home\yourname`) will be destroyed. Move important files elsewhere first.
4.  **🛑 Running Processes:** The script will forcefully close any programs running *from* the Cygwin directory to release file locks. Save your work.
5.  **👤 Single User Cleanup:** Shortcuts and registry keys are cleaned for the **current user** and the **System** only. It does not clean the "Desktop" of other users on the machine.

---

## 🚀 Quick Start (Interactive)

For most users, Interactive Mode is best. It auto-detects your Cygwin installation and asks for permission before every major deletion step.

1.  **Download** `Remove-Cygwin.ps1`.
2.  **Open PowerShell as Administrator** (Right-click Start -> Terminal (Admin)).
3.  **Allow script execution** (if you haven't before):
    ```powershell
    Set-ExecutionPolicy Bypass -Scope Process -Force
    ```
4.  **Run the script:**
    ```powershell
    .\Remove-Cygwin.ps1 -Verbose
    ```
5.  **Follow the prompts.**
6.  **Reboot your computer.**

---

## 🤖 Silent Mode (Automation)

For sysadmins or automated setups. Silent mode suppresses all prompts. You must explicitly provide flags to tell the script what to do.

> **Note:** Silent mode implies `-Force`. It will kill processes and delete files without asking.

### Common Examples

**1. The "Clean Sweep" (Recommended)**
Removes everything. Checks for LSA, cleans Registry, Path, Services, and Files.
```powershell
.\Remove-Cygwin.ps1 -Silent -RemoveAllSafe
```
*If `cyglsa` was modified, the script output will demand a reboot.*

**2. Remove Specific Components Only**
To clean just the Registry and Shortcuts (keeping the files):
```powershell
.\Remove-Cygwin.ps1 -Silent -RemoveRegistryKeys -RemoveShortcuts
```

**3. Manual Path Definition**
If auto-detection fails, or you have multiple installations:
```powershell
.\Remove-Cygwin.ps1 -Silent -RemoveAllSafe -CygwinPath "D:\DevTools\Cygwin"
```

---

## ⚙️ Parameters

| Parameter | Description |
| :--- | :--- |
| **`-Silent`** | Enables silent operation. Requires specific action switches below. |
| **`-CygwinPath <String>`** | Optional. Overrides auto-detection. E.g., `"C:\cygwin64"`. |
| **`-RemoveAllSafe`** | **(Silent)** Activates all removal steps. Actions requiring a path (Services, Files) only run if a valid Cygwin path is found. |
| **`-RemoveInstallDir`** | **(Silent)** Deletes the main folder. *Implies* `-TerminateProcesses`, `-RemoveServices`, and `-ModifyPath`. |
| **`-RemoveRegistryKeys`** | **(Silent)** Deletes `HKLM\Software\Cygwin` and `HKCU\Software\Cygwin`. |
| **`-RemoveServices`** | **(Silent)** Stops and deletes Cygwin-related Windows Services (e.g., `sshd`, `cron`). |
| **`-ModifyPath`** | **(Silent)** Removes Cygwin directories from System and User `PATH` variables. |
| **`-ResetLsaPackages`** | **(Silent)** Removes `cyglsa` from the LSA Registry. **Reboot Mandatory.** |
| **`-RemoveShortcuts`** | **(Silent)** Deletes Cygwin shortcuts from Start Menu and Desktop. |
| **`-RemoveCacheFolders`** | **(Silent)** Deletes Cygwin package download cache folders (e.g., in Downloads). |

---

## 🔍 How It Works (Under the Hood)

1.  **Detection:** Looks for Cygwin in Registry keys and common paths (`C:\cygwin64`, `C:\cygwin`).
2.  **Services:** Queries Windows services (`Win32_Service`) looking for binaries located inside the Cygwin path. Stops them, then runs `sc delete`.
3.  **Processes:** Scans for running processes. To ensure safety, it only kills processes whose `.Path` property starts with the Cygwin directory.
4.  **LSA Protection:** Checks `HKLM\SYSTEM\CurrentControlSet\Control\Lsa`.
    *   If `cyglsa` is found, it removes it while preserving standard Windows packages (`msv1_0`).
    *   **Safety Lock:** If LSA cleanup fails or is refused by the user, the script **blocks** the deletion of the `bin` folder to prevent system instability.
5.  **Path Variable:** Parses `HKLM` and `HKCU` environment variables and strictly filters out paths belonging to Cygwin.

---

## 📝 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
