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

  BudgetStats({
    required this.totalBudget,
    required this.totalSpent,
    required this.daysRemaining,
    required this.categoryStats,
  }) : totalRemaining = totalBudget - totalSpent,
       dailyAllowance = daysRemaining > 0
           ? (totalBudget - totalSpent) / daysRemaining
           : 0;

  double get percentUsed =>
      totalBudget > 0 ? (totalSpent / totalBudget * 100).clamp(0, 200) : 0;
  bool get isOverBudget => totalSpent > totalBudget;
}

/// Provider for budget statistics
final budgetStatsProvider = FutureProvider<BudgetStats>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();

  // Get current month range
  final monthStart = DateTime(now.year, now.month, 1);
  final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

  // Get all categories with budgets
  final categories = await db.select(db.categories).get();

  // Get all expenses for current month (exclude goal-linked)
  final allTransactions = await db.select(db.transactions).get();

  final transactions = allTransactions
      .where(
        (t) =>
            t.timestamp.isAfter(
              monthStart.subtract(const Duration(seconds: 1)),
            ) &&
            t.timestamp.isBefore(monthEnd.add(const Duration(seconds: 1))) &&
            t.type == 'expense' &&
            t.goalId == null,
      )
      .toList();

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
    daysRemaining: Formatters.daysRemainingInMonth(),
    categoryStats: categoryStats,
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
