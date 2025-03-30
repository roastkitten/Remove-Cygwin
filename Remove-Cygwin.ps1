<#
.SYNOPSIS
    Stops and removes Cygwin components including Start Menu shortcuts, with interactive prompts OR controlled silent operation.
.DESCRIPTION
    Attempts a thorough removal of Cygwin. Runs interactively by default.
    Use -Silent along with action switches for automated removal. Service/Path/Shortcut removal requires path detection or specific locations.
    -RemoveInstallDir implies -RemoveServices and -ModifyPath in silent mode (if path found).
    -RemoveAllSafe enables most removal actions safely in silent mode (requires path for some actions).
.PARAMETER CygwinPath
    Optional. Specify the exact root path to the Cygwin installation (e.g., "C:\cygwin64"). Required for service/path removal.
.PARAMETER Silent
    REQUIRED to enable any silent operation. Suppresses interactive prompts.
.PARAMETER RemoveInstallDir
    If -Silent is specified, deletes the main Cygwin installation directory (requires path detection). IMPLICITLY enables -RemoveServices and -ModifyPath in silent mode.
.PARAMETER RemoveRegistryKeys
    If -Silent is specified, deletes standard Cygwin registry keys.
.PARAMETER RemoveServices
    If -Silent is specified, stops and deletes Cygwin services (requires path detection). Also implicitly enabled by -RemoveInstallDir in silent mode.
.PARAMETER RemoveCacheFolders
    If -Silent is specified, deletes detected Cygwin download cache folders.
.PARAMETER ModifyPath
    If -Silent is specified, removes Cygwin entries from System and User PATH variables (requires path detection). Also implicitly enabled by -RemoveInstallDir in silent mode.
.PARAMETER RemoveShortcuts
    If -Silent is specified, removes the 'Cygwin' folder from common Start Menu locations.
.PARAMETER RemoveAllSafe
    If -Silent is specified, enables -RemoveInstallDir, -RemoveRegistryKeys, -RemoveServices, -RemoveCacheFolders, -ModifyPath, and -RemoveShortcuts (actions requiring path detection will only run if path is found).
.EXAMPLE
    # Run interactively, prompting for confirmation
    .\Remove-Cygwin.ps1

    # Run silently, removing ONLY registry keys and Start Menu shortcuts
    .\Remove-Cygwin.ps1 -Silent -RemoveRegistryKeys -RemoveShortcuts

    # Run silently using the safe 'all' switch (DANGEROUS, requires path detection for some actions)
    .\Remove-Cygwin.ps1 -Silent -RemoveAllSafe

.WARNING
    This script is highly destructive. Silent mode removes prompts. Review switches carefully. BACK UP YOUR DATA. Run AS ADMINISTRATOR. Use at your own risk.
.NOTES
    Author: Assistant (AI)
    Version: 1.7 - Added Start Menu shortcut removal (-RemoveShortcuts, updated -RemoveAllSafe).
#>
param (
    [string]$CygwinPath = "",
    [switch]$Silent,
    [switch]$RemoveInstallDir,
    [switch]$RemoveRegistryKeys,
    [switch]$RemoveServices,
    [switch]$RemoveCacheFolders,
    [switch]$ModifyPath,
    [switch]$RemoveShortcuts, # New switch
    [switch]$RemoveAllSafe
)

# --- Start Configuration ---
$CommonCygwinPaths = @("C:\cygwin64", "C:\cygwin")
$CacheSearchLocations = @("$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop", "$env:USERPROFILE")
$StartMenuPaths = @(
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs", # All Users
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"      # Current User
)
$CygwinShortcutFolderName = "Cygwin" # Standard folder name created by installer
# --- End Configuration ---

# Function to check for Admin privileges
function Test-IsAdmin {
    try { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent(); $principal = [System.Security.Principal.WindowsPrincipal]::new($identity); return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator) }
    catch { Write-Warning "Could not determine admin status."; return $false }
}

# --- Initialization ---
$ScriptStartTime = Get-Date

# Determine effective actions in silent mode
$EffectiveRemoveInstallDir = $Silent -and ($RemoveInstallDir.IsPresent -or $RemoveAllSafe.IsPresent)
$EffectiveRemoveRegistryKeys = $Silent -and ($RemoveRegistryKeys.IsPresent -or $RemoveAllSafe.IsPresent)
$EffectiveRemoveServices = $Silent -and ($RemoveServices.IsPresent -or $RemoveInstallDir.IsPresent -or $RemoveAllSafe.IsPresent)
$EffectiveRemoveCacheFolders = $Silent -and ($RemoveCacheFolders.IsPresent -or $RemoveAllSafe.IsPresent)
$EffectiveModifyPath = $Silent -and ($ModifyPath.IsPresent -or $RemoveInstallDir.IsPresent -or $RemoveAllSafe.IsPresent)
$EffectiveRemoveShortcuts = $Silent -and ($RemoveShortcuts.IsPresent -or $RemoveAllSafe.IsPresent) # Added

# 1. Check for Admin privileges
if (-not (Test-IsAdmin)) { Write-Error "Run as Administrator."; Exit 1 }

# 2. Initial Warning and Confirmation (if not silent)
Write-Host "*** EXTREME WARNING ***" -ForegroundColor Red
Write-Host "This script will attempt to COMPLETELY REMOVE Cygwin and related components." -ForegroundColor Yellow
if ($Silent) {
    Write-Host "RUNNING IN SILENT MODE." -ForegroundColor Magenta
    Write-Host "Effective actions intended by switches (some require path detection):"
    if ($EffectiveRemoveInstallDir) { Write-Host " - RemoveInstallDir (Implies Service/Path removal if path found)" -ForegroundColor Cyan }
    if ($EffectiveRemoveRegistryKeys) { Write-Host " - RemoveRegistryKeys" -ForegroundColor Cyan }
    if ($EffectiveRemoveServices) { Write-Host " - RemoveServices (Requires path detection)" -ForegroundColor Cyan }
    if ($EffectiveRemoveCacheFolders) { Write-Host " - RemoveCacheFolders" -ForegroundColor Cyan }
    if ($EffectiveModifyPath) { Write-Host " - ModifyPath (Requires path detection)" -ForegroundColor Cyan }
    if ($EffectiveRemoveShortcuts) { Write-Host " - RemoveShortcuts (Start Menu)" -ForegroundColor Cyan } # Added
    if (-not ($EffectiveRemoveInstallDir -or $EffectiveRemoveRegistryKeys -or $EffectiveRemoveServices -or $EffectiveRemoveCacheFolders -or $EffectiveModifyPath -or $EffectiveRemoveShortcuts)) { # Added Shortcuts check
         Write-Warning "Silent mode specified, but no effective actions enabled by switches. No destructive actions will be taken."
    }
} else { Write-Host "Running interactively. It will prompt before each major destructive action." -ForegroundColor Yellow }
Write-Host "This includes DELETING services, registry keys, shortcuts, and files/folders. THERE IS NO UNDO." -ForegroundColor Yellow
Write-Host "Ensure important data is backed up elsewhere." -ForegroundColor Yellow
Write-Host ""

if (-not $Silent) {
    $initialConfirmation = Read-Host "Are you sure you want to begin the Cygwin removal process interactively? (y/n)"
    if ($initialConfirmation -ne 'y') { Write-Host "Operation cancelled."; Exit 0 }
} else { Write-Host "Pausing for 5 seconds before proceeding in silent mode..."; Start-Sleep -Seconds 5 }

# 3. Determine Cygwin Installation Path (Warn but continue if not found)
Write-Host "`nStep 1: Attempting to detect Cygwin installation path..." -ForegroundColor Cyan
$DetectedCygwinPath = $null
$PathFound = $false
# (Detection logic remains the same...)
if (-not [string]::IsNullOrEmpty($CygwinPath)) { if (Test-Path -Path $CygwinPath -PathType Container) { $DetectedCygwinPath = $CygwinPath.TrimEnd('\'); Write-Host "Using provided Cygwin path: $DetectedCygwinPath" -ForegroundColor Cyan; $PathFound = $true } else { Write-Warning "Provided path '$CygwinPath' not found. Attempting auto-detection." } }
if (-not $PathFound) { $regKeyPaths = @("HKLM:\Software\Cygwin\setup", "HKCU:\Software\Cygwin\setup"); foreach ($keyPath in $regKeyPaths) { if (Test-Path $keyPath) { $regValue = Get-ItemProperty -Path $keyPath -Name "rootdir" -ErrorAction SilentlyContinue; if ($regValue -and $regValue.rootdir -and (Test-Path $regValue.rootdir -PathType Container)) { $DetectedCygwinPath = $regValue.rootdir.TrimEnd('\'); Write-Host "Found path in Registry ($keyPath): $DetectedCygwinPath" -ForegroundColor Green; $PathFound = $true; break } } } }
if (-not $PathFound) { Write-Host "Checking common locations..."; foreach ($path in $CommonCygwinPaths) { if (Test-Path -Path $path -PathType Container) { if (Test-Path (Join-Path $path "Cygwin.bat") -PathType Leaf -or Test-Path (Join-Path $path "bin") -PathType Container) { $DetectedCygwinPath = $path.TrimEnd('\'); Write-Host "Found potential path: $DetectedCygwinPath" -ForegroundColor Green; $PathFound = $true; break } } } }

if (-not $PathFound) { Write-Warning "Could not determine Cygwin installation path. Actions requiring path (-ModifyPath, -RemoveInstallDir, -RemoveServices) will be skipped."; $DetectedCygwinPath = $null }
else { Write-Host "Confirmed Cygwin Root Path: $DetectedCygwinPath" -ForegroundColor Cyan }

# --- Removal Steps ---

# 4. Stop and Remove Cygwin Services (REQUIRES PATH)
Write-Host "`nStep 2: Processing Cygwin services..." -ForegroundColor Cyan
$proceedWithServiceRemoval = $false; $cygwinServices = @()
if ($PathFound) {
    Write-Host "Searching for services linked to path: $DetectedCygwinPath"
    $cygwinServices = Get-CimInstance Win32_Service | Where-Object { $_.PathName -like "$DetectedCygwinPath\*" } -ErrorAction SilentlyContinue
    if ($cygwinServices.Count -gt 0) {
        Write-Host "Found potential Cygwin services:" -ForegroundColor Yellow; $cygwinServices | ForEach-Object { Write-Host "  - $($_.Name) ($($_.DisplayName)) - Path: $($_.PathName)" }
        if ($Silent) { if ($EffectiveRemoveServices) { Write-Host "Silent mode: Proceeding with service removal." -ForegroundColor Cyan; $proceedWithServiceRemoval = $true } else { Write-Host "Silent mode: Skipping service removal (action not enabled)." -ForegroundColor Gray } }
        else { Write-Host ""; $confirm = Read-Host "STOP and DELETE these services? (y/n)"; if ($confirm -eq 'y') { $proceedWithServiceRemoval = $true } }
    } else { Write-Host "No services found linked to path '$DetectedCygwinPath'." -ForegroundColor Green }
} else { Write-Warning "Skipping service processing because Cygwin installation path was not found." }
if ($proceedWithServiceRemoval) {
    Write-Host "Proceeding with service stop and deletion..." -ForegroundColor Yellow
    foreach ($service in $cygwinServices) { $serviceName = $service.Name; Write-Host "  Processing service: $serviceName"; Write-Host "    Stopping..." -ForegroundColor Yellow; Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 2; $status = Get-Service -Name $serviceName -ErrorAction SilentlyContinue; if ($status -and $status.Status -ne 'Stopped'){Write-Warning "      Not stopped gracefully."}else{Write-Host "      Stopped." -ForegroundColor Green}; Write-Host "    Deleting..." -ForegroundColor Yellow; $removed = $false; try { $deleteResult = sc.exe delete "$serviceName" 2>&1; if($LASTEXITCODE -eq 0){Write-Host "      Deleted via sc.exe." -ForegroundColor Green; $removed = $true} else {Write-Warning "      sc.exe delete failed: $deleteResult"}} catch {Write-Warning "      Error sc.exe: $($_.Exception.Message)"}; if (-not $removed -and (Get-Command Remove-Service -ErrorAction SilentlyContinue)) { Write-Host "      Attempting Remove-Service..."; try { Remove-Service -Name $serviceName -Force -ErrorAction Stop; Write-Host "      Deleted via Remove-Service." -ForegroundColor Green; $removed = $true } catch { Write-Warning "      Remove-Service failed: $($_.Exception.Message)" }}; if (-not $removed) { Write-Error "      FAILED to delete service '$serviceName'." } }
} elseif ($cygwinServices.Count -gt 0 -and (-not $proceedWithServiceRemoval)) { Write-Host "Skipping service removal." -ForegroundColor Green }


# 5. Remove Registry Keys
Write-Host "`nStep 3: Processing Cygwin registry keys..." -ForegroundColor Cyan
# (Registry logic remains the same)
$regKeysToRemove = @("HKLM:\Software\Cygwin", "HKCU:\Software\Cygwin"); $foundRegKeys = @(); foreach ($keyPath in $regKeysToRemove) { if (Test-Path $keyPath) { $foundRegKeys += $keyPath } }
if ($foundRegKeys.Count -gt 0) { Write-Host "Found potential Cygwin registry keys:" -ForegroundColor Yellow; $foundRegKeys | ForEach-Object { Write-Host "  - $_" }; $proceedWithRegistryRemoval = $false; if ($Silent) { if ($EffectiveRemoveRegistryKeys) { Write-Host "Silent mode: Proceeding." -ForegroundColor Cyan; $proceedWithRegistryRemoval = $true } else { Write-Host "Silent mode: Skipping." -ForegroundColor Gray } } else { Write-Host ""; $confirm = Read-Host "DELETE these registry keys? (y/n)"; if ($confirm -eq 'y') { $proceedWithRegistryRemoval = $true } }; if ($proceedWithRegistryRemoval) { Write-Host "Proceeding..." -ForegroundColor Yellow; foreach ($keyPath in $foundRegKeys) { Write-Host "  Removing: $keyPath..." -ForegroundColor Yellow; try { Remove-Item -Path $keyPath -Recurse -Force -ErrorAction Stop; Write-Host "    Removed." -ForegroundColor Green } catch { Write-Warning "    Failed: $($_.Exception.Message)" } } } else { Write-Host "Skipping registry key removal." -ForegroundColor Green } }
else { Write-Host "No standard Cygwin registry keys found." -ForegroundColor Green }


# 6. Remove Cygwin from PATH environment variables (REQUIRES PATH)
Write-Host "`nStep 4: Processing PATH environment variables..." -ForegroundColor Cyan
# (PATH logic remains the same)
$proceedWithPathModification = $false
if ($PathFound) { if ($Silent) { if ($EffectiveModifyPath) { Write-Host "Silent mode: Proceeding." -ForegroundColor Cyan; $proceedWithPathModification = $true } else { Write-Host "Silent mode: Skipping." -ForegroundColor Gray } } else { Write-Host "Path found: $DetectedCygwinPath"; Write-Host ""; $confirm = Read-Host "Modify PATH variables? (y/n)"; if ($confirm -eq 'y') { $proceedWithPathModification = $true } }; if ($proceedWithPathModification) { $cygwinBinPath = Join-Path $DetectedCygwinPath "bin"; try { $sysPathReg = "Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment"; $systemPath = (Get-ItemProperty -Path $sysPathReg -Name Path -ErrorAction SilentlyContinue).Path; if ($systemPath) { $originalSystemPath = $systemPath; $newSystemPath = ($systemPath -split ';') | Where-Object {$_ -ne '' -and -not $_.StartsWith($cygwinBinPath,[System.StringComparison]::OrdinalIgnoreCase) -and -not $_.StartsWith($DetectedCygwinPath,[System.StringComparison]::OrdinalIgnoreCase)} | Sort-Object | Get-Unique; $newSystemPathString = $newSystemPath -join ';'; if ($newSystemPathString.Length -ne $originalSystemPath.Length) { Write-Host "  Modifying System PATH..." -ForegroundColor Yellow; Set-ItemProperty -Path $sysPathReg -Name Path -Value $newSystemPathString; Write-Host "  System PATH modified." -ForegroundColor Green } else { Write-Host "  No changes needed for System PATH." } } else { Write-Host "  System PATH not found." } } catch { Write-Warning "  Could not process System PATH: $($_.Exception.Message)" }; try { $usrPathReg = "Registry::HKEY_CURRENT_USER\Environment"; if (-not (Test-Path $usrPathReg)) { New-Item -Path $usrPathReg -Force | Out-Null } $userPath = (Get-ItemProperty -Path $usrPathReg -Name Path -ErrorAction SilentlyContinue).Path; if ($userPath) { $originalUserPath = $userPath; $newUserPath = ($userPath -split ';') | Where-Object {$_ -ne '' -and -not $_.StartsWith($cygwinBinPath,[System.StringComparison]::OrdinalIgnoreCase) -and -not $_.StartsWith($DetectedCygwinPath,[System.StringComparison]::OrdinalIgnoreCase)} | Sort-Object | Get-Unique; $newUserPathString = $newUserPath -join ';'; if ($newUserPathString.Length -ne $originalUserPath.Length) { Write-Host "  Modifying User PATH..." -ForegroundColor Yellow; Set-ItemProperty -Path $usrPathReg -Name Path -Value $newUserPathString; Write-Host "  User PATH modified." -ForegroundColor Green } else { Write-Host "  No changes needed for User PATH." } } else { Write-Host "  User PATH not found or empty." } } catch { Write-Warning "  Could not process User PATH: $($_.Exception.Message)" } } else { Write-Host "Skipping PATH modification." -ForegroundColor Green } }
else { Write-Warning "Skipping PATH modification because Cygwin installation path was not found." }


# 7. Find and Remove Cygwin Download Cache Folders
Write-Host "`nStep 5: Processing Cygwin download cache folders..." -ForegroundColor Cyan
# (Cache logic remains the same)
$potentialCacheFolders = @(); foreach ($location in $CacheSearchLocations) { if (Test-Path $location) { Write-Host "  Searching: $location" -ForegroundColor Gray; try { $excludePathCheck = if ($PathFound) { { $_.FullName -ne $DetectedCygwinPath } } else { { $true } }; $folders = Get-ChildItem -Path $location -Directory -Depth 0 -ErrorAction SilentlyContinue | Where-Object { ($_.Name -like 'http*' -or $_.Name -like 'ftp*' -or $_.Name -match 'cygwin') -and ((Test-Path (Join-Path $_.FullName 'x86_64') -PathType Container) -or (Test-Path (Join-Path $_.FullName 'x86') -PathType Container)) -and (& $excludePathCheck) }; if ($folders) { $potentialCacheFolders += $folders } } catch { Write-Warning "   Error searching '$location': $($_.Exception.Message)" } } else { Write-Host "  Skipping: $location" -ForegroundColor Gray } }
$uniqueCachePaths = $potentialCacheFolders | Select-Object -ExpandProperty FullName -Unique
if ($uniqueCachePaths.Count -gt 0) { Write-Host "Found potential Cygwin download cache folders:" -ForegroundColor Yellow; $uniqueCachePaths | ForEach-Object { Write-Host "  - $_" }; $proceedWithCacheRemoval = $false; if ($Silent) { if ($EffectiveRemoveCacheFolders) { Write-Host "Silent mode: Proceeding." -ForegroundColor Cyan; $proceedWithCacheRemoval = $true } else { Write-Host "Silent mode: Skipping." -ForegroundColor Gray } } else { Write-Host ""; $confirm = Read-Host "DELETE these cache folders? (y/n)"; if ($confirm -eq 'y') { $proceedWithCacheRemoval = $true } }; if ($proceedWithCacheRemoval) { Write-Host "Proceeding..." -ForegroundColor Yellow; foreach ($cachePath in $uniqueCachePaths) { Write-Host "  Deleting: $cachePath..." -ForegroundColor Yellow; try { Remove-Item -Path $cachePath -Recurse -Force -ErrorAction Stop; Write-Host "    Deleted." -ForegroundColor Green } catch { Write-Warning "    Failed: $($_.Exception.Message)" } } } else { Write-Host "Skipping cache folder removal." -ForegroundColor Green } }
else { Write-Host "No likely Cygwin download cache folders found." -ForegroundColor Green }


# 8. Find and Remove Start Menu Shortcuts --- NEW STEP ---
Write-Host "`nStep 6: Processing Start Menu shortcuts..." -ForegroundColor Cyan
$foundShortcutFolders = @()
foreach ($startMenuPath in $StartMenuPaths) {
    $cygwinFolderInStartMenu = Join-Path $startMenuPath $CygwinShortcutFolderName
    if (Test-Path $cygwinFolderInStartMenu -PathType Container) {
        Write-Host "Found potential Cygwin Start Menu folder: $cygwinFolderInStartMenu" -ForegroundColor Yellow
        $foundShortcutFolders += $cygwinFolderInStartMenu
    }
}

if ($foundShortcutFolders.Count -gt 0) {
    $proceedWithShortcutRemoval = $false
    if ($Silent) {
        if ($EffectiveRemoveShortcuts) { Write-Host "Silent mode: Proceeding with Start Menu shortcut folder removal." -ForegroundColor Cyan; $proceedWithShortcutRemoval = $true }
        else { Write-Host "Silent mode: Skipping Start Menu shortcut folder removal (action not enabled)." -ForegroundColor Gray }
    } else { # Interactive
        Write-Host ""; $confirm = Read-Host "Do you want to DELETE these Start Menu folders (and their contents)? (y/n)"
        if ($confirm -eq 'y') { $proceedWithShortcutRemoval = $true }
    }

    if ($proceedWithShortcutRemoval) {
        Write-Host "Proceeding with Start Menu folder removal..." -ForegroundColor Yellow
        foreach ($shortcutFolderPath in $foundShortcutFolders) {
            Write-Host "  Deleting folder: $shortcutFolderPath..." -ForegroundColor Yellow
            try { Remove-Item -Path $shortcutFolderPath -Recurse -Force -ErrorAction Stop; Write-Host "    Folder '$shortcutFolderPath' deleted successfully." -ForegroundColor Green }
            catch { Write-Warning "    FAILED to delete folder '$shortcutFolderPath': $($_.Exception.Message)" }
        }
    } else {
        Write-Host "Skipping Start Menu shortcut folder removal." -ForegroundColor Green
    }
} else {
    Write-Host "No '$CygwinShortcutFolderName' folder found in standard Start Menu locations." -ForegroundColor Green
}


# 9. Delete Cygwin Installation Directory (REQUIRES PATH)
Write-Host "`nStep 7: Processing main Cygwin installation directory..." -ForegroundColor Cyan # Step Number Updated
# (Install Dir logic remains the same)
$proceedWithInstallDirRemoval = $false
if ($PathFound) { if ($Silent) { if ($EffectiveRemoveInstallDir) { Write-Host "Silent mode: Proceeding." -ForegroundColor Cyan; $proceedWithInstallDirRemoval = $true } else { Write-Host "Silent mode: Skipping." -ForegroundColor Gray } } else { Write-Warning "Final Step: Permanently delete: $DetectedCygwinPath"; Write-Host ""; $confirm = Read-Host "DELETE '$DetectedCygwinPath'? (y/n)"; if ($confirm -eq 'y') { $proceedWithInstallDirRemoval = $true } }; if ($proceedWithInstallDirRemoval) { Write-Host "  Deleting: $DetectedCygwinPath..." -ForegroundColor Red; try { Remove-Item -Path $DetectedCygwinPath -Recurse -Force -ErrorAction Stop; Write-Host "  Deleted." -ForegroundColor Green } catch { Write-Error "  FAILED: $($_.Exception.Message)"; Write-Warning "  RESTART may be required." } } else { Write-Host "Skipping." -ForegroundColor Green } }
else { Write-Warning "Skipping main directory deletion because Cygwin installation path was not found." }


# 10. Recommend Restart (Step Number Updated)
Write-Host "`nCygwin removal process complete." -ForegroundColor Green
Write-Host "-----------------------------------------------------"
Write-Warning "RESTART STRONGLY RECOMMENDED."
Write-Warning "Manually check Desktop for any remaining Cygwin shortcuts." # Adjusted message slightly
$ScriptEndTime = Get-Date; $Duration = New-TimeSpan -Start $ScriptStartTime -End $ScriptEndTime
Write-Host "Script execution time: $($Duration.TotalSeconds) seconds."
Write-Host "-----------------------------------------------------"

Exit 0
