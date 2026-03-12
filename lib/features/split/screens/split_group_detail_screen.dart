import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/presentation/glass_widgets.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/split_providers.dart';
import '../widgets/settle_up_sheet.dart';
import 'add_split_expense_screen.dart';

class SplitGroupDetailScreen extends ConsumerStatefulWidget {
  final SplitGroup group;

  const SplitGroupDetailScreen({super.key, required this.group});

  @override
  ConsumerState<SplitGroupDetailScreen> createState() =>
      _SplitGroupDetailScreenState();
}

class _SplitGroupDetailScreenState
    extends ConsumerState<SplitGroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(
      splitGroupMembersProvider(widget.group.id),
    );
    final expensesAsync = ref.watch(
      splitGroupExpensesProvider(widget.group.id),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassScaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.narutoOrange,
          labelColor: AppTheme.narutoOrange,
          unselectedLabelColor: isDark
              ? Colors.white.withOpacity(0.6)
              : Colors.black.withOpacity(0.5),
          tabs: const [
            Tab(text: 'Expenses'),
            Tab(text: 'Balances'),
          ],
        ),
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (members) => TabBarView(
          controller: _tabController,
          children: [
            // ── Expenses tab ──────────────────────────────────────────────
            expensesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (expenses) => _ExpensesTab(
                group: widget.group,
                members: members,
                expenses: expenses,
              ),
            ),
            // ── Balances tab ──────────────────────────────────────────────
            _BalancesTab(group: widget.group, members: members),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.neonGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.narutoOrange.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: () {
            final members = ref
                .read(splitGroupMembersProvider(widget.group.id))
                .valueOrNull;
            if (members == null || members.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Add members to the group first'),
                ),
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddSplitExpenseScreen(
                  groupId: widget.group.id,
                  members: members,
                ),
              ),
            );
          },
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Expenses tab
// ---------------------------------------------------------------------------

class _ExpensesTab extends ConsumerWidget {
  final SplitGroup group;
  final List<SplitMember> members;
  final List<SplitExpense> expenses;

  const _ExpensesTab({
    required this.group,
    required this.members,
    required this.expenses,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (expenses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: 56,
                color: AppTheme.narutoOrange.withOpacity(0.6),
              ),
              const SizedBox(height: 16),
              Text(
                'No expenses yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the + button to add your first expense',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final memberMap = {for (final m in members) m.id: m.name};

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: expenses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 2),
      itemBuilder: (context, i) {
        final exp = expenses[i];
        return _ExpenseCard(
          expense: exp,
          paidByName: memberMap[exp.paidByMemberId] ?? 'Unknown',
          onDelete: () async {
            final confirmed = await _confirmDelete(context);
            if (confirmed) {
              await ref.read(splitServiceProvider).deleteExpense(exp.id);
            }
          },
        );
      },
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Expense'),
            content: const Text('Remove this expense from the group?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _ExpenseCard extends StatelessWidget {
  final SplitExpense expense;
  final String paidByName;
  final VoidCallback onDelete;

  const _ExpenseCard({
    required this.expense,
    required this.paidByName,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.07)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.narutoOrange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.receipt_rounded,
              color: AppTheme.narutoOrange,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Paid by $paidByName  •  '
                  '${expense.date.day}/${expense.date.month}/${expense.date.year}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${expense.amount.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.narutoOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onDelete,
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: Colors.red.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Balances tab
// ---------------------------------------------------------------------------

class _BalancesTab extends ConsumerWidget {
  final SplitGroup group;
  final List<SplitMember> members;

  const _BalancesTab({required this.group, required this.members});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<MemberBalance>>(
      future: ref.read(splitServiceProvider).calculateBalances(group.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final balances = snapshot.data ?? [];
        final debts = ref
            .read(splitServiceProvider)
            .simplifyDebts(balances);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // ── Net balances ──────────────────────────────────────────────
            _SectionHeader(title: 'Net Balances'),
            const SizedBox(height: 8),
            ...balances.map((b) => _BalanceCard(balance: b)),
            const SizedBox(height: 20),

            // ── Who owes who ──────────────────────────────────────────────
            _SectionHeader(title: 'Suggested Settlements'),
            const SizedBox(height: 8),
            if (debts.isEmpty)
              const _AllSettledCard()
            else
              ...debts.map((d) => _DebtCard(debt: d)),
            const SizedBox(height: 20),

            // ── Settle up button ──────────────────────────────────────────
            ElevatedButton.icon(
              onPressed: () => _showSettleUpSheet(context, debts),
              icon: const Icon(Icons.handshake_rounded),
              label: const Text('Settle Up'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.leafGreen,
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSettleUpSheet(BuildContext context, List<DebtSummary> debts) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1A1A2E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SettleUpSheet(
        groupId: group.id,
        members: members,
        debts: debts,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleSmall);
  }
}

class _BalanceCard extends StatelessWidget {
  final MemberBalance balance;

  const _BalanceCard({required this.balance});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPositive = balance.netBalance > 0;
    final isZero = balance.netBalance.abs() < 0.005;
    final color = isZero
        ? Colors.grey
        : (isPositive ? AppTheme.leafGreen : AppTheme.kuramaRed);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                balance.memberName[0].toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              balance.memberName,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isZero
                    ? 'Settled'
                    : (isPositive
                          ? '+₹${balance.netBalance.abs().toStringAsFixed(2)}'
                          : '-₹${balance.netBalance.abs().toStringAsFixed(2)}'),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Text(
                isZero
                    ? ''
                    : (isPositive ? 'gets back' : 'owes'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  final DebtSummary debt;

  const _DebtCard({required this.debt});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium,
                children: [
                  TextSpan(
                    text: debt.fromName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' pays '),
                  TextSpan(
                    text: debt.toName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          Text(
            '₹${debt.amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: AppTheme.kuramaRed,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _AllSettledCard extends StatelessWidget {
  const _AllSettledCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.leafGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppTheme.leafGreen),
          const SizedBox(width: 12),
          Text(
            'Everyone is settled up! 🎉',
            style: TextStyle(
              color: AppTheme.leafGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
