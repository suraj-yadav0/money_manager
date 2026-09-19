# Quantro — Private Financial Intelligence

[![CI](https://github.com/suraj-yadav0/money_manager/actions/workflows/ci.yml/badge.svg)](https://github.com/suraj-yadav0/money_manager/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Latest Release](https://img.shields.io/github/v/release/suraj-yadav0/money_manager?color=10b981&label=Release)](https://github.com/suraj-yadav0/money_manager/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Architecture](https://img.shields.io/badge/Architecture-Local--First%20%2F%20Drift%20SQLite-10b981)](#architecture--security)

Quantro is a private, local-first financial intelligence engine designed for total personal financial autonomy. It pairs a Flutter Android client with a standalone, responsive web application to deliver real-time expense tracking, automated bank SMS parsing, deterministic runway forecasting, and capital solvency tracking without cloud dependencies.

[![Quantro Launch Video](assets/brag.gif)](assets/brag.mp4)

<sub>Click the preview above to watch the full launch video with audio.</sub>

---

![Quantro Interface Overview](assets/quantro_preview_mockup.png)

---

## Download & Releases

### Android Client
Download pre-compiled universal release builds from GitHub Releases:
- **Latest Release:** [Quantro v1.0.1](https://github.com/suraj-yadav0/money_manager/releases/tag/v1.0.1)
- **Direct APK:** [quantro-v1.0.1.apk](https://github.com/suraj-yadav0/money_manager/releases/download/v1.0.1/quantro-v1.0.1.apk)
- **Compatibility:** Android 8.0+ (ARM64, ARMv7, x86_64)

---

## Core Capabilities

- **Automated SMS Parsing:** Ingests bank debit and credit SMS alerts locally on Android to eliminate manual transaction logging.
- **Local-First Drift SQLite:** All accounts, transactions, and categories persist on-device using Drift ORM with full offline query performance.
- **Deterministic Runway Forecasting:** Computes survival timelines based on liquid reserves and rolling 30-day burn velocity.
- **Capital Solvency & Net Worth:** Real-time tracking of assets, liabilities, and debt-to-asset ratios.
- **Multi-Platform Web Client:** Standalone single-tone web application (`web_app/`) for desktop and LAN access with zero framework bloat.
- **Client-Side Encryption:** Optional cloud backup uses AES-256-GCM encryption with keys derived on-device via PBKDF2.
- **Hardware Biometrics:** Fingerprint and biometric lock support via local system hardware APIs.
- **Zero Telemetry:** No user tracking, analytics pings, or data monetization.

---

## Architecture & Security

```
+-------------------------------------------------------------------------+
|                              Quantro Client                             |
|                                                                         |
|  +--------------------+  +---------------------+  +------------------+  |
|  |   Android Client   |  | Standalone Web App  |  |  Desktop Client  |  |
|  |     (Flutter)      |  |    (Vite / JS)      |  |  (Linux/macOS)   |  |
|  +---------+----------+  +----------+----------+  +--------+---------+  |
|            |                        |                      |            |
|            +-------------------+----+----------------------+            |
|                                |                                        |
|                                v                                        |
|             +--------------------------------------+                    |
|             |          Local-First Engine          |                    |
|             |  - Drift SQLite (Embedded DB)        |                    |
|             |  - Deterministic Financial Math      |                    |
|             |  - SMS Categorization Heuristics     |                    |
|             +------------------+-------------------+                    |
|                                |                                        |
|                                v                                        |
|             +--------------------------------------+                    |
|             |       Client-Side Encryption         |                    |
|             |  - AES-256-GCM Payload Cipher        |                    |
|             |  - PBKDF2 Key Stretching             |                    |
|             |  - Zero-Knowledge Multi-Device Sync  |                    |
|             +--------------------------------------+                    |
+-------------------------------------------------------------------------+
```

---

## Tech Stack

| Domain | Technology | Implementation |
|---|---|---|
| Mobile Client | Flutter (Dart 3) | Cross-platform client for Android, Linux, macOS, Windows |
| State Management | Flutter Riverpod | Reactive state tree and cached computed providers |
| Local Database | Drift SQLite | Type-safe embedded SQL database with migrations |
| Web Application | Vanilla JS + Vite | Lightweight responsive client for browser and LAN |
| Visualizations | Chart.js & Custom SVG | Trajectory forecasts, burn rate curves, and spending donuts |
| Containerization | Docker + Nginx | Multi-stage production container for local self-hosting |
| Testing | package:test, Vitest | Comprehensive unit and integration test suites |

---

## Getting Started

### 1. Mobile Application (Flutter)

#### Prerequisites
- Flutter SDK >= 3.24.0
- Android SDK (for Android builds) or desktop toolchains (Linux/macOS/Windows)

#### Setup & Execution
```bash
# Clone the repository
git clone https://github.com/suraj-yadav0/money_manager.git
cd money_manager

# Install Dart dependencies
flutter pub get

# Generate Drift code and Riverpod providers
dart run build_runner build --delete-conflicting-outputs

# Launch on connected device
flutter run
```

#### Build Production APK
```bash
flutter build apk --release
# Artifact: build/app/outputs/flutter-apk/app-release.apk
```

---

### 2. Web Application (`web_app`)

The web client runs independently and can be hosted locally on your network for family or desktop access.

#### Development Server
```bash
cd web_app
npm install
npm run dev
# Default port: http://localhost:5173
```

#### Production Build & Host
```bash
npm run build
npm run host
# Accessible across LAN at http://<host-ip>:5173
```

#### Docker Self-Hosting
From the repository root:
```bash
docker compose up -d --build
# Default endpoint: http://localhost:8080
```

---

## Testing & Quality Assurance

### Flutter Test Suite
```bash
# Run unit and integration tests
flutter test

# Run static analysis
flutter analyze
```

### Web Client Test Suite
```bash
cd web_app

# Run auth and state unit tests
npm test

# Verify production build
npm run build
```

---

## Project Structure

```
money_manager/
├── lib/
│   ├── main.dart                  # Flutter entry point
│   ├── core/                      # Core infrastructure
│   │   ├── database/              # Drift schema definitions and queries
│   │   ├── navigation/            # Shell routing and navigation state
│   │   ├── services/              # Auth, SMS parsing, and secure storage
│   │   └── theme/                 # Design tokens and theme system
│   └── features/                  # Domain modules
│       ├── dashboard/             # Cash flow, runway, and liquidity views
│       ├── transactions/          # Transaction ledger and SMS review deck
│       ├── budget/                # Category limits and burn pacing
│       ├── goals/                 # Milestone savings targets
│       ├── networth/              # Asset/liability holdings and solvency
│       ├── auth/                  # Authentication and password recovery
│       └── settings/              # Application settings and bank configuration
├── web_app/                       # Standalone web client
│   ├── src/
│   │   ├── auth.js                # Web session and password reset logic
│   │   ├── pages/                 # Dashboard, Ledger, Budget, and Modals
│   │   └── css/                   # Design tokens and responsive styles
│   ├── Dockerfile                 # Multi-stage production Nginx container
│   └── package.json               # Web dependencies and test scripts
├── assets/                        # Video, previews, and application assets
├── test/                          # Flutter unit and widget tests
├── docker-compose.yml             # Local self-hosting configuration
├── CONTRIBUTING.md                # Development and submission guidelines
├── SECURITY.md                    # Vulnerability reporting and encryption architecture
└── LICENSE                        # MIT License
```

---

## Community & Guidelines

- **Contributing:** Please read [CONTRIBUTING.md](CONTRIBUTING.md) for branch conventions, code style, and PR requirements.
- **Security:** Please review [SECURITY.md](SECURITY.md) for vulnerability disclosure procedures.
- **License:** Distributed under the [MIT License](LICENSE).
