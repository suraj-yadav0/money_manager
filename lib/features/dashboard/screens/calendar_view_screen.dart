import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../providers/calendar_providers.dart';
import '../widgets/day_transactions_list.dart';

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
                border: Border.all(color: colorScheme.outlineVariant.withAlpha(50)),
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

          // Calendar
          summariesAsync.when(
            loading: () => const Expanded(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Expanded(child: Center(child: Text('Error: $e'))),
            data: (summaries) => _buildCalendar(
              context,
              ref,
              focusedDay,
              selectedDay,
              calendarFormat,
              summaries,
            ),
          ),

          // Selected day transactions
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Selected date header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Text(
                      selectedDay != null
                          ? Formatters.date(selectedDay)
                          : 'Select a date',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Transactions list
                  const Expanded(
                    child: DayTransactionsList(),
                  ),
                ],
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
      rowHeight: 48, // Increased row height to fit expense amounts
      daysOfWeekHeight: 20,
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18,
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
        cellMargin: const EdgeInsets.all(2),
        rowDecoration: const BoxDecoration(),
        todayDecoration: BoxDecoration(
          color: colorScheme.primary.withAlpha(30),
          shape: BoxShape.circle,
        ),
        todayTextStyle: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
        selectedDecoration: BoxDecoration(
          color: colorScheme.primary,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: TextStyle(
          color: colorScheme.onPrimary,
          fontWeight: FontWeight.w600,
        ),
        defaultTextStyle: TextStyle(color: colorScheme.onSurface),
        weekendTextStyle: TextStyle(color: colorScheme.onSurface.withAlpha(180)),
      ),
      onDaySelected: (selected, focused) {
        ref.read(calendarSelectedDayProvider.notifier).state = selected;
        ref.read(calendarFocusedDayProvider.notifier).state = focused;
      },
      onPageChanged: (focused) {
        ref.read(calendarFocusedDayProvider.notifier).state = focused;
      },
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, date, events) {
          final dateKey = DateTime(date.year, date.month, date.day);
          final summary = summaries[dateKey];

          if (summary == null || !summary.hasTransactions) {
            return null;
          }

          return Positioned(
            bottom: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (summary.totalExpenses > 0)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                if (summary.totalExpenses > 0 && summary.totalIncome > 0)
                  const SizedBox(width: 2),
                if (summary.totalIncome > 0)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.success,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          );
        },
        // Optional: Show amount below the date
        defaultBuilder: (context, date, focusedDay) {
          final dateKey = DateTime(date.year, date.month, date.day);
          final summary = summaries[dateKey];

          return _buildDayCell(
            context,
            date,
            summary,
            isSelected: false,
            isToday: false,
          );
        },
        todayBuilder: (context, date, focusedDay) {
          final dateKey = DateTime(date.year, date.month, date.day);
          final summary = summaries[dateKey];

          return _buildDayCell(
            context,
            date,
            summary,
            isSelected: false,
            isToday: true,
          );
        },
        selectedBuilder: (context, date, focusedDay) {
          final dateKey = DateTime(date.year, date.month, date.day);
          final summary = summaries[dateKey];

          return _buildDayCell(
            context,
            date,
            summary,
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

    Color backgroundColor;
    Color textColor;

    if (isSelected) {
      backgroundColor = colorScheme.primary;
      textColor = colorScheme.onPrimary;
    } else if (isToday) {
      backgroundColor = colorScheme.primary.withAlpha(30);
      textColor = colorScheme.primary;
    } else {
      backgroundColor = Colors.transparent;
      textColor = colorScheme.onSurface;
    }

    final hasExpenses = summary != null && summary.totalExpenses > 0;

    return Container(
      margin: const EdgeInsets.all(2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                fontWeight: isSelected || isToday ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          if (hasExpenses)
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  Formatters.compactNumber(summary!.totalExpenses),
                  style: TextStyle(
                    fontSize: 7,
                    color: isSelected ? colorScheme.onPrimary.withAlpha(200) : colorScheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
