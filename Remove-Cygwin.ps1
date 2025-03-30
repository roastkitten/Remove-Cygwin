<#
.SYNOPSIS
    Stops and removes Cygwin components including Start Menu and Desktop shortcuts, with interactive prompts OR controlled silent operation.
.DESCRIPTION
    Attempts a thorough removal of Cygwin. Runs interactively by default.
    Use -Silent along with action switches for automated removal. Service/Path/Install Dir removal requires path detection.
    -RemoveInstallDir implies -RemoveServices and -ModifyPath in silent mode (if path found).
    -RemoveAllSafe enables most removal actions safely in silent mode.
.PARAMETER CygwinPath
    Optional. Specify the exact root path to the Cygwin installation (e.g., "C:\cygwin64"). Required for service/path/install dir removal.
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
    If -Silent is specified, removes the 'Cygwin' folder from common Start Menu locations AND Cygwin-named shortcuts from common Desktop locations. Implied by -RemoveAllSafe.
.PARAMETER RemoveAllSafe
    If -Silent is specified, enables -RemoveInstallDir, -RemoveRegistryKeys, -RemoveServices, -RemoveCacheFolders, -ModifyPath, and -RemoveShortcuts (actions requiring path detection will only run if path is found).
.EXAMPLE
    # Run interactively, prompting for confirmation
    .\Remove-Cygwin.ps1

    # Run silently, removing ONLY registry keys and shortcuts (Start Menu + Desktop)
    .\Remove-Cygwin.ps1 -Silent -RemoveRegistryKeys -RemoveShortcuts

    # Run silently using the safe 'all' switch (DANGEROUS, requires path detection for some actions)
    .\Remove-Cygwin.ps1 -Silent -RemoveAllSafe

.WARNING
    This script is highly destructive. Silent mode removes prompts. Review switches carefully. BACK UP YOUR DATA. Run AS ADMINISTRATOR. Use at your own risk.
.NOTES
    Author: Assistant (AI)
    Version: 1.8 - Added Desktop shortcut removal to -RemoveShortcuts, code formatting.
#>
param (
    [string]$CygwinPath = "",
    [switch]$Silent,
    [switch]$RemoveInstallDir,
    [switch]$RemoveRegistryKeys,
    [switch]$RemoveServices,
    [switch]$RemoveCacheFolders,
    [switch]$ModifyPath,
    [switch]$RemoveShortcuts,
    [switch]$RemoveAllSafe
)

# --- Start Configuration ---
$CommonCygwinPaths = @(
    "C:\cygwin64",
    "C:\cygwin"
)
$CacheSearchLocations = @(
    "$env:USERPROFILE\Downloads",
    "$env:USERPROFILE\Desktop",
    "$env:USERPROFILE"
)
$StartMenuPaths = @(
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs", # All Users
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"      # Current User
)
$DesktopPaths = @(
    "$env:PUBLIC\Desktop",                                    # All Users
    "$env:USERPROFILE\Desktop"                                # Current User
)
$CygwinShortcutFolderName = "Cygwin" # Standard folder name in Start Menu
# --- End Configuration ---

# Function to check for Admin privileges
function Test-IsAdmin {
    try {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [System.Security.Principal.WindowsPrincipal]::new($identity)
        return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        Write-Warning "Could not determine administrator status."
        return $false
    }
}

# --- Initialization ---
$ScriptStartTime = Get-Date

# Determine effective actions in silent mode
$EffectiveRemoveInstallDir = $Silent -and ($RemoveInstallDir.IsPresent -or $RemoveAllSafe.IsPresent)
$EffectiveRemoveRegistryKeys = $Silent -and ($RemoveRegistryKeys.IsPresent -or $RemoveAllSafe.IsPresent)
$EffectiveRemoveServices = $Silent -and ($RemoveServices.IsPresent -or $RemoveInstallDir.IsPresent -or $RemoveAllSafe.IsPresent)
$EffectiveRemoveCacheFolders = $Silent -and ($RemoveCacheFolders.IsPresent -or $RemoveAllSafe.IsPresent)
$EffectiveModifyPath = $Silent -and ($ModifyPath.IsPresent -or $RemoveInstallDir.IsPresent -or $RemoveAllSafe.IsPresent)
$EffectiveRemoveShortcuts = $Silent -and ($RemoveShortcuts.IsPresent -or $RemoveAllSafe.IsPresent)

# 1. Check for Admin privileges
if (-not (Test-IsAdmin)) {
    Write-Error "This script must be run with Administrator privileges. Please re-run as Administrator."
    Exit 1
}

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
    if ($EffectiveRemoveShortcuts) { Write-Host " - RemoveShortcuts (Start Menu + Desktop)" -ForegroundColor Cyan }
    if (-not ($EffectiveRemoveInstallDir -or $EffectiveRemoveRegistryKeys -or $EffectiveRemoveServices -or $EffectiveRemoveCacheFolders -or $EffectiveModifyPath -or $EffectiveRemoveShortcuts)) {
        Write-Warning "Silent mode specified, but no effective actions enabled by switches. No destructive actions will be taken."
    }
} else {
    Write-Host "Running interactively. It will prompt before each major destructive action." -ForegroundColor Yellow
}
Write-Host "This includes DELETING services, registry keys, shortcuts, and files/folders. THERE IS NO UNDO." -ForegroundColor Yellow
Write-Host "Ensure important data is backed up elsewhere." -ForegroundColor Yellow
Write-Host ""

if (-not $Silent) {
    $initialConfirmation = Read-Host "Are you sure you want to begin the Cygwin removal process interactively? (y/n)"
    if ($initialConfirmation -ne 'y') {
        Write-Host "Operation cancelled by user." -ForegroundColor Green
        Exit 0
    }
} else {
    Write-Host "Pausing for 5 seconds before proceeding in silent mode..."
    Start-Sleep -Seconds 5
}

# 3. Determine Cygwin Installation Path (Warn but continue if not found)
Write-Host "`nStep 1: Attempting to detect Cygwin installation path..." -ForegroundColor Cyan
$DetectedCygwinPath = $null
$PathFound = $false

if (-not [string]::IsNullOrEmpty($CygwinPath)) {
    if (Test-Path -Path $CygwinPath -PathType Container) {
        $DetectedCygwinPath = $CygwinPath.TrimEnd('\')
        Write-Host "Using provided Cygwin path: $DetectedCygwinPath" -ForegroundColor Cyan
        $PathFound = $true
    } else {
        Write-Warning "Provided path '$CygwinPath' does not exist or is not a directory. Attempting auto-detection."
    }
}

if (-not $PathFound) {
    $regKeyPaths = @(
        "HKLM:\Software\Cygwin\setup",
        "HKCU:\Software\Cygwin\setup"
    )
    foreach ($keyPath in $regKeyPaths) {
        if (Test-Path $keyPath) {
            $regValue = Get-ItemProperty -Path $keyPath -Name "rootdir" -ErrorAction SilentlyContinue
            if ($regValue -and $regValue.rootdir -and (Test-Path $regValue.rootdir -PathType Container)) {
                $DetectedCygwinPath = $regValue.rootdir.TrimEnd('\')
                Write-Host "Found Cygwin path in Registry ($keyPath): $DetectedCygwinPath" -ForegroundColor Green
                $PathFound = $true
                break
            }
        }
    }
}

if (-not $PathFound) {
    Write-Host "Checking common locations..." -ForegroundColor Cyan
    foreach ($path in $CommonCygwinPaths) {
        if (Test-Path -Path $path -PathType Container) {
            if (Test-Path (Join-Path $path "Cygwin.bat") -PathType Leaf -or Test-Path (Join-Path $path "bin") -PathType Container) {
                $DetectedCygwinPath = $path.TrimEnd('\')
                Write-Host "Found potential Cygwin path: $DetectedCygwinPath" -ForegroundColor Green
                $PathFound = $true
                break
            }
        }
    }
}

if (-not $PathFound) {
    Write-Warning "Could not determine the Cygwin installation path."
    Write-Warning "Actions requiring the path (-ModifyPath, -RemoveInstallDir, -RemoveServices) will be skipped."
    $DetectedCygwinPath = $null
} else {
    Write-Host "Confirmed Cygwin Root Path: $DetectedCygwinPath" -ForegroundColor Cyan
}

# --- Removal Steps ---

# 4. Stop and Remove Cygwin Services (REQUIRES PATH)
Write-Host "`nStep 2: Processing Cygwin services..." -ForegroundColor Cyan
$proceedWithServiceRemoval = $false
$cygwinServices = @()

if ($PathFound) {
    Write-Host "Searching for services linked to path: $DetectedCygwinPath"
    $cygwinServices = Get-CimInstance Win32_Service | Where-Object { $_.PathName -like "$DetectedCygwinPath\*" } -ErrorAction SilentlyContinue

    if ($cygwinServices.Count -gt 0) {
        Write-Host "Found potential Cygwin services:" -ForegroundColor Yellow
        $cygwinServices | ForEach-Object { Write-Host "  - $($_.Name) ($($_.DisplayName)) - Path: $($_.PathName)" }

        if ($Silent) {
            if ($EffectiveRemoveServices) {
                Write-Host "Silent mode: Proceeding with service removal." -ForegroundColor Cyan
                $proceedWithServiceRemoval = $true
            } else {
                Write-Host "Silent mode: Skipping service removal (action not enabled)." -ForegroundColor Gray
            }
        } else { # Interactive mode
            Write-Host ""
            $confirm = Read-Host "Do you want to STOP and DELETE these services? (y/n)"
            if ($confirm -eq 'y') {
                $proceedWithServiceRemoval = $true
            }
        }
    } else {
        Write-Host "No services found linked to path '$DetectedCygwinPath'." -ForegroundColor Green
    }
} else {
    Write-Warning "Skipping service processing because Cygwin installation path was not found."
}

# Execute service removal if confirmed/enabled
if ($proceedWithServiceRemoval) {
    Write-Host "Proceeding with service stop and deletion..." -ForegroundColor Yellow
    foreach ($service in $cygwinServices) {
        $serviceName = $service.Name
        Write-Host "  Processing service: $serviceName"

        # Stop
        Write-Host "    Stopping service..." -ForegroundColor Yellow
        Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2 # Give service time to stop
        $status = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($status -and $status.Status -ne 'Stopped') {
            Write-Warning "      Service '$serviceName' may not have stopped gracefully."
        } else {
            Write-Host "      Service '$serviceName' stopped." -ForegroundColor Green
        }

        # Remove/Delete
        Write-Host "    Deleting service registration..." -ForegroundColor Yellow
        $removed = $false
        try {
            # Using sc.exe delete is often more reliable
            $deleteResult = sc.exe delete "$serviceName" 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "      Service '$serviceName' deleted successfully via sc.exe." -ForegroundColor Green
                $removed = $true
            } else {
                Write-Warning "      sc.exe delete failed for '$serviceName'. Output: $deleteResult"
            }
        } catch {
            Write-Warning "      An error occurred using sc.exe delete for '$serviceName': $($_.Exception.Message)"
        }

        # Fallback using Remove-Service if sc.exe failed and cmdlet exists
        if (-not $removed -and (Get-Command Remove-Service -ErrorAction SilentlyContinue)) {
            Write-Host "      Attempting fallback deletion with Remove-Service for '$serviceName'..."
            try {
                Remove-Service -Name $serviceName -Force -ErrorAction Stop
                Write-Host "      Service '$serviceName' deleted successfully via Remove-Service." -ForegroundColor Green
                $removed = $true
            } catch {
                Write-Warning "      Remove-Service failed for '$serviceName': $($_.Exception.Message)"
            }
        }

        if (-not $removed) {
            Write-Error "      FAILED to delete service '$serviceName' using available methods."
        }
    }
} elseif ($cygwinServices.Count -gt 0 -and (-not $proceedWithServiceRemoval)) {
    # Log if services were found but removal was skipped
    Write-Host "Skipping service removal." -ForegroundColor Green
}

# 5. Remove Registry Keys
Write-Host "`nStep 3: Processing Cygwin registry keys..." -ForegroundColor Cyan
$regKeysToRemove = @(
    "HKLM:\Software\Cygwin",
    "HKCU:\Software\Cygwin"
)
$foundRegKeys = @()
foreach ($keyPath in $regKeysToRemove) {
    if (Test-Path $keyPath) {
        $foundRegKeys += $keyPath
    }
}

if ($foundRegKeys.Count -gt 0) {
    Write-Host "Found potential Cygwin registry keys:" -ForegroundColor Yellow
    $foundRegKeys | ForEach-Object { Write-Host "  - $_" }

    $proceedWithRegistryRemoval = $false
    if ($Silent) {
        if ($EffectiveRemoveRegistryKeys) {
            Write-Host "Silent mode: Proceeding with registry key removal." -ForegroundColor Cyan
            $proceedWithRegistryRemoval = $true
        } else {
            Write-Host "Silent mode: Skipping registry key removal (action not enabled)." -ForegroundColor Gray
        }
    } else { # Interactive
        Write-Host ""
        $confirm = Read-Host "Do you want to DELETE these registry keys (and their subkeys)? (y/n)"
        if ($confirm -eq 'y') {
            $proceedWithRegistryRemoval = $true
        }
    }

    if ($proceedWithRegistryRemoval) {
        Write-Host "Proceeding with registry key removal..." -ForegroundColor Yellow
        foreach ($keyPath in $foundRegKeys) {
            Write-Host "  Removing registry key: $keyPath..." -ForegroundColor Yellow
            try {
                Remove-Item -Path $keyPath -Recurse -Force -ErrorAction Stop
                Write-Host "    Registry key '$keyPath' removed." -ForegroundColor Green
            } catch {
                Write-Warning "    Could not remove registry key '$keyPath': $($_.Exception.Message)"
            }
        }
    } else {
        Write-Host "Skipping registry key removal." -ForegroundColor Green
    }
} else {
    Write-Host "No standard Cygwin registry keys found." -ForegroundColor Green
}

# 6. Remove Cygwin from PATH environment variables (REQUIRES PATH)
Write-Host "`nStep 4: Processing PATH environment variables..." -ForegroundColor Cyan
$proceedWithPathModification = $false

if ($PathFound) {
    if ($Silent) {
        if ($EffectiveModifyPath) {
            Write-Host "Silent mode: Proceeding with PATH modification." -ForegroundColor Cyan
            $proceedWithPathModification = $true
        } else {
            Write-Host "Silent mode: Skipping PATH modification (action not enabled)." -ForegroundColor Gray
        }
    } else { # Interactive
        Write-Host "Found Cygwin path: $DetectedCygwinPath"
        Write-Host "Entries matching this path or its '/bin' subdirectory will be removed from System and User PATH."
        Write-Host ""
        $confirm = Read-Host "Do you want to modify the System and User PATH variables? (y/n)"
        if ($confirm -eq 'y') {
            $proceedWithPathModification = $true
        }
    }

    if ($proceedWithPathModification) {
        $cygwinBinPath = Join-Path $DetectedCygwinPath "bin"

        # Process System PATH
        try {
            $sysPathReg = "Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment"
            $systemPath = (Get-ItemProperty -Path $sysPathReg -Name Path -ErrorAction SilentlyContinue).Path
            if ($systemPath) {
                $originalSystemPath = $systemPath
                $newSystemPath = ($systemPath -split ';') | Where-Object {
                    $_ -ne '' -and `
                    -not $_.StartsWith($cygwinBinPath, [System.StringComparison]::OrdinalIgnoreCase) -and `
                    -not $_.StartsWith($DetectedCygwinPath, [System.StringComparison]::OrdinalIgnoreCase)
                } | Sort-Object | Get-Unique
                $newSystemPathString = $newSystemPath -join ';'

                if ($newSystemPathString.Length -ne $originalSystemPath.Length) {
                    Write-Host "  Modifying System PATH..." -ForegroundColor Yellow
                    Set-ItemProperty -Path $sysPathReg -Name Path -Value $newSystemPathString
                    Write-Host "  System PATH modified (requires restart/re-login)." -ForegroundColor Green
                } else {
                    Write-Host "  No Cygwin entries found in System PATH."
                }
            } else {
                Write-Host "  System PATH variable not found or accessible in registry."
            }
        } catch {
            Write-Warning "  Could not process System PATH: $($_.Exception.Message)"
        }

        # Process User PATH
        try {
            $usrPathReg = "Registry::HKEY_CURRENT_USER\Environment"
            # Ensure the key exists before trying to get/set properties
            if (-not (Test-Path $usrPathReg)) {
                New-Item -Path $usrPathReg -Force | Out-Null
            }
            $userPath = (Get-ItemProperty -Path $usrPathReg -Name Path -ErrorAction SilentlyContinue).Path
            if ($userPath) {
                $originalUserPath = $userPath
                $newUserPath = ($userPath -split ';') | Where-Object {
                    $_ -ne '' -and `
                    -not $_.StartsWith($cygwinBinPath, [System.StringComparison]::OrdinalIgnoreCase) -and `
                    -not $_.StartsWith($DetectedCygwinPath, [System.StringComparison]::OrdinalIgnoreCase)
                } | Sort-Object | Get-Unique
                $newUserPathString = $newUserPath -join ';'

                if ($newUserPathString.Length -ne $originalUserPath.Length) {
                    Write-Host "  Modifying User PATH..." -ForegroundColor Yellow
                    Set-ItemProperty -Path $usrPathReg -Name Path -Value $newUserPathString
                    Write-Host "  User PATH modified (requires restart/re-login)." -ForegroundColor Green
                } else {
                    Write-Host "  No Cygwin entries found in User PATH."
                }
            } else {
                Write-Host "  User PATH variable not found or empty."
            }
        } catch {
            Write-Warning "  Could not process User PATH: $($_.Exception.Message)"
        }
    } else {
        Write-Host "Skipping PATH modification." -ForegroundColor Green
    }
} else {
    Write-Warning "Skipping PATH modification because Cygwin installation path was not found."
}

# 7. Find and Remove Cygwin Download Cache Folders
Write-Host "`nStep 5: Processing Cygwin download cache folders..." -ForegroundColor Cyan
$potentialCacheFolders = @()
foreach ($location in $CacheSearchLocations) {
    if (Test-Path $location) {
        Write-Host "  Searching in: $location" -ForegroundColor Gray
        try {
            # Define exclusion logic based on whether path was found
            $excludePathCheck = if ($PathFound) { { $_.FullName -ne $DetectedCygwinPath } } else { { $true } }

            $folders = Get-ChildItem -Path $location -Directory -Depth 0 -ErrorAction SilentlyContinue | Where-Object {
                ($_.Name -like 'http*' -or $_.Name -like 'ftp*' -or $_.Name -match 'cygwin') -and `
                ((Test-Path (Join-Path $_.FullName 'x86_64') -PathType Container) -or (Test-Path (Join-Path $_.FullName 'x86') -PathType Container)) -and `
                (& $excludePathCheck) # Dynamically apply the exclusion check
            }
            if ($folders) {
                $potentialCacheFolders += $folders
            }
        } catch {
            Write-Warning "   Error searching in '$location': $($_.Exception.Message)"
        }
    } else {
        Write-Host "  Skipping non-existent location: $location" -ForegroundColor Gray
    }
}

$uniqueCachePaths = $potentialCacheFolders | Select-Object -ExpandProperty FullName -Unique

if ($uniqueCachePaths.Count -gt 0) {
    Write-Host "Found potential Cygwin download cache folders:" -ForegroundColor Yellow
    $uniqueCachePaths | ForEach-Object { Write-Host "  - $_" }

    $proceedWithCacheRemoval = $false
    if ($Silent) {
        if ($EffectiveRemoveCacheFolders) {
            Write-Host "Silent mode: Proceeding with cache folder removal." -ForegroundColor Cyan
            $proceedWithCacheRemoval = $true
        } else {
            Write-Host "Silent mode: Skipping cache folder removal (action not enabled)." -ForegroundColor Gray
        }
    } else { # Interactive
        Write-Host ""
        $confirm = Read-Host "Do you want to DELETE these potential cache folders? (y/n)"
        if ($confirm -eq 'y') {
            $proceedWithCacheRemoval = $true
        }
    }

    if ($proceedWithCacheRemoval) {
        Write-Host "Proceeding with cache folder removal..." -ForegroundColor Yellow
        foreach ($cachePath in $uniqueCachePaths) {
            Write-Host "  Deleting folder: $cachePath..." -ForegroundColor Yellow
            try {
                Remove-Item -Path $cachePath -Recurse -Force -ErrorAction Stop
                Write-Host "    Folder '$cachePath' deleted successfully." -ForegroundColor Green
            } catch {
                Write-Warning "    FAILED to delete folder '$cachePath': $($_.Exception.Message)"
            }
        }
    } else {
        Write-Host "Skipping potential cache folder removal." -ForegroundColor Green
    }
} else {
    Write-Host "No likely Cygwin download cache folders found in specified search locations." -ForegroundColor Green
}

# 8. Find and Remove Start Menu & Desktop Shortcuts
Write-Host "`nStep 6: Processing Start Menu & Desktop shortcuts..." -ForegroundColor Cyan
$foundShortcutFolders = @() # Start Menu Folders
$foundDesktopShortcuts = @() # Desktop .lnk Files

# Find Start Menu Folders
foreach ($startMenuPath in $StartMenuPaths) {
    if (Test-Path $startMenuPath -PathType Container) {
         $cygwinFolderInStartMenu = Join-Path $startMenuPath $CygwinShortcutFolderName
        if (Test-Path $cygwinFolderInStartMenu -PathType Container) {
            Write-Host "Found potential Cygwin Start Menu folder: $cygwinFolderInStartMenu" -ForegroundColor Yellow
            $foundShortcutFolders += $cygwinFolderInStartMenu
        }
    }
}

# Find Desktop Shortcuts
foreach ($desktopPath in $DesktopPaths) {
    if (Test-Path $desktopPath -PathType Container) {
        try {
            $shortcuts = Get-ChildItem -Path $desktopPath -Filter "*.lnk" -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'cygwin' }
            if ($shortcuts) {
                $shortcuts | ForEach-Object {
                     Write-Host "Found potential Cygwin Desktop shortcut: $($_.FullName)" -ForegroundColor Yellow
                     $foundDesktopShortcuts += $_.FullName
                }
            }
        } catch {
             Write-Warning "Error searching for shortcuts in '$desktopPath': $($_.Exception.Message)"
        }
    }
}


if ($foundShortcutFolders.Count -gt 0 -or $foundDesktopShortcuts.Count -gt 0) {
    $proceedWithShortcutRemoval = $false
    if ($Silent) {
        if ($EffectiveRemoveShortcuts) {
            Write-Host "Silent mode: Proceeding with Start Menu/Desktop shortcut removal." -ForegroundColor Cyan
            $proceedWithShortcutRemoval = $true
        } else {
            Write-Host "Silent mode: Skipping Start Menu/Desktop shortcut removal (action not enabled)." -ForegroundColor Gray
        }
    } else { # Interactive
        Write-Host ""
        $confirm = Read-Host "Do you want to DELETE these Start Menu folders and Desktop shortcuts? (y/n)"
        if ($confirm -eq 'y') {
            $proceedWithShortcutRemoval = $true
        }
    }

    if ($proceedWithShortcutRemoval) {
        # Remove Start Menu Folders
        if ($foundShortcutFolders.Count -gt 0) {
            Write-Host "Proceeding with Start Menu folder removal..." -ForegroundColor Yellow
            foreach ($shortcutFolderPath in $foundShortcutFolders) {
                Write-Host "  Deleting folder: $shortcutFolderPath..." -ForegroundColor Yellow
                try {
                    Remove-Item -Path $shortcutFolderPath -Recurse -Force -ErrorAction Stop
                    Write-Host "    Folder '$shortcutFolderPath' deleted successfully." -ForegroundColor Green
                } catch {
                    Write-Warning "    FAILED to delete folder '$shortcutFolderPath': $($_.Exception.Message)"
                }
            }
        }
         # Remove Desktop Shortcuts
        if ($foundDesktopShortcuts.Count -gt 0) {
            Write-Host "Proceeding with Desktop shortcut removal..." -ForegroundColor Yellow
            foreach ($shortcutPath in $foundDesktopShortcuts) {
                Write-Host "  Deleting file: $shortcutPath..." -ForegroundColor Yellow
                try {
                    Remove-Item -Path $shortcutPath -Force -ErrorAction Stop
                    Write-Host "    File '$shortcutPath' deleted successfully." -ForegroundColor Green
                } catch {
                    Write-Warning "    FAILED to delete file '$shortcutPath': $($_.Exception.Message)"
                }
            }
        }
    } else {
        Write-Host "Skipping Start Menu/Desktop shortcut removal." -ForegroundColor Green
    }
} else {
    Write-Host "No '$CygwinShortcutFolderName' folder found in standard Start Menu locations and no Cygwin shortcuts found on Desktops." -ForegroundColor Green
}

# 9. Delete Cygwin Installation Directory (REQUIRES PATH)
Write-Host "`nStep 7: Processing main Cygwin installation directory..." -ForegroundColor Cyan
$proceedWithInstallDirRemoval = $false

if ($PathFound) {
    if ($Silent) {
        if ($EffectiveRemoveInstallDir) {
            Write-Host "Silent mode: Proceeding with main installation directory removal." -ForegroundColor Cyan
            $proceedWithInstallDirRemoval = $true
        } else {
            Write-Host "Silent mode: Skipping main installation directory removal (action not enabled)." -ForegroundColor Gray
        }
    } else { # Interactive
        Write-Warning "This final destructive step will permanently delete the main installation folder: $DetectedCygwinPath"
        Write-Host ""
        $confirm = Read-Host "Are you absolutely sure you want to DELETE '$DetectedCygwinPath'? (y/n)"
        if ($confirm -eq 'y') {
            $proceedWithInstallDirRemoval = $true
        }
    }

    if ($proceedWithInstallDirRemoval) {
        Write-Host "  Deleting directory '$DetectedCygwinPath'..." -ForegroundColor Red
        try {
            Remove-Item -Path $DetectedCygwinPath -Recurse -Force -ErrorAction Stop
            Write-Host "  Directory '$DetectedCygwinPath' deleted successfully." -ForegroundColor Green
        } catch {
            Write-Error "  FAILED to delete directory '$DetectedCygwinPath': $($_.Exception.Message)"
            Write-Warning "  A RESTART may be required before manual deletion."
        }
    } else {
        Write-Host "Main directory deletion skipped." -ForegroundColor Green
    }
} else {
    Write-Warning "Skipping main directory deletion because Cygwin installation path was not found."
}

# 10. Recommend Restart
Write-Host "`nCygwin removal process complete." -ForegroundColor Green
Write-Host "-----------------------------------------------------"
Write-Warning "RESTART STRONGLY RECOMMENDED to ensure all changes take effect."
# Note: Desktop shortcuts were handled if requested, so no specific warning needed here unless further manual checks desired.
$ScriptEndTime = Get-Date
$Duration = New-TimeSpan -Start $ScriptStartTime -End $ScriptEndTime
Write-Host "Script execution time: $($Duration.TotalSeconds) seconds."
Write-Host "-----------------------------------------------------"

Exit 0
