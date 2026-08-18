import 'dart:ffi';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/core/database/database.dart';
import 'package:money_manager/features/sms/services/sms_reader_service.dart';
import 'package:money_manager/features/transactions/services/categorization_engine.dart';
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
  late CategorizationEngine categorizationEngine;
  late SmsReaderService smsReaderService;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    categorizationEngine = CategorizationEngine(db);
    smsReaderService = SmsReaderService(
      db: db,
      categorizationEngine: categorizationEngine,
    );

    // Initial table creation
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

  group('Bank Accounts Database Tests', () {
    test('Can insert and retrieve bank accounts', () async {
      await db.into(db.bankAccounts).insert(
            BankAccountsCompanion.insert(
              name: 'HDFC Salary',
              bankName: 'HDFC Bank',
              accountNumberLast4: const Value('1234'),
              accountType: const Value('savings'),
              balance: const Value(50000.0),
              isDefault: const Value(true),
            ),
          );

      final accounts = await db.select(db.bankAccounts).get();
      expect(accounts.any((a) => a.name == 'HDFC Salary'), isTrue);
      final acc = accounts.firstWhere((a) => a.name == 'HDFC Salary');
      expect(acc.bankName, 'HDFC Bank');
      expect(acc.balance, 50000.0);
      expect(acc.isDefault, true);
    });

    test('Can link a transaction to a bank account', () async {
      final accountId = await db.into(db.bankAccounts).insert(
            BankAccountsCompanion.insert(
              name: 'SBI Savings',
              bankName: 'State Bank of India',
              accountNumberLast4: const Value('5678'),
              balance: const Value(15000.0),
            ),
          );

      final categoryId = await getOrCreateCategory('Food & Dining', 'restaurant', 'expense');

      final txId = await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              amount: 450.0,
              type: 'expense',
              categoryId: categoryId,
              accountId: Value(accountId),
              timestamp: DateTime.now(),
              note: const Value('Swiggy Lunch'),
            ),
          );

      final tx = await (db.select(db.transactions)..where((t) => t.id.equals(txId))).getSingle();
      expect(tx.amount, 450.0);
      expect(tx.accountId, accountId);
    });
  });

  group('SmsReaderService & Swipe Workflow Tests', () {
    test('Simulates incoming SMS and creates pending SMS transaction', () async {
      await getOrCreateCategory('Food & Dining', 'restaurant', 'expense');

      await db.into(db.bankAccounts).insert(
            BankAccountsCompanion.insert(
              name: 'HDFC Account',
              bankName: 'HDFC Bank',
              accountNumberLast4: const Value('1234'),
              balance: const Value(20000.0),
            ),
          );

      final smsTx = await smsReaderService.simulateIncomingSms(
        body: 'Dear Customer, INR 550.00 has been debited from your A/c ending 1234 on 15-AUG-26 at SWIGGY via UPI.',
        sender: 'VM-HDFCBK',
      );

      expect(smsTx, isNotNull);
      expect(smsTx!.amount, 550.0);
      expect(smsTx.status, 'pending');
      expect(smsTx.type, 'expense');
      expect(smsTx.accountNumberLast4, '1234');

      final pendingList = await (db.select(db.smsTransactions)
            ..where((s) => s.status.equals('pending')))
          .get();
      expect(pendingList.length, 1);
    });

    test('Accepting an SMS transaction creates real transaction and updates bank balance', () async {
      final catId = await getOrCreateCategory('Food & Dining', 'restaurant', 'expense');

      final accId = await db.into(db.bankAccounts).insert(
            BankAccountsCompanion.insert(
              name: 'HDFC Savings',
              bankName: 'HDFC Bank',
              accountNumberLast4: const Value('1234'),
              balance: const Value(10000.0),
            ),
          );

      final smsTx = await smsReaderService.simulateIncomingSms(
        body: 'Dear Customer, INR 1200.00 debited from A/c ending 1234 at Zomato via UPI.',
        sender: 'VM-HDFCBK',
      );

      expect(smsTx, isNotNull);

      final createdTxId = await smsReaderService.acceptTransaction(
        smsTransactionId: smsTx!.id,
        categoryId: catId,
        accountId: accId,
        note: 'Zomato Dinner',
      );

      expect(createdTxId, greaterThan(0));

      final tx = await (db.select(db.transactions)..where((t) => t.id.equals(createdTxId))).getSingle();
      expect(tx.amount, 1200.0);
      expect(tx.categoryId, catId);
      expect(tx.accountId, accId);
      expect(tx.note, 'Zomato Dinner');

      final account = await (db.select(db.bankAccounts)..where((a) => a.id.equals(accId))).getSingle();
      expect(account.balance, 8800.0);

      final updatedSms = await (db.select(db.smsTransactions)..where((s) => s.id.equals(smsTx.id))).getSingle();
      expect(updatedSms.status, 'accepted');
      expect(updatedSms.transactionId, createdTxId);
    });

    test('Rejecting an SMS transaction marks it as rejected without creating transaction', () async {
      final smsTx = await smsReaderService.simulateIncomingSms(
        body: 'Dear Customer, INR 300.00 debited from A/c ending 1234.',
        sender: 'VM-HDFCBK',
      );

      await smsReaderService.rejectTransaction(smsTx!.id);

      final updatedSms = await (db.select(db.smsTransactions)..where((s) => s.id.equals(smsTx.id))).getSingle();
      expect(updatedSms.status, 'rejected');

      final allTx = await db.select(db.transactions).get();
      expect(allTx, isEmpty);
    });

    test('Undoing an accepted SMS transaction reverts balance and deletes transaction', () async {
      final catId = await getOrCreateCategory('Shopping', 'shopping_bag', 'expense');

      final accId = await db.into(db.bankAccounts).insert(
            BankAccountsCompanion.insert(
              name: 'HDFC Savings',
              bankName: 'HDFC Bank',
              accountNumberLast4: const Value('1234'),
              balance: const Value(5000.0),
            ),
          );

      final smsTx = await smsReaderService.simulateIncomingSms(
        body: 'Dear Customer, INR 2000.00 debited from A/c ending 1234 at Amazon.',
        sender: 'VM-HDFCBK',
      );

      final txId = await smsReaderService.acceptTransaction(
        smsTransactionId: smsTx!.id,
        categoryId: catId,
        accountId: accId,
      );

      var account = await (db.select(db.bankAccounts)..where((a) => a.id.equals(accId))).getSingle();
      expect(account.balance, 3000.0);

      await smsReaderService.undoTransaction(smsTx.id);

      account = await (db.select(db.bankAccounts)..where((a) => a.id.equals(accId))).getSingle();
      expect(account.balance, 5000.0);

      final txList = await (db.select(db.transactions)..where((t) => t.id.equals(txId))).get();
      expect(txList, isEmpty);

      final revertedSms = await (db.select(db.smsTransactions)..where((s) => s.id.equals(smsTx.id))).getSingle();
      expect(revertedSms.status, 'pending');
      expect(revertedSms.transactionId, isNull);
    });
  });
}
