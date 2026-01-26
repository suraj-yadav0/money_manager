import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/database/database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../providers/goals_provider.dart';
import '../widgets/add_contribution_sheet.dart';
import '../widgets/edit_goal_sheet.dart';
import '../widgets/goal_card.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(activeGoalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Savings Goals',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
      ),
      body: goalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (goals) {
          if (goals.isEmpty) {
            return _NoGoalView(
              onCreateGoal: () => _showCreateGoalSheet(context, ref),
            );
          }
          return _GoalsListView(
            goals: goals,
            onCreateGoal: () => _showCreateGoalSheet(context, ref),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateGoalSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Goal'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }

  void _showCreateGoalSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CreateGoalSheet(ref: ref),
    );
  }
}

class _NoGoalView extends StatelessWidget {
  final VoidCallback onCreateGoal;

  const _NoGoalView({required this.onCreateGoal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.savings_outlined,
                size: 48,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Savings Goals',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Set a savings goal to track your progress and stay motivated.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onCreateGoal,
              icon: const Icon(Icons.add),
              label: const Text('Create Goal'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalsListView extends ConsumerWidget {
  final List<Goal> goals;
  final VoidCallback onCreateGoal;

  const _GoalsListView({required this.goals, required this.onCreateGoal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: goals.length,
      itemBuilder: (context, index) {
        final goal = goals[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GoalCard(
            goal: goal,
            onTap: () => _showGoalDetails(context, ref, goal),
            onAddContribution: () => _showAddContribution(context, ref, goal),
            onEdit: () => _showEditGoal(context, ref, goal),
            onDelete: () => _confirmDelete(context, ref, goal),
          ),
        );
      },
    );
  }

  void _showGoalDetails(BuildContext context, WidgetRef ref, Goal goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _GoalDetailsSheet(goal: goal),
    );
  }

  void _showAddContribution(BuildContext context, WidgetRef ref, Goal goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddContributionSheet(goal: goal),
    ).then((result) {
      if (result == true && context.mounted) {
        // Check if goal was just completed
        final updatedGoal = ref.read(goalByIdProvider(goal.id)).value;
        if (updatedGoal?.isCompleted == true && !goal.isCompleted) {
          _showCelebration(context, updatedGoal!);
        }
      }
    });
  }

  void _showEditGoal(BuildContext context, WidgetRef ref, Goal goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => EditGoalSheet(goal: goal),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Goal goal,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal?'),
        content: Text(
          'Are you sure you want to delete "${goal.name}"? '
          'This will also delete all contribution history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final goalService = ref.read(goalServiceProvider);
      await goalService.deleteGoal(goal.id);
      ref.invalidate(activeGoalsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Goal deleted')));
      }
    }
  }

  void _showCelebration(BuildContext context, Goal goal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'Goal Completed!',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Congratulations! You\'ve reached your goal of ${Formatters.currency(goal.targetAmount)} for "${goal.name}"!',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Awesome!'),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet showing goal details and contribution history
class _GoalDetailsSheet extends ConsumerWidget {
  final Goal goal;

  const _GoalDetailsSheet({required this.goal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final contributionsAsync = ref.watch(goalContributionsProvider(goal.id));
    final daysRemaining = goal.deadline.difference(DateTime.now()).inDays;
    final remainingAmount = goal.targetAmount - goal.savedAmount;
    final monthsRemaining = (daysRemaining / 30).ceil();
    final monthlySuggestion = monthsRemaining > 0
        ? remainingAmount / monthsRemaining
        : remainingAmount;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withAlpha(100),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  // Goal header
                  Row(
                    children: [
                      Icon(Icons.flag, color: colorScheme.primary, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          goal.name,
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Stats cards
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.savings,
                          label: 'Saved',
                          value: Formatters.currency(goal.savedAmount),
                          color: AppTheme.success,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.flag,
                          label: 'Target',
                          value: Formatters.currency(goal.targetAmount),
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.calendar_today,
                          label: 'Days Left',
                          value: daysRemaining > 0
                              ? '$daysRemaining'
                              : 'Overdue',
                          color: daysRemaining > 0
                              ? colorScheme.primary
                              : AppTheme.danger,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.trending_up,
                          label: 'Save/Month',
                          value: Formatters.currency(monthlySuggestion),
                          color: AppTheme.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Contribution history
                  Text(
                    'Contribution History',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  contributionsAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (e, _) => Text('Error: $e'),
                    data: (contributions) {
                      if (contributions.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withAlpha(100),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.history,
                                size: 40,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No contributions yet',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        children: contributions.map((c) {
                          return Dismissible(
                            key: Key('contribution_${c.id}'),
                            background: Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 20),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.edit,
                                color: colorScheme.primary,
                              ),
                            ),
                            secondaryBackground: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.delete,
                                color: colorScheme.error,
                              ),
                            ),
                            confirmDismiss: (direction) async {
                              if (direction == DismissDirection.endToStart) {
                                // Delete - show confirmation
                                return await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text(
                                          'Delete Contribution?',
                                        ),
                                        content: Text(
                                          'Delete ${Formatters.currency(c.amount)} contribution?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  colorScheme.error,
                                            ),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    ) ??
                                    false;
                              } else {
                                // Edit - show edit dialog
                                await _showEditContributionDialog(
                                  context,
                                  ref,
                                  c,
                                  goal,
                                );
                                return false; // Don't dismiss
                              }
                            },
                            onDismissed: (direction) async {
                              if (direction == DismissDirection.endToStart) {
                                final goalService = ref.read(
                                  goalServiceProvider,
                                );
                                await goalService.deleteContribution(c);
                                ref.invalidate(
                                  goalContributionsProvider(goal.id),
                                );
                                ref.invalidate(activeGoalsProvider);
                                ref.invalidate(activeGoalProvider);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Contribution deleted'),
                                    ),
                                  );
                                }
                              }
                            },
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.success.withAlpha(30),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: AppTheme.success,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                '+${Formatters.currency(c.amount)}',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.success,
                                ),
                              ),
                              subtitle: Text(
                                c.note ?? Formatters.dateTime(c.createdAt),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Text(
                                Formatters.relativeDate(c.createdAt),
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditContributionDialog(
    BuildContext context,
    WidgetRef ref,
    GoalContribution contribution,
    Goal goal,
  ) async {
    final amountController = TextEditingController(
      text: contribution.amount.toStringAsFixed(0),
    );
    final noteController = TextEditingController(text: contribution.note ?? '');
    final colorScheme = Theme.of(context).colorScheme;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Contribution'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withAlpha(100),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: 'Note (optional)',
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withAlpha(100),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newAmount = double.tryParse(
                amountController.text.replaceAll(',', ''),
              );
              if (newAmount != null && newAmount > 0) {
                final goalService = ref.read(goalServiceProvider);
                await goalService.updateContribution(
                  contribution: contribution,
                  newAmount: newAmount,
                  newNote: noteController.text.isNotEmpty
                      ? noteController.text
                      : null,
                );
                ref.invalidate(goalContributionsProvider(goal.id));
                ref.invalidate(activeGoalsProvider);
                ref.invalidate(activeGoalProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    amountController.dispose();
    noteController.dispose();
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateGoalSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;

  const _CreateGoalSheet({required this.ref});

  @override
  ConsumerState<_CreateGoalSheet> createState() => _CreateGoalSheetState();
}

class _CreateGoalSheetState extends ConsumerState<_CreateGoalSheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _deadline = DateTime.now().add(const Duration(days: 90));
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _createGoal() async {
    if (_nameController.text.isEmpty || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final goalService = widget.ref.read(goalServiceProvider);
      final amount = double.parse(_amountController.text.replaceAll(',', ''));

      await goalService.createGoal(
        name: _nameController.text,
        targetAmount: amount,
        deadline: _deadline,
      );

      widget.ref.invalidate(activeGoalsProvider);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
            'Create Savings Goal',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Goal Name',
              hintText: 'e.g., Emergency Fund, Vacation',
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withAlpha(100),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            decoration: InputDecoration(
              labelText: 'Target Amount',
              prefixText: '₹ ',
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withAlpha(100),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Deadline'),
            subtitle: Text(Formatters.date(_deadline)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _deadline,
                firstDate: DateTime.now().add(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
              );
              if (picked != null) {
                setState(() => _deadline = picked);
              }
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isLoading ? null : _createGoal,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Goal'),
            ),
          ),
        ],
      ),
    );
  }
}
