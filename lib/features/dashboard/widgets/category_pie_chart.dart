import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/dashboard_providers.dart';

/// Category pie chart showing spending breakdown
class CategoryPieChart extends ConsumerWidget {
  const CategoryPieChart({super.key});

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
                    Icons.pie_chart_outline,
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
        final total = entries.fold<double>(0, (sum, e) => sum + e.value);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  height: 200,
                  child: Row(
                    children: [
                      // Pie Chart
                      Expanded(
                        flex: 3,
                        child: PieChart(
                          PieChartData(
                            sections: _buildSections(entries, total),
                            sectionsSpace: 2,
                            centerSpaceRadius: 35,
                            startDegreeOffset: -90,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Legend
                      Expanded(
                        flex: 4,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: entries
                              .take(5)
                              .toList()
                              .asMap()
                              .entries
                              .map((e) {
                                final index = e.key;
                                final entry = e.value;
                                final percentage = (entry.value / total * 100);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color:
                                              AppTheme.categoryColors[index %
                                                  AppTheme
                                                      .categoryColors
                                                      .length],
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          entry.key,
                                          style: theme.textTheme.bodySmall,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        '${percentage.toStringAsFixed(0)}%',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              })
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<PieChartSectionData> _buildSections(
    List<MapEntry<String, double>> entries,
    double total,
  ) {
    return entries.asMap().entries.map((e) {
      final index = e.key;
      final entry = e.value;
      final percentage = entry.value / total * 100;

      return PieChartSectionData(
        color: AppTheme.categoryColors[index % AppTheme.categoryColors.length],
        value: entry.value,
        title: percentage >= 10 ? '${percentage.toStringAsFixed(0)}%' : '',
        radius: 45,
        titleStyle: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }
}
