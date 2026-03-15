import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../providers/dashboard_providers.dart';

/// Shows a modal bottom sheet with all transactions matching [params].
///
/// Pass [color] to tint the header accent strip (matches the chart segment colour).
void showChartDrillDown(
  BuildContext context, {
  required DrillDownParams params,
  String? title,
  Color? color,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChartDrillDownSheet(
      params: params,
      title: title,
      accentColor: color,
    ),
  );
}

/// A draggable bottom sheet that displays individual transactions for a
/// chart segment (category or specific day).
class ChartDrillDownSheet extends ConsumerWidget {
  final DrillDownParams params;
  final String? title;
  final Color? accentColor;

  const ChartDrillDownSheet({
    super.key,
    required this.params,
    this.title,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = accentColor ?? colorScheme.primary;

    final transactionsAsync = ref.watch(
      drillDownTransactionsProvider(params),
    );

    final sheetTitle = _resolveTitle();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              _DragHandle(color: colorScheme.onSurfaceVariant),
              // Header
              _SheetHeader(
                title: sheetTitle,
                accent: accent,
                transactionsAsync: transactionsAsync,
                transactionType: params.transactionType,
              ),
              const Divider(height: 1),
              // Transaction list
              Expanded(
                child: transactionsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      'Failed to load transactions',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  data: (transactions) {
                    if (transactions.isEmpty) {
                      return _EmptyState(
                        transactionType: params.transactionType,
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: transactions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        return _TransactionTile(
                          item: transactions[index],
                          accentColor: accent,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _resolveTitle() {
    if (title != null) return title!;
    if (params.categoryName != null) return params.categoryName!;
    if (params.date != null) return Formatters.date(params.date!);
    return params.transactionType == 'expense' ? 'Expenses' : 'Income';
  }
}

// ─── Private helper widgets ──────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  final Color color;
  const _DragHandle({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: color.withAlpha(80),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String title;
  final Color accent;
  final AsyncValue<List<TransactionWithCategory>> transactionsAsync;
  final String transactionType;

  const _SheetHeader({
    required this.title,
    required this.accent,
    required this.transactionsAsync,
    required this.transactionType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (total, count) = transactionsAsync.when(
      data: (txns) {
        final sum = txns.fold<double>(0, (s, t) => s + t.transaction.amount);
        return (sum, txns.length);
      },
      loading: () => (0.0, 0),
      error: (_, __) => (0.0, 0),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Row(
        children: [
          // Accent colour indicator
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (count > 0)
                  Text(
                    '$count transaction${count == 1 ? '' : 's'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (total > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Formatters.currency(total),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: transactionType == 'expense'
                        ? AppTheme.kuramaRed
                        : AppTheme.leafGreen,
                  ),
                ),
                Text(
                  'total',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String transactionType;
  const _EmptyState({required this.transactionType});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            transactionType == 'expense'
                ? Icons.receipt_long_outlined
                : Icons.account_balance_wallet_outlined,
            size: 56,
            color: colorScheme.onSurfaceVariant.withAlpha(100),
          ),
          const SizedBox(height: 16),
          Text(
            'No transactions found',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final TransactionWithCategory item;
  final Color accentColor;

  const _TransactionTile({required this.item, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tx = item.transaction;
    final category = item.category;

    final label = (tx.note != null && tx.note!.isNotEmpty)
        ? tx.note!
        : (category?.name ?? 'Transaction');

    final subtitle = StringBuffer();
    subtitle.write(Formatters.dateTime(tx.timestamp));
    if (tx.paymentMode != null && tx.paymentMode!.isNotEmpty) {
      subtitle.write(' · ${tx.paymentMode}');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // Category icon circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accentColor.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _iconForCategory(category?.icon),
              size: 20,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle.toString(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            Formatters.currency(tx.amount),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: tx.type == 'expense' ? AppTheme.kuramaRed : AppTheme.leafGreen,
            ),
          ),
        ],
      ),
    );
  }

  /// Map a stored icon name string to a Flutter [IconData].
  IconData _iconForCategory(String? iconName) {
    if (iconName == null || iconName.isEmpty) return Icons.label_outline;
    // The app stores icon names as strings; parse common ones.
    const iconMap = <String, IconData>{
      'restaurant': Icons.restaurant,
      'directions_car': Icons.directions_car,
      'shopping_cart': Icons.shopping_cart,
      'shopping_bag': Icons.shopping_bag,
      'movie': Icons.movie,
      'bolt': Icons.bolt,
      'receipt_long': Icons.receipt_long,
      'local_hospital': Icons.local_hospital,
      'school': Icons.school,
      'self_improvement': Icons.self_improvement,
      'spa': Icons.spa,
      'local_grocery_store': Icons.local_grocery_store,
      'card_giftcard': Icons.card_giftcard,
      'savings': Icons.savings,
      'trending_up': Icons.trending_up,
      'show_chart': Icons.show_chart,
      'attach_money': Icons.attach_money,
      'family_restroom': Icons.family_restroom,
      'work': Icons.work,
      'laptop': Icons.laptop,
      'account_balance_wallet': Icons.account_balance_wallet,
      'more_horiz': Icons.more_horiz,
    };
    return iconMap[iconName] ?? Icons.label_outline;
  }
}
