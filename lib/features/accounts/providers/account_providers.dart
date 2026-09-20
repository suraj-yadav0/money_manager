import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/app_state_provider.dart';

/// Stream provider for all bank accounts
final bankAccountsStreamProvider = StreamProvider<List<BankAccount>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.bankAccounts)
        ..orderBy([
          (a) => OrderingTerm.desc(a.isDefault),
          (a) => OrderingTerm.asc(a.name),
        ]))
      .watch();
});

/// Summary of bank account balances
class AccountBalanceSummary {
  final double totalLiquid;
  final double totalCreditDebt;
  final double netBalance;
  final int count;

  const AccountBalanceSummary({
    required this.totalLiquid,
    required this.totalCreditDebt,
    required this.netBalance,
    required this.count,
  });
}

/// Provider for account balances summary
final accountBalanceSummaryProvider = Provider<AccountBalanceSummary>((ref) {
  final accountsAsync = ref.watch(bankAccountsStreamProvider);
  final accounts = accountsAsync.value ?? [];

  double liquid = 0;
  double creditDebt = 0;

  for (final acc in accounts) {
    if (acc.accountType == 'credit_card') {
      creditDebt += acc.balance;
    } else {
      liquid += acc.balance;
    }
  }

  return AccountBalanceSummary(
    totalLiquid: liquid,
    totalCreditDebt: creditDebt,
    netBalance: liquid - creditDebt,
    count: accounts.length,
  );
});

/// Account action controller
class AccountNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  AccountNotifier(this.ref) : super(const AsyncData(null));

  Future<void> createAccount({
    required String name,
    required String bankName,
    String? last4,
    String accountType = 'savings',
    double balance = 0.0,
    double? creditLimit,
    int? billingCycleDay,
    int? paymentDueDay,
    int gracePeriodDays = 20,
    double? lastBillAmount,
    DateTime? lastBillDate,
    double? minAmountDue,
    bool autoNotifyBill = true,
    String? colorHex,
    bool isDefault = false,
  }) async {
    state = const AsyncLoading();
    try {
      final db = ref.read(databaseProvider);

      if (isDefault) {
        // Clear previous default
        await (db.update(db.bankAccounts)).write(
          const BankAccountsCompanion(isDefault: Value(false)),
        );
      }

      await db.into(db.bankAccounts).insert(
            BankAccountsCompanion.insert(
              name: name,
              bankName: bankName,
              accountNumberLast4: Value(last4),
              accountType: Value(accountType),
              balance: Value(balance),
              creditLimit: Value(creditLimit),
              billingCycleDay: Value(billingCycleDay),
              paymentDueDay: Value(paymentDueDay),
              gracePeriodDays: Value(gracePeriodDays),
              lastBillAmount: Value(lastBillAmount),
              lastBillDate: Value(lastBillDate),
              minAmountDue: Value(minAmountDue),
              autoNotifyBill: Value(autoNotifyBill),
              colorHex: Value(colorHex),
              isDefault: Value(isDefault),
            ),
          );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> updateAccount({
    required int id,
    required String name,
    required String bankName,
    String? last4,
    String accountType = 'savings',
    double balance = 0.0,
    double? creditLimit,
    int? billingCycleDay,
    int? paymentDueDay,
    int gracePeriodDays = 20,
    double? lastBillAmount,
    DateTime? lastBillDate,
    double? minAmountDue,
    bool autoNotifyBill = true,
    String? colorHex,
    bool isDefault = false,
  }) async {
    state = const AsyncLoading();
    try {
      final db = ref.read(databaseProvider);

      if (isDefault) {
        // Clear previous default
        await (db.update(db.bankAccounts)).write(
          const BankAccountsCompanion(isDefault: Value(false)),
        );
      }

      await (db.update(db.bankAccounts)..where((a) => a.id.equals(id))).write(
        BankAccountsCompanion(
          name: Value(name),
          bankName: Value(bankName),
          accountNumberLast4: Value(last4),
          accountType: Value(accountType),
          balance: Value(balance),
          creditLimit: Value(creditLimit),
          billingCycleDay: Value(billingCycleDay),
          paymentDueDay: Value(paymentDueDay),
          gracePeriodDays: Value(gracePeriodDays),
          lastBillAmount: Value(lastBillAmount),
          lastBillDate: Value(lastBillDate),
          minAmountDue: Value(minAmountDue),
          autoNotifyBill: Value(autoNotifyBill),
          colorHex: Value(colorHex),
          isDefault: Value(isDefault),
          updatedAt: Value(DateTime.now()),
        ),
      );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> recordBillPayment({
    required int creditCardAccountId,
    required int fromAccountId,
    required double amount,
    String? note,
  }) async {
    state = const AsyncLoading();
    try {
      final db = ref.read(databaseProvider);

      final cc = await (db.select(db.bankAccounts)
            ..where((a) => a.id.equals(creditCardAccountId)))
          .getSingleOrNull();
      final fromAcc = await (db.select(db.bankAccounts)
            ..where((a) => a.id.equals(fromAccountId)))
          .getSingleOrNull();

      if (cc == null || fromAcc == null) {
        throw Exception('Account not found');
      }

      // Deduct funds from source account
      final newFromBalance = fromAcc.balance - amount;
      await (db.update(db.bankAccounts)..where((a) => a.id.equals(fromAcc.id)))
          .write(
        BankAccountsCompanion(
          balance: Value(newFromBalance),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // Deduct debt from credit card account
      final newDebt = (cc.balance - amount).clamp(0.0, double.infinity);
      final newLastBill = cc.lastBillAmount != null
          ? (cc.lastBillAmount! - amount).clamp(0.0, double.infinity)
          : null;

      await (db.update(db.bankAccounts)..where((a) => a.id.equals(cc.id))).write(
        BankAccountsCompanion(
          balance: Value(newDebt),
          lastBillAmount: Value(newLastBill),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // Find or fallback to Bills & Utilities category
      final billCat = await (db.select(db.categories)
            ..where((c) => c.name.equals('Bills & Utilities'))
            ..limit(1))
          .getSingleOrNull() ??
          await (db.select(db.categories)..limit(1)).getSingle();

      // Record transaction as transfer so it settles liability without double counting as category expense
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              amount: amount,
              type: 'transfer',
              categoryId: billCat.id,
              accountId: Value(fromAcc.id),
              timestamp: DateTime.now(),
              paymentMode: const Value('Transfer'),
              note: Value(note ?? 'Credit Card Bill Payment: ${cc.name}'),
            ),
          );

      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> deleteAccount(int id) async {
    state = const AsyncLoading();
    try {
      final db = ref.read(databaseProvider);
      await (db.delete(db.bankAccounts)..where((a) => a.id.equals(id))).go();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> setDefaultAccount(int id) async {
    final db = ref.read(databaseProvider);
    await (db.update(db.bankAccounts)).write(
      const BankAccountsCompanion(isDefault: Value(false)),
    );
    await (db.update(db.bankAccounts)..where((a) => a.id.equals(id))).write(
      const BankAccountsCompanion(isDefault: Value(true)),
    );
  }
}

final accountNotifierProvider =
    StateNotifierProvider<AccountNotifier, AsyncValue<void>>((ref) {
  return AccountNotifier(ref);
});
