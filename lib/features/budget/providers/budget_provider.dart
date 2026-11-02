import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/utils/formatters.dart';
import '../../dashboard/providers/dashboard_providers.dart';

/// Budget statistics for a category
class CategoryBudgetStats {
  final int id;
  final String name;
  final String icon;
  final double budget;
  final double baseBudget;
  final double rollover;
  final double spent;
  final double remaining;
  final double percentUsed;

  CategoryBudgetStats({
    required this.id,
    required this.name,
    required this.icon,
    required this.budget,
    double? baseBudget,
    this.rollover = 0.0,
    required this.spent,
  }) : baseBudget = baseBudget ?? budget,
       remaining = budget - spent,
       percentUsed = budget > 0 ? (spent / budget * 100).clamp(0, 200) : (spent > 0 ? 100 : 0);

  bool get isOverBudget => spent > budget;
  bool get isNearLimit => percentUsed >= 80 && !isOverBudget;
}

/// Overall budget statistics
class BudgetStats {
  final double totalBudget;
  final double totalBaseBudget;
  final double totalRollover;
  final double totalSpent;
  final double totalRemaining;
  final double dailyAllowance;
  final int daysRemaining;
  final List<CategoryBudgetStats> categoryStats;
  final String periodLabel; // Added to show which period is being displayed

  BudgetStats({
    required this.totalBudget,
    double? totalBaseBudget,
    this.totalRollover = 0.0,
    required this.totalSpent,
    required this.daysRemaining,
    required this.categoryStats,
    this.periodLabel = 'This Month',
  }) : totalBaseBudget = totalBaseBudget ?? totalBudget,
       totalRemaining = totalBudget - totalSpent,
       dailyAllowance = daysRemaining > 0
           ? (totalBudget - totalSpent) / daysRemaining
           : 0;

  double get percentUsed =>
      totalBudget > 0 ? (totalSpent / totalBudget * 100).clamp(0, 200) : (totalSpent > 0 ? 100 : 0);
  bool get isOverBudget => totalSpent > totalBudget;
}

/// Provider for selected budget month
final budgetSelectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

/// Provider for budget statistics - respects selected budget month and reacts live to database changes
final budgetStatsProvider = StreamProvider<BudgetStats>((ref) async* {
  final db = ref.watch(databaseProvider);
  final selectedMonth = ref.watch(budgetSelectedMonthProvider);
  ref.watch(categoriesProvider); // Re-run when category budgets change

  final settings = await db.select(db.userSettings).getSingleOrNull();
  final carryForwardEnabled = settings?.carryForwardEnabled ?? true;

  final now = DateTime.now();
  final monthStart = DateTime(selectedMonth.year, selectedMonth.month, 1);
  final lastDay = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
  final monthEnd = DateTime(
    lastDay.year,
    lastDay.month,
    lastDay.day,
    23,
    59,
    59,
    999,
  );

  final isCurrentMonth = selectedMonth.year == now.year && selectedMonth.month == now.month;
  final isPastMonth = selectedMonth.isBefore(DateTime(now.year, now.month, 1));
  final int daysRemaining;
  final String periodLabel;

  if (isCurrentMonth) {
    daysRemaining = Formatters.daysRemainingInMonth();
    periodLabel = 'This Month';
  } else if (isPastMonth) {
    daysRemaining = 0;
    periodLabel = Formatters.month(selectedMonth);
  } else {
    daysRemaining = lastDay.day;
    periodLabel = Formatters.month(selectedMonth);
  }

  // Watch all expenses up to the end of the selected month
  final transactionsQuery = db.select(db.transactions)
    ..where(
      (t) =>
          t.timestamp.isSmallerOrEqualValue(monthEnd) &
          t.type.equals('expense') &
          t.goalId.isNull(),
    );

  await for (final transactions in transactionsQuery.watch()) {
    // Get categories with positive monthly budgets
    final categoriesQuery = db.select(db.categories)
      ..where((c) => c.monthlyBudget.isBiggerThanValue(0));
    final categories = await categoriesQuery.get();

    // Separate selected month transactions and historical prior transactions
    final Map<int, double> categorySpending = {};
    final Map<int, Map<String, double>> historicalSpending = {};
    DateTime earliestDate = selectedMonth;

    for (final tx in transactions) {
      if (tx.timestamp.isBefore(monthStart)) {
        if (tx.timestamp.isBefore(earliestDate)) {
          earliestDate = tx.timestamp;
        }
        final key = '${tx.timestamp.year}-${tx.timestamp.month.toString().padLeft(2, '0')}';
        final catMap = historicalSpending.putIfAbsent(tx.categoryId, () => {});
        catMap[key] = (catMap[key] ?? 0) + tx.amount;
      } else if (!tx.timestamp.isAfter(monthEnd)) {
        categorySpending[tx.categoryId] =
            (categorySpending[tx.categoryId] ?? 0) + tx.amount;
      }
    }

    final maxLookback = DateTime(selectedMonth.year, selectedMonth.month - 24, 1);
    final categoryStartMonth = earliestDate.isBefore(maxLookback) ? maxLookback : DateTime(earliestDate.year, earliestDate.month, 1);

    // Build category stats for categories with budgets
    final List<CategoryBudgetStats> categoryStats = [];
    double totalBaseBudget = 0;
    double totalRollover = 0;
    double totalBudget = 0;
    double totalSpent = 0;

    for (final category in categories) {
      if (category.monthlyBudget != null && category.monthlyBudget! > 0) {
        final baseBudget = category.monthlyBudget!;
        final spent = categorySpending[category.id] ?? 0;
        double rollover = 0.0;

        if (carryForwardEnabled && historicalSpending.containsKey(category.id)) {
          final catSpendMap = historicalSpending[category.id]!;
          final sortedMonths = catSpendMap.keys.toList()..sort();
          if (sortedMonths.isNotEmpty) {
            final firstMonthParts = sortedMonths.first.split('-');
            final firstMonthDate = DateTime(
              int.parse(firstMonthParts[0]),
              int.parse(firstMonthParts[1]),
              1,
            );
            DateTime cur = firstMonthDate.isAfter(categoryStartMonth)
                ? firstMonthDate
                : categoryStartMonth;

            while (cur.isBefore(monthStart)) {
              final key = '${cur.year}-${cur.month.toString().padLeft(2, '0')}';
              final spentInMonth = catSpendMap[key] ?? 0.0;
              rollover = (baseBudget + rollover) - spentInMonth;
              cur = DateTime(cur.year, cur.month + 1, 1);
            }
          }
        }

        final effectiveBudget = baseBudget + rollover;

        categoryStats.add(
          CategoryBudgetStats(
            id: category.id,
            name: category.name,
            icon: category.icon,
            budget: effectiveBudget,
            baseBudget: baseBudget,
            rollover: rollover,
            spent: spent,
          ),
        );
        totalBaseBudget += baseBudget;
        totalRollover += rollover;
        totalBudget += effectiveBudget;
        totalSpent += spent;
      }
    }

    // Sort by percent used (highest first)
    categoryStats.sort((a, b) => b.percentUsed.compareTo(a.percentUsed));

    yield BudgetStats(
      totalBudget: totalBudget,
      totalBaseBudget: totalBaseBudget,
      totalRollover: totalRollover,
      totalSpent: totalSpent,
      daysRemaining: daysRemaining,
      categoryStats: categoryStats,
      periodLabel: periodLabel,
    );
  }
});

/// Provider to update a category's budget
final updateCategoryBudgetProvider =
    Provider<Future<void> Function(int categoryId, double budget)>((ref) {
      final db = ref.watch(databaseProvider);

      return (int categoryId, double budget) async {
        await (db.update(db.categories)..where((c) => c.id.equals(categoryId)))
            .write(CategoriesCompanion(monthlyBudget: Value(budget)));
        ref.invalidate(budgetStatsProvider);
      };
    });

/// Provider to get average monthly spending per category (last 3 months)
/// Used to suggest budget amounts based on actual spending patterns
final categoryAvgSpendingProvider = FutureProvider<Map<int, double>>((
  ref,
) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();

  // Calculate date range for last 3 complete months
  final threeMonthsAgo = DateTime(now.year, now.month - 3, 1);
  final currentMonthStart = DateTime(now.year, now.month, 1);

  // Get all expenses from the last 3 complete months (excluding current month)
  final transactionsQuery = db.select(db.transactions)
    ..where(
      (t) =>
          t.timestamp.isBiggerOrEqualValue(threeMonthsAgo) &
          t.timestamp.isSmallerThanValue(currentMonthStart) &
          t.type.equals('expense') &
          t.goalId.isNull(),
    );
  final transactions = await transactionsQuery.get();

  // Calculate total spending per category
  final Map<int, double> totalSpending = {};
  for (final tx in transactions) {
    totalSpending[tx.categoryId] =
        (totalSpending[tx.categoryId] ?? 0) + tx.amount;
  }

  // Calculate number of complete months in range
  int monthsCount = 0;
  DateTime checkDate = threeMonthsAgo;
  while (checkDate.isBefore(currentMonthStart)) {
    monthsCount++;
    checkDate = DateTime(checkDate.year, checkDate.month + 1, 1);
  }

  // Avoid division by zero
  if (monthsCount == 0) monthsCount = 1;

  // Calculate average per category and round to nearest 100
  final Map<int, double> avgSpending = {};
  for (final entry in totalSpending.entries) {
    final avg = entry.value / monthsCount;
    // Round to nearest 100 for cleaner suggestions
    avgSpending[entry.key] = (avg / 100).round() * 100;
  }

  return avgSpending;
});
