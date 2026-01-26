import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/formatters.dart';

/// Monthly statistics for the dashboard
class MonthlyStats {
  final double totalIncome;
  final double totalExpenses;
  final double balance;
  final double dailyBurnRate;
  final int daysRemaining;
  final double projectedBalance;
  final ForecastStatus forecastStatus;
  final Map<String, double> categoryBreakdown;
  final double goalAllocations; // Amount allocated to savings goals

  MonthlyStats({
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

  factory MonthlyStats.empty() => MonthlyStats(
    totalIncome: 0,
    totalExpenses: 0,
    balance: 0,
    dailyBurnRate: 0,
    daysRemaining: Formatters.daysRemainingInMonth(),
    projectedBalance: 0,
    forecastStatus: ForecastStatus.safe,
    categoryBreakdown: {},
    goalAllocations: 0,
  );
}

/// Provider for monthly statistics
final monthlyStatsProvider = FutureProvider<MonthlyStats>((ref) async {
  final db = ref.watch(databaseProvider);
  final settings = await db.select(db.userSettings).getSingleOrNull();
  final monthlyIncome = settings?.monthlyIncome ?? 0;

  // Get current month's date range
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

  // Query transactions for this month
  final transactions = await (db.select(
    db.transactions,
  )..where((t) => t.timestamp.isBetweenValues(startOfMonth, endOfMonth))).get();

  // Calculate totals
  double totalIncome = monthlyIncome;
  double totalExpenses = 0;
  double goalAllocatedAmount = 0;
  Map<int, double> categoryTotals = {};

  for (final tx in transactions) {
    if (tx.type == 'income') {
      totalIncome += tx.amount;
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
  final daysElapsed = Formatters.daysElapsedInMonth();
  final daysRemaining = Formatters.daysRemainingInMonth();
  final dailyBurnRate = daysElapsed > 0 ? totalExpenses / daysElapsed : 0;

  // Forecast: Average Daily Spend × Remaining Days
  final projectedAdditionalSpend = dailyBurnRate * daysRemaining;
  final projectedBalance = balance - projectedAdditionalSpend;

  // Determine forecast status
  ForecastStatus forecastStatus;
  if (projectedBalance > monthlyIncome * AppConstants.safeBalanceThreshold) {
    forecastStatus = ForecastStatus.safe;
  } else if (projectedBalance > AppConstants.cautionBalanceThreshold) {
    forecastStatus = ForecastStatus.caution;
  } else {
    forecastStatus = ForecastStatus.deficit;
  }

  return MonthlyStats(
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

/// Provider for recent transactions (last 5)
final recentTransactionsProvider =
    StreamProvider<List<TransactionWithCategory>>((ref) {
      final db = ref.watch(databaseProvider);

      final query =
          db.select(db.transactions).join([
              leftOuterJoin(
                db.categories,
                db.categories.id.equalsExp(db.transactions.categoryId),
              ),
            ])
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

/// Provider for all transactions (no limit)
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
