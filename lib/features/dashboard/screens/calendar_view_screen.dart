import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../providers/calendar_providers.dart';
import 'day_transactions_screen.dart';

/// Calendar view screen showing expenses in a calendar format
class CalendarViewScreen extends ConsumerWidget {
  const CalendarViewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final focusedDay = ref.watch(calendarFocusedDayProvider);
    final selectedDay = ref.watch(calendarSelectedDayProvider);
    final calendarFormat = ref.watch(calendarFormatProvider);
    final summariesAsync = ref.watch(calendarDailySummariesProvider);
    final monthTotalsAsync = ref.watch(calendarMonthTotalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Calendar View',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        actions: [
          // Format toggle button
          PopupMenuButton<CalendarViewFormat>(
            icon: const Icon(Icons.calendar_view_month),
            tooltip: 'Change view',
            onSelected: (format) {
              ref.read(calendarFormatProvider.notifier).state = format;
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: CalendarViewFormat.month,
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_view_month,
                      color: calendarFormat == CalendarViewFormat.month
                          ? colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 12),
                    const Text('Month'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: CalendarViewFormat.twoWeeks,
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_view_week,
                      color: calendarFormat == CalendarViewFormat.twoWeeks
                          ? colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 12),
                    const Text('2 Weeks'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: CalendarViewFormat.week,
                child: Row(
                  children: [
                    Icon(
                      Icons.view_week,
                      color: calendarFormat == CalendarViewFormat.week
                          ? colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 12),
                    const Text('Week'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Month totals card
          monthTotalsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (totals) => Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outlineVariant.withAlpha(50),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Income',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Formatters.currency(totals.income),
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: colorScheme.outlineVariant.withAlpha(100),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Expenses',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Formatters.currency(totals.expenses),
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Calendar - Full page height
          summariesAsync.when(
            loading: () => const Expanded(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Expanded(child: Center(child: Text('Error: $e'))),
            data: (summaries) => Expanded(
              child: _buildCalendar(
                context,
                ref,
                focusedDay,
                selectedDay,
                calendarFormat,
                summaries,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(
    BuildContext context,
    WidgetRef ref,
    DateTime focusedDay,
    DateTime? selectedDay,
    CalendarViewFormat format,
    Map<DateTime, DailySummary> summaries,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Convert our format enum to table_calendar's CalendarFormat
    CalendarFormat tableCalendarFormat;
    switch (format) {
      case CalendarViewFormat.month:
        tableCalendarFormat = CalendarFormat.month;
        break;
      case CalendarViewFormat.twoWeeks:
        tableCalendarFormat = CalendarFormat.twoWeeks;
        break;
      case CalendarViewFormat.week:
        tableCalendarFormat = CalendarFormat.week;
        break;
    }

    return TableCalendar<void>(
      firstDay: DateTime(2000),
      lastDay: DateTime(2100),
      focusedDay: focusedDay,
      selectedDayPredicate: (day) => isSameDay(day, selectedDay),
      calendarFormat: tableCalendarFormat,
      startingDayOfWeek: StartingDayOfWeek.monday,
      shouldFillViewport: true,
      daysOfWeekHeight: 32,
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        headerPadding: const EdgeInsets.symmetric(vertical: 8),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        leftChevronIcon: Icon(Icons.chevron_left, color: colorScheme.primary),
        rightChevronIcon: Icon(Icons.chevron_right, color: colorScheme.primary),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: theme.textTheme.bodySmall!.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurfaceVariant,
        ),
        weekendStyle: theme.textTheme.bodySmall!.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurfaceVariant.withAlpha(150),
        ),
      ),
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        cellMargin: EdgeInsets.zero,
        tableBorder: TableBorder.all(
          color: colorScheme.outlineVariant.withAlpha(50),
          width: 0.5,
        ),
        defaultDecoration: const BoxDecoration(),
        weekendDecoration: const BoxDecoration(),
        todayDecoration: const BoxDecoration(),
        selectedDecoration: const BoxDecoration(),
      ),
      onDaySelected: (selected, focused) {
        ref.read(calendarSelectedDayProvider.notifier).state = selected;
        ref.read(calendarFocusedDayProvider.notifier).state = focused;
        // Navigate to day transactions screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DayTransactionsScreen(date: selected),
          ),
        );
      },
      onPageChanged: (focused) {
        ref.read(calendarFocusedDayProvider.notifier).state = focused;
      },
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, date, _) {
          final dateKey = DateTime(date.year, date.month, date.day);
          return _buildDayCell(
            context,
            date,
            summaries[dateKey],
            isSelected: false,
            isToday: false,
          );
        },
        todayBuilder: (context, date, _) {
          final dateKey = DateTime(date.year, date.month, date.day);
          return _buildDayCell(
            context,
            date,
            summaries[dateKey],
            isSelected: false,
            isToday: true,
          );
        },
        selectedBuilder: (context, date, _) {
          final dateKey = DateTime(date.year, date.month, date.day);
          return _buildDayCell(
            context,
            date,
            summaries[dateKey],
            isSelected: true,
            isToday: isSameDay(date, DateTime.now()),
          );
        },
      ),
    );
  }

  Widget _buildDayCell(
    BuildContext context,
    DateTime date,
    DailySummary? summary, {
    required bool isSelected,
    required bool isToday,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    final hasExpenses = summary != null && summary.totalExpenses > 0;
    final hasIncome = summary != null && summary.totalIncome > 0;

    // Background color logic
    Color backgroundColor = Colors.transparent;
    if (isSelected) {
      backgroundColor = colorScheme.primary.withAlpha(10);
    } else if (isToday) {
      backgroundColor = colorScheme.primary.withAlpha(5);
    }

    // Text color logic
    Color dayTextColor = colorScheme.onSurface;
    if (isSelected) {
      dayTextColor = colorScheme.primary;
    } else if (isToday) {
      dayTextColor = colorScheme.primary;
    }

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: isSelected
            ? Border.all(color: colorScheme.primary, width: 1.5)
            : null,
      ),
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top row: Day number
          Align(
            alignment: Alignment.topRight,
            child: Text(
              '${date.day}',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: (isSelected || isToday)
                    ? FontWeight.w600
                    : FontWeight.normal,
                color: dayTextColor,
              ),
            ),
          ),

          if (hasIncome || hasExpenses) ...[
            const Spacer(),
            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (hasIncome)
                  Container(
                    margin: const EdgeInsets.only(right: 2),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                if (hasExpenses)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            // Amount
            if (hasExpenses)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  Formatters.compactNumber(summary.totalExpenses),
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.error,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
