import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/utils/formatters.dart';
import '../providers/dashboard_providers.dart';
import '../providers/chart_type_provider.dart';
import '../widgets/balance_card.dart';
// import '../widgets/forecast_card.dart';
// import '../widgets/income_trend_chart.dart';
import '../widgets/category_pie_chart.dart';
import '../widgets/category_bar_chart.dart';
import '../widgets/spending_line_chart.dart';
import '../widgets/recent_transactions.dart';
import '../widgets/date_filter_bar.dart';
import '../../transactions/screens/all_transactions_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../insights/screens/insights_screen.dart';
import '../../sms/widgets/sms_detected_banner.dart';
import '../../sms/screens/sms_card_deck_screen.dart';
import 'calendar_view_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final chartType = ref.watch(dashboardChartTypeProvider);
    final transactionType = ref.watch(dashboardTransactionTypeProvider);
    // final userSettings = ref.watch(userSettingsStreamProvider);
    // final showIncomeChart = userSettings.value?.showIncomeChart ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CalendarViewScreen()),
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getTitle(ref),
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down, size: 20),
              ],
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const InsightsScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(recentTransactionsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SMS Auto-detected Transaction Banner (if any pending)
              const SmsDetectedBanner(),

              // Date Filters
              const DateFilterBar(),
              const SizedBox(height: 16),

              // Balance Card (New Design)
              const BalanceCard(),
              const SizedBox(height: 16),

              /*
              // Income Trend Chart (Moved to main chart section)
              if (showIncomeChart) ...[
                const IncomeTrendChart(),
                const SizedBox(height: 24),
              ],
*/

              // Forecast Card (Removed)
              // const ForecastCard(),
              // const SizedBox(height: 24),

              // Category Breakdown with chart type selector
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Transaction Type Query Selector
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'expense',
                          label: Text('Expense'),
                          icon: Icon(Icons.arrow_downward),
                        ),
                        ButtonSegment(
                          value: 'income',
                          label: Text('Income'),
                          icon: Icon(Icons.arrow_upward),
                        ),
                      ],
                      selected: {transactionType},
                      onSelectionChanged: (selected) {
                        ref
                                .read(dashboardTransactionTypeProvider.notifier)
                                .state =
                            selected.first;
                      },
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Chart type selector
                    SegmentedButton<DashboardChartType>(
                      segments: DashboardChartType.values
                          .map(
                            (type) => ButtonSegment(
                              value: type,
                              label: Text(type.label),
                              tooltip: type.tooltip,
                            ),
                          )
                          .toList(),
                      selected: {chartType},
                      onSelectionChanged: (selected) {
                        ref.read(dashboardChartTypeProvider.notifier).state =
                            selected.first;
                      },
                      showSelectedIcon: false,
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Dynamic chart based on selection
              SizedBox(
                height: chartType == DashboardChartType.pie ? 275 : 425,
                child: _buildChart(chartType, transactionType),
              ),
              const SizedBox(height: 24),

              // Recent Transactions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Transactions',
                    style: theme.textTheme.titleMedium,
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AllTransactionsScreen(),
                        ),
                      );
                    },
                    child: const Text('See All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const RecentTransactions(),
              const SizedBox(height: 100), // Space for bottom nav + FAB
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChart(DashboardChartType type, String transactionType) {
    switch (type) {
      case DashboardChartType.pie:
        return CategoryPieChart(transactionType: transactionType);
      case DashboardChartType.bar:
        return CategoryBarChart(transactionType: transactionType);
      case DashboardChartType.line:
        return SpendingLineChart(transactionType: transactionType);
    }
  }

  String _getTitle(WidgetRef ref) {
    final filter = ref.watch(dashboardDateFilterProvider);
    final range = ref.watch(dateRangeProvider);

    switch (filter) {
      case DashboardDateFilter.thisWeek:
      case DashboardDateFilter.lastWeek:
        return '${Formatters.shortDate(range.start)} - ${Formatters.shortDate(range.end)}';
      case DashboardDateFilter.thisMonth:
      case DashboardDateFilter.lastMonth:
        return Formatters.month(range.start);
      case DashboardDateFilter.thisYear:
        return range.start.year.toString();
      case DashboardDateFilter.allTime:
        return 'All Time';
    }
  }
}
