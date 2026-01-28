import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../providers/dashboard_providers.dart';

/// Horizontal bar chart showing spending by category
class CategoryBarChart extends ConsumerWidget {
  const CategoryBarChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return statsAsync.when(
      loading: () => const SizedBox(height: 200),
      error: (error, stack) => const SizedBox(),
      data: (stats) {
        if (stats.categoryBreakdown.isEmpty) {
          return Card(
            child: Container(
              height: 200,
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bar_chart,
                    size: 48,
                    color: colorScheme.onSurfaceVariant.withAlpha(100),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No expenses yet',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add your first expense to see the breakdown',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final entries = stats.categoryBreakdown.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final maxValue = entries.first.value;
        final displayEntries = entries.take(6).toList();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  height: displayEntries.length * 44.0,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxValue * 1.2,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              Formatters.currency(rod.toY),
                              GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 100,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < displayEntries.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text(
                                    displayEntries[index].key,
                                    style: theme.textTheme.bodySmall,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        drawHorizontalLine: false,
                        getDrawingVerticalLine: (value) => FlLine(
                          color: colorScheme.outlineVariant.withAlpha(50),
                          strokeWidth: 1,
                        ),
                      ),
                      barGroups: displayEntries.asMap().entries.map((e) {
                        final index = e.key;
                        final entry = e.value;
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value,
                              color:
                                  AppTheme.categoryColors[index %
                                      AppTheme.categoryColors.length],
                              width: 20,
                              borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(4),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                    duration: const Duration(milliseconds: 300),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
