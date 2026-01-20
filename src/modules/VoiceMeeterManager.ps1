# VoiceMeeter Manager Module
# Handles VoiceMeeter integration using VoiceMeeter Remote API (DLL)

# P/Invoke definitions for VoiceMeeter Remote DLL
$VoiceMeeterApiSignature = @"
using System;
using System.Runtime.InteropServices;

public class VoiceMeeterRemote
{
    // Login to VoiceMeeter Remote API
    [DllImport("VoicemeeterRemote64.dll", EntryPoint = "VBVMR_Login", CallingConvention = CallingConvention.StdCall)]
    public static extern int Login();

    // Logout from VoiceMeeter Remote API
    [DllImport("VoicemeeterRemote64.dll", EntryPoint = "VBVMR_Logout", CallingConvention = CallingConvention.StdCall)]
    public static extern int Logout();

    // Run VoiceMeeter application
    [DllImport("VoicemeeterRemote64.dll", EntryPoint = "VBVMR_RunVoicemeeter", CallingConvention = CallingConvention.StdCall)]
    public static extern int RunVoicemeeter(int vbType);

    // Get VoiceMeeter type (1=Voicemeeter, 2=Voicemeeter Banana, 3=Voicemeeter Potato)
    [DllImport("VoicemeeterRemote64.dll", EntryPoint = "VBVMR_GetVoicemeeterType", CallingConvention = CallingConvention.StdCall)]
    public static extern int GetVoicemeeterType(ref int pType);

    // Check if parameters have changed
    [DllImport("VoicemeeterRemote64.dll", EntryPoint = "VBVMR_IsParametersDirty", CallingConvention = CallingConvention.StdCall)]
    public static extern int IsParametersDirty();

    // Get parameter value (float)
    [DllImport("VoicemeeterRemote64.dll", EntryPoint = "VBVMR_GetParameterFloat", CallingConvention = CallingConvention.StdCall, CharSet = CharSet.Ansi)]
    public static extern int GetParameterFloat([MarshalAs(UnmanagedType.LPStr)] string paramName, ref float value);

    // Set parameter value (float)
    [DllImport("VoicemeeterRemote64.dll", EntryPoint = "VBVMR_SetParameterFloat", CallingConvention = CallingConvention.StdCall, CharSet = CharSet.Ansi)]
    public static extern int SetParameterFloat([MarshalAs(UnmanagedType.LPStr)] string paramName, float value);

    // Get parameter value (string)
    [DllImport("VoicemeeterRemote64.dll", EntryPoint = "VBVMR_GetParameterStringA", CallingConvention = CallingConvention.StdCall, CharSet = CharSet.Ansi)]
    public static extern int GetParameterString([MarshalAs(UnmanagedType.LPStr)] string paramName, [MarshalAs(UnmanagedType.LPStr)] System.Text.StringBuilder value);

    // Set parameter value (string)
    [DllImport("VoicemeeterRemote64.dll", EntryPoint = "VBVMR_SetParameterStringA", CallingConvention = CallingConvention.StdCall, CharSet = CharSet.Ansi)]
    public static extern int SetParameterString([MarshalAs(UnmanagedType.LPStr)] string paramName, [MarshalAs(UnmanagedType.LPStr)] string value);

    // Set multiple parameters (macro)
    [DllImport("VoicemeeterRemote64.dll", EntryPoint = "VBVMR_SetParameters", CallingConvention = CallingConvention.StdCall, CharSet = CharSet.Ansi)]
    public static extern int SetParameters([MarshalAs(UnmanagedType.LPStr)] string script);
}
"@

class VoiceMeeterManager {
    [object] $Config
    [object] $Messages
    [object] $Logger
    [bool] $IsConnected
    [string] $DllPath
    [int] $VoiceMeeterType
    [hashtable] $SavedParameters

    # VoiceMeeter type constants
    static [hashtable] $VoiceMeeterTypes = @{
        "standard" = 1
        "banana"   = 2
        "potato"   = 3
    }

    # Constructor
    VoiceMeeterManager([object] $voiceMeeterConfig, [object] $messages, [object] $logger = $null) {
        $this.Config = $voiceMeeterConfig
        $this.Messages = $messages
        $this.Logger = $logger
        $this.IsConnected = $false
        $this.VoiceMeeterType = 0
        $this.SavedParameters = @{}

        # Get DLL path from config
        if ($voiceMeeterConfig.dllPath) {
            $this.DllPath = [System.Environment]::ExpandEnvironmentVariables($voiceMeeterConfig.dllPath)
        } else {
            # Try default installation path
            $this.DllPath = "C:\Program Files (x86)\VB\Voicemeeter\VoicemeeterRemote64.dll"
        }

        # Load P/Invoke types if DLL exists
        if (Test-Path $this.DllPath) {
            try {
                if (-not ([System.Management.Automation.PSTypeName]'VoiceMeeterRemote').Type) {
                    Add-Type -TypeDefinition $script:VoiceMeeterApiSignature -ErrorAction Stop
                }
                Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_dll_loaded" -Args @($this.DllPath) -Default "VoiceMeeter DLL loaded: {0}" -Level "OK" -Component "VoiceMeeterManager"
                if ($this.Logger) {
                    $this.Logger.Info("VoiceMeeter DLL loaded: $($this.DllPath)", "VOICEMEETER")
                }
            } catch {
                Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_dll_load_failed" -Args @($_) -Default "Failed to load VoiceMeeter DLL: {0}" -Level "WARNING" -Component "VoiceMeeterManager"
                if ($this.Logger) {
                    $this.Logger.Warning("Failed to load VoiceMeeter DLL: $_", "VOICEMEETER")
                }
            }
        } else {
            Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_dll_not_found" -Args @($this.DllPath) -Default "VoiceMeeter DLL not found: {0}" -Level "WARNING" -Component "VoiceMeeterManager"
            if ($this.Logger) {
                $this.Logger.Warning("VoiceMeeter DLL not found: $($this.DllPath)", "VOICEMEETER")
            }
        }
    }

    # Connect to VoiceMeeter Remote API
    [bool] Connect() {
        try {
            if ($this.IsConnected) {
                Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_already_connected" -Default "Already connected to VoiceMeeter" -Level "INFO" -Component "VoiceMeeterManager"
                return $true
            }

            Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_connecting" -Default "Connecting to VoiceMeeter..." -Level "INFO" -Component "VoiceMeeterManager"
            
            # Check if DLL is loaded
            if (-not (Test-Path $this.DllPath)) {
                Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_dll_not_found" -Args @($this.DllPath) -Default "VoiceMeeter DLL not found: {0}" -Level "WARNING" -Component "VoiceMeeterManager"
                return $false
            }

            # Login to VoiceMeeter
            $result = [VoiceMeeterRemote]::Login()
            
            # Return codes: 0=OK, 1=OK but VoiceMeeter not running, -1=cannot get client, -2=unexpected login
            if ($result -eq 0) {
                $this.IsConnected = $true
                Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_connected" -Default "Connected to VoiceMeeter" -Level "OK" -Component "VoiceMeeterManager"
                if ($this.Logger) {
                    $this.Logger.Info("Connected to VoiceMeeter", "VOICEMEETER")
                }

                # Get VoiceMeeter type
                $typeRef = 0
                [VoiceMeeterRemote]::GetVoicemeeterType([ref]$typeRef)
                $this.VoiceMeeterType = $typeRef

                $typeName = switch ($typeRef) {
                    1 { "VoiceMeeter (Standard)" }
                    2 { "VoiceMeeter Banana" }
                    3 { "VoiceMeeter Potato" }
                    default { "Unknown ($typeRef)" }
                }
                Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_type_detected" -Args @($typeName) -Default "VoiceMeeter type: {0}" -Level "INFO" -Component "VoiceMeeterManager"

                return $true
            } elseif ($result -eq 1) {
                # VoiceMeeter not running, try to start it
                Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_not_running" -Default "VoiceMeeter is not running. Attempting to start..." -Level "INFO" -Component "VoiceMeeterManager"
                
                # Get VoiceMeeter type from config
                $vmType = [VoiceMeeterManager]::VoiceMeeterTypes["standard"]
                if ($this.Config.type) {
                    $vmType = [VoiceMeeterManager]::VoiceMeeterTypes[$this.Config.type]
                }

                $startResult = [VoiceMeeterRemote]::RunVoicemeeter($vmType)
                if ($startResult -eq 0) {
                    Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_started" -Default "VoiceMeeter started successfully" -Level "OK" -Component "VoiceMeeterManager"
                    Start-Sleep -Seconds 2  # Wait for VoiceMeeter to initialize

                    # Try login again
                    $loginResult = [VoiceMeeterRemote]::Login()
                    if ($loginResult -eq 0) {
                        $this.IsConnected = $true
                        return $true
                    }
                }
                Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_start_failed" -Default "Failed to start VoiceMeeter" -Level "WARNING" -Component "VoiceMeeterManager"
                return $false
            } else {
                Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_login_failed" -Args @($result) -Default "VoiceMeeter login failed with code: {0}" -Level "WARNING" -Component "VoiceMeeterManager"
                if ($this.Logger) {
                    $this.Logger.Warning("VoiceMeeter login failed with code: $result", "VOICEMEETER")
                }
                return $false
            }
        } catch {
            Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_connect_error" -Args @($_) -Default "VoiceMeeter connection error: {0}" -Level "WARNING" -Component "VoiceMeeterManager"
            if ($this.Logger) {
                $this.Logger.Error("VoiceMeeter connection error: $_", "VOICEMEETER")
            }
            return $false
        }
    }

    # Disconnect from VoiceMeeter Remote API
    [void] Disconnect() {
        try {
            if ($this.IsConnected) {
                [VoiceMeeterRemote]::Logout()
                $this.IsConnected = $false
                Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_disconnected" -Default "Disconnected from VoiceMeeter" -Level "OK" -Component "VoiceMeeterManager"
                if ($this.Logger) {
                    $this.Logger.Info("Disconnected from VoiceMeeter", "VOICEMEETER")
                }
            }
        } catch {
            Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_disconnect_error" -Args @($_) -Default "VoiceMeeter disconnect error: {0}" -Level "WARNING" -Component "VoiceMeeterManager"
        }
    }

    # Set a parameter value (float)
    [bool] SetParameter([string] $paramName, [float] $value) {
        try {
            if (-not $this.IsConnected) {
                Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_not_connected" -Default "Not connected to VoiceMeeter" -Level "WARNING" -Component "VoiceMeeterManager"
                return $false
            }

            $result = [VoiceMeeterRemote]::SetParameterFloat($paramName, $value)
            if ($result -eq 0) {
                Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_parameter_set" -Args @($paramName, $value) -Default "Set VoiceMeeter parameter {0} = {1}" -Level "INFO" -Component "VoiceMeeterManager"
                if ($this.Logger) {
                    $this.Logger.Info("Set parameter $paramName = $value", "VOICEMEETER")
                }
                return $true
            } else {
                Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_parameter_set_failed" -Args @($paramName, $result) -Default "Failed to set parameter {0}: code {1}" -Level "WARNING" -Component "VoiceMeeterManager"
                return $false
            }
        } catch {
            Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_parameter_error" -Args @($paramName, $_) -Default "Error setting parameter {0}: {1}" -Level "WARNING" -Component "VoiceMeeterManager"
            return $false
        }
    }

    # Get a parameter value (float)
    [float] GetParameter([string] $paramName) {
        try {
            if (-not $this.IsConnected) {
                return 0.0
            }

            $value = 0.0
            $result = [VoiceMeeterRemote]::GetParameterFloat($paramName, [ref]$value)
            if ($result -eq 0) {
                return $value
            } else {
                Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_parameter_get_failed" -Args @($paramName, $result) -Default "Failed to get parameter {0}: code {1}" -Level "WARNING" -Component "VoiceMeeterManager"
                return 0.0
            }
        } catch {
            Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_parameter_error" -Args @($paramName, $_) -Default "Error getting parameter {0}: {1}" -Level "WARNING" -Component "VoiceMeeterManager"
            return 0.0
        }
    }

    # Load profile from XML or apply parameters
    [bool] LoadProfile([string] $profilePath) {
        try {
            if (-not $this.IsConnected) {
                Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_not_connected" -Default "Not connected to VoiceMeeter" -Level "WARNING" -Component "VoiceMeeterManager"
                return $false
            }

            # Check if profile file exists
            if (-not (Test-Path $profilePath)) {
                Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_profile_not_found" -Args @($profilePath) -Default "Profile not found: {0}" -Level "WARNING" -Component "VoiceMeeterManager"
                return $false
            }

            # Load XML profile
            [xml]$profile = Get-Content $profilePath
            Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_loading_profile" -Args @($profilePath) -Default "Loading VoiceMeeter profile: {0}" -Level "INFO" -Component "VoiceMeeterManager"

            # Apply parameters from profile
            $success = $true
            foreach ($param in $profile.VoicemeeterProfile.Parameters.Parameter) {
                $paramName = $param.Name
                $paramValue = [float]$param.Value
                
                if (-not $this.SetParameter($paramName, $paramValue)) {
                    $success = $false
                }
            }

            if ($success) {
                Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_profile_loaded" -Args @($profilePath) -Default "Profile loaded: {0}" -Level "OK" -Component "VoiceMeeterManager"
                if ($this.Logger) {
                    $this.Logger.Info("Loaded profile: $profilePath", "VOICEMEETER")
                }
            }

            return $success
        } catch {
            Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_profile_load_error" -Args @($profilePath, $_) -Default "Error loading profile {0}: {1}" -Level "WARNING" -Component "VoiceMeeterManager"
            if ($this.Logger) {
                $this.Logger.Error("Error loading profile $profilePath`: $_", "VOICEMEETER")
            }
            return $false
        }
    }

    # Save current parameters for rollback
    [void] SaveCurrentParameters([array] $paramNames) {
        try {
            foreach ($paramName in $paramNames) {
                $value = $this.GetParameter($paramName)
                $this.SavedParameters[$paramName] = $value
                Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_parameter_saved" -Args @($paramName, $value) -Default "Saved parameter {0} = {1}" -Level "INFO" -Component "VoiceMeeterManager"
            }
        } catch {
            Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_save_parameters_error" -Args @($_) -Default "Error saving parameters: {0}" -Level "WARNING" -Component "VoiceMeeterManager"
        }
    }

    # Restore saved parameters
    [void] RestoreSavedParameters() {
        try {
            foreach ($paramName in $this.SavedParameters.Keys) {
                $value = $this.SavedParameters[$paramName]
                $this.SetParameter($paramName, $value)
                Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_parameter_restored" -Args @($paramName, $value) -Default "Restored parameter {0} = {1}" -Level "INFO" -Component "VoiceMeeterManager"
            }
            $this.SavedParameters.Clear()
        } catch {
            Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_restore_parameters_error" -Args @($_) -Default "Error restoring parameters: {0}" -Level "WARNING" -Component "VoiceMeeterManager"
        }
    }

    # Apply game-specific settings
    [bool] ApplyGameSettings([object] $gameSettings) {
        try {
            if (-not $this.IsConnected) {
                if (-not $this.Connect()) {
                    return $false
                }
            }

            $action = if ($gameSettings -and $gameSettings.action) { $gameSettings.action } else { "load-profile" }

            if ($action -eq "load-profile") {
                # Load profile from file
                $profilePath = if ($gameSettings -and $gameSettings.profilePath) {
                    [System.Environment]::ExpandEnvironmentVariables($gameSettings.profilePath)
                } elseif ($this.Config.defaultProfile) {
                    [System.Environment]::ExpandEnvironmentVariables($this.Config.defaultProfile)
                } else {
                    $null
                }

                if ($profilePath) {
                    return $this.LoadProfile($profilePath)
                } else {
                    Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_no_profile_specified" -Default "No profile specified" -Level "WARNING" -Component "VoiceMeeterManager"
                    return $false
                }
            } elseif ($action -eq "apply-params") {
                # Apply individual parameters
                if ($gameSettings -and $gameSettings.parameters) {
                    # Save current values for rollback
                    $paramNames = $gameSettings.parameters.PSObject.Properties.Name
                    $this.SaveCurrentParameters($paramNames)

                    # Apply new values
                    $success = $true
                    foreach ($prop in $gameSettings.parameters.PSObject.Properties) {
                        $paramName = $prop.Name
                        $paramValue = [float]$prop.Value
                        if (-not $this.SetParameter($paramName, $paramValue)) {
                            $success = $false
                        }
                    }
                    return $success
                } else {
                    Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_no_parameters_specified" -Default "No parameters specified" -Level "WARNING" -Component "VoiceMeeterManager"
                    return $false
                }
            }

            return $true
        } catch {
            Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_apply_settings_error" -Args @($_) -Default "Error applying game settings: {0}" -Level "WARNING" -Component "VoiceMeeterManager"
            return $false
        }
    }

    # Restore default settings
    [bool] RestoreDefaultSettings() {
        try {
            if (-not $this.IsConnected) {
                if (-not $this.Connect()) {
                    return $false
                }
            }

            # Restore saved parameters if any
            if ($this.SavedParameters.Count -gt 0) {
                $this.RestoreSavedParameters()
                return $true
            }

            # Load default profile if specified
            if ($this.Config.defaultProfile) {
                $defaultProfile = [System.Environment]::ExpandEnvironmentVariables($this.Config.defaultProfile)
                return $this.LoadProfile($defaultProfile)
            }

            return $true
        } catch {
            Write-LocalizedHost -Messages $this.Messages -Key "voicemeeter_restore_default_error" -Args @($_) -Default "Error restoring default settings: {0}" -Level "WARNING" -Component "VoiceMeeterManager"
            return $false
        }
    }
}

# Public function for VoiceMeeter management
function New-VoiceMeeterManager {
    param(
        [Parameter(Mandatory = $true)]
        [object] $VoiceMeeterConfig,

        [Parameter(Mandatory = $true)]
        [object] $Messages,

        [Parameter(Mandatory = $false)]
        [object] $Logger = $null
    )

    return [VoiceMeeterManager]::new($VoiceMeeterConfig, $Messages, $Logger)
}
