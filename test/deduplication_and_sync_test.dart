import 'dart:ffi';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/core/database/database.dart';
import 'package:money_manager/core/services/sync_service.dart';
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

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final migrator = db.createMigrator();
    await migrator.createAll();
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> getCategoryId(String name) async {
    final existing = await (db.select(db.categories)..where((c) => c.name.equals(name))).getSingleOrNull();
    if (existing != null) return existing.id;
    return await db.into(db.categories).insert(
      CategoriesCompanion.insert(name: name, icon: 'category', type: const Value('expense')),
    );
  }

  group('Transaction Deduplication Tests', () {
    test('Deduplicates transactions with identical syncId', () async {
      final catId = await getCategoryId('Food');
      final now = DateTime(2026, 10, 18, 12, 0, 0);

      // Insert two transactions with identical syncId
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          syncId: const Value('dup-sync-1'),
          amount: 250.0,
          type: 'expense',
          categoryId: catId,
          timestamp: now,
          note: const Value('Lunch'),
          isSynced: const Value(true),
        ),
      );

      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          syncId: const Value('dup-sync-1'),
          amount: 250.0,
          type: 'expense',
          categoryId: catId,
          timestamp: now,
          note: const Value('Lunch'),
          isSynced: const Value(false),
        ),
      );

      var allTx = await db.select(db.transactions).get();
      expect(allTx.length, 2);

      final removedSyncIds = await db.deduplicateTransactions();
      allTx = await db.select(db.transactions).get();

      expect(allTx.length, 1);
      expect(allTx.first.syncId, 'dup-sync-1');
      expect(allTx.first.isSynced, true);
      expect(removedSyncIds, isEmpty);
    });

    test('Deduplicates transactions with identical content signature and different syncIds', () async {
      final catId = await getCategoryId('Transport');
      final now = DateTime(2026, 10, 18, 14, 30, 0);

      // Insert two identical content transactions with different syncIds
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          syncId: const Value('sync-orig'),
          amount: 150.0,
          type: 'expense',
          categoryId: catId,
          timestamp: now,
          note: const Value('Metro recharge'),
          isSynced: const Value(true),
        ),
      );

      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          syncId: const Value('sync-duplicate'),
          amount: 150.0,
          type: 'expense',
          categoryId: catId,
          timestamp: now,
          note: const Value('Metro recharge'),
          isSynced: const Value(false),
        ),
      );

      var allTx = await db.select(db.transactions).get();
      expect(allTx.length, 2);

      final removed = await db.deduplicateTransactions();
      allTx = await db.select(db.transactions).get();

      expect(allTx.length, 1);
      expect(allTx.first.syncId, 'sync-orig');
      expect(removed, contains('sync-duplicate'));
    });

    test('Preserves distinct transactions with different notes or timestamps', () async {
      final catId = await getCategoryId('Shopping');
      final now = DateTime(2026, 10, 18, 16, 0, 0);

      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          syncId: const Value('tx-1'),
          amount: 500.0,
          type: 'expense',
          categoryId: catId,
          timestamp: now,
          note: const Value('Shirt'),
        ),
      );

      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          syncId: const Value('tx-2'),
          amount: 500.0,
          type: 'expense',
          categoryId: catId,
          timestamp: now.add(const Duration(minutes: 30)),
          note: const Value('Pants'),
        ),
      );

      final removed = await db.deduplicateTransactions();
      final allTx = await db.select(db.transactions).get();

      expect(removed, isEmpty);
      expect(allTx.length, 2);
    });
  });

  group('Goal and Asset Deduplication Tests', () {
    test('Deduplicates goals with duplicate names and preserves highest saved amount', () async {
      final deadline = DateTime(2026, 12, 31);

      await db.into(db.goals).insert(
        GoalsCompanion.insert(
          syncId: const Value('goal-1'),
          name: 'Emergency Fund',
          targetAmount: 50000.0,
          savedAmount: const Value(10000.0),
          deadline: deadline,
        ),
      );

      await db.into(db.goals).insert(
        GoalsCompanion.insert(
          syncId: const Value('goal-2'),
          name: 'emergency fund',
          targetAmount: 50000.0,
          savedAmount: const Value(25000.0),
          deadline: deadline,
        ),
      );

      var goals = await db.select(db.goals).get();
      expect(goals.length, 2);

      await db.deduplicateGoals();
      goals = await db.select(db.goals).get();

      expect(goals.length, 1);
      expect(goals.first.savedAmount, 25000.0);
    });

    test('Deduplicates assets with identical name and type', () async {
      await db.into(db.assets).insert(
        AssetsCompanion.insert(
          syncId: const Value('asset-1'),
          name: 'Mutual Funds',
          type: 'investment',
          value: 100000.0,
        ),
      );

      await db.into(db.assets).insert(
        AssetsCompanion.insert(
          syncId: const Value('asset-2'),
          name: 'mutual funds',
          type: 'investment',
          value: 100000.0,
        ),
      );

      var assets = await db.select(db.assets).get();
      expect(assets.length, 2);

      await db.deduplicateAssets();
      assets = await db.select(db.assets).get();

      expect(assets.length, 1);
    });
  });

  group('SyncService Concurrency Single-Flight Guard Tests', () {
    test('Concurrent syncAll calls return same active future without racing', () async {
      final syncService = SyncService(db);

      // When Firebase is unconfigured, syncAll returns unconfigured/offline immediately
      final f1 = syncService.syncAll();
      final f2 = syncService.syncAll();

      final results = await Future.wait([f1, f2]);
      expect(results[0].success, false);
      expect(results[1].success, false);
    });
  });
}
