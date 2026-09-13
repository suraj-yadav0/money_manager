import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/presentation/glass_widgets.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/utils/formatters.dart';
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

    return GlassScaffold(
      appBar: AppBar(
        title: Text(
          'Budget',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
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
                // Month Navigation Header
                _buildMonthNavigator(context, ref),
                const SizedBox(height: 16),

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
      floatingActionButton: (budgetAsync.asData?.value.totalBudget ?? 0) > 0
          ? Padding(
              padding: const EdgeInsets.only(
                bottom: 120,
              ), // Spacing to clear the floating nav bar
              child: FloatingActionButton.extended(
                heroTag: 'budget_fab',
                onPressed: () => _showBudgetSettings(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Set Budget'),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor:
                    Theme.of(context).colorScheme.onPrimaryContainer,
                elevation: 4,
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.narutoOrange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                size: 64,
                color: AppTheme.narutoOrange,
              ),
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

  Widget _buildMonthNavigator(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(budgetSelectedMonthProvider);
    final now = DateTime.now();
    final isCurrentMonth =
        selectedMonth.year == now.year && selectedMonth.month == now.month;

    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      borderRadius: 16,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            iconSize: 20,
            tooltip: 'Previous month',
            onPressed: () {
              ref.read(budgetSelectedMonthProvider.notifier).state =
                  DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
            },
          ),
          Expanded(
            child: Text(
              Formatters.month(selectedMonth),
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            iconSize: 20,
            tooltip: 'Next month',
            onPressed: () {
              ref.read(budgetSelectedMonthProvider.notifier).state =
                  DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
            },
          ),
          if (!isCurrentMonth) ...[
            const SizedBox(width: 4),
            TextButton(
              onPressed: () {
                ref.read(budgetSelectedMonthProvider.notifier).state =
                    DateTime(now.year, now.month, 1);
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Current', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 4),
          ],
        ],
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
      isScrollControlled: true,
      builder: (_) => _EditBudgetSheet(
        categoryId: category.id,
        categoryName: category.name,
        categoryIcon: category.icon,
        currentBudget: category.budget,
      ),
    );
  }
}

/// Sheet for setting budgets for all categories - Redesigned for better UX
class _BudgetSettingsSheet extends ConsumerStatefulWidget {
  const _BudgetSettingsSheet();

  @override
  ConsumerState<_BudgetSettingsSheet> createState() =>
      _BudgetSettingsSheetState();
}

class _BudgetSettingsSheetState extends ConsumerState<_BudgetSettingsSheet> {
  List<Category>? _categories;
  Map<int, double>? _avgSpending;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final db = ref.read(databaseProvider);

      // Fetch all expense categories
      final categories = await (db.select(
        db.categories,
      )..where((c) => c.type.equals('expense'))).get();

      // Fetch average monthly spending per category (last 3 months)
      final avgSpending = await ref.read(categoryAvgSpendingProvider.future);

      if (mounted) {
        setState(() {
          _categories = categories;
          _avgSpending = avgSpending;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return SizedBox(
        height: 300,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  'Failed to load categories',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _error = null;
                    });
                    _loadData();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final categories = _categories!;
    if (categories.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No expense categories found.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    // Split categories into those with budgets and those without
    final withBudget = categories
        .where((c) => (c.monthlyBudget ?? 0) > 0)
        .toList();
    final withoutBudget = categories
        .where((c) => (c.monthlyBudget ?? 0) <= 0)
        .toList();

    // Calculate total budget for summary
    final totalBudget = withBudget.fold<double>(
      0,
      (sum, c) => sum + (c.monthlyBudget ?? 0),
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withAlpha(100),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header with summary
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Set Budgets',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // Total budget summary chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Total: ${Formatters.currency(totalBudget)}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap any category to set or edit its monthly budget',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Category list with sections
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Categories with budgets section
                  if (withBudget.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'Budget Set',
                      count: withBudget.length,
                      icon: Icons.check_circle,
                      iconColor: colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    ...withBudget.map(
                      (category) => _CategoryBudgetTile(
                        category: category,
                        avgSpending: _avgSpending?[category.id],
                        onTap: () => _openEditSheet(category),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Categories without budgets section
                  if (withoutBudget.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'No Budget',
                      count: withoutBudget.length,
                      icon: Icons.add_circle_outline,
                      iconColor: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    ...withoutBudget.map(
                      (category) => _CategoryBudgetTile(
                        category: category,
                        avgSpending: _avgSpending?[category.id],
                        onTap: () => _openEditSheet(category),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _openEditSheet(Category category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditBudgetSheet(
        categoryId: category.id,
        categoryName: category.name,
        categoryIcon: category.icon,
        currentBudget: category.monthlyBudget ?? 0,
        suggestedBudget: _avgSpending?[category.id],
      ),
    ).then((_) {
      // Refresh data after editing
      _loadData();
    });
  }
}

/// Section header for category groups
class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color iconColor;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('$count', style: theme.textTheme.labelSmall),
        ),
      ],
    );
  }
}

/// Category tile with tap-to-edit pattern (no inline TextField)
class _CategoryBudgetTile extends StatelessWidget {
  final Category category;
  final double? avgSpending;
  final VoidCallback onTap;

  const _CategoryBudgetTile({
    required this.category,
    required this.onTap,
    this.avgSpending,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasBudget = (category.monthlyBudget ?? 0) > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasBudget
              ? colorScheme.primary.withAlpha(50)
              : colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Category icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: hasBudget
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  IconHelper.getIcon(category.icon),
                  size: 22,
                  color: hasBudget
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),

              // Category name and suggestion
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (avgSpending != null && avgSpending! > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Avg. spend: ${Formatters.currency(avgSpending!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Budget amount or "Tap to set"
              if (hasBudget)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withAlpha(100),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    Formatters.currency(category.monthlyBudget!),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tap to set',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Enhanced sheet for editing a single category's budget
/// Features: Quick-set chips, suggested budget, keyboard-safe scrolling
class _EditBudgetSheet extends ConsumerStatefulWidget {
  final int categoryId;
  final String categoryName;
  final String categoryIcon;
  final double currentBudget;
  final double? suggestedBudget;

  const _EditBudgetSheet({
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.currentBudget,
    this.suggestedBudget,
  });

  @override
  ConsumerState<_EditBudgetSheet> createState() => _EditBudgetSheetState();
}

class _EditBudgetSheetState extends ConsumerState<_EditBudgetSheet> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isSaving = false;

  // Quick-set budget presets
  static const List<int> _presets = [1000, 2000, 5000, 10000, 20000, 50000];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentBudget > 0
          ? widget.currentBudget.toStringAsFixed(0)
          : '',
    );
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _setAmount(double amount) {
    _controller.text = amount.toStringAsFixed(0);
    // Trigger haptic feedback for better UX
    HapticFeedback.lightImpact();
  }

  Future<void> _saveBudget() async {
    if (_isSaving) return;

    final rawText = _controller.text.trim();
    final parsedBudget = double.tryParse(rawText) ?? 0;

    if (parsedBudget < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Budget cannot be negative')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ref.read(updateCategoryBudgetProvider)(
        widget.categoryId,
        parsedBudget,
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update budget. Try again.')),
      );
    }
  }

  String _formatPreset(int amount) {
    if (amount >= 1000) {
      return '₹${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)}K';
    }
    return '₹$amount';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: bottomInset + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withAlpha(100),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Category header with icon
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    IconHelper.getIcon(widget.categoryIcon),
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.categoryName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Set monthly budget',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Suggested budget banner (if available)
            if (widget.suggestedBudget != null &&
                widget.suggestedBudget! > 0) ...[
              InkWell(
                onTap: () => _setAmount(widget.suggestedBudget!),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer.withAlpha(100),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.tertiary.withAlpha(50),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 20,
                        color: colorScheme.tertiary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Suggested Budget',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.onTertiaryContainer,
                              ),
                            ),
                            Text(
                              '${Formatters.currency(widget.suggestedBudget!)} based on your avg. spending',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onTertiaryContainer
                                    .withAlpha(180),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.tertiary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Use',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onTertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Budget input field
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
                hintText: '0',
                hintStyle: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant.withAlpha(100),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withAlpha(100),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),

            const SizedBox(height: 16),

            // Quick-set chips
            Text(
              'Quick set',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets.map((amount) {
                return ActionChip(
                  label: Text(_formatPreset(amount)),
                  onPressed: () => _setAmount(amount.toDouble()),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                // Clear/Remove budget button
                if (widget.currentBudget > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () {
                              _controller.text = '0';
                              _saveBudget();
                            },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Remove Budget'),
                    ),
                  ),
                if (widget.currentBudget > 0) const SizedBox(width: 12),

                // Save button
                Expanded(
                  flex: widget.currentBudget > 0 ? 1 : 2,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _saveBudget,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Budget'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
