import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/dashboard_providers.dart';

class DateFilterBar extends ConsumerWidget {
  const DateFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFilter = ref.watch(dashboardDateFilterProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: DashboardDateFilter.values.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = DashboardDateFilter.values[index];
          final isSelected = filter == selectedFilter;

          return ChoiceChip(
            label: Text(
              filter.label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                ref.read(dashboardDateFilterProvider.notifier).state = filter;
                ref.invalidate(dashboardStatsProvider);
                ref.invalidate(
                  recentTransactionsProvider,
                ); // Refresh recent list too
              }
            },
            selectedColor: colorScheme.primary,
            backgroundColor: colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected
                    ? Colors.transparent
                    : colorScheme.outlineVariant,
              ),
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }
}
