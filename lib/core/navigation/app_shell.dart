import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/budget/screens/budget_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/insights/screens/insights_screen.dart';
import '../../features/goals/screens/goals_screen.dart';
import '../../features/transactions/screens/add_transaction_screen.dart';

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
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navIndexProvider);

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          ref.read(navIndexProvider.notifier).state = index;
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Budget',
          ),
          NavigationDestination(
            icon: Icon(Icons.lightbulb_outline),
            selectedIcon: Icon(Icons.lightbulb),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.savings_outlined),
            selectedIcon: Icon(Icons.savings),
            label: 'Goals',
          ),
        ],
      ),
      floatingActionButton: currentIndex == 3
          ? null
          : FloatingActionButton(
              heroTag: 'shell_fab',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AddTransactionScreen(),
                  ),
                );
              },
              child: const Icon(Icons.add),
            ),
    );
  }
}
