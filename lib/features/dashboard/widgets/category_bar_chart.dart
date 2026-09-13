import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../providers/dashboard_providers.dart';
import 'chart_drilldown_sheet.dart';

/// Horizontal bar chart showing spending or income by category.
/// Tapping a bar opens a drill-down sheet with individual transactions.
class CategoryBarChart extends ConsumerWidget {
  final String transactionType;
  final bool wrapInCard;

  const CategoryBarChart({
    super.key,
    this.transactionType = 'expense',
    this.wrapInCard = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return statsAsync.when(
      loading: () => const SizedBox(height: 200),
      error: (error, stack) => const SizedBox(),
      data: (stats) {
        final data = transactionType == 'expense'
            ? stats.categoryBreakdown
            : stats.incomeCategoryBreakdown;

        if (data.isEmpty) {
          final emptyView = Container(
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
                  transactionType == 'expense'
                      ? 'No expenses yet'
                      : 'No income yet',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  transactionType == 'expense'
                      ? 'Add your first expense to see the breakdown'
                      : 'Add your first income to see the breakdown',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
          if (wrapInCard) {
            return Card(child: emptyView);
          }
          return emptyView;
        }

        final entries = data.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final maxValue = entries.first.value;
        // Show all entries, sorted by value
        final displayEntries = entries;
        final range = ref.read(dateRangeProvider);

        final chartContent = LayoutBuilder(
              builder: (context, constraints) {
                final contentWidth = (displayEntries.length * 64.0).clamp(
                  0.0,
                  5000.0,
                );
                final chartWidth = constraints.maxWidth > contentWidth
                    ? constraints.maxWidth
                    : contentWidth;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 350,
                        width: chartWidth, // Dynamic width
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: maxValue * 1.2,
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipItem:
                                    (group, groupIndex, rod, rodIndex) {
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
                              touchCallback: (event, response) {
                                if (event is FlTapUpEvent) {
                                  final groupIndex =
                                      response?.spot?.touchedBarGroupIndex ?? -1;
                                  if (groupIndex >= 0 &&
                                      groupIndex < displayEntries.length) {
                                    final entry = displayEntries[groupIndex];
                                    final color = AppTheme.categoryColors[
                                        groupIndex %
                                            AppTheme.categoryColors.length];
                                    showChartDrillDown(
                                      context,
                                      params: DrillDownParams(
                                        categoryName: entry.key,
                                        start: range.start,
                                        end: range.end,
                                        transactionType: transactionType,
                                      ),
                                      title: entry.key,
                                      color: color,
                                    );
                                  }
                                }
                              },
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 60,
                                  // Calculate interval to show ~5 labels max prevents overlap
                                  interval: maxValue > 0 ? maxValue / 4 : 1.0,
                                  getTitlesWidget: (value, meta) {
                                    if (value == 0) return const SizedBox();
                                    return Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Text(
                                        Formatters.compactCurrency(value),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              fontSize: 10,
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                        overflow: TextOverflow.visible,
                                        softWrap: false,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 60,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    if (index >= 0 &&
                                        index < displayEntries.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: SizedBox(
                                          width: 50,
                                          child: Text(
                                            displayEntries[index].key,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(fontSize: 10),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                          ),
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
                              drawVerticalLine: false,
                              drawHorizontalLine: true,
                              horizontalInterval: maxValue > 0
                                  ? maxValue / 4
                                  : 1.0,
                              getDrawingHorizontalLine: (value) => FlLine(
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
                                    width: 24, // Slightly wider bars
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
                      // Tap hint
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.touch_app_outlined,
                              size: 14,
                              color: colorScheme.onSurfaceVariant.withAlpha(150),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Tap a bar for details',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant.withAlpha(150),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );

        if (wrapInCard) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: chartContent,
            ),
          );
        }
        return chartContent;
      },
    );
  }
}
