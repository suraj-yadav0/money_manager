import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/dashboard_providers.dart';

class DateFilterBar extends ConsumerWidget {
  const DateFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFilter = ref.watch(dashboardDateFilterProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: DashboardDateFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = DashboardDateFilter.values[index];
          final isSelected = filter == selectedFilter;

          final label = _formatFilterLabel(filter);

          return GestureDetector(
            onTap: () {
              if (!isSelected) {
                ref.read(dashboardDateFilterProvider.notifier).state = filter;
                ref.invalidate(dashboardStatsProvider);
                ref.invalidate(recentTransactionsProvider);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.narutoOrange
                    : (isDark ? AppTheme.bgSurfaceElevatedDark : AppTheme.bgSurfaceElevatedLight),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
                  width: 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.narutoOrange.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatFilterLabel(DashboardDateFilter filter) {
    switch (filter) {
      case DashboardDateFilter.thisWeek:
        return '7 Days';
      case DashboardDateFilter.lastWeek:
        return 'Last Week';
      case DashboardDateFilter.thisMonth:
        return 'This Month';
      case DashboardDateFilter.lastMonth:
        return 'Last Month';
      case DashboardDateFilter.thisYear:
        return 'This Year';
      case DashboardDateFilter.allTime:
        return 'All Time';
    }
  }
}
