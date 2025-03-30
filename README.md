# Cygwin Removal Script (PowerShell)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A PowerShell script to thoroughly remove Cygwin installations from Windows, including services, registry keys, cache, and the install directory. Offers interactive prompts or a silent mode.

**Current Script:** `Remove-Cygwin-SafeSilent.ps1`

## 🚨🚨 **EXTREME WARNING** 🚨🚨

*   **DESTRUCTIVE:** This script PERMANENTLY DELETES Cygwin files, folders, services, and registry keys.
*   **NO UNDO:** Actions cannot be easily reversed.
*   **BACKUP DATA:** Back up important data from within your Cygwin environment *before* running.
*   **RUN AS ADMIN:** Requires Administrator privileges.
*   **USE AT YOUR OWN RISK:** Understand the script before use.

## Purpose

Safely and completely uninstall Cygwin components from your system.

## Quick Usage

1.  **Download:** Get `Remove-Cygwin-SafeSilent.ps1`.
2.  **Backup:** Ensure your Cygwin data is backed up.
3.  **Run as Administrator:** Open PowerShell *as Administrator*.
4.  **Navigate:** `cd C:\path\to\script`
5.  **Execution Policy (If Needed):** `Set-ExecutionPolicy Bypass -Scope Process -Force`
6.  **Run:**

    *   **Interactive (Recommended First):**
        ```powershell
        .\Remove-Cygwin-SafeSilent.ps1
        ```
        (Follow the prompts carefully)

    *   **Silent (Use Caution - Removes Most Components Safely):**
        ```powershell
        # Requires path detection or -CygwinPath for full effect
        .\Remove-Cygwin-SafeSilent.ps1 -Silent -RemoveAllSafe
        ```

7.  **Restart:** **RESTART YOUR COMPUTER** after the script finishes.

## Key Parameters

*   `-CygwinPath <String>`: Manually specify Cygwin's location (e.g., `"C:\cygwin64"`). Needed for some actions if auto-detection fails.
*   `-Silent`: Enables silent mode (no prompts). Requires action switches.
*   `-RemoveAllSafe`: (Silent Mode) Enables removal of most components. Safer than manually specifying all flags. Does *not* delete services based on name patterns if path is unknown.
*   (Other granular switches exist for specific silent actions - see script comments.)

## Important Notes

*   Manually delete any leftover Desktop/Start Menu shortcuts.
*   Service removal, PATH changes, and install directory deletion require the script to find the Cygwin path.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.
