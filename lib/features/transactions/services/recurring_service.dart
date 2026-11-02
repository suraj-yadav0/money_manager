import 'dart:math' as math;
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/app_state_provider.dart';
import 'package:uuid/uuid.dart';

/// Service to handle recurring transactions
/// Automatically generates monthly liability transactions based on recurring templates
class RecurringTransactionService {
  final AppDatabase db;

  RecurringTransactionService(this.db);

  /// Process recurring transactions on app startup or resume
  /// Creates new transaction instances for the current month when the scheduled date has arrived
  Future<void> processRecurringTransactions({DateTime? currentDate}) async {
    final now = currentDate ?? DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final daysInCurrentMonth = DateTime(now.year, now.month + 1, 0).day;

    // Unmark any recurring salary or income templates so they never auto-credit
    await (db.update(db.transactions)
      ..where(
        (t) =>
            t.isRecurring.equals(true) &
            (t.note.equals('Monthly Salary') | t.type.equals('income')),
      )).write(const TransactionsCompanion(isRecurring: Value(false)));

    // Get all recurring transactions (templates)
    final recurringTransactions = await (db.select(
      db.transactions,
    )..where((t) => t.isRecurring.equals(true))).get();

    for (final template in recurringTransactions) {
      // Do not auto-credit recurring income or salary
      if (template.type == 'income' ||
          (template.note?.toLowerCase().contains('salary') ?? false)) {
        continue;
      }

      // If template was created in the current month or future, skip current month
      final templateMonth =
          DateTime(template.timestamp.year, template.timestamp.month);
      if (!templateMonth.isBefore(currentMonthStart)) {
        continue;
      }

      // Target day in the current month, clamped to days in month
      final targetDay = math.min(template.timestamp.day, daysInCurrentMonth);

      // Only generate on or after the scheduled date of the month
      if (now.day < targetDay) {
        continue;
      }

      // Check if a transaction for this template already exists in this month
      final existingThisMonth = await _hasTransactionThisMonth(
        template,
        currentMonthStart,
      );

      if (!existingThisMonth) {
        await _createRecurringInstance(template, now.year, now.month, targetDay);
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

    final transactionsInMonth = await (db.select(db.transactions)
          ..where((t) =>
              t.categoryId.equals(template.categoryId) &
              t.type.equals(template.type) &
              t.timestamp.isBetweenValues(monthStart, monthEnd)))
        .get();

    final templateNote = template.note?.trim().toLowerCase() ?? '';

    return transactionsInMonth.any((t) {
      // Verify amount within 1 cent/paisa
      final amountMatches = (t.amount - template.amount).abs() < 0.01;
      if (!amountMatches) return false;

      // If template has a note, match it
      final tNote = t.note?.trim().toLowerCase() ?? '';
      if (templateNote.isNotEmpty) {
        return tNote == templateNote;
      }

      // If template has no note, also check account if linked
      if (template.accountId != null && t.accountId != null) {
        return t.accountId == template.accountId;
      }

      return true;
    });
  }

  /// Create a new instance of a recurring transaction for the given month on its target day
  Future<void> _createRecurringInstance(
    Transaction template,
    int year,
    int month,
    int day,
  ) async {
    final instanceDate = DateTime(
      year,
      month,
      day,
      template.timestamp.hour,
      template.timestamp.minute,
      template.timestamp.second,
    );

    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            syncId: Value(const Uuid().v4()),
            amount: template.amount,
            type: template.type,
            categoryId: template.categoryId,
            goalId: Value(template.goalId),
            accountId: Value(template.accountId),
            timestamp: instanceDate,
            note: Value(template.note),
            paymentMode: Value(template.paymentMode),
            isRecurring: const Value(false),
            isSynced: const Value(false),
          ),
        );

    // If an account is linked, adjust balance
    if (template.accountId != null) {
      final currentAcc = await (db.select(db.bankAccounts)
            ..where((a) => a.id.equals(template.accountId!)))
          .getSingleOrNull();

      if (currentAcc != null) {
        final isCredit = currentAcc.accountType == 'credit_card';
        final double newBal;
        if (isCredit) {
          newBal = template.type == 'expense'
              ? currentAcc.balance + template.amount
              : (currentAcc.balance - template.amount).clamp(0.0, double.infinity);
        } else {
          newBal = template.type == 'expense'
              ? currentAcc.balance - template.amount
              : currentAcc.balance + template.amount;
        }

        await (db.update(db.bankAccounts)
              ..where((a) => a.id.equals(currentAcc.id)))
            .write(
          BankAccountsCompanion(
            balance: Value(newBal),
            updatedAt: Value(DateTime.now()),
            isSynced: const Value(false),
          ),
        );
      }
    }
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
    int? accountId,
    DateTime? timestamp,
  }) async {
    final now = DateTime.now();

    // Create the template (marked as recurring)
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            syncId: Value(const Uuid().v4()),
            amount: amount,
            type: type,
            categoryId: categoryId,
            goalId: Value(goalId),
            accountId: Value(accountId),
            timestamp: timestamp ?? DateTime(now.year, now.month, 1),
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
