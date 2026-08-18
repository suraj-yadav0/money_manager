import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/database.dart';
import '../../transactions/services/categorization_engine.dart';
import 'sms_parser_engine.dart';

class SmsScanResult {
  final int totalScanned;
  final int newTransactionsFound;
  final String message;

  const SmsScanResult({
    required this.totalScanned,
    required this.newTransactionsFound,
    required this.message,
  });
}

class SmsReaderService {
  static const MethodChannel _channel =
      MethodChannel('com.example.money_manager/sms_reader');
  static const String _prefLastSmsSyncKey = 'last_sms_sync_timestamp';

  final AppDatabase db;
  final CategorizationEngine categorizationEngine;

  SmsReaderService({
    required this.db,
    required this.categorizationEngine,
  });

  /// Check if SMS permission is granted
  Future<bool> hasPermission() async {
    if (!Platform.isAndroid) return false;
    final status = await Permission.sms.status;
    return status.isGranted;
  }

  /// Request SMS permission from user
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return false;
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  /// Scan Android SMS inbox for new financial transaction messages
  Future<SmsScanResult> scanInbox({bool forceFullScan = false}) async {
    if (!Platform.isAndroid) {
      return const SmsScanResult(
        totalScanned: 0,
        newTransactionsFound: 0,
        message: 'SMS detection is only supported on Android',
      );
    }

    final hasPerm = await hasPermission();
    if (!hasPerm) {
      final granted = await requestPermission();
      if (!granted) {
        return const SmsScanResult(
          totalScanned: 0,
          newTransactionsFound: 0,
          message: 'SMS permission was not granted',
        );
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncTimestamp = forceFullScan
          ? null
          : prefs.getInt(_prefLastSmsSyncKey);

      // Default look back 30 days if first time
      final since = lastSyncTimestamp ??
          DateTime.now()
              .subtract(const Duration(days: 30))
              .millisecondsSinceEpoch;

      final List<dynamic>? rawMessages =
          await _channel.invokeMethod<List<dynamic>>(
        'readInboxSms',
        {'sinceTimestamp': since, 'limit': 150},
      );

      if (rawMessages == null || rawMessages.isEmpty) {
        await prefs.setInt(
            _prefLastSmsSyncKey, DateTime.now().millisecondsSinceEpoch);
        return const SmsScanResult(
          totalScanned: 0,
          newTransactionsFound: 0,
          message: 'No new messages found',
        );
      }

      int newFoundCount = 0;
      final existingSmsList = await (db.select(db.smsTransactions)).get();
      final existingIds = existingSmsList.map((s) => s.smsId).toSet();

      final allAccounts = await (db.select(db.bankAccounts)).get();
      final defaultAccount =
          allAccounts.where((a) => a.isDefault).firstOrNull ??
              allAccounts.firstOrNull;

      for (final raw in rawMessages) {
        if (raw is! Map) continue;
        final id = raw['id']?.toString() ?? '';
        final sender = raw['address']?.toString() ?? '';
        final body = raw['body']?.toString() ?? '';
        final dateMillis = raw['date'] as num?;
        final timestamp = dateMillis != null
            ? DateTime.fromMillisecondsSinceEpoch(dateMillis.toInt())
            : DateTime.now();

        if (id.isNotEmpty && existingIds.contains(id)) {
          continue;
        }

        final parsed = SmsParserEngine.parse(
          id: id,
          sender: sender,
          body: body,
          timestamp: timestamp,
        );

        if (parsed != null) {
          // Double check if hash exists
          if (existingIds.contains(parsed.smsId)) continue;

          // 1. Auto-suggest Category
          int? suggestedCatId;
          final searchNote = parsed.merchant ?? parsed.rawBody;
          final suggestedCat =
              await categorizationEngine.suggestCategory(searchNote);
          if (suggestedCat != null) {
            suggestedCatId = suggestedCat.id;
          } else {
            // Default category based on type
            final fallbackCat = await (db.select(db.categories)
                  ..where((c) => c.type.equals(parsed.type))
                  ..limit(1))
                .getSingleOrNull();
            suggestedCatId = fallbackCat?.id;
          }

          // 2. Auto-match Bank Account
          int? matchedAccountId;
          if (parsed.accountNumberLast4 != null) {
            final matchByLast4 = allAccounts
                .where((a) =>
                    a.accountNumberLast4 != null &&
                    a.accountNumberLast4 == parsed.accountNumberLast4)
                .firstOrNull;
            matchedAccountId = matchByLast4?.id;
          }

          if (matchedAccountId == null && parsed.bankName != null) {
            final matchByName = allAccounts
                .where((a) =>
                    a.bankName.toLowerCase().contains(
                        parsed.bankName!.toLowerCase()) ||
                    parsed.bankName!
                        .toLowerCase()
                        .contains(a.bankName.toLowerCase()))
                .firstOrNull;
            matchedAccountId = matchByName?.id;
          }

          matchedAccountId ??= defaultAccount?.id;

          // 3. Insert into database
          await db.into(db.smsTransactions).insert(
                SmsTransactionsCompanion.insert(
                  smsId: parsed.smsId,
                  sender: parsed.sender,
                  body: parsed.rawBody,
                  amount: parsed.amount,
                  type: parsed.type,
                  paymentMode: Value(parsed.paymentMode),
                  bankName: Value(parsed.bankName),
                  accountNumberLast4: Value(parsed.accountNumberLast4),
                  merchant: Value(parsed.merchant),
                  refNumber: Value(parsed.refNumber),
                  balance: Value(parsed.balance),
                  suggestedCategoryId: Value(suggestedCatId),
                  suggestedAccountId: Value(matchedAccountId),
                  smsTimestamp: parsed.timestamp,
                  status: const Value('pending'),
                ),
              );

          existingIds.add(parsed.smsId);
          newFoundCount++;
        }
      }

      await prefs.setInt(
          _prefLastSmsSyncKey, DateTime.now().millisecondsSinceEpoch);

      return SmsScanResult(
        totalScanned: rawMessages.length,
        newTransactionsFound: newFoundCount,
        message: newFoundCount > 0
            ? 'Found $newFoundCount new transaction${newFoundCount > 1 ? 's' : ''}'
            : 'No new transaction messages detected',
      );
    } catch (e) {
      debugPrint('Error reading SMS inbox: $e');
      return SmsScanResult(
        totalScanned: 0,
        newTransactionsFound: 0,
        message: 'Error scanning SMS: $e',
      );
    }
  }

  /// Simulate an incoming SMS (for testing and emulator use)
  Future<SmsTransaction?> simulateIncomingSms({
    required String body,
    String sender = 'VM-HDFCBK',
    DateTime? timestamp,
  }) async {
    final now = timestamp ?? DateTime.now();
    final dummyId = 'SIM_${now.millisecondsSinceEpoch}_${body.hashCode.abs()}';

    final parsed = SmsParserEngine.parse(
      id: dummyId,
      sender: sender,
      body: body,
      timestamp: now,
    );

    if (parsed == null) return null;

    final allAccounts = await (db.select(db.bankAccounts)).get();
    final defaultAccount = allAccounts.where((a) => a.isDefault).firstOrNull ??
        allAccounts.firstOrNull;

    // Suggest Category
    int? suggestedCatId;
    final searchNote = parsed.merchant ?? parsed.rawBody;
    final suggestedCat = await categorizationEngine.suggestCategory(searchNote);
    if (suggestedCat != null) {
      suggestedCatId = suggestedCat.id;
    } else {
      final fallbackCat = await (db.select(db.categories)
            ..where((c) => c.type.equals(parsed.type))
            ..limit(1))
          .getSingleOrNull();
      suggestedCatId = fallbackCat?.id;
    }

    // Match Account
    int? matchedAccountId;
    if (parsed.accountNumberLast4 != null) {
      final match = allAccounts
          .where((a) =>
              a.accountNumberLast4 != null &&
              a.accountNumberLast4 == parsed.accountNumberLast4)
          .firstOrNull;
      matchedAccountId = match?.id;
    }
    if (matchedAccountId == null && parsed.bankName != null) {
      final match = allAccounts
          .where((a) =>
              a.bankName
                  .toLowerCase()
                  .contains(parsed.bankName!.toLowerCase()) ||
              parsed.bankName!
                  .toLowerCase()
                  .contains(a.bankName.toLowerCase()))
          .firstOrNull;
      matchedAccountId = match?.id;
    }
    matchedAccountId ??= defaultAccount?.id;

    final insertedId = await db.into(db.smsTransactions).insert(
          SmsTransactionsCompanion.insert(
            smsId: parsed.smsId,
            sender: parsed.sender,
            body: parsed.rawBody,
            amount: parsed.amount,
            type: parsed.type,
            paymentMode: Value(parsed.paymentMode),
            bankName: Value(parsed.bankName),
            accountNumberLast4: Value(parsed.accountNumberLast4),
            merchant: Value(parsed.merchant),
            refNumber: Value(parsed.refNumber),
            balance: Value(parsed.balance),
            suggestedCategoryId: Value(suggestedCatId),
            suggestedAccountId: Value(matchedAccountId),
            smsTimestamp: parsed.timestamp,
            status: const Value('pending'),
          ),
        );

    return (db.select(db.smsTransactions)
          ..where((s) => s.id.equals(insertedId)))
        .getSingleOrNull();
  }

  /// Accept a detected SMS transaction and insert it into real Transactions table
  Future<int> acceptTransaction({
    required int smsTransactionId,
    int? categoryId,
    int? accountId,
    String? note,
    double? amount,
    DateTime? timestamp,
  }) async {
    final smsTx = await (db.select(db.smsTransactions)
          ..where((s) => s.id.equals(smsTransactionId)))
        .getSingleOrNull();

    if (smsTx == null) {
      throw Exception('SMS Transaction not found: $smsTransactionId');
    }

    final finalAmount = amount ?? smsTx.amount;
    final finalDate = timestamp ?? smsTx.smsTimestamp;
    final finalNote = note ?? smsTx.merchant ?? smsTx.sender;

    // Resolve Category
    int finalCatId = categoryId ?? smsTx.suggestedCategoryId ?? 1;
    final catExists = await (db.select(db.categories)
          ..where((c) => c.id.equals(finalCatId)))
        .getSingleOrNull();

    if (catExists == null) {
      final fallbackCat = await (db.select(db.categories)
            ..where((c) => c.type.equals(smsTx.type))
            ..limit(1))
          .getSingle();
      finalCatId = fallbackCat.id;
    }

    // 1. Insert into Transactions
    final txId = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            amount: finalAmount,
            type: smsTx.type,
            categoryId: finalCatId,
            accountId: Value(accountId ?? smsTx.suggestedAccountId),
            timestamp: finalDate,
            note: Value(finalNote),
            paymentMode: Value(smsTx.paymentMode ?? 'UPI'),
          ),
        );

    // 2. Update Bank Account Balance
    final targetAccountId = accountId ?? smsTx.suggestedAccountId;
    if (targetAccountId != null) {
      final account = await (db.select(db.bankAccounts)
            ..where((a) => a.id.equals(targetAccountId)))
          .getSingleOrNull();

      if (account != null) {
        final newBalance = smsTx.type == 'income'
            ? account.balance + finalAmount
            : account.balance - finalAmount;

        await (db.update(db.bankAccounts)
              ..where((a) => a.id.equals(targetAccountId)))
            .write(
          BankAccountsCompanion(
            balance: Value(newBalance),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    }

    // 3. Train Categorization Engine
    if (finalNote.isNotEmpty) {
      await categorizationEngine.learnFromCorrection(finalNote, finalCatId);
    }

    // 4. Mark SmsTransaction as Accepted
    await (db.update(db.smsTransactions)
          ..where((s) => s.id.equals(smsTransactionId)))
        .write(
      SmsTransactionsCompanion(
        status: const Value('accepted'),
        transactionId: Value(txId),
        suggestedCategoryId: Value(finalCatId),
        suggestedAccountId: Value(targetAccountId),
        updatedAt: Value(DateTime.now()),
      ),
    );

    return txId;
  }

  /// Reject / Dismiss a detected SMS transaction
  Future<void> rejectTransaction(int smsTransactionId) async {
    await (db.update(db.smsTransactions)
          ..where((s) => s.id.equals(smsTransactionId)))
        .write(
      SmsTransactionsCompanion(
        status: const Value('rejected'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Undo the last swipe action (revert back to pending)
  Future<void> undoTransaction(int smsTransactionId) async {
    final smsTx = await (db.select(db.smsTransactions)
          ..where((s) => s.id.equals(smsTransactionId)))
        .getSingleOrNull();

    if (smsTx == null) return;

    if (smsTx.status == 'accepted' && smsTx.transactionId != null) {
      // Revert account balance
      if (smsTx.suggestedAccountId != null) {
        final account = await (db.select(db.bankAccounts)
              ..where((a) => a.id.equals(smsTx.suggestedAccountId!)))
            .getSingleOrNull();

        if (account != null) {
          final revertedBalance = smsTx.type == 'income'
              ? account.balance - smsTx.amount
              : account.balance + smsTx.amount;

          await (db.update(db.bankAccounts)
                ..where((a) => a.id.equals(smsTx.suggestedAccountId!)))
              .write(BankAccountsCompanion(
            balance: Value(revertedBalance),
            updatedAt: Value(DateTime.now()),
          ));
        }
      }

      // Delete generated Transaction row
      await (db.delete(db.transactions)
            ..where((t) => t.id.equals(smsTx.transactionId!)))
          .go();
    }

    // Reset status to pending
    await (db.update(db.smsTransactions)
          ..where((s) => s.id.equals(smsTransactionId)))
        .write(
      const SmsTransactionsCompanion(
        status: Value('pending'),
        transactionId: Value(null),
      ),
    );
  }
}
