# Cygwin Removal Script (PowerShell)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A PowerShell script to thoroughly remove Cygwin installations from Windows, including services, registry keys, cache, and the install directory. Offers interactive prompts or a silent mode with granular controls.

**Current Script:** `Remove-Cygwin.ps1`

## 🚨🚨 **EXTREME WARNING** 🚨🚨

*   **DESTRUCTIVE:** This script PERMANENTLY DELETES Cygwin files, folders, services, and registry keys.
*   **NO UNDO:** Actions cannot be easily reversed.
*   **BACKUP DATA:** Back up important data from within your Cygwin environment *before* running.
*   **RUN AS ADMIN:** Requires Administrator privileges.
*   **USE AT YOUR OWN RISK:** Understand the script before use.

## Purpose

Safely and completely uninstall Cygwin components from your system.

## Quick Usage

1.  **Download:** Get `Remove-Cygwin.ps1`.
2.  **Backup:** Ensure your Cygwin data is backed up.
3.  **Run as Administrator:** Open PowerShell *as Administrator*.
4.  **Navigate:** `cd C:\path\to\script`
5.  **Execution Policy (If Needed):** `Set-ExecutionPolicy Bypass -Scope Process -Force`
6.  **Run:**

    *   **Interactive (Recommended First):**
        ```powershell
        .\Remove-Cygwin.ps1
        ```
        (Follow the prompts carefully)

    *   **Silent (Use Caution - Remove Most Components Safely):**
        ```powershell
        # Requires path detection or -CygwinPath for full effect
        .\Remove-Cygwin.ps1 -Silent -RemoveAllSafe
        ```
        
   *   **Silent (Use Caution - Example: Remove Registry & Cache Only):**
        ```powershell
        .\Remove-Cygwin.ps1 -Silent -RemoveRegistryKeys -RemoveCacheFolders
        ```

7.  **Restart:** **RESTART YOUR COMPUTER** after the script finishes.

## Key Parameters

*   `-CygwinPath <String>`: Manually specify Cygwin's location (e.g., `"C:\cygwin64"`). Needed for some actions if auto-detection fails.
*   `-Silent`: REQUIRED to enable silent mode (no prompts). Must be used with one or more action switches below.
*   `-RemoveInstallDir`: *(Silent Mode)* Deletes the main Cygwin directory. Requires path detection. Implies `-RemoveServices` and `-ModifyPath`.
*   `-RemoveRegistryKeys`: *(Silent Mode)* Deletes standard Cygwin `Software\Cygwin` keys from HKLM and HKCU.
*   `-RemoveServices`: *(Silent Mode)* Stops and deletes Cygwin services. Requires path detection. Implied by `-RemoveInstallDir`.
*   `-RemoveCacheFolders`: *(Silent Mode)* Deletes detected Cygwin download cache folders.
*   `-ModifyPath`: *(Silent Mode)* Removes Cygwin entries from System/User PATH. Requires path detection. Implied by `-RemoveInstallDir`.
*   `-RemoveAllSafe`: *(Silent Mode)* Convenience switch to enable `-RemoveInstallDir`, `-RemoveRegistryKeys`, `-RemoveServices`, `-RemoveCacheFolders`, and `-ModifyPath` (actions requiring path detection will only run if path is found).

## Important Notes

*   Manually delete any leftover Desktop/Start Menu shortcuts.
*   Service removal, PATH changes, and install directory deletion require the script to find the Cygwin path. Registry and Cache removal can proceed even if the path isn't found.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.
