# Quantro - Smart Finance Manager

Quantro is a cross-platform personal finance management application built with Flutter. It provides users with a complete view of their financial health through transaction tracking, budget management, savings goals, and net worth calculation, all stored locally on the device without any server dependency.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Technology Stack](#technology-stack)
- [Database Schema](#database-schema)
- [Application Flow](#application-flow)
- [Setup and Installation](#setup-and-installation)
- [Platform-Specific Build Instructions](#platform-specific-build-instructions)
- [Development Workflow](#development-workflow)
- [Contributing](#contributing)

---

## Overview

Quantro is a local-first, offline personal finance manager. All financial data is stored in a SQLite database on the user's device using the Drift ORM. The application supports six platforms: Android, iOS, Web, Windows, macOS, and Linux.

The app uses a glassmorphic visual design built on the Material 3 design system, with custom theming, animated charts, and a bottom-navigation shell that organizes the main features into distinct tabs.

---

## Features

### Transaction Management

- Record income and expense transactions with amount, category, date, and optional note
- Attach payment mode (Cash, UPI, Credit Card, Debit Card, Bank Transfer, or Other)
- Capture and store receipt images directly from the camera or gallery
- Automatically suggest a category for a transaction based on the description using a keyword-matching categorization engine with over 200 pre-seeded rules
- Define and process recurring transactions on a scheduled basis
- Link individual transactions to savings goals to track goal contributions

### Dashboard and Visualization

- Summary balance card showing total income, total expenses, and net balance for the selected period
- Date filter bar with presets: This Week, Last Week, This Month, This Year, and All Time
- Multiple chart types selectable by the user:
  - Pie chart of spending by category
  - Bar chart of spending by category
  - Line chart of spending trend over time
  - Line chart of income trend over time
- Recent transactions list on the home screen
- Full transactions list with search and filter capabilities
- Calendar view showing days with recorded transactions; tap any day to view its transactions

### Budget Management

- Set a monthly budget per spending category
- Visual progress bar for each category showing spending versus budget
- Budget summary card showing aggregate used and remaining amounts
- Alerts when spending approaches or exceeds a category budget

### Savings Goals

- Create goals with a name, target amount, and optional deadline
- View progress toward each goal as a percentage
- Make manual contributions to a goal at any time, optionally with a note
- Link expense or income transactions to a goal so contributions are tracked automatically
- Mark goals as completed or inactive

### Net Worth Tracking

- Add and manage assets of types: Savings, Investment, Gold, Property, and Other
- Add liabilities such as Loans and Debts
- The net worth screen computes and displays total assets, total liabilities, and net worth
- Edit asset values and notes at any time

### Security

- Optional biometric lock (fingerprint or Face ID) using the device's local authentication
- Sensitive settings stored using Flutter Secure Storage

### Settings and Personalization

- Set monthly income for reference on the dashboard
- Choose the display currency from INR, USD, EUR, and GBP
- Toggle biometric lock on or off
- Toggle income chart visibility

### Onboarding

- First-launch onboarding flow guides the user through initial configuration
- Onboarding state is persisted so it runs only once

---

## Architecture

The application follows a **feature-based clean architecture** pattern. Code is organized by feature rather than by layer, which keeps all related screens, providers, widgets, and services co-located. Shared infrastructure (database, theme, navigation, utilities) lives in a central `core` module.

### Layer Overview

```
+------------------------------------------------------------+
|                        Presentation                        |
|  Screens (UI pages) -- Widgets (reusable components)       |
+------------------------------------------------------------+
|                      State Management                      |
|  Riverpod Providers (feature-specific and global)          |
+------------------------------------------------------------+
|                      Business Logic                        |
|  Services: CategorizationEngine, RecurringService          |
+------------------------------------------------------------+
|                       Data Layer                           |
|  Drift ORM -- SQLite (local, on-device database)           |
+------------------------------------------------------------+
```

### Feature Module Structure

Each feature folder follows this internal layout:

```
features/<feature_name>/
  screens/     # Full-page UI widgets navigated to by the shell or other screens
  widgets/     # Smaller, reusable UI components used within this feature
  providers/   # Riverpod providers that manage state and call the database
  services/    # Business logic classes (categorization, recurrence, etc.)
```

### State Management Flow

```
User Interaction
      |
      v
  Riverpod Provider (StateNotifier / AsyncNotifier / StreamProvider)
      |
      |-- reads/writes --> Drift Database (SQLite)
      |
      v
  UI rebuilds reactively via ref.watch()
```

Providers are either:
- `StreamProvider` - watch a database query in real time; the UI updates automatically when underlying data changes
- `AsyncNotifierProvider` - async operations (loads, saves) with loading and error states
- `StateNotifierProvider` / `NotifierProvider` - synchronous, in-memory state (e.g., selected date filter, selected chart type)

Global providers (database instance, user settings, onboarding flag) are defined in `core/providers/app_state_provider.dart` and are accessible throughout the entire app.

### Navigation

The app uses a bottom navigation shell (`AppShell`) with four top-level tabs:

```
AppShell (Scaffold + BottomNavigationBar)
  |-- Tab 0: Dashboard
  |-- Tab 1: Budget
  |-- Tab 2: Net Worth
  |-- Tab 3: Goals
```

Secondary screens (Calendar, Day Transactions, All Transactions, Settings, Insights, Add Transaction) are pushed onto the navigator stack from within the relevant tab.

---

## Project Structure

```
money_manager/
├── lib/
│   ├── main.dart                        # Application entry point; initializes Riverpod and runs the app
│   ├── core/
│   │   ├── database/
│   │   │   ├── database.dart            # Drift database definition: all tables, queries, and migrations
│   │   │   └── database.g.dart          # Auto-generated Drift code (do not edit manually)
│   │   ├── navigation/
│   │   │   └── app_shell.dart           # Bottom navigation shell with tab routing
│   │   ├── presentation/
│   │   │   └── glass_widgets.dart       # Shared glassmorphic UI components
│   │   ├── providers/
│   │   │   └── app_state_provider.dart  # Global providers: database, settings, onboarding
│   │   ├── theme/
│   │   │   └── app_theme.dart           # ThemeData, color palette, and gradient definitions
│   │   └── utils/
│   │       ├── constants.dart           # App-wide constants (currencies, default values)
│   │       ├── formatters.dart          # Currency and date formatting utilities
│   │       └── icon_helper.dart         # Maps icon name strings to IconData
│   └── features/
│       ├── onboarding/
│       │   └── screens/                 # First-launch onboarding pages
│       ├── dashboard/
│       │   ├── screens/
│       │   │   ├── dashboard_screen.dart         # Main home screen
│       │   │   ├── calendar_view_screen.dart     # Monthly calendar with transaction markers
│       │   │   └── day_transactions_screen.dart  # All transactions for a selected day
│       │   ├── widgets/
│       │   │   ├── balance_card.dart             # Summary card (income, expenses, balance)
│       │   │   ├── category_pie_chart.dart        # FL Chart pie chart widget
│       │   │   ├── category_bar_chart.dart        # FL Chart bar chart widget
│       │   │   ├── spending_line_chart.dart       # Daily spending trend chart
│       │   │   ├── income_trend_chart.dart        # Income trend chart
│       │   │   ├── recent_transactions.dart       # Last N transactions list
│       │   │   ├── date_filter_bar.dart           # Date range selector chips
│       │   │   └── day_transactions_list.dart     # Reusable transaction list for a day
│       │   └── providers/
│       │       ├── dashboard_providers.dart       # Aggregated financial data providers
│       │       ├── calendar_providers.dart        # Per-day transaction data for calendar
│       │       └── chart_type_provider.dart       # Currently selected chart type
│       ├── transactions/
│       │   ├── screens/
│       │   │   ├── add_transaction_screen.dart    # Form for creating or editing a transaction
│       │   │   └── all_transactions_screen.dart   # Paginated full transaction history
│       │   └── services/
│       │       ├── categorization_engine.dart     # Keyword-based auto-categorization logic
│       │       └── recurring_service.dart         # Generates due recurring transactions
│       ├── budget/
│       │   ├── screens/
│       │   │   └── budget_screen.dart             # Budget overview and per-category cards
│       │   ├── providers/
│       │   │   └── budget_provider.dart           # Budget vs. spending data provider
│       │   └── widgets/                           # Budget card and progress bar widgets
│       ├── goals/
│       │   ├── screens/
│       │   │   └── goals_screen.dart              # Goals list screen
│       │   ├── providers/
│       │   │   └── goals_provider.dart            # Goals and contributions data providers
│       │   └── widgets/
│       │       ├── goal_card.dart                 # Individual goal progress card
│       │       ├── edit_goal_sheet.dart           # Bottom sheet for editing a goal
│       │       └── add_contribution_sheet.dart    # Bottom sheet for adding a contribution
│       ├── networth/
│       │   ├── screens/
│       │   │   └── net_worth_screen.dart          # Net worth summary and asset list
│       │   ├── providers/
│       │   │   └── net_worth_providers.dart       # Asset/liability data providers
│       │   └── widgets/
│       │       └── add_asset_sheet.dart           # Bottom sheet for adding an asset
│       ├── insights/
│       │   ├── screens/
│       │   │   └── insights_screen.dart           # Spending pattern analysis screen
│       │   └── services/                          # Forecasting and analysis logic
│       └── settings/
│           └── screens/
│               └── settings_screen.dart           # User preferences and configuration
├── assets/                              # App icons and image assets
├── android/                             # Android native project
├── ios/                                 # iOS native project (Xcode)
├── web/                                 # Flutter Web build target
├── windows/                             # Windows desktop build target
├── macos/                               # macOS desktop build target
├── linux/                               # Linux desktop build target
├── test/
│   └── widget_test.dart                 # Widget smoke test
├── pubspec.yaml                         # Project dependencies and metadata
├── analysis_options.yaml                # Dart analyzer and linting configuration
└── README.md                            # This file
```

---

## Technology Stack

| Category | Library / Tool | Version | Purpose |
|---|---|---|---|
| Framework | Flutter | >=3.24.0 | Cross-platform UI framework |
| Language | Dart | >=3.10.7 <4.0.0 | Programming language |
| State Management | flutter_riverpod | 2.6.1 | Reactive state management |
| State Management | riverpod_annotation | 2.6.1 | Annotations for code generation |
| Database ORM | drift | 2.22.1 | Type-safe SQLite ORM |
| SQLite | sqlite3_flutter_libs | - | Bundled SQLite for all platforms |
| Code Generation | build_runner | 2.4.14 | Runs Drift and Riverpod generators |
| Code Generation | drift_dev | 2.22.1 | Drift schema and query generation |
| Code Generation | riverpod_generator | 2.6.3 | Riverpod provider generation |
| Charts | fl_chart | 0.70.2 | Pie, bar, and line charts |
| Calendar | table_calendar | 3.1.3 | Monthly calendar with event markers |
| Typography | google_fonts | 6.2.1 | Outfit font family |
| Biometrics | local_auth | 2.3.0 | Fingerprint and Face ID |
| Secure Storage | flutter_secure_storage | 9.2.3 | Encrypted key-value storage |
| Preferences | shared_preferences | 2.3.4 | Lightweight key-value storage |
| Notifications | flutter_local_notifications | 18.0.1 | Local push notifications |
| Image | image_picker | 1.2.1 | Camera and gallery access |
| Permissions | permission_handler | 11.4.0 | Runtime permission management |
| Formatting | intl | 0.20.2 | Date and currency formatting |
| Unique IDs | uuid | 4.5.1 | UUID v4 generation |
| Path Utilities | path_provider | 2.1.5 | Platform-specific directories |
| Icons | cupertino_icons | 1.0.8 | iOS-style icon set |
| Dev: Linting | flutter_lints | 6.0.0 | Recommended Flutter linting rules |
| Dev: Icons | flutter_launcher_icons | 0.13.1 | Multi-platform icon generation |
| Dev: Splash | flutter_native_splash | 2.4.0 | Native splash screen generation |

---

## Database Schema

The app uses a single local SQLite database (`money_manager.sqlite`) managed by Drift. The schema is at version 8, with a non-destructive migration chain from version 1.

### Entity Relationship Overview

```
UserSettings (1)

Categories (1) <----(many) Transactions (many)----> Goals (1)
                                                         |
                                                   GoalContributions

CategorizationRules (keyword --> Category)

Assets (independent)
```

### Table Definitions

**transactions**

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique row identifier |
| amount | REAL | NOT NULL | Transaction amount |
| type | TEXT | NOT NULL | `income` or `expense` |
| category_id | INTEGER | NOT NULL, FK -> categories.id | Associated category |
| goal_id | INTEGER | NULLABLE, FK -> goals.id | Optional linked savings goal |
| timestamp | DATETIME | NOT NULL | Date and time of the transaction |
| note | TEXT | NULLABLE | User description (used for auto-categorization) |
| payment_mode | TEXT | NULLABLE | Cash, UPI, Card, etc. |
| receipt_image_path | TEXT | NULLABLE | File path to stored receipt image |
| is_recurring | BOOLEAN | NOT NULL, DEFAULT false | Whether transaction repeats |
| created_at | DATETIME | NOT NULL | Record creation timestamp |

**categories**

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique row identifier |
| name | TEXT | NOT NULL, UNIQUE | Display name |
| icon | TEXT | NOT NULL | Material icon name string |
| monthly_budget | REAL | NULLABLE | Budget cap for the month |
| type | TEXT | NOT NULL | `income` or `expense` |
| is_default | BOOLEAN | NOT NULL | System-seeded vs user-created |

Pre-seeded expense categories: Food and Dining, Transport, Shopping, Entertainment, Bills and Utilities, Health, Education, Self Care, Groceries, Gifts, Savings, Investments, Family, Other.

Pre-seeded income categories: Salary, Freelance, Investment, Other Income.

**user_settings**

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | INTEGER | PRIMARY KEY | Single-row settings table |
| monthly_income | REAL | NOT NULL | User's stated monthly income |
| currency | TEXT | NOT NULL, DEFAULT `INR` | Display currency code |
| is_onboarded | BOOLEAN | NOT NULL | Whether onboarding has been completed |
| biometric_enabled | BOOLEAN | NOT NULL | Whether biometric lock is active |
| show_income_chart | BOOLEAN | NOT NULL | Whether income chart is visible on dashboard |
| created_at | DATETIME | NOT NULL | Record creation timestamp |

**goals**

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique row identifier |
| name | TEXT | NOT NULL | Goal name |
| target_amount | REAL | NOT NULL | Target savings amount |
| deadline | DATETIME | NOT NULL | Goal deadline |
| saved_amount | REAL | NOT NULL, DEFAULT 0 | Current amount saved toward goal |
| is_active | BOOLEAN | NOT NULL, DEFAULT true | Whether goal is in progress |
| is_completed | BOOLEAN | NOT NULL, DEFAULT false | Whether goal has been reached |
| created_at | DATETIME | NOT NULL | Record creation timestamp |

**goal_contributions**

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique row identifier |
| goal_id | INTEGER | NOT NULL, FK -> goals.id | Parent goal |
| amount | REAL | NOT NULL | Contribution amount |
| note | TEXT | NULLABLE | Optional description |
| created_at | DATETIME | NOT NULL | Contribution timestamp |

**categorization_rules**

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique row identifier |
| keyword | TEXT | NOT NULL | Lowercase keyword to match against transaction notes |
| category_id | INTEGER | NOT NULL, FK -> categories.id | Category to assign on match |
| weight | INTEGER | NOT NULL, DEFAULT 1 | Match confidence weight; higher values take precedence |

Over 200 rules are pre-seeded at first launch, covering merchants and terms such as `zomato`, `swiggy`, `uber`, `amazon`, `netflix`, `salary`, `rent`, and others.

**assets**

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique row identifier |
| name | TEXT | NOT NULL | Asset or liability display name |
| type | TEXT | NOT NULL | `savings`, `investment`, `loan`, `gold`, `property`, or `other` |
| value | REAL | NOT NULL | Current monetary value |
| is_liability | BOOLEAN | NOT NULL | True for debts/loans; affects net worth direction |
| note | TEXT | NULLABLE | Optional description |
| created_at | DATETIME | NOT NULL | Record creation timestamp |
| updated_at | DATETIME | NOT NULL | Last modification timestamp |

---

## Application Flow

### Startup and Onboarding

```
App Launch
    |
    v
Read UserSettings from database
    |
    |-- is_onboarded = false --> OnboardingScreen (set monthly income, currency)
    |                                |
    |                                v
    |                           Save settings, set is_onboarded = true
    |                                |
    v                                v
biometric_enabled = true        AppShell (main navigation)
    |
    v
BiometricLockScreen
    |-- authentication success --> AppShell
    |-- no biometrics enrolled --> AppShell (bypass)
```

### Adding a Transaction

```
User taps "Add Transaction" (FAB)
    |
    v
AddTransactionScreen
    |
    |-- User enters note text
    |       |
    |       v
    |   CategorizationEngine.suggest(note)
    |       |-- tokenize note into lowercase keywords
    |       |-- look up each keyword in categorization_rules
    |       |-- return category with highest total weight
    |       |-- if no match, return "Other" category
    |
    |-- User selects type (income / expense), amount, date, payment mode
    |-- User optionally attaches a receipt image (image_picker)
    |-- User optionally links to a savings goal
    |
    v
Validate form fields (amount > 0, category selected)
    |
    v
Write Transaction row to database (Drift insert)
    |
    v
If goal_id is set:
    Update goals.saved_amount += transaction.amount
    Insert GoalContribution row
    |
    v
StreamProviders watching relevant queries emit new data
    |
    v
Dashboard, Budget, Goals, NetWorth screens rebuild automatically
```

### Recurring Transaction Processing

```
App Launch or Dashboard Load
    |
    v
RecurringService.processDueTransactions()
    |
    v
Query all transactions where is_recurring = true
    |
    v
For each recurring transaction:
    |-- Determine next due date from created_at interval
    |-- If due date <= today and no matching transaction exists for that date
    |       |
    |       v
    |   Insert new Transaction row (copy of original with updated timestamp)
    |
    v
StreamProviders emit updated data to UI
```

### Budget Calculation Flow

```
User navigates to Budget tab
    |
    v
BudgetProvider loads:
    |-- All categories of type "expense" with monthly_budget set
    |-- All transactions of type "expense" in the current calendar month
    |
    v
For each category:
    spent    = sum of transaction amounts for this category this month
    budget   = category.monthly_budget
    remaining = budget - spent
    percent   = spent / budget * 100
    |
    v
BudgetScreen renders a card per category with progress bar and amounts
```

### Net Worth Calculation Flow

```
User navigates to Net Worth tab
    |
    v
NetWorthProvider loads all rows from assets table
    |
    v
total_assets      = sum of value where is_liability = false
total_liabilities = sum of value where is_liability = true
net_worth         = total_assets - total_liabilities
    |
    v
NetWorthScreen renders summary header and per-asset list
```

---

## Setup and Installation

### Prerequisites

| Tool | Minimum Version | Notes |
|---|---|---|
| Flutter SDK | 3.24.0 | Install via flutter.dev or fvm |
| Dart SDK | 3.10.7 | Bundled with Flutter |
| Android Studio | Latest stable | Required for Android builds; provides SDK and emulator |
| Xcode | 12 or later | Required for iOS and macOS builds; macOS only |
| Visual Studio | 2022 with C++ workload | Required for Windows builds |
| CMake | 3.14+ | Required for Linux builds |
| GCC / Clang | System default | Required for Linux builds |

### Installation Steps

**1. Clone the repository**

```bash
git clone https://github.com/suraj-yadav0/money_manager.git
cd money_manager
```

**2. Install Flutter dependencies**

```bash
flutter pub get
```

**3. Run code generation**

Drift (database) and Riverpod (state management) both require generated files. These generated files (`*.g.dart`) are checked into the repository, so this step is only required when database tables or providers change.

```bash
dart run build_runner build --delete-conflicting-outputs
```

To keep generated files updated continuously during development:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

**4. Verify the setup**

```bash
flutter doctor
flutter analyze
```

**5. Run the application**

```bash
# Android (with a device connected or emulator running)
flutter run -d android

# iOS Simulator (macOS only)
flutter run -d iphone

# Web (Chrome)
flutter run -d chrome

# Windows
flutter run -d windows

# macOS
flutter run -d macos

# Linux
flutter run -d linux
```

---

## Platform-Specific Build Instructions

### Android

**Prerequisites:** Android SDK installed, `ANDROID_HOME` environment variable set.

```bash
# Debug APK
flutter build apk --debug

# Release APK (requires signing configuration in android/app/build.gradle)
flutter build apk --release

# App Bundle for Play Store submission
flutter build appbundle --release
```

Signing configuration is added to `android/app/build.gradle`. See the [Flutter documentation on Android release builds](https://docs.flutter.dev/deployment/android) for key generation and signing setup.

### iOS

**Prerequisites:** macOS with Xcode installed and configured. An Apple Developer account is required for device deployment and App Store submission.

```bash
# Open the Xcode workspace to configure signing
open ios/Runner.xcworkspace

# Build from command line (after signing is configured in Xcode)
flutter build ios --release

# Archive for App Store Connect
flutter build ipa
```

### Web

```bash
flutter build web --release
```

The output is placed in `build/web/`. Deploy this directory to any static web hosting service (Netlify, Vercel, GitHub Pages, Firebase Hosting, etc.).

### Windows

**Prerequisites:** Visual Studio 2022 with the "Desktop development with C++" workload installed.

```bash
flutter build windows --release
```

Output is placed in `build/windows/runner/Release/`.

### macOS

**Prerequisites:** macOS with Xcode. Requires an Apple Developer account for distribution outside of direct local builds.

```bash
flutter build macos --release
```

Output is placed in `build/macos/Build/Products/Release/`.

### Linux

**Prerequisites:** `gcc`, `cmake`, `make`, `libgtk-3-dev`, and `libblkid-dev` packages installed.

```bash
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev
flutter build linux --release
```

Output is placed in `build/linux/x64/release/bundle/`.

---

## Development Workflow

### Generating Code

After modifying any Drift table definition in `lib/core/database/database.dart`, or after adding or modifying Riverpod providers annotated with `@riverpod`, regenerate the corresponding files:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Generating App Icons

The launcher icon configuration is defined in `pubspec.yaml` under the `flutter_launcher_icons` key.

```bash
dart run flutter_launcher_icons:main
```

### Generating Native Splash Screen

The splash screen configuration is defined in `pubspec.yaml` under the `flutter_native_splash` key.

```bash
dart run flutter_native_splash:create
```

### Running Tests

```bash
# Run all tests
flutter test

# Run a specific test file
flutter test test/widget_test.dart

# Run tests with verbose output
flutter test --verbose
```

### Code Analysis and Formatting

```bash
# Analyze for lint warnings and errors
flutter analyze

# Auto-format all Dart files
dart format lib/

# Check formatting without applying changes
dart format lib/ --output=none --set-exit-if-changed
```

### Clean Build

When dependency or generated file issues arise, perform a clean build:

```bash
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### Database Migrations

The database schema version is defined in `lib/core/database/database.dart` in the `AppDatabase` class. When adding a new column or table:

1. Increment `schemaVersion` by 1.
2. Add a `MigrationStep` in the `migration` getter's `onUpgrade` callback that issues the appropriate `ALTER TABLE` or `CREATE TABLE` statement.
3. Run code generation to update `database.g.dart`.

Avoid destructive migrations. All existing schema changes have been additive (new columns with defaults, new tables).

---

## Contributing

1. Fork the repository and create a feature branch from `main`.

   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes. Run code generation if you modified database tables or Riverpod providers.

3. Ensure the code passes analysis and is formatted correctly.

   ```bash
   flutter analyze
   dart format lib/
   ```

4. Run the test suite.

   ```bash
   flutter test
   ```

5. Commit your changes with a clear, descriptive message.

6. Open a pull request against the `main` branch with a description of what was changed and why.
