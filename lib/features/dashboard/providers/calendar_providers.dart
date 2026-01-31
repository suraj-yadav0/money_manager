import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_state_provider.dart';
import 'dashboard_providers.dart';

/// Currently focused month in the calendar view
final calendarFocusedDayProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

/// Currently selected day in the calendar (null if none selected)
final calendarSelectedDayProvider = StateProvider<DateTime?>((ref) {
  return DateTime.now();
});

/// Calendar format (month, 2 weeks, week)
enum CalendarViewFormat { month, twoWeeks, week }

final calendarFormatProvider = StateProvider<CalendarViewFormat>((ref) {
  return CalendarViewFormat.month;
});

/// Daily summary for calendar markers
class DailySummary {
  final DateTime date;
  final double totalExpenses;
  final double totalIncome;
  final int transactionCount;

  DailySummary({
    required this.date,
    required this.totalExpenses,
    required this.totalIncome,
    required this.transactionCount,
  });

  double get netAmount => totalIncome - totalExpenses;
  bool get hasTransactions => transactionCount > 0;
}

/// Provider for transactions grouped by date for the focused month
/// Returns a Map where key is date (normalized to midnight) and value is DailySummary
final calendarDailySummariesProvider =
    FutureProvider<Map<DateTime, DailySummary>>((ref) async {
  final db = ref.watch(databaseProvider);
  final focusedDay = ref.watch(calendarFocusedDayProvider);

  // Get first and last day of the focused month
  final firstDay = DateTime(focusedDay.year, focusedDay.month, 1);
  final lastDay = DateTime(focusedDay.year, focusedDay.month + 1, 0, 23, 59, 59, 999);

  // Query all transactions for the month
  final transactions = await (db.select(db.transactions)
        ..where((t) => t.timestamp.isBetweenValues(firstDay, lastDay)))
      .get();

  // Group by date
  final Map<DateTime, DailySummary> summaries = {};

  for (final tx in transactions) {
    // Normalize date to midnight for consistent key
    final dateKey = DateTime(
      tx.timestamp.year,
      tx.timestamp.month,
      tx.timestamp.day,
    );

    final existing = summaries[dateKey];
    final isExpense = tx.type == 'expense';

    if (existing != null) {
      summaries[dateKey] = DailySummary(
        date: dateKey,
        totalExpenses: existing.totalExpenses + (isExpense ? tx.amount : 0),
        totalIncome: existing.totalIncome + (isExpense ? 0 : tx.amount),
        transactionCount: existing.transactionCount + 1,
      );
    } else {
      summaries[dateKey] = DailySummary(
        date: dateKey,
        totalExpenses: isExpense ? tx.amount : 0,
        totalIncome: isExpense ? 0 : tx.amount,
        transactionCount: 1,
      );
    }
  }

  return summaries;
});

/// Provider for transactions on the selected day
final selectedDayTransactionsProvider =
    FutureProvider<List<TransactionWithCategory>>((ref) async {
  final selectedDay = ref.watch(calendarSelectedDayProvider);
  if (selectedDay == null) return [];

  final db = ref.watch(databaseProvider);

  // Get start and end of the selected day
  final startOfDay = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
  final endOfDay = DateTime(selectedDay.year, selectedDay.month, selectedDay.day, 23, 59, 59, 999);

  final query = db.select(db.transactions).join([
    leftOuterJoin(
      db.categories,
      db.categories.id.equalsExp(db.transactions.categoryId),
    ),
  ])
    ..where(db.transactions.timestamp.isBetweenValues(startOfDay, endOfDay))
    ..orderBy([OrderingTerm.desc(db.transactions.timestamp)]);

  final rows = await query.get();

  return rows.map((row) {
    return TransactionWithCategory(
      transaction: row.readTable(db.transactions),
      category: row.readTableOrNull(db.categories),
    );
  }).toList();
});

/// Monthly totals for the calendar header
final calendarMonthTotalsProvider = FutureProvider<({double income, double expenses})>((ref) async {
  final summaries = await ref.watch(calendarDailySummariesProvider.future);

  double totalIncome = 0;
  double totalExpenses = 0;

  for (final summary in summaries.values) {
    totalIncome += summary.totalIncome;
    totalExpenses += summary.totalExpenses;
  }

  return (income: totalIncome, expenses: totalExpenses);
});
