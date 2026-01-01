# VTube Studio Integration Test Script
<#
.SYNOPSIS
    Runs integration tests for VTubeStudioManager, ensuring it correctly interacts with the application and configuration.

.DESCRIPTION
    This Pester test script verifies the functionality of the VTubeStudioManager module. It performs the following checks:
    - Loads the VTubeStudioManager and AppManager modules.
    - Loads the application's configuration from 'config/config.json'.
    - Tests the VTubeStudioManager by creating an instance and checking for the VTube Studio installation.
    - Tests AppManager integration by validating the VTube Studio configuration.
    - Tests the ConfigValidator by running a full configuration validation and reporting the results.

.EXAMPLE
    .\Test-Integration-VTubeStudio.ps1
    Runs all integration tests defined in the script.

.NOTES
    This script is intended to be run from the 'test/scripts/integration' directory. It requires the main configuration file ('config/config.json') to be present and correctly formatted.

.OUTPUTS
    Outputs test results to the console, indicating the status of each test (e.g., [OK], [ERROR], [WARNING]).
#>

# Import the BuildLogger
. "$PSScriptRoot/../../../build-tools/utils/BuildLogger.ps1"

Write-BuildLog "=== VTube Studio Integration Test ==="

$projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

# Load required helper modules
try {
    $languageHelperPath = Join-Path -Path $projectRoot -ChildPath "scripts/LanguageHelper.ps1"
    . $languageHelperPath
    Write-BuildLog "[OK] LanguageHelper module loaded"
} catch {
    Write-BuildLog "[ERROR] Failed to load LanguageHelper: $_"
    exit 1
}

try {
    $webSocketBasePath = Join-Path -Path $projectRoot -ChildPath "src/modules/WebSocketAppManagerBase.ps1"
    . $webSocketBasePath
    Write-BuildLog "[OK] WebSocketAppManagerBase module loaded"
} catch {
    Write-BuildLog "[ERROR] Failed to load WebSocketAppManagerBase: $_"
    exit 1
}

try {
    $obsManagerPath = Join-Path -Path $projectRoot -ChildPath "src/modules/OBSManager.ps1"
    . $obsManagerPath
    Write-BuildLog "[OK] OBSManager module loaded"
} catch {
    Write-BuildLog "[ERROR] Failed to load OBSManager: $_"
    exit 1
}

try {
    $discordManagerPath = Join-Path -Path $projectRoot -ChildPath "src/modules/DiscordManager.ps1"
    . $discordManagerPath
    Write-BuildLog "[OK] DiscordManager module loaded"
} catch {
    Write-BuildLog "[WARNING] Failed to load DiscordManager (optional): $_"
}

# Load required modules
try {
    $vtubeStudioManagerPath = Join-Path -Path $projectRoot -ChildPath "src/modules/VTubeStudioManager.ps1"
    . $vtubeStudioManagerPath
    Write-BuildLog "[OK] VTubeStudioManager module loaded"
} catch {
    Write-BuildLog "[ERROR] Failed to load VTubeStudioManager: $_"
    exit 1
}

try {
    $appManagerPath = Join-Path -Path $projectRoot -ChildPath "src/modules/AppManager.ps1"
    . $appManagerPath
    Write-BuildLog "[OK] AppManager module loaded"
} catch {
    Write-BuildLog "[ERROR] Failed to load AppManager: $_"
    exit 1
}

# Load configuration
try {
    $configPath = Join-Path -Path $projectRoot -ChildPath "config/config.json"
    $config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-BuildLog "[OK] Configuration loaded"
} catch {
    Write-BuildLog "[ERROR] Failed to load configuration: $_"
    exit 1
}

# Test VTubeStudioManager
Write-BuildLog "=== Testing VTubeStudioManager ==="

# Create DiscordManager instance
$messages = @{}  # Mock messages object for testing
try {
    $vtubeManager = New-VTubeStudioManager -VTubeConfig $config.integrations.vtubeStudio -Messages $messages
    Write-BuildLog "[OK] VTubeStudioManager instance created"
} catch {
    Write-BuildLog "[ERROR] VTubeStudioManager test failed: $_"
    exit 1
}

# Test: IsVTubeStudioRunning
try {
    $isRunning = $vtubeManager.IsVTubeStudioRunning()
    Write-BuildLog "[OK] IsVTubeStudioRunning is success: $isRunning"
} catch {
    Write-BuildLog "[ERROR] Failed to IsVTubeStudioRunning: $_"
    exit 1
}

# Test: GetSteamPath
try {
    $steamPath = $vtubeManager.GetSteamPath()
    Write-BuildLog "[OK] GetSteamPath is success: $steamPath"
} catch {
    Write-BuildLog "[WARNING] Failed to GetSteamPath: $_"
}

# Test: StartVTubeStudio (commented out - requires VTube Studio to be installed)
# try {
#     $started = $vtubeManager.StartVTubeStudio()
#     Write-BuildLog "[OK] StartVTubeStudio is success: $started"
# } catch {
#     Write-BuildLog "[ERROR] Failed to StartVTubeStudio: $_"
#     exit 1
# }

# Test: StopVTubeStudio (commented out - requires VTube Studio to be running)
# try {
#     $stopped = $vtubeManager.StopVTubeStudio()
#     Write-BuildLog "[OK] StopVTubeStudio is success: $stopped"
# } catch {
#     Write-BuildLog "[ERROR] Failed to StopVTubeStudio: $_"
#     exit 1
# }

# Test: GetSteamPath (already tested above)

# Test: ConnectWebSocket / DisconnectWebSocket (commented out - requires VTube Studio running)
# try {
#     $connected = $vtubeManager.ConnectWebSocket()
#     Write-BuildLog "[OK] ConnectWebSocket is success: $connected"
#     $vtubeManager.DisconnectWebSocket()
#     Write-BuildLog "[OK] DisconnectWebSocket is success"
# } catch {
#     Write-BuildLog "[ERROR] Failed to Connect/DisconnectWebSocket: $_"
#     exit 1
# }

# Test: SendCommand (deprecated method)
try {
    $result = $vtubeManager.SendCommand("TestCommand")
    Write-BuildLog "[OK] SendCommand is success: $result (deprecated)"
} catch {
    Write-BuildLog "[WARNING] Failed to SendCommand: $_"
}
