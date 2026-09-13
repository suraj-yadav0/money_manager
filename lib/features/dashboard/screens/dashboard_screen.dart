import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/utils/formatters.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/balance_card.dart';
import '../widgets/analytics_card.dart';
import '../widgets/recent_transactions.dart';
import '../widgets/date_filter_bar.dart';
import '../../transactions/screens/all_transactions_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../insights/screens/insights_screen.dart';
import '../../sms/widgets/sms_detected_banner.dart';
import '../../sms/widgets/sms_startup_popup.dart';
import '../../sms/providers/sms_providers.dart';
import 'calendar_view_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  static bool _hasShownStartupPopup = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowStartupPopup();
    });
  }

  void _checkAndShowStartupPopup() {
    if (_hasShownStartupPopup || !mounted) return;

    final pendingCount = ref.read(pendingSmsCountProvider);
    if (pendingCount > 0) {
      _hasShownStartupPopup = true;
      SmsStartupPopup.show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Listen for newly arrived SMS alerts to pop up immediately if user is on Homescreen
    ref.listen<int>(pendingSmsCountProvider, (prev, next) {
      if (next > 0 && (prev == null || prev == 0) && !_hasShownStartupPopup) {
        _hasShownStartupPopup = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            SmsStartupPopup.show(context);
          }
        });
      }
    });

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
                Flexible(
                  child: Text(
                    _getTitle(ref),
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
          ref.invalidate(pendingSmsTransactionsProvider);
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

              // Balance Card (Authoritative Liquid & Period Cashflow)
              const BalanceCard(),
              const SizedBox(height: 16),

              // Analytics Section (Card Header Controls + Chart)
              const AnalyticsCard(),
              const SizedBox(height: 24),

              // Recent Transactions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Recent Transactions',
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
