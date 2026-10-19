import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/dashboard_providers.dart';

class DateFilterBar extends ConsumerWidget {
  const DateFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFilter = ref.watch(dashboardDateFilterProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final unselectedBg = isDark
        ? const Color(0xFF131318)
        : const Color(0xFFEBECEF);
    final unselectedBorder = isDark ? const Color(0x1AFFFFFF) : AppTheme.borderLight;

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: DashboardDateFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = DashboardDateFilter.values[index];
          final isSelected = filter == selectedFilter;
          final label = _formatFilterLabel(filter);

          return GestureDetector(
            onTap: () {
              if (!isSelected) {
                HapticFeedback.selectionClick();
                ref.read(dashboardDateFilterProvider.notifier).state = filter;
                ref.invalidate(dashboardStatsProvider);
                ref.invalidate(recentTransactionsProvider);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : unselectedBg,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: isSelected ? Colors.transparent : unselectedBorder,
                  width: 0.8,
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    letterSpacing: -0.1,
                    color: isSelected
                        ? (primaryColor == Colors.white ? const Color(0xFF09090B) : Colors.white)
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
