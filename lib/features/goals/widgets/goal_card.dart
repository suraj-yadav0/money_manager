import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/database/database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

/// Reusable goal card widget showing progress and quick actions
class GoalCard extends StatelessWidget {
  final Goal goal;
  final VoidCallback? onTap;
  final VoidCallback? onAddContribution;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool showActions;

  const GoalCard({
    super.key,
    required this.goal,
    this.onTap,
    this.onAddContribution,
    this.onEdit,
    this.onDelete,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = goal.savedAmount / goal.targetAmount;
    final daysRemaining = goal.deadline.difference(DateTime.now()).inDays;

    final isCompleted = goal.isCompleted || progress >= 1.0;
    final isOnTrack =
        isCompleted ||
        progress >=
            (1 -
                daysRemaining /
                    goal.deadline.difference(goal.createdAt).inDays);

    final statusColor = isCompleted
        ? AppTheme.success
        : (isOnTrack ? colorScheme.primary : AppTheme.warning);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isCompleted ? Icons.check_circle : Icons.flag,
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.name,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          isCompleted
                              ? 'Goal completed!'
                              : daysRemaining > 0
                              ? '$daysRemaining days left'
                              : 'Overdue',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isCompleted
                                ? AppTheme.success
                                : (daysRemaining > 0
                                      ? colorScheme.onSurfaceVariant
                                      : AppTheme.danger),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showActions) ...[
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            onEdit?.call();
                          case 'delete':
                            onDelete?.call();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 20),
                              SizedBox(width: 8),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              // Amount row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Formatters.currency(goal.savedAmount),
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      Text(
                        'of ${Formatters.currency(goal.targetAmount)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Progress bar with milestones
              _ProgressBarWithMilestones(
                progress: progress.clamp(0.0, 1.0),
                color: statusColor,
              ),
              if (showActions && !isCompleted) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: onAddContribution,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Contribution'),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        textStyle: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Progress bar with milestone markers at 25%, 50%, 75%
class _ProgressBarWithMilestones extends StatelessWidget {
  final double progress;
  final Color color;

  const _ProgressBarWithMilestones({
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background track
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          // Progress fill
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
          // Milestone markers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [0.25, 0.5, 0.75].map((milestone) {
              final reached = progress >= milestone;
              return Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: reached ? color : colorScheme.surfaceContainerHighest,
                  border: Border.all(
                    color: reached ? color : colorScheme.outline,
                    width: 2,
                  ),
                  shape: BoxShape.circle,
                ),
                child: reached
                    ? const Icon(Icons.check, size: 10, color: Colors.white)
                    : null,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
