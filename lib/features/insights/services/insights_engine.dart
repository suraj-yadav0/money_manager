import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/formatters.dart';

/// Types of insights
enum InsightType {
  spendingSpike,
  budgetOverrun,
  categoryDominance,
  monthOverMonth,
  weekendSpending,
  goalProgress,
  forecastWarning,
}

/// Severity of insight
enum InsightSeverity { info, warning, critical }

/// Individual insight
class Insight {
  final InsightType type;
  final InsightSeverity severity;
  final String title;
  final String description;
  final String? actionText;
  final String? tip;
  final DateTime generatedAt;

  Insight({
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    this.actionText,
    this.tip,
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.now();
}

/// Insights Engine - generates rule-based insights
class InsightsEngine {
  final AppDatabase db;

  InsightsEngine(this.db);

  /// Generate all insights for today
  Future<List<Insight>> generateDailyInsights() async {
    final insights = <Insight>[];

    // Get current month transactions
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    // Get all transactions and filter for current month
    final allTransactions = await db.select(db.transactions).get();
    final transactions = allTransactions
        .where(
          (t) =>
              t.timestamp.isAfter(startOfMonth) ||
              t.timestamp.isAtSameMomentAs(startOfMonth),
        )
        .toList();

    if (transactions.isEmpty) return insights;

    // Get user settings
    final settings = await db.select(db.userSettings).getSingleOrNull();
    final monthlyIncome = settings?.monthlyIncome ?? 0;

    // Get categories
    final categories = await db.select(db.categories).get();
    final categoryMap = {for (var c in categories) c.id: c};

    // Calculate metrics
    final expenses = transactions.where((t) => t.type == 'expense').toList();
    final totalExpenses = expenses.fold<double>(0, (sum, t) => sum + t.amount);

    // 1. Spending Spike Detection
    final spikeInsight = _checkSpendingSpike(expenses);
    if (spikeInsight != null) insights.add(spikeInsight);

    // 2. Category Dominance
    final dominanceInsight = _checkCategoryDominance(
      expenses,
      categoryMap,
      totalExpenses,
    );
    if (dominanceInsight != null) insights.add(dominanceInsight);

    // 3. Budget Progress
    final budgetInsight = _checkBudgetProgress(totalExpenses, monthlyIncome);
    if (budgetInsight != null) insights.add(budgetInsight);

    // 4. Weekend Spending Pattern
    final weekendInsight = _checkWeekendSpending(expenses);
    if (weekendInsight != null) insights.add(weekendInsight);

    // 5. Forecast Warning
    final forecastInsight = await _checkForecast(totalExpenses, monthlyIncome);
    if (forecastInsight != null) insights.add(forecastInsight);

    return insights;
  }

  /// Check if today's spending is a spike
  Insight? _checkSpendingSpike(List<Transaction> expenses) {
    if (expenses.isEmpty) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todayExpenses = expenses.where((t) {
      final txDate = DateTime(
        t.timestamp.year,
        t.timestamp.month,
        t.timestamp.day,
      );
      return txDate == today;
    }).toList();

    if (todayExpenses.isEmpty) return null;

    final todayTotal = todayExpenses.fold<double>(
      0,
      (sum, t) => sum + t.amount,
    );

    // Calculate daily average (excluding today)
    final otherExpenses = expenses.where((t) {
      final txDate = DateTime(
        t.timestamp.year,
        t.timestamp.month,
        t.timestamp.day,
      );
      return txDate != today;
    }).toList();

    if (otherExpenses.isEmpty) return null;

    final daysWithExpenses = otherExpenses
        .map(
          (t) => DateTime(t.timestamp.year, t.timestamp.month, t.timestamp.day),
        )
        .toSet()
        .length;

    if (daysWithExpenses == 0) return null;

    final otherTotal = otherExpenses.fold<double>(
      0,
      (sum, t) => sum + t.amount,
    );
    final dailyAverage = otherTotal / daysWithExpenses;

    if (todayTotal > dailyAverage * AppConstants.spendingSpikeFactor) {
      return Insight(
        type: InsightType.spendingSpike,
        severity: InsightSeverity.warning,
        title: 'Spending Spike Detected',
        description:
            "which is ${(todayTotal / dailyAverage).toStringAsFixed(1)}x your daily average.",
        actionText: 'View details',
        tip: 'Try a "no-spend day" tomorrow to balance this out.',
      );
    }

    return null;
  }

  /// Check if one category dominates spending
  Insight? _checkCategoryDominance(
    List<Transaction> expenses,
    Map<int, Category> categoryMap,
    double totalExpenses,
  ) {
    if (expenses.isEmpty || totalExpenses == 0) return null;

    // Group by category
    final categoryTotals = <int, double>{};
    for (final tx in expenses) {
      categoryTotals[tx.categoryId] =
          (categoryTotals[tx.categoryId] ?? 0) + tx.amount;
    }

    // Find dominant category
    for (final entry in categoryTotals.entries) {
      final ratio = entry.value / totalExpenses;
      if (ratio > AppConstants.categoryDominanceThreshold) {
        final category = categoryMap[entry.key];
        return Insight(
          type: InsightType.categoryDominance,
          severity: InsightSeverity.info,
          title: '${category?.name ?? "Category"} Leads Spending',
          description:
              '${(ratio * 100).toStringAsFixed(0)}% of your expenses '
              '(${Formatters.currency(entry.value)}) went to ${category?.name ?? "this category"}.',
          actionText: 'View details',
          tip:
              'Check if there are cheaper alternatives for your major expenses in ${category?.name ?? "this category"}.',
        );
      }
    }

    return null;
  }

  /// Check budget progress
  Insight? _checkBudgetProgress(double totalExpenses, double monthlyIncome) {
    if (monthlyIncome == 0) return null;

    final ratio = totalExpenses / monthlyIncome;
    final daysElapsed = Formatters.daysElapsedInMonth();
    final totalDays = Formatters.daysInCurrentMonth();
    final expectedRatio = daysElapsed / totalDays;

    if (ratio > expectedRatio + 0.15) {
      return Insight(
        type: InsightType.budgetOverrun,
        severity: InsightSeverity.warning,
        title: 'Spending Ahead of Schedule',
        description:
            "You've spent ${Formatters.percentage(ratio)} of your income "
            "with ${Formatters.percentage(1 - expectedRatio)} of the month remaining.",
        actionText: 'Review expenses',
        tip: 'Consider pausing non-essential subscriptions until next month.',
      );
    }

    return null;
  }

  /// Check weekend spending pattern
  Insight? _checkWeekendSpending(List<Transaction> expenses) {
    if (expenses.length < 7) return null;

    double weekendTotal = 0;
    double weekdayTotal = 0;
    int weekendDays = 0;
    int weekdayDays = 0;

    final daysSeen = <String>{};

    for (final tx in expenses) {
      final isWeekend = tx.timestamp.weekday == 6 || tx.timestamp.weekday == 7;
      final dayKey =
          '${tx.timestamp.year}-${tx.timestamp.month}-${tx.timestamp.day}';

      if (isWeekend) {
        weekendTotal += tx.amount;
        if (!daysSeen.contains('w$dayKey')) {
          weekendDays++;
          daysSeen.add('w$dayKey');
        }
      } else {
        weekdayTotal += tx.amount;
        if (!daysSeen.contains('d$dayKey')) {
          weekdayDays++;
          daysSeen.add('d$dayKey');
        }
      }
    }

    if (weekendDays == 0 || weekdayDays == 0) return null;

    final weekendAvg = weekendTotal / weekendDays;
    final weekdayAvg = weekdayTotal / weekdayDays;

    if (weekendAvg > weekdayAvg * 1.8) {
      return Insight(
        type: InsightType.weekendSpending,
        severity: InsightSeverity.info,
        title: 'Weekend Spending Pattern',
        description:
            'You spend ${(weekendAvg / weekdayAvg).toStringAsFixed(1)}x more '
            'on weekends (${Formatters.currency(weekendAvg)}/day) than weekdays.',
        actionText: 'View details',
        tip:
            'Planning weekend activities in advance can help avoid impulse spending.',
      );
    }

    return null;
  }

  /// Check forecast for warnings
  Future<Insight?> _checkForecast(
    double totalExpenses,
    double monthlyIncome,
  ) async {
    if (monthlyIncome == 0) return null;

    final daysElapsed = Formatters.daysElapsedInMonth();
    final daysRemaining = Formatters.daysRemainingInMonth();

    if (daysElapsed == 0) return null;

    final dailyBurn = totalExpenses / daysElapsed;
    final projectedTotal = totalExpenses + (dailyBurn * daysRemaining);
    final projectedBalance = monthlyIncome - projectedTotal;

    if (projectedBalance < 0) {
      return Insight(
        type: InsightType.forecastWarning,
        severity: InsightSeverity.critical,
        title: 'Deficit Warning',
        description:
            'At this rate, you\'ll overspend by ${Formatters.currency(-projectedBalance)} this month.',
        actionText: 'Reduce spending',
        tip:
            'Look for one variable expense you can cut this week (e.g., dining out).',
      );
    } else if (projectedBalance < monthlyIncome * 0.1) {
      return Insight(
        type: InsightType.forecastWarning,
        severity: InsightSeverity.warning,
        title: 'Tight Month Ahead',
        description:
            'You\'ll have only ${Formatters.currency(projectedBalance)} left at month-end.',
        actionText: 'View forecast',
        tip:
            'Try to limit daily spending to ${Formatters.currency(projectedBalance / daysRemaining)} for the rest of the month.',
      );
    }

    return null;
  }
}

/// Provider for insights engine
final insightsEngineProvider = Provider<InsightsEngine>((ref) {
  final db = ref.watch(databaseProvider);
  return InsightsEngine(db);
});

/// Provider for current insights
final insightsProvider = FutureProvider<List<Insight>>((ref) async {
  final engine = ref.watch(insightsEngineProvider);
  return engine.generateDailyInsights();
});
