import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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
import '../presentation/update_prompt_sheet.dart';
import '../providers/update_providers.dart';
import '../theme/app_theme.dart';

/// Main app shell with frosted iOS navigation bar
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
      _checkAppUpdates();
    });
  }

  Future<void> _checkAppUpdates() async {
    try {
      final info = await ref
          .read(updateCheckNotifierProvider.notifier)
          .checkForUpdate();
      if (info != null && info.isNewer && mounted) {
        UpdatePromptSheet.show(context, info);
      }
    } catch (e) {
      debugPrint('Error checking startup app updates: $e');
    }
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

  void _openAddTransaction() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AddTransactionScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          final tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navIndexProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final borderColor = isDark ? const Color(0x1AFFFFFF) : AppTheme.borderLight;
    final navBgColor = isDark
        ? const Color(0xFF09090D).withValues(alpha: 0.88)
        : Colors.white.withValues(alpha: 0.90);

    return GlassScaffold(
      extendBody: true,
      body: IndexedStack(index: currentIndex, children: _screens),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: navBgColor,
              border: Border(top: BorderSide(color: borderColor, width: 0.8)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 58,
                child: Row(
                  children: [
                    _buildNavItem(
                      index: 0,
                      icon: Icons.space_dashboard_outlined,
                      activeIcon: Icons.space_dashboard_rounded,
                      label: 'Overview',
                      isSelected: currentIndex == 0,
                      primaryColor: primaryColor,
                      isDark: isDark,
                    ),
                    _buildNavItem(
                      index: 1,
                      icon: Icons.pie_chart_outline_rounded,
                      activeIcon: Icons.pie_chart_rounded,
                      label: 'Budget',
                      isSelected: currentIndex == 1,
                      primaryColor: primaryColor,
                      isDark: isDark,
                    ),

                    // Refined Center Action
                    Expanded(
                      child: Center(
                        child: GestureDetector(
                          onTap: _openAddTransaction,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              color: (primaryColor == Colors.white)
                                  ? const Color(0xFF09090B)
                                  : Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),

                    _buildNavItem(
                      index: 2,
                      icon: Icons.account_balance_wallet_outlined,
                      activeIcon: Icons.account_balance_wallet_rounded,
                      label: 'Net Worth',
                      isSelected: currentIndex == 2,
                      primaryColor: primaryColor,
                      isDark: isDark,
                    ),
                    _buildNavItem(
                      index: 3,
                      icon: Icons.savings_outlined,
                      activeIcon: Icons.savings_rounded,
                      label: 'Goals',
                      isSelected: currentIndex == 3,
                      primaryColor: primaryColor,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
    required Color primaryColor,
    required bool isDark,
  }) {
    final inactiveColor =
        isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(navIndexProvider.notifier).state = index;
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? primaryColor : inactiveColor,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: -0.1,
                color: isSelected ? primaryColor : inactiveColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
