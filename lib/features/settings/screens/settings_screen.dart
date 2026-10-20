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
import '../../../core/presentation/update_prompt_sheet.dart';
import '../../../core/providers/update_providers.dart';
import 'package:url_launcher/url_launcher_string.dart';

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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // Account & Cloud Sync Section
            _buildSectionHeader(context, 'Account & Cloud'),
            _buildAccountCloudSyncCard(context),

            // Bank Accounts & SMS Auto-Detection Section
            _buildSectionHeader(context, 'Bank Accounts & SMS'),
            _buildSmsAndBankAccountsCard(context),

            // Finances & Currency Section
            _buildSectionHeader(context, 'Finances & Currency'),
            _buildFinancesGroup(context),

            // Appearance & Fintech Palette Section
            _buildSectionHeader(context, 'Appearance & Theme'),
            _buildAppearanceCard(context),

            // Data Management Section
            _buildSectionHeader(context, 'Data Management'),
            _buildDataManagementGroup(context),

            // About Section
            _buildSectionHeader(context, 'About Quantro'),
            _buildAboutGroup(context),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancesGroup(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return _buildInsetGroup(
      context,
      footer: 'Monthly baseline used for budget pacing, surplus calculations, and savings rate.',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildIconBadge(
                    icon: Icons.account_balance_wallet_outlined,
                    color: const Color(0xFF10B981),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Monthly Income',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  if (_hasChanges)
                    TextButton(
                      onPressed: _isLoading ? null : _saveSettings,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'Save',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                              ),
                            ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _incomeController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  prefixIcon: Container(
                    width: 36,
                    alignment: Alignment.center,
                    child: Text(
                      AppConstants.supportedCurrencies[_selectedCurrency] ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                  ),
                  hintText: 'Enter monthly income',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1B1B24) : const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your income';
                  }
                  final income = double.tryParse(value.replaceAll(',', ''));
                  if (income == null || income <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
                onChanged: _onIncomeChanged,
              ),
            ],
          ),
        ),
        _buildSettingTile(
          context: context,
          icon: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              AppConstants.supportedCurrencies[_selectedCurrency] ?? '?',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          title: 'Primary Currency',
          subtitle: 'Display currency for transactions and reports',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _selectedCurrency,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight,
                ),
              ),
              const SizedBox(width: 4),
              _buildChevron(context),
            ],
          ),
          onTap: _showCurrencyPicker,
        ),
      ],
    );
  }

  Widget _buildAppearanceCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentMode = ref.watch(themeModeNotifierProvider);
    final currentPalette = ref.watch(fintechPaletteNotifierProvider);
    final borderColor = isDark ? const Color(0x1AFFFFFF) : AppTheme.borderLight;

    return _buildInsetGroup(
      context,
      footer: 'Accent colors dynamically adapt charts, cards, tabs, and action items.',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildIconBadge(
                    icon: Icons.brightness_6_outlined,
                    color: const Color(0xFF6366F1),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Interface Style',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C26) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 0.8),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    _buildThemeModeOption(
                      label: 'System',
                      icon: Icons.brightness_auto_outlined,
                      isSelected: currentMode == ThemeMode.system,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(themeModeNotifierProvider.notifier).setThemeMode(ThemeMode.system);
                      },
                      isDark: isDark,
                    ),
                    _buildThemeModeOption(
                      label: 'Dark',
                      icon: Icons.dark_mode_outlined,
                      isSelected: currentMode == ThemeMode.dark,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(themeModeNotifierProvider.notifier).setThemeMode(ThemeMode.dark);
                      },
                      isDark: isDark,
                    ),
                    _buildThemeModeOption(
                      label: 'Light',
                      icon: Icons.light_mode_outlined,
                      isSelected: currentMode == ThemeMode.light,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(themeModeNotifierProvider.notifier).setThemeMode(ThemeMode.light);
                      },
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildIconBadge(
                    icon: Icons.palette_outlined,
                    color: currentPalette.swatchColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fintech Palette',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          currentPalette.displayName,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: currentPalette.swatchColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 62,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: FintechPalette.values.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final p = FintechPalette.values[index];
                    final isSelected = p == currentPalette;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(fintechPaletteNotifierProvider.notifier).setPalette(p);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? p.swatchColor.withValues(alpha: isDark ? 0.22 : 0.12)
                              : (isDark ? const Color(0xFF1C1C26) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? p.swatchColor : borderColor,
                            width: isSelected ? 1.5 : 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: p.swatchColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark ? Colors.white24 : Colors.black12,
                                  width: 1,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  p.displayName,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  p.subtitle,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: isDark
                                        ? AppTheme.textMutedDark
                                        : AppTheme.textMutedLight,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeModeOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF2A2A38) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? Colors.white : const Color(0xFF0F172A))
                        : (isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountCloudSyncCard(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final syncState = ref.watch(syncNotifierProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return _buildInsetGroup(
      context,
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: user != null
                      ? LinearGradient(
                          colors: [colorScheme.primary, colorScheme.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: user == null
                      ? (isDark ? const Color(0xFF262632) : const Color(0xFFE2E8F0))
                      : null,
                ),
                alignment: Alignment.center,
                child: Icon(
                  user != null ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                  color: user != null
                      ? Colors.white
                      : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user != null ? (user.email ?? 'Cloud Account') : 'Offline Guest Mode',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user != null
                          ? (syncState.message ?? 'Cloud sync active')
                          : 'Data stored locally on this device',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: user != null
              ? Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: syncState.status == SyncStatus.syncing
                            ? const SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync_rounded, size: 15),
                        label: Text(
                          syncState.status == SyncStatus.syncing ? 'Syncing' : 'Sync',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
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
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.lock_outline_rounded, size: 15),
                        label: Text(
                          'Password',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => _showChangePasswordDialog(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.redAccent),
                      tooltip: 'Sign Out',
                      style: IconButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isDark ? const Color(0x1AFFFFFF) : AppTheme.borderLight,
                            width: 0.8,
                          ),
                        ),
                      ),
                      onPressed: () async {
                        await ref.read(authServiceProvider).signOut();
                      },
                    ),
                  ],
                )
              : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () async {
                      await ref.read(guestModeProvider.notifier).disableGuestMode();
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_upload_outlined, size: 16),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Sign In / Connect Cloud',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildAboutGroup(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return _buildInsetGroup(
      context,
      children: [
        Consumer(
          builder: (context, ref, _) {
            final pkgAsync = ref.watch(packageInfoProvider);
            final versionText = pkgAsync.when(
              data: (pkg) => 'v${pkg.version} (${pkg.buildNumber})',
              loading: () => 'v1.0.9',
              error: (err, stack) => 'v1.0.9',
            );

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colorScheme.primary, colorScheme.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 20,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quantro',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Expense & Finance Manager',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E28) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark ? const Color(0x1AFFFFFF) : AppTheme.borderLight,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      versionText,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        Consumer(
          builder: (context, ref, _) {
            final updateState = ref.watch(updateCheckNotifierProvider);
            return _buildSettingTile(
              context: context,
              icon: _buildIconBadge(
                icon: Icons.system_update_rounded,
                color: const Color(0xFF0284C7),
              ),
              title: 'Check for Updates',
              subtitle: updateState.lastChecked != null
                  ? 'Last checked: ${Formatters.date(updateState.lastChecked!)}'
                  : 'Check GitHub releases for updates',
              trailing: updateState.isChecking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _buildChevron(context),
              onTap: updateState.isChecking
                  ? null
                  : () async {
                      final info = await ref
                          .read(updateCheckNotifierProvider.notifier)
                          .checkForUpdate(force: true);
                      if (!context.mounted) return;
                      if (info != null && info.isNewer) {
                        UpdatePromptSheet.show(context, info);
                      } else if (info != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Quantro is up to date (v${info.currentVersion})',
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not check for updates. Check your connection.',
                            ),
                          ),
                        );
                      }
                    },
            );
          },
        ),
        _buildSettingTile(
          context: context,
          icon: _buildIconBadge(
            icon: Icons.open_in_new_rounded,
            color: const Color(0xFF64748B),
          ),
          title: 'Release Notes & Downloads',
          subtitle: 'View GitHub release log and APK downloads',
          trailing: _buildChevron(context),
          onTap: () {
            launchUrlString(
              'https://github.com/suraj-yadav0/money_manager/releases',
              mode: LaunchMode.externalApplication,
            );
          },
        ),
      ],
    );
  }

  Widget _buildDataManagementGroup(BuildContext context) {
    return _buildInsetGroup(
      context,
      children: [
        _buildSettingTile(
          context: context,
          icon: _buildIconBadge(
            icon: Icons.download_rounded,
            color: const Color(0xFF0284C7),
          ),
          title: 'Export Complete Backup',
          subtitle: 'Save transactions, accounts, and goals as JSON',
          trailing: _buildChevron(context),
          onTap: _exportBackup,
        ),
        _buildSettingTile(
          context: context,
          icon: _buildIconBadge(
            icon: Icons.upload_rounded,
            color: const Color(0xFFD97706),
          ),
          title: 'Import Backup from JSON',
          subtitle: 'Restore database from an exported backup file',
          trailing: _buildChevron(context),
          onTap: _importBackup,
        ),
        _buildSettingTile(
          context: context,
          icon: _buildIconBadge(
            icon: Icons.delete_outline_rounded,
            color: const Color(0xFFEF4444),
          ),
          title: 'Clear All Data',
          titleColor: const Color(0xFFEF4444),
          subtitle: 'Permanently remove all local data and settings',
          trailing: _buildChevron(context),
          onTap: () => _showClearDataDialog(context),
        ),
      ],
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
              Expanded(
                child: Text(
                  'Account Security',
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                ),
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
              Expanded(
                child: Text(
                  'Change Password',
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                ),
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
    final theme = Theme.of(context);
    final pendingCount = ref.watch(pendingSmsCountProvider);
    final scanState = ref.watch(smsScanNotifierProvider);
    final isDark = theme.brightness == Brightness.dark;

    return _buildInsetGroup(
      context,
      children: [
        _buildSettingTile(
          context: context,
          icon: _buildIconBadge(
            icon: Icons.account_balance_rounded,
            color: const Color(0xFF3B82F6),
          ),
          title: 'Bank Accounts & Cards',
          subtitle: 'Configure accounts, cards, and opening balances',
          trailing: _buildChevron(context),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BankAccountsScreen()),
            );
          },
        ),
        _buildSettingTile(
          context: context,
          icon: _buildIconBadge(
            icon: Icons.style_rounded,
            color: const Color(0xFF8B5CF6),
          ),
          title: 'Review SMS Transactions',
          subtitle: pendingCount > 0
              ? '$pendingCount pending swipe cards to review'
              : 'All detected SMS transactions reviewed',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pendingCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$pendingCount NEW',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              _buildChevron(context),
            ],
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SmsCardDeckScreen()),
            );
          },
        ),
        _buildSettingTile(
          context: context,
          icon: _buildIconBadge(
            icon: Icons.sms_outlined,
            color: const Color(0xFF10B981),
          ),
          title: 'Scan SMS Inbox Now',
          subtitle: 'Scan recent bank SMS messages from Android inbox',
          trailing: scanState.isScanning
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF10B981),
                  ),
                )
              : Icon(
                  Icons.sync_rounded,
                  size: 20,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
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
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, top: 20, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight,
        ),
      ),
    );
  }

  Widget _buildInsetGroup(
    BuildContext context, {
    required List<Widget> children,
    String? footer,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0x1AFFFFFF) : AppTheme.borderLight;
    final cardBg = isDark ? const Color(0xFF14141B) : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 0.8),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 0.8,
                    thickness: 0.8,
                    indent: 58,
                    endIndent: 0,
                    color: isDark ? const Color(0x14FFFFFF) : const Color(0x0F000000),
                  ),
                children[i],
              ],
            ],
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.only(left: 6, right: 6, top: 6),
            child: Text(
              footer,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSettingTile({
    required BuildContext context,
    required Widget icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: titleColor ??
                            (isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: isDark
                              ? AppTheme.textMutedDark
                              : AppTheme.textMutedLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconBadge({
    required IconData icon,
    required Color color,
    Color? iconColor,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: 18,
        color: iconColor ?? color,
      ),
    );
  }

  Widget _buildChevron(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Icon(
      Icons.chevron_right_rounded,
      size: 20,
      color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
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
                Expanded(
                  child: Row(
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
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
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
