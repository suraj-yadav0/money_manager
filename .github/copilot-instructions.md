# Copilot Instructions for Quantro – Smart Finance Manager

## Project Overview

**Quantro** is a cross-platform personal finance manager built with Flutter/Dart. It helps users track income and expenses, set savings goals, manage budgets, and visualise their net worth. The app targets Android, iOS, Web, Linux, macOS, and Windows.

Package name: `money_manager`  
App display name: `Quantro`

---

## Tech Stack

| Concern | Library |
|---|---|
| UI Framework | Flutter (Material 3) |
| State Management | [Riverpod](https://riverpod.dev/) (`flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`) |
| Local Database | [Drift](https://drift.simonbinder.eu/) (SQLite via `sqlite3_flutter_libs`) |
| Charts | `fl_chart`, `table_calendar` |
| Fonts | `google_fonts` |
| Security | `local_auth`, `flutter_secure_storage` |
| Notifications | `flutter_local_notifications` |
| Utilities | `intl`, `uuid`, `shared_preferences`, `equatable` |
| Image Handling | `image_picker`, `permission_handler` |

---

## Project Structure

```
lib/
├── main.dart                  # App entry point; wraps everything in ProviderScope
├── core/
│   ├── database/              # Drift database definition (database.dart, database.g.dart)
│   ├── navigation/            # AppShell and bottom-nav routing
│   ├── presentation/          # Shared widgets
│   ├── providers/             # Top-level Riverpod providers (e.g. app_state_provider)
│   ├── theme/                 # Light/dark AppTheme definitions
│   └── utils/                 # Formatting helpers, extensions, etc.
└── features/
    ├── budget/                # Monthly budget management
    ├── dashboard/             # Home screen overview
    ├── goals/                 # Savings goals
    ├── insights/              # Spending analytics & charts
    ├── networth/              # Asset/liability tracking
    ├── onboarding/            # First-run onboarding flow
    ├── settings/              # User preferences
    └── transactions/          # Income/expense CRUD + categorisation
        ├── screens/
        └── services/          # Categorisation engine, recurring transactions
test/
└── widget_test.dart           # Flutter widget tests
```

---

## Database Schema (Drift)

The database is defined in `lib/core/database/database.dart` and the generated code lives in `database.g.dart`. **Never edit `database.g.dart` manually.**

Tables:
- `Transactions` – income and expense records
- `Categories` – predefined and user-created transaction categories
- `UserSettings` – single-row user preferences (currency, onboarding status, etc.)
- `Goals` – savings goals with target amounts and deadlines
- `GoalContributions` – individual contributions toward a goal
- `CategorizationRules` – keyword → category mappings learned from user corrections
- `Assets` – net-worth items (savings, investments, loans, property, gold, etc.)

Current schema version: **8**. Every schema change requires a new migration step in the `onUpgrade` callback and a version bump.

---

## Code Generation

Several files are generated and must be regenerated after modifying their source:

```bash
# Regenerate Drift database code and Riverpod providers
flutter pub run build_runner build --delete-conflicting-outputs
```

Files that are generated (do not edit manually):
- `lib/core/database/database.g.dart`
- Any `*.g.dart` or `*.freezed.dart` files produced by `riverpod_generator`

---

## Coding Conventions

- **Dart/Flutter style**: Follow the [official Dart style guide](https://dart.dev/guides/language/effective-dart/style). The project uses `flutter_lints`; run `flutter analyze` to check.
- **State management**: Use Riverpod providers annotated with `@riverpod` (code-gen style). Prefer `AsyncNotifierProvider` for async state, `NotifierProvider` for sync state.
- **Immutability**: Prefer `const` constructors and immutable data wherever possible.
- **Naming**:
  - Files and directories: `snake_case`
  - Classes: `PascalCase`
  - Variables/functions: `camelCase`
  - Private members: prefix with `_`
- **Widget decomposition**: Extract reusable UI into small, focused widgets inside `core/presentation/` or a feature's own `widgets/` subfolder.
- **Error handling**: Surface errors through Riverpod's `AsyncValue.error` state; do not swallow exceptions silently.
- **Currency**: The default currency is `INR`. Use the `intl` package (`NumberFormat`) for formatting monetary values.
- **No print statements**: Use proper error/logging patterns; avoid `print()` in production code (lint rule `avoid_print`).

---

## Linting & Analysis

```bash
flutter analyze
```

Configuration is in `analysis_options.yaml` (extends `package:flutter_lints/flutter.yaml`).

---

## Running Tests

```bash
flutter test
```

Tests live in the `test/` directory. Widget tests use the standard `flutter_test` package.

---

## Building the App

```bash
# Android (APK)
flutter build apk

# Android (App Bundle)
flutter build appbundle

# iOS
flutter build ios

# Web
flutter build web

# Desktop (example: Linux)
flutter build linux
```

---

## Adding a New Feature

1. Create a new directory under `lib/features/<feature_name>/`.
2. Add `screens/`, `widgets/`, and `providers/` sub-folders as needed.
3. Register any new Drift tables in `lib/core/database/database.dart`, bump `schemaVersion`, and add a migration step.
4. Run code generation: `flutter pub run build_runner build --delete-conflicting-outputs`.
5. Wire up routing in `lib/core/navigation/`.
6. Add widget/unit tests in `test/`.

---

## Key Files to Know

| File | Purpose |
|---|---|
| `lib/main.dart` | App entry point |
| `lib/core/database/database.dart` | Drift schema + migrations |
| `lib/core/theme/app_theme.dart` | Material 3 light/dark themes |
| `lib/core/navigation/app_shell.dart` | Bottom navigation shell |
| `lib/core/providers/app_state_provider.dart` | Global app state (onboarding, etc.) |
| `pubspec.yaml` | Dependencies and asset configuration |
| `analysis_options.yaml` | Lint rules |
