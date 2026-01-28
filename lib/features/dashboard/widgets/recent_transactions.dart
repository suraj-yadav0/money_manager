import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../transactions/screens/add_transaction_screen.dart';
import '../providers/dashboard_providers.dart';

/// Recent transactions list widget
class RecentTransactions extends ConsumerWidget {
  const RecentTransactions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(recentTransactionsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return transactionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
      data: (transactions) {
        if (transactions.isEmpty) {
          return Card(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 48,
                    color: colorScheme.onSurfaceVariant.withAlpha(100),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No transactions yet',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap the + button to add your first expense',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          child: Column(
            children: transactions.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isLast = index == transactions.length - 1;
              final isExpense = item.transaction.type == 'expense';

              return Column(
                children: [
                  Dismissible(
                    key: Key(item.transaction.id.toString()),
                    direction: DismissDirection.horizontal,
                    background: Container(
                      color: colorScheme.error,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 24),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    secondaryBackground: Container(
                      color: AppTheme.success,
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
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                AddTransactionScreen(transactionToEdit: item),
                          ),
                        );
                      },
                      onLongPress: () async {
                        final confirmed = await _showDeleteConfirmation(
                          context,
                        );
                        if (confirmed == true && context.mounted) {
                          _deleteTransaction(context, ref, item);
                        }
                      },
                      child: ListTile(
                        leading: Container(
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
                            color: isExpense
                                ? colorScheme.error
                                : AppTheme.success,
                            size: 22,
                          ),
                        ),
                        title: Text(
                          item.category?.name ?? 'Unknown',
                          style: theme.textTheme.titleSmall,
                        ),
                        subtitle: Text(
                          [
                            item.transaction.note?.isNotEmpty == true
                                ? item.transaction.note!
                                : Formatters.relativeDate(
                                    item.transaction.timestamp,
                                  ),
                            if (item.transaction.paymentMode != null)
                              item.transaction.paymentMode!,
                          ].join(' • '),
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          '${isExpense ? '-' : '+'}${Formatters.currency(item.transaction.amount)}',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isExpense
                                ? colorScheme.error
                                : AppTheme.success,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 72,
                      endIndent: 16,
                      color: colorScheme.outlineVariant.withAlpha(50),
                    ),
                ],
              );
            }).toList(),
          ),
        );
      },
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
        content: const Text(
          'Are you sure you want to delete this transaction?',
        ),
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
    await (db.delete(
      db.transactions,
    )..where((t) => t.id.equals(item.transaction.id))).go();

    // Refresh dashboard
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(recentTransactionsProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Transaction deleted')));
    }
  }
}
