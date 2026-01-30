import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/utils/icon_helper.dart';
import '../providers/budget_provider.dart';
import '../widgets/budget_summary_card.dart';
import '../widgets/category_budget_card.dart';

/// Budget screen showing spending vs budget breakdown
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetAsync = ref.watch(budgetStatsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Budget',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _showBudgetSettings(context, ref),
          ),
        ],
      ),
      body: budgetAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (stats) {
          if (stats.totalBudget == 0) {
            return _buildNoBudgetView(context, ref);
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(budgetStatsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary Card
                BudgetSummaryCard(stats: stats),
                const SizedBox(height: 24),

                // Category breakdown header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Category Budgets',
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      '${stats.categoryStats.length} categories',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Category budget cards
                ...stats.categoryStats.map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CategoryBudgetCard(
                      stats: category,
                      onEdit: () => _showEditBudget(context, ref, category),
                    ),
                  ),
                ),

                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoBudgetView(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 80,
              color: colorScheme.onSurfaceVariant.withAlpha(100),
            ),
            const SizedBox(height: 24),
            Text('No Budgets Set', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Set monthly budgets for your categories to track your spending and stay on target.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _showBudgetSettings(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Set Up Budgets'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBudgetSettings(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _BudgetSettingsSheet(),
    );
  }

  void _showEditBudget(
    BuildContext context,
    WidgetRef ref,
    CategoryBudgetStats category,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _EditBudgetSheet(category: category),
    );
  }
}

/// Sheet for setting budgets for all categories
class _BudgetSettingsSheet extends ConsumerWidget {
  const _BudgetSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final theme = Theme.of(context);

    return FutureBuilder(
      future: (db.select(
        db.categories,
      )..where((c) => c.type.equals('expense'))).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Failed to load categories.',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please try again or close this sheet.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No expense categories found.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final categories = snapshot.data!;

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withAlpha(
                          100,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Set Category Budgets',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set monthly spending limits for each category',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        return _CategoryBudgetTile(category: category);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CategoryBudgetTile extends ConsumerStatefulWidget {
  final Category category;

  const _CategoryBudgetTile({required this.category});

  @override
  ConsumerState<_CategoryBudgetTile> createState() =>
      _CategoryBudgetTileState();
}

class _CategoryBudgetTileState extends ConsumerState<_CategoryBudgetTile> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.category.monthlyBudget?.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(IconHelper.getIcon(widget.category.icon), size: 20),
      ),
      title: Text(widget.category.name),
      trailing: SizedBox(
        width: 120,
        child: TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            prefixText: '₹',
            hintText: '0',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onEditingComplete: () {
            final text = _controller.text;
            final budget = double.tryParse(text) ?? 0;
            ref.read(updateCategoryBudgetProvider)(widget.category.id, budget);
          },
          onSubmitted: (value) {
            final budget = double.tryParse(value) ?? 0;
            ref.read(updateCategoryBudgetProvider)(widget.category.id, budget);
          },
        ),
      ),
    );
  }
}

/// Sheet for editing a single category's budget
class _EditBudgetSheet extends ConsumerStatefulWidget {
  final CategoryBudgetStats category;

  const _EditBudgetSheet({required this.category});

  @override
  ConsumerState<_EditBudgetSheet> createState() => _EditBudgetSheetState();
}

class _EditBudgetSheetState extends ConsumerState<_EditBudgetSheet> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.category.budget.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edit Budget: ${widget.category.name}',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Monthly Budget',
              prefixText: '₹',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                final rawText = _controller.text.trim();

                if (rawText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a budget amount'),
                    ),
                  );
                  return;
                }

                final parsedBudget = double.tryParse(rawText);
                if (parsedBudget == null || parsedBudget < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid non-negative number'),
                    ),
                  );
                  return;
                }

                try {
                  // Persist the updated budget for this category
                  await ref.read(updateCategoryBudgetProvider)(
                    widget.category.id,
                    parsedBudget,
                  );

                  if (!mounted) return;
                  Navigator.pop(context);
                } catch (_) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Failed to update budget. Please try again.'),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}
