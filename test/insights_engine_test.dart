import 'dart:ffi';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/core/database/database.dart';
import 'package:money_manager/features/insights/services/insights_engine.dart';
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
  late InsightsEngine engine;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    engine = InsightsEngine(db);

    final migrator = db.createMigrator();
    await migrator.createAll();
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> getOrCreateCategory(String name, String icon, String type) async {
    final existing = await (db.select(db.categories)
          ..where((c) => c.name.equals(name)))
        .getSingleOrNull();
    if (existing != null) return existing.id;
    return await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            name: name,
            icon: icon,
            type: Value(type),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  group('Insights Engine Forecast and Dominance Tests', () {
    test('Large investment does not trigger false deficit warning when living expenses are lean', () async {
      final investCatId = await getOrCreateCategory('Investments', 'show_chart', 'expense');
      final diningCatId = await getOrCreateCategory('Food & Dining', 'restaurant', 'expense');

      // Set user monthly income to 100,000
      await db.into(db.userSettings).insert(
        UserSettingsCompanion.insert(
          id: const Value(1),
          monthlyIncome: const Value(100000.0),
        ),
        mode: InsertMode.insertOrReplace,
      );

      final now = DateTime.now();

      // User invested 40,000 in index funds
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          note: const Value('Monthly Index Fund SIP'),
          amount: 40000.0,
          type: 'expense',
          categoryId: investCatId,
          timestamp: now,
        ),
      );

      // User spent 500 on dinner
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          note: const Value('Dinner'),
          amount: 500.0,
          type: 'expense',
          categoryId: diningCatId,
          timestamp: now,
        ),
      );

      final insights = await engine.generateDailyInsights();

      // Deficit warning should NOT be present because living burn is tiny (500 / daysElapsed)
      final deficitWarning = insights.where(
        (i) => i.type == InsightType.forecastWarning && i.severity == InsightSeverity.critical,
      );
      expect(deficitWarning.isEmpty, isTrue);

      // Dominance check should ignore Investments category for spend cuts
      final investDominance = insights.where(
        (i) => i.type == InsightType.categoryDominance && i.title.contains('Investments'),
      );
      expect(investDominance.isEmpty, isTrue);
    });

    test('Excessive living consumption does trigger deficit warning', () async {
      final shoppingCatId = await getOrCreateCategory('Shopping', 'shopping_bag', 'expense');

      // User income is 30,000
      await db.into(db.userSettings).insert(
        UserSettingsCompanion.insert(
          id: const Value(1),
          monthlyIncome: const Value(30000.0),
        ),
        mode: InsertMode.insertOrReplace,
      );

      final now = DateTime.now();

      // High consumption expense
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          note: const Value('Luxury goods'),
          amount: 28000.0,
          type: 'expense',
          categoryId: shoppingCatId,
          timestamp: now,
        ),
      );

      final insights = await engine.generateDailyInsights();
      final hasWarning = insights.any((i) => i.type == InsightType.forecastWarning);
      expect(hasWarning, isTrue);
    });
  });
}
