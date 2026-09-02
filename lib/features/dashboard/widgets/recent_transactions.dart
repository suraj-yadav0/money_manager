import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:drift/drift.dart' show Value;
import '../../../core/database/database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/presentation/glass_widgets.dart';
import '../../transactions/screens/add_transaction_screen.dart';
import '../providers/dashboard_providers.dart';

/// Fast, vibrant recent transactions list
class RecentTransactions extends ConsumerWidget {
  const RecentTransactions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(recentTransactionsProvider);
    final currencySymbol = ref.watch(currencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return transactionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
      data: (transactions) {
        if (transactions.isEmpty) {
          return GlassContainer(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 40,
                  color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight,
                ),
                const SizedBox(height: 12),
                Text(
                  'No recent activity',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap + to record your first transaction',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight,
                  ),
                ),
              ],
            ),
          );
        }

        return GlassContainer(
          padding: EdgeInsets.zero,
          child: Column(
            children: transactions.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isLast = index == transactions.length - 1;
              final isExpense = item.transaction.type == 'expense';
              final catColor = isExpense ? AppTheme.danger : AppTheme.success;

              return Column(
                children: [
                  Dismissible(
                    key: Key(item.transaction.id.toString()),
                    direction: DismissDirection.horizontal,
                    background: Container(
                      color: AppTheme.danger,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 20),
                      child: const Icon(Icons.delete_outline, color: Colors.white),
                    ),
                    secondaryBackground: Container(
                      color: AppTheme.narutoOrange,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.edit_outlined, color: Colors.white),
                    ),
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.startToEnd) {
                        return await _showDeleteConfirmation(context);
                      } else {
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
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AddTransactionScreen(transactionToEdit: item),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            // Category Icon Container with vibrant background
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: isDark ? 0.18 : 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getCategoryIcon(item.category?.icon),
                                color: catColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Note / Merchant & Subtitle
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.transaction.note?.isNotEmpty == true
                                        ? item.transaction.note!
                                        : (item.category?.name ?? 'General'),
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    [
                                      item.category?.name ?? 'Category',
                                      Formatters.relativeDate(item.transaction.timestamp),
                                      if (item.transaction.paymentMode != null)
                                        item.transaction.paymentMode!,
                                    ].join(' • '),
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Amount
                            Text(
                              '${isExpense ? '-' : '+'}${Formatters.currency(item.transaction.amount, symbol: currencySymbol)}',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isExpense ? AppTheme.danger : AppTheme.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 70,
                      endIndent: 16,
                      color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                    ),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Color? _parseColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return null;
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return null;
    }
  }

  IconData _getCategoryIcon(String? iconName) {
    final iconMap = {
      'restaurant': Icons.restaurant_rounded,
      'directions_car': Icons.directions_car_rounded,
      'shopping_bag': Icons.shopping_bag_outlined,
      'movie': Icons.movie_outlined,
      'receipt_long': Icons.receipt_long_outlined,
      'local_hospital': Icons.local_hospital_outlined,
      'school': Icons.school_outlined,
      'spa': Icons.spa_outlined,
      'local_grocery_store': Icons.local_grocery_store_outlined,
      'more_horiz': Icons.more_horiz_rounded,
      'work': Icons.work_outline_rounded,
      'laptop': Icons.laptop_mac_rounded,
      'trending_up': Icons.trending_up_rounded,
      'attach_money': Icons.attach_money_rounded,
      'card_giftcard': Icons.card_giftcard_rounded,
      'savings': Icons.savings_outlined,
      'show_chart': Icons.show_chart_rounded,
      'family_restroom': Icons.family_restroom_rounded,
    };
    return iconMap[iconName] ?? Icons.receipt_rounded;
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

    // Rollback bank account balance if linked
    if (item.transaction.accountId != null) {
      final acc = await (db.select(db.bankAccounts)
            ..where((a) => a.id.equals(item.transaction.accountId!)))
          .getSingleOrNull();
      if (acc != null) {
        final isExpense = item.transaction.type == 'expense';
        final restoredBal = isExpense
            ? acc.balance + item.transaction.amount
            : acc.balance - item.transaction.amount;
        await (db.update(db.bankAccounts)
              ..where((a) => a.id.equals(acc.id)))
            .write(BankAccountsCompanion(
          balance: Value(restoredBal),
          updatedAt: Value(DateTime.now()),
        ));
      }
    }

    // Delete locally
    await (db.delete(
      db.transactions,
    )..where((t) => t.id.equals(item.transaction.id))).go();

    // Delete remotely from Cloud Firestore
    if (item.transaction.syncId != null) {
      ref.read(syncServiceProvider).deleteRemoteDoc('transactions', item.transaction.syncId);
    }

    // Refresh dashboard
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(recentTransactionsProvider);

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
