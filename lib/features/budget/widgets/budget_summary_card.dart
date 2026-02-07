import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/presentation/glass_widgets.dart';
import '../../../core/utils/formatters.dart';
import '../providers/budget_provider.dart';

/// Summary card showing total budget overview
class BudgetSummaryCard extends StatelessWidget {
  final BudgetStats stats;

  const BudgetSummaryCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final statusColor = _getStatusColor();
    final statusLabel = _getStatusLabel();

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
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
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: statusColor.withOpacity(0.5),
                    width: 1.5,
                  ),
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
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${Formatters.currency(stats.totalSpent)} / ${Formatters.currency(stats.totalBudget)}',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (stats.percentUsed / 100).clamp(0.0, 1.0),
              backgroundColor: theme.brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              valueColor: AlwaysStoppedAnimation(statusColor),
              minHeight: 12,
            ),
          ),

          const SizedBox(height: 24),

          // Stats row
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: 'Remaining',
                  value: Formatters.currency(
                    stats.totalRemaining.clamp(0, double.infinity),
                  ),
                  color: stats.isOverBudget
                      ? AppTheme.kuramaRed
                      : AppTheme.leafGreen,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: theme.dividerColor.withOpacity(0.2),
              ),
              Expanded(
                child: _StatItem(
                  label: 'Daily Limit',
                  value: Formatters.currency(
                    stats.dailyAllowance.clamp(0, double.infinity),
                  ),
                  color: stats.dailyAllowance < 0 ? AppTheme.kuramaRed : null,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: theme.dividerColor.withOpacity(0.2),
              ),
              Expanded(
                child: _StatItem(
                  label: 'Days Left',
                  value: '${stats.daysRemaining}',
                  color: AppTheme.narutoOrange,
                ),
              ),
            ],
          ),
        ],
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
