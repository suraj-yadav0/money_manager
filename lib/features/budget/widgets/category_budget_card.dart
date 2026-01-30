import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/icon_helper.dart';
import '../providers/budget_provider.dart';

/// Card showing budget progress for a single category
class CategoryBudgetCard extends StatelessWidget {
  final CategoryBudgetStats stats;
  final VoidCallback? onEdit;

  const CategoryBudgetCard({super.key, required this.stats, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final statusColor = _getStatusColor();

    return Card(
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // Category icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      IconHelper.getIcon(stats.icon),
                      color: statusColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Category name and amounts
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stats.name, style: theme.textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          '${Formatters.currency(stats.spent)} of ${Formatters.currency(stats.budget)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  // Remaining / Over amount
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        stats.isOverBudget
                            ? '-${Formatters.currency(stats.spent - stats.budget)}'
                            : Formatters.currency(stats.remaining),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                      Text(
                        stats.isOverBudget ? 'over' : 'left',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (stats.percentUsed / 100).clamp(0.0, 1.0),
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(statusColor),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    if (stats.isOverBudget) return AppTheme.danger;
    if (stats.isNearLimit) return AppTheme.caution;
    return AppTheme.safe;
  }
}
