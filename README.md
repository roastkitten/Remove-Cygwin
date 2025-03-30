# Cygwin Removal Script (PowerShell)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A PowerShell script designed to thoroughly and carefully remove a Cygwin installation from Windows. It handles services, registry keys, environment variables, cache folders, Start Menu/Desktop shortcuts, LSA Authentication Package (`cyglsa`) cleanup, and the main installation directory. Includes interactive prompts for safety and an optional silent mode with granular controls.

## 🚨🚨 EXTREME WARNING 🚨🚨

*   **HIGHLY DESTRUCTIVE:** This script PERMANENTLY deletes files, folders, Windows services, registry keys, and shortcuts associated with Cygwin. It can also modify critical system settings like **LSA Authentication Packages**.
*   **LSA MODIFICATION & REBOOT:** If the `cyglsa` package is detected and removed from LSA, a **SYSTEM REBOOT IS MANDATORY** to ensure stability and prevent login issues. This should only occur If you installed cyglsa.dll by running the shell script /usr/bin/cyglsa-config as described in https://cygwin.com/cygwin-ug-net/ntsec.html
*   **LSA DEPENDENCY:** If `cyglsa` is detected, it **MUST** be successfully removed (requiring confirmation or specific silent flags) before the main Cygwin installation directory can be deleted by this script. Refusing or failing the LSA reset will block directory removal.
*   **NO UNDO:** There is no built-in way to reverse the actions performed by this script.
*   **BACKUP YOUR DATA:** Before running this script, ensure any important data stored *within* your Cygwin environment (e.g., in `/home/your_user`) or any data you cannot afford to lose is backed up securely elsewhere.
*   **RUN AS ADMINISTRATOR:** The script requires elevated privileges to modify system components. It includes a check and will exit if not run as Administrator.
*   **USE AT YOUR OWN RISK:** Review the script code and understand its actions *before* execution. While designed with safety checks (prompts, path dependencies, LSA handling), the responsibility for its use lies with you.

## Prerequisites

*   Windows Operating System
*   PowerShell (typically included with modern Windows versions)
*   **Administrator Privileges** to run the script.

## Usage

1.  **Download/Clone:** Obtain the `Remove-Cygwin.ps1` script (ensure you have the latest version).
2.  **Review:** Open the script in a text editor and understand what it does, especially the LSA handling sections. **BACK UP YOUR DATA!**
3.  **Open PowerShell as Administrator:**
    *   Search for "PowerShell".
    *   Right-click "Windows PowerShell".
    *   Select "Run as administrator".
4.  **Navigate to Script Directory:** Use the `cd` command to go to the folder where you saved the script.
    ```powershell
    cd C:\path\to\your\scripts
    ```
5.  **Execution Policy:** If you encounter an error about script execution being disabled, you may need to adjust the execution policy for this session:
    ```powershell
    # Temporarily allow script execution for this PowerShell process
    Set-ExecutionPolicy Bypass -Scope Process -Force
    ```
6.  **Run the Script:**

    *   **Interactive Mode (Recommended):**
        ```powershell
        .\Remove-Cygwin.ps1 -Verbose
        ```
        The script will attempt to find Cygwin and prompt you before each removal step (Services, Registry, LSA Reset, PATH, Cache, Shortcuts, Install Dir). Pay close attention to the LSA prompt if it appears. `-Verbose` provides extra detail.

    *   **Interactive Mode (Manual Path):**
        ```powershell
        .\Remove-Cygwin.ps1 -CygwinPath "C:\your\custom\cygwin_location" -Verbose
        ```

    *   **Silent Mode (Use with Extreme Caution!):** Requires the `-Silent` switch plus one or more action switches. **A reboot may be required without prompt if LSA is modified.**

        *   *Example: Remove only registry keys and shortcuts silently:*
            ```powershell
            .\Remove-Cygwin.ps1 -Silent -RemoveRegistryKeys -RemoveShortcuts
            ```
        *   *Example: Remove the installation directory silently (also attempts service/path/LSA removal if needed/applicable):*
            ```powershell
            # Requires path detection or explicit -CygwinPath
            # Will also attempt LSA reset if cyglsa is found
            # !!! REBOOT LIKELY REQUIRED if cyglsa was present !!!
            .\Remove-Cygwin.ps1 -Silent -RemoveInstallDir -CygwinPath "C:\cygwin64"
            ```
        *   *Example: Remove most components safely using `-RemoveAllSafe` (includes LSA reset):*
            ```powershell
            # This enables most removal actions, including LSA reset if cyglsa is found.
            # !!! REBOOT LIKELY REQUIRED if cyglsa was present !!!
            .\Remove-Cygwin.ps1 -Silent -RemoveAllSafe
            ```
        *   *Example: Silently remove components *except* LSA reset (Directory removal will fail if `cyglsa` was registered):*
            ```powershell
            .\Remove-Cygwin.ps1 -Silent -RemoveInstallDir -RemoveRegistryKeys -RemoveServices -RemoveCacheFolders -ModifyPath -RemoveShortcuts # Note: No -ResetLsaPackages or -RemoveAllSafe
            ```

7.  **Follow Prompts / Monitor Output:** If running interactively, carefully read and respond (`y`/`n`). If silent, monitor the output for errors or warnings.
8.  **Restart:** After the script finishes:
    *   If LSA packages were modified (script will state this clearly), a **REBOOT IS MANDATORY**.
    *   Otherwise, a restart is **strongly recommended** to ensure all other changes take full effect.

## Parameters

*   `-CygwinPath <String>`: Optional. Specify the full path to the Cygwin root installation directory (e.g., `"C:\cygwin64"`). Overrides auto-detection if valid. Actions like `-RemoveServices`, `-ModifyPath`, `-RemoveInstallDir` depend on a valid path.
*   `-Silent`: REQUIRED to enable silent mode. Suppresses all interactive confirmation prompts. Must be used with one or more action switches below.
*   `-RemoveInstallDir`: *(Silent Mode)* Deletes the main Cygwin directory. Requires path detection AND requires successful LSA reset if `cyglsa` was registered. Implies `-RemoveServices` and `-ModifyPath` in silent mode.
*   `-RemoveRegistryKeys`: *(Silent Mode)* Deletes standard Cygwin `Software\Cygwin` keys from HKLM and HKCU.
*   `-RemoveServices`: *(Silent Mode)* Stops and deletes Cygwin services linked to the detected path. Implied by `-RemoveInstallDir` in silent mode.
*   `-RemoveCacheFolders`: *(Silent Mode)* Deletes detected Cygwin download cache folders from common user locations.
*   `-ModifyPath`: *(Silent Mode)* Removes Cygwin entries from System/User PATH variables. Requires path detection. Implied by `-RemoveInstallDir` in silent mode.
*   `-RemoveShortcuts`: *(Silent Mode)* Removes the 'Cygwin' folder from common User/All Users Start Menu program locations AND Cygwin-named shortcuts (`*.lnk`) from common Desktop locations. Implied by `-RemoveAllSafe`.
*   `-ResetLsaPackages`: *(Silent Mode)* **CRITICAL!** Removes the `cyglsa` entry from LSA Authentication Packages if found. Implied by `-RemoveAllSafe`. **Results in a MANDATORY REBOOT.** Necessary if `cyglsa` was used (e.g., by some SSHD setups) and required for `-RemoveInstallDir` if `cyglsa` was registered.
*   `-RemoveAllSafe`: *(Silent Mode)* Convenience switch to enable `-RemoveInstallDir`, `-RemoveRegistryKeys`, `-RemoveServices`, `-RemoveCacheFolders`, `-ModifyPath`, `-RemoveShortcuts`, and `-ResetLsaPackages`. Actions requiring path detection will only execute if the path is found. Directory removal depends on successful LSA reset if `cyglsa` was registered.

## Features

*   **Administrator Check:** Ensures the script is run with necessary privileges.
*   **Path Detection:** Attempts to automatically find the Cygwin installation directory via registry and common paths. Allows manual path specification.
*   **Service Removal:** Stops and **deletes** Windows services associated with the detected Cygwin installation (requires path detection).
*   **Registry Cleanup:** Removes standard Cygwin keys from `HKEY_LOCAL_MACHINE` and `HKEY_CURRENT_USER`.
*   **LSA Package Cleanup:** Detects and removes the `cyglsa` authentication package if present (interactive prompt or silent switch required). **Includes critical safety checks.**
*   **PATH Modification:** Removes Cygwin directories from System and User `PATH` environment variables (requires path detection).
*   **Cache Folder Removal:** Detects and removes potential Cygwin setup download cache folders.
*   **Shortcut Removal:** Detects and removes the Cygwin folder from common Start Menu locations and Cygwin-named `.lnk` files from common Desktop locations.
*   **Installation Directory Removal:** Deletes the main Cygwin installation folder (requires path detection AND successful LSA reset if `cyglsa` was registered).
*   **Interactive Mode:** Prompts the user for confirmation before each major destructive action (default behavior).
*   **Silent Mode:** Allows automated execution using command-line switches.
    *   `-Silent`: Enables silent operation.
    *   Granular Control Switches (e.g., `-RemoveRegistryKeys`, `-ResetLsaPackages`).
    *   Bundled Control Switches (`-RemoveAllSafe` enables most actions).
*   **Robust Logic:** Service removal, PATH modification, and installation directory removal depend on successful path detection. LSA handling includes safety checks. Improved error reporting.

## Safety Considerations

*   **LSA Sensitivity:** Modifying LSA Authentication Packages is inherently risky if done incorrectly. This script includes checks (e.g., verifying `msv1_0` remains), but understand the implications. **A mandatory reboot follows LSA changes.**
*   **LSA/Directory Dependency:** Be aware that choosing *not* to reset LSA (when `cyglsa` is present) will prevent the script from deleting the main installation directory, even if `-RemoveInstallDir` or `-RemoveAllSafe` is used. This is a safety measure.
*   **Double-Check Silent Switches:** Ensure you are enabling the correct actions when using `-Silent`. `-RemoveAllSafe` is powerful but still requires careful consideration, especially regarding the implied LSA reset and mandatory reboot.
*   **Test Environment:** If possible, test the script (especially silent mode with `-ResetLsaPackages` or `-RemoveAllSafe`) on a non-critical virtual machine or test system first.
*   **Path Dependency:** Remember that removing services, modifying the PATH, and deleting the main install directory depend on the script successfully finding the Cygwin path.

## Limitations

*   **Other Shortcuts:** The script only targets specific common Start Menu folders and Desktop `.lnk` files. Shortcuts placed elsewhere (e.g., Taskbar, custom folders) need manual removal.
*   **Temporary Files:** Does not explicitly target Cygwin-related files in `%TEMP%` or other temporary locations beyond the download cache.
*   **User Data:** Deletes the entire installation directory if `-RemoveInstallDir` is successful, including user home directories (`/home`) within it. Backups are essential.
*   **Guarantees:** While comprehensive, the script cannot guarantee removal of *every single trace* of Cygwin, especially with highly customized installations or third-party integrations.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
