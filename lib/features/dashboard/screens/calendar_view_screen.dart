import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/presentation/glass_widgets.dart';
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

    return GlassScaffold(
      appBar: GlassAppBar(
        title: 'Calendar View',
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
            data: (totals) => GlassContainer(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              borderRadius: 12,
              child: Row(
                children: [
                  // Income
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Income',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
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
                              color: AppTheme.neonBlue,
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
                            color: Colors.white70,
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
                              color: AppTheme.neonPink,
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
                            color: Colors.white70,
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
                              color: Colors.white,
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
          color: Colors.white,
        ),
        leftChevronIcon: Icon(Icons.chevron_left, color: AppTheme.neonBlue),
        rightChevronIcon: Icon(Icons.chevron_right, color: AppTheme.neonBlue),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        dowTextFormatter: (date, locale) => Formatters.dayOfWeek(date),
        weekdayStyle: const TextStyle(color: Colors.white70),
        weekendStyle: const TextStyle(color: Colors.white70),
      ),
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        cellMargin: EdgeInsets.zero,
        tableBorder: TableBorder.all(
          color: Colors.white.withOpacity(0.1),
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
          Color color = Colors.white;
          if (day.weekday == DateTime.sunday) color = AppTheme.neonPink;
          if (day.weekday == DateTime.saturday) color = AppTheme.neonBlue;

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
      backgroundColor = AppTheme.neonBlue.withOpacity(0.2);
    } else if (isSelected) {
      backgroundColor = Colors.white.withOpacity(0.05);
    }

    // Text color logic
    Color dayTextColor = Colors.white;
    if (isToday) {
      dayTextColor = AppTheme.neonBlue;
    } else if (date.weekday == DateTime.sunday) {
      dayTextColor = AppTheme.neonPink;
    } else if (date.weekday == DateTime.saturday) {
      dayTextColor = AppTheme.neonBlue;
    }

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: isSelected
            ? Border(bottom: BorderSide(color: AppTheme.neonPurple, width: 2))
            : null,
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
                    color: AppTheme.neonBlue,
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
                    color: AppTheme.neonPink,
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
