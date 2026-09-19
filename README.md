# Quantro

[![CI](https://github.com/suraj-yadav0/money_manager/actions/workflows/ci.yml/badge.svg)](https://github.com/suraj-yadav0/money_manager/actions/workflows/ci.yml)
[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL--3.0-blue.svg)](LICENSE)
[![Latest Release](https://img.shields.io/github/v/release/suraj-yadav0/money_manager?color=10b981&label=Release)](https://github.com/suraj-yadav0/money_manager/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)

Private, local-first financial intelligence engine. Automated bank SMS parsing, local Drift SQLite persistence, deterministic runway forecasting, and client-side AES-256 encryption. Zero telemetry.

[![Quantro Launch Video](assets/brag.gif)](assets/brag.mp4)

<sub>Click the preview above to watch the full launch video with audio.</sub>

---

![Quantro Interface Overview](assets/quantro_preview_mockup.png)

## Features

- **Local-First Ledger**: Stores all accounts, transactions, and budgets locally in SQLite via Drift ORM with full offline query performance.
- **Automated SMS Parsing**: Reads bank debit and credit alerts on Android to eliminate manual transaction entry.
- **Deterministic Runway**: Calculates zero-revenue survival duration based on liquid reserves and rolling burn velocity.
- **Client-Side Encryption**: Sync payloads use AES-256-GCM with keys derived on-device via PBKDF2.
- **Multi-Platform**: Cross-platform Flutter mobile/desktop client alongside a standalone lightweight web client (`web_app/`).
- **Zero Telemetry**: No third-party analytics, behavioral tracking, or data monetization.

## Quick Start

### Android Application (Flutter)

```bash
git clone https://github.com/suraj-yadav0/money_manager.git
cd money_manager

flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Pre-compiled APKs are available on [GitHub Releases](https://github.com/suraj-yadav0/money_manager/releases).

### Web Client (`web_app`)

```bash
cd web_app
npm install
npm run dev
```

For local Docker self-hosting:
```bash
docker compose up -d --build
```

## Testing

```bash
# Flutter unit tests and static analysis
flutter test
flutter analyze

# Web client tests
cd web_app && npm test
```

## License

Quantro is licensed under the [GNU Affero General Public License v3.0 (AGPL-3.0)](LICENSE) to guarantee that it remains strictly copyleft and open source. Any network deployments or modifications must share their complete source code under the same terms.

For contribution workflow and coding standards, refer to [CONTRIBUTING.md](CONTRIBUTING.md).
