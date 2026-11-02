import 'dart:ffi';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/core/database/database.dart';
import 'package:money_manager/features/transactions/services/recurring_service.dart';
import 'package:sqlite3/open.dart';

void main() {
  setUpAll(() {
    open.overrideFor(OperatingSystem.linux, () {
      try {
        return DynamicLibrary.open('/usr/lib/x86_64-linux-gnu/libsqlite3.so.0');
      } catch (_) {
        return DynamicLibrary.open('libsqlite3.so.0');
      }
    });
  });

  late AppDatabase db;
  late RecurringTransactionService service;
  late int billsCategoryId;
  late int entertainmentCategoryId;
  late int bankAccountId;
  late int creditCardAccountId;

  Future<int> getCategoryId(String name, {String icon = 'category'}) async {
    final existing = await (db.select(db.categories)..where((c) => c.name.equals(name))).getSingleOrNull();
    if (existing != null) return existing.id;
    return db.into(db.categories).insert(
          CategoriesCompanion.insert(
            name: name,
            icon: icon,
            type: const Value('expense'),
          ),
        );
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final migrator = db.createMigrator();
    await migrator.createAll();
    service = RecurringTransactionService(db);

    billsCategoryId = await getCategoryId('Bills & Utilities');
    entertainmentCategoryId = await getCategoryId('Entertainment');

    // Seed test bank account and credit card
    bankAccountId = await db.into(db.bankAccounts).insert(
          BankAccountsCompanion.insert(
            name: 'Savings Account',
            bankName: 'HDFC Bank',
            accountType: const Value('savings'),
            balance: const Value(50000.0),
          ),
        );

    creditCardAccountId = await db.into(db.bankAccounts).insert(
          BankAccountsCompanion.insert(
            name: 'Millennia Card',
            bankName: 'HDFC Bank',
            accountType: const Value('credit_card'),
            balance: const Value(2000.0), // Current debt
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  test('does not create recurring liability before required date', () async {
    // Template created in previous month for the 15th of every month
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            amount: 2500,
            type: 'expense',
            categoryId: billsCategoryId,
            timestamp: DateTime(2026, 10, 15, 10, 0),
            note: const Value('Fiber Internet Bill'),
            isRecurring: const Value(true),
          ),
        );

    // Today is Nov 10, 2026 (before 15th)
    await service.processRecurringTransactions(
      currentDate: DateTime(2026, 11, 10),
    );

    final novTransactions = await (db.select(db.transactions)
          ..where((t) => t.timestamp.isBetweenValues(
                DateTime(2026, 11, 1),
                DateTime(2026, 11, 30, 23, 59, 59),
              )))
        .get();

    expect(novTransactions, isEmpty);
  });

  test('creates recurring liability on or after required date with target day', () async {
    // Template created in previous month for the 15th
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            amount: 2500,
            type: 'expense',
            categoryId: billsCategoryId,
            timestamp: DateTime(2026, 10, 15, 9, 30),
            note: const Value('Fiber Internet Bill'),
            paymentMode: const Value('UPI'),
            isRecurring: const Value(true),
          ),
        );

    // Today is Nov 16, 2026 (after 15th)
    await service.processRecurringTransactions(
      currentDate: DateTime(2026, 11, 16),
    );

    final novTransactions = await (db.select(db.transactions)
          ..where((t) =>
              t.isRecurring.equals(false) &
              t.timestamp.isBetweenValues(
                DateTime(2026, 11, 1),
                DateTime(2026, 11, 30, 23, 59, 59),
              )))
        .get();

    expect(novTransactions.length, 1);
    final instance = novTransactions.first;
    expect(instance.amount, 2500);
    expect(instance.note, 'Fiber Internet Bill');
    expect(instance.categoryId, billsCategoryId);
    expect(instance.timestamp.year, 2026);
    expect(instance.timestamp.month, 11);
    expect(instance.timestamp.day, 15); // Exact target day
    expect(instance.isRecurring, false);
  });

  test('unrelated expense in same category does not block recurring liability', () async {
    // Template for rent/bill on 12th
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            amount: 4500,
            type: 'expense',
            categoryId: billsCategoryId,
            timestamp: DateTime(2026, 9, 12, 10, 0),
            note: const Value('Electricity Bill'),
            isRecurring: const Value(true),
          ),
        );

    // User logged an ad-hoc bill earlier this month on Nov 3rd
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            amount: 800,
            type: 'expense',
            categoryId: billsCategoryId,
            timestamp: DateTime(2026, 11, 3, 14, 0),
            note: const Value('Water Tanker'),
            isRecurring: const Value(false),
          ),
        );

    // Today is Nov 12th
    await service.processRecurringTransactions(
      currentDate: DateTime(2026, 11, 12),
    );

    final novTransactions = await (db.select(db.transactions)
          ..where((t) =>
              t.categoryId.equals(billsCategoryId) &
              t.timestamp.isBetweenValues(
                DateTime(2026, 11, 1),
                DateTime(2026, 11, 30, 23, 59, 59),
              )))
        .get();

    expect(novTransactions.length, 2);
    expect(novTransactions.any((t) => t.note == 'Water Tanker'), true);
    expect(novTransactions.any((t) => t.note == 'Electricity Bill' && t.timestamp.day == 12), true);
  });

  test('does not duplicate recurring liability on repeated runs', () async {
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            amount: 649,
            type: 'expense',
            categoryId: entertainmentCategoryId,
            timestamp: DateTime(2026, 10, 5, 8, 0),
            note: const Value('Netflix Subscription'),
            isRecurring: const Value(true),
          ),
        );

    // Process on Nov 5th
    await service.processRecurringTransactions(
      currentDate: DateTime(2026, 11, 5),
    );

    // Process again on Nov 6th and Nov 7th
    await service.processRecurringTransactions(
      currentDate: DateTime(2026, 11, 6),
    );
    await service.processRecurringTransactions(
      currentDate: DateTime(2026, 11, 7),
    );

    final netflixList = await (db.select(db.transactions)
          ..where((t) =>
              t.note.equals('Netflix Subscription') &
              t.timestamp.isBetweenValues(
                DateTime(2026, 11, 1),
                DateTime(2026, 11, 30, 23, 59, 59),
              )))
        .get();

    expect(netflixList.length, 1);
  });

  test('updates linked bank account and credit card balances', () async {
    // 1. Template linked to savings account
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            amount: 15000,
            type: 'expense',
            categoryId: billsCategoryId,
            accountId: Value(bankAccountId),
            timestamp: DateTime(2026, 10, 1, 10, 0),
            note: const Value('House Rent'),
            isRecurring: const Value(true),
          ),
        );

    // 2. Template linked to credit card
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            amount: 1200,
            type: 'expense',
            categoryId: entertainmentCategoryId,
            accountId: Value(creditCardAccountId),
            timestamp: DateTime(2026, 10, 1, 10, 0),
            note: const Value('Cloud Hosting'),
            isRecurring: const Value(true),
          ),
        );

    // Initial balances
    final bankBefore = await (db.select(db.bankAccounts)..where((a) => a.id.equals(bankAccountId))).getSingle();
    final cardBefore = await (db.select(db.bankAccounts)..where((a) => a.id.equals(creditCardAccountId))).getSingle();
    expect(bankBefore.balance, 50000.0);
    expect(cardBefore.balance, 2000.0);

    // Process recurring transactions on Nov 1
    await service.processRecurringTransactions(
      currentDate: DateTime(2026, 11, 1),
    );

    final bankAfter = await (db.select(db.bankAccounts)..where((a) => a.id.equals(bankAccountId))).getSingle();
    final cardAfter = await (db.select(db.bankAccounts)..where((a) => a.id.equals(creditCardAccountId))).getSingle();

    // Savings deducted by 15000 -> 35000
    expect(bankAfter.balance, 35000.0);
    // Credit card accumulated debt by 1200 -> 3200
    expect(cardAfter.balance, 3200.0);
  });

  test('does not auto-credit recurring income or salary', () async {
    final salaryCategoryId = await getCategoryId('Salary', icon: 'payments');

    // Salary template
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            amount: 75000,
            type: 'income',
            categoryId: salaryCategoryId,
            timestamp: DateTime(2026, 10, 1, 10, 0),
            note: const Value('Monthly Salary'),
            isRecurring: const Value(true),
          ),
        );

    // Process on Nov 1
    await service.processRecurringTransactions(
      currentDate: DateTime(2026, 11, 1),
    );

    final novIncome = await (db.select(db.transactions)
          ..where((t) =>
              t.type.equals('income') &
              t.timestamp.isBetweenValues(
                DateTime(2026, 11, 1),
                DateTime(2026, 11, 30, 23, 59, 59),
              )))
        .get();

    expect(novIncome, isEmpty);
  });
}
