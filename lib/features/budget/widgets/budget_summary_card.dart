import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../providers/budget_provider.dart';

/// Summary card showing total budget overview
class BudgetSummaryCard extends StatelessWidget {
  final BudgetStats stats;

  const BudgetSummaryCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final statusColor = _getStatusColor();
    final statusLabel = _getStatusLabel();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Main stats row
            Row(
              children: [
                // Status icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    stats.isOverBudget
                        ? Icons.warning_rounded
                        : Icons.account_balance_wallet,
                    color: statusColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                // Budget info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusLabel,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${Formatters.currency(stats.totalSpent)} / ${Formatters.currency(stats.totalBudget)}',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (stats.percentUsed / 100).clamp(0.0, 1.0),
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(statusColor),
                minHeight: 10,
              ),
            ),

            const SizedBox(height: 20),

            // Stats row
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    label: 'Remaining',
                    value: Formatters.currency(
                      stats.totalRemaining.clamp(0, double.infinity),
                    ),
                    color: stats.isOverBudget ? colorScheme.error : null,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: colorScheme.outlineVariant.withAlpha(100),
                ),
                Expanded(
                  child: _StatItem(
                    label: 'Daily Allowance',
                    value: Formatters.currency(
                      stats.dailyAllowance.clamp(0, double.infinity),
                    ),
                    color: stats.dailyAllowance < 0 ? colorScheme.error : null,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: colorScheme.outlineVariant.withAlpha(100),
                ),
                Expanded(
                  child: _StatItem(
                    label: 'Days Left',
                    value: '${stats.daysRemaining}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    if (stats.isOverBudget) return AppTheme.danger;
    if (stats.percentUsed >= 80) return AppTheme.caution;
    return AppTheme.safe;
  }

  String _getStatusLabel() {
    if (stats.isOverBudget) return 'Over Budget!';
    if (stats.percentUsed >= 90) return 'Almost at limit';
    if (stats.percentUsed >= 80) return 'Approaching limit';
    if (stats.percentUsed >= 50) return 'On track';
    return 'Under budget';
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatItem({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
