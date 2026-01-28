import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Available chart types for the dashboard
enum DashboardChartType { pie, bar, line }

extension DashboardChartTypeExtension on DashboardChartType {
  String get label {
    switch (this) {
      case DashboardChartType.pie:
        return 'Pie';
      case DashboardChartType.bar:
        return 'Bar';
      case DashboardChartType.line:
        return 'Trend';
    }
  }

  String get tooltip {
    switch (this) {
      case DashboardChartType.pie:
        return 'Category breakdown';
      case DashboardChartType.bar:
        return 'Spending by category';
      case DashboardChartType.line:
        return 'Daily spending trend';
    }
  }
}

/// Provider for the selected chart type
final dashboardChartTypeProvider = StateProvider<DashboardChartType>((ref) {
  return DashboardChartType.pie;
});
