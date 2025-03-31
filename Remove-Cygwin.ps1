<#
.SYNOPSIS
    Stops and removes Cygwin components including services, processes, LSA package reset, shortcuts, with interactive prompts OR controlled silent operation. Enforces LSA reset before directory removal if needed.
.DESCRIPTION
    Attempts a thorough removal of Cygwin. Runs interactively by default.
    Use -Silent along with action switches for automated removal. Handles LSA package 'cyglsa' and attempts to terminate running Cygwin processes.

    Key Features:
    - Detects Cygwin path (Registry, Common Locations).
    - Stops and removes associated services.
    - **Terminates running processes originating from the Cygwin path.**
    - Removes standard Cygwin registry keys.
    - Handles 'cyglsa' LSA Authentication Package removal (REQUIRES REBOOT).
    - Removes Cygwin entries from System and User PATH variables.
    - Removes Cygwin download cache folders.
    - Removes Start Menu and Desktop shortcuts.
    - Deletes the main installation directory.

    Dependencies:
    - Removing the installation directory requires path detection and process termination.
    - Removing services requires path detection.
    - Terminating processes requires path detection.
    - Modifying PATH requires path detection.
    - **CRITICAL:** If 'cyglsa' is found registered in LSA, it *must* be reset (requires user confirmation or specific silent flags) before the main installation directory can be deleted to prevent potential system instability.

    Silent Mode:
    - Requires the -Silent switch.
    - Use action switches (-RemoveInstallDir, -RemoveRegistryKeys, etc.) to specify what to remove.
    - -RemoveAllSafe enables most removal actions (requires path detection for some).
    - -RemoveInstallDir implicitly enables -RemoveServices, -TerminateProcesses, and -ModifyPath in silent mode (if the path is found).

.PARAMETER CygwinPath
    Optional. Specify the exact root path to the Cygwin installation (e.g., "C:\cygwin64"). If provided and valid, overrides automatic detection. Required for service/process/path/install dir removal if auto-detection fails.
.PARAMETER Silent
    REQUIRED to enable any silent operation. Suppresses all interactive prompts. Action switches must also be used.
.PARAMETER RemoveInstallDir
    If -Silent is specified, deletes the main Cygwin installation directory (requires path detection). IMPLICITLY enables -RemoveServices, -TerminateProcesses, and -ModifyPath in silent mode. Requires LSA reset if cyglsa is registered.
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
    If -Silent is specified, enables -RemoveInstallDir, -RemoveRegistryKeys, -RemoveServices, -RemoveCacheFolders, -ModifyPath, -RemoveShortcuts, and -ResetLsaPackages. Actions requiring path detection will only run if the path is found. Implies process termination.

.EXAMPLE
    # Run interactively, prompting for confirmation for each step
    # Includes LSA check & enforces dependency for directory removal.
    .\Remove-Cygwin.ps1 -Verbose

.EXAMPLE
    # Run silently, removing everything possible, using auto-detected path
    # DANGEROUS: No prompts. Attempts process termination. REQUIRES REBOOT if LSA was modified.
    .\Remove-Cygwin.ps1 -Silent -RemoveAllSafe

.EXAMPLE
    # Run silently, only remove registry keys and shortcuts
    .\Remove-Cygwin.ps1 -Silent -RemoveRegistryKeys -RemoveShortcuts

.EXAMPLE
    # Run interactively, specifying the Cygwin path explicitly
    .\Remove-Cygwin.ps1 -CygwinPath "C:\Cygwin" -Verbose

.WARNING
    This script performs DESTRUCTIVE actions: deleting files, folders, services, terminating processes, removing registry keys, and modifying system settings (PATH, LSA).
    Silent mode removes all confirmation prompts. Review switches carefully.
    **BACK UP YOUR DATA before running.**
    **Run AS ADMINISTRATOR.**
    **USE AT YOUR OWN RISK.**
    **LSA modification REQUIRES A REBOOT.** Refusing LSA reset (when needed) will prevent main directory deletion.
    **BEFORE RUNNING:** If you need to preserve Cygwin mount points, run `mount -m > my_mounts.txt` in Cygwin first.

.NOTES
    Author: Assistant (AI) / Refined by User Request
    Version: 1.12 - Added process termination step, PATH fix, updated warnings.
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
$CacheSearchLocations = @(
    "$env:USERPROFILE\Downloads",
    "$env:USERPROFILE\Desktop",
    "$env:USERPROFILE"
)
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
$LsaModified = $false           # Tracks if LSA registry key was successfully changed
$CygLsaFoundInRegistry = $false # Tracks if 'cyglsa' was found in the LSA packages list initially
$LsaResetAttempted = $false     # Tracks if user confirmed or silent mode triggered LSA reset attempt
$DetectedCygwinPath = $null
$PathFound = $false

# Determine effective actions in silent mode
# Note: Some actions depend on $PathFound being true later.
$EffectiveRemoveInstallDir = $Silent.IsPresent -and ($RemoveInstallDir.IsPresent -or $RemoveAllSafe.IsPresent)
$EffectiveRemoveRegistryKeys = $Silent.IsPresent -and ($RemoveRegistryKeys.IsPresent -or $RemoveAllSafe.IsPresent)
# RemoveInstallDir implies RemoveServices, TerminateProcesses and ModifyPath in silent mode
$EffectiveRemoveServices = $Silent.IsPresent -and ($RemoveServices.IsPresent -or $EffectiveRemoveInstallDir -or $RemoveAllSafe.IsPresent)
$EffectiveTerminateProcesses = $Silent.IsPresent -and ($EffectiveRemoveInstallDir -or $RemoveAllSafe.IsPresent) # Implicitly enabled if removing install dir
$EffectiveRemoveCacheFolders = $Silent.IsPresent -and ($RemoveCacheFolders.IsPresent -or $RemoveAllSafe.IsPresent)
$EffectiveModifyPath = $Silent.IsPresent -and ($ModifyPath.IsPresent -or $EffectiveRemoveInstallDir -or $RemoveAllSafe.IsPresent)
$EffectiveRemoveShortcuts = $Silent.IsPresent -and ($RemoveShortcuts.IsPresent -or $RemoveAllSafe.IsPresent)
$EffectiveResetLsaPackages = $Silent.IsPresent -and ($ResetLsaPackages.IsPresent -or $RemoveAllSafe.IsPresent)

# --- Pre-Checks and Warnings ---

# 1. Check for Admin privileges
if (-not (Test-IsAdmin)) {
    Write-Error "This script requires Administrator privileges to modify services, processes, registry (HKLM), LSA, and system files. Please run as Administrator."
    Exit 1
}

# 2. Initial Warning and Confirmation (if not silent)
Write-Host "`n*** EXTREME WARNING ***" -ForegroundColor Red
Write-Host "This script attempts to COMPLETELY REMOVE Cygwin and related components." -ForegroundColor Yellow
Write-Host "This includes potentially deleting services, terminating processes, removing registry keys, shortcuts, LSA settings, and the main installation folder." -ForegroundColor Yellow
Write-Host "Ensure all important data within the Cygwin installation is backed up." -ForegroundColor Yellow
Write-Warning "BEFORE RUNNING: If you want to save Cygwin mount points for later re-use, run 'mount -m > my_mounts.txt' within Cygwin first. See Cygwin docs."
Write-Host "** MODIFICATION OF LSA PACKAGES REQUIRES A REBOOT! **" -ForegroundColor Red
Write-Host "** If 'cyglsa' is registered, refusing LSA reset will PREVENT main directory deletion. **" -ForegroundColor Yellow
Write-Warning "** The script will attempt to terminate running Cygwin processes to release file locks. Ensure work is saved! **"
Write-Host "There is NO UNDO feature." -ForegroundColor Yellow
Write-Host ""

if ($Silent.IsPresent) {
    Write-Host "RUNNING IN SILENT MODE. NO FURTHER PROMPTS WILL BE SHOWN." -ForegroundColor Magenta
    Write-Host "Effective actions intended by switches (some require path detection or successful LSA reset):"
    if ($EffectiveRemoveInstallDir)   { Write-Host " - RemoveInstallDir (Implies Service/Process/Path removal, requires LSA reset if applicable)" -ForegroundColor Cyan }
    if ($EffectiveRemoveRegistryKeys) { Write-Host " - RemoveRegistryKeys" -ForegroundColor Cyan }
    if ($EffectiveRemoveServices)     { Write-Host " - RemoveServices (Requires path detection)" -ForegroundColor Cyan }
    if ($EffectiveTerminateProcesses) { Write-Host " - TerminateProcesses (Implied by RemoveInstallDir/RemoveAllSafe)" -ForegroundColor Cyan }
    if ($EffectiveModifyPath)         { Write-Host " - ModifyPath (Requires path detection)" -ForegroundColor Cyan }
    if ($EffectiveResetLsaPackages)   { Write-Host " - ResetLsaPackages (REQUIRES REBOOT if changed)" -ForegroundColor Yellow }
    if ($EffectiveRemoveCacheFolders) { Write-Host " - RemoveCacheFolders" -ForegroundColor Cyan }
    if ($EffectiveRemoveShortcuts)    { Write-Host " - RemoveShortcuts (Start Menu + Desktop)" -ForegroundColor Cyan }

    if (-not ($EffectiveRemoveInstallDir `
        -or $EffectiveRemoveRegistryKeys `
        -or $EffectiveRemoveServices `
        -or $EffectiveRemoveCacheFolders `
        -or $EffectiveModifyPath `
        -or $EffectiveRemoveShortcuts `
        -or $EffectiveResetLsaPackages)) {
        Write-Warning "Silent mode specified, but no action switches (-Remove*, -RemoveAllSafe) were provided. No actions will be taken."
    }
    else {
        Write-Host "Pausing for 5 seconds before silent execution begins..." -ForegroundColor Gray
        Start-Sleep -Seconds 5
    }
}
else {
    Write-Host "Running INTERACTIVELY. You will be prompted before each major destructive action." -ForegroundColor Yellow
    $initialConfirmation = Read-Host "Do you understand the risks and wish to proceed with Cygwin removal? (y/n)"
    if ($initialConfirmation -ne 'y') {
        Write-Host "Operation cancelled by user." -ForegroundColor Green
        Exit 0
    }
}

# --- Main Removal Steps ---

# Step 1: Detect Path
Write-Host "`nStep 1: Detecting Cygwin installation path..." -ForegroundColor Cyan
# Priority 1: User-provided path
if (-not [string]::IsNullOrEmpty($CygwinPath)) {
    $NormalizedPath = $CygwinPath.TrimEnd('\')
    Write-Verbose "Checking user provided path: $NormalizedPath"
    if (Test-Path -Path $NormalizedPath -PathType Container) {
        # Check for identifying files/folders
        if ((Test-Path (Join-Path $NormalizedPath "Cygwin.bat") -PathType Leaf) -or (Test-Path (Join-Path $NormalizedPath "bin") -PathType Container)) {
            $DetectedCygwinPath = $NormalizedPath
            Write-Host "Using valid provided path: $DetectedCygwinPath" -ForegroundColor Green
            $PathFound = $true
        }
        else {
            Write-Warning "Provided path '$NormalizedPath' exists, but doesn't look like a Cygwin root (missing Cygwin.bat or bin/). Continuing detection."
        }
    }
    else {
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
                    break # Found it
                }
            }
            catch {
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
            # Check for identifying files/folders
            if ((Test-Path (Join-Path $path "Cygwin.bat") -PathType Leaf) -or (Test-Path (Join-Path $path "bin") -PathType Container)) {
                $DetectedCygwinPath = $path.TrimEnd('\')
                Write-Host "Found potential path in common location: $DetectedCygwinPath" -ForegroundColor Green
                $PathFound = $true
                break # Found it
            }
        }
    }
}
# Final Path Check Result
if (-not $PathFound) {
    Write-Warning "Could not determine Cygwin installation path automatically."
    Write-Warning "Path-dependent actions (Services, Processes, PATH, Install Dir) will be skipped unless a path was provided manually but failed validation."
    $DetectedCygwinPath = $null
}
else {
    Write-Host "Confirmed Cygwin Root Path: $DetectedCygwinPath" -ForegroundColor Cyan
}
Write-Host "-----------------------------------------------------"


# Step 2: Stop Services (REQUIRES PATH)
Write-Host "`nStep 2: Processing Cygwin services..." -ForegroundColor Cyan
$ProceedWithServiceRemoval = $false
$CygwinServices = @()
if ($PathFound) {
    Write-Verbose "Searching for services linked to path: $DetectedCygwinPath"
    try {
        $CygwinServices = Get-CimInstance Win32_Service | Where-Object { $_.PathName -like "$DetectedCygwinPath\*" } -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "Error querying services: $($_.Exception.Message)"
    }

    if ($CygwinServices.Count -gt 0) {
        Write-Host "Found potential Cygwin services:" -ForegroundColor Yellow
        $CygwinServices | ForEach-Object { Write-Host "  - $($_.Name) ($($_.DisplayName)) Path: $($_.PathName)" }
        if ($Silent.IsPresent) {
            if ($EffectiveRemoveServices) {
                Write-Host "Silent mode: Will attempt to stop and remove services." -ForegroundColor Cyan
                $ProceedWithServiceRemoval = $true
            }
            else {
                Write-Host "Silent mode: Skipping service removal (Action not enabled)." -ForegroundColor Gray
            }
        }
        else {
            Write-Host ""
            $confirm = Read-Host "Do you want to STOP and DELETE these services? (y/n)"
            if ($confirm -eq 'y') { $ProceedWithServiceRemoval = $true }
        }
    }
    else {
        Write-Host "No running services found linked to the path '$DetectedCygwinPath'." -ForegroundColor Green
    }
}
else {
    Write-Warning "Skipping service processing: Cygwin installation path not found."
}

if ($ProceedWithServiceRemoval) {
    Write-Host "Proceeding with service stop and deletion..." -ForegroundColor Yellow
    foreach ($service in $CygwinServices) {
        $serviceName = $service.Name
        Write-Host "  Processing: $serviceName"
        Write-Host "    Stopping service..." -ForegroundColor Yellow
        try {
            Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 3
            $status = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($status -and $status.Status -ne 'Stopped') {
                Write-Warning "      Service '$serviceName' did not stop gracefully after Stop-Service."
            }
            else {
                Write-Host "      Service stopped." -ForegroundColor Green
            }
        }
        catch {
            Write-Warning "      Error trying to stop service '$serviceName': $($_.Exception.Message)"
        }

        Write-Host "    Deleting service..." -ForegroundColor Yellow
        $removed = $false
        try {
            Write-Verbose "      Attempting deletion with sc.exe delete ""$serviceName"""
            $scOutput = sc.exe delete "$serviceName" 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "      Deleted successfully via sc.exe." -ForegroundColor Green
                $removed = $true
            }
            else {
                # Check for specific error code 1060 (Service does not exist)
                if ($scOutput -match '1060') {
                    Write-Host "      Service already deleted or does not exist (sc.exe error 1060)." -ForegroundColor Green
                    $removed = $true
                }
                else {
                    Write-Warning "      sc.exe delete failed for '$serviceName'. Exit Code: $LASTEXITCODE Output: $scOutput"
                }
            }
        }
        catch {
            Write-Warning "      Error executing sc.exe delete for '$serviceName': $($_.Exception.Message)"
        }

        # Fallback to Remove-Service if sc.exe failed and the cmdlet exists
        if (-not $removed -and (Get-Command Remove-Service -ErrorAction SilentlyContinue)) {
            Write-Verbose "      Attempting deletion with Remove-Service..."
            try {
                Remove-Service -Name $serviceName -Force -ErrorAction Stop
                Write-Host "      Deleted successfully via Remove-Service." -ForegroundColor Green
                $removed = $true
            }
            catch {
                Write-Warning "      Remove-Service failed for '$serviceName': $($_.Exception.Message)"
            }
        }

        if (-not $removed) {
            Write-Error "      FAILED to delete service '$serviceName'. Manual removal might be required after reboot."
        }
    }
}
elseif ($CygwinServices.Count -gt 0 -and (-not $ProceedWithServiceRemoval)) {
    Write-Host "Skipping service removal as requested or not enabled." -ForegroundColor Green
}
Write-Host "-----------------------------------------------------"


# Step 3: Terminate Running Processes (REQUIRES PATH)
Write-Host "`nStep 3: Terminating running Cygwin processes..." -ForegroundColor Cyan
$ProceedWithProcessTermination = $false
$CygwinProcesses = @()
if ($PathFound) {
    Write-Verbose "Searching for processes running from path: $DetectedCygwinPath"
    try {
        # Get all processes first, then filter
        $AllProcesses = Get-Process -ErrorAction SilentlyContinue
        $CygwinProcesses = $AllProcesses | Where-Object {
            $_.Path -ne $null -and $_.Path.StartsWith($DetectedCygwinPath, [System.StringComparison]::OrdinalIgnoreCase)
        } -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "Error querying processes: $($_.Exception.Message)"
    }

    if ($CygwinProcesses.Count -gt 0) {
        Write-Host "Found potential Cygwin processes running from the installation directory:" -ForegroundColor Yellow
        $CygwinProcesses | ForEach-Object { Write-Host ("  - PID: {0,-6} Name: {1,-15} Path: {2}" -f $_.Id, $_.Name, $_.Path) }
        if ($Silent.IsPresent) {
            if ($EffectiveTerminateProcesses) {
                Write-Host "Silent mode: Will attempt to terminate these processes." -ForegroundColor Cyan
                $ProceedWithProcessTermination = $true
            }
            else {
                Write-Host "Silent mode: Skipping process termination (Action not implicitly enabled by -RemoveInstallDir/-RemoveAllSafe)." -ForegroundColor Gray
            }
        }
        else {
            Write-Host ""
            Write-Warning "Terminating these processes can help release file locks, making directory removal more likely to succeed."
            Write-Warning "Ensure you have saved any work in these applications (e.g., mintty sessions, X applications)."
            $confirm = Read-Host "Do you want to attempt to TERMINATE these processes? (y/n)"
            if ($confirm -eq 'y') { $ProceedWithProcessTermination = $true }
        }
    }
    else {
        Write-Host "No active processes found running directly from '$DetectedCygwinPath'." -ForegroundColor Green
    }
}
else {
    Write-Warning "Skipping running process termination: Cygwin installation path not found."
}

if ($ProceedWithProcessTermination) {
    Write-Host "Proceeding with process termination..." -ForegroundColor Yellow
    foreach ($process in $CygwinProcesses) {
        Write-Host "  Terminating: $($process.Name) (PID: $($process.Id))..." -ForegroundColor Yellow
        try {
            Stop-Process -Id $process.Id -Force -ErrorAction Stop
            Write-Host "    Terminated." -ForegroundColor Green
        }
        catch {
            Write-Warning "    FAILED to terminate process $($process.Name) (PID: $($process.Id)): $($_.Exception.Message)"
        }
    }
}
elseif ($CygwinProcesses.Count -gt 0 -and (-not $ProceedWithProcessTermination)) {
    Write-Host "Skipping process termination as requested or not enabled." -ForegroundColor Green
    Write-Warning "Remaining processes might prevent successful deletion of the installation directory later."
}
Write-Host "-----------------------------------------------------"


# Step 4: Remove Registry Keys
Write-Host "`nStep 4: Processing main Cygwin registry keys..." -ForegroundColor Cyan
$RegKeysToRemove = @("HKLM:\Software\Cygwin", "HKCU:\Software\Cygwin")
$FoundRegKeys = @()
$ProceedWithRegistryRemoval = $false
foreach ($keyPath in $RegKeysToRemove) {
    if (Test-Path $keyPath) {
        $FoundRegKeys += $keyPath
    }
}
if ($FoundRegKeys.Count -gt 0) {
    Write-Host "Found standard Cygwin registry keys:" -ForegroundColor Yellow
    $FoundRegKeys | ForEach-Object { Write-Host "  - $_" }
    if ($Silent.IsPresent) {
        if ($EffectiveRemoveRegistryKeys) {
            Write-Host "Silent mode: Will attempt to remove registry keys." -ForegroundColor Cyan
            $ProceedWithRegistryRemoval = $true
        }
        else {
            Write-Host "Silent mode: Skipping registry key removal (Action not enabled)." -ForegroundColor Gray
        }
    }
    else {
        Write-Host ""
        $confirm = Read-Host "Do you want to DELETE these registry keys and their subkeys? (y/n)"
        if ($confirm -eq 'y') { $ProceedWithRegistryRemoval = $true }
    }

    if ($ProceedWithRegistryRemoval) {
        Write-Host "Proceeding with registry key removal..." -ForegroundColor Yellow
        foreach ($keyPath in $FoundRegKeys) {
            Write-Host "  Removing: $keyPath..." -ForegroundColor Yellow
            try {
                Remove-Item -Path $keyPath -Recurse -Force -ErrorAction Stop
                Write-Host "    Removed '$keyPath'." -ForegroundColor Green
            }
            catch {
                Write-Warning "    FAILED to remove registry key '$keyPath': $($_.Exception.Message)"
            }
        }
    }
    else {
        Write-Host "Skipping registry key removal as requested or not enabled." -ForegroundColor Green
    }
}
else {
    Write-Host "No standard Cygwin registry keys found at HKLM/HKCU:\Software\Cygwin." -ForegroundColor Green
}
Write-Host "-----------------------------------------------------"


# Step 5: Reset LSA Authentication Packages
Write-Host "`nStep 5: Processing LSA Authentication Packages..." -ForegroundColor Cyan
$ProceedWithLsaReset = $false
$CurrentLsaPackages = $null
try {
    $lsaProp = Get-ItemProperty -Path $LsaRegKeyPath -Name $LsaValueName -ErrorAction SilentlyContinue
    if ($lsaProp -ne $null) {
        $CurrentLsaPackages = @($lsaProp.$LsaValueName)
        if ($CurrentLsaPackages -contains $CygLsaPackageName) {
            $CygLsaFoundInRegistry = $true
            Write-Host "Found '$CygLsaPackageName' in LSA Authentication Packages." -ForegroundColor Yellow
            Write-Host "  Current Value: $($CurrentLsaPackages -join ', ')"
        }
        else {
            Write-Host "'$CygLsaPackageName' not found in LSA Authentication Packages." -ForegroundColor Green
        }
    }
    else {
        Write-Host "LSA Authentication Packages value not found or registry key unreadable. Skipping LSA modification." -ForegroundColor Green
    }
}
catch {
    Write-Warning "Could not read LSA Packages key '$LsaRegKeyPath': $($_.Exception.Message). Skipping LSA modification."
}

if ($CygLsaFoundInRegistry) {
    if ($Silent.IsPresent) {
        if ($EffectiveResetLsaPackages) {
            Write-Warning "Silent mode: Proceeding with LSA package reset. REBOOT WILL BE MANDATORY."
            $ProceedWithLsaReset = $true
            $LsaResetAttempted = $true
        }
        else {
            Write-Warning "Silent mode: '$CygLsaPackageName' found but reset not enabled via -ResetLsaPackages or -RemoveAllSafe."
            Write-Warning "Main Cygwin directory deletion will be BLOCKED due to potential system instability."
            $ProceedWithLsaReset = $false
        }
    }
    else {
        Write-Warning "Modifying LSA Authentication Packages is a sensitive operation."
        Write-Warning "Removing '$CygLsaPackageName' requires a system REBOOT afterwards."
        Write-Warning "If you used Cygwin features requiring LSA (like SSHD with certain auth types), this is necessary."
        Write-Warning "Refusing this step will PREVENT the main Cygwin directory from being deleted later."
        Write-Host ""
        $confirm = Read-Host "Remove '$CygLsaPackageName' from LSA Packages? (REBOOT REQUIRED) (y/n)"
        if ($confirm -eq 'y') {
            $ProceedWithLsaReset = $true
            $LsaResetAttempted = $true
        }
        else {
            $ProceedWithLsaReset = $false
        }
    }

    if ($ProceedWithLsaReset) {
        $NewLsaPackages = $CurrentLsaPackages | Where-Object { $_ -ne $CygLsaPackageName }
        # --- CRITICAL SAFETY CHECK ---
        if ($NewLsaPackages -contains $CoreLsaPackage) {
            Write-Host "  New LSA Package list will be: $($NewLsaPackages -join ', ')" -ForegroundColor Cyan
            Write-Host "  Attempting registry update..." -ForegroundColor Yellow
            try {
                Set-ItemProperty -Path $LsaRegKeyPath -Name $LsaValueName -Value $NewLsaPackages -Type MultiString -Force -ErrorAction Stop
                Write-Host "  LSA Packages updated successfully in registry." -ForegroundColor Green
                $LsaModified = $true
            }
            catch {
                Write-Error "  FAILED to update LSA Packages key '$LsaRegKeyPath': $($_.Exception.Message)"
                Write-Error "  LSA settings may be in an inconsistent state. Manual check recommended."
                $LsaModified = $false
            }
        }
        else {
            Write-Error "  CRITICAL ERROR: Core LSA package '$CoreLsaPackage' would be removed. Aborting LSA modification."
            Write-Error "  Original LSA Packages: $($CurrentLsaPackages -join ', ')"
            $ProceedWithLsaReset = $false # Ensure we don't proceed based on this failure
            $LsaModified = $false
        }
    }
    else {
        Write-Host "Skipping LSA package reset." -ForegroundColor Green
        if ($CygLsaFoundInRegistry) {
            Write-Warning "Reminder: '$CygLsaPackageName' remains in LSA. Main directory deletion will be blocked."
        }
    }
}
Write-Host "-----------------------------------------------------"


# Step 6: Remove Cygwin from PATH environment variables (REQUIRES PATH)
Write-Host "`nStep 6: Processing PATH environment variables..." -ForegroundColor Cyan
$ProceedWithPathModification = $false
if ($PathFound) {
    if ($Silent.IsPresent) {
        if ($EffectiveModifyPath) {
            Write-Host "Silent mode: Will attempt PATH modification." -ForegroundColor Cyan
            $ProceedWithPathModification = $true
        }
        else {
            Write-Host "Silent mode: Skipping PATH modification (Action not enabled)." -ForegroundColor Gray
        }
    }
    else {
        Write-Host "Detected Cygwin Path: $DetectedCygwinPath"
        Write-Host "This step will remove entries related to this path from System and User PATH variables."
        Write-Host ""
        $confirm = Read-Host "Do you want to modify System and User PATH variables? (y/n)"
        if ($confirm -eq 'y') { $ProceedWithPathModification = $true }
    }

    if ($ProceedWithPathModification) {
        Write-Host "Proceeding with PATH modification..." -ForegroundColor Yellow
        $CygwinBinPath = Join-Path $DetectedCygwinPath "bin"
        $PathsToFilter = @($DetectedCygwinPath, $CygwinBinPath)
        Write-Verbose "Will filter PATH entries starting with: $($PathsToFilter -join ', ')"

        # --- Process System PATH ---
        Write-Verbose "Processing System PATH..."
        $sysPathReg = "Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment"
        $OriginalSystemPath = $null
        $SystemPathModified = $false
        try {
            $sysProp = Get-ItemProperty -Path $sysPathReg -Name Path -ErrorAction SilentlyContinue
            if ($sysProp -and $sysProp.Path) {
                $OriginalSystemPath = $sysProp.Path
                $pathEntries = $OriginalSystemPath -split ';' | Where-Object { $_ -ne '' }
                $filteredEntries = $pathEntries | Where-Object {
                    $currentEntry = $_
                    $matchCount = ($PathsToFilter | Where-Object { $currentEntry.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) } | Measure-Object).Count
                    $matchCount -eq 0 # Keep if no match found
                }
                $NewSystemPathString = $filteredEntries -join ';'

                if ($NewSystemPathString -ne $OriginalSystemPath) {
                    Write-Host "  Modifying System PATH..." -ForegroundColor Yellow
                    Write-Verbose "    Old System PATH: $OriginalSystemPath"
                    Write-Verbose "    New System PATH: $NewSystemPathString"
                    Set-ItemProperty -Path $sysPathReg -Name Path -Value $NewSystemPathString -ErrorAction Stop
                    Write-Host "    System PATH updated." -ForegroundColor Green
                    $SystemPathModified = $true
                }
                else {
                    Write-Verbose "    No changes needed for System PATH."
                }
            }
            else {
                Write-Verbose "  System PATH variable not found or empty."
            }
        }
        catch {
            Write-Warning "  Could not process System PATH: $($_.Exception.Message)"
        }
        if (-not $SystemPathModified -and $OriginalSystemPath -ne $null) {
            Write-Host "  No changes made to System PATH." -ForegroundColor Green
        }

        # --- Process User PATH ---
        Write-Verbose "Processing User PATH..."
        $usrPathReg = "Registry::HKEY_CURRENT_USER\Environment"
        $OriginalUserPath = $null
        $UserPathModified = $false
        try {
            # Ensure the Environment key exists for the current user
            if (-not (Test-Path $usrPathReg)) {
                Write-Verbose "  Creating HKCU:\Environment key as it doesn't exist."
                New-Item -Path $usrPathReg -Force | Out-Null
            }
            $usrProp = Get-ItemProperty -Path $usrPathReg -Name Path -ErrorAction SilentlyContinue
            if ($usrProp -and $usrProp.Path) {
                $OriginalUserPath = $usrProp.Path
                $pathEntries = $OriginalUserPath -split ';' | Where-Object { $_ -ne '' }
                $filteredEntries = $pathEntries | Where-Object {
                    $currentEntry = $_
                    $matchCount = ($PathsToFilter | Where-Object { $currentEntry.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) } | Measure-Object).Count
                    $matchCount -eq 0 # Keep if no match found
                }
                $NewUserPathString = $filteredEntries -join ';'

                if ($NewUserPathString -ne $OriginalUserPath) {
                    Write-Host "  Modifying User PATH..." -ForegroundColor Yellow
                    Write-Verbose "    Old User PATH: $OriginalUserPath"
                    Write-Verbose "    New User PATH: $NewUserPathString"
                    Set-ItemProperty -Path $usrPathReg -Name Path -Value $NewUserPathString -ErrorAction Stop
                    Write-Host "    User PATH updated." -ForegroundColor Green
                    $UserPathModified = $true
                }
                else {
                    Write-Verbose "    No changes needed for User PATH."
                }
            }
            else {
                Write-Verbose "  User PATH variable not found or empty."
            }
        }
        catch {
            Write-Warning "  Could not process User PATH: $($_.Exception.Message)"
        }
        if (-not $UserPathModified -and $OriginalUserPath -ne $null) {
            Write-Host "  No changes made to User PATH." -ForegroundColor Green
        }

        if ($SystemPathModified -or $UserPathModified) {
            Write-Warning "  PATH changes require restarting applications or the system to take effect."
        }
        else {
            Write-Host "  No Cygwin-related entries found or removed from PATH variables." -ForegroundColor Green
        }
    }
    else {
        Write-Host "Skipping PATH modification as requested or not enabled." -ForegroundColor Green
    }
}
else {
    Write-Warning "Skipping PATH modification: Cygwin installation path not found."
}
Write-Host "-----------------------------------------------------"


# Step 7: Find and Remove Cygwin Download Cache Folders
Write-Host "`nStep 7: Processing Cygwin download cache folders..." -ForegroundColor Cyan
$PotentialCacheFolders = @()
$ProceedWithCacheRemoval = $false
Write-Verbose "Searching for potential cache folders in common locations..."
foreach ($location in $CacheSearchLocations) {
    if (Test-Path $location -PathType Container) {
        Write-Verbose "  Searching in: $location"
        try {
            # Define a check to exclude the main install dir from being identified as a cache dir
            $excludeCheck = { param($folder) $true }
            if ($PathFound) {
                $excludeCheck = { param($folder) $folder.FullName -ne $DetectedCygwinPath }
            }

            # Heuristic search for cache folders
            $folders = Get-ChildItem -Path $location -Directory -Depth 0 -ErrorAction SilentlyContinue | Where-Object {
                (
                    $_.Name -like 'http*' -or
                    $_.Name -like 'ftp*' -or
                    $_.Name -match 'cygwin' # Match name containing 'cygwin'
                ) -and (
                    (Test-Path (Join-Path $_.FullName 'x86_64') -PathType Container) -or
                    (Test-Path (Join-Path $_.FullName 'x86') -PathType Container) # Look for x86 or x86_64 subdirs
                ) -and (
                    & $excludeCheck $_ # Ensure it's not the main install dir
                )
            }
            if ($folders) {
                $PotentialCacheFolders += $folders
            }
        }
        catch {
            Write-Warning "   Error searching '$location' for cache folders: $($_.Exception.Message)"
        }
    }
    else {
        Write-Verbose "  Skipping search location (not found): $location"
    }
}

$UniqueCachePaths = $PotentialCacheFolders | Select-Object -ExpandProperty FullName -Unique
if ($UniqueCachePaths.Count -gt 0) {
    Write-Host "Found potential Cygwin download cache folders:" -ForegroundColor Yellow
    $UniqueCachePaths | ForEach-Object { Write-Host "  - $_" }
    if ($Silent.IsPresent) {
        if ($EffectiveRemoveCacheFolders) {
            Write-Host "Silent mode: Will attempt to remove cache folders." -ForegroundColor Cyan
            $ProceedWithCacheRemoval = $true
        }
        else {
            Write-Host "Silent mode: Skipping cache folder removal (Action not enabled)." -ForegroundColor Gray
        }
    }
    else {
        Write-Host ""
        $confirm = Read-Host "Do you want to DELETE these cache folders? (y/n)"
        if ($confirm -eq 'y') { $ProceedWithCacheRemoval = $true }
    }

    if ($ProceedWithCacheRemoval) {
        Write-Host "Proceeding with cache folder removal..." -ForegroundColor Yellow
        foreach ($cachePath in $UniqueCachePaths) {
            Write-Host "  Deleting: $cachePath..." -ForegroundColor Yellow
            try {
                Remove-Item -Path $cachePath -Recurse -Force -ErrorAction Stop
                Write-Host "    Deleted '$cachePath'." -ForegroundColor Green
            }
            catch {
                Write-Warning "    FAILED to delete cache folder '$cachePath': $($_.Exception.Message)"
            }
        }
    }
    else {
        Write-Host "Skipping cache folder removal as requested or not enabled." -ForegroundColor Green
    }
}
else {
    Write-Host "No likely Cygwin download cache folders found in searched locations." -ForegroundColor Green
}
Write-Host "-----------------------------------------------------"


# Step 8: Find and Remove Start Menu & Desktop Shortcuts
Write-Host "`nStep 8: Processing Start Menu & Desktop shortcuts..." -ForegroundColor Cyan
$FoundShortcutItems = @{ StartMenuFolders = @(); DesktopShortcuts = @() }
$ProceedWithShortcutRemoval = $false

# Search Start Menu Folders
Write-Verbose "Searching for '$CygwinShortcutFolderName' folder in common Start Menu locations..."
foreach ($startMenuPath in $StartMenuPaths) {
    if (Test-Path $startMenuPath -PathType Container) {
        $cygwinFolderInStartMenu = Join-Path $startMenuPath $CygwinShortcutFolderName
        if (Test-Path $cygwinFolderInStartMenu -PathType Container) {
            Write-Verbose "Found Start Menu folder: $cygwinFolderInStartMenu"
            $FoundShortcutItems.StartMenuFolders += $cygwinFolderInStartMenu
        }
    }
}

# Search Desktop Shortcuts
Write-Verbose "Searching for Cygwin shortcuts (*cygwin*.lnk) on common Desktops..."
foreach ($desktopPath in $DesktopPaths) {
    if (Test-Path $desktopPath -PathType Container) {
        try {
            $shortcuts = Get-ChildItem -Path $desktopPath -Filter "*cygwin*.lnk" -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'cygwin' }
            if ($shortcuts) {
                $shortcuts | ForEach-Object {
                    Write-Verbose "Found Desktop shortcut: $($_.FullName)"
                    $FoundShortcutItems.DesktopShortcuts += $_.FullName
                }
            }
        }
        catch {
            Write-Warning "Error searching for shortcuts in '$desktopPath': $($_.Exception.Message)"
        }
    }
}

$TotalShortcutsFound = $FoundShortcutItems.StartMenuFolders.Count + $FoundShortcutItems.DesktopShortcuts.Count
if ($TotalShortcutsFound -gt 0) {
    Write-Host "Found potential Cygwin shortcuts/folders:" -ForegroundColor Yellow
    $FoundShortcutItems.StartMenuFolders | ForEach-Object { Write-Host "  - Start Menu Folder: $_" }
    $FoundShortcutItems.DesktopShortcuts | ForEach-Object { Write-Host "  - Desktop Shortcut: $_" }

    if ($Silent.IsPresent) {
        if ($EffectiveRemoveShortcuts) {
            Write-Host "Silent mode: Will attempt to remove shortcuts/folders." -ForegroundColor Cyan
            $ProceedWithShortcutRemoval = $true
        }
        else {
            Write-Host "Silent mode: Skipping shortcut removal (Action not enabled)." -ForegroundColor Gray
        }
    }
    else {
        Write-Host ""
        $confirm = Read-Host "Do you want to DELETE these shortcuts and folders? (y/n)"
        if ($confirm -eq 'y') { $ProceedWithShortcutRemoval = $true }
    }

    if ($ProceedWithShortcutRemoval) {
        Write-Host "Proceeding with shortcut/folder removal..." -ForegroundColor Yellow
        if ($FoundShortcutItems.StartMenuFolders.Count -gt 0) {
            Write-Host "  Removing Start Menu folders..." -ForegroundColor Yellow
            foreach ($shortcutFolderPath in $FoundShortcutItems.StartMenuFolders) {
                Write-Host "    Deleting Folder: $shortcutFolderPath..."
                try {
                    Remove-Item -Path $shortcutFolderPath -Recurse -Force -ErrorAction Stop
                    Write-Host "      Deleted." -ForegroundColor Green
                }
                catch {
                    Write-Warning "      FAILED to delete Start Menu folder '$shortcutFolderPath': $($_.Exception.Message)"
                }
            }
        }
        if ($FoundShortcutItems.DesktopShortcuts.Count -gt 0) {
            Write-Host "  Removing Desktop shortcuts..." -ForegroundColor Yellow
            foreach ($shortcutPath in $FoundShortcutItems.DesktopShortcuts) {
                Write-Host "    Deleting Shortcut: $shortcutPath..."
                try {
                    Remove-Item -Path $shortcutPath -Force -ErrorAction Stop
                    Write-Host "      Deleted." -ForegroundColor Green
                }
                catch {
                    Write-Warning "      FAILED to delete Desktop shortcut '$shortcutPath': $($_.Exception.Message)"
                }
            }
        }
    }
    else {
        Write-Host "Skipping shortcut removal as requested or not enabled." -ForegroundColor Green
    }
}
else {
    Write-Host "No standard Cygwin Start Menu folders or Desktop shortcuts found." -ForegroundColor Green
}
Write-Host "-----------------------------------------------------"


# Step 9: Delete Cygwin Installation Directory (REQUIRES PATH and depends on LSA Reset & Process Termination)
Write-Host "`nStep 9: Processing main Cygwin installation directory..." -ForegroundColor Cyan
$ProceedWithInstallDirRemoval = $false
$CanAttemptInstallDirRemoval = $true

if (-not $PathFound) {
    Write-Warning "Skipping main directory deletion: Cygwin installation path was not found."
    $CanAttemptInstallDirRemoval = $false
}
else {
    # --- LSA Dependency Check ---
    if ($CygLsaFoundInRegistry -and -not $LsaModified) {
        Write-Error "CRITICAL: Blocking main directory deletion because '$CygLsaPackageName' was found in LSA packages, but was NOT successfully removed."
        Write-Error "Deleting the Cygwin directory ('$DetectedCygwinPath') without removing '$CygLsaPackageName' from LSA first can cause system login failures or instability after reboot."
        Write-Warning "To remove the directory, re-run this script ensuring LSA reset is allowed and successful, then reboot."
        $CanAttemptInstallDirRemoval = $false
    }
}

if ($PathFound -and $CanAttemptInstallDirRemoval) {
    if ($Silent.IsPresent) {
        if ($EffectiveRemoveInstallDir) {
            Write-Host "Silent mode: Will attempt removal of main installation directory: $DetectedCygwinPath" -ForegroundColor Cyan
            $ProceedWithInstallDirRemoval = $true
        }
        else {
            Write-Host "Silent mode: Skipping main installation directory removal (Action not enabled)." -ForegroundColor Gray
        }
    }
    else {
        Write-Warning "FINAL STEP: This will permanently delete the main Cygwin installation directory and all its contents:"
        Write-Warning "$DetectedCygwinPath"
        Write-Warning "(Success depends on files not being locked - processes were terminated in Step 3 if allowed)."
        Write-Host ""
        $confirm = Read-Host "Are you ABSOLUTELY SURE you want to DELETE this directory? (y/n)"
        if ($confirm -eq 'y') { $ProceedWithInstallDirRemoval = $true }
    }

    if ($ProceedWithInstallDirRemoval) {
        Write-Host "  Attempting to delete directory '$DetectedCygwinPath'..." -ForegroundColor Red
        try {
            Remove-Item -Path $DetectedCygwinPath -Recurse -Force -ErrorAction Stop
            Write-Host "  Directory '$DetectedCygwinPath' deleted successfully." -ForegroundColor Green
        }
        catch {
            Write-Error "  FAILED to delete directory '$DetectedCygwinPath': $($_.Exception.Message)"
            Write-Warning "  This often happens if files are locked by processes missed by termination or system handles."
            Write-Warning "  A RESTART may be required before you can manually delete the remaining directory."
        }
    }
    else {
        Write-Host "Skipping main directory deletion as requested or not enabled." -ForegroundColor Green
    }
}
elseif ($PathFound -and -not $CanAttemptInstallDirRemoval) {
    # Message already shown by the LSA dependency check
    Write-Host "Main directory deletion skipped due to unmet LSA dependency." -ForegroundColor Yellow
}

# --- Final Recommendations ---
Write-Host "`n-----------------------------------------------------"
Write-Host "Cygwin removal process attempted." -ForegroundColor Green
Write-Host "-----------------------------------------------------"
if ($LsaModified) {
    Write-Host ""
    Write-Host " LSA AUTHENTICATION PACKAGES WERE MODIFIED! " -BackgroundColor Red -ForegroundColor White
    Write-Warning "A system REBOOT IS **MANDATORY** for these changes to take effect correctly and ensure system stability."
    Write-Warning "Failure to reboot after LSA changes can lead to login problems or other authentication issues."
    Write-Host ""
}
else {
    # Recommend restart if significant actions were attempted, even if LSA wasn't changed
    if ($ProceedWithServiceRemoval `
        -or $ProceedWithPathModification `
        -or $ProceedWithInstallDirRemoval `
        -or $ProceedWithRegistryRemoval `
        -or $ProceedWithProcessTermination) {
        Write-Warning "RESTART RECOMMENDED to ensure all changes (service removal, process termination, PATH updates, file locks released) take full effect."
    }
    else {
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
