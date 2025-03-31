# PowerShell Cygwin Removal Script

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) <!-- Assuming you have a LICENSE file -->

A comprehensive PowerShell script designed to thoroughly remove a Cygwin installation from Windows. It handles the termination of Cygwin processes, removal of services, registry keys, environment variables, cache folders, Start Menu/Desktop shortcuts, LSA Authentication Package (`cyglsa`) cleanup, and deletion of the main installation directory. Features interactive prompts for safety and an optional silent mode with granular controls.

---

## 🚨🚨 EXTREME WARNING 🚨🚨

*   **HIGHLY DESTRUCTIVE:** This script PERMANENTLY deletes files, folders, Windows services, registry keys, and shortcuts associated with Cygwin. It **terminates running Cygwin processes** and can modify critical system settings like **LSA Authentication Packages**.
*   **PROCESS TERMINATION:** The script will attempt to forcefully terminate processes running from the Cygwin installation directory to release file locks before deletion. **Ensure any work in Cygwin applications (terminals, X servers, etc.) is saved.**
*   **LSA MODIFICATION & REBOOT:** If the `cyglsa` package is detected and removed from LSA (requiring user confirmation or specific silent flags), a **SYSTEM REBOOT IS MANDATORY** afterwards to ensure system stability and prevent login issues. This cleanup is typically only needed if you manually configured `cyglsa.dll` as per Cygwin documentation (unlikely).
*   **LSA/DIRECTORY DEPENDENCY:** If `cyglsa` is detected in the LSA registry, it **MUST** be successfully removed by this script (or manually beforehand) before the main Cygwin installation directory can be deleted by the script. Refusing or failing the LSA reset step will **BLOCK** the installation directory removal to prevent potential system instability.
*   **NO UNDO:** There is no built-in way to reverse the actions performed by this script.
*   **BACKUP YOUR DATA:** Before running, ensure any important data stored *within* your Cygwin environment (e.g., in `/home/your_user` if it's inside the main installation path) or any other critical data is backed up securely elsewhere. Consider saving your Cygwin mount points using `mount -m > my_mounts.txt` inside Cygwin if needed.
*   **RUN AS ADMINISTRATOR:** The script requires elevated privileges. It includes a check and will exit if not run as Administrator.
*   **USE AT YOUR OWN RISK:** Review the script code and understand its actions *before* execution. The responsibility for its use lies entirely with you.

---

## Features

*   ✅ **Administrator Check:** Ensures the script runs with necessary privileges.
*   ✅ **Path Detection:** Attempts to find the Cygwin installation directory (Registry, common paths) or allows manual specification.
*   ✅ **Process Termination:** Attempts to terminate running processes originating from the Cygwin installation path to release file locks (requires path detection).
*   ✅ **Service Removal:** Stops and **deletes** Windows services associated with the detected Cygwin installation (requires path detection).
*   ✅ **Registry Cleanup:** Removes standard Cygwin keys (`Software\Cygwin`) from `HKEY_LOCAL_MACHINE` and `HKEY_CURRENT_USER`.
*   ✅ **LSA Package Cleanup:** Detects and removes the `cyglsa` authentication package if present (interactive prompt or silent switch required). Includes critical safety checks and **enforces mandatory reboot** if changed.
*   ✅ **PATH Modification:** Removes Cygwin-related directories from System and User `PATH` environment variables (requires path detection).
*   ✅ **Cache Folder Removal:** Detects and removes potential Cygwin setup download cache folders from common user locations.
*   ✅ **Shortcut Removal:** Removes the `Cygwin` folder from common Start Menu locations and Cygwin-named `.lnk` files from common Desktop locations.
*   ✅ **Installation Directory Removal:** Deletes the main Cygwin installation folder (requires path detection AND successful LSA reset if `cyglsa` was registered).
*   ✅ **Interactive Mode (Default):** Prompts the user for confirmation before each major destructive action.
*   ✅ **Silent Mode:** Allows fully automated execution via command-line switches for scripted scenarios.
    *   Requires `-Silent` switch.
    *   Granular control via action switches (e.g., `-RemoveRegistryKeys`, `-ResetLsaPackages`).
    *   Convenience switch `-RemoveAllSafe` enables most removal actions.
    *   Implicit actions: `-RemoveInstallDir` automatically enables process termination, service removal, and path modification in silent mode.
*   ✅ **Robust Logic:** Key actions depend on successful path detection. LSA handling includes safety checks and blocks directory removal if LSA reset is needed but skipped/failed. Provides detailed verbose output (`-Verbose`).

---

## Prerequisites

*   Windows Operating System (Tested primarily on Windows 10/11, may work on others)
*   PowerShell (v3 or later recommended, typically included with modern Windows)
*   **Administrator Privileges** to execute the script.

---

## Installation

1.  Download the `Remove-Cygwin.ps1` script file to your local machine.
2.  **Strongly recommended:** Read the script and this README carefully to understand what it does.
3.  **BACK UP ANY IMPORTANT DATA** from your Cygwin installation or system.

---

## Usage

1.  **Open PowerShell as Administrator:**
    *   Press `Win + X` and choose "Windows PowerShell (Admin)" or "Terminal (Admin)".
    *   Alternatively, search for "PowerShell", right-click "Windows PowerShell", and select "Run as administrator".
2.  **Navigate to Script Directory:** Use the `cd` command (Change Directory) to go to the folder where you saved the script.
    ```powershell
    cd C:\path\to\your\scripts
    ```
3.  **(Optional) Adjust Execution Policy:** If script execution is disabled, you might need to bypass the policy for the current process:
    ```powershell
    # This allows the script to run only in this specific PowerShell window
    Set-ExecutionPolicy Bypass -Scope Process -Force
    ```
4.  **Run the Script:**

    *   **Interactive Mode (Recommended First Run):**
        ```powershell
        .\Remove-Cygwin.ps1 -Verbose
        ```
        *The script will attempt auto-detection and prompt before each major action. Pay close attention to LSA prompts.*

    *   **Interactive Mode (Manual Path):**
        ```powershell
        .\Remove-Cygwin.ps1 -CygwinPath "C:\your\custom\cygwin_location" -Verbose
        ```
        *Use this if auto-detection fails or you want to be explicit.*

    *   **Silent Mode (Use with Extreme Caution!):**
        *   Requires the `-Silent` switch *plus* one or more `-Remove*` or `-Reset*` switches.
        *   **No confirmation prompts will be shown.**
        *   **A reboot may be required without prompt if LSA is modified (`-ResetLsaPackages` or `-RemoveAllSafe`).**

        ```powershell
        # Example: Silently remove only registry keys and shortcuts
        .\Remove-Cygwin.ps1 -Silent -RemoveRegistryKeys -RemoveShortcuts

        # Example: Silently remove installation directory (and implicitly processes, services, path)
        # Requires path detection OR explicit -CygwinPath.
        # Will attempt LSA reset if cyglsa is found (MANDATORY REBOOT REQUIRED IF SO).
        .\Remove-Cygwin.ps1 -Silent -RemoveInstallDir -CygwinPath "C:\cygwin64" -Verbose

        # Example: Silently remove almost everything safely, including LSA reset if needed.
        # (MANDATORY REBOOT REQUIRED IF LSA WAS RESET).
        .\Remove-Cygwin.ps1 -Silent -RemoveAllSafe -Verbose

        # Example: Silently remove components EXCEPT LSA reset.
        # !!! Directory removal WILL FAIL if 'cyglsa' was registered !!!
        .\Remove-Cygwin.ps1 -Silent -RemoveInstallDir -RemoveRegistryKeys -RemoveServices -RemoveCacheFolders -ModifyPath -RemoveShortcuts -Verbose
        ```

5.  **Follow Prompts / Monitor Output:**
    *   **Interactive:** Carefully read prompts and respond (`y`/`n`).
    *   **Silent:** Monitor the console output for progress, warnings (Yellow), and errors (Red). Use `-Verbose` for more detail.
6.  **Restart:**
    *   If the script output indicates **LSA AUTHENTICATION PACKAGES WERE MODIFIED**, a **REBOOT IS MANDATORY**.
    *   Otherwise, a restart is still **strongly recommended** to ensure all file locks are released, PATH changes are effective system-wide, and service removals are fully completed.

---

## Parameters

*   `-CygwinPath <String>`
    *   Optional. Specify the full path to the Cygwin root installation directory (e.g., `"C:\cygwin64"`).
    *   Overrides auto-detection if the provided path is valid.
    *   Required for process termination, service removal, path modification, and installation directory removal if auto-detection fails.
*   `-Silent`
    *   **REQUIRED** to enable silent mode. Suppresses all interactive confirmation prompts.
    *   Must be used with one or more action switches (`-RemoveInstallDir`, `-RemoveAllSafe`).
*   `-RemoveInstallDir`
    *   *(Silent Mode)* Deletes the main Cygwin installation directory.
    *   **Depends on:** Path detection AND successful LSA reset (if `cyglsa` was registered).
    *   **Implies:** Enables `-TerminateProcesses`, `-RemoveServices`, and `-ModifyPath` automatically in silent mode.
*   `-RemoveRegistryKeys`
    *   *(Silent Mode)* Deletes standard Cygwin `Software\Cygwin` keys from HKLM and HKCU registry hives.
*   `-RemoveServices`
    *   *(Silent Mode)* Stops and deletes Cygwin services linked to the detected/provided path.
    *   **Depends on:** Path detection.
*   `-TerminateProcesses`
    *   *(Silent Mode)* Attempts to terminate processes running from the detected/provided Cygwin path.
    *   **Depends on:** Path detection.
    *   **Note:** This action is automatically implied (enabled) by `-RemoveInstallDir` or `-RemoveAllSafe` in silent mode. It is not typically needed as a standalone switch unless you *only* want to terminate processes silently without removing the directory.
*   `-RemoveCacheFolders`
    *   *(Silent Mode)* Deletes detected Cygwin download cache folders from common user profile locations (Downloads, Desktop, UserProfile root).
*   `-ModifyPath`
    *   *(Silent Mode)* Removes Cygwin entries from System and User PATH environment variables in the registry.
    *   **Depends on:** Path detection.
*   `-RemoveShortcuts`
    *   *(Silent Mode)* Removes the 'Cygwin' folder from common Start Menu program locations (All Users/Current User) AND Cygwin-named shortcuts (`*cygwin*.lnk`) from common Desktop locations (Public/Current User).
*   `-ResetLsaPackages`
    *   *(Silent Mode)* **CRITICAL!** Removes the `cyglsa` entry from LSA Authentication Packages registry value if found.
    *   **Results in a MANDATORY REBOOT if changes are made.**
    *   Necessary for `-RemoveInstallDir` to succeed if `cyglsa` was registered.
*   `-RemoveAllSafe`
    *   *(Silent Mode)* Convenience switch. Enables: `-RemoveInstallDir`, `-RemoveRegistryKeys`, `-RemoveServices`, `-RemoveCacheFolders`, `-ModifyPath`, `-RemoveShortcuts`, and `-ResetLsaPackages`.
    *   Actions requiring path detection only run if the path is found.
    *   Directory removal still depends on successful LSA reset if `cyglsa` was registered.
    *   Process termination is implicitly enabled.

---

## Important Notes & Safety

*   **LSA Sensitivity:** Modifying LSA is inherently risky. This script includes checks (e.g., ensuring core `msv1_0` package remains), but proceed with caution. The **mandatory reboot** after LSA changes is vital.
*   **LSA/Directory Dependency:** The script deliberately prevents deleting the main installation directory if `cyglsa` is found in LSA but the LSA reset step is skipped or fails. This is a key safety mechanism.
*   **Silent Mode Risks:** Double-check your switches when using `-Silent`. `-RemoveAllSafe` is powerful; understand its implications, especially the potential LSA reset and mandatory reboot.
*   **Testing:** If possible, test the script (especially silent operations involving LSA reset) on a non-critical virtual machine or test system first.
*   **Path Dependency:** Service/Process/Path/Install Dir actions rely on finding the Cygwin path. If not found automatically, you must provide it via `-CygwinPath`.

---

## Limitations

*   Does not remove user data stored *outside* the main Cygwin installation path (e.g., if `/home` was mounted elsewhere).
*   Only removes standard Cygwin registry keys (`Software\Cygwin`). Other related keys might exist.
*   Only removes specific common Start Menu/Desktop shortcuts. Others need manual removal.
*   Does not explicitly clean Cygwin-related files in user `%TEMP%` directories beyond the identified download cache.
*   Cannot guarantee removal of *every* trace, especially with highly customized setups or third-party Cygwin package integrations.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details. <!-- Make sure you have a LICENSE file -->
