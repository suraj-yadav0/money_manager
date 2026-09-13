import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/presentation/glass_widgets.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../providers/calendar_providers.dart';
import 'day_transactions_screen.dart';

/// Calendar view screen showing expenses and income in a responsive calendar format
class CalendarViewScreen extends ConsumerWidget {
  const CalendarViewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? AppTheme.borderDark : AppTheme.borderLight;

    final focusedDay = ref.watch(calendarFocusedDayProvider);
    final selectedDay = ref.watch(calendarSelectedDayProvider);
    final calendarFormat = ref.watch(calendarFormatProvider);
    final summariesAsync = ref.watch(calendarDailySummariesProvider);
    final monthTotalsAsync = ref.watch(calendarMonthTotalsProvider);

    return GlassScaffold(
      appBar: GlassAppBar(
        title: 'Calendar View',
        actions: [
          PopupMenuButton<CalendarViewFormat>(
            icon: Icon(Icons.calendar_view_month, color: textColor),
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape = constraints.maxWidth >= 600 &&
              constraints.maxWidth > constraints.maxHeight;

          if (isLandscape) {
            final sidebarWidth =
                (constraints.maxWidth * 0.28).clamp(240.0, 300.0);

            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: sidebarWidth,
                  child: _buildLandscapeSidebar(
                    context,
                    ref,
                    monthTotalsAsync,
                    summariesAsync,
                    selectedDay,
                    calendarFormat,
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: borderColor,
                ),
                Expanded(
                  child: summariesAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (summaries) => _buildCalendar(
                      context,
                      ref,
                      focusedDay,
                      selectedDay,
                      calendarFormat,
                      summaries,
                      isLandscape: true,
                      constraints: constraints,
                    ),
                  ),
                ),
              ],
            );
          }

          // Portrait layout
          return Column(
            children: [
              monthTotalsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (totals) => _buildPortraitMonthTotals(
                  context,
                  totals,
                  textColor,
                  subTextColor,
                ),
              ),
              summariesAsync.when(
                loading: () => const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) =>
                    Expanded(child: Center(child: Text('Error: $e'))),
                data: (summaries) => Expanded(
                  child: _buildCalendar(
                    context,
                    ref,
                    focusedDay,
                    selectedDay,
                    calendarFormat,
                    summaries,
                    isLandscape: false,
                    constraints: constraints,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPortraitMonthTotals(
    BuildContext context,
    ({double income, double expenses}) totals,
    Color textColor,
    Color subTextColor,
  ) {
    final theme = Theme.of(context);

    return GlassContainer(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      borderRadius: 12,
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text(
                  'Income',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: subTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    Formatters.currency(totals.income),
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.leafGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Expenses',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: subTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    Formatters.currency(totals.expenses),
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.kuramaRed,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Total',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: subTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    Formatters.currency(totals.income - totals.expenses),
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeSidebar(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<({double income, double expenses})> monthTotalsAsync,
    AsyncValue<Map<DateTime, DailySummary>> summariesAsync,
    DateTime? selectedDay,
    CalendarViewFormat format,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? AppTheme.borderDark : AppTheme.borderLight;
    final elevatedBg =
        isDark ? AppTheme.bgSurfaceElevatedDark : AppTheme.bgSurfaceElevatedLight;

    DailySummary? selectedDaySummary;
    if (selectedDay != null) {
      final summaries = summariesAsync.valueOrNull;
      if (summaries != null) {
        final key =
            DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
        selectedDaySummary = summaries[key];
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFormatSelector(context, ref, format, isDark),
          const SizedBox(height: 12),
          monthTotalsAsync.when(
            loading: () => const SizedBox(
              height: 90,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => const SizedBox.shrink(),
            data: (totals) => Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: elevatedBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Month Summary',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: subTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildSidebarStatRow(
                    label: 'Income',
                    amount: totals.income,
                    color: AppTheme.leafGreen,
                    icon: Icons.arrow_upward_rounded,
                  ),
                  const SizedBox(height: 8),
                  _buildSidebarStatRow(
                    label: 'Expenses',
                    amount: totals.expenses,
                    color: AppTheme.kuramaRed,
                    icon: Icons.arrow_downward_rounded,
                  ),
                  Divider(height: 16, thickness: 1, color: borderColor),
                  _buildSidebarStatRow(
                    label: 'Net Total',
                    amount: totals.income - totals.expenses,
                    color: textColor,
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (selectedDay != null)
            _buildSelectedDayCard(
              context,
              selectedDay,
              selectedDaySummary,
              isDark,
              textColor,
              subTextColor,
              borderColor,
              elevatedBg,
            ),
        ],
      ),
    );
  }

  Widget _buildSidebarStatRow({
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: color.withValues(alpha: 0.9),
          ),
        ),
        const Spacer(),
        Text(
          Formatters.currency(amount),
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedDayCard(
    BuildContext context,
    DateTime selectedDay,
    DailySummary? summary,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color borderColor,
    Color elevatedBg,
  ) {
    final hasTx = summary != null && summary.hasTransactions;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: elevatedBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.event_outlined,
                size: 14,
                color: AppTheme.narutoOrange,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  Formatters.shortDate(selectedDay),
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasTx) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${summary.transactionCount} transaction${summary.transactionCount > 1 ? 's' : ''}',
                  style: GoogleFonts.inter(fontSize: 11, color: subTextColor),
                ),
                Text(
                  summary.netAmount >= 0
                      ? '+${Formatters.currency(summary.netAmount)}'
                      : Formatters.currency(summary.netAmount),
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: summary.netAmount >= 0
                        ? AppTheme.leafGreen
                        : AppTheme.kuramaRed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 32,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  side: BorderSide(
                    color: AppTheme.narutoOrange.withValues(alpha: 0.5),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DayTransactionsScreen(date: selectedDay),
                    ),
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'View Details',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.narutoOrange,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 12,
                      color: AppTheme.narutoOrange,
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Text(
              'No transactions recorded',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: subTextColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormatSelector(
    BuildContext context,
    WidgetRef ref,
    CalendarViewFormat currentFormat,
    bool isDark,
  ) {
    final elevatedBg =
        isDark ? AppTheme.bgSurfaceElevatedDark : AppTheme.bgSurfaceElevatedLight;
    final borderClr =
        isDark ? AppTheme.borderDark.withValues(alpha: 0.2) : AppTheme.borderLight;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: elevatedBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderClr, width: 1),
      ),
      child: Row(
        children: [
          _buildFormatPill(
            label: 'Month',
            isSelected: currentFormat == CalendarViewFormat.month,
            isDark: isDark,
            onTap: () {
              ref.read(calendarFormatProvider.notifier).state =
                  CalendarViewFormat.month;
            },
          ),
          _buildFormatPill(
            label: '2 Weeks',
            isSelected: currentFormat == CalendarViewFormat.twoWeeks,
            isDark: isDark,
            onTap: () {
              ref.read(calendarFormatProvider.notifier).state =
                  CalendarViewFormat.twoWeeks;
            },
          ),
          _buildFormatPill(
            label: 'Week',
            isSelected: currentFormat == CalendarViewFormat.week,
            isDark: isDark,
            onTap: () {
              ref.read(calendarFormatProvider.notifier).state =
                  CalendarViewFormat.week;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFormatPill({
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final activeBg = isDark
        ? AppTheme.narutoOrange.withValues(alpha: 0.25)
        : AppTheme.narutoOrange.withValues(alpha: 0.15);
    final activeColor = AppTheme.narutoOrange;
    final inactiveColor =
        isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? activeBg : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar(
    BuildContext context,
    WidgetRef ref,
    DateTime focusedDay,
    DateTime? selectedDay,
    CalendarViewFormat format,
    Map<DateTime, DailySummary> summaries, {
    required bool isLandscape,
    required BoxConstraints constraints,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.1);

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

    final shouldFill = !isLandscape || constraints.maxHeight >= 360;

    final calendarWidget = TableCalendar<void>(
      firstDay: DateTime(2000),
      lastDay: DateTime(2100),
      focusedDay: focusedDay,
      selectedDayPredicate: (day) => isSameDay(day, selectedDay),
      calendarFormat: tableCalendarFormat,
      startingDayOfWeek: StartingDayOfWeek.sunday,
      shouldFillViewport: shouldFill,
      daysOfWeekHeight: isLandscape ? 24 : 32,
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        headerPadding: EdgeInsets.symmetric(vertical: isLandscape ? 4 : 8),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: isLandscape ? 17 : 20,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        leftChevronIcon: Icon(
          Icons.chevron_left,
          color: AppTheme.narutoOrange,
          size: isLandscape ? 20 : 24,
        ),
        rightChevronIcon: Icon(
          Icons.chevron_right,
          color: AppTheme.narutoOrange,
          size: isLandscape ? 20 : 24,
        ),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        dowTextFormatter: (date, locale) => Formatters.dayOfWeek(date),
        weekdayStyle: TextStyle(color: subTextColor),
        weekendStyle: TextStyle(color: subTextColor),
      ),
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        cellMargin: EdgeInsets.zero,
        tableBorder: TableBorder.all(color: borderColor, width: 0.5),
        defaultDecoration: const BoxDecoration(),
        weekendDecoration: const BoxDecoration(),
        todayDecoration: const BoxDecoration(),
        selectedDecoration: const BoxDecoration(),
      ),
      onDaySelected: (selected, focused) {
        final previousSelected = ref.read(calendarSelectedDayProvider);
        ref.read(calendarSelectedDayProvider.notifier).state = selected;
        ref.read(calendarFocusedDayProvider.notifier).state = focused;
        if (!isLandscape || isSameDay(previousSelected, selected)) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DayTransactionsScreen(date: selected),
            ),
          );
        }
      },
      onPageChanged: (focused) {
        ref.read(calendarFocusedDayProvider.notifier).state = focused;
      },
      calendarBuilders: CalendarBuilders(
        dowBuilder: (context, day) {
          final text = Formatters.dayOfWeek(day);
          Color color = textColor;
          if (day.weekday == DateTime.sunday) color = AppTheme.kuramaRed;
          if (day.weekday == DateTime.saturday) color = AppTheme.leafGreen;

          return Center(
            child: Text(
              text,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w500,
                fontSize: isLandscape ? 12 : 14,
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
            isLandscape: isLandscape,
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
            isLandscape: isLandscape,
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
            isLandscape: isLandscape,
          );
        },
      ),
    );

    if (!shouldFill) {
      return SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: calendarWidget,
      );
    }
    return calendarWidget;
  }

  Widget _buildDayCell(
    BuildContext context,
    DateTime date,
    DailySummary? summary, {
    required bool isSelected,
    required bool isToday,
    required bool isLandscape,
  }) {
    final hasExpenses = summary != null && summary.totalExpenses > 0;
    final hasIncome = summary != null && summary.totalIncome > 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color backgroundColor = Colors.transparent;
    if (isToday) {
      backgroundColor = AppTheme.narutoOrange.withValues(alpha: 0.2);
    } else if (isSelected) {
      backgroundColor = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.06);
    }

    Color dayTextColor = isDark ? Colors.white : Colors.black;
    if (isToday) {
      dayTextColor = AppTheme.narutoOrange;
    } else if (date.weekday == DateTime.sunday) {
      dayTextColor = AppTheme.kuramaRed;
    } else if (date.weekday == DateTime.saturday) {
      dayTextColor = AppTheme.leafGreen;
    }

    final dayNumberWidget = Text(
      '${date.day}',
      style: GoogleFonts.outfit(
        fontSize: isLandscape ? 12 : 13,
        fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
        color: dayTextColor,
      ),
    );

    final amountsWidget = (hasIncome || hasExpenses)
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (hasIncome)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    Formatters.compactNumber(summary.totalIncome),
                    style: GoogleFonts.outfit(
                      fontSize: isLandscape ? 9.5 : 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.leafGreen,
                    ),
                  ),
                ),
              if (hasExpenses)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    Formatters.compactNumber(summary.totalExpenses),
                    style: GoogleFonts.outfit(
                      fontSize: isLandscape ? 9.5 : 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.kuramaRed,
                    ),
                  ),
                ),
            ],
          )
        : null;

    final cellContent = isLandscape
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                dayNumberWidget,
                const Spacer(),
                if (amountsWidget != null) amountsWidget,
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.all(3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: dayNumberWidget,
                ),
                if (amountsWidget != null) amountsWidget,
              ],
            ),
          );

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: isSelected
            ? Border(
                bottom: BorderSide(
                  color: AppTheme.narutoOrange,
                  width: 2.5,
                ),
              )
            : null,
      ),
      child: cellContent,
    );
  }
}
