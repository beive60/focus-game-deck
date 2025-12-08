<#
.SYNOPSIS
    Focus Game Deck code signing script for executable files

.DESCRIPTION
    This script handles digital signing of executables with Extended Validation certificates.
    It provides functionality to list certificates, test certificate configuration,
    and sign individual files or all executables in the build directory.

.PARAMETER SigningConfigPath
    Path to the signing configuration JSON file.
    Default: build-tools/signing-config/signing-config.json
    This file contains certificate thumbprint, timestamp server, and other signing settings.

.PARAMETER BuildPath
    Path to the build directory containing executables to sign.
    Default: build-tools/build
    All .exe files in this directory and subdirectories will be processed when using -SignAll.

.PARAMETER TestCertificate
    Tests the configured certificate for signing capability.
    Validates certificate existence, private key access, expiration status,
    and timestamp server connectivity.

.PARAMETER ListCertificates
    Lists all available code signing certificates in the current user certificate store.
    Displays certificate details including subject, issuer, thumbprint, validity period,
    and current status (valid/expired/not yet valid).

.PARAMETER SignAll
    Signs all executable files (.exe) found in the build directory.
    Requires signing to be enabled in configuration and a valid certificate.
    Creates signature information file and optionally creates distribution package.

.PARAMETER SignFile
    Signs a specific file specified by its path.
    Use this parameter to sign individual files instead of all files in the build directory.

.EXAMPLE
    .\Sign-Executables.ps1 -ListCertificates
    Lists all available code signing certificates in the certificate store.

.EXAMPLE
    .\Sign-Executables.ps1 -TestCertificate
    Tests the certificate configuration and connectivity.

.EXAMPLE
    .\Sign-Executables.ps1 -SignAll
    Signs all executable files in the build directory.

.EXAMPLE
    .\Sign-Executables.ps1 -SignFile "C:\path\to\file.exe"
    Signs a specific executable file.

.EXAMPLE
    .\Sign-Executables.ps1 -SigningConfigPath "custom-config.json" -SignAll
    Signs all files using a custom configuration file.

.NOTES
    Version: 1.0.0
    Author: Focus Game Deck Development Team

    Requirements:
    - Windows PowerShell 5.1 or later
    - Extended Validation certificate installed in Windows Certificate Store
    - Properly configured signing-config.json file

    Setup Process:
    1. Install Extended Validation certificate in Windows Certificate Store
    2. Run with -ListCertificates to find certificate thumbprint
    3. Configure signing-config.json with certificate thumbprint
    4. Set 'enabled: true' in signing-config.json
    5. Test with -TestCertificate
    6. Sign files with -SignAll or -SignFile
#>

param(
    # signing config lives in build-tools/signing-config/
    [string]$SigningConfigPath = (Join-Path $PSScriptRoot "signing-config/signing-config.json"),
    [string]$BuildPath = (Join-Path $PSScriptRoot "build"),
    [switch]$TestCertificate,
    [switch]$ListCertificates,
    [switch]$SignAll,
    [string]$SignFile
)

# Load signing configuration
function Get-SigningConfig {
    param([string]$SigningConfigPath)


# Import the BuildLogger
. "$PSScriptRoot/utils/BuildLogger.ps1"
    if (-not (Test-Path $SigningConfigPath)) {
        Write-BuildLog "Signing configuration not found: $SigningConfigPath" -Level Error
        return $null
    }

    try {
        $config = Get-Content $SigningConfigPath -Raw | ConvertFrom-Json
        return $config.codeSigningSettings
    } catch {
        Write-BuildLog "Failed to load signing configuration: $($_.Exception.Message)" -Level Error
        return $null
    }
}

# List available code signing certificates
function Get-CodeSigningCertificates {
    Write-BuildLog "Available Code Signing Certificates:"
    Write-BuildLog "======================================"

    $certs = Get-ChildItem -Path "Cert:/CurrentUser/My" | Where-Object {
        $_.Extensions | Where-Object {
            $_.Oid.FriendlyName -eq "Enhanced Key Usage" -and
            $_.Format($false) -match "Code Signing"
        }
    }

    if ($certs.Count -eq 0) {
        Write-BuildLog "No code signing certificates found in CurrentUser/My store."
        Write-BuildLog "Please install an Extended Validation certificate first."
        return $null
    }

    foreach ($cert in $certs) {
        Write-BuildLog "Certificate Details:"
        Write-BuildLog "Subject: $($cert.Subject)"
        Write-BuildLog "Issuer: $($cert.Issuer)"
        Write-BuildLog "Thumbprint: $($cert.Thumbprint)"
        Write-BuildLog "Valid From: $($cert.NotBefore)"
        Write-BuildLog "Valid To: $($cert.NotAfter)"
        Write-BuildLog "Has Private Key: $($cert.HasPrivateKey)"

        # Check if certificate is expired
        if ($cert.NotAfter -lt (Get-Date)) {
            Write-BuildLog "Status: EXPIRED"
        } elseif ($cert.NotBefore -gt (Get-Date)) {
            Write-BuildLog "Status: NOT YET VALID"
        } else {
            Write-BuildLog "Status: VALID"
        }

        Write-Host ("-" * 50)
    }

    return $certs
}

# Test certificate functionality
function Test-Certificate {
    param([object]$SigningConfig)


# Import the BuildLogger
. "$PSScriptRoot/utils/BuildLogger.ps1"
    if (-not $SigningConfig) {
        Write-BuildLog "Signing configuration is required for certificate testing" -Level Error
        return $false
    }

    if ([string]::IsNullOrEmpty($SigningConfig.certificateThumbprint)) {
        Write-BuildLog "No certificate thumbprint configured. Available certificates:"
        Get-CodeSigningCertificates
        return $false
    }

    Write-BuildLog "Testing certificate: $($SigningConfig.certificateThumbprint)"

    try {
        $cert = Get-ChildItem -Path $SigningConfig.certificateStorePath |
        Where-Object { $_.Thumbprint -eq $SigningConfig.certificateThumbprint }

        if (-not $cert) {
            Write-BuildLog "Certificate not found with thumbprint: $($SigningConfig.certificateThumbprint)" -Level Error
            return $false
        }

        Write-BuildLog "Certificate found and accessible:"
        Write-BuildLog "Subject: $($cert.Subject)"
        Write-BuildLog "Valid To: $($cert.NotAfter)"
        Write-BuildLog "Has Private Key: $($cert.HasPrivateKey)"

        if (-not $cert.HasPrivateKey) {
            Write-BuildLog "Certificate does not have an associated private key" -Level Error
            return $false
        }

        if ($cert.NotAfter -lt (Get-Date)) {
            Write-BuildLog "Certificate has expired" -Level Error
            return $false
        }

        # Test timestamp server connectivity
        Write-BuildLog "Testing timestamp server connectivity..."
        try {
            $null = Invoke-WebRequest -Uri $SigningConfig.timestampServer -Method Head -TimeoutSec 10
            Write-BuildLog "Timestamp server is accessible"
        } catch {
            Write-BuildLog "Timestamp server test failed: $($_.Exception.Message)" -Level Warning
        }

        return $true

    } catch {
        Write-BuildLog "Certificate test failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# Sign a single file
function Add-CodeSignature {
    param(
        [string]$FilePath,
        [object]$SigningConfig
    )


# Import the BuildLogger
. "$PSScriptRoot/utils/BuildLogger.ps1"
    if (-not (Test-Path $FilePath)) {
        Write-BuildLog "File not found: $FilePath" -Level Error
        return $false
    }

    if (-not $SigningConfig.enabled) {
        Write-BuildLog "Code signing is disabled in configuration."
        return $false
    }

    Write-BuildLog "Signing file: $(Split-Path $FilePath -Leaf)"

    try {
        $signParams = @{
            FilePath = $FilePath
            Certificate = Get-ChildItem -Path $SigningConfig.certificateStorePath |
            Where-Object { $_.Thumbprint -eq $SigningConfig.certificateThumbprint }
            HashAlgorithm = $SigningConfig.hashAlgorithm
            TimestampServer = $SigningConfig.timestampServer
        }

        # Note: Set-AuthenticodeSignature doesn't support Description/DescriptionUrl
        # These would be available with signtool.exe instead
        Set-AuthenticodeSignature @signParams

        # Verify the signature
        $signature = Get-AuthenticodeSignature -FilePath $FilePath
        $fileName = Split-Path $FilePath -Leaf

        # Check if signature was applied (certificate exists)
        $isSignatureApplied = $null -ne $signature.SignerCertificate

        # Check if signature is trusted (Valid status)
        $isSignatureTrusted = $signature.Status -eq "Valid"

        Write-BuildLog "Signature analysis for: $fileName"
        $signatureLevel = if ($isSignatureApplied) { "Success" } else { "Error" }
        Write-BuildLog "Signature applied: $($isSignatureApplied)" -Level $signatureLevel
        $trustLevel = if ($isSignatureTrusted) { "Success" } else { "Warning" }
        Write-BuildLog "Signature trusted: $($isSignatureTrusted)" -Level $trustLevel
        Write-BuildLog "Signature status: $($signature.Status)"

        if ($signature.SignerCertificate) {
            Write-BuildLog "Certificate subject: $($signature.SignerCertificate.Subject)"
        }

        if ($isSignatureApplied) {
            if ($isSignatureTrusted) {
                Write-BuildLog "Successfully signed with trusted certificate: $fileName"
            } else {
                Write-BuildLog "Successfully signed with test/self-signed certificate: $fileName"
                Write-BuildLog "Note: Certificate is not trusted by system (expected for test certificates)"
            }
            return $true
        } else {
            Write-BuildLog "Failed to apply signature to: $fileName" -Level Error
            return $false
        }

    } catch {
        Write-BuildLog "Failed to sign file: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# Sign all executables in build directory
function Add-AllCodeSignatures {
    param(
        [string]$BuildPath,
        [object]$SigningConfig
    )


# Import the BuildLogger
. "$PSScriptRoot/utils/BuildLogger.ps1"
    if (-not (Test-Path $BuildPath)) {
        Write-BuildLog "Build directory not found: $BuildPath" -Level Error
        return $false
    }

    $exeFiles = Get-ChildItem -Path $BuildPath -Filter "*.exe" -Recurse

    if ($exeFiles.Count -eq 0) {
        Write-BuildLog "No executable files found in build directory."
        return $true
    }

    Write-BuildLog "Found $($exeFiles.Count) executable files to sign:"

    $successCount = 0
    $failCount = 0

    foreach ($exeFile in $exeFiles) {
        if (Add-CodeSignature -FilePath $exeFile.FullName -SigningConfig $SigningConfig) {
            $successCount++
        } else {
            $failCount++
        }
    }

    Write-BuildLog "Signing Summary:"
    Write-BuildLog "Successfully signed: $successCount"
    if ($failCount -gt 0) {
        Write-BuildLog "Failed to sign: $failCount"
    } elseif ($failCount -eq 0) {
        Write-BuildLog "All files signed successfully!"
    }

    return $failCount -eq 0
}

# Create distribution package information (build script will handle the actual distribution)
function New-SignedDistribution {
    param(
        [string]$BuildPath,
        [object]$BuildConfig
    )


# Import the BuildLogger
. "$PSScriptRoot/utils/BuildLogger.ps1"
    $distDir = Join-Path (Split-Path $BuildPath -Parent) "dist"

    if (-not (Test-Path $distDir)) {
        New-Item -ItemType Directory -Path $distDir -Force | Out-Null
    }

    Write-BuildLog "Signed distribution package created: $distDir"

    # Create version info file
    $versionInfo = @{
        BuildDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Version = "1.0.0"
        SignedFiles = @()
    }

    # List signed files in build directory
    $signedFiles = Get-ChildItem -Path $BuildPath -Filter "*.exe" -Recurse
    foreach ($file in $signedFiles) {
        $signature = Get-AuthenticodeSignature -FilePath $file.FullName
        $versionInfo.SignedFiles += @{
            FileName = $file.Name
            SignatureStatus = $signature.Status.ToString()
            SignerCertificate = if ($signature.SignerCertificate) { $signature.SignerCertificate.Subject } else { "None" }
            TimeStamperCertificate = if ($signature.TimeStamperCertificate) { $signature.TimeStamperCertificate.Subject } else { "None" }
        }
    }

    $versionInfoPath = Join-Path $distDir "signature-info.json"
    $versionInfo | ConvertTo-Json -Depth 4 | Set-Content -Path $versionInfoPath -Encoding UTF8

    Write-BuildLog "Signature information saved to: signature-info.json"

    return $distDir
}

# Main script execution
try {
    Write-BuildLog "Focus Game Deck - Code Signing Tool"
    Write-BuildLog "===================================="

    # Load configuration
    $fullConfig = Get-Content $SigningConfigPath -Raw | ConvertFrom-Json
    $signingConfig = $fullConfig.codeSigningSettings
    if (-not $signingConfig) {
        exit 1
    }

    # List certificates if requested
    if ($ListCertificates) {
        Get-CodeSigningCertificates
        exit 0
    }

    # Test certificate if requested
    if ($TestCertificate) {
        if (Test-Certificate -SigningConfig $signingConfig) {
            Write-BuildLog "Certificate test passed!"
        } else {
            Write-BuildLog "Certificate test failed!"
            exit 1
        }
        exit 0
    }

    # Sign specific file if requested
    if (-not [string]::IsNullOrEmpty($SignFile)) {
        if (Add-CodeSignature -FilePath $SignFile -SigningConfig $signingConfig) {
            Write-BuildLog "File signed successfully!"
        } else {
            Write-BuildLog "Failed to sign file!"
            exit 1
        }
        exit 0
    }

    # Sign all files if requested
    if ($SignAll) {
        if (-not $signingConfig.enabled) {
            Write-BuildLog "Code signing is disabled in configuration."
            Write-BuildLog "Please enable signing and configure certificate thumbprint."
            exit 1
        }

        if (Test-Certificate -SigningConfig $signingConfig) {
            if (Add-AllCodeSignatures -BuildPath $BuildPath -SigningConfig $signingConfig) {
                # Use the already loaded configuration
                $buildConfig = $fullConfig.buildSettings

                if ($buildConfig.createDistribution) {
                    $distributionPath = New-SignedDistribution -BuildPath $BuildPath -BuildConfig $buildConfig
                    Write-BuildLog "Signed distribution package created: $distributionPath"
                }

                Write-BuildLog "All files signed successfully!"
            } else {
                Write-BuildLog "Some files failed to sign!"
                exit 1
            }
        } else {
            Write-BuildLog "Certificate validation failed!"
            exit 1
        }
        exit 0
    }

    # Show usage if no specific action requested
    Write-BuildLog "Usage:"
    Write-BuildLog "./Sign-Executables.ps1 -ListCertificates      # List available certificates"
    Write-BuildLog "./Sign-Executables.ps1 -TestCertificate       # Test configured certificate"
    Write-BuildLog "./Sign-Executables.ps1 -SignAll               # Sign all executables in build directory"
    Write-BuildLog "./Sign-Executables.ps1 -SignFile <path>       # Sign specific file"
    Write-Host ""
    Write-BuildLog "Configuration:"
    Write-BuildLog "Signing Config file: $SigningConfigPath"
    Write-BuildLog "Build path: $BuildPath"
    Write-BuildLog "Signing enabled: $($signingConfig.enabled)"
    Write-Host ""
    Write-BuildLog "Setup Instructions:"
    Write-BuildLog "1. Install Extended Validation certificate in Windows Certificate Store"
    Write-BuildLog "2. Run: ./Sign-Executables.ps1 -ListCertificates"
    Write-BuildLog "3. Copy certificate thumbprint to signing-config.json"
    Write-BuildLog "4. Set 'enabled: true' in signing-config.json"
    Write-BuildLog "5. Run: ./Sign-Executables.ps1 -TestCertificate"
    Write-BuildLog "6. Run: ./Sign-Executables.ps1 -SignAll"

} catch {
    Write-BuildLog "Unexpected error: $($_.Exception.Message)" -Level Error
    exit 1
}
