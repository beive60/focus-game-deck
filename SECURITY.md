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

- ✅ **Only hash values are transmitted** - never the actual log content
- ✅ **No personal information** is sent to external servers
- ✅ **Gaming behavior data stays local** - only cryptographic fingerprints are shared
- ✅ **No user identification** is linked to the notarized hashes
- ✅ **Anonymous operation** - no account creation or login required

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

### Data Format

Each notarized record contains:

```json
{
  "logHash": "abc123...def789",           // SHA256 hash of log file
  "clientTimestamp": "2025-09-26T10:30:00.123Z",  // When hash was calculated
  "serverTimestamp": "2025-09-26T10:30:01.456Z"   // When record was stored
}
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
