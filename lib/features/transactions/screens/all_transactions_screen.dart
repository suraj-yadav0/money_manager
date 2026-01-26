import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/icon_helper.dart';

import '../../../core/providers/app_state_provider.dart';
import 'add_transaction_screen.dart';
import '../../dashboard/providers/dashboard_providers.dart';

class AllTransactionsScreen extends ConsumerWidget {
  const AllTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(allTransactionsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'All Transactions',
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
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: colorScheme.onSurfaceVariant.withAlpha(100),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No transactions found',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          // Group transactions by date
          final grouped = <String, List<TransactionWithCategory>>{};
          for (var item in transactions) {
            final dateKey = Formatters.date(item.transaction.timestamp);
            if (!grouped.containsKey(dateKey)) {
              grouped[dateKey] = [];
            }
            grouped[dateKey]!.add(item);
          }

          return RefreshIndicator(
            onRefresh: () async {
              // Invalidate the provider to force a refresh from the database
              // Since it's a stream, it technically updates automatically,
              // but this ensures we catch any manual changes or external updates if any.
              // However, for a StreamProvider, 'invalidate' usually restarts the stream.
              ref.invalidate(allTransactionsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: grouped.length,
              itemBuilder: (context, index) {
                final dateKey = grouped.keys.elementAt(index);
                final items = grouped[dateKey]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _getDateHeader(dateKey),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: items.asMap().entries.map((entry) {
                          final itemIndex = entry.key;
                          final item = entry.value;
                          final isLast = itemIndex == items.length - 1;
                          final isExpense = item.transaction.type == 'expense';

                          return Column(
                            children: [
                              InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AddTransactionScreen(
                                        transactionToEdit: item,
                                      ),
                                    ),
                                  );
                                },
                                onLongPress: () =>
                                    _confirmDelete(context, ref, item),
                                child: ListTile(
                                  leading: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: isExpense
                                          ? colorScheme.errorContainer
                                                .withAlpha(100)
                                          : AppTheme.success.withAlpha(30),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      IconHelper.getIcon(item.category?.icon),
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
                                    item.transaction.note?.isNotEmpty == true
                                        ? item.transaction.note!
                                        : Formatters.relativeDate(
                                            item.transaction.timestamp,
                                          ),
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
                              if (!isLast)
                                Divider(
                                  height: 1,
                                  indent: 72,
                                  endIndent: 16,
                                  color: colorScheme.outlineVariant.withAlpha(
                                    50,
                                  ),
                                ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _getDateHeader(String dateStr) {
    if (dateStr == Formatters.date(DateTime.now())) {
      return 'Today';
    } else if (dateStr ==
        Formatters.date(DateTime.now().subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return dateStr;
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TransactionWithCategory item,
  ) async {
    final confirmed = await showDialog<bool>(
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

    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      await (db.delete(
        db.transactions,
      )..where((t) => t.id.equals(item.transaction.id))).go();

      // Refresh dashboard (and this list via stream)
      ref.invalidate(dashboardStatsProvider);
      // allTransactionsProvider is auto-refreshed as it's a stream

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transaction deleted')));
      }
    }
  }
}
