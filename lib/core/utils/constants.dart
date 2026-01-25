/// App-wide constants
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Money Manager';
  static const String appVersion = '1.0.0';

  // Currency
  static const String defaultCurrency = 'INR';
  static const String currencySymbol = '₹';

  // Thresholds for insights
  static const double spendingSpikeFactor = 2.0; // 2x daily average
  static const double categoryDominanceThreshold = 0.4; // 40% of total
  static const double budgetWarningThreshold = 0.8; // 80% of budget

  // Forecast status thresholds
  static const double safeBalanceThreshold = 0.2; // 20% of income remaining
  static const double cautionBalanceThreshold = 0.0; // 0% remaining

  // Notifications
  static const int maxNotificationsPerDay = 1;

  // Performance targets
  static const int coldStartTargetMs = 2000;
  static const int expenseEntryTargetMs = 5000;
  static const int insightGenerationTargetMs = 200;
}

/// Transaction types
enum TransactionType {
  income,
  expense;

  bool get isIncome => this == TransactionType.income;
  bool get isExpense => this == TransactionType.expense;
}

/// Forecast status for month-end projection
enum ForecastStatus {
  safe,
  caution,
  deficit;

  String get label {
    switch (this) {
      case ForecastStatus.safe:
        return 'On Track';
      case ForecastStatus.caution:
        return 'Borderline';
      case ForecastStatus.deficit:
        return 'At Risk';
    }
  }
}
