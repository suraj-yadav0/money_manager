import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/budget/screens/budget_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/networth/screens/net_worth_screen.dart';
import '../../features/goals/screens/goals_screen.dart';
import '../../features/transactions/screens/add_transaction_screen.dart';
import '../../features/transactions/services/recurring_service.dart';
import '../../features/sms/providers/sms_providers.dart';
import '../presentation/glass_widgets.dart';
import '../providers/app_state_provider.dart';
import '../providers/auth_providers.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

/// Main app shell with floating vibrant navigation dock
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

/// Provider for the current bottom navigation index
final navIndexProvider = StateProvider<int>((ref) => 0);

class _AppShellState extends ConsumerState<AppShell> {
  final _screens = const [
    DashboardScreen(),
    BudgetScreen(),
    NetWorthScreen(),
    GoalsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processRecurringTransactions();
      _scanSmsInbox();
      _triggerCloudSync();
      _checkCreditCardBillReminders();
    });
  }

  Future<void> _checkCreditCardBillReminders() async {
    try {
      final db = ref.read(databaseProvider);
      final accounts = await db.select(db.bankAccounts).get();
      await ref.read(notificationServiceProvider).checkAndNotifyCards(accounts);
    } catch (e) {
      debugPrint('Error checking credit card bill reminders: $e');
    }
  }

  Future<void> _scanSmsInbox() async {
    try {
      final hasPerm = await ref.read(smsReaderServiceProvider).hasPermission();
      if (hasPerm) {
        await ref.read(smsScanNotifierProvider.notifier).scanInbox();
      }
    } catch (e) {
      debugPrint('Error running startup SMS scan: $e');
    }
  }

  Future<void> _triggerCloudSync() async {
    try {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        ref.read(syncNotifierProvider.notifier).triggerSync();
      }
    } catch (e) {
      debugPrint('Error triggering startup sync: $e');
    }
  }

  Future<void> _processRecurringTransactions() async {
    try {
      final service = ref.read(recurringTransactionServiceProvider);
      await service.processRecurringTransactions();
    } catch (e) {
      debugPrint('Error processing recurring transactions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navIndexProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassScaffold(
      extendBody: true,
      body: IndexedStack(index: currentIndex, children: _screens),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        height: 70,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.bgSurfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(0, Icons.grid_view_rounded, 'Overview'),
            _buildNavItem(1, Icons.pie_chart_outline_rounded, 'Budget'),

            // Center Floating Action Button with Signature Orange Gradient
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const AddTransactionScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      const begin = Offset(0.0, 1.0);
                      const end = Offset.zero;
                      const curve = Curves.easeOutCubic;
                      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                      return SlideTransition(position: animation.drive(tween), child: child);
                    },
                  ),
                );
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppTheme.neonGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.narutoOrange.withValues(alpha: 0.45),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),

            _buildNavItem(2, Icons.account_balance_wallet_outlined, 'Net Worth'),
            _buildNavItem(3, Icons.savings_outlined, 'Goals'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final currentIndex = ref.watch(navIndexProvider);
    final isSelected = currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => ref.read(navIndexProvider.notifier).state = index,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.narutoOrange.withValues(alpha: isDark ? 0.15 : 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          color: isSelected
              ? AppTheme.narutoOrange
              : (isDark ? AppTheme.textMutedDark : const Color(0xFF94A3B8)),
          size: 22,
        ),
      ),
    );
  }
}
