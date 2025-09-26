# Application Manager Module
# Handles unified application lifecycle management

class AppManager {
    [object] $Config
    [object] $Messages
    [object] $ManagedApps

    # Constructor
    AppManager([object] $config, [object] $messages) {
        $this.Config = $config
        $this.Messages = $messages
        $this.ManagedApps = $config.managedApps
    }

    # Validate application configuration
    [bool] ValidateAppConfig([string] $appId) {
        if (-not $this.ManagedApps.$appId) {
            Write-Host ($this.Messages.warning_app_not_defined -f $appId)
            return $false
        }

        $appConfig = $this.ManagedApps.$appId

        # Check required properties
        if (-not $appConfig.PSObject.Properties.Name -contains "processName") {
            Write-Host "Application '$appId' is missing 'processName' property"
            return $false
        }

        return $true
    }

    # Execute application action
    [bool] InvokeAction([string] $appId, [string] $action) {
        if (-not $this.ValidateAppConfig($appId)) {
            return $false
        }

        $appConfig = $this.ManagedApps.$appId

        switch ($action) {
            "start-process" {
                return $this.StartProcess($appId, $appConfig)
            }
            "stop-process" {
                return $this.StopProcess($appId, $appConfig)
            }
            "toggle-hotkeys" {
                return $this.ToggleHotkeys($appId, $appConfig)
            }
            "start-vtube-studio" {
                return $this.StartVTubeStudio($appId, $appConfig)
            }
            "stop-vtube-studio" {
                return $this.StopVTubeStudio($appId, $appConfig)
            }
            "set-discord-gaming-mode" {
                return $this.SetDiscordGamingMode($appId, $appConfig)
            }
            "restore-discord-normal" {
                return $this.RestoreDiscordNormal($appId, $appConfig)
            }
            "pause-wallpaper" {
                return $this.PauseWallpaper($appId, $appConfig)
            }
            "play-wallpaper" {
                return $this.PlayWallpaper($appId, $appConfig)
            }
            "none" {
                return $true
            }
            default {
                Write-Host "Unknown action: $action for app: $appId"
                return $false
            }
        }

        return $false
    }

    # Start application process
    [bool] StartProcess([string] $appId, [object] $appConfig) {
        if (-not $appConfig.path -or $appConfig.path -eq "") {
            Write-Host ($this.Messages.warning_no_path_specified -f $appId)
            return $false
        }

        if (-not (Test-Path $appConfig.path)) {
            Write-Host "Application path not found: $($appConfig.path)"
            return $false
        }

        try {
            $arguments = if ($appConfig.arguments -and $appConfig.arguments -ne "") {
                $appConfig.arguments
            } else {
                $null
            }

            if ($arguments) {
                Start-Process -FilePath $appConfig.path -ArgumentList $arguments
            } else {
                Start-Process -FilePath $appConfig.path
            }

            Write-Host ($this.Messages.app_started -f $appId)
            return $true
        }
        catch {
            Write-Host "Failed to start $appId : $_"
            return $false
        }
    }

    # Stop application process
    [bool] StopProcess([string] $appId, [object] $appConfig) {
        if (-not $appConfig.processName -or $appConfig.processName -eq "") {
            Write-Host ($this.Messages.warning_no_process_name -f $appId)
            return $false
        }

        # Get termination method (default: auto for backward compatibility)
        $terminationMethod = if ($appConfig.terminationMethod) { $appConfig.terminationMethod } else { "auto" }

        # Get graceful shutdown timeout (default: 3 seconds)
        $gracefulTimeoutMs = if ($appConfig.gracefulTimeoutMs) { $appConfig.gracefulTimeoutMs } else { 3000 }

        # Handle multiple process names separated by |
        $processNames = $appConfig.processName -split '\|'
        $processFound = $false

        foreach ($processName in $processNames) {
            $processName = $processName.Trim()
            try {
                $processes = Get-Process -Name $processName -ErrorAction Stop
                if ($processes) {
                    $success = $this.TerminateProcess($processName, $terminationMethod, $gracefulTimeoutMs, $appId)
                    if ($success) {
                        Write-Host ($this.Messages.app_process_stopped -f $appId, $processName)
                        $processFound = $true
                    }
                }
            }
            catch {
                # Process not found, continue to next
            }
        }

        if (-not $processFound) {
            Write-Host ($this.Messages.app_process_not_running -f $appId)
        }

        return $true
    }

    # Terminate process based on specified method
    [bool] TerminateProcess([string] $processName, [string] $method, [int] $timeoutMs, [string] $appId) {
        switch ($method.ToLower()) {
            "graceful" {
                return $this.GracefulTermination($processName, $timeoutMs, $appId)
            }
            "force" {
                return $this.ForceTermination($processName, $appId)
            }
            "auto" {
                # Try graceful first, then force if needed
                $gracefulSuccess = $this.GracefulTermination($processName, $timeoutMs, $appId)
                if (-not $gracefulSuccess) {
                    Write-Host ($this.Messages.graceful_failed_using_force -f $processName) -ForegroundColor Yellow
                    return $this.ForceTermination($processName, $appId)
                }
                return $true
            }
            default {
                Write-Host "Unknown termination method '$method' for $appId. Using 'auto' as fallback." -ForegroundColor Yellow
                return $this.TerminateProcess($processName, "auto", $timeoutMs, $appId)
            }
        }
    }

    # Graceful process termination (allows user dialogs)
    [bool] GracefulTermination([string] $processName, [int] $timeoutMs, [string] $appId) {
        try {
            # Send graceful termination signal
            Stop-Process -Name $processName -ErrorAction Stop

            Write-Host ($this.Messages.graceful_shutdown_initiated -f $processName, ($timeoutMs / 1000))

            # Wait for process to exit gracefully
            $waitInterval = 100  # Check every 100ms
            $elapsedMs = 0

            while ($elapsedMs -lt $timeoutMs) {
                Start-Sleep -Milliseconds $waitInterval
                $elapsedMs += $waitInterval

                # Check if process still exists
                $remainingProcesses = Get-Process -Name $processName -ErrorAction SilentlyContinue
                if (-not $remainingProcesses) {
                    Write-Host ($this.Messages.graceful_shutdown_success -f $processName) -ForegroundColor Green
                    return $true
                }
            }

            # Timeout reached
            Write-Host ($this.Messages.graceful_shutdown_timeout -f $processName, ($timeoutMs / 1000)) -ForegroundColor Yellow
            return $false
        }
        catch {
            Write-Host ($this.Messages.graceful_shutdown_failed -f $processName, $_) -ForegroundColor Red
            return $false
        }
    }

    # Force process termination (immediate)
    [bool] ForceTermination([string] $processName, [string] $appId) {
        try {
            Stop-Process -Name $processName -Force -ErrorAction Stop
            Write-Host ($this.Messages.force_termination_success -f $processName) -ForegroundColor Yellow
            return $true
        }
        catch {
            Write-Host ($this.Messages.force_termination_failed -f $processName, $_) -ForegroundColor Red
            return $false
        }
    }

    # Toggle hotkeys (special case for applications like Clibor)
    [bool] ToggleHotkeys([string] $appId, [object] $appConfig) {
        if (-not $appConfig.path -or $appConfig.path -eq "") {
            Write-Host ($this.Messages.warning_no_path_specified -f $appId)
            return $false
        }

        try {
            $arguments = if ($appConfig.arguments -and $appConfig.arguments -ne "") {
                $appConfig.arguments
            } else {
                "/hs"
            }

            Start-Process -FilePath $appConfig.path -ArgumentList $arguments
            Write-Host ($this.Messages.app_hotkey_toggled -f $appId, $this.Messages.clibor_action_toggled)
            return $true
        }
        catch {
            Write-Host "Failed to toggle hotkeys for $appId : $_"
            return $false
        }
    }

    # Start VTube Studio (special action)
    [bool] StartVTubeStudio([string] $appId, [object] $appConfig) {
        try {
            # Load VTubeStudioManager if not already loaded
            $modulePath = Join-Path $PSScriptRoot "VTubeStudioManager.ps1"
            if (Test-Path $modulePath) {
                . $modulePath
            } else {
                Write-Host "VTubeStudioManager module not found at: $modulePath"
                return $false
            }

            # Create VTubeStudioManager instance
            $vtubeManager = New-VTubeStudioManager -VTubeConfig $appConfig -Messages $this.Messages

            # Start VTube Studio
            return $vtubeManager.StartVTubeStudio()
        }
        catch {
            Write-Host "Failed to start VTube Studio: $_"
            return $false
        }
    }

    # Stop VTube Studio (special action)
    [bool] StopVTubeStudio([string] $appId, [object] $appConfig) {
        try {
            # Load VTubeStudioManager if not already loaded
            $modulePath = Join-Path $PSScriptRoot "VTubeStudioManager.ps1"
            if (Test-Path $modulePath) {
                . $modulePath
            } else {
                Write-Host "VTubeStudioManager module not found at: $modulePath"
                return $false
            }

            # Create VTubeStudioManager instance
            $vtubeManager = New-VTubeStudioManager -VTubeConfig $appConfig -Messages $this.Messages

            # Stop VTube Studio
            return $vtubeManager.StopVTubeStudio()
        }
        catch {
            Write-Host "Failed to stop VTube Studio: $_"
            return $false
        }
    }

    # Set Discord Gaming Mode (special action)
    [bool] SetDiscordGamingMode([string] $appId, [object] $appConfig) {
        try {
            # Load DiscordManager if not already loaded
            $modulePath = Join-Path $PSScriptRoot "DiscordManager.ps1"
            if (Test-Path $modulePath) {
                . $modulePath
            } else {
                Write-Host "DiscordManager module not found at: $modulePath"
                return $false
            }

            # Create DiscordManager instance
            $discordManager = New-DiscordManager -DiscordConfig $appConfig -Messages $this.Messages

            # Set Gaming Mode
            return $discordManager.SetGamingMode($this.gameConfig.name)
        }
        catch {
            Write-Host "Failed to set Discord Gaming Mode: $_"
            return $false
        }
    }

    # Restore Discord Normal Mode (special action)
    [bool] RestoreDiscordNormal([string] $appId, [object] $appConfig) {
        try {
            # Load DiscordManager if not already loaded
            $modulePath = Join-Path $PSScriptRoot "DiscordManager.ps1"
            if (Test-Path $modulePath) {
                . $modulePath
            } else {
                Write-Host "DiscordManager module not found at: $modulePath"
                return $false
            }

            # Create DiscordManager instance
            $discordManager = New-DiscordManager -DiscordConfig $appConfig -Messages $this.Messages

            # Restore Normal Mode
            return $discordManager.RestoreNormalMode()
        }
        catch {
            Write-Host "Failed to restore Discord Normal Mode: $_"
            return $false
        }
    }

    # Control Wallpaper Engine playback
    [bool] ControlWallpaper([string] $appId, [object] $appConfig, [string] $command) {
        if (-not $appConfig.path -or $appConfig.path -eq "") {
            Write-Host "Wallpaper Engine path not specified for $appId"
            return $false
        }

        # Check if the path exists
        if (-not (Test-Path $appConfig.path)) {
            Write-Host "Wallpaper Engine executable not found at: $($appConfig.path)"
            return $false
        }

        try {
            # Determine the correct executable based on system architecture
            $executablePath = $appConfig.path
            $executableName = [System.IO.Path]::GetFileNameWithoutExtension($executablePath)
            $executableDir = [System.IO.Path]::GetDirectoryName($executablePath)

            # Check if we need to auto-select between 32-bit and 64-bit versions
            $is64Bit = [Environment]::Is64BitOperatingSystem
            if ($executableName -eq "wallpaper32" -and $is64Bit) {
                $wallpaper64Path = Join-Path $executableDir "wallpaper64.exe"
                if (Test-Path $wallpaper64Path) {
                    $executablePath = $wallpaper64Path
                    Write-Host "Auto-selected 64-bit version: $executablePath"
                }
            }

            # Execute the control command
            $arguments = "-control", $command
            Start-Process -FilePath $executablePath -ArgumentList $arguments -NoNewWindow -Wait

            $actionDescription = if ($command -eq "pause") { "paused" } else { "resumed" }
            Write-Host "Wallpaper Engine $actionDescription successfully"
            return $true
        }
        catch {
            Write-Host "Failed to control Wallpaper Engine ($command): $_"
            return $false
        }
    }

    # Pause Wallpaper Engine (special action)
    [bool] PauseWallpaper([string] $appId, [object] $appConfig) {
        return $this.ControlWallpaper($appId, $appConfig, "pause")
    }

    # Resume Wallpaper Engine playback (special action)
    [bool] PlayWallpaper([string] $appId, [object] $appConfig) {
        return $this.ControlWallpaper($appId, $appConfig, "play")
    }

    # Check if application process is running
    [bool] IsProcessRunning([string] $processName) {
        return $null -ne (Get-Process -Name $processName -ErrorAction SilentlyContinue)
    }

    # Get application startup action
    [string] GetStartupAction([string] $appId) {
        if ($this.ManagedApps.$appId -and $this.ManagedApps.$appId.gameStartAction) {
            return $this.ManagedApps.$appId.gameStartAction
        }
        return "none"
    }

    # Get application shutdown action
    [string] GetShutdownAction([string] $appId) {
        if ($this.ManagedApps.$appId -and $this.ManagedApps.$appId.gameEndAction) {
            return $this.ManagedApps.$appId.gameEndAction
        }
        return "none"
    }

    # Process application startup sequence
    [bool] ProcessStartupSequence([array] $appIds) {
        $allSuccess = $true

        foreach ($appId in $appIds) {
            $action = $this.GetStartupAction($appId)
            $success = $this.InvokeAction($appId, $action)
            if (-not $success) {
                $allSuccess = $false
                Write-Warning "Failed to start $appId with action: $action"
            }
        }

        return $allSuccess
    }

    # Process application shutdown sequence
    [bool] ProcessShutdownSequence([array] $appIds) {
        $allSuccess = $true

        foreach ($appId in $appIds) {
            $action = $this.GetShutdownAction($appId)
            $success = $this.InvokeAction($appId, $action)
            if (-not $success) {
                $allSuccess = $false
                Write-Warning "Failed to shutdown $appId with action: $action"
            }
        }

        return $allSuccess
    }
}

# Public function for App management
function New-AppManager {
    param(
        [Parameter(Mandatory = $true)]
        [object] $Config,

        [Parameter(Mandatory = $true)]
        [object] $Messages
    )

    return [AppManager]::new($Config, $Messages)
}

# Functions are available via dot-sourcing
