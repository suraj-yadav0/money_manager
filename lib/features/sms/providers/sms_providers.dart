import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../transactions/services/categorization_engine.dart';
import '../services/sms_reader_service.dart';

/// Provider for SmsReaderService
final smsReaderServiceProvider = Provider<SmsReaderService>((ref) {
  final db = ref.watch(databaseProvider);
  final engine = ref.watch(categorizationEngineProvider);
  return SmsReaderService(db: db, categorizationEngine: engine);
});

/// Data class combining SMS transaction with its suggested Category & BankAccount
class SmsTransactionDetail {
  final SmsTransaction smsTransaction;
  final Category? suggestedCategory;
  final BankAccount? suggestedAccount;

  const SmsTransactionDetail({
    required this.smsTransaction,
    this.suggestedCategory,
    this.suggestedAccount,
  });
}

/// Stream provider for pending SMS transactions
final pendingSmsTransactionsProvider =
    StreamProvider<List<SmsTransactionDetail>>((ref) {
  final db = ref.watch(databaseProvider);

  final query = db.select(db.smsTransactions).join([
    leftOuterJoin(
      db.categories,
      db.categories.id.equalsExp(db.smsTransactions.suggestedCategoryId),
    ),
    leftOuterJoin(
      db.bankAccounts,
      db.bankAccounts.id.equalsExp(db.smsTransactions.suggestedAccountId),
    ),
  ])
    ..where(db.smsTransactions.status.equals('pending'))
    ..orderBy([OrderingTerm.desc(db.smsTransactions.smsTimestamp)]);

  return query.watch().map((rows) {
    return rows.map((row) {
      return SmsTransactionDetail(
        smsTransaction: row.readTable(db.smsTransactions),
        suggestedCategory: row.readTableOrNull(db.categories),
        suggestedAccount: row.readTableOrNull(db.bankAccounts),
      );
    }).toList();
  });
});

/// Provider for pending SMS count
final pendingSmsCountProvider = Provider<int>((ref) {
  final pendingAsync = ref.watch(pendingSmsTransactionsProvider);
  return pendingAsync.value?.length ?? 0;
});

/// State notifier for scanning SMS inbox
class SmsScanState {
  final bool isScanning;
  final String? message;
  final int? newCount;

  const SmsScanState({
    this.isScanning = false,
    this.message,
    this.newCount,
  });
}

class SmsScanNotifier extends StateNotifier<SmsScanState> {
  final Ref ref;

  SmsScanNotifier(this.ref) : super(const SmsScanState());

  Future<SmsScanResult> scanInbox({bool forceFullScan = false}) async {
    state = const SmsScanState(isScanning: true);
    final service = ref.read(smsReaderServiceProvider);
    final result = await service.scanInbox(forceFullScan: forceFullScan);

    state = SmsScanState(
      isScanning: false,
      message: result.message,
      newCount: result.newTransactionsFound,
    );

    if (result.newTransactionsFound > 0) {
      ref.invalidate(pendingSmsTransactionsProvider);
    }

    return result;
  }

  Future<void> acceptCard(
    int smsId, {
    int? categoryId,
    int? accountId,
    String? note,
    double? amount,
  }) async {
    final service = ref.read(smsReaderServiceProvider);
    await service.acceptTransaction(
      smsTransactionId: smsId,
      categoryId: categoryId,
      accountId: accountId,
      note: note,
      amount: amount,
    );
    ref.invalidate(pendingSmsTransactionsProvider);
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(recentTransactionsProvider);
  }

  Future<void> rejectCard(int smsId) async {
    final service = ref.read(smsReaderServiceProvider);
    await service.rejectTransaction(smsId);
    ref.invalidate(pendingSmsTransactionsProvider);
  }

  Future<void> undoCard(int smsId) async {
    final service = ref.read(smsReaderServiceProvider);
    await service.undoTransaction(smsId);
    ref.invalidate(pendingSmsTransactionsProvider);
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(recentTransactionsProvider);
  }

  Future<SmsTransaction?> simulateSms(String body, {String sender = 'VM-HDFCBK'}) async {
    final service = ref.read(smsReaderServiceProvider);
    final tx = await service.simulateIncomingSms(body: body, sender: sender);
    ref.invalidate(pendingSmsTransactionsProvider);
    return tx;
  }
}

final smsScanNotifierProvider =
    StateNotifierProvider<SmsScanNotifier, SmsScanState>((ref) {
  return SmsScanNotifier(ref);
});
