import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:drift/drift.dart' hide Column;

import '../../../core/providers/app_state_provider.dart';
import '../../../core/utils/formatters.dart';
import '../providers/dashboard_providers.dart';
import 'chart_drilldown_sheet.dart';

/// Line chart showing daily spending or income trends over the selected period
class SpendingLineChart extends ConsumerStatefulWidget {
  final String transactionType;

  const SpendingLineChart({super.key, this.transactionType = 'expense'});

  @override
  ConsumerState<SpendingLineChart> createState() => _SpendingLineChartState();
}

class _SpendingLineChartState extends ConsumerState<SpendingLineChart> {
  ({DateTime start, DateTime end})? _range;
  Future<List<_DailySpend>>? _dailySpendingFuture;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Listen to date range changes and recompute the future when it changes.
    ref.listen<({DateTime start, DateTime end})>(dateRangeProvider, (
      previous,
      next,
    ) {
      if (previous == next) {
        return;
      }
      setState(() {
        _range = next;
        _dailySpendingFuture = _getDailySpending(ref, next.start, next.end);
      });
    });

    // Initialize on first build
    final currentRange = ref.read(dateRangeProvider);
    if (_range == null || _dailySpendingFuture == null) {
      _range = currentRange;
      _dailySpendingFuture = _getDailySpending(
        ref,
        currentRange.start,
        currentRange.end,
      );
    }

    return FutureBuilder<List<_DailySpend>>(
      future: _dailySpendingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: Container(
              height: 200,
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: colorScheme.error.withAlpha(180),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.transactionType == 'expense'
                        ? 'Failed to load spending data'
                        : 'Failed to load income data',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Card(
            child: Container(
              height: 200,
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.show_chart,
                    size: 48,
                    color: colorScheme.onSurfaceVariant.withAlpha(100),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.transactionType == 'expense'
                        ? 'No spending data'
                        : 'No income data',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final maxY = data.map((d) => d.amount).reduce((a, b) => a > b ? a : b);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                children: [
                  SizedBox(
                    height: 350,
                    width: (data.length * 50.0).clamp(
                      500.0,
                      5000.0,
                    ), // Dynamic width
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: colorScheme.outlineVariant.withAlpha(50),
                            strokeWidth: 1,
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
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 50,
                              getTitlesWidget: (value, meta) {
                                if (value == 0 || value == maxY) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Text(
                                      Formatters.compactCurrency(value),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  );
                                }
                                return const SizedBox();
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 24,
                              interval: _getInterval(data.length),
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < data.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      _formatDate(data[index].date),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(fontSize: 10),
                                    ),
                                  );
                                }
                                return const SizedBox();
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineTouchData: LineTouchData(
                          enabled: true,
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (spots) {
                              return spots.map((spot) {
                                final dailySpend = data[spot.x.toInt()];
                                final date = dailySpend.date;

                                // Build tooltip text
                                final sb = StringBuffer();
                                sb.writeln(Formatters.shortDate(date));
                                sb.writeln(Formatters.currency(spot.y));

                                if (dailySpend.topTransactions.isNotEmpty) {
                                  sb.writeln(''); // Spacer
                                  for (final name
                                      in dailySpend.topTransactions) {
                                    sb.writeln('• $name');
                                  }
                                  if (dailySpend.hasMore) {
                                    sb.write('+ more');
                                  }
                                }

                                return LineTooltipItem(
                                  sb.toString().trim(),
                                  GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                          touchCallback: (event, response) {
                            if (event is FlTapUpEvent) {
                              final spotIndex =
                                  response?.lineBarSpots?.first.spotIndex ?? -1;
                              if (spotIndex >= 0 && spotIndex < data.length) {
                                final daily = data[spotIndex];
                                if (daily.amount > 0) {
                                  final range = ref.read(dateRangeProvider);
                                  showChartDrillDown(
                                    context,
                                    params: DrillDownParams(
                                      date: daily.date,
                                      start: range.start,
                                      end: range.end,
                                      transactionType: widget.transactionType,
                                    ),
                                    title: Formatters.date(daily.date),
                                    color: widget.transactionType == 'expense'
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.green,
                                  );
                                }
                              }
                            }
                          },
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: data
                                .asMap()
                                .entries
                                .map(
                                  (e) =>
                                      FlSpot(e.key.toDouble(), e.value.amount),
                                )
                                .toList(),
                            isCurved: true,
                            curveSmoothness: 0.3,
                            color: widget.transactionType == 'expense'
                                ? colorScheme.primary
                                : Colors.green, // Use green for income
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: data.length <= 14,
                              getDotPainter: (spot, percent, bar, index) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: widget.transactionType == 'expense'
                                      ? colorScheme.primary
                                      : Colors.green, // Use green for income
                                  strokeWidth: 2,
                                  strokeColor: colorScheme.surface,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  widget.transactionType == 'expense'
                                      ? colorScheme.primary.withAlpha(80)
                                      : Colors.green.withAlpha(80),
                                  widget.transactionType == 'expense'
                                      ? colorScheme.primary.withAlpha(10)
                                      : Colors.green.withAlpha(10),
                                ],
                              ),
                            ),
                          ),
                        ],
                        minX: 0,
                        maxX: (data.length - 1).toDouble(),
                        minY: 0,
                        maxY: maxY * 1.1,
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
                          'Tap a data point for details',
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
            ),
          ),
        );
      },
    );
  }

  Future<List<_DailySpend>> _getDailySpending(
    WidgetRef ref,
    DateTime start,
    DateTime end,
  ) async {
    final db = ref.read(databaseProvider);

    // Limit the date range to prevent OOM with very large ranges (e.g., allTime)
    // If range is more than 365 days, use monthly aggregation would be better,
    // but for now we'll just cap at 365 days from start
    DateTime effectiveEnd = end;
    final daysDiff = end.difference(start).inDays;
    if (daysDiff > 365) {
      effectiveEnd = start.add(const Duration(days: 365));
    }

    // Get expenses in range with category info, filtered in SQL
    final allTransactions =
        await (db.select(db.transactions)..where(
              (t) =>
                  t.type.equals(widget.transactionType) &
                  t.timestamp.isBetweenValues(start, effectiveEnd),
            ))
            .join([
              leftOuterJoin(
                db.categories,
                db.categories.id.equalsExp(db.transactions.categoryId),
              ),
            ])
            .get();

    // Group by date
    final Map<DateTime, double> dailyTotals = {};
    final Map<DateTime, List<String>> dailyNotes = {};
    final Map<DateTime, int> dailyCounts =
        {}; // Track total transaction count per day

    for (final row in allTransactions) {
      final t = row.readTable(db.transactions);
      final c = row.readTableOrNull(db.categories);

      final date = DateTime(
        t.timestamp.year,
        t.timestamp.month,
        t.timestamp.day,
      );

      dailyTotals[date] = (dailyTotals[date] ?? 0) + t.amount;
      dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;

      // Store transaction name (Note or Category or 'Expense')
      if (dailyNotes[date] == null) dailyNotes[date] = [];
      String label = t.note ?? c?.name ?? 'Transaction';
      if (label.isEmpty) label = c?.name ?? 'Transaction';

      // Limit to top 3 per day to avoid huge tooltips
      if (dailyNotes[date]!.length < 3) {
        dailyNotes[date]!.add(label);
      }
    }

    // Fill in missing dates with 0
    final List<_DailySpend> result = [];
    DateTime current = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(
      effectiveEnd.year,
      effectiveEnd.month,
      effectiveEnd.day,
    );

    while (!current.isAfter(endDate)) {
      final amount = dailyTotals[current] ?? 0;
      final notes = dailyNotes[current] ?? [];
      final totalCount = dailyCounts[current] ?? 0;
      // Check if there are more transactions than shown (only true when count > 3)
      final hasMore = totalCount > 3;

      result.add(
        _DailySpend(
          date: current,
          amount: amount,
          topTransactions: notes,
          hasMore: hasMore,
        ),
      );
      current = current.add(const Duration(days: 1));
    }

    return result;
  }

  double _getInterval(int dataLength) {
    if (dataLength <= 7) return 1;
    if (dataLength <= 14) return 2;
    if (dataLength <= 31) return 5;
    return 7;
  }

  String _formatDate(DateTime date) {
    return Formatters.shortDate(date);
  }
}

class _DailySpend {
  final DateTime date;
  final double amount;
  final List<String> topTransactions;
  final bool hasMore;

  _DailySpend({
    required this.date,
    required this.amount,
    this.topTransactions = const [],
    this.hasMore = false,
  });
}
