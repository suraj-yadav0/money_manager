import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/utils/constants.dart';
import '../../../core/presentation/glass_widgets.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/providers/auth_providers.dart';
import '../../auth/screens/auth_screen.dart';
import '../../../main.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _incomeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isLoading = false;

  final List<double> _presetIncomes = [30000, 60000, 100000, 200000];

  @override
  void dispose() {
    _incomeController.dispose();
    super.dispose();
  }

  void _navigateToSignIn() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  Future<void> _skipToGuest() async {
    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseProvider);
      await db.into(db.userSettings).insertOnConflictUpdate(
        UserSettingsCompanion(
          id: const Value(1),
          monthlyIncome: const Value(0),
          isOnboarded: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await ref.read(guestModeProvider.notifier).enableGuestMode();
      ref.invalidate(isOnboardedProvider);
      ref.invalidate(userSettingsProvider);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _completeOnboarding() async {
    setState(() => _isLoading = true);

    try {
      final db = ref.read(databaseProvider);
      final rawVal = _incomeController.text.replaceAll(',', '').trim();
      final income = double.tryParse(rawVal) ?? 0;

      // Upsert user settings
      await db.into(db.userSettings).insertOnConflictUpdate(
        UserSettingsCompanion(
          id: const Value(1),
          monthlyIncome: Value(income),
          isOnboarded: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) {
        await ref.read(guestModeProvider.notifier).enableGuestMode();
      }

      ref.invalidate(isOnboardedProvider);
      ref.invalidate(userSettingsProvider);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GlassScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              // Top navigation and brand bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withAlpha(28),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.query_stats_rounded,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Quantro',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  if (_currentStep == 0)
                    TextButton.icon(
                      onPressed: _isLoading ? null : _navigateToSignIn,
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: const Text('Sign In'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                  else
                    TextButton(
                      onPressed: _isLoading ? null : _skipToGuest,
                      child: const Text('Skip'),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / 3,
                  minHeight: 4,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                ),
              ),
              const SizedBox(height: 24),

              // Step content
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _buildStep(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_currentStep) {
      case 0:
        return _buildWelcomeStep();
      case 1:
        return _buildIncomeStep();
      case 2:
        return _buildReadyStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildWelcomeStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      key: const ValueKey('welcome'),
      children: [
        const Spacer(),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colorScheme.primary, colorScheme.tertiary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withAlpha(50),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            Icons.account_balance_wallet_rounded,
            size: 48,
            color: colorScheme.onPrimary,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Welcome to Quantro',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Smart personal finance with month-end projections and real-time expense tracking.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        _buildFeaturePill(
          icon: Icons.trending_up_rounded,
          title: 'Predictive Projections',
          subtitle: 'Know your exact month-end balance in advance.',
        ),
        const SizedBox(height: 12),
        _buildFeaturePill(
          icon: Icons.security_rounded,
          title: 'Private & Local-First',
          subtitle: 'Works completely offline with optional cloud sync.',
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => setState(() => _currentStep = 1),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('Get Started'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _navigateToSignIn,
            icon: const Icon(Icons.sync_rounded, size: 18),
            label: const Text('Sign In to Sync Account'),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _isLoading ? null : _skipToGuest,
          child: const Text('Explore as Guest'),
        ),
      ],
    );
  }

  Widget _buildFeaturePill({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(100),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('income'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Monthly income baseline',
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Used to calculate daily spending limits and track savings rate. You can change this anytime in Settings.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _incomeController,
            keyboardType: TextInputType.number,
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              prefixText: '${AppConstants.currencySymbol} ',
              prefixStyle: GoogleFonts.outfit(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
              hintText: '50,000',
              hintStyle: GoogleFonts.outfit(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant.withAlpha(100),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withAlpha(80),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your monthly income';
              }
              final parsed = double.tryParse(value.replaceAll(',', '').trim());
              if (parsed == null || parsed <= 0) {
                return 'Please enter a valid amount greater than 0';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Quick select:',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _presetIncomes.map((amount) {
              final formatted = Formatters.currency(amount);
              return ActionChip(
                label: Text(formatted),
                onPressed: () {
                  _incomeController.text = amount.toInt().toString();
                },
              );
            }).toList(),
          ),
          const Spacer(),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _currentStep = 0),
                child: const Text('Back'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  _incomeController.text = '0';
                  setState(() => _currentStep = 2);
                },
                child: const Text('Skip for now'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    setState(() => _currentStep = 2);
                  }
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReadyStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final rawVal = _incomeController.text.replaceAll(',', '').trim();
    final income = double.tryParse(rawVal) ?? 0;
    final dailyBudget =
        income > 0 ? income / Formatters.daysInCurrentMonth() : 0.0;

    return Column(
      key: const ValueKey('ready'),
      children: [
        const Spacer(),
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_rounded,
            size: 44,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Setup complete',
          style: GoogleFonts.outfit(
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your initial profile is ready. Here is a snapshot of your plan:',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withAlpha(90),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withAlpha(100),
            ),
          ),
          child: Column(
            children: [
              _buildSummaryRow(
                label: 'Monthly Income',
                value: income > 0 ? Formatters.currency(income) : 'Not specified',
                highlight: true,
              ),
              const Divider(height: 24),
              _buildSummaryRow(
                label: 'Estimated Daily Budget',
                value: income > 0 ? Formatters.currency(dailyBudget) : 'Flexible',
                highlight: false,
              ),
              const Divider(height: 24),
              _buildSummaryRow(
                label: 'Storage & Sync',
                value: 'Local SQLite (Offline Ready)',
                highlight: false,
              ),
            ],
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isLoading ? null : _completeOnboarding,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Start Using Quantro'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _currentStep = 1),
          child: const Text('Adjust Income'),
        ),
      ],
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
    required bool highlight,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
            color: highlight ? colorScheme.primary : colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
