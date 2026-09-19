import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/presentation/glass_widgets.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../accounts/screens/bank_accounts_screen.dart';
import '../../sms/screens/sms_card_deck_screen.dart';
import '../../sms/providers/sms_providers.dart';
import '../../../core/services/backup_service.dart';

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
              _originalIncome;
    });
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final db = ref.read(databaseProvider);
      final newIncome =
          double.tryParse(_incomeController.text.replaceAll(',', '')) ?? 0;

      // Upsert user settings
      await db.into(db.userSettings).insertOnConflictUpdate(
        UserSettingsCompanion(
          id: const Value(1),
          monthlyIncome: Value(newIncome),
          currency: Value(_selectedCurrency),
          updatedAt: Value(DateTime.now()),
        ),
      );

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

  Future<void> _exportBackup() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preparing backup file...'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await ref.read(backupServiceProvider).exportAndShareBackup();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _importBackup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Restore Backup'),
        content: const Text(
          'Importing a backup will merge transactions, categories, bank accounts, goals, and assets into your local database. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Select File'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final stats = await ref.read(backupServiceProvider).importBackup(ref);
      if (stats != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Backup restored: ${stats['transactions']} transactions, ${stats['categories']} categories, ${stats['bankAccounts']} accounts',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
            // Account & Cloud Sync Section
            _buildSectionHeader(context, 'Account & Cloud Sync', Icons.cloud_sync_outlined),
            const SizedBox(height: 12),
            _buildAccountCloudSyncCard(context),

            const SizedBox(height: 24),

            // Bank Accounts & SMS Auto-Detection Section
            _buildSectionHeader(context, 'Bank Accounts & SMS Auto-Detection', Icons.auto_awesome),
            const SizedBox(height: 12),
            _buildSmsAndBankAccountsCard(context),

            const SizedBox(height: 24),

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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Monthly income baseline for budget pacing and savings analysis',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (_hasChanges) ...[
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _saveSettings,
                            style: ElevatedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Save'),
                          ),
                        ],
                      ],
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
                    title: const Text('Export Complete Backup (JSON)'),
                    subtitle: const Text(
                      'Share or save all transactions, goals, accounts, and assets',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _exportBackup,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.upload_outlined,
                      color: colorScheme.primary,
                    ),
                    title: const Text('Import Backup from JSON'),
                    subtitle: const Text(
                      'Restore database from exported JSON backup file',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _importBackup,
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

  Widget _buildAccountCloudSyncCard(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final syncState = ref.watch(syncNotifierProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: user != null
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHighest,
                child: Icon(
                  user != null ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                  color: user != null
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              title: Text(
                user != null ? (user.email ?? 'Cloud Account') : 'Offline Guest Mode',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Text(
                user != null
                    ? (syncState.message ?? 'Cloud Data Sync Active')
                    : 'Data stored locally on this device only',
                style: theme.textTheme.bodySmall,
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (user != null) ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.password, size: 16),
                    label: const Text('Password'),
                    onPressed: () => _showChangePasswordDialog(context),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: syncState.status == SyncStatus.syncing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync, size: 16),
                    label: const Text('Sync Now'),
                    onPressed: syncState.status == SyncStatus.syncing
                        ? null
                        : () async {
                            final res = await ref
                                .read(syncNotifierProvider.notifier)
                                .triggerSync();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res.message),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.logout, size: 16, color: Colors.redAccent),
                    label: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
                    onPressed: () async {
                      await ref.read(authServiceProvider).signOut();
                    },
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.login, size: 16),
                    label: const Text('Sign In / Connect Cloud'),
                    onPressed: () async {
                      await ref.read(guestModeProvider.notifier).disableGuestMode();
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final authService = ref.read(authServiceProvider);
    final isPasswordUser = authService.isPasswordUser;
    final userEmail = authService.currentUser?.email ?? '';

    if (!isPasswordUser) {
      return showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.security, color: Colors.amber, size: 24),
              const SizedBox(width: 8),
              Text(
                'Account Security',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'You are currently signed in with Google ($userEmail). Your authentication is managed by your Google account.',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                'To also sign in using email and password, you can request a password setup email.',
                style: GoogleFonts.inter(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                try {
                  await authService.resetPassword(userEmail);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Password setup link sent to $userEmail'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: const Text('Send Setup Email'),
            ),
          ],
        ),
      );
    }

    final currentPwdController = TextEditingController();
    final newPwdController = TextEditingController();
    final confirmPwdController = TextEditingController();
    bool isUpdating = false;
    String? dialogError;
    bool obscureCurrent = true;
    bool obscureNew = true;

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.password, color: Colors.amber, size: 24),
              const SizedBox(width: 8),
              Text(
                'Change Password',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Update the password for $userEmail',
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                if (dialogError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            dialogError!,
                            style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                TextField(
                  controller: currentPwdController,
                  obscureText: obscureCurrent,
                  style: const TextStyle(color: Colors.white),
                  enabled: !isUpdating,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    labelStyle: const TextStyle(color: Colors.white60),
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.white60),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: Colors.white60,
                        size: 20,
                      ),
                      onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPwdController,
                  obscureText: obscureNew,
                  style: const TextStyle(color: Colors.white),
                  enabled: !isUpdating,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    labelStyle: const TextStyle(color: Colors.white60),
                    prefixIcon: const Icon(Icons.lock_reset, color: Colors.white60),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: Colors.white60,
                        size: 20,
                      ),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPwdController,
                  obscureText: obscureNew,
                  style: const TextStyle(color: Colors.white),
                  enabled: !isUpdating,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    labelStyle: const TextStyle(color: Colors.white60),
                    prefixIcon: const Icon(Icons.check, color: Colors.white60),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: isUpdating
                        ? null
                        : () async {
                            try {
                              await authService.resetPassword(userEmail);
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Password reset link sent to $userEmail'),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              setDialogState(() {
                                dialogError = e.toString().replaceAll('Exception:', '').trim();
                              });
                            }
                          },
                    child: Text(
                      'Forgot current password?',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUpdating ? null : () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isUpdating
                  ? null
                  : () async {
                      final currentPwd = currentPwdController.text;
                      final newPwd = newPwdController.text;
                      final confirmPwd = confirmPwdController.text;

                      if (currentPwd.isEmpty) {
                        setDialogState(() => dialogError = 'Please enter your current password.');
                        return;
                      }
                      if (newPwd.length < 6) {
                        setDialogState(() => dialogError = 'New password must be at least 6 characters.');
                        return;
                      }
                      if (newPwd != confirmPwd) {
                        setDialogState(() => dialogError = 'New passwords do not match.');
                        return;
                      }

                      setDialogState(() {
                        isUpdating = true;
                        dialogError = null;
                      });

                      try {
                        await authService.changePassword(
                          currentPassword: currentPwd,
                          newPassword: newPwd,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password updated successfully!'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          isUpdating = false;
                          dialogError = e.toString().replaceAll('Exception:', '').trim();
                        });
                      }
                    },
              child: isUpdating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Update Password'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmsAndBankAccountsCard(BuildContext context) {
    final pendingCount = ref.watch(pendingSmsCountProvider);
    final scanState = ref.watch(smsScanNotifierProvider);

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance_rounded, color: Colors.blue),
            ),
            title: const Text('Manage Bank Accounts & Cards'),
            subtitle: const Text('Configure accounts, credit cards and starting balances'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BankAccountsScreen()),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.narutoOrange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.style_rounded, color: AppTheme.narutoOrange),
            ),
            title: const Text('Review SMS Transactions'),
            subtitle: Text(
              pendingCount > 0
                  ? '$pendingCount pending swipe cards to review'
                  : 'All detected SMS transactions reviewed',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pendingCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.narutoOrange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$pendingCount NEW',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SmsCardDeckScreen()),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: scanState.isScanning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green),
                    )
                  : const Icon(Icons.sms_outlined, color: Colors.green),
            ),
            title: const Text('Scan SMS Inbox Now'),
            subtitle: const Text('Scan recent bank SMS messages from Android inbox'),
            trailing: const Icon(Icons.sync),
            onTap: scanState.isScanning
                ? null
                : () async {
                    final res = await ref
                        .read(smsScanNotifierProvider.notifier)
                        .scanInbox(forceFullScan: true);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(res.message),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
          ),
        ],
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

    if (confirmed == true && context.mounted) {
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
