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
