import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/presentation/glass_widgets.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/icon_helper.dart';

import 'package:drift/drift.dart' show Value;
import '../../../core/database/database.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/providers/auth_providers.dart';
import 'add_transaction_screen.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../accounts/providers/account_providers.dart';
import '../../goals/providers/goals_provider.dart';

class AllTransactionsScreen extends ConsumerStatefulWidget {
  const AllTransactionsScreen({super.key});

  @override
  ConsumerState<AllTransactionsScreen> createState() =>
      _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends ConsumerState<AllTransactionsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedType = 'all'; // 'all', 'expense', 'income'
  int? _selectedCategoryId;
  bool _hideGestureTip = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(allTransactionsProvider);
    final currencySymbol = ref.watch(currencyProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GlassScaffold(
      appBar: AppBar(
        title: Text(
          'All Transactions',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (transactions) {
          if (transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: colorScheme.onSurfaceVariant.withAlpha(100),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No transactions found',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          // Extract unique categories from current transactions
          final availableCategories = <Category>[];
          final seenCategoryIds = <int>{};
          for (final item in transactions) {
            if (item.category != null && !seenCategoryIds.contains(item.category!.id)) {
              seenCategoryIds.add(item.category!.id);
              availableCategories.add(item.category!);
            }
          }
          availableCategories.sort((a, b) => a.name.compareTo(b.name));

          // Filter transactions
          final filtered = transactions.where((item) {
            if (_selectedType == 'expense' && item.transaction.type != 'expense') {
              return false;
            }
            if (_selectedType == 'income' && item.transaction.type != 'income') {
              return false;
            }
            if (_selectedCategoryId != null &&
                item.transaction.categoryId != _selectedCategoryId) {
              return false;
            }
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              final noteMatch = (item.transaction.note ?? '').toLowerCase().contains(q);
              final catMatch = (item.category?.name ?? '').toLowerCase().contains(q);
              final paymentMatch =
                  (item.transaction.paymentMode ?? '').toLowerCase().contains(q);
              final amountStr = item.transaction.amount.toString();
              final amountFormatted = Formatters.currency(
                item.transaction.amount,
                symbol: '',
              ).toLowerCase();
              final amountMatch = amountStr.contains(q) || amountFormatted.contains(q);
              if (!noteMatch && !catMatch && !paymentMatch && !amountMatch) {
                return false;
              }
            }
            return true;
          }).toList();

          // Group filtered transactions by date
          final grouped = <String, List<TransactionWithCategory>>{};
          for (var item in filtered) {
            final dateKey = Formatters.date(item.transaction.timestamp);
            if (!grouped.containsKey(dateKey)) {
              grouped[dateKey] = [];
            }
            grouped[dateKey]!.add(item);
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allTransactionsProvider);
            },
            child: Column(
              children: [
                // Search Input Field
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withAlpha(120),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withAlpha(70),
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search note, payee, amount...',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 12,
                        ),
                      ),
                    ),
                  ),
                ),

                // Filter Chips Bar
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _selectedType == 'all' && _selectedCategoryId == null,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedType = 'all';
                              _selectedCategoryId = null;
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Expenses'),
                        selected: _selectedType == 'expense',
                        onSelected: (selected) {
                          setState(() {
                            _selectedType = selected ? 'expense' : 'all';
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Income'),
                        selected: _selectedType == 'income',
                        onSelected: (selected) {
                          setState(() {
                            _selectedType = selected ? 'income' : 'all';
                          });
                        },
                      ),
                      ...availableCategories.map((cat) {
                        final isSelected = _selectedCategoryId == cat.id;
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: FilterChip(
                            label: Text(cat.name),
                            selected: isSelected,
                            avatar: Icon(IconHelper.getIcon(cat.icon), size: 14),
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategoryId = selected ? cat.id : null;
                              });
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                // Dismissible Gesture Cue Tip
                if (!_hideGestureTip) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withAlpha(60),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: colorScheme.primary.withAlpha(35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.swipe_outlined, size: 16, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tip: Swipe right to delete, left to edit',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => setState(() => _hideGestureTip = true),
                            child: Icon(
                              Icons.close,
                              size: 15,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 6),

                // Main Transaction List or Empty Match State
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 52,
                                  color: colorScheme.onSurfaceVariant.withAlpha(120),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'No matching transactions',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Try adjusting your search query or filters',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                      _selectedType = 'all';
                                      _selectedCategoryId = null;
                                    });
                                  },
                                  icon: const Icon(Icons.clear_all, size: 16),
                                  label: const Text('Clear Filters'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: grouped.length,
                          itemBuilder: (context, index) {
                            final dateKey = grouped.keys.elementAt(index);
                            final items = grouped[dateKey]!;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    _getDateHeader(dateKey),
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  child: Column(
                                    children: items.asMap().entries.map((entry) {
                                      final itemIndex = entry.key;
                                      final item = entry.value;
                                      final isLast = itemIndex == items.length - 1;
                                      final isExpense =
                                          item.transaction.type == 'expense';

                                      return Column(
                                        children: [
                                          Dismissible(
                                            key: Key(item.transaction.id.toString()),
                                            direction: DismissDirection.horizontal,
                                            background: Container(
                                              color: colorScheme.error,
                                              alignment: Alignment.centerLeft,
                                              padding: const EdgeInsets.only(left: 24),
                                              child: const Icon(
                                                Icons.delete,
                                                color: Colors.white,
                                              ),
                                            ),
                                            secondaryBackground: Container(
                                              color: AppTheme.success,
                                              alignment: Alignment.centerRight,
                                              padding: const EdgeInsets.only(right: 24),
                                              child: const Icon(
                                                Icons.edit,
                                                color: Colors.white,
                                              ),
                                            ),
                                            confirmDismiss: (direction) async {
                                              if (direction ==
                                                  DismissDirection.startToEnd) {
                                                // Swipe left-to-right: Delete
                                                return await _confirmDelete(
                                                  context,
                                                  ref,
                                                  item,
                                                );
                                              } else {
                                                // Swipe right-to-left: Edit
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        AddTransactionScreen(
                                                      transactionToEdit: item,
                                                    ),
                                                  ),
                                                );
                                                return false;
                                              }
                                            },
                                            onDismissed: (direction) {
                                              if (direction ==
                                                  DismissDirection.startToEnd) {
                                                _deleteTransaction(
                                                  context,
                                                  ref,
                                                  item,
                                                );
                                              }
                                            },
                                            child: InkWell(
                                              onTap: () {
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        AddTransactionScreen(
                                                      transactionToEdit: item,
                                                    ),
                                                  ),
                                                );
                                              },
                                              onLongPress: () async {
                                                final confirmed =
                                                    await _confirmDelete(
                                                  context,
                                                  ref,
                                                  item,
                                                );
                                                if (confirmed == true &&
                                                    context.mounted) {
                                                  _deleteTransaction(
                                                    context,
                                                    ref,
                                                    item,
                                                  );
                                                }
                                              },
                                              child: ListTile(
                                                leading: Container(
                                                  width: 44,
                                                  height: 44,
                                                  decoration: BoxDecoration(
                                                    color: isExpense
                                                        ? colorScheme
                                                            .errorContainer
                                                            .withAlpha(100)
                                                        : AppTheme.success
                                                            .withAlpha(30),
                                                    borderRadius:
                                                        BorderRadius.circular(12),
                                                  ),
                                                  child: Icon(
                                                    IconHelper.getIcon(
                                                      item.category?.icon,
                                                    ),
                                                    color: isExpense
                                                        ? colorScheme.error
                                                        : AppTheme.success,
                                                    size: 22,
                                                  ),
                                                ),
                                                title: Text(
                                                  item.category?.name ?? 'Unknown',
                                                  style:
                                                      theme.textTheme.titleSmall,
                                                ),
                                                subtitle: Row(
                                                  children: [
                                                    if (item.transaction
                                                            .receiptImagePath !=
                                                        null) ...[
                                                      Icon(
                                                        Icons.receipt,
                                                        size: 14,
                                                        color:
                                                            colorScheme.primary,
                                                      ),
                                                      const SizedBox(width: 4),
                                                    ],
                                                    Expanded(
                                                      child: Text(
                                                        item.transaction.note
                                                                    ?.isNotEmpty ==
                                                                true
                                                            ? item.transaction
                                                                .note!
                                                            : Formatters
                                                                .relativeDate(
                                                                item.transaction
                                                                    .timestamp,
                                                              ),
                                                        style: theme
                                                            .textTheme.bodySmall,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                trailing: Text(
                                                  '${isExpense ? '-' : '+'}${Formatters.currency(item.transaction.amount, symbol: currencySymbol)}',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: isExpense
                                                        ? colorScheme.error
                                                        : AppTheme.success,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (!isLast)
                                            Divider(
                                              height: 1,
                                              indent: 72,
                                              endIndent: 16,
                                              color: colorScheme.outlineVariant
                                                  .withAlpha(50),
                                            ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getDateHeader(String dateStr) {
    if (dateStr == Formatters.date(DateTime.now())) {
      return 'Today';
    } else if (dateStr ==
        Formatters.date(DateTime.now().subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return dateStr;
  }

  Future<bool?> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TransactionWithCategory item,
  ) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text(
          'Are you sure you want to delete this transaction?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTransaction(
    BuildContext context,
    WidgetRef ref,
    TransactionWithCategory item,
  ) async {
    final db = ref.read(databaseProvider);

    // Rollback bank account balance if linked
    if (item.transaction.accountId != null) {
      final acc = await (db.select(db.bankAccounts)
            ..where((a) => a.id.equals(item.transaction.accountId!)))
          .getSingleOrNull();
      if (acc != null) {
        final isExpense = item.transaction.type == 'expense';
        final restoredBal = isExpense
            ? acc.balance + item.transaction.amount
            : acc.balance - item.transaction.amount;
        await (db.update(db.bankAccounts)
              ..where((a) => a.id.equals(acc.id)))
            .write(BankAccountsCompanion(
          balance: Value(restoredBal),
          updatedAt: Value(DateTime.now()),
        ));
      }
    }

    // Rollback goal savedAmount if linked
    if (item.transaction.goalId != null) {
      final goal = await (db.select(db.goals)
            ..where((g) => g.id.equals(item.transaction.goalId!)))
          .getSingleOrNull();
      if (goal != null) {
        final restoredSaved = (goal.savedAmount - item.transaction.amount)
            .clamp(0.0, double.infinity);
        await (db.update(db.goals)..where((g) => g.id.equals(goal.id))).write(
          GoalsCompanion(
            savedAmount: Value(restoredSaved),
            isCompleted: Value(restoredSaved >= goal.targetAmount),
          ),
        );
      }
    }

    // Delete locally
    await (db.delete(
      db.transactions,
    )..where((t) => t.id.equals(item.transaction.id))).go();

    // Delete remotely from Cloud Firestore
    if (item.transaction.syncId != null) {
      ref
          .read(syncServiceProvider)
          .deleteRemoteDoc('transactions', item.transaction.syncId);
    }

    // Refresh dashboard and lists
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(recentTransactionsProvider);
    ref.invalidate(allTransactionsProvider);
    ref.invalidate(bankAccountsStreamProvider);
    ref.invalidate(activeGoalsProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction deleted'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
