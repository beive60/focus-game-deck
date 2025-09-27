# Security Features

## Log Notarization System

Focus Game Deck includes an advanced **Log Notarization System** designed to provide cryptographic proof of log file integrity. This feature helps users demonstrate the authenticity of their gaming sessions in cases where integrity verification is required.

### Overview

The Log Notarization System creates a tamper-evident record of your gaming session logs by:

1. **Calculating SHA256 hash** of the complete log file
2. **Submitting the hash** to a trusted third-party service (Google Firebase/Firestore)
3. **Receiving a Certificate ID** that serves as proof of the log's existence and integrity at a specific point in time

### Privacy Protection

**Your privacy is completely protected:**

- **Only hash values are transmitted** - never the actual log content
- **No personal information** is sent to external servers
- **Gaming behavior data stays local** - only cryptographic fingerprints are shared
- **No user identification** is linked to the notarized hashes
- **Anonymous operation** - no account creation or login required

### How It Works

```text
[Local Log File] → [SHA256 Hash] → [Firebase Firestore] → [Certificate ID]
```

1. **During gaming session**: Focus Game Deck creates detailed logs of all actions and events
2. **At session end**: The system calculates a SHA256 hash of the complete log file
3. **Secure transmission**: Only the hash (not the content) is sent to Firebase
4. **Timestamped record**: Firebase stores the hash with both client and server timestamps
5. **Certificate ID**: A unique document ID is returned as your "proof of integrity" certificate

### Certificate ID Usage

The Certificate ID serves as your **proof of log integrity**. In situations where you need to demonstrate the authenticity of your gaming session:

1. **Provide the Certificate ID** to the relevant party
2. **Share your local log file** (if required and appropriate)
3. **Verification process**: The party can recalculate the SHA256 hash of your log file and verify it matches the hash stored in the Firebase database under your Certificate ID

### Technical Implementation

- **Hash Algorithm**: SHA256 (256-bit cryptographic hash)
- **Storage Service**: Google Firebase Firestore (99.95% uptime SLA)
- **Data Retention**: Permanent storage (no automatic deletion)
- **Transport Security**: HTTPS/TLS 1.3 encryption
- **Database Security**: Write-only access (no updates/deletions possible after creation)

### Firebase Security Rules

The Firebase database is configured with strict security rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /log_hashes/{logId} {
      allow create: if true;           // Anyone can create new records
      allow read, update, delete: if false;  // No modifications allowed
    }
  }
}
```

This ensures that:

- New notarization records can be created by anyone
- **No one can modify or delete existing records** (immutable audit trail)
- Data integrity is preserved permanently

### Cost Considerations

- **Free for users**: No cost to end users
- **Sustainable operation**: Uses Firebase's generous free tier limits
- **Minimal resource usage**: Only hash values are stored (64 bytes per session)

### Configuration

Log notarization is **disabled by default** and must be explicitly enabled:

#### Via Configuration File

```json
{
  "logging": {
    "enableNotarization": true,
    "firebase": {
      "projectId": "your-firebase-project-id",
      "apiKey": "your-firebase-api-key"
    }
  }
}
```

#### Via GUI Configuration Editor

1. Open the Configuration Editor
2. Navigate to **Global Settings** tab
3. Check **"Enable Log Notarization"**
4. Save configuration

### Use Cases

The Log Notarization System is particularly valuable in scenarios such as:

- **Anti-cheat false positives**: Providing evidence of legitimate gameplay
- **Tournament disputes**: Demonstrating authentic game session records
- **Support ticket escalation**: Proving the integrity of diagnostic logs
- **Competitive gaming verification**: Showing unmodified session data
- **Legal proceedings**: Providing cryptographically verifiable evidence

## Enhanced Chain-of-Trust Authentication (v1.0.1+)

Starting from version 1.0.1, Focus Game Deck implements an **Enhanced Chain-of-Trust Authentication System** that not only proves log integrity but also verifies the **authenticity of the application** that generated the logs.

### The Problem: Log Forgery Prevention

The original system could only prove that a log file hadn't been modified after creation, but couldn't prevent malicious actors from:

- Creating fake logs using modified versions of the application
- Impersonating official releases with unsigned binaries
- Distributing backdoored versions that generate falsified session data

### The Solution: Self-Authentication

The enhanced system creates a **cryptographic chain of trust** by recording:

1. **Log Hash** (as before): Proves content integrity
2. **Application Signature Hash**: Proves the log was generated by an official, signed executable
3. **Application Version**: Links the log to a specific release
4. **Executable Path**: Provides audit trail of the running binary

### How Self-Authentication Works

```text
[Signed .exe] → [Digital Signature] → [Certificate Hash] → [Firebase Record]
     ↓                                                           ↑
[Log Generation] → [SHA256 Hash] → [Combined with App Hash] → [Upload]
```

1. **At startup**: Application reads its own digital signature using `Get-AuthenticodeSignature`
2. **Signature extraction**: Certificate thumbprint is cached as the "app signature hash"
3. **Version detection**: Current version is loaded from `Version.ps1`
4. **Log notarization**: Both log hash AND app authentication data are sent to Firebase

### Enhanced Data Format

Each notarized record now contains:

```json
{
  "logHash": "abc123...def789",                    // SHA256 hash of log file
  "appSignatureHash": "fedcba...987654",           // Certificate thumbprint of executable
  "appVersion": "v1.0.1-alpha",                    // Application version from Version.ps1
  "executablePath": "C:\\Path\\To\\Focus-Game-Deck.exe",  // Path to running executable
  "clientTimestamp": "2025-09-26T10:30:00.123Z",  // When hash was calculated
  "serverTimestamp": "2025-09-26T10:30:01.456Z"   // When record was stored
}
```

### Official Signature Registry

All official releases maintain a registry of authentic signature hashes in [`docs/official_signature_hashes.json`](docs/official_signature_hashes.json):

```json
{
  "releases": {
    "v1.0.1-alpha": {
      "executables": {
        "Focus-Game-Deck.exe": {
          "signatureHash": "A1B2C3D4E5F6...",
          "description": "Main application executable"
        },
        "Focus-Game-Deck-MultiPlatform.exe": {
          "signatureHash": "F6E5D4C3B2A1...",
          "description": "Multi-platform version"
        },
        "Focus-Game-Deck-Config-Editor.exe": {
          "signatureHash": "123456789ABC...",
          "description": "GUI configuration editor"
        }
      }
    }
  }
}
```

### Verification Process (Enhanced)

To verify a log file with chain-of-trust authentication:

1. **Obtain Certificate ID** from user
2. **Query Firebase record** using Certificate ID
3. **Extract authentication data**:
   - `logHash`: Used for log integrity verification
   - `appSignatureHash`: Used for application authenticity verification
   - `appVersion`: Used to locate official registry entry
4. **Verify log integrity**: Calculate SHA256 of log file, compare with `logHash`
5. **Verify application authenticity**:
   - Look up `appVersion` in `docs/official_signature_hashes.json`
   - Find the matching executable entry
   - Compare `appSignatureHash` with registry entry
6. **Assessment**:
   - **Fully Authentic**: Both hashes match official registry
   - **Content Valid, Source Unknown**: Log hash valid but app signature not in registry
   - **Invalid**: Log hash doesn't match file content

### Development vs Production Signatures

The system handles different build types appropriately:

- **Production builds** (signed): Record actual certificate thumbprint
- **Development builds** (unsigned): Record `"UNSIGNED_DEVELOPMENT_BUILD"`
- **Invalid signatures**: Record `"INVALID_SIGNATURE_[STATUS]"`
- **Verification errors**: Record `"SIGNATURE_VERIFICATION_ERROR"`

### Registry Maintenance

The official signature registry is automatically maintained:

1. **During production builds**: `Master-Build.ps1` with `-Production` flag
2. **After code signing**: `Sign-Executables.ps1` completes successfully
3. **Automatic recording**: Signature hashes are extracted and recorded
4. **Git tracking**: Registry changes are committed to version control

### Attack Prevention

This enhanced system prevents several attack vectors:

| Attack Type | Prevention Method |
|-------------|------------------|
| **Fake logs from modified binaries** | App signature won't match official registry |
| **Backdoored applications** | Unofficial signatures will be flagged |
| **Log replay attacks** | Each session gets unique timestamp |
| **Certificate spoofing** | Registry is version-controlled and publicly auditable |
| **Development build abuse** | Clear marking of unsigned builds |

### Legacy Compatibility

- **Existing logs**: Old records without authentication data remain valid
- **Gradual migration**: New authentication fields are additive, not breaking
- **Client support**: Older versions continue to work (without enhanced security)

### Privacy Considerations

The enhanced system maintains privacy protection:

- **No additional personal data**: Only cryptographic hashes are transmitted
- **Executable path sanitization**: Only filename, not full paths containing usernames
- **Anonymous operation**: No user identification required
- **Audit trail**: All signature hashes are publicly verifiable

### Verification Command Line Example

Example PowerShell script for verifying enhanced logs:

```powershell
# Example verification script
param($CertificateId, $LogFilePath)

# 1. Query Firebase for record
$record = Invoke-RestMethod -Uri "https://firestore.googleapis.com/v1/projects/PROJECT_ID/databases/(default)/documents/log_hashes/$CertificateId"

# 2. Extract data
$logHash = $record.fields.logHash.stringValue
$appSignatureHash = $record.fields.appSignatureHash.stringValue
$appVersion = $record.fields.appVersion.stringValue

# 3. Verify log integrity
$actualLogHash = (Get-FileHash -Path $LogFilePath -Algorithm SHA256).Hash
$logIntegrityValid = ($logHash -eq $actualLogHash)

# 4. Verify application authenticity
$registry = Get-Content "docs/official_signature_hashes.json" | ConvertFrom-Json
$officialHashes = $registry.releases.$appVersion.executables | Get-Member -MemberType NoteProperty | ForEach-Object { $registry.releases.$appVersion.executables.($_.Name).signatureHash }
$appAuthentic = ($appSignatureHash -in $officialHashes)

# 5. Results
Write-Host "Log Integrity: $(if ($logIntegrityValid) { 'VALID' } else { 'INVALID' })"
Write-Host "App Authenticity: $(if ($appAuthentic) { 'OFFICIAL' } else { 'UNOFFICIAL' })"
```

### Verification Process

To verify a log file against a Certificate ID:

1. **Obtain the original log file** from the user
2. **Calculate SHA256 hash** of the file: `Get-FileHash -Algorithm SHA256 logfile.log`
3. **Query Firebase** using the Certificate ID to retrieve the stored hash
4. **Compare hashes**: If they match, the log file is authentic and unmodified

### Limitations and Considerations

- **Network dependency**: Requires internet connection during notarization
- **Timestamp trust**: Client timestamps are user-controllable (server timestamps are authoritative)
- **Storage permanence**: Records cannot be deleted (this is by design for integrity)
- **No content verification**: System only proves file integrity, not content validity
- **Rate limiting**: Subject to Firebase API rate limits (should not affect normal usage)

### Troubleshooting

**Common issues and solutions:**

1. **"Firebase configuration not set"**
   - Ensure `projectId` and `apiKey` are configured in `config.json`
   - Verify Firebase project exists and Firestore is enabled

2. **"Failed to send hash to Firebase"**
   - Check internet connectivity
   - Verify Firebase API key is valid and has Firestore permissions
   - Ensure Firebase project ID is correct

3. **"No log file to notarize"**
   - Enable file logging: Set `enableFileLogging: true` in logging configuration
   - Ensure log directory is writable

### Security Considerations

- **Hash collision resistance**: SHA256 provides ~2^256 security against hash collisions
- **Immutable audit trail**: Firebase rules prevent modification of stored records
- **Transport security**: All communications use HTTPS encryption
- **No authentication required**: Reduces attack surface and privacy concerns

### Future Enhancements

Planned improvements to the Log Notarization System:

- **Blockchain integration**: Additional notarization via public blockchain
- **Third-party timestamp authorities**: RFC 3161 compliant timestamping
- **Batch processing**: Efficient handling of multiple log files
- **Verification utilities**: Standalone tools for hash verification

---

## Contact Information

For security-related questions or concerns about the Log Notarization System:

- **GitHub Issues**: Report bugs or feature requests
- **Documentation**: Check `docs/` directory for additional technical details
- **Community**: Join discussions in project forums

---

*This document was last updated: September 26, 2025*
*Version: 1.0.0*
