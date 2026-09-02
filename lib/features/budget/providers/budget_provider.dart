import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/utils/formatters.dart';

/// Budget statistics for a category
class CategoryBudgetStats {
  final int id;
  final String name;
  final String icon;
  final double budget;
  final double spent;
  final double remaining;
  final double percentUsed;

  CategoryBudgetStats({
    required this.id,
    required this.name,
    required this.icon,
    required this.budget,
    required this.spent,
  }) : remaining = budget - spent,
       percentUsed = budget > 0 ? (spent / budget * 100).clamp(0, 200) : 0;

  bool get isOverBudget => spent > budget;
  bool get isNearLimit => percentUsed >= 80 && !isOverBudget;
}

/// Overall budget statistics
class BudgetStats {
  final double totalBudget;
  final double totalSpent;
  final double totalRemaining;
  final double dailyAllowance;
  final int daysRemaining;
  final List<CategoryBudgetStats> categoryStats;
  final String periodLabel; // Added to show which period is being displayed

  BudgetStats({
    required this.totalBudget,
    required this.totalSpent,
    required this.daysRemaining,
    required this.categoryStats,
    this.periodLabel = 'This Month',
  }) : totalRemaining = totalBudget - totalSpent,
       dailyAllowance = daysRemaining > 0
           ? (totalBudget - totalSpent) / daysRemaining
           : 0;

  double get percentUsed =>
      totalBudget > 0 ? (totalSpent / totalBudget * 100).clamp(0, 200) : 0;
  bool get isOverBudget => totalSpent > totalBudget;
}

/// Provider for selected budget month
final budgetSelectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

/// Provider for budget statistics - respects selected budget month
final budgetStatsProvider = FutureProvider<BudgetStats>((ref) async {
  final db = ref.watch(databaseProvider);
  final selectedMonth = ref.watch(budgetSelectedMonthProvider);
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

  // Get categories with positive monthly budgets
  final categoriesQuery = db.select(db.categories)
    ..where((c) => c.monthlyBudget.isBiggerThanValue(0));
  final categories = await categoriesQuery.get();

  // Get all expenses for current month (exclude goal-linked) filtered in SQL
  final transactionsQuery = db.select(db.transactions)
    ..where(
      (t) =>
          t.timestamp.isBetweenValues(monthStart, monthEnd) &
          t.type.equals('expense') &
          t.goalId.isNull(),
    );
  final transactions = await transactionsQuery.get();

  // Calculate spending per category
  final Map<int, double> categorySpending = {};
  for (final tx in transactions) {
    categorySpending[tx.categoryId] =
        (categorySpending[tx.categoryId] ?? 0) + tx.amount;
  }

  // Build category stats for categories with budgets
  final List<CategoryBudgetStats> categoryStats = [];
  double totalBudget = 0;
  double totalSpent = 0;

  for (final category in categories) {
    if (category.monthlyBudget != null && category.monthlyBudget! > 0) {
      final spent = categorySpending[category.id] ?? 0;
      categoryStats.add(
        CategoryBudgetStats(
          id: category.id,
          name: category.name,
          icon: category.icon,
          budget: category.monthlyBudget!,
          spent: spent,
        ),
      );
      totalBudget += category.monthlyBudget!;
      totalSpent += spent;
    }
  }

  // Sort by percent used (highest first)
  categoryStats.sort((a, b) => b.percentUsed.compareTo(a.percentUsed));

  return BudgetStats(
    totalBudget: totalBudget,
    totalSpent: totalSpent,
    daysRemaining: daysRemaining,
    categoryStats: categoryStats,
    periodLabel: periodLabel,
  );
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
