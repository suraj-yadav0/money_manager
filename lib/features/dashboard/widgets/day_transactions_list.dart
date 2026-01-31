import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../transactions/screens/add_transaction_screen.dart';
import '../providers/dashboard_providers.dart';
import '../providers/calendar_providers.dart';

/// Widget to display transactions for the selected day in calendar view
class DayTransactionsList extends ConsumerWidget {
  const DayTransactionsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(selectedDayTransactionsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return transactionsAsync.when(
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
                  size: 48,
                  color: colorScheme.onSurfaceVariant.withAlpha(100),
                ),
                const SizedBox(height: 12),
                Text(
                  'No transactions',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'No expenses or income recorded for this day',
                  style: theme.textTheme.bodySmall,
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
            // Day summary
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withAlpha(50),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem(
                    context,
                    'Income',
                    dayIncome,
                    AppTheme.success,
                    Icons.arrow_upward,
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: colorScheme.outlineVariant.withAlpha(100),
                  ),
                  _buildSummaryItem(
                    context,
                    'Expenses',
                    dayExpenses,
                    colorScheme.error,
                    Icons.arrow_downward,
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: colorScheme.outlineVariant.withAlpha(100),
                  ),
                  _buildSummaryItem(
                    context,
                    'Net',
                    dayIncome - dayExpenses,
                    dayIncome >= dayExpenses ? AppTheme.success : colorScheme.error,
                    dayIncome >= dayExpenses ? Icons.trending_up : Icons.trending_down,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Transactions list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final item = transactions[index];
                  final isExpense = item.transaction.type == 'expense';

                  return Dismissible(
                    key: Key('calendar_tx_${item.transaction.id}'),
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
                        // Edit action
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AddTransactionScreen(transactionToEdit: item),
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
                              builder: (_) => AddTransactionScreen(transactionToEdit: item),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Category icon
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isExpense
                                      ? colorScheme.errorContainer.withAlpha(100)
                                      : AppTheme.success.withAlpha(30),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _getCategoryIcon(item.category?.icon),
                                  color: isExpense ? colorScheme.error : AppTheme.success,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.category?.name ?? 'Unknown',
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      [
                                        Formatters.time(item.transaction.timestamp),
                                        if (item.transaction.note?.isNotEmpty == true)
                                          item.transaction.note!,
                                        if (item.transaction.paymentMode != null)
                                          item.transaction.paymentMode!,
                                      ].join(' • '),
                                      style: theme.textTheme.bodySmall?.copyWith(
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
                                  color: isExpense ? colorScheme.error : AppTheme.success,
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
    );
  }

  Widget _buildSummaryItem(
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
          mainAxisSize: MainAxisSize.min,
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
        const SizedBox(height: 4),
        Text(
          Formatters.compactCurrency(amount.abs()),
          style: GoogleFonts.outfit(
            fontSize: 14,
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
        content: const Text('Are you sure you want to delete this transaction?'),
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

    // Refresh calendar data
    ref.invalidate(selectedDayTransactionsProvider);
    ref.invalidate(calendarDailySummariesProvider);
    ref.invalidate(calendarMonthTotalsProvider);
    ref.invalidate(dashboardStatsProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction deleted')),
      );
    }
  }
}
