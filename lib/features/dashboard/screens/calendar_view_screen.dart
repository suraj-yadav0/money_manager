import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';

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
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                // No border or shadow as per reference clean look, or subtle
              ),
              child: Row(
                children: [
                  // Income
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Income',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          child: Text(
                            Formatters.currency(totals.income),
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue, // Reference: Blue
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Expenses
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Expenses',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          child: Text(
                            Formatters.currency(totals.expenses),
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red, // Reference: Red
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Total
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Total',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          child: Text(
                            Formatters.currency(
                              totals.income - totals.expenses,
                            ),
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black, // Reference: Black
                            ),
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
      startingDayOfWeek: StartingDayOfWeek.sunday, // Reference: Starts Sunday
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
        dowTextFormatter: (date, locale) =>
            Formatters.dayOfWeek(date), // Custom styling needed?
        // We will customize via builder if needed, but styling properties are limited.
        // Let's rely on standard text styles and override colors in builder if TableCalendar supported dowBuilder.
        // TableCalendar 3.0 has dowBuilder in CalendarBuilders!
        weekdayStyle: const TextStyle(), // We will use builder
        weekendStyle: const TextStyle(), // We will use builder
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
        dowBuilder: (context, day) {
          final text = Formatters.dayOfWeek(day);
          Color color = Colors.black;
          if (day.weekday == DateTime.sunday) color = Colors.red;
          if (day.weekday == DateTime.saturday) color = Colors.blue;

          return Center(
            child: Text(
              text,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          );
        },
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
    final hasExpenses = summary != null && summary.totalExpenses > 0;
    final hasIncome = summary != null && summary.totalIncome > 0;

    // Background color logic: Today gets a dark fill
    Color backgroundColor = Colors.transparent;
    if (isToday) {
      backgroundColor = const Color(
        0xFF2C3E50,
      ); // Dark Blue/Black like reference
    } else if (isSelected) {
      backgroundColor = Colors.transparent; // Selection is border only
    }

    // Text color logic
    Color dayTextColor = Colors.black;
    if (isToday) {
      dayTextColor = Colors.white;
    } else if (date.weekday == DateTime.sunday) {
      dayTextColor = Colors.red;
    } else if (date.weekday == DateTime.saturday) {
      dayTextColor = Colors.blue;
    }

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: isSelected
            ? Border(bottom: BorderSide(color: Colors.red, width: 2))
            : null, // Bottom accent like reference tab highlight
        // OR Box Border as per previous "Box Shape" request? User now says "Similar to this". Reference has white cells with no border, but user ASKED for "Box Shape" in previous turn.
        // The reference image is a grid. The grid lines come from TableBorder we set on TableCalendar.
        // So we don't need borders here except selection.
        // Reference selection seems to be just the text color or a highlight?
        // I will stick to "Box Shape" grid lines (already in _buildCalendar) and use a distinct selection style (e.g. slight background or border).
        // Let's use a subtle box border for selection.
      ),
      padding: const EdgeInsets.all(2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Left: Day number
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 4, top: 4),
              child: Text(
                '${date.day}',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: dayTextColor,
                ),
              ),
            ),
          ),

          const Spacer(),

          // Income (Blue)
          if (hasIncome)
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  Formatters.compactNumber(summary.totalIncome),
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ),
            ),

          // Expenses (Red)
          if (hasExpenses)
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  Formatters.compactNumber(summary.totalExpenses),
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }
}
