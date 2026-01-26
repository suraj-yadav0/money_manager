import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/formatters.dart';

/// Available date filters for the dashboard
enum DashboardDateFilter {
  thisWeek,
  lastWeek,
  thisMonth,
  lastMonth,
  thisYear,
  allTime,
}

extension DashboardDateFilterExtension on DashboardDateFilter {
  String get label {
    switch (this) {
      case DashboardDateFilter.thisWeek:
        return 'This Week';
      case DashboardDateFilter.lastWeek:
        return 'Last Week';
      case DashboardDateFilter.thisMonth:
        return 'This Month';
      case DashboardDateFilter.lastMonth:
        return 'Last Month';
      case DashboardDateFilter.thisYear:
        return 'This Year';
      case DashboardDateFilter.allTime:
        return 'All Time';
    }
  }
}

/// Provider for the currently selected date filter
final dashboardDateFilterProvider = StateProvider<DashboardDateFilter>((ref) {
  return DashboardDateFilter.thisMonth;
});

/// Provider for the calculated date range based on the filter
final dateRangeProvider = Provider<({DateTime start, DateTime end})>((ref) {
  final filter = ref.watch(dashboardDateFilterProvider);
  final now = DateTime.now();

  switch (filter) {
    case DashboardDateFilter.thisWeek:
      // Find the most recent Sunday (or today if today is Sunday, depending on preference.
      // Usually "This Week" starts on Monday or Sunday. Let's assume Monday as start of week for business logic often,
      // but Formatters usually handle locales. Let's do standard Monday start.)
      // Actually standard ISO 8601 is Monday.
      final difference = now.weekday - 1; // Mon=1, Sun=7 -> Mon=0, Sun=6
      final start = DateTime(now.year, now.month, now.day - difference);
      final end = DateTime(
        now.year,
        now.month,
        now.day + (7 - 1 - difference),
        23,
        59,
        59,
      );
      return (start: start, end: end);

    case DashboardDateFilter.lastWeek:
      final difference = now.weekday - 1;
      final startCurrent = DateTime(now.year, now.month, now.day - difference);
      final start = startCurrent.subtract(const Duration(days: 7));
      final end = start.add(
        const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
      );
      return (start: start, end: end);

    case DashboardDateFilter.thisMonth:
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      return (start: start, end: end);

    case DashboardDateFilter.lastMonth:
      final start = DateTime(now.year, now.month - 1, 1);
      final end = DateTime(now.year, now.month, 0, 23, 59, 59);
      return (start: start, end: end);

    case DashboardDateFilter.thisYear:
      final start = DateTime(now.year, 1, 1);
      final end = DateTime(now.year, 12, 31, 23, 59, 59);
      return (start: start, end: end);

    case DashboardDateFilter.allTime:
      return (
        start: DateTime(2000),
        end: DateTime(2100),
      ); // Arbitrary wide range
  }
});

/// Monthly statistics for the dashboard
class DashboardStats {
  final double totalIncome;
  final double totalExpenses;
  final double balance;
  final double dailyBurnRate;
  final int daysRemaining;
  final double projectedBalance;
  final ForecastStatus forecastStatus;
  final Map<String, double> categoryBreakdown;
  final double goalAllocations; // Amount allocated to savings goals

  DashboardStats({
    required this.totalIncome,
    required this.totalExpenses,
    required this.balance,
    required this.dailyBurnRate,
    required this.daysRemaining,
    required this.projectedBalance,
    required this.forecastStatus,
    required this.categoryBreakdown,
    this.goalAllocations = 0,
  });

  factory DashboardStats.empty() => DashboardStats(
    totalIncome: 0,
    totalExpenses: 0,
    balance: 0,
    dailyBurnRate: 0,
    daysRemaining: 0,
    projectedBalance: 0,
    forecastStatus: ForecastStatus.safe,
    categoryBreakdown: {},
    goalAllocations: 0,
  );
}

/// Provider for dashboard statistics based on selected filter
final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final db = ref.watch(databaseProvider);
  final range = ref.watch(dateRangeProvider);

  // Note: For "This Month" we still want to compare against monthly income setting.
  // For other views, "Projected Balance" might need interpretation or be hidden.
  // For now, we will calculate based on actuals in range.

  final settings = await db.select(db.userSettings).getSingleOrNull();
  // Monthly income is only relevant for month views roughly, but we can treat it as base for projections.
  final monthlyIncome = settings?.monthlyIncome ?? 0;

  // Query transactions for range
  final transactions = await (db.select(
    db.transactions,
  )..where((t) => t.timestamp.isBetweenValues(range.start, range.end))).get();

  // Calculate totals
  double totalRangeIncome = 0; // Income found in transactions
  double totalExpenses = 0;
  double goalAllocatedAmount = 0;
  Map<int, double> categoryTotals = {};

  for (final tx in transactions) {
    if (tx.type == 'income') {
      totalRangeIncome += tx.amount;
    } else {
      totalExpenses += tx.amount;
      categoryTotals[tx.categoryId] =
          (categoryTotals[tx.categoryId] ?? 0) + tx.amount;
      // Track goal allocations separately
      if (tx.goalId != null) {
        goalAllocatedAmount += tx.amount;
      }
    }
  }

  // Logic adjustment: If filter is "This Month", use settings income as base if no income transactions?
  // Original code: totalIncome = monthlyIncome + (income transactions?).
  // Wait, original code: totalIncome = monthlyIncome; for (tx) if income totalIncome += tx.amount;
  // This implies monthlyIncome is a static base + any extra income.
  // For other periods (Week, Year), adding "Monthly Income" doesn't make sense directly.
  // We should likely rely on ACTUAL income for non-month views, or prorate.
  // For simplicity and correctness in "This Month" view to match original behavior:
  double totalIncome = totalRangeIncome;
  final filter = ref.read(dashboardDateFilterProvider);
  if (filter == DashboardDateFilter.thisMonth) {
    totalIncome += monthlyIncome;
  }

  // Get category names
  final categories = await db.select(db.categories).get();
  final categoryMap = {for (var c in categories) c.id: c.name};

  Map<String, double> categoryBreakdown = {};
  for (final entry in categoryTotals.entries) {
    final name = categoryMap[entry.key] ?? 'Other';
    categoryBreakdown[name] = entry.value;
  }

  // Add goal allocations as a separate entry if any exist
  if (goalAllocatedAmount > 0) {
    categoryBreakdown['🎯 Savings Goals'] = goalAllocatedAmount;
  }

  // Calculate metrics
  final balance = totalIncome - totalExpenses;

  // Burn rate / Projection logic only makes strict sense for "This Month" in the original context.
  // For others, we can just zero them out or provide simple averages.

  double dailyBurnRate = 0;
  int daysRemaining = 0;
  double projectedBalance = 0;
  ForecastStatus forecastStatus = ForecastStatus.safe;

  if (filter == DashboardDateFilter.thisMonth) {
    final daysElapsed = Formatters.daysElapsedInMonth();
    daysRemaining = Formatters.daysRemainingInMonth();
    dailyBurnRate = daysElapsed > 0 ? totalExpenses / daysElapsed : 0;
    final projectedAdditionalSpend = dailyBurnRate * daysRemaining;
    projectedBalance = balance - projectedAdditionalSpend;

    if (projectedBalance > monthlyIncome * AppConstants.safeBalanceThreshold) {
      forecastStatus = ForecastStatus.safe;
    } else if (projectedBalance > AppConstants.cautionBalanceThreshold) {
      forecastStatus = ForecastStatus.caution;
    } else {
      forecastStatus = ForecastStatus.deficit;
    }
  } else {
    // For other views, projected isn't as relevant or requires complex logic.
    // Just use actuals.
    projectedBalance = balance;
  }

  return DashboardStats(
    totalIncome: totalIncome,
    totalExpenses: totalExpenses,
    balance: balance,
    dailyBurnRate: dailyBurnRate.toDouble(),
    daysRemaining: daysRemaining,
    projectedBalance: projectedBalance,
    forecastStatus: forecastStatus,
    categoryBreakdown: categoryBreakdown,
    goalAllocations: goalAllocatedAmount,
  );
});

// Deprecate old name to avoid immediate breaking, pointing to new one if possible,
// OR just replace usage. Since I'm editing the file, I'll remove the old class and provider
// and rely on refactoring the consumers.
// NOTE: I am replacing the file content, so the old one is gone. Consumers will break until fixed.

/// Provider for recent transactions (last 5) - now respects filter?
/// Typically "Recent" means recent in time globally context, OR recent in the selected view?
/// If I select "Last Year", "Recent Transactions" might show the last 5 of LAST YEAR.
/// Let's make it respect the filter.
final recentTransactionsProvider =
    StreamProvider<List<TransactionWithCategory>>((ref) {
      final db = ref.watch(databaseProvider);
      final range = ref.watch(dateRangeProvider); // Watch the range

      final query =
          db.select(db.transactions).join([
              leftOuterJoin(
                db.categories,
                db.categories.id.equalsExp(db.transactions.categoryId),
              ),
            ])
            ..where(
              db.transactions.timestamp.isBetweenValues(range.start, range.end),
            ) // Add filter
            ..orderBy([OrderingTerm.desc(db.transactions.timestamp)])
            ..limit(5);

      return query.watch().map((rows) {
        return rows.map((row) {
          return TransactionWithCategory(
            transaction: row.readTable(db.transactions),
            category: row.readTableOrNull(db.categories),
          );
        }).toList();
      });
    });

/// Provider for all transactions (no limit) - used in See All screen.
/// Should this respect the dashboard filter?
/// The "See All" screen usually expects ALL transactions.
/// However, if we are filtering the dashboard, maybe "See All" should show "See All in this period"?
/// The requirement says "create Filters... in Calendar View". The dashboard IS the view.
/// The list in "See All" shouldn't necessarily be bound to the dashboard filter unless we pass it.
/// For now, keeping allTransactionsProvider strictly "All" is safer for a generic "All Transactions" screen.
/// But the user might want to see the full list for the filtered period.
/// Let's keep `allTransactionsProvider` unrelated to dashboard filter for now to avoid side effects in other screens,
/// or create a filtered version if needed.
final allTransactionsProvider = StreamProvider<List<TransactionWithCategory>>((
  ref,
) {
  final db = ref.watch(databaseProvider);

  final query = db.select(db.transactions).join([
    leftOuterJoin(
      db.categories,
      db.categories.id.equalsExp(db.transactions.categoryId),
    ),
  ])..orderBy([OrderingTerm.desc(db.transactions.timestamp)]);

  return query.watch().map((rows) {
    return rows.map((row) {
      return TransactionWithCategory(
        transaction: row.readTable(db.transactions),
        category: row.readTableOrNull(db.categories),
      );
    }).toList();
  });
});

/// Transaction with its category
class TransactionWithCategory {
  final Transaction transaction;
  final Category? category;

  TransactionWithCategory({required this.transaction, this.category});
}

/// Provider for all categories
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.categories).watch();
});

/// Provider for expense categories only
final expenseCategoriesProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.categories,
  )..where((c) => c.type.equals('expense'))).watch();
});

/// Provider for income categories only
final incomeCategoriesProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.categories,
  )..where((c) => c.type.equals('income'))).watch();
});
