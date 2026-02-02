import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/budget/screens/budget_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/insights/screens/insights_screen.dart';
import '../../features/goals/screens/goals_screen.dart';
import '../../features/transactions/screens/add_transaction_screen.dart';
import '../../features/transactions/services/recurring_service.dart';

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
    InsightsScreen(),
    GoalsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Process recurring transactions on app startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processRecurringTransactions();
    });
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

    return Scaffold(
      extendBody: true, // Content flows behind the floating nav
      body: IndexedStack(index: currentIndex, children: _screens),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        margin: const EdgeInsets.only(top: 32),
        height: 64,
        width: 64,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFF5722), // Deep Orange
              Color(0xFFFF8A65), // Lighter Orange
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5722).withAlpha(100),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
            );
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          shape: const CircleBorder(),
          child: const Icon(Icons.add, color: Colors.white, size: 32),
        ),
      ),

      bottomNavigationBar: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BottomAppBar(
            elevation: 0,
            color: Colors.transparent,
            height: 70,
            padding: EdgeInsets.zero,
            shape: const CircularNotchedRectangle(),
            notchMargin: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  context,
                  0,
                  Icons.dashboard_rounded,
                  Icons.dashboard_outlined,
                ),
                _buildNavItem(
                  context,
                  1,
                  Icons.account_balance_wallet_rounded,
                  Icons.account_balance_wallet_outlined,
                ),
                const SizedBox(width: 48), // Space for FAB
                _buildNavItem(
                  context,
                  2,
                  Icons.insights_rounded,
                  Icons.insights_outlined,
                ),
                _buildNavItem(
                  context,
                  3,
                  Icons.savings_rounded,
                  Icons.savings_outlined,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    IconData selectedIcon,
    IconData unselectedIcon,
  ) {
    final currentIndex = ref.watch(navIndexProvider);
    final isSelected = currentIndex == index;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => ref.read(navIndexProvider.notifier).state = index,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 20 : 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF5722).withAlpha(30)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(
          isSelected ? selectedIcon : unselectedIcon,
          color: isSelected
              ? const Color(0xFFFF5722)
              : theme.colorScheme.onSurface.withAlpha(100),
          size: 26,
        ),
      ),
    );
  }
}
