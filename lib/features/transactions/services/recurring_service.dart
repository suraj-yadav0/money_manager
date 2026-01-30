import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/app_state_provider.dart';

/// Service to handle recurring transactions
/// Automatically generates monthly income transactions based on recurring templates
class RecurringTransactionService {
  final AppDatabase db;

  RecurringTransactionService(this.db);

  /// Process recurring transactions on app startup
  /// Creates new transaction instances for the current month if they don't exist
  Future<void> processRecurringTransactions() async {
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);

    // Get all recurring transactions (templates)
    final recurringTransactions = await (db.select(
      db.transactions,
    )..where((t) => t.isRecurring.equals(true))).get();

    for (final template in recurringTransactions) {
      // Check if a transaction for this month already exists
      // We look for transactions with the same categoryId, type, and amount
      // in the current month
      final existingThisMonth = await _hasTransactionThisMonth(
        template,
        currentMonthStart,
      );

      if (!existingThisMonth) {
        await _createRecurringInstance(template, currentMonthStart);
      }
    }
  }

  /// Check if a recurring transaction already has an instance this month
  Future<bool> _hasTransactionThisMonth(
    Transaction template,
    DateTime monthStart,
  ) async {
    final monthEnd = DateTime(
      monthStart.year,
      monthStart.month + 1,
      0,
      23,
      59,
      59,
      999,
    );

    // For recurring income (like salary), we check by categoryId and type
    // For the same month - we don't want duplicate salary entries
    final existing =
        await (db.select(db.transactions)..where(
              (t) =>
                  t.categoryId.equals(template.categoryId) &
                  t.type.equals(template.type) &
                  t.timestamp.isBetweenValues(monthStart, monthEnd),
            ))
            .get();

    return existing.isNotEmpty;
  }

  /// Create a new instance of a recurring transaction for the given month
  Future<void> _createRecurringInstance(
    Transaction template,
    DateTime monthStart,
  ) async {
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            amount: template.amount,
            type: template.type,
            categoryId: template.categoryId,
            goalId: Value(template.goalId),
            timestamp: monthStart, // Set to 1st of the month
            note: Value(template.note),
            paymentMode: Value(template.paymentMode),
            isRecurring: const Value(false), // Instance is not a template
          ),
        );
  }

  /// Get all recurring transaction templates
  Future<List<Transaction>> getRecurringTemplates() async {
    return (db.select(
      db.transactions,
    )..where((t) => t.isRecurring.equals(true))).get();
  }

  /// Create a new recurring transaction template
  Future<void> createRecurringTemplate({
    required double amount,
    required String type,
    required int categoryId,
    String? note,
    String? paymentMode,
    int? goalId,
  }) async {
    final now = DateTime.now();

    // Create the template (marked as recurring)
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            amount: amount,
            type: type,
            categoryId: categoryId,
            goalId: Value(goalId),
            timestamp: DateTime(now.year, now.month, 1),
            note: Value(note),
            paymentMode: Value(paymentMode),
            isRecurring: const Value(true),
          ),
        );
  }

  /// Delete a recurring transaction template and optionally all its instances
  Future<void> deleteRecurringTemplate(int templateId) async {
    await (db.delete(
      db.transactions,
    )..where((t) => t.id.equals(templateId))).go();
  }
}

/// Provider for the recurring transaction service
final recurringTransactionServiceProvider =
    Provider<RecurringTransactionService>((ref) {
      final db = ref.watch(databaseProvider);
      return RecurringTransactionService(db);
    });
