import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/dashboard_providers.dart';
import 'chart_drilldown_sheet.dart';

/// Category pie chart showing spending or income breakdown.
/// Tapping a pie slice opens a drill-down sheet with individual transactions.
class CategoryPieChart extends ConsumerStatefulWidget {
  final String transactionType;
  final bool wrapInCard;

  const CategoryPieChart({
    super.key,
    this.transactionType = 'expense',
    this.wrapInCard = false,
  });

  @override
  ConsumerState<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends ConsumerState<CategoryPieChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return statsAsync.when(
      loading: () => const SizedBox(height: 200),
      error: (error, stack) => const SizedBox(),
      data: (stats) {
        final data = widget.transactionType == 'expense'
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
                  Icons.pie_chart_outline,
                  size: 48,
                  color: colorScheme.onSurfaceVariant.withAlpha(100),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.transactionType == 'expense'
                      ? 'No expenses yet'
                      : 'No income yet',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.transactionType == 'expense'
                      ? 'Add your first expense to see the breakdown'
                      : 'Add your first income to see the breakdown',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
          if (widget.wrapInCard) {
            return Card(child: emptyView);
          }
          return emptyView;
        }

        final entries = data.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final total = entries.fold<double>(0, (sum, e) => sum + e.value);
        final range = ref.read(dateRangeProvider);

        final chartContent = Column(
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
                            pieTouchData: PieTouchData(
                              touchCallback: (event, response) {
                                if (event is FlTapUpEvent) {
                                  final sectionIndex =
                                      response?.touchedSection
                                          ?.touchedSectionIndex ??
                                      -1;
                                  if (sectionIndex >= 0 &&
                                      sectionIndex < entries.length) {
                                    final entry = entries[sectionIndex];
                                    final color = AppTheme.categoryColors[
                                        sectionIndex %
                                            AppTheme.categoryColors.length];
                                    showChartDrillDown(
                                      context,
                                      params: DrillDownParams(
                                        categoryName: entry.key,
                                        start: range.start,
                                        end: range.end,
                                        transactionType:
                                            widget.transactionType,
                                      ),
                                      title: entry.key,
                                      color: color,
                                    );
                                  }
                                }
                                setState(() {
                                  _touchedIndex =
                                      response?.touchedSection
                                          ?.touchedSectionIndex ??
                                      -1;
                                });
                              },
                            ),
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
                                final color = AppTheme.categoryColors[
                                    index % AppTheme.categoryColors.length];
                                return GestureDetector(
                                  onTap: () => showChartDrillDown(
                                    context,
                                    params: DrillDownParams(
                                      categoryName: entry.key,
                                      start: range.start,
                                      end: range.end,
                                      transactionType: widget.transactionType,
                                    ),
                                    title: entry.key,
                                    color: color,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: color,
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
                                  ),
                                );
                              })
                              .toList(),
                        ),
                      ),
                    ],
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
                        'Tap a slice or label for details',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withAlpha(150),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );

        if (widget.wrapInCard) {
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

  List<PieChartSectionData> _buildSections(
    List<MapEntry<String, double>> entries,
    double total,
  ) {
    return entries.asMap().entries.map((e) {
      final index = e.key;
      final entry = e.value;
      final percentage = entry.value / total * 100;
      final isTouched = index == _touchedIndex;

      return PieChartSectionData(
        color: AppTheme.categoryColors[index % AppTheme.categoryColors.length],
        value: entry.value,
        title: percentage >= 10 ? '${percentage.toStringAsFixed(0)}%' : '',
        radius: isTouched ? 55 : 45,
        titleStyle: GoogleFonts.inter(
          fontSize: isTouched ? 13 : 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }
}
