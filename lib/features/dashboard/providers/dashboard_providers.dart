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
  final today = DateTime(now.year, now.month, now.day);

  switch (filter) {
    case DashboardDateFilter.thisWeek:
      // ISO 8601: Week starts on Monday (weekday = 1)
      // Calculate days since Monday: Mon=0, Tue=1, ..., Sun=6
      final daysSinceMonday = now.weekday - 1;
      final start = DateTime(
        today.year,
        today.month,
        today.day - daysSinceMonday,
      );
      // End of week is Sunday at 23:59:59.999
      final endDate = start.add(const Duration(days: 6));
      final end = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        23,
        59,
        59,
        999,
      );
      return (start: start, end: end);

    case DashboardDateFilter.lastWeek:
      final daysSinceMonday = now.weekday - 1;
      final thisWeekStart = DateTime(
        today.year,
        today.month,
        today.day - daysSinceMonday,
      );
      final start = thisWeekStart.subtract(const Duration(days: 7));
      final endDate = start.add(const Duration(days: 6));
      final end = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        23,
        59,
        59,
        999,
      );
      return (start: start, end: end);

    case DashboardDateFilter.thisMonth:
      final start = DateTime(now.year, now.month, 1);
      // Day 0 of next month = last day of current month
      final lastDay = DateTime(now.year, now.month + 1, 0);
      final end = DateTime(
        lastDay.year,
        lastDay.month,
        lastDay.day,
        23,
        59,
        59,
        999,
      );
      return (start: start, end: end);

    case DashboardDateFilter.lastMonth:
      final start = DateTime(now.year, now.month - 1, 1);
      // Day 0 of current month = last day of previous month
      final lastDay = DateTime(now.year, now.month, 0);
      final end = DateTime(
        lastDay.year,
        lastDay.month,
        lastDay.day,
        23,
        59,
        59,
        999,
      );
      return (start: start, end: end);

    case DashboardDateFilter.thisYear:
      final start = DateTime(now.year, 1, 1);
      final end = DateTime(now.year, 12, 31, 23, 59, 59, 999);
      return (start: start, end: end);

    case DashboardDateFilter.allTime:
      return (
        start: DateTime(2000),
        end: DateTime(2100, 12, 31, 23, 59, 59, 999),
      );
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
  final Map<String, double> incomeCategoryBreakdown;
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
    required this.incomeCategoryBreakdown,
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
    incomeCategoryBreakdown: {},
    goalAllocations: 0,
  );
}

/// Provider for dashboard statistics based on selected filter
final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final db = ref.watch(databaseProvider);
  final range = ref.watch(dateRangeProvider);
  final filter = ref.read(dashboardDateFilterProvider);

  // Get settings for forecast calculations (monthlyIncome used for projections reference)
  final settings = await db.select(db.userSettings).getSingleOrNull();
  final monthlyIncome = settings?.monthlyIncome ?? 0;

  // Query transactions for range
  final transactions = await (db.select(
    db.transactions,
  )..where((t) => t.timestamp.isBetweenValues(range.start, range.end))).get();

  // Calculate totals from actual transactions only
  double totalIncome = 0;
  double totalExpenses = 0;
  double goalAllocatedAmount = 0;
  Map<int, double> expenseCategoryTotals = {};
  Map<int, double> incomeCategoryTotals = {};

  for (final tx in transactions) {
    if (tx.type == 'income') {
      totalIncome += tx.amount;
      incomeCategoryTotals[tx.categoryId] =
          (incomeCategoryTotals[tx.categoryId] ?? 0) + tx.amount;
    } else {
      totalExpenses += tx.amount;
      // Track goal allocations separately - don't add to category breakdown
      if (tx.goalId != null) {
        goalAllocatedAmount += tx.amount;
      } else {
        // Only add non-goal expenses to category breakdown
        expenseCategoryTotals[tx.categoryId] =
            (expenseCategoryTotals[tx.categoryId] ?? 0) + tx.amount;
      }
    }
  }

  // Get category names
  final categories = await db.select(db.categories).get();
  final categoryMap = {for (var c in categories) c.id: c.name};

  Map<String, double> categoryBreakdown = {};
  for (final entry in expenseCategoryTotals.entries) {
    final name = categoryMap[entry.key] ?? 'Other';
    categoryBreakdown[name] = entry.value;
  }

  Map<String, double> incomeCategoryBreakdown = {};
  for (final entry in incomeCategoryTotals.entries) {
    final name = categoryMap[entry.key] ?? 'Other';
    incomeCategoryBreakdown[name] = entry.value;
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
    incomeCategoryBreakdown: incomeCategoryBreakdown,
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

/// Stream provider for user settings
final userSettingsStreamProvider = StreamProvider<UserSetting?>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.userSettings).watchSingleOrNull();
});

/// Provider for selected transaction type in dashboard charts (expense/income)
final dashboardTransactionTypeProvider = StateProvider<String>(
  (ref) => 'expense',
);

/// Parameters for the chart drill-down provider
class DrillDownParams {
  /// Category name filter (null means match all categories)
  final String? categoryName;

  /// Specific date filter (null means match all dates in range)
  final DateTime? date;

  /// Date range start
  final DateTime start;

  /// Date range end
  final DateTime end;

  /// Transaction type: 'expense' or 'income'
  final String transactionType;

  const DrillDownParams({
    this.categoryName,
    this.date,
    required this.start,
    required this.end,
    required this.transactionType,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DrillDownParams &&
          categoryName == other.categoryName &&
          date == other.date &&
          start == other.start &&
          end == other.end &&
          transactionType == other.transactionType;

  @override
  int get hashCode => Object.hash(categoryName, date, start, end, transactionType);
}

/// Provider that fetches detailed transactions for chart drill-down.
/// Supports filtering by category name OR by a specific date within a range.
final drillDownTransactionsProvider =
    FutureProvider.family<List<TransactionWithCategory>, DrillDownParams>((
      ref,
      params,
    ) async {
      final db = ref.read(databaseProvider);

      DateTime rangeStart = params.start;
      DateTime rangeEnd = params.end;

      // If a specific date is provided, narrow the range to that single day
      if (params.date != null) {
        final d = params.date!;
        rangeStart = DateTime(d.year, d.month, d.day);
        rangeEnd = DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
      }

      final query =
          db.select(db.transactions).join([
              leftOuterJoin(
                db.categories,
                db.categories.id.equalsExp(db.transactions.categoryId),
              ),
            ])
            ..where(
              db.transactions.type.equals(params.transactionType) &
                  db.transactions.timestamp.isBetweenValues(
                    rangeStart,
                    rangeEnd,
                  ),
            )
            ..orderBy([OrderingTerm.desc(db.transactions.timestamp)]);

      final rows = await query.get();

      final results = rows.map((row) {
        return TransactionWithCategory(
          transaction: row.readTable(db.transactions),
          category: row.readTableOrNull(db.categories),
        );
      }).toList();

      // If a category name filter is provided, keep only matching rows.
      // The '🎯 Savings Goals' pseudo-category is matched via goalId != null.
      if (params.categoryName != null) {
        if (params.categoryName == '🎯 Savings Goals') {
          return results
              .where((t) => t.transaction.goalId != null)
              .toList();
        }
        return results
            .where((t) => t.category?.name == params.categoryName)
            .toList();
      }

      return results;
    });
