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

        # Handle multiple process names separated by |
        $processNames = $appConfig.processName -split '\|'
        $processFound = $false
        
        foreach ($processName in $processNames) {
            $processName = $processName.Trim()
            try {
                $processes = Get-Process -Name $processName -ErrorAction Stop
                if ($processes) {
                    Stop-Process -Name $processName -Force
                    Write-Host ($this.Messages.app_process_stopped -f $appId, $processName)
                    $processFound = $true
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