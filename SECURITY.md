# Security Policy

Quantro is designed with a local-first, privacy-native architecture. Because financial records and cryptographic keys reside on client devices, maintaining security integrity is a top priority.

## Supported Versions

Security updates and patches are actively applied to the following versions:

| Version | Supported |
|---|---|
| 1.x.x | Yes |
| < 1.0.0 | No |

## Reporting a Vulnerability

If you discover a potential security vulnerability or sensitive data leak in Quantro:

1. **Do not create a public GitHub issue.**
2. Send an email to the maintainer or report via GitHub Private Vulnerability Reporting on this repository.
3. Include:
   - Detailed description of the issue.
   - Steps to reproduce or proof-of-concept code.
   - Potential impact on client databases, encryption keys, or sync channels.
4. You will receive an initial response acknowledging receipt within 48 hours.
5. Once verified, a patch will be prepared, tested, and released promptly.

## Security Architecture

- **Local Storage**: All transactional and balance records are stored locally using Drift SQLite.
- **Client Encryption**: Sensitive configuration and sync payloads use AES-256-GCM encryption with keys derived on-device using PBKDF2.
- **Zero Telemetry**: The application transmits no analytics, behavioral telemetry, or personal identifiers.
