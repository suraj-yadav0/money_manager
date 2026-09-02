import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/firebase_config.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../transactions/screens/add_transaction_screen.dart';
import '../providers/dashboard_providers.dart';
import '../providers/calendar_providers.dart';

/// Screen to display transactions for a specific day
class DayTransactionsScreen extends ConsumerWidget {
  final DateTime date;

  const DayTransactionsScreen({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Set the selected day provider to this date
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(calendarSelectedDayProvider.notifier).state = date;
    });

    final transactionsAsync = ref.watch(selectedDayTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          Formatters.date(date),
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (transactions) {
          if (transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_available,
                    size: 64,
                    color: colorScheme.onSurfaceVariant.withAlpha(100),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No transactions',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No expenses or income recorded for this day',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant.withAlpha(150),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Calculate day totals
          double dayIncome = 0;
          double dayExpenses = 0;
          for (final item in transactions) {
            if (item.transaction.type == 'income') {
              dayIncome += item.transaction.amount;
            } else {
              dayExpenses += item.transaction.amount;
            }
          }

          return Column(
            children: [
              // Day summary card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withAlpha(50),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSummaryColumn(
                        context,
                        'Income',
                        dayIncome,
                        AppTheme.success,
                        Icons.arrow_upward,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 50,
                      color: colorScheme.outlineVariant.withAlpha(100),
                    ),
                    Expanded(
                      child: _buildSummaryColumn(
                        context,
                        'Expenses',
                        dayExpenses,
                        colorScheme.error,
                        Icons.arrow_downward,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 50,
                      color: colorScheme.outlineVariant.withAlpha(100),
                    ),
                    Expanded(
                      child: _buildSummaryColumn(
                        context,
                        'Net',
                        dayIncome - dayExpenses,
                        dayIncome >= dayExpenses
                            ? AppTheme.success
                            : colorScheme.error,
                        dayIncome >= dayExpenses
                            ? Icons.trending_up
                            : Icons.trending_down,
                      ),
                    ),
                  ],
                ),
              ),

              // Section header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Text(
                      'Transactions',
                      style: theme.textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Text(
                      '${transactions.length} items',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Transactions list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final item = transactions[index];
                    final isExpense = item.transaction.type == 'expense';

                    return Dismissible(
                      key: Key('day_tx_${item.transaction.id}'),
                      direction: DismissDirection.horizontal,
                      background: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.error,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 24),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      secondaryBackground: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.success,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        child: const Icon(Icons.edit, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          return await _showDeleteConfirmation(context);
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  AddTransactionScreen(transactionToEdit: item),
                            ),
                          );
                          return false;
                        }
                      },
                      onDismissed: (direction) {
                        if (direction == DismissDirection.startToEnd) {
                          _deleteTransaction(context, ref, item);
                        }
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AddTransactionScreen(
                                    transactionToEdit: item),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Category icon
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: isExpense
                                        ? colorScheme.errorContainer
                                            .withAlpha(100)
                                        : AppTheme.success.withAlpha(30),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _getCategoryIcon(item.category?.icon),
                                    color: isExpense
                                        ? colorScheme.error
                                        : AppTheme.success,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.category?.name ?? 'Unknown',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        [
                                          Formatters.time(
                                              item.transaction.timestamp),
                                          if (item.transaction.note
                                                  ?.isNotEmpty ==
                                              true)
                                            item.transaction.note!,
                                          if (item.transaction.paymentMode !=
                                              null)
                                            item.transaction.paymentMode!,
                                        ].join(' • '),
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),

                                // Amount
                                Text(
                                  '${isExpense ? '-' : '+'}${Formatters.currency(item.transaction.amount)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isExpense
                                        ? colorScheme.error
                                        : AppTheme.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryColumn(
    BuildContext context,
    String label,
    double amount,
    Color color,
    IconData icon,
  ) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          Formatters.compactCurrency(amount.abs()),
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String? iconName) {
    final iconMap = {
      'restaurant': Icons.restaurant,
      'directions_car': Icons.directions_car,
      'shopping_bag': Icons.shopping_bag,
      'movie': Icons.movie,
      'receipt_long': Icons.receipt_long,
      'local_hospital': Icons.local_hospital,
      'school': Icons.school,
      'spa': Icons.spa,
      'local_grocery_store': Icons.local_grocery_store,
      'more_horiz': Icons.more_horiz,
      'work': Icons.work,
      'laptop': Icons.laptop,
      'trending_up': Icons.trending_up,
      'attach_money': Icons.attach_money,
      'card_giftcard': Icons.card_giftcard,
      'savings': Icons.savings,
      'show_chart': Icons.show_chart,
      'family_restroom': Icons.family_restroom,
    };
    return iconMap[iconName] ?? Icons.receipt;
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content:
            const Text('Are you sure you want to delete this transaction?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTransaction(
    BuildContext context,
    WidgetRef ref,
    TransactionWithCategory item,
  ) async {
    final db = ref.read(databaseProvider);
    await (db.delete(db.transactions)
          ..where((t) => t.id.equals(item.transaction.id)))
        .go();

    // Delete directly from Firestore if cloud user
    final currentUser = FirebaseConfig.auth?.currentUser;
    if (currentUser != null && item.transaction.syncId != null) {
      FirebaseConfig.db
          ?.collection('users')
          .doc(currentUser.uid)
          .collection('transactions')
          .doc(item.transaction.syncId!)
          .delete()
          .catchError((e) {
            debugPrint('Error deleting transaction from Firestore: $e');
          });
    }

    // Refresh data
    ref.invalidate(selectedDayTransactionsProvider);
    ref.invalidate(calendarDailySummariesProvider);
    ref.invalidate(calendarMonthTotalsProvider);
    ref.invalidate(dashboardStatsProvider);

    // Trigger cloud sync
    if (currentUser != null) {
      ref.read(syncNotifierProvider.notifier).triggerSync();
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction deleted'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
