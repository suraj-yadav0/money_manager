import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/glass_widgets.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/split_providers.dart';
import '../widgets/add_group_sheet.dart';
import '../widgets/split_group_card.dart';
import 'split_group_detail_screen.dart';

class SplitScreen extends ConsumerWidget {
  const SplitScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(activeSplitGroupsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassScaffold(
      appBar: AppBar(
        title: const Text('Split Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_rounded),
            color: AppTheme.narutoOrange,
            onPressed: () => _showAddGroupSheet(context),
          ),
        ],
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (groups) {
          if (groups.isEmpty) {
            return _EmptyState(onCreateGroup: () => _showAddGroupSheet(context));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            itemCount: groups.length,
            itemBuilder: (context, i) {
              final group = groups[i];
              return _GroupCardWrapper(
                group: group,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SplitGroupDetailScreen(group: group),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.neonGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.narutoOrange.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: () => _showAddGroupSheet(context),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  void _showAddGroupSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1A1A2E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const AddGroupSheet(),
    );
  }
}

// ---------------------------------------------------------------------------
// Group card wrapper (fetches member and expense counts)
// ---------------------------------------------------------------------------

class _GroupCardWrapper extends ConsumerWidget {
  final dynamic group;
  final VoidCallback onTap;

  const _GroupCardWrapper({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(splitGroupMembersProvider(group.id));
    final expensesAsync = ref.watch(splitGroupExpensesProvider(group.id));

    final memberCount = membersAsync.valueOrNull?.length ?? 0;
    final expenseCount = expensesAsync.valueOrNull?.length ?? 0;

    return SplitGroupCard(
      group: group,
      memberCount: memberCount,
      expenseCount: expenseCount,
      onTap: onTap,
      onDelete: () async {
        final confirmed = await _confirmDelete(context);
        if (confirmed) {
          await ref.read(splitServiceProvider).deleteGroup(group.id);
        }
      },
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Group'),
            content:
                const Text('This will delete all expenses in this group. Continue?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateGroup;

  const _EmptyState({required this.onCreateGroup});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                gradient: AppTheme.neonGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.group_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No split groups yet',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Create a group to start splitting expenses\nwith friends and family',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onCreateGroup,
              icon: const Icon(Icons.add),
              label: const Text('Create Group'),
            ),
          ],
        ),
      ),
    );
  }
}
