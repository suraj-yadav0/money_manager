import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/presentation/glass_widgets.dart';
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

    final statusColor = _getStatusColor();

    return GlassContainer(
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
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
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusColor.withOpacity(0.3),
                        width: 1,
                      ),
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
                        Text(
                          stats.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
                        style: GoogleFonts.outfit(
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
                  backgroundColor: theme.brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
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
