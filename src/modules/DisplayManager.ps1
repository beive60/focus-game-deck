# Focus Game Deck - Display Manager Module
# Display configuration management for console games via DisplayMan.exe
# Supports profile switching for capture card passthrough setups

class DisplayProfileManager {
    [string] $DisplayManPath
    [object] $Logger
    [hashtable] $SavedProfile
    
    DisplayProfileManager([object] $Config, [object] $Logger) {
        $this.Logger = $Logger
        
        # Determine DisplayMan.exe path from config
        if ($Config.paths -and $Config.paths.displayManager) {
            $this.DisplayManPath = $Config.paths.displayManager
        } else {
            # Default path relative to application root
            $this.DisplayManPath = "./tools/DisplayMan.exe"
        }
        
        # Resolve relative path if needed
        if (-not [System.IO.Path]::IsPathRooted($this.DisplayManPath)) {
            # Get the application root directory using global $PSScriptRoot context
            # In class context, we need to use script-level variables
            $appRoot = $null
            
            # Try to get from calling context (works in most cases)
            if ($script:appRoot) {
                $appRoot = $script:appRoot
            } else {
                # Fallback: assume we're in src/modules and go up two levels
                $modulePath = $PSScriptRoot
                if ($modulePath) {
                    $appRoot = Split-Path -Parent (Split-Path -Parent $modulePath)
                } else {
                    # Last resort: use current directory
                    $appRoot = Get-Location
                }
            }
            
            $this.DisplayManPath = Join-Path -Path $appRoot -ChildPath $this.DisplayManPath
        }
        
        if (-not (Test-Path $this.DisplayManPath)) {
            if ($this.Logger) {
                $this.Logger.Warning("DisplayMan.exe not found at: $($this.DisplayManPath). Display profile management will be unavailable.", "DISPLAY")
            }
        }
    }
    
    [bool] IsAvailable() {
        return (Test-Path $this.DisplayManPath)
    }
    
    [bool] SetProfile([string] $ProfilePath) {
        if (-not $this.IsAvailable()) {
            if ($this.Logger) {
                $this.Logger.Error("DisplayMan.exe is not available. Cannot set display profile.", "DISPLAY")
            }
            return $false
        }
        
        if (-not (Test-Path $ProfilePath)) {
            if ($this.Logger) {
                $this.Logger.Error("Display profile not found: $ProfilePath", "DISPLAY")
            }
            return $false
        }
        
        try {
            $args = "--load `"$ProfilePath`" --persistent"
            if ($this.Logger) {
                $this.Logger.Debug("Executing DisplayMan: $($this.DisplayManPath) $args", "DISPLAY")
            }
            
            $process = Start-Process $this.DisplayManPath -ArgumentList $args -Wait -PassThru -NoNewWindow
            
            if ($process.ExitCode -eq 0) {
                if ($this.Logger) {
                    $this.Logger.Info("Display profile applied: $ProfilePath", "DISPLAY")
                }
                return $true
            } else {
                if ($this.Logger) {
                    $this.Logger.Error("DisplayMan.exe exited with code $($process.ExitCode)", "DISPLAY")
                }
                return $false
            }
        } catch {
            if ($this.Logger) {
                $this.Logger.Error("Failed to apply display profile: $_", "DISPLAY")
            }
            return $false
        }
    }
    
    [bool] SaveCurrentProfile([string] $OutputPath) {
        if (-not $this.IsAvailable()) {
            if ($this.Logger) {
                $this.Logger.Error("DisplayMan.exe is not available. Cannot save display profile.", "DISPLAY")
            }
            return $false
        }
        
        try {
            $args = "--save `"$OutputPath`""
            if ($this.Logger) {
                $this.Logger.Debug("Executing DisplayMan: $($this.DisplayManPath) $args", "DISPLAY")
            }
            
            $process = Start-Process $this.DisplayManPath -ArgumentList $args -Wait -PassThru -NoNewWindow
            
            if ($process.ExitCode -eq 0) {
                if ($this.Logger) {
                    $this.Logger.Info("Display profile saved: $OutputPath", "DISPLAY")
                }
                return $true
            } else {
                if ($this.Logger) {
                    $this.Logger.Error("DisplayMan.exe exited with code $($process.ExitCode)", "DISPLAY")
                }
                return $false
            }
        } catch {
            if ($this.Logger) {
                $this.Logger.Error("Failed to save display profile: $_", "DISPLAY")
            }
            return $false
        }
    }
    
    [bool] RestoreDefault() {
        if (-not $this.IsAvailable()) {
            if ($this.Logger) {
                $this.Logger.Error("DisplayMan.exe is not available. Cannot restore display profile.", "DISPLAY")
            }
            return $false
        }
        
        try {
            $args = "--reset"
            if ($this.Logger) {
                $this.Logger.Debug("Executing DisplayMan: $($this.DisplayManPath) $args", "DISPLAY")
            }
            
            $process = Start-Process $this.DisplayManPath -ArgumentList $args -Wait -PassThru -NoNewWindow
            
            if ($process.ExitCode -eq 0) {
                if ($this.Logger) {
                    $this.Logger.Info("Display profile restored to default", "DISPLAY")
                }
                return $true
            } else {
                if ($this.Logger) {
                    $this.Logger.Error("DisplayMan.exe exited with code $($process.ExitCode)", "DISPLAY")
                }
                return $false
            }
        } catch {
            if ($this.Logger) {
                $this.Logger.Error("Failed to restore display profile: $_", "DISPLAY")
            }
            return $false
        }
    }
}

# Factory function for PowerShell module compatibility
function New-DisplayProfileManager {
    param(
        [object] $Config,
        [object] $Logger
    )
    return [DisplayProfileManager]::new($Config, $Logger)
}
