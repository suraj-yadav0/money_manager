import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/database/database.dart';
import '../../../core/navigation/app_shell.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/formatters.dart';

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

  @override
  void dispose() {
    _incomeController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    // Income was already validated when moving from step 1 to step 2
    if (_incomeController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter your income')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final db = ref.read(databaseProvider);
      final income =
          double.tryParse(_incomeController.text.replaceAll(',', '')) ?? 0;

      if (income <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a valid income')),
          );
        }
        return;
      }

      // Update user settings
      await (db.update(db.userSettings)..where((t) => t.id.equals(1))).write(
        UserSettingsCompanion(
          monthlyIncome: Value(income),
          isOnboarded: const Value(true),
        ),
      );

      // Create an actual income transaction for this month
      // Find the Salary income category
      final salaryCategory = await (db.select(
        db.categories,
      )..where((c) => c.name.equals('Salary'))).getSingleOrNull();

      // Verify it's an income category before creating transaction
      if (salaryCategory != null && salaryCategory.type == 'income') {
        final now = DateTime.now();
        // Create income transaction for 1st of current month
        await db
            .into(db.transactions)
            .insert(
              TransactionsCompanion.insert(
                amount: income,
                type: 'income',
                categoryId: salaryCategory.id,
                timestamp: DateTime(now.year, now.month, 1),
                note: const Value('Monthly Salary'),
                isRecurring: const Value(true),
              ),
            );
      }

      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const AppShell()));
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Progress indicator
              LinearProgressIndicator(
                value: (_currentStep + 1) / 3,
                backgroundColor: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 48),

              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
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
        return const SizedBox();
    }
  }

  Widget _buildWelcomeStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      key: const ValueKey('welcome'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colorScheme.primary, colorScheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Icon(
            Icons.account_balance_wallet_rounded,
            size: 60,
            color: colorScheme.onPrimary,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Welcome to\nMoney Manager',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Take control of your finances.\nKnow where your money goes.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
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
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() => _currentStep = 1),
          child: const Text('Continue as Guest'),
        ),
      ],
    );
  }

  Widget _buildIncomeStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Form(
      key: const ValueKey('income'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "What's your monthly income?",
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This helps us predict your month-end balance.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          Form(
            key: _formKey,
            child: TextFormField(
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
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your income';
                }
                final parsed = double.tryParse(value.replaceAll(',', ''));
                if (parsed == null || parsed <= 0) {
                  return 'Please enter a valid amount';
                }
                return null;
              },
            ),
          ),
          const Spacer(),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() => _currentStep = 0),
                child: const Text('Back'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    setState(() => _currentStep = 2);
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('Continue'),
                ),
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
    final income =
        double.tryParse(_incomeController.text.replaceAll(',', '')) ?? 0;

    return Column(
      key: const ValueKey('ready'),
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
            Icons.check_rounded,
            size: 50,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          "You're all set!",
          style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Monthly Income',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      Formatters.currency(income),
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Daily Budget',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      Formatters.currency(
                        income / Formatters.daysInCurrentMonth(),
                      ),
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
                  : const Text('Start Tracking'),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() => _currentStep = 1),
          child: const Text('Edit Income'),
        ),
      ],
    );
  }
}
