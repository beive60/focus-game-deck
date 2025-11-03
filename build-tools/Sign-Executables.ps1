# Focus Game Deck - Code Signing Script
# This script handles digital signing of executables with Extended Validation certificates

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

    if (-not (Test-Path $SigningConfigPath)) {
        Write-Error "Signing configuration not found: $SigningConfigPath"
        return $null
    }

    try {
        $config = Get-Content $SigningConfigPath -Raw | ConvertFrom-Json
        return $config.codeSigningSettings
    } catch {
        Write-Error "Failed to load signing configuration: $($_.Exception.Message)"
        return $null
    }
}

# List available code signing certificates
function Get-CodeSigningCertificates {
    Write-Host "Available Code Signing Certificates:" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan

    $certs = Get-ChildItem -Path "Cert:/CurrentUser/My" | Where-Object {
        $_.Extensions | Where-Object {
            $_.Oid.FriendlyName -eq "Enhanced Key Usage" -and
            $_.Format($false) -match "Code Signing"
        }
    }

    if ($certs.Count -eq 0) {
        Write-Host "No code signing certificates found in CurrentUser/My store." -ForegroundColor Yellow
        Write-Host "Please install an Extended Validation certificate first." -ForegroundColor Yellow
        return $null
    }

    foreach ($cert in $certs) {
        Write-Host "Certificate Details:" -ForegroundColor Green
        Write-Host "Subject: $($cert.Subject)" -ForegroundColor White
        Write-Host "Issuer: $($cert.Issuer)" -ForegroundColor White
        Write-Host "Thumbprint: $($cert.Thumbprint)" -ForegroundColor Yellow
        Write-Host "Valid From: $($cert.NotBefore)" -ForegroundColor White
        Write-Host "Valid To: $($cert.NotAfter)" -ForegroundColor White
        Write-Host "Has Private Key: $($cert.HasPrivateKey)" -ForegroundColor White

        # Check if certificate is expired
        if ($cert.NotAfter -lt (Get-Date)) {
            Write-Host "Status: EXPIRED" -ForegroundColor Red
        } elseif ($cert.NotBefore -gt (Get-Date)) {
            Write-Host "Status: NOT YET VALID" -ForegroundColor Yellow
        } else {
            Write-Host "Status: VALID" -ForegroundColor Green
        }

        Write-Host ("-" * 50) -ForegroundColor Gray
    }

    return $certs
}

# Test certificate functionality
function Test-Certificate {
    param([object]$SigningConfig)

    if (-not $SigningConfig) {
        Write-Error "Signing configuration is required for certificate testing"
        return $false
    }

    if ([string]::IsNullOrEmpty($SigningConfig.certificateThumbprint)) {
        Write-Host "No certificate thumbprint configured. Available certificates:" -ForegroundColor Yellow
        Get-CodeSigningCertificates
        return $false
    }

    Write-Host "Testing certificate: $($SigningConfig.certificateThumbprint)" -ForegroundColor Cyan

    try {
        $cert = Get-ChildItem -Path $SigningConfig.certificateStorePath |
        Where-Object { $_.Thumbprint -eq $SigningConfig.certificateThumbprint }

        if (-not $cert) {
            Write-Error "Certificate not found with thumbprint: $($SigningConfig.certificateThumbprint)"
            return $false
        }

        Write-Host "Certificate found and accessible:" -ForegroundColor Green
        Write-Host "Subject: $($cert.Subject)" -ForegroundColor White
        Write-Host "Valid To: $($cert.NotAfter)" -ForegroundColor White
        Write-Host "Has Private Key: $($cert.HasPrivateKey)" -ForegroundColor White

        if (-not $cert.HasPrivateKey) {
            Write-Error "Certificate does not have an associated private key"
            return $false
        }

        if ($cert.NotAfter -lt (Get-Date)) {
            Write-Error "Certificate has expired"
            return $false
        }

        # Test timestamp server connectivity
        Write-Host "Testing timestamp server connectivity..." -ForegroundColor Cyan
        try {
            $null = Invoke-WebRequest -Uri $SigningConfig.timestampServer -Method Head -TimeoutSec 10
            Write-Host "Timestamp server is accessible" -ForegroundColor Green
        } catch {
            Write-Warning "Timestamp server test failed: $($_.Exception.Message)"
        }

        return $true

    } catch {
        Write-Error "Certificate test failed: $($_.Exception.Message)"
        return $false
    }
}

# Sign a single file
function Add-CodeSignature {
    param(
        [string]$FilePath,
        [object]$SigningConfig
    )

    if (-not (Test-Path $FilePath)) {
        Write-Error "File not found: $FilePath"
        return $false
    }

    if (-not $SigningConfig.enabled) {
        Write-Host "Code signing is disabled in configuration." -ForegroundColor Yellow
        return $false
    }

    Write-Host "Signing file: $(Split-Path $FilePath -Leaf)" -ForegroundColor Cyan

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

        Write-Host "Signature analysis for: $fileName" -ForegroundColor Cyan
        Write-Host "Signature applied: $($isSignatureApplied)" -ForegroundColor $(if($isSignatureApplied) {"Green"} else {"Red"})
        Write-Host "Signature trusted: $($isSignatureTrusted)" -ForegroundColor $(if($isSignatureTrusted) {"Green"} else {"Yellow"})
        Write-Host "Signature status: $($signature.Status)" -ForegroundColor Gray

        if ($signature.SignerCertificate) {
            Write-Host "Certificate subject: $($signature.SignerCertificate.Subject)" -ForegroundColor Gray
        }

        if ($isSignatureApplied) {
            if ($isSignatureTrusted) {
                Write-Host "Successfully signed with trusted certificate: $fileName" -ForegroundColor Green
            } else {
                Write-Host "Successfully signed with test/self-signed certificate: $fileName" -ForegroundColor Yellow
                Write-Host "Note: Certificate is not trusted by system (expected for test certificates)" -ForegroundColor Gray
            }
            return $true
        } else {
            Write-Error "Failed to apply signature to: $fileName"
            return $false
        }

    } catch {
        Write-Error "Failed to sign file: $($_.Exception.Message)"
        return $false
    }
}

# Sign all executables in build directory
function Add-AllCodeSignatures {
    param(
        [string]$BuildPath,
        [object]$SigningConfig
    )

    if (-not (Test-Path $BuildPath)) {
        Write-Error "Build directory not found: $BuildPath"
        return $false
    }

    $exeFiles = Get-ChildItem -Path $BuildPath -Filter "*.exe" -Recurse

    if ($exeFiles.Count -eq 0) {
        Write-Host "No executable files found in build directory." -ForegroundColor Yellow
        return $true
    }

    Write-Host "Found $($exeFiles.Count) executable files to sign:" -ForegroundColor Cyan

    $successCount = 0
    $failCount = 0

    foreach ($exeFile in $exeFiles) {
        if (Add-CodeSignature -FilePath $exeFile.FullName -SigningConfig $SigningConfig) {
            $successCount++
        } else {
            $failCount++
        }
    }

    Write-Host "Signing Summary:" -ForegroundColor Cyan
    Write-Host "Successfully signed: $successCount" -ForegroundColor Green
    if ($failCount -gt 0) {
        Write-Host "Failed to sign: $failCount" -ForegroundColor Red
    } elseif ($failCount -eq 0) {
        Write-Host "All files signed successfully!" -ForegroundColor Green
    }

    return $failCount -eq 0
}

# Create signed distribution package
function New-SignedDistribution {
    param(
        [string]$BuildPath,
        [object]$BuildConfig
    )

    $signedDir = Join-Path (Split-Path $BuildPath -Parent) $BuildConfig.signedDirectory

    if (Test-Path $signedDir) {
        Remove-Item $signedDir -Recurse -Force
    }

    New-Item -ItemType Directory -Path $signedDir -Force | Out-Null

    # Copy all files from build directory
    Copy-Item -Path "$BuildPath/*" -Destination $signedDir -Recurse -Force

    Write-Host "Created signed distribution package: $signedDir" -ForegroundColor Green

    # Create version info file
    $versionInfo = @{
        BuildDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Version = "1.0.0"
        SignedFiles = @()
    }

    # List signed files
    $signedFiles = Get-ChildItem -Path $signedDir -Filter "*.exe" -Recurse
    foreach ($file in $signedFiles) {
        $signature = Get-AuthenticodeSignature -FilePath $file.FullName
        $versionInfo.SignedFiles += @{
            FileName = $file.Name
            SignatureStatus = $signature.Status.ToString()
            SignerCertificate = if ($signature.SignerCertificate) { $signature.SignerCertificate.Subject } else { "None" }
            TimeStamperCertificate = if ($signature.TimeStamperCertificate) { $signature.TimeStamperCertificate.Subject } else { "None" }
        }
    }

    $versionInfoPath = Join-Path $signedDir "signature-info.json"
    $versionInfo | ConvertTo-Json -Depth 4 | Set-Content -Path $versionInfoPath -Encoding UTF8

    Write-Host "Signature information saved to: signature-info.json" -ForegroundColor Green

    return $signedDir
}

# Main script execution
try {
    Write-Host "Focus Game Deck - Code Signing Tool" -ForegroundColor Cyan
    Write-Host "====================================" -ForegroundColor Cyan

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
            Write-Host "Certificate test passed!" -ForegroundColor Green
        } else {
            Write-Host "Certificate test failed!" -ForegroundColor Red
            exit 1
        }
        exit 0
    }

    # Sign specific file if requested
    if (-not [string]::IsNullOrEmpty($SignFile)) {
        if (Add-CodeSignature -FilePath $SignFile -SigningConfig $signingConfig) {
            Write-Host "File signed successfully!" -ForegroundColor Green
        } else {
            Write-Host "Failed to sign file!" -ForegroundColor Red
            exit 1
        }
        exit 0
    }

    # Sign all files if requested
    if ($SignAll) {
        if (-not $signingConfig.enabled) {
            Write-Host "Code signing is disabled in configuration." -ForegroundColor Yellow
            Write-Host "Please enable signing and configure certificate thumbprint." -ForegroundColor Yellow
            exit 1
        }

        if (Test-Certificate -SigningConfig $signingConfig) {
            if (Add-AllCodeSignatures -BuildPath $BuildPath -SigningConfig $signingConfig) {
                # Use the already loaded configuration
                $buildConfig = $fullConfig.buildSettings

                if ($buildConfig.createDistribution) {
                    $distributionPath = New-SignedDistribution -BuildPath $BuildPath -BuildConfig $buildConfig
                    Write-Host "Signed distribution package created: $distributionPath" -ForegroundColor Green
                }

                Write-Host "All files signed successfully!" -ForegroundColor Green
            } else {
                Write-Host "Some files failed to sign!" -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Host "Certificate validation failed!" -ForegroundColor Red
            exit 1
        }
        exit 0
    }

    # Show usage if no specific action requested
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "./Sign-Executables.ps1 -ListCertificates      # List available certificates"
    Write-Host "./Sign-Executables.ps1 -TestCertificate       # Test configured certificate"
    Write-Host "./Sign-Executables.ps1 -SignAll               # Sign all executables in build directory"
    Write-Host "./Sign-Executables.ps1 -SignFile <path>       # Sign specific file"
    Write-Host ""
    Write-Host "Configuration:" -ForegroundColor Yellow
    Write-Host "Signing Config file: $SigningConfigPath"
    Write-Host "Build path: $BuildPath"
    Write-Host "Signing enabled: $($signingConfig.enabled)"
    Write-Host ""
    Write-Host "Setup Instructions:" -ForegroundColor Cyan
    Write-Host "1. Install Extended Validation certificate in Windows Certificate Store"
    Write-Host "2. Run: ./Sign-Executables.ps1 -ListCertificates"
    Write-Host "3. Copy certificate thumbprint to signing-config.json"
    Write-Host "4. Set 'enabled: true' in signing-config.json"
    Write-Host "5. Run: ./Sign-Executables.ps1 -TestCertificate"
    Write-Host "6. Run: ./Sign-Executables.ps1 -SignAll"

} catch {
    Write-Error "Unexpected error: $($_.Exception.Message)"
    exit 1
}
