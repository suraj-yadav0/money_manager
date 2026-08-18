import 'dart:ui';
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
import '../providers/auth_providers.dart';
import '../theme/app_theme.dart';

/// Main app shell with bottom navigation
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
    // Process recurring transactions, SMS scan & trigger background sync on app startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processRecurringTransactions();
      _scanSmsInbox();
      _triggerCloudSync();
    });
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
      // Silently handle errors - don't block app startup
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
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 30),
        height: 80,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.black.withOpacity(0.2)
              : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.05),
                        ]
                      : [
                          Colors.white.withOpacity(0.6),
                          Colors.white.withOpacity(0.4),
                        ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(0, Icons.grid_view_rounded, 'Home'),
                  _buildNavItem(
                    1,
                    Icons.account_balance_wallet_rounded,
                    'Budget',
                  ),

                  // Floating Action Button in the middle
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const AddTransactionScreen(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                const begin = Offset(0.0, 1.0);
                                const end = Offset.zero;
                                const curve = Curves.ease;
                                var tween = Tween(
                                  begin: begin,
                                  end: end,
                                ).chain(CurveTween(curve: curve));
                                return SlideTransition(
                                  position: animation.drive(tween),
                                  child: child,
                                );
                              },
                          opaque: false, // For glass effect overlay if needed
                        ),
                      );
                    },
                    child: Container(
                      width: 55,
                      height: 55,
                      decoration: BoxDecoration(
                        gradient: AppTheme.neonGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.narutoOrange.withOpacity(0.5),
                            blurRadius: 15,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),

                  _buildNavItem(2, Icons.account_balance_rounded, 'Net Worth'),
                  _buildNavItem(3, Icons.savings_rounded, 'Goals'),
                ],
              ),
            ),
          ),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.05))
                  : Colors.transparent,
              shape: BoxShape.circle,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppTheme.narutoOrange.withOpacity(0.3),
                        blurRadius: 12,
                      ),
                    ]
                  : [],
            ),
            child: Icon(
              icon,
              color: isSelected
                  ? AppTheme.narutoOrange
                  : (isDark
                        ? Colors.white.withOpacity(0.6)
                        : Colors.black.withOpacity(0.5)),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}
