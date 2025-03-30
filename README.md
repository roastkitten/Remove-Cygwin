# Cygwin Removal Script (PowerShell)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A PowerShell script designed to thoroughly and carefully remove a Cygwin installation from Windows. It handles services, registry keys, environment variables, cache folders, Start Menu and Desktop shortcuts, and the main installation directory. Includes interactive prompts for safety and an optional silent mode with granular controls.

## 🚨🚨 EXTREME WARNING 🚨🚨

*   **HIGHLY DESTRUCTIVE:** This script PERMANENTLY deletes files, folders, Windows services, registry keys, and shortcuts associated with Cygwin.
*   **NO UNDO:** There is no built-in way to reverse the actions performed by this script.
*   **BACKUP YOUR DATA:** Before running this script, ensure any important data stored *within* your Cygwin environment (e.g., in `/home/your_user`) or any data you cannot afford to lose is backed up securely elsewhere.
*   **RUN AS ADMINISTRATOR:** The script requires elevated privileges to modify system components. It includes a check and will exit if not run as Administrator.
*   **USE AT YOUR OWN RISK:** Review the script code and understand its actions *before* execution. While designed with safety checks (prompts, path-dependent actions), the responsibility for its use lies with you.

## Features

*   **Administrator Check:** Ensures the script is run with necessary privileges.
*   **Path Detection:** Attempts to automatically find the Cygwin installation directory via registry and common paths. Allows manual path specification.
*   **Service Removal:** Stops and **deletes** Windows services associated with the detected Cygwin installation (requires path detection).
*   **Registry Cleanup:** Removes standard Cygwin keys from `HKEY_LOCAL_MACHINE` and `HKEY_CURRENT_USER`.
*   **PATH Modification:** Removes Cygwin directories from System and User `PATH` environment variables (requires path detection).
*   **Cache Folder Removal:** Detects and removes potential Cygwin setup download cache folders.
*   **Shortcut Removal:** Detects and removes the Cygwin folder from common Start Menu locations and Cygwin-named `.lnk` files from common Desktop locations.
*   **Installation Directory Removal:** Deletes the main Cygwin installation folder (requires path detection).
*   **Interactive Mode:** Prompts the user for confirmation before each major destructive action (default behavior).
*   **Silent Mode:** Allows automated execution using command-line switches.
    *   `-Silent`: Enables silent operation.
    *   Granular Control Switches (e.g., `-RemoveRegistryKeys`, `-RemoveShortcuts`).
    *   Bundled Control Switches (`-RemoveInstallDir` implies service/path removal, `-RemoveAllSafe` enables most actions).
*   **Safer Logic:** Service removal, PATH modification, and installation directory removal now strictly require successful path detection, preventing accidental removal based on name patterns alone.

## Prerequisites

*   Windows Operating System
*   PowerShell (typically included with modern Windows versions)
*   **Administrator Privileges** to run the script.

## Usage

1.  **Download/Clone:** Obtain the `Remove-Cygwin.ps1` script.
2.  **Review:** Open the script in a text editor and understand what it does. **BACK UP YOUR DATA!**
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
    # Check current policy (optional)
    Get-ExecutionPolicy -List

    # Temporarily allow script execution for this PowerShell process
    Set-ExecutionPolicy Bypass -Scope Process -Force
    ```
6.  **Run the Script:**

    *   **Interactive Mode (Recommended for first use):**
        ```powershell
        .\Remove-Cygwin.ps1
        ```
        The script will attempt to find Cygwin and prompt you before each removal step (Services, Registry, PATH, Cache, Shortcuts, Install Dir).

    *   **Interactive Mode (Manual Path):**
        ```powershell
        .\Remove-Cygwin.ps1 -CygwinPath "C:\your\custom\cygwin_location"
        ```

    *   **Silent Mode (Use with Extreme Caution!):** Requires the `-Silent` switch plus one or more action switches.

        *   *Example: Remove only registry keys and shortcuts silently:*
            ```powershell
            .\Remove-Cygwin.ps1 -Silent -RemoveRegistryKeys -RemoveShortcuts
            ```
        *   *Example: Remove the installation directory silently (also attempts service/path removal if path found):*
            ```powershell
            # Requires path detection or explicit -CygwinPath
            .\Remove-Cygwin.ps1 -Silent -RemoveInstallDir -CygwinPath "C:\cygwin64"
            ```
        *   *Example: Remove most components safely (actions requiring path only run if path found):*
            ```powershell
            .\Remove-Cygwin.ps1 -Silent -RemoveAllSafe
            ```

7.  **Follow Prompts:** If running interactively, carefully read and respond (`y`/`n`) to the confirmation prompts.
8.  **Restart:** After the script finishes, it is **strongly recommended** to restart your computer.

## Parameters

*   `-CygwinPath <String>`: Optional. Specify the full path to the Cygwin root installation directory (e.g., `"C:\cygwin64"`). Required for actions like `-RemoveInstallDir`, `-RemoveServices`, `-ModifyPath`.
*   `-Silent`: REQUIRED to enable silent mode. Suppresses all interactive confirmation prompts. Must be used with one or more action switches below.
*   `-RemoveInstallDir`: *(Silent Mode)* Deletes the main Cygwin directory. Requires path detection. Implies `-RemoveServices` and `-ModifyPath` in silent mode.
*   `-RemoveRegistryKeys`: *(Silent Mode)* Deletes standard Cygwin `Software\Cygwin` keys from HKLM and HKCU.
*   `-RemoveServices`: *(Silent Mode)* Stops and deletes Cygwin services. Requires path detection. Implied by `-RemoveInstallDir` in silent mode.
*   `-RemoveCacheFolders`: *(Silent Mode)* Deletes detected Cygwin download cache folders.
*   `-ModifyPath`: *(Silent Mode)* Removes Cygwin entries from System/User PATH. Requires path detection. Implied by `-RemoveInstallDir` in silent mode.
*   `-RemoveShortcuts`: *(Silent Mode)* Removes the 'Cygwin' folder from common User/All Users Start Menu program locations AND Cygwin-named shortcuts (`*.lnk`) from common Desktop locations. Implied by `-RemoveAllSafe`.
*   `-RemoveAllSafe`: *(Silent Mode)* Convenience switch to enable `-RemoveInstallDir`, `-RemoveRegistryKeys`, `-RemoveServices`, `-RemoveCacheFolders`, `-ModifyPath`, and `-RemoveShortcuts` (actions requiring path detection will only execute if the path is found).

## Safety Considerations

*   **Double-Check Silent Switches:** Ensure you are enabling the correct actions when using `-Silent`. `-RemoveAllSafe` is generally safer than enabling individual flags if you want broad removal, but still requires caution.
*   **Test Environment:** If possible, test the script (especially silent mode) on a non-critical virtual machine or test system first.
*   **Path Dependency:** Remember that removing services, modifying the PATH, and deleting the main install directory depend on the script successfully finding the Cygwin path. Registry, Cache, and Shortcut removal can proceed even if the path isn't found (though shortcut removal is less likely to find things without knowing the install path in some cases).

## Limitations

*   **Other Shortcuts:** The script only targets specific common Start Menu folders and Desktop `.lnk` files. Shortcuts placed elsewhere (e.g., Taskbar, custom folders) need manual removal.
*   **Temporary Files:** Does not explicitly target Cygwin-related files in `%TEMP%` or other temporary locations beyond the download cache.
*   **User Data:** Deletes the entire installation directory, including user home directories (`/home`) within it. Backups are essential.
*   **Guarantees:** While comprehensive, the script cannot guarantee removal of *every single trace* of Cygwin, especially with highly customized installations or third-party integrations.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
