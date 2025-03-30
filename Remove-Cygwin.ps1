<#
.SYNOPSIS
    Stops and removes Cygwin components including LSA package reset, shortcuts, with interactive prompts OR controlled silent operation. Enforces LSA reset before directory removal if needed.
.DESCRIPTION
    Attempts a thorough removal of Cygwin. Runs interactively by default.
    Use -Silent along with action switches for automated removal. Handles LSA package 'cyglsa'.

    Key Features:
    - Detects Cygwin path (Registry, Common Locations).
    - Stops and removes associated services.
    - Removes standard Cygwin registry keys.
    - Handles 'cyglsa' LSA Authentication Package removal (REQUIRES REBOOT).
    - Removes Cygwin entries from System and User PATH variables.
    - Removes Cygwin download cache folders.
    - Removes Start Menu and Desktop shortcuts.
    - Deletes the main installation directory.

    Dependencies:
    - Removing the installation directory requires path detection.
    - Removing services requires path detection.
    - Modifying PATH requires path detection.
    - **CRITICAL:** If 'cyglsa' is found registered in LSA, it *must* be reset (requires user confirmation or specific silent flags) before the main installation directory can be deleted to prevent potential system instability.

    Silent Mode:
    - Requires the -Silent switch.
    - Use action switches (-RemoveInstallDir, -RemoveRegistryKeys, etc.) to specify what to remove.
    - -RemoveAllSafe enables most removal actions (requires path detection for some).
    - -RemoveInstallDir implicitly enables -RemoveServices and -ModifyPath in silent mode (if the path is found).

.PARAMETER CygwinPath
    Optional. Specify the exact root path to the Cygwin installation (e.g., "C:\cygwin64"). If provided and valid, overrides automatic detection. Required for service/path/install dir removal if auto-detection fails.
.PARAMETER Silent
    REQUIRED to enable any silent operation. Suppresses all interactive prompts. Action switches must also be used.
.PARAMETER RemoveInstallDir
    If -Silent is specified, deletes the main Cygwin installation directory (requires path detection). IMPLICITLY enables -RemoveServices and -ModifyPath in silent mode. Requires LSA reset if cyglsa is registered.
.PARAMETER RemoveRegistryKeys
    If -Silent is specified, deletes standard Cygwin registry keys (HKLM/HKCU:\Software\Cygwin).
.PARAMETER RemoveServices
    If -Silent is specified, stops and deletes Cygwin services linked to the detected path. Also implicitly enabled by -RemoveInstallDir in silent mode.
.PARAMETER RemoveCacheFolders
    If -Silent is specified, deletes detected Cygwin download cache folders (searches common locations).
.PARAMETER ModifyPath
    If -Silent is specified, removes Cygwin entries from System and User PATH environment variables (requires path detection). Also implicitly enabled by -RemoveInstallDir in silent mode.
.PARAMETER RemoveShortcuts
    If -Silent is specified, removes the 'Cygwin' folder from common Start Menu locations AND Cygwin-named shortcuts from common Desktop locations. Implied by -RemoveAllSafe.
.PARAMETER ResetLsaPackages
    If -Silent is specified, removes 'cyglsa' from LSA Authentication Packages if present. Implied by -RemoveAllSafe. **RESULTS IN MANDATORY REBOOT.** Crucial if cyglsa was used.
.PARAMETER RemoveAllSafe
    If -Silent is specified, enables -RemoveInstallDir, -RemoveRegistryKeys, -RemoveServices, -RemoveCacheFolders, -ModifyPath, -RemoveShortcuts, and -ResetLsaPackages. Actions requiring path detection will only run if the path is found.

.EXAMPLE
    # Run interactively, prompting for confirmation for each step
    # Includes LSA check & enforces dependency for directory removal.
    .\Remove-Cygwin.ps1 -Verbose

.EXAMPLE
    # Run silently, removing everything possible, using auto-detected path
    # DANGEROUS: No prompts. REQUIRES REBOOT if LSA was modified.
    .\Remove-Cygwin.ps1 -Silent -RemoveAllSafe

.EXAMPLE
    # Run silently, only remove registry keys and shortcuts
    .\Remove-Cygwin.ps1 -Silent -RemoveRegistryKeys -RemoveShortcuts

.EXAMPLE
    # Run interactively, specifying the Cygwin path explicitly
    .\Remove-Cygwin.ps1 -CygwinPath "C:\Cygwin" -Verbose

.WARNING
    This script performs DESTRUCTIVE actions: deleting files, folders, services, registry keys, and modifying system settings (PATH, LSA).
    Silent mode removes all confirmation prompts. Review switches carefully.
    **BACK UP YOUR DATA before running.**
    **Run AS ADMINISTRATOR.**
    **USE AT YOUR OWN RISK.**
    **LSA modification REQUIRES A REBOOT.** Refusing LSA reset (when needed) will prevent main directory deletion.

.NOTES
    Author: Assistant (AI) / Refined by User Request
    Version: 1.9 - Improved Readability, Error Handling, Standard Practices.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Mandatory = $false)]
    [string]$CygwinPath = "",

    [Parameter(Mandatory = $false)]
    [switch]$Silent,

    [Parameter(Mandatory = $false)]
    [switch]$RemoveInstallDir,

    [Parameter(Mandatory = $false)]
    [switch]$RemoveRegistryKeys,

    [Parameter(Mandatory = $false)]
    [switch]$RemoveServices,

    [Parameter(Mandatory = $false)]
    [switch]$RemoveCacheFolders,

    [Parameter(Mandatory = $false)]
    [switch]$ModifyPath,

    [Parameter(Mandatory = $false)]
    [switch]$RemoveShortcuts,

    [Parameter(Mandatory = $false)]
    [switch]$ResetLsaPackages,

    [Parameter(Mandatory = $false)]
    [switch]$RemoveAllSafe
)

# --- Start Configuration ---
$CommonCygwinPaths = @("C:\cygwin64", "C:\cygwin")
$CacheSearchLocations = @("$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop", "$env:USERPROFILE")
$StartMenuPaths = @(
    Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs"
    Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"
)
$DesktopPaths = @(
    Join-Path $env:PUBLIC "Desktop"
    Join-Path $env:USERPROFILE "Desktop"
)
$CygwinShortcutFolderName = "Cygwin" # Name of the folder in Start Menu
$LsaRegKeyPath = "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa"
$LsaValueName = "Authentication Packages"
$CygLsaPackageName = "cyglsa"
$CoreLsaPackage = "msv1_0" # Essential LSA package, don't remove!
# --- End Configuration ---

# --- Helper Function ---
function Test-IsAdmin {
    try {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [System.Security.Principal.WindowsPrincipal]::new($identity)
        return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        Write-Warning "Could not determine admin status. Assuming not admin."
        return $false
    }
}

# --- Initialization ---
$ScriptStartTime = Get-Date
$lsaModified = $false           # Tracks if LSA registry key was successfully changed
$cygLsaFoundInRegistry = $false # Tracks if 'cyglsa' was found in the LSA packages list initially
$lsaResetAttempted = $false      # Tracks if user confirmed or silent mode triggered LSA reset attempt
$DetectedCygwinPath = $null
$PathFound = $false

# Determine effective actions in silent mode
# Note: Some actions depend on $PathFound being true later.
$EffectiveRemoveInstallDir = $Silent.IsPresent -and ($RemoveInstallDir.IsPresent -or $RemoveAllSafe.IsPresent)
$EffectiveRemoveRegistryKeys = $Silent.IsPresent -and ($RemoveRegistryKeys.IsPresent -or $RemoveAllSafe.IsPresent)
# RemoveInstallDir implies RemoveServices and ModifyPath in silent mode
$EffectiveRemoveServices = $Silent.IsPresent -and ($RemoveServices.IsPresent -or $EffectiveRemoveInstallDir -or $RemoveAllSafe.IsPresent)
$EffectiveRemoveCacheFolders = $Silent.IsPresent -and ($RemoveCacheFolders.IsPresent -or $RemoveAllSafe.IsPresent)
$EffectiveModifyPath = $Silent.IsPresent -and ($ModifyPath.IsPresent -or $EffectiveRemoveInstallDir -or $RemoveAllSafe.IsPresent)
$EffectiveRemoveShortcuts = $Silent.IsPresent -and ($RemoveShortcuts.IsPresent -or $RemoveAllSafe.IsPresent)
$EffectiveResetLsaPackages = $Silent.IsPresent -and ($ResetLsaPackages.IsPresent -or $RemoveAllSafe.IsPresent)

# --- Pre-Checks and Warnings ---

# 1. Check for Admin privileges
if (-not (Test-IsAdmin)) {
    Write-Error "This script requires Administrator privileges to modify services, registry (HKLM), LSA, and system files. Please run as Administrator."
    Exit 1
}

# 2. Initial Warning and Confirmation (if not silent)
Write-Host "`n*** EXTREME WARNING ***" -ForegroundColor Red
Write-Host "This script attempts to COMPLETELY REMOVE Cygwin and related components." -ForegroundColor Yellow
Write-Host "This includes potentially deleting services, registry keys, shortcuts, LSA settings, and the main installation folder." -ForegroundColor Yellow
Write-Host "Ensure all important data within the Cygwin installation is backed up." -ForegroundColor Yellow
Write-Host "** MODIFICATION OF LSA PACKAGES REQUIRES A REBOOT! **" -ForegroundColor Red
Write-Host "** If 'cyglsa' is registered, refusing LSA reset will PREVENT main directory deletion. **" -ForegroundColor Yellow
Write-Host "There is NO UNDO feature." -ForegroundColor Yellow
Write-Host ""

if ($Silent.IsPresent) {
    Write-Host "RUNNING IN SILENT MODE. NO FURTHER PROMPTS WILL BE SHOWN." -ForegroundColor Magenta
    Write-Host "Effective actions intended by switches (some require path detection or successful LSA reset):"
    if ($EffectiveRemoveInstallDir)   { Write-Host " - RemoveInstallDir (Implies Service/Path removal if path found, requires LSA reset if applicable)" -ForegroundColor Cyan }
    if ($EffectiveRemoveRegistryKeys) { Write-Host " - RemoveRegistryKeys" -ForegroundColor Cyan }
    if ($EffectiveRemoveServices)     { Write-Host " - RemoveServices (Requires path detection)" -ForegroundColor Cyan }
    if ($EffectiveModifyPath)         { Write-Host " - ModifyPath (Requires path detection)" -ForegroundColor Cyan }
    if ($EffectiveResetLsaPackages)   { Write-Host " - ResetLsaPackages (REQUIRES REBOOT if changed)" -ForegroundColor Yellow }
    if ($EffectiveRemoveCacheFolders) { Write-Host " - RemoveCacheFolders" -ForegroundColor Cyan }
    if ($EffectiveRemoveShortcuts)    { Write-Host " - RemoveShortcuts (Start Menu + Desktop)" -ForegroundColor Cyan }

    if (-not ($EffectiveRemoveInstallDir -or $EffectiveRemoveRegistryKeys -or $EffectiveRemoveServices -or $EffectiveRemoveCacheFolders -or $EffectiveModifyPath -or $EffectiveRemoveShortcuts -or $EffectiveResetLsaPackages)) {
        Write-Warning "Silent mode specified, but no action switches (-Remove*, -RemoveAllSafe) were provided. No actions will be taken."
        # Exit here or let it continue (it will just detect path etc.)? Let it continue for now.
    } else {
         Write-Host "Pausing for 5 seconds before silent execution begins..." -ForegroundColor Gray
         Start-Sleep -Seconds 5
    }
} else {
    Write-Host "Running INTERACTIVELY. You will be prompted before each major destructive action." -ForegroundColor Yellow
    $initialConfirmation = Read-Host "Do you understand the risks and wish to proceed with Cygwin removal? (y/n)"
    if ($initialConfirmation -ne 'y') {
        Write-Host "Operation cancelled by user." -ForegroundColor Green
        Exit 0
    }
}

# --- Main Removal Steps ---

# 3. Determine Cygwin Installation Path
Write-Host "`nStep 1: Detecting Cygwin installation path..." -ForegroundColor Cyan
# Priority 1: User-provided path
if (-not [string]::IsNullOrEmpty($CygwinPath)) {
    $NormalizedPath = $CygwinPath.TrimEnd('\')
    if (Test-Path -Path $NormalizedPath -PathType Container) {
        Write-Verbose "Checking user provided path: $NormalizedPath"
        # Basic sanity check for a Cygwin directory
        if (Test-Path (Join-Path $NormalizedPath "Cygwin.bat") -PathType Leaf -or Test-Path (Join-Path $NormalizedPath "bin") -PathType Container) {
             $DetectedCygwinPath = $NormalizedPath
             Write-Host "Using valid provided path: $DetectedCygwinPath" -ForegroundColor Green
             $PathFound = $true
        } else {
             Write-Warning "Provided path '$NormalizedPath' exists, but doesn't look like a Cygwin root (missing Cygwin.bat or bin/). Continuing detection."
        }
    } else {
        Write-Warning "Provided path '$CygwinPath' not found or is not a directory. Continuing detection."
    }
}

# Priority 2: Registry
if (-not $PathFound) {
    Write-Verbose "Checking registry for Cygwin path..."
    $regKeyPaths = @("HKLM:\Software\Cygwin\setup", "HKCU:\Software\Cygwin\setup")
    foreach ($keyPath in $regKeyPaths) {
        if (Test-Path $keyPath) {
            Write-Verbose "Checking key: $keyPath"
            try {
                $regValue = Get-ItemProperty -Path $keyPath -Name "rootdir" -ErrorAction Stop
                if ($regValue -and $regValue.rootdir -and (Test-Path $regValue.rootdir -PathType Container)) {
                    $DetectedCygwinPath = $regValue.rootdir.TrimEnd('\')
                    Write-Host "Found path in Registry ($keyPath): $DetectedCygwinPath" -ForegroundColor Green
                    $PathFound = $true
                    break # Found it, stop checking registry
                }
            } catch {
                Write-Verbose "Could not read 'rootdir' from '$keyPath' or path invalid: $($_.Exception.Message)"
            }
        }
    }
}

# Priority 3: Common Locations
if (-not $PathFound) {
    Write-Verbose "Checking common installation locations..."
    foreach ($path in $CommonCygwinPaths) {
        Write-Verbose "Checking location: $path"
        if (Test-Path -Path $path -PathType Container) {
            # Check for Cygwin.bat or bin directory as indicators
            if (Test-Path (Join-Path $path "Cygwin.bat") -PathType Leaf -or Test-Path (Join-Path $path "bin") -PathType Container) {
                $DetectedCygwinPath = $path.TrimEnd('\')
                Write-Host "Found potential path in common location: $DetectedCygwinPath" -ForegroundColor Green
                $PathFound = $true
                break # Found it, stop checking common paths
            }
        }
    }
}

if (-not $PathFound) {
    Write-Warning "Could not determine Cygwin installation path automatically."
    Write-Warning "Path-dependent actions (Services, PATH, Install Dir) will be skipped unless a path was provided manually but failed validation."
    $DetectedCygwinPath = $null # Ensure it's null if not found
} else {
    Write-Host "Confirmed Cygwin Root Path: $DetectedCygwinPath" -ForegroundColor Cyan
}
Write-Host "-----------------------------------------------------"


# 4. Stop and Remove Cygwin Services (REQUIRES PATH)
Write-Host "`nStep 2: Processing Cygwin services..." -ForegroundColor Cyan
$proceedWithServiceRemoval = $false
$cygwinServices = @()

if ($PathFound) {
    Write-Verbose "Searching for services linked to path: $DetectedCygwinPath"
    try {
        # Using -like is generally safer than assuming exact path structure in service registration
        $cygwinServices = Get-CimInstance Win32_Service | Where-Object { $_.PathName -like "$DetectedCygwinPath\*" } -ErrorAction SilentlyContinue
    } catch {
        Write-Warning "Error querying services: $($_.Exception.Message)"
    }

    if ($cygwinServices.Count -gt 0) {
        Write-Host "Found potential Cygwin services:" -ForegroundColor Yellow
        $cygwinServices | ForEach-Object { Write-Host "  - $($_.Name) ($($_.DisplayName)) Path: $($_.PathName)" }

        if ($Silent.IsPresent) {
            if ($EffectiveRemoveServices) {
                Write-Host "Silent mode: Will attempt to stop and remove services." -ForegroundColor Cyan
                $proceedWithServiceRemoval = $true
            } else {
                Write-Host "Silent mode: Skipping service removal (Action not enabled)." -ForegroundColor Gray
            }
        } else { # Interactive
            Write-Host ""
            $confirm = Read-Host "Do you want to STOP and DELETE these services? (y/n)"
            if ($confirm -eq 'y') {
                $proceedWithServiceRemoval = $true
            }
        }
    } else {
        Write-Host "No running services found linked to the path '$DetectedCygwinPath'." -ForegroundColor Green
    }
} else {
    Write-Warning "Skipping service processing: Cygwin installation path not found."
}

if ($proceedWithServiceRemoval) {
    Write-Host "Proceeding with service stop and deletion..." -ForegroundColor Yellow
    foreach ($service in $cygwinServices) {
        $serviceName = $service.Name
        Write-Host "  Processing: $serviceName"
        # Stop the service
        Write-Host "    Stopping service..." -ForegroundColor Yellow
        try {
            Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue # Try stopping gracefully first, but force if needed
            Start-Sleep -Seconds 3 # Give time for service to stop
            $status = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($status -and $status.Status -ne 'Stopped') {
                Write-Warning "      Service '$serviceName' did not stop gracefully after Stop-Service."
                # Optional: Could try taskkill here if needed, but sc delete usually works even if running
            } else {
                Write-Host "      Service stopped." -ForegroundColor Green
            }
        } catch {
            Write-Warning "      Error trying to stop service '$serviceName': $($_.Exception.Message)"
        }

        # Delete the service
        Write-Host "    Deleting service..." -ForegroundColor Yellow
        $removed = $false
        try {
            # Use sc.exe as it's often more reliable for deleting stubborn services
            Write-Verbose "      Attempting deletion with sc.exe delete ""$serviceName"""
            $scOutput = sc.exe delete "$serviceName" 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "      Deleted successfully via sc.exe." -ForegroundColor Green
                $removed = $true
            } else {
                # Check if error is "service does not exist" (error code 1060) - maybe already removed
                if ($scOutput -match '1060') {
                     Write-Host "      Service already deleted or does not exist (sc.exe error 1060)." -ForegroundColor Green
                     $removed = $true
                } else {
                    Write-Warning "      sc.exe delete failed for '$serviceName'. Output: $scOutput"
                }
            }
        } catch {
            Write-Warning "      Error executing sc.exe delete for '$serviceName': $($_.Exception.Message)"
        }

        # Fallback using PowerShell cmdlet if sc.exe failed and cmdlet exists
        if (-not $removed -and (Get-Command Remove-Service -ErrorAction SilentlyContinue)) {
            Write-Verbose "      Attempting deletion with Remove-Service..."
            try {
                Remove-Service -Name $serviceName -Force -ErrorAction Stop
                Write-Host "      Deleted successfully via Remove-Service." -ForegroundColor Green
                $removed = $true
            } catch {
                Write-Warning "      Remove-Service failed for '$serviceName': $($_.Exception.Message)"
            }
        }

        if (-not $removed) {
            Write-Error "      FAILED to delete service '$serviceName'. Manual removal might be required after reboot."
        }
    }
} elseif ($cygwinServices.Count -gt 0 -and (-not $proceedWithServiceRemoval)) {
    Write-Host "Skipping service removal as requested or not enabled." -ForegroundColor Green
}
Write-Host "-----------------------------------------------------"


# 5. Remove Registry Keys (Software\Cygwin)
Write-Host "`nStep 3: Processing main Cygwin registry keys..." -ForegroundColor Cyan
$regKeysToRemove = @("HKLM:\Software\Cygwin", "HKCU:\Software\Cygwin")
$foundRegKeys = @()
$proceedWithRegistryRemoval = $false

foreach ($keyPath in $regKeysToRemove) {
    if (Test-Path $keyPath) {
        $foundRegKeys += $keyPath
    }
}

if ($foundRegKeys.Count -gt 0) {
    Write-Host "Found standard Cygwin registry keys:" -ForegroundColor Yellow
    $foundRegKeys | ForEach-Object { Write-Host "  - $_" }

    if ($Silent.IsPresent) {
        if ($EffectiveRemoveRegistryKeys) {
            Write-Host "Silent mode: Will attempt to remove registry keys." -ForegroundColor Cyan
            $proceedWithRegistryRemoval = $true
        } else {
            Write-Host "Silent mode: Skipping registry key removal (Action not enabled)." -ForegroundColor Gray
        }
    } else { # Interactive
        Write-Host ""
        $confirm = Read-Host "Do you want to DELETE these registry keys and their subkeys? (y/n)"
        if ($confirm -eq 'y') {
            $proceedWithRegistryRemoval = $true
        }
    }

    if ($proceedWithRegistryRemoval) {
        Write-Host "Proceeding with registry key removal..." -ForegroundColor Yellow
        foreach ($keyPath in $foundRegKeys) {
            Write-Host "  Removing: $keyPath..." -ForegroundColor Yellow
            try {
                # Use -Recurse -Force for thorough removal
                Remove-Item -Path $keyPath -Recurse -Force -ErrorAction Stop
                Write-Host "    Removed '$keyPath'." -ForegroundColor Green
            } catch {
                Write-Warning "    FAILED to remove registry key '$keyPath': $($_.Exception.Message)"
            }
        }
    } else {
        Write-Host "Skipping registry key removal as requested or not enabled." -ForegroundColor Green
    }
} else {
    Write-Host "No standard Cygwin registry keys found at HKLM/HKCU:\Software\Cygwin." -ForegroundColor Green
}
Write-Host "-----------------------------------------------------"


# 6. Reset LSA Authentication Packages
Write-Host "`nStep 4: Processing LSA Authentication Packages..." -ForegroundColor Cyan
$proceedWithLsaReset = $false
$currentLsaPackages = $null

# Check if 'cyglsa' exists in the LSA packages
try {
    $lsaProp = Get-ItemProperty -Path $LsaRegKeyPath -Name $LsaValueName -ErrorAction SilentlyContinue
    if ($lsaProp -ne $null) {
        # Ensure it's treated as an array, even if it's a single string currently
        $currentLsaPackages = @($lsaProp.$LsaValueName)
        if ($currentLsaPackages -contains $CygLsaPackageName) {
            $cygLsaFoundInRegistry = $true # Set flag: It was present initially
            Write-Host "Found '$CygLsaPackageName' in LSA Authentication Packages." -ForegroundColor Yellow
            Write-Host "  Current Value: $($currentLsaPackages -join ', ')"
        } else {
            Write-Host "'$CygLsaPackageName' not found in LSA Authentication Packages." -ForegroundColor Green
        }
    } else {
        Write-Host "LSA Authentication Packages value not found or registry key unreadable. Skipping LSA modification." -ForegroundColor Green
    }
} catch {
    Write-Warning "Could not read LSA Packages key '$LsaRegKeyPath': $($_.Exception.Message). Skipping LSA modification."
}

# If found, decide whether to remove it
if ($cygLsaFoundInRegistry) {
    if ($Silent.IsPresent) {
        if ($EffectiveResetLsaPackages) {
            Write-Warning "Silent mode: Proceeding with LSA package reset. REBOOT WILL BE MANDATORY."
            $proceedWithLsaReset = $true
            $lsaResetAttempted = $true
        } else {
            Write-Warning "Silent mode: '$CygLsaPackageName' found but reset not enabled via -ResetLsaPackages or -RemoveAllSafe."
            Write-Warning "Main Cygwin directory deletion will be BLOCKED due to potential system instability."
            $proceedWithLsaReset = $false # Explicitly false
        }
    } else { # Interactive
        Write-Warning "Modifying LSA Authentication Packages is a sensitive operation."
        Write-Warning "Removing '$CygLsaPackageName' requires a system REBOOT afterwards."
        Write-Warning "If you used Cygwin features requiring LSA (like SSHD with certain auth types), this is necessary."
        Write-Warning "Refusing this step will PREVENT the main Cygwin directory from being deleted later."
        Write-Host ""
        $confirm = Read-Host "Remove '$CygLsaPackageName' from LSA Packages? (REBOOT REQUIRED) (y/n)"
        if ($confirm -eq 'y') {
            $proceedWithLsaReset = $true
            $lsaResetAttempted = $true
        } else {
             $proceedWithLsaReset = $false
        }
    }

    # Perform the removal if decided
    if ($proceedWithLsaReset) {
        # Filter out cyglsa
        $newLsaPackages = $currentLsaPackages | Where-Object { $_ -ne $CygLsaPackageName }

        # CRITICAL CHECK: Ensure the core package 'msv1_0' is still present
        if ($newLsaPackages -contains $CoreLsaPackage) {
            Write-Host "  New LSA Package list will be: $($newLsaPackages -join ', ')" -ForegroundColor Cyan
            Write-Host "Attempting registry update..." -ForegroundColor Yellow
            try {
                # Set the modified list back
                Set-ItemProperty -Path $LsaRegKeyPath -Name $LsaValueName -Value $newLsaPackages -Type MultiString -Force -ErrorAction Stop
                Write-Host "  LSA Packages updated successfully in registry." -ForegroundColor Green
                $lsaModified = $true # Flag that the change was made and reboot is needed
            } catch {
                Write-Error "  FAILED to update LSA Packages key '$LsaRegKeyPath': $($_.Exception.Message)"
                Write-Error "  LSA settings may be in an inconsistent state. Manual check recommended."
                $lsaModified = $false # Failed, don't set the flag
            }
        } else {
            # This should almost never happen unless the system LSA is already broken
            Write-Error "  CRITICAL ERROR: Core LSA package '$CoreLsaPackage' would be removed by this operation. Aborting LSA modification to prevent system lockout."
            Write-Error "  Original LSA Packages: $($currentLsaPackages -join ', ')"
            $proceedWithLsaReset = $false # Ensure this didn't proceed
            $lsaModified = $false
        }
    } else {
        Write-Host "Skipping LSA package reset." -ForegroundColor Green
        if ($cygLsaFoundInRegistry) { # Only warn if it was found but skipped
             Write-Warning "Reminder: '$CygLsaPackageName' remains in LSA. Main directory deletion will be blocked."
        }
    }
}
Write-Host "-----------------------------------------------------"


# 7. Remove Cygwin from PATH environment variables (REQUIRES PATH)
Write-Host "`nStep 5: Processing PATH environment variables..." -ForegroundColor Cyan
$proceedWithPathModification = $false

if ($PathFound) {
    if ($Silent.IsPresent) {
        if ($EffectiveModifyPath) {
            Write-Host "Silent mode: Will attempt PATH modification." -ForegroundColor Cyan
            $proceedWithPathModification = $true
        } else {
            Write-Host "Silent mode: Skipping PATH modification (Action not enabled)." -ForegroundColor Gray
        }
    } else { # Interactive
        Write-Host "Detected Cygwin Path: $DetectedCygwinPath"
        Write-Host "This step will remove entries related to this path (e.g., '$DetectedCygwinPath\bin') from System and User PATH variables."
        Write-Host ""
        $confirm = Read-Host "Do you want to modify System and User PATH variables? (y/n)"
        if ($confirm -eq 'y') {
            $proceedWithPathModification = $true
        }
    }

    if ($proceedWithPathModification) {
        Write-Host "Proceeding with PATH modification..." -ForegroundColor Yellow
        $cygwinBinPath = Join-Path $DetectedCygwinPath "bin"
        # Define the paths/prefixes to filter out
        $pathsToFilter = @($DetectedCygwinPath, $cygwinBinPath)
        Write-Verbose "Will filter PATH entries starting with: $($pathsToFilter -join ', ')"

        # --- Process System PATH ---
        Write-Verbose "Processing System PATH..."
        $sysPathReg = "Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment"
        $originalSystemPath = $null
        $systemPathModified = $false
        try {
            $sysProp = Get-ItemProperty -Path $sysPathReg -Name Path -ErrorAction SilentlyContinue
            if ($sysProp -and $sysProp.Path) {
                $originalSystemPath = $sysProp.Path
                # Split into entries, filter out empty ones first
                $pathEntries = $originalSystemPath -split ';' | Where-Object { $_ -ne '' }

                # *** CORRECTED FILTERING LOGIC ***
                $filteredEntries = $pathEntries | Where-Object {
                    $currentEntry = $_
                    # Check if the current entry starts with any of the paths to filter
                    $matchCount = ($pathsToFilter | Where-Object { $currentEntry.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) } | Measure-Object).Count
                    # Keep the entry ($_) if the match count is 0
                    $matchCount -eq 0
                }

                # Join the filtered entries back, preserving relative order
                $newSystemPathString = $filteredEntries -join ';'

                # Only write if changed
                if ($newSystemPathString -ne $originalSystemPath) {
                    Write-Host "  Modifying System PATH..." -ForegroundColor Yellow
                    Write-Verbose "    Old System PATH: $originalSystemPath"
                    Write-Verbose "    New System PATH: $newSystemPathString"
                    Set-ItemProperty -Path $sysPathReg -Name Path -Value $newSystemPathString -ErrorAction Stop
                    Write-Host "    System PATH updated." -ForegroundColor Green
                    $systemPathModified = $true
                } else {
                     Write-Verbose "    No changes needed for System PATH."
                }
            } else {
                Write-Verbose "  System PATH variable not found or empty."
            }
        } catch {
            Write-Warning "  Could not process System PATH: $($_.Exception.Message)" # Error message will now be more specific if Set-ItemProperty fails
        }
        if (!$systemPathModified -and $originalSystemPath -ne $null) { Write-Host "  No changes made to System PATH." -ForegroundColor Green }


        # --- Process User PATH ---
        Write-Verbose "Processing User PATH..."
        $usrPathReg = "Registry::HKEY_CURRENT_USER\Environment"
        $originalUserPath = $null
        $userPathModified = $false
        try {
            if (-not (Test-Path $usrPathReg)) {
                Write-Verbose "  Creating HKCU:\Environment key as it doesn't exist."
                New-Item -Path $usrPathReg -Force | Out-Null
            }
            $usrProp = Get-ItemProperty -Path $usrPathReg -Name Path -ErrorAction SilentlyContinue
            if ($usrProp -and $usrProp.Path) {
                 $originalUserPath = $usrProp.Path
                 $pathEntries = $originalUserPath -split ';' | Where-Object { $_ -ne '' }

                 # *** CORRECTED FILTERING LOGIC ***
                 $filteredEntries = $pathEntries | Where-Object {
                    $currentEntry = $_
                    $matchCount = ($pathsToFilter | Where-Object { $currentEntry.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) } | Measure-Object).Count
                    $matchCount -eq 0
                 }

                 $newUserPathString = $filteredEntries -join ';'

                 if ($newUserPathString -ne $originalUserPath) {
                    Write-Host "  Modifying User PATH..." -ForegroundColor Yellow
                    Write-Verbose "    Old User PATH: $originalUserPath"
                    Write-Verbose "    New User PATH: $newUserPathString"
                    Set-ItemProperty -Path $usrPathReg -Name Path -Value $newUserPathString -ErrorAction Stop
                    Write-Host "    User PATH updated." -ForegroundColor Green
                    $userPathModified = $true
                } else {
                     Write-Verbose "    No changes needed for User PATH."
                }
            } else {
                 Write-Verbose "  User PATH variable not found or empty."
            }
        } catch {
            Write-Warning "  Could not process User PATH: $($_.Exception.Message)" # Error message will now be more specific if Set-ItemProperty fails
        }
         if (!$userPathModified -and $originalUserPath -ne $null) { Write-Host "  No changes made to User PATH." -ForegroundColor Green }

         if ($systemPathModified -or $userPathModified) {
             Write-Warning "  PATH changes require restarting applications or the system to take effect."
         } else {
              Write-Host "  No Cygwin-related entries found or removed from PATH variables." -ForegroundColor Green
         }

    } else {
        Write-Host "Skipping PATH modification as requested or not enabled." -ForegroundColor Green
    }
} else {
    Write-Warning "Skipping PATH modification: Cygwin installation path not found."
}
Write-Host "-----------------------------------------------------"

# 8. Find and Remove Cygwin Download Cache Folders
Write-Host "`nStep 6: Processing Cygwin download cache folders..." -ForegroundColor Cyan
$potentialCacheFolders = @()
$proceedWithCacheRemoval = $false

Write-Verbose "Searching for potential cache folders in common locations..."
foreach ($location in $CacheSearchLocations) {
    if (Test-Path $location -PathType Container) {
        Write-Verbose "  Searching in: $location"
        try {
            # Define a scriptblock to check if a folder should be excluded (i.e., it's the main install dir)
            $excludeCheck = { param($folder) $true } # Default to NOT exclude
            if ($PathFound) {
                $excludeCheck = { param($folder) $folder.FullName -ne $DetectedCygwinPath }
            }

            # Find folders matching typical cache patterns, containing x86 or x86_64 subdirs, and not being the install dir itself
            $folders = Get-ChildItem -Path $location -Directory -Depth 0 -ErrorAction SilentlyContinue |
                       Where-Object {
                           ($_.Name -like 'http*' -or $_.Name -like 'ftp*' -or $_.Name -match 'cygwin') -and # Name pattern
                           ((Test-Path (Join-Path $_.FullName 'x86_64') -PathType Container) -or (Test-Path (Join-Path $_.FullName 'x86') -PathType Container)) -and # Contains arch subdir
                           (& $excludeCheck $_) # Exclude if it's the main install path
                       }

            if ($folders) {
                $potentialCacheFolders += $folders
            }
        } catch {
            Write-Warning "   Error searching '$location' for cache folders: $($_.Exception.Message)"
        }
    } else {
        Write-Verbose "  Skipping search location (not found): $location"
    }
}

# Get unique full paths
$uniqueCachePaths = $potentialCacheFolders | Select-Object -ExpandProperty FullName -Unique

if ($uniqueCachePaths.Count -gt 0) {
    Write-Host "Found potential Cygwin download cache folders:" -ForegroundColor Yellow
    $uniqueCachePaths | ForEach-Object { Write-Host "  - $_" }

    if ($Silent.IsPresent) {
        if ($EffectiveRemoveCacheFolders) {
            Write-Host "Silent mode: Will attempt to remove cache folders." -ForegroundColor Cyan
            $proceedWithCacheRemoval = $true
        } else {
            Write-Host "Silent mode: Skipping cache folder removal (Action not enabled)." -ForegroundColor Gray
        }
    } else { # Interactive
        Write-Host ""
        $confirm = Read-Host "Do you want to DELETE these cache folders? (y/n)"
        if ($confirm -eq 'y') {
            $proceedWithCacheRemoval = $true
        }
    }

    if ($proceedWithCacheRemoval) {
        Write-Host "Proceeding with cache folder removal..." -ForegroundColor Yellow
        foreach ($cachePath in $uniqueCachePaths) {
            Write-Host "  Deleting: $cachePath..." -ForegroundColor Yellow
            try {
                Remove-Item -Path $cachePath -Recurse -Force -ErrorAction Stop
                Write-Host "    Deleted '$cachePath'." -ForegroundColor Green
            } catch {
                Write-Warning "    FAILED to delete cache folder '$cachePath': $($_.Exception.Message)"
            }
        }
    } else {
        Write-Host "Skipping cache folder removal as requested or not enabled." -ForegroundColor Green
    }
} else {
    Write-Host "No likely Cygwin download cache folders found in searched locations." -ForegroundColor Green
}
Write-Host "-----------------------------------------------------"


# 9. Find and Remove Start Menu & Desktop Shortcuts
Write-Host "`nStep 7: Processing Start Menu & Desktop shortcuts..." -ForegroundColor Cyan
$foundShortcutItems = @{ StartMenuFolders = @(); DesktopShortcuts = @() }
$proceedWithShortcutRemoval = $false

# Search Start Menu Folders
Write-Verbose "Searching for '$CygwinShortcutFolderName' folder in common Start Menu locations..."
foreach ($startMenuPath in $StartMenuPaths) {
    if (Test-Path $startMenuPath -PathType Container) {
        $cygwinFolderInStartMenu = Join-Path $startMenuPath $CygwinShortcutFolderName
        if (Test-Path $cygwinFolderInStartMenu -PathType Container) {
            Write-Verbose "Found Start Menu folder: $cygwinFolderInStartMenu"
            $foundShortcutItems.StartMenuFolders += $cygwinFolderInStartMenu
        }
    }
}

# Search Desktop Shortcuts
Write-Verbose "Searching for Cygwin shortcuts (*cygwin*.lnk) on common Desktops..."
foreach ($desktopPath in $DesktopPaths) {
    if (Test-Path $desktopPath -PathType Container) {
        try {
            $shortcuts = Get-ChildItem -Path $desktopPath -Filter "*cygwin*.lnk" -File -ErrorAction SilentlyContinue |
                         Where-Object { $_.Name -match 'cygwin' } # Double check name just in case filter is broad
            if ($shortcuts) {
                $shortcuts | ForEach-Object {
                    Write-Verbose "Found Desktop shortcut: $($_.FullName)"
                    $foundShortcutItems.DesktopShortcuts += $_.FullName
                 }
            }
        } catch {
            Write-Warning "Error searching for shortcuts in '$desktopPath': $($_.Exception.Message)"
        }
    }
}

# Consolidate findings and decide action
$totalShortcutsFound = $foundShortcutItems.StartMenuFolders.Count + $foundShortcutItems.DesktopShortcuts.Count
if ($totalShortcutsFound -gt 0) {
    Write-Host "Found potential Cygwin shortcuts/folders:" -ForegroundColor Yellow
    $foundShortcutItems.StartMenuFolders | ForEach-Object { Write-Host "  - Start Menu Folder: $_" }
    $foundShortcutItems.DesktopShortcuts | ForEach-Object { Write-Host "  - Desktop Shortcut: $_" }

    if ($Silent.IsPresent) {
        if ($EffectiveRemoveShortcuts) {
            Write-Host "Silent mode: Will attempt to remove shortcuts/folders." -ForegroundColor Cyan
            $proceedWithShortcutRemoval = $true
        } else {
            Write-Host "Silent mode: Skipping shortcut removal (Action not enabled)." -ForegroundColor Gray
        }
    } else { # Interactive
        Write-Host ""
        $confirm = Read-Host "Do you want to DELETE these shortcuts and folders? (y/n)"
        if ($confirm -eq 'y') {
            $proceedWithShortcutRemoval = $true
        }
    }

    if ($proceedWithShortcutRemoval) {
        Write-Host "Proceeding with shortcut/folder removal..." -ForegroundColor Yellow
        # Remove Start Menu Folders
        if ($foundShortcutItems.StartMenuFolders.Count -gt 0) {
            Write-Host "  Removing Start Menu folders..." -ForegroundColor Yellow
            foreach ($shortcutFolderPath in $foundShortcutItems.StartMenuFolders) {
                Write-Host "    Deleting Folder: $shortcutFolderPath..."
                try {
                    Remove-Item -Path $shortcutFolderPath -Recurse -Force -ErrorAction Stop
                    Write-Host "      Deleted." -ForegroundColor Green
                } catch {
                    Write-Warning "      FAILED to delete Start Menu folder '$shortcutFolderPath': $($_.Exception.Message)"
                }
            }
        }
        # Remove Desktop Shortcuts
        if ($foundShortcutItems.DesktopShortcuts.Count -gt 0) {
            Write-Host "  Removing Desktop shortcuts..." -ForegroundColor Yellow
            foreach ($shortcutPath in $foundShortcutItems.DesktopShortcuts) {
                 Write-Host "    Deleting Shortcut: $shortcutPath..."
                 try {
                    Remove-Item -Path $shortcutPath -Force -ErrorAction Stop
                    Write-Host "      Deleted." -ForegroundColor Green
                 } catch {
                    Write-Warning "      FAILED to delete Desktop shortcut '$shortcutPath': $($_.Exception.Message)"
                 }
            }
        }
    } else {
        Write-Host "Skipping shortcut removal as requested or not enabled." -ForegroundColor Green
    }
} else {
    Write-Host "No standard Cygwin Start Menu folders or Desktop shortcuts found." -ForegroundColor Green
}
Write-Host "-----------------------------------------------------"


# 10. Delete Cygwin Installation Directory (REQUIRES PATH and depends on LSA Reset if applicable)
Write-Host "`nStep 8: Processing main Cygwin installation directory..." -ForegroundColor Cyan
$proceedWithInstallDirRemoval = $false
$canAttemptInstallDirRemoval = $true # Assume possible unless blocked

if (-not $PathFound) {
    Write-Warning "Skipping main directory deletion: Cygwin installation path was not found."
    $canAttemptInstallDirRemoval = $false
} else {
    # --- LSA Dependency Check ---
    # If cyglsa WAS found in registry, BUT we did NOT successfully attempt/complete the reset (either user said 'n', or silent mode didn't enable it)
    if ($cygLsaFoundInRegistry -and -not $lsaModified) { # Check if modification was successful, not just attempted
        Write-Error "CRITICAL: Blocking main directory deletion because '$CygLsaPackageName' was found in LSA packages, but was NOT successfully removed."
        Write-Error "Deleting the Cygwin directory ('$DetectedCygwinPath') without removing '$CygLsaPackageName' from LSA first can cause system login failures or instability after reboot."
        Write-Warning "To remove the directory, re-run this script ensuring LSA reset is allowed and successful, then reboot."
        $canAttemptInstallDirRemoval = $false
    }
}

# Proceed only if path was found AND LSA dependency is met
if ($PathFound -and $canAttemptInstallDirRemoval) {
    if ($Silent.IsPresent) {
        if ($EffectiveRemoveInstallDir) {
            Write-Host "Silent mode: Will attempt removal of main installation directory: $DetectedCygwinPath" -ForegroundColor Cyan
            $proceedWithInstallDirRemoval = $true
        } else {
            Write-Host "Silent mode: Skipping main installation directory removal (Action not enabled)." -ForegroundColor Gray
        }
    } else { # Interactive
        Write-Warning "FINAL STEP: This will permanently delete the main Cygwin installation directory and all its contents:"
        Write-Warning "$DetectedCygwinPath"
        Write-Host ""
        $confirm = Read-Host "Are you ABSOLUTELY SURE you want to DELETE this directory? (y/n)"
        if ($confirm -eq 'y') {
            $proceedWithInstallDirRemoval = $true
        }
    }

    if ($proceedWithInstallDirRemoval) {
        Write-Host "  Attempting to delete directory '$DetectedCygwinPath'..." -ForegroundColor Red
        try {
            # Use standard Remove-Item
            Remove-Item -Path $DetectedCygwinPath -Recurse -Force -ErrorAction Stop
            Write-Host "  Directory '$DetectedCygwinPath' deleted successfully." -ForegroundColor Green
        } catch {
            Write-Error "  FAILED to delete directory '$DetectedCygwinPath': $($_.Exception.Message)"
            Write-Warning "  This often happens if files are locked by running processes (even after service stop)."
            Write-Warning "  A RESTART may be required before you can manually delete the remaining directory."
        }
    } else {
        Write-Host "Skipping main directory deletion as requested or not enabled." -ForegroundColor Green
    }
} elseif ($PathFound -and -not $canAttemptInstallDirRemoval) {
     # Message about LSA block already shown above
     Write-Host "Main directory deletion skipped due to unmet LSA dependency." -ForegroundColor Yellow
}
# Case where path not found already handled at the start of this step

# --- Final Recommendations ---
Write-Host "`n-----------------------------------------------------"
Write-Host "Cygwin removal process attempted." -ForegroundColor Green
Write-Host "-----------------------------------------------------"

if ($lsaModified) {
    Write-Host ""
    Write-Host " LSA AUTHENTICATION PACKAGES WERE MODIFIED! " -BackgroundColor Red -ForegroundColor White
    Write-Warning "A system REBOOT IS **MANDATORY** for these changes to take effect correctly and ensure system stability."
    Write-Warning "Failure to reboot after LSA changes can lead to login problems or other authentication issues."
    Write-Host ""
} else {
    # Check if any potentially impactful action was taken (even if LSA wasn't touched)
    if ($proceedWithServiceRemoval -or $proceedWithPathModification -or $proceedWithInstallDirRemoval -or $proceedWithRegistryRemoval) {
         Write-Warning "RESTART RECOMMENDED to ensure all changes (service removal, PATH updates, file locks released) take full effect."
    } else {
         Write-Host "Review the log for actions taken. A restart might still be beneficial."
    }
}

Write-Warning "Manually check your system for any remaining non-standard Cygwin shortcuts, user data (e.g., in home directories if they were outside the main install path), or environment variables if needed."

$ScriptEndTime = Get-Date
$Duration = New-TimeSpan -Start $ScriptStartTime -End $ScriptEndTime
Write-Host "`nScript execution finished at: $ScriptEndTime"
Write-Host "Total execution time: $([math]::Round($Duration.TotalSeconds, 2)) seconds."
Write-Host "-----------------------------------------------------"

Exit 0
