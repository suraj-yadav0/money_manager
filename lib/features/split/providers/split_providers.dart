import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/app_state_provider.dart';

// ---------------------------------------------------------------------------
// Stream providers
// ---------------------------------------------------------------------------

/// All split groups ordered by newest first
final allSplitGroupsProvider = StreamProvider<List<SplitGroup>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.splitGroups)
        ..orderBy([(g) => OrderingTerm.desc(g.createdAt)]))
      .watch();
});

/// Active (non-archived) split groups
final activeSplitGroupsProvider = StreamProvider<List<SplitGroup>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.splitGroups)
        ..where((g) => g.isActive.equals(true))
        ..orderBy([(g) => OrderingTerm.desc(g.createdAt)]))
      .watch();
});

/// Members of a specific group
final splitGroupMembersProvider =
    StreamProvider.family<List<SplitMember>, int>((ref, groupId) {
      final db = ref.watch(databaseProvider);
      return (db.select(db.splitMembers)
            ..where((m) => m.groupId.equals(groupId))
            ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
          .watch();
    });

/// Expenses of a specific group
final splitGroupExpensesProvider =
    StreamProvider.family<List<SplitExpense>, int>((ref, groupId) {
      final db = ref.watch(databaseProvider);
      return (db.select(db.splitExpenses)
            ..where((e) => e.groupId.equals(groupId))
            ..orderBy([(e) => OrderingTerm.desc(e.date)]))
          .watch();
    });

/// Shares for a specific expense
final splitExpenseSharesProvider =
    StreamProvider.family<List<SplitExpenseShare>, int>((ref, expenseId) {
      final db = ref.watch(databaseProvider);
      return (db.select(db.splitExpenseShares)
            ..where((s) => s.expenseId.equals(expenseId)))
          .watch();
    });

/// Settlements for a specific group
final splitGroupSettlementsProvider =
    StreamProvider.family<List<SplitSettlement>, int>((ref, groupId) {
      final db = ref.watch(databaseProvider);
      return (db.select(db.splitSettlements)
            ..where((s) => s.groupId.equals(groupId))
            ..orderBy([(s) => OrderingTerm.desc(s.settledAt)]))
          .watch();
    });

// ---------------------------------------------------------------------------
// Balance model
// ---------------------------------------------------------------------------

/// Net balance for a single member within a group.
/// Positive → they are owed money; negative → they owe money.
class MemberBalance {
  final int memberId;
  final String memberName;
  final double netBalance;

  const MemberBalance({
    required this.memberId,
    required this.memberName,
    required this.netBalance,
  });
}

/// Simplified debt: [fromName] owes [amount] to [toName].
class DebtSummary {
  final int fromMemberId;
  final String fromName;
  final int toMemberId;
  final String toName;
  final double amount;

  const DebtSummary({
    required this.fromMemberId,
    required this.fromName,
    required this.toMemberId,
    required this.toName,
    required this.amount,
  });
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class SplitService {
  final AppDatabase db;

  SplitService(this.db);

  // ── Group operations ──────────────────────────────────────────────────────

  Future<int> createGroup({
    required String name,
    String? description,
    required List<String> memberNames,
  }) async {
    int groupId = 0;
    await db.transaction(() async {
      groupId = await db.into(db.splitGroups).insert(
        SplitGroupsCompanion.insert(
          name: name,
          description: Value(description),
        ),
      );
      for (final memberName in memberNames) {
        await db.into(db.splitMembers).insert(
          SplitMembersCompanion.insert(groupId: groupId, name: memberName),
        );
      }
    });
    return groupId;
  }

  Future<void> archiveGroup(int groupId) async {
    await (db.update(db.splitGroups)..where((g) => g.id.equals(groupId)))
        .write(const SplitGroupsCompanion(isActive: Value(false)));
  }

  Future<void> deleteGroup(int groupId) async {
    await db.transaction(() async {
      // Fetch expenses to delete their shares first
      final expenses = await (db.select(db.splitExpenses)
            ..where((e) => e.groupId.equals(groupId)))
          .get();
      for (final exp in expenses) {
        await (db.delete(db.splitExpenseShares)
              ..where((s) => s.expenseId.equals(exp.id)))
            .go();
      }
      await (db.delete(db.splitExpenses)
            ..where((e) => e.groupId.equals(groupId)))
          .go();
      await (db.delete(db.splitSettlements)
            ..where((s) => s.groupId.equals(groupId)))
          .go();
      await (db.delete(db.splitMembers)
            ..where((m) => m.groupId.equals(groupId)))
          .go();
      await (db.delete(db.splitGroups)..where((g) => g.id.equals(groupId)))
          .go();
    });
  }

  // ── Member operations ─────────────────────────────────────────────────────

  Future<int> addMember({required int groupId, required String name}) {
    return db
        .into(db.splitMembers)
        .insert(SplitMembersCompanion.insert(groupId: groupId, name: name));
  }

  // ── Expense operations ────────────────────────────────────────────────────

  /// Add an expense and auto-compute equal shares for all members.
  Future<int> addExpenseEqual({
    required int groupId,
    required int paidByMemberId,
    required double amount,
    required String description,
    required DateTime date,
    required List<int> memberIds,
  }) async {
    int expenseId = 0;
    await db.transaction(() async {
      expenseId = await db.into(db.splitExpenses).insert(
        SplitExpensesCompanion.insert(
          groupId: groupId,
          paidByMemberId: paidByMemberId,
          amount: amount,
          description: description,
          date: date,
        ),
      );
      final share = amount / memberIds.length;
      for (final memberId in memberIds) {
        await db.into(db.splitExpenseShares).insert(
          SplitExpenseSharesCompanion.insert(
            expenseId: expenseId,
            memberId: memberId,
            shareAmount: share,
          ),
        );
      }
    });
    return expenseId;
  }

  /// Add an expense with custom per-member amounts.
  Future<int> addExpenseCustom({
    required int groupId,
    required int paidByMemberId,
    required double amount,
    required String description,
    required DateTime date,
    required Map<int, double> memberShares, // memberId → shareAmount
  }) async {
    int expenseId = 0;
    await db.transaction(() async {
      expenseId = await db.into(db.splitExpenses).insert(
        SplitExpensesCompanion.insert(
          groupId: groupId,
          paidByMemberId: paidByMemberId,
          amount: amount,
          description: description,
          splitType: const Value('custom'),
          date: date,
        ),
      );
      for (final entry in memberShares.entries) {
        await db.into(db.splitExpenseShares).insert(
          SplitExpenseSharesCompanion.insert(
            expenseId: expenseId,
            memberId: entry.key,
            shareAmount: entry.value,
          ),
        );
      }
    });
    return expenseId;
  }

  Future<void> deleteExpense(int expenseId) async {
    await db.transaction(() async {
      await (db.delete(db.splitExpenseShares)
            ..where((s) => s.expenseId.equals(expenseId)))
          .go();
      await (db.delete(db.splitExpenses)
            ..where((e) => e.id.equals(expenseId)))
          .go();
    });
  }

  // ── Settlement operations ─────────────────────────────────────────────────

  Future<void> recordSettlement({
    required int groupId,
    required int fromMemberId,
    required int toMemberId,
    required double amount,
    String? note,
  }) async {
    await db.into(db.splitSettlements).insert(
      SplitSettlementsCompanion.insert(
        groupId: groupId,
        fromMemberId: fromMemberId,
        toMemberId: toMemberId,
        amount: amount,
        note: Value(note),
        settledAt: DateTime.now(),
      ),
    );
  }

  // ── Balance calculation ───────────────────────────────────────────────────

  /// Compute net balances for all members in a group.
  Future<List<MemberBalance>> calculateBalances(int groupId) async {
    final members = await (db.select(db.splitMembers)
          ..where((m) => m.groupId.equals(groupId)))
        .get();

    final balances = <int, double>{
      for (final m in members) m.id: 0.0,
    };

    // Process expenses
    final expenses = await (db.select(db.splitExpenses)
          ..where((e) => e.groupId.equals(groupId)))
        .get();

    for (final expense in expenses) {
      final shares = await (db.select(db.splitExpenseShares)
            ..where((s) => s.expenseId.equals(expense.id)))
          .get();

      // Payer lent money to others
      for (final share in shares) {
        if (share.memberId != expense.paidByMemberId) {
          // payer is owed this share amount
          balances[expense.paidByMemberId] =
              (balances[expense.paidByMemberId] ?? 0) + share.shareAmount;
          // this member owes
          balances[share.memberId] =
              (balances[share.memberId] ?? 0) - share.shareAmount;
        }
      }
    }

    // Process settlements
    final settlements = await (db.select(db.splitSettlements)
          ..where((s) => s.groupId.equals(groupId)))
        .get();

    for (final settlement in settlements) {
      balances[settlement.fromMemberId] =
          (balances[settlement.fromMemberId] ?? 0) + settlement.amount;
      balances[settlement.toMemberId] =
          (balances[settlement.toMemberId] ?? 0) - settlement.amount;
    }

    return members
        .map(
          (m) => MemberBalance(
            memberId: m.id,
            memberName: m.name,
            netBalance: balances[m.id] ?? 0,
          ),
        )
        .toList();
  }

  /// Simplify debts using a greedy algorithm (like Splitwise).
  List<DebtSummary> simplifyDebts(List<MemberBalance> balances) {
    // Separate creditors (positive) and debtors (negative) as typed records
    final creditors = balances
        .where((b) => b.netBalance > 0.005)
        .map((b) => _BalanceEntry(b.memberId, b.memberName, b.netBalance))
        .toList();
    final debtors = balances
        .where((b) => b.netBalance < -0.005)
        .map((b) => _BalanceEntry(b.memberId, b.memberName, -b.netBalance))
        .toList();

    final result = <DebtSummary>[];
    int ci = 0;
    int di = 0;

    while (ci < creditors.length && di < debtors.length) {
      final creditAmount = creditors[ci].amount;
      final debtAmount = debtors[di].amount;
      final settleAmount =
          creditAmount < debtAmount ? creditAmount : debtAmount;

      result.add(
        DebtSummary(
          fromMemberId: debtors[di].memberId,
          fromName: debtors[di].memberName,
          toMemberId: creditors[ci].memberId,
          toName: creditors[ci].memberName,
          amount: settleAmount,
        ),
      );

      creditors[ci].amount -= settleAmount;
      debtors[di].amount -= settleAmount;

      if (creditors[ci].amount < 0.005) ci++;
      if (debtors[di].amount < 0.005) di++;
    }

    return result;
  }
}

final splitServiceProvider = Provider<SplitService>((ref) {
  final db = ref.watch(databaseProvider);
  return SplitService(db);
});

// ---------------------------------------------------------------------------
// Internal helper
// ---------------------------------------------------------------------------

/// Mutable entry used by [SplitService.simplifyDebts].
class _BalanceEntry {
  final int memberId;
  final String memberName;
  double amount;

  _BalanceEntry(this.memberId, this.memberName, this.amount);
}
