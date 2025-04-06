# Remove-Cygwin: Cygwin Removal Script

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A comprehensive PowerShell script to thoroughly uninstall Cygwin from Windows. It handles processes, services, registry keys, environment variables, shortcuts, cache folders, the installation directory, and offers optional LSA Authentication Package (`cyglsa`) cleanup. Features interactive prompts (default) and a detailed silent mode for automation.

---

## ⚠️ WARNING ⚠️

**Use this script with EXTREME CAUTION! It performs destructive and irreversible actions.**

* **Permanent Deletion:** Deletes Cygwin files, folders, services, registry keys, and shortcuts. **There is NO UNDO.**
* **Process Termination:** Automatically attempts to forcefully terminate running Cygwin processes. **Save all work** in Cygwin applications before running.
* **Backup Data:** Ensure any important data *within* your Cygwin environment (like `/home` mapped inside the install path) is **backed up securely** elsewhere before execution.
* **Administrator Required:** Must be run with elevated (Admin) privileges. The script includes a check.
* **LSA Modification & Mandatory Reboot:** Removing the `cyglsa` LSA package (uncommon unless manually configured) is high-risk. If performed (requires confirmation or specific silent flags), a **SYSTEM REBOOT IS MANDATORY** afterwards to prevent login issues and ensure stability.
* **LSA/Directory Dependency:** For safety, the script **WILL NOT** delete the main Cygwin installation directory if `cyglsa` is detected in the LSA registry but the LSA reset step fails, is skipped, or is refused.
* **Silent Mode Risks:** Using `-Silent` bypasses all confirmations. Double-check parameters. `-RemoveAllSafe` is powerful; understand its LSA implications and the mandatory reboot. Test on non-critical systems if possible.
* **Use At Your Own Risk:** Review the script's code to fully understand its actions *before* running. You are solely responsible for its use.

---

## Features

* Checks for Administrator privileges.
* Auto-detects Cygwin installation path (Registry, common locations) or accepts a manual path.
* Terminates processes running from the Cygwin directory.
* Stops and deletes associated Windows services.
* Removes standard Cygwin registry keys (HKLM, HKCU).
* Cleans up `cyglsa` LSA Authentication Package (with safety checks and mandatory reboot flag).
* Removes Cygwin directories from System and User PATH environment variables.
* Deletes Cygwin setup download cache folders from common user locations.
* Removes Cygwin Start Menu folder and Desktop shortcuts.
* Deletes the main Cygwin installation directory.
* **Interactive Mode (Default):** Prompts for confirmation before destructive actions.
* **Silent Mode:** Allows fully automated removal using command-line switches.

---

## Prerequisites

* Windows OS (Tested on Windows 11)
* PowerShell (v3+ recommended)
* **Administrator Privileges**

---

## Installation

1.  Download `Remove-Cygwin.ps1`.
2.  **Strongly Recommended:** Read this README and review the script code carefully.
3.  **Back up critical data.**

---

## Usage

1.  **Open PowerShell as Administrator** (e.g., Right-click Start -> "Windows PowerShell (Admin)" or "Terminal (Admin)").
2.  Navigate to the script's directory:
    ```powershell
    cd C:\path\to\your\scripts
    ```
3.  **(If needed) Adjust Execution Policy for the session:**
    ```powershell
    Set-ExecutionPolicy Bypass -Scope Process -Force
    ```
4.  **Run the Script:**

    * **Interactive Mode (Recommended First Run):**
        ```powershell
        # Auto-detect path, prompt for actions
        .\Remove-Cygwin.ps1 -Verbose
        ```
        ```powershell
        # Specify path manually, prompt for actions
        .\Remove-Cygwin.ps1 -CygwinPath "C:\your\cygwin_location" -Verbose
        ```

    * **Silent Mode (Use with EXTREME CAUTION):**
        * Requires `-Silent` AND specific `-Remove*` / `-Reset*` action switches.
        * **NO confirmation prompts!** Actions are performed automatically.
        * **A REBOOT MAY BE REQUIRED WITHOUT PROMPT** if LSA is modified.

        ```powershell
        # Example: Silently remove ONLY registry keys and shortcuts (Path independent)
        .\Remove-Cygwin.ps1 -Silent -RemoveRegistryKeys -RemoveShortcuts -Verbose

        # Example: Silently remove install dir (implies process/service/path removal)
        # Requires path. Will attempt LSA reset if needed (-> MANDATORY REBOOT).
        .\Remove-Cygwin.ps1 -Silent -RemoveInstallDir -CygwinPath "C:\cygwin64" -Verbose

        # Example: Silently remove almost everything ('Safe' includes LSA Reset if needed)
        # MANDATORY REBOOT REQUIRED if LSA was reset.
        .\Remove-Cygwin.ps1 -Silent -RemoveAllSafe -Verbose

        # Example: Silently remove components EXCEPT LSA.
        # !!! Install Dir removal WILL FAIL if 'cyglsa' is registered !!!
        .\Remove-Cygwin.ps1 -Silent -RemoveInstallDir -RemoveRegistryKeys -RemoveServices -ModifyPath -Verbose #-ResetLsaPackages is omitted
        ```

5.  **Follow Prompts / Monitor Output:**
    * **Interactive:** Read prompts carefully (`y`/`n`).
    * **Silent:** Check console output for progress, warnings (Yellow), errors (Red). Use `-Verbose` for detail.

6.  **REBOOT:**
    * **MANDATORY if LSA Authentication Packages were modified.** The script output will indicate this.
    * **Strongly Recommended** otherwise, to ensure all changes (PATH, services, file locks) take full effect.

---

## Parameters

* `-CygwinPath <String>`
    * Optional path to Cygwin root (e.g., `"C:\cygwin64"`). Overrides auto-detection. Needed for path-dependent actions if auto-detect fails.
* `-Silent`
    * Enables silent mode (no prompts). **Requires** one or more action switches below.
* Action Switches (only effective with `-Silent`):
    * `-RemoveInstallDir`
        * Deletes the main Cygwin directory.
        * *Requires:* Path found/provided & successful LSA reset if `cyglsa` was registered.
        * *Implies:* Enables process termination, service removal, and path modification.
    * `-RemoveRegistryKeys`
        * Deletes `Software\Cygwin` registry keys (HKLM/HKCU).
    * `-RemoveServices`
        * Stops and deletes Cygwin services. *Requires:* Path.
    * `-TerminateProcesses`
        * Kills processes from Cygwin path. *Requires:* Path. (Usually implied by `-RemoveInstallDir` / `-RemoveAllSafe`).
    * `-RemoveCacheFolders`
        * Deletes detected Cygwin download caches in user profiles.
    * `-ModifyPath`
        * Removes Cygwin entries from PATH env variable (System/User). *Requires:* Path.
    * `-RemoveShortcuts`
        * Removes common Cygwin Start Menu/Desktop shortcuts.
    * `-ResetLsaPackages`
        * **CRITICAL!** Removes `cyglsa` from LSA registry. **MANDATORY REBOOT** follows if changed. Needed by `-RemoveInstallDir` if `cyglsa` is present.
    * `-RemoveAllSafe`
        * Convenience switch. Enables most removals: InstallDir, Registry, Services, Cache, Path, Shortcuts, **and LSA Reset**.
        * Path-dependent actions only run if path is known. Process termination implied. **MANDATORY REBOOT** if LSA is reset.

---

## Limitations

* Does not remove user data stored *outside* the main Cygwin installation path (e.g., external mounts for `/home`).
* Only removes standard `Software\Cygwin` registry keys.
* Only removes common Start Menu/Desktop shortcuts.
* Does not deep-clean user `%TEMP%` directories beyond specific cache checks.
* May not remove every trace from heavily customized setups or third-party integrations.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
