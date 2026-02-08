import 'package:intl/intl.dart';
import 'constants.dart';

/// Currency and date formatting utilities
class Formatters {
  Formatters._();

  static final _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '', // Symbol will be prepended manually
    decimalDigits: 0,
  );

  static final _currencyFormatWithDecimals = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '', // Symbol will be prepended manually
    decimalDigits: 2,
  );

  static final _compactCurrency = NumberFormat.compactCurrency(
    locale: 'en_IN',
    symbol: '', // Symbol will be prepended manually
    decimalDigits: 1,
  );

  static final _dateFormat = DateFormat('d MMM yyyy');
  static final _shortDateFormat = DateFormat('d MMM');
  static final _timeFormat = DateFormat('h:mm a');
  static final _monthFormat = DateFormat('MMMM yyyy');
  static final _dayFormat = DateFormat('EEEE');

  /// Format amount as currency: ₹1,23,456
  static String currency(double amount, {String? symbol}) {
    final s = symbol ?? AppConstants.currencySymbol;
    return '$s${_currencyFormat.format(amount).trim()}';
  }

  /// Format amount with decimals: ₹1,23,456.78
  static String currencyWithDecimals(double amount, {String? symbol}) {
    final s = symbol ?? AppConstants.currencySymbol;
    return '$s${_currencyFormatWithDecimals.format(amount).trim()}';
  }

  /// Format large amounts compactly: ₹1.2L
  static String compactCurrency(double amount, {String? symbol}) {
    final s = symbol ?? AppConstants.currencySymbol;
    return '$s${_compactCurrency.format(amount).trim()}';
  }

  /// Format as percentage: 45%
  static String percentage(double value) {
    return '${(value * 100).toStringAsFixed(0)}%';
  }

  /// Format date: 25 Jan 2026
  static String date(DateTime date) {
    return _dateFormat.format(date);
  }

  /// Format short date: 25 Jan
  static String shortDate(DateTime date) {
    return _shortDateFormat.format(date);
  }

  /// Format time: 5:30 PM
  static String time(DateTime date) {
    return _timeFormat.format(date);
  }

  /// Format date and time: 25 Jan 2026, 5:30 PM
  static String dateTime(DateTime date) {
    return '${_shortDateFormat.format(date)}, ${_timeFormat.format(date)}';
  }

  /// Format compact number: 1.5K, 2.3L
  static String compactNumber(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }

  /// Format month: January 2026
  static String month(DateTime date) {
    return _monthFormat.format(date);
  }

  /// Format day name: Sunday
  static String dayName(DateTime date) {
    return _dayFormat.format(date);
  }

  /// Format short day name: Sun
  static String dayOfWeek(DateTime date) {
    return DateFormat('E').format(date);
  }

  /// Get relative date text: Today, Yesterday, or date
  static String relativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    final difference = today.difference(dateOnly).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return dayName(date);
    return shortDate(date);
  }

  /// Get days remaining in current month
  static int daysRemainingInMonth() {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0);
    return lastDay.day - now.day;
  }

  /// Get days elapsed in current month
  static int daysElapsedInMonth() {
    return DateTime.now().day;
  }

  /// Get total days in current month
  static int daysInCurrentMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 0).day;
  }
}
