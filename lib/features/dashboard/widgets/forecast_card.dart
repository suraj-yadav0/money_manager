import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/formatters.dart';
import '../providers/dashboard_providers.dart';

/// Forecast card showing projected month-end balance
class ForecastCard extends ConsumerWidget {
  const ForecastCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return statsAsync.when(
      loading: () => const SizedBox(height: 100),
      error: (error, stack) => const SizedBox(),
      data: (stats) {
        final statusColor = _getStatusColor(stats.forecastStatus);
        final statusIcon = _getStatusIcon(stats.forecastStatus);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Month-End Forecast',
                            style: theme.textTheme.bodySmall,
                          ),
                          Text(
                            stats.forecastStatus.label,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Formatters.currency(stats.projectedBalance),
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        Text(
                          '${stats.daysRemaining} days left',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _getProgress(stats),
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(statusColor),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStat(
                      context,
                      'Daily Burn',
                      Formatters.currency(stats.dailyBurnRate),
                    ),
                    _buildStat(
                      context,
                      'Projected Spend',
                      Formatters.currency(
                        stats.dailyBurnRate * stats.daysRemaining,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStat(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Color _getStatusColor(ForecastStatus status) {
    switch (status) {
      case ForecastStatus.safe:
        return AppTheme.safe;
      case ForecastStatus.caution:
        return AppTheme.caution;
      case ForecastStatus.deficit:
        return AppTheme.danger;
    }
  }

  IconData _getStatusIcon(ForecastStatus status) {
    switch (status) {
      case ForecastStatus.safe:
        return Icons.check_circle_outline;
      case ForecastStatus.caution:
        return Icons.warning_amber_rounded;
      case ForecastStatus.deficit:
        return Icons.error_outline;
    }
  }

  double _getProgress(DashboardStats stats) {
    if (stats.totalIncome <= 0) return 0;
    final spent = stats.totalExpenses / stats.totalIncome;
    return spent.clamp(0.0, 1.0);
  }
}
