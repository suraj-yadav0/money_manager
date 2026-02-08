import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/presentation/glass_widgets.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/formatters.dart';
import '../../dashboard/providers/dashboard_providers.dart';

/// Settings screen for user preferences and monthly income
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _incomeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _hasChanges = false;
  double _originalIncome = 0;
  String _selectedCurrency = AppConstants.defaultCurrency;
  String _originalCurrency = AppConstants.defaultCurrency;
  bool _showIncomeChart = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final db = ref.read(databaseProvider);
    final settings = await db.select(db.userSettings).getSingleOrNull();

    if (settings != null && mounted) {
      setState(() {
        _originalIncome = settings.monthlyIncome;
        _originalCurrency = settings.currency;
        _selectedCurrency = settings.currency;
        _showIncomeChart = settings.showIncomeChart;

        final symbol =
            AppConstants.supportedCurrencies[settings.currency] ??
            AppConstants.currencySymbol;
        _incomeController.text = Formatters.currency(
          settings.monthlyIncome,
          symbol: symbol,
        ).replaceAll(',', '').replaceAll(symbol, '').trim();
      });
    }
  }

  @override
  void dispose() {
    _incomeController.dispose();
    super.dispose();
  }

  void _onIncomeChanged(String value) {
    final newIncome = double.tryParse(value.replaceAll(',', '')) ?? 0;
    setState(() {
      _hasChanges =
          newIncome != _originalIncome ||
          _selectedCurrency != _originalCurrency;
    });
  }

  void _onCurrencyChanged(String? newCurrency) {
    if (newCurrency == null) return;
    setState(() {
      _selectedCurrency = newCurrency;
      _hasChanges =
          _selectedCurrency != _originalCurrency ||
          (double.tryParse(_incomeController.text.replaceAll(',', '')) ?? 0) !=
              _originalIncome ||
          _showIncomeChart !=
              (ref.read(userSettingsStreamProvider).value?.showIncomeChart ??
                  false);
    });
  }

  void _onShowIncomeChartChanged(bool value) {
    setState(() {
      _showIncomeChart = value;
      _hasChanges =
          true; // Simplified change tracking for now, or compare with original
    });
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final db = ref.read(databaseProvider);
      final newIncome =
          double.tryParse(_incomeController.text.replaceAll(',', '')) ?? 0;

      // Update user settings
      await (db.update(db.userSettings)..where((t) => t.id.equals(1))).write(
        UserSettingsCompanion(
          monthlyIncome: Value(newIncome),
          currency: Value(_selectedCurrency),
          showIncomeChart: Value(_showIncomeChart),
        ),
      );

      // If income changed, create/update the recurring income transaction for this month
      if (newIncome != _originalIncome) {
        await _updateMonthlyIncomeTransaction(db, newIncome);
      }

      // Refresh providers
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(
        userSettingsProvider,
      ); // Also invalidate settings to update currency globally

      setState(() {
        _originalIncome = newIncome;
        _originalCurrency = _selectedCurrency;
        _hasChanges = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving settings: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateMonthlyIncomeTransaction(
    AppDatabase db,
    double newIncome,
  ) async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);

    // Find the Salary income category
    final salaryCategory = await (db.select(
      db.categories,
    )..where((c) => c.name.equals('Salary'))).getSingleOrNull();

    if (salaryCategory == null || salaryCategory.type != 'income') return;

    // Check if there's already a salary transaction this month
    // Query all income transactions for salary category and filter in Dart
    final salaryTransactions = await (db.select(
      db.transactions,
    )..where((t) => t.categoryId.equals(salaryCategory.id))).get();

    final existingTransaction = salaryTransactions
        .where(
          (t) =>
              t.type == 'income' &&
              t.timestamp.isAfter(
                monthStart.subtract(const Duration(seconds: 1)),
              ) &&
              t.timestamp.isBefore(monthEnd.add(const Duration(seconds: 1))),
        )
        .firstOrNull;

    if (existingTransaction != null) {
      // Update existing transaction
      await (db.update(db.transactions)
            ..where((t) => t.id.equals(existingTransaction.id)))
          .write(TransactionsCompanion(amount: Value(newIncome)));
    } else {
      // Create new income transaction
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              amount: newIncome,
              type: 'income',
              categoryId: salaryCategory.id,
              timestamp: monthStart,
              note: const Value('Monthly Salary'),
              isRecurring: const Value(true),
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GlassScaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _isLoading ? null : _saveSettings,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Income Section
            _buildSectionHeader(context, 'Income', Icons.attach_money),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Income',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _incomeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        prefixText:
                            '${AppConstants.supportedCurrencies[_selectedCurrency]} ',
                        hintText: 'Enter your monthly income',
                        filled: true,
                        fillColor: colorScheme.surfaceContainerLowest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your income';
                        }
                        final income = double.tryParse(
                          value.replaceAll(',', ''),
                        );
                        if (income == null || income <= 0) {
                          return 'Please enter a valid amount';
                        }
                        return null;
                      },
                      onChanged: _onIncomeChanged,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This will update your recurring salary transaction',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Preferences Section
            _buildSectionHeader(context, 'Preferences', Icons.tune),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        AppConstants.supportedCurrencies[_selectedCurrency] ??
                            '?',
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: const Text('Currency'),
                    subtitle: Text('Selected: $_selectedCurrency'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showCurrencyPicker,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: Icon(
                      Icons.show_chart,
                      color: colorScheme.primary,
                    ),
                    title: const Text('Show Income Chart'),
                    subtitle: const Text('Display income trend on dashboard'),
                    value: _showIncomeChart,
                    onChanged: _onShowIncomeChartChanged,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // About Section
            _buildSectionHeader(context, 'About', Icons.info_outline),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colorScheme.primary, colorScheme.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                    title: Text(
                      'Money Manager',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text('Version 1.0.0'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.code, color: colorScheme.primary),
                    title: const Text('Built with Flutter'),
                    subtitle: const Text('Cross-platform personal finance app'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Data Management Section
            _buildSectionHeader(context, 'Data', Icons.storage_outlined),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.download_outlined,
                      color: colorScheme.primary,
                    ),
                    title: const Text('Export Data'),
                    subtitle: const Text('Download your transactions'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Export feature coming soon'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.delete_outline,
                      color: colorScheme.error,
                    ),
                    title: Text(
                      'Clear All Data',
                      style: TextStyle(color: colorScheme.error),
                    ),
                    subtitle: const Text(
                      'Delete all transactions and settings',
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: colorScheme.error,
                    ),
                    onTap: () => _showClearDataDialog(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Future<void> _showClearDataDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete all your transactions, categories, '
          'goals, and settings. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Clear data logic would go here
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clear data feature coming soon'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showCurrencyPicker() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Currency'),
        children: AppConstants.supportedCurrencies.entries.map((entry) {
          final isSelected = entry.key == _selectedCurrency;
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, entry.key),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(entry.key, style: const TextStyle(fontSize: 16)),
                  ],
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );

    if (result != null) {
      _onCurrencyChanged(result);
    }
  }
}
