import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dashboard_providers.dart';
import '../screens/calendar_view_screen.dart';

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
        itemCount: DashboardDateFilter.values.length + 1, // +1 for Calendar button
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          // Last item is the Calendar button
          if (index == DashboardDateFilter.values.length) {
            return ActionChip(
              avatar: Icon(
                Icons.calendar_month,
                size: 18,
                color: colorScheme.primary,
              ),
              label: Text(
                'Calendar',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CalendarViewScreen(),
                  ),
                );
              },
              backgroundColor: colorScheme.primaryContainer.withAlpha(100),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: colorScheme.primary.withAlpha(100)),
              ),
            );
          }

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
