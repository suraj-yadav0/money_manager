import 'dart:ffi';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/core/database/database.dart';
import 'package:money_manager/core/providers/app_state_provider.dart';
import 'package:money_manager/features/budget/providers/budget_provider.dart';
import 'package:money_manager/features/dashboard/providers/dashboard_providers.dart';
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
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final migrator = db.createMigrator();
    await migrator.createAll();

    // Reset default user settings with carryForwardEnabled = true
    await db.into(db.userSettings).insertOnConflictUpdate(
          UserSettingsCompanion.insert(
            id: const Value(1),
            monthlyIncome: const Value(50000),
            currency: const Value('INR'),
            carryForwardEnabled: const Value(true),
          ),
        );

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<int> getOrCreateCategoryWithBudget(String name, double budget) async {
    final existing = await (db.select(db.categories)..where((c) => c.name.equals(name))).getSingleOrNull();
    if (existing != null) {
      await (db.update(db.categories)..where((c) => c.id.equals(existing.id))).write(
        CategoriesCompanion(monthlyBudget: Value(budget)),
      );
      return existing.id;
    }
    return await db.into(db.categories).insert(
      CategoriesCompanion.insert(
        name: name,
        icon: 'category',
        monthlyBudget: Value(budget),
        type: const Value('expense'),
      ),
    );
  }

  test('Budget carry forward rolls over surplus unspent budget to next month', () async {
    final catId = await getOrCreateCategoryWithBudget('Test Food', 5000.0);

    // Expense of 3500 in Oct 2026 (leaves 1500 surplus)
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            amount: 3500.0,
            type: 'expense',
            categoryId: catId,
            timestamp: DateTime(2026, 10, 15, 12, 0),
          ),
        );

    // View Nov 2026 budget
    container.read(budgetSelectedMonthProvider.notifier).state = DateTime(2026, 11, 1);
    final sub = container.listen(budgetStatsProvider, (_, __) {});
    final stats = await container.read(budgetStatsProvider.future);
    sub.close();

    final foodStats = stats.categoryStats.firstWhere((c) => c.id == catId);
    expect(foodStats.baseBudget, 5000.0);
    expect(foodStats.rollover, 1500.0);
    expect(foodStats.budget, 6500.0); // 5000 base + 1500 surplus
    expect(foodStats.spent, 0.0);
    expect(foodStats.remaining, 6500.0);
  });

  test('Budget carry forward rolls over deficit when overspent', () async {
    final catId = await getOrCreateCategoryWithBudget('Test Entertainment', 2000.0);

    // Overspend: spent 2600 in Oct 2026 (deficit -600)
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            amount: 2600.0,
            type: 'expense',
            categoryId: catId,
            timestamp: DateTime(2026, 10, 20),
          ),
        );

    // View Nov 2026 budget
    container.read(budgetSelectedMonthProvider.notifier).state = DateTime(2026, 11, 1);
    final sub = container.listen(budgetStatsProvider, (_, __) {});
    final stats = await container.read(budgetStatsProvider.future);
    sub.close();

    final entStats = stats.categoryStats.firstWhere((c) => c.id == catId);
    expect(entStats.baseBudget, 2000.0);
    expect(entStats.rollover, -600.0);
    expect(entStats.budget, 1400.0); // 2000 base - 600 deficit
  });

  test('Multi-month chain carries forward across successive months', () async {
    final catId = await getOrCreateCategoryWithBudget('Test Shopping', 4000.0);

    // Aug: base 4000, spent 3000 -> +1000 leftover
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            amount: 3000.0,
            type: 'expense',
            categoryId: catId,
            timestamp: DateTime(2026, 8, 10),
          ),
        );

    // Sep: effective 4000 + 1000 = 5000, spent 5500 -> -500 deficit
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            amount: 5500.0,
            type: 'expense',
            categoryId: catId,
            timestamp: DateTime(2026, 9, 12),
          ),
        );

    // Oct: effective 4000 - 500 = 3500, spent 2000 -> +1500 leftover
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            amount: 2000.0,
            type: 'expense',
            categoryId: catId,
            timestamp: DateTime(2026, 10, 5),
          ),
        );

    // Nov 2026 should have +1500 rollover -> 5500 effective budget
    container.read(budgetSelectedMonthProvider.notifier).state = DateTime(2026, 11, 1);
    final sub = container.listen(budgetStatsProvider, (_, __) {});
    final stats = await container.read(budgetStatsProvider.future);
    sub.close();
    final shopStats = stats.categoryStats.firstWhere((c) => c.id == catId);

    expect(shopStats.baseBudget, 4000.0);
    expect(shopStats.rollover, 1500.0);
    expect(shopStats.budget, 5500.0);
  });

  test('Dashboard carries forward unspent cash balance into monthly net balance', () async {
    final catIncome = await (db.select(db.categories)..where((c) => c.type.equals('income'))).get();
    final incomeCatId = catIncome.first.id;
    final catExpense = await (db.select(db.categories)..where((c) => c.type.equals('expense'))).get();
    final expenseCatId = catExpense.first.id;

    // Prior transactions before the start of the filter:
    // Insert historical transactions before range
    // October 2026: Income 60,000, Expense 40,000 -> +20,000 leftover
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            amount: 60000.0,
            type: 'income',
            categoryId: incomeCatId,
            timestamp: DateTime(2026, 10, 1),
          ),
        );
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            amount: 40000.0,
            type: 'expense',
            categoryId: expenseCatId,
            timestamp: DateTime(2026, 10, 2),
          ),
        );

    // Now test with dashboardDateFilterProvider set to thisMonth (current month)
    container.read(dashboardDateFilterProvider.notifier).state = DashboardDateFilter.thisMonth;
    final sub = container.listen(dashboardStatsProvider, (_, __) {});
    final stats = await container.read(dashboardStatsProvider.future);
    sub.close();

    // All transactions in Oct 2026 are before Nov 2026, so carried forward must be +20000
    expect(stats.carriedForward, 20000.0);
    expect(stats.balance, 20000.0 + stats.periodNet);
  });

  test('Disabling carry forward isolates monthly budget and dashboard', () async {
    // Disable carry forward
    await (db.update(db.userSettings)..where((u) => u.id.equals(1))).write(
      const UserSettingsCompanion(carryForwardEnabled: Value(false)),
    );

    final catId = await getOrCreateCategoryWithBudget('Test Groceries', 5000.0);

    // Oct 2026: spent 2000 (leaves 3000)
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            amount: 2000.0,
            type: 'expense',
            categoryId: catId,
            timestamp: DateTime(2026, 10, 10),
          ),
        );

    // In Nov 2026 with carryForward disabled, rollover must be 0
    container.read(budgetSelectedMonthProvider.notifier).state = DateTime(2026, 11, 1);
    final sub = container.listen(budgetStatsProvider, (_, __) {});
    final stats = await container.read(budgetStatsProvider.future);
    sub.close();
    final grocStats = stats.categoryStats.firstWhere((c) => c.id == catId);

    expect(grocStats.rollover, 0.0);
    expect(grocStats.budget, 5000.0);
  });
}
