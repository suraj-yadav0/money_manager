import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/chart_type_provider.dart';
import '../providers/dashboard_providers.dart';
import 'category_bar_chart.dart';
import 'category_pie_chart.dart';
import 'spending_line_chart.dart';

/// Single unified analytics card hosting low-profile header controls and responsive charts
class AnalyticsCard extends ConsumerWidget {
  const AnalyticsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppTheme.borderDark : AppTheme.borderLight;
    final cardBg = isDark ? AppTheme.bgSurfaceDark : AppTheme.bgSurfaceLight;

    final transactionType = ref.watch(dashboardTransactionTypeProvider);
    final chartType = ref.watch(dashboardChartTypeProvider);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Low-profile header controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Expense / Income compact switcher
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: _buildTransactionTypeSwitch(
                          context,
                          ref,
                          transactionType,
                          isDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Chart Type compact switcher
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: _buildChartTypeSwitch(
                        context,
                        ref,
                        chartType,
                        isDark,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Divider(height: 1, thickness: 1, color: borderColor),
          // Dynamic embedded chart
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _buildChart(chartType, transactionType),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTypeSwitch(
    BuildContext context,
    WidgetRef ref,
    String currentType,
    bool isDark,
  ) {
    final elevatedBg =
        isDark ? AppTheme.bgSurfaceElevatedDark : AppTheme.bgSurfaceElevatedLight;
    final borderClr =
        isDark ? AppTheme.borderDark.withAlpha(25) : AppTheme.borderLight;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: elevatedBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderClr, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTypePill(
            label: 'Expense',
            icon: Icons.arrow_downward_rounded,
            isSelected: currentType == 'expense',
            activeColor: AppTheme.kuramaRed,
            isDark: isDark,
            onTap: () {
              ref.read(dashboardTransactionTypeProvider.notifier).state =
                  'expense';
            },
          ),
          const SizedBox(width: 2),
          _buildTypePill(
            label: 'Income',
            icon: Icons.arrow_upward_rounded,
            isSelected: currentType == 'income',
            activeColor: AppTheme.leafGreen,
            isDark: isDark,
            onTap: () {
              ref.read(dashboardTransactionTypeProvider.notifier).state =
                  'income';
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTypePill({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final activeBg = activeColor.withAlpha(isDark ? 45 : 30);
    final inactiveColor =
        isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? activeColor : inactiveColor,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartTypeSwitch(
    BuildContext context,
    WidgetRef ref,
    DashboardChartType currentChartType,
    bool isDark,
  ) {
    final elevatedBg =
        isDark ? AppTheme.bgSurfaceElevatedDark : AppTheme.bgSurfaceElevatedLight;
    final borderClr =
        isDark ? AppTheme.borderDark.withAlpha(25) : AppTheme.borderLight;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: elevatedBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderClr, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: DashboardChartType.values.map((type) {
          final isSelected = type == currentChartType;
          return _buildChartIconPill(
            type: type,
            isSelected: isSelected,
            isDark: isDark,
            onTap: () {
              ref.read(dashboardChartTypeProvider.notifier).state = type;
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChartIconPill({
    required DashboardChartType type,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final inactiveColor =
        isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight;
    final activeBg =
        isDark ? Colors.white.withAlpha(35) : Colors.white;

    return Tooltip(
      message: type.tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected ? activeBg : Colors.transparent,
              borderRadius: BorderRadius.circular(13),
              boxShadow: isSelected && !isDark
                  ? [
                      BoxShadow(
                        color: Colors.black.withAlpha(15),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              type.icon,
              size: 16,
              color: isSelected
                  ? (isDark ? Colors.white : AppTheme.narutoOrange)
                  : inactiveColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChart(DashboardChartType type, String transactionType) {
    switch (type) {
      case DashboardChartType.pie:
        return CategoryPieChart(
          key: ValueKey('pie_$transactionType'),
          transactionType: transactionType,
          wrapInCard: false,
        );
      case DashboardChartType.bar:
        return CategoryBarChart(
          key: ValueKey('bar_$transactionType'),
          transactionType: transactionType,
          wrapInCard: false,
        );
      case DashboardChartType.line:
        return SpendingLineChart(
          key: ValueKey('line_$transactionType'),
          transactionType: transactionType,
          wrapInCard: false,
        );
    }
  }
}
