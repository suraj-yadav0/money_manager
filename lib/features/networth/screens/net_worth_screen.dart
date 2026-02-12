import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/database/database.dart';
import '../../../core/presentation/glass_widgets.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/providers/app_state_provider.dart';
import '../providers/net_worth_providers.dart';
import '../widgets/add_asset_sheet.dart';

class NetWorthScreen extends ConsumerWidget {
  const NetWorthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final netWorthAsync = ref.watch(netWorthProvider);
    final monthlyAsync = ref.watch(monthlyNetWorthProvider);
    final assetsAsync = ref.watch(assetsProvider);
    final currencySymbol = ref.watch(currencyProvider);
    final selectedType = ref.watch(selectedAssetTypeProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GlassScaffold(
      appBar: AppBar(
        title: Text(
          'Net Worth',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Asset',
            onPressed: () => _showAddAssetSheet(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(netWorthProvider);
          ref.invalidate(monthlyNetWorthProvider);
          ref.invalidate(assetsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Net Worth Header Card
              netWorthAsync.when(
                loading: () => _buildLoadingCard(context),
                error: (e, _) => _buildErrorCard(context, e.toString()),
                data: (data) =>
                    _NetWorthCard(data: data, currencySymbol: currencySymbol),
              ),
              const SizedBox(height: 20),

              // Breakdown Stats
              netWorthAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (data) =>
                    _BreakdownRow(data: data, currencySymbol: currencySymbol),
              ),
              const SizedBox(height: 28),

              // My Assets & Liabilities
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Assets & Liabilities',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showAddAssetSheet(context, ref),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.narutoOrange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Type Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      isSelected: selectedType == null,
                      onSelected: () =>
                          ref.read(selectedAssetTypeProvider.notifier).state =
                              null,
                    ),
                    const SizedBox(width: 6),
                    ...AssetType.values.map(
                      (type) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _FilterChip(
                          label: '${type.emoji} ${type.label}',
                          isSelected: selectedType == type,
                          onSelected: () =>
                              ref
                                      .read(selectedAssetTypeProvider.notifier)
                                      .state =
                                  type,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Asset List
              assetsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (allAssets) {
                  final filtered = selectedType == null
                      ? allAssets
                      : allAssets
                            .where((a) => a.type == selectedType.key)
                            .toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 48,
                              color: colorScheme.onSurfaceVariant.withAlpha(
                                100,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              selectedType == null
                                  ? 'No assets added yet.\nTap "+" to add your first asset.'
                                  : 'No ${selectedType.label.toLowerCase()} added yet.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: filtered
                        .map(
                          (asset) => _AssetCard(
                            asset: asset,
                            currencySymbol: currencySymbol,
                            onTap: () =>
                                _showAddAssetSheet(context, ref, asset: asset),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 28),

              // Monthly Trend Chart
              Text(
                'Net Worth Trend',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              monthlyAsync.when(
                loading: () => const SizedBox(
                  height: 250,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => SizedBox(
                  height: 250,
                  child: Center(child: Text('Error: $e')),
                ),
                data: (months) {
                  if (months.isEmpty) {
                    return SizedBox(
                      height: 200,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.show_chart,
                              size: 48,
                              color: colorScheme.onSurfaceVariant.withAlpha(
                                100,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No data yet',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return _NetWorthChart(
                    months: months,
                    currencySymbol: currencySymbol,
                  );
                },
              ),
              const SizedBox(height: 28),

              // Monthly Breakdown List
              Text(
                'Monthly Breakdown',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              monthlyAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
                data: (months) {
                  if (months.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'Add transactions to see your monthly breakdown.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }
                  final reversed = months.reversed.toList();
                  return Column(
                    children: reversed
                        .map(
                          (m) => _MonthCard(
                            month: m,
                            currencySymbol: currencySymbol,
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddAssetSheet(BuildContext context, WidgetRef ref, {Asset? asset}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AddAssetSheet(existingAsset: asset),
    ).then((result) {
      if (result == true) {
        ref.invalidate(netWorthProvider);
        ref.invalidate(assetsProvider);
      }
    });
  }

  Widget _buildLoadingCard(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorCard(BuildContext context, String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text('Error: $error'),
    );
  }
}

// ─── Filter Chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.narutoOrange.withAlpha(30)
              : (isDark
                    ? Colors.white.withAlpha(15)
                    : Colors.black.withAlpha(10)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.narutoOrange
                : (isDark
                      ? Colors.white.withAlpha(20)
                      : Colors.black.withAlpha(15)),
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? AppTheme.narutoOrange
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

// ─── Asset Card ────────────────────────────────────────────────────────────────

class _AssetCard extends StatelessWidget {
  final Asset asset;
  final String currencySymbol;
  final VoidCallback onTap;

  const _AssetCard({
    required this.asset,
    required this.currencySymbol,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final type = AssetType.fromKey(asset.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Emoji icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color:
                      (asset.isLiability
                              ? AppTheme.kuramaRed
                              : AppTheme.leafGreen)
                          .withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(type.emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 14),
              // Name + type
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.name,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      type.label,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              // Value
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${asset.isLiability ? '-' : ''}${Formatters.currency(asset.value, symbol: currencySymbol)}',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: asset.isLiability
                          ? AppTheme.kuramaRed
                          : AppTheme.leafGreen,
                    ),
                  ),
                  Text(
                    asset.isLiability ? 'Liability' : 'Asset',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withAlpha(100),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Net Worth Card ────────────────────────────────────────────────────────────

class _NetWorthCard extends StatelessWidget {
  final NetWorthData data;
  final String currencySymbol;

  const _NetWorthCard({required this.data, required this.currencySymbol});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPositive = data.netWorth >= 0;

    return GlassContainer(
      width: double.infinity,
      borderRadius: 28,
      padding: const EdgeInsets.all(28),
      gradientColors: isDark
          ? [
              (isPositive ? AppTheme.leafGreen : AppTheme.kuramaRed).withAlpha(
                90,
              ),
              (isPositive ? AppTheme.chakraBlue : AppTheme.narutoOrange)
                  .withAlpha(40),
            ]
          : [
              (isPositive ? AppTheme.leafGreen : AppTheme.kuramaRed).withAlpha(
                215,
              ),
              (isPositive ? AppTheme.chakraBlue : AppTheme.narutoOrange)
                  .withAlpha(165),
            ],
      border: Border.all(
        color: (isPositive ? AppTheme.leafGreen : AppTheme.kuramaRed).withAlpha(
          100,
        ),
        width: 1.5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPositive
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Total Net Worth',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withAlpha(215),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            Formatters.currency(data.netWorth, symbol: currencySymbol),
            style: GoogleFonts.outfit(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Assets · Cashflow · Liabilities',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withAlpha(150),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Breakdown Row ─────────────────────────────────────────────────────────────

class _BreakdownRow extends StatelessWidget {
  final NetWorthData data;
  final String currencySymbol;

  const _BreakdownRow({required this.data, required this.currencySymbol});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatMiniCard(
                icon: Icons.account_balance_rounded,
                label: 'Assets',
                value: Formatters.currency(
                  data.totalAssets,
                  symbol: currencySymbol,
                ),
                color: AppTheme.leafGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatMiniCard(
                icon: Icons.credit_card,
                label: 'Liabilities',
                value: Formatters.currency(
                  data.totalLiabilities,
                  symbol: currencySymbol,
                ),
                color: AppTheme.kuramaRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatMiniCard(
                icon: Icons.arrow_upward_rounded,
                label: 'Income',
                value: Formatters.currency(
                  data.totalIncome,
                  symbol: currencySymbol,
                ),
                color: AppTheme.chakraBlue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatMiniCard(
                icon: Icons.arrow_downward_rounded,
                label: 'Expenses',
                value: Formatters.currency(
                  data.totalExpenses,
                  symbol: currencySymbol,
                ),
                color: AppTheme.narutoOrange,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatMiniCard(
                icon: Icons.savings_rounded,
                label: 'Goals',
                value: Formatters.currency(
                  data.goalSavings,
                  symbol: currencySymbol,
                ),
                color: AppTheme.leafGreen,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatMiniCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatMiniCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Net Worth Chart ───────────────────────────────────────────────────────────

class _NetWorthChart extends StatelessWidget {
  final List<MonthlyNetWorth> months;
  final String currencySymbol;

  const _NetWorthChart({required this.months, required this.currencySymbol});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gridColor = isDark
        ? Colors.white.withAlpha(20)
        : Colors.black.withAlpha(15);
    final labelColor = isDark
        ? Colors.white.withAlpha(130)
        : Colors.black.withAlpha(130);

    final spots = months.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.cumulativeNetWorth);
    }).toList();

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final padding = (maxY - minY) * 0.15;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 16, 12),
        child: SizedBox(
          height: 250,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: _calculateInterval(maxY - minY),
                getDrawingHorizontalLine: (value) =>
                    FlLine(color: gridColor, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 52,
                    getTitlesWidget: (value, meta) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        _formatShortCurrency(value),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: labelColor,
                        ),
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: _bottomInterval(months.length),
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= months.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _shortMonth(months[index].month),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: labelColor,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: (months.length - 1).toDouble(),
              minY: minY - padding,
              maxY: maxY + padding,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: AppTheme.narutoOrange,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: months.length <= 12,
                    getDotPainter: (spot, percent, bar, index) =>
                        FlDotCirclePainter(
                          radius: 4,
                          color: AppTheme.narutoOrange,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppTheme.narutoOrange.withAlpha(76),
                        AppTheme.narutoOrange.withAlpha(0),
                      ],
                    ),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) {
                    return spots.map((spot) {
                      final m = months[spot.x.toInt()];
                      return LineTooltipItem(
                        '${_monthName(m.month)}\n',
                        GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withAlpha(180),
                        ),
                        children: [
                          TextSpan(
                            text: Formatters.currency(
                              m.cumulativeNetWorth,
                              symbol: currencySymbol,
                            ),
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _calculateInterval(double range) {
    if (range <= 0) return 1000;
    if (range < 5000) return 1000;
    if (range < 20000) return 5000;
    if (range < 100000) return 20000;
    if (range < 500000) return 100000;
    return 200000;
  }

  double _bottomInterval(int count) {
    if (count <= 6) return 1;
    if (count <= 12) return 2;
    return (count / 6).ceilToDouble();
  }

  String _formatShortCurrency(double value) {
    if (value.abs() >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value.abs() >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  String _shortMonth(DateTime m) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[m.month - 1];
  }

  String _monthName(DateTime m) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[m.month - 1]} ${m.year}';
  }
}

// ─── Month Card ────────────────────────────────────────────────────────────────

class _MonthCard extends StatelessWidget {
  final MonthlyNetWorth month;
  final String currencySymbol;

  const _MonthCard({required this.month, required this.currencySymbol});

  @override
  Widget build(BuildContext context) {
    final isPositive = month.net >= 0;

    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${monthNames[month.month.month - 1]} ${month.month.year}',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (isPositive ? AppTheme.leafGreen : AppTheme.kuramaRed)
                            .withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${isPositive ? '+' : ''}${Formatters.currency(month.net, symbol: currencySymbol)}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isPositive
                          ? AppTheme.leafGreen
                          : AppTheme.kuramaRed,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Income',
                    value: Formatters.currency(
                      month.income,
                      symbol: currencySymbol,
                    ),
                    color: AppTheme.leafGreen,
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Expenses',
                    value: Formatters.currency(
                      month.expenses,
                      symbol: currencySymbol,
                    ),
                    color: AppTheme.kuramaRed,
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Net Worth',
                    value: Formatters.currency(
                      month.cumulativeNetWorth,
                      symbol: currencySymbol,
                    ),
                    color: AppTheme.narutoOrange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
