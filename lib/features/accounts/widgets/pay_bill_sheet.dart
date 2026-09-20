import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/database/database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../providers/account_providers.dart';

class PayBillSheet extends ConsumerStatefulWidget {
  final BankAccount creditCard;

  const PayBillSheet({super.key, required this.creditCard});

  @override
  ConsumerState<PayBillSheet> createState() => _PayBillSheetState();
}

class _PayBillSheetState extends ConsumerState<PayBillSheet> {
  final _amountController = TextEditingController();
  BankAccount? _selectedSourceAccount;
  String _paymentOption = 'full'; // 'full', 'bill', 'custom'
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.creditCard.balance.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _onOptionChanged(String option) {
    setState(() {
      _paymentOption = option;
      if (option == 'full') {
        _amountController.text = widget.creditCard.balance.toStringAsFixed(0);
      } else if (option == 'bill') {
        final amt = widget.creditCard.lastBillAmount ?? widget.creditCard.balance;
        _amountController.text = amt.toStringAsFixed(0);
      }
    });
  }

  Future<void> _submitPayment() async {
    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid payment amount')),
      );
      return;
    }

    if (_selectedSourceAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment source account')),
      );
      return;
    }

    if (_selectedSourceAccount!.balance < amount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Insufficient balance in ${_selectedSourceAccount!.name} (${Formatters.currency(_selectedSourceAccount!.balance)})',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(accountNotifierProvider.notifier).recordBillPayment(
            creditCardAccountId: widget.creditCard.id,
            fromAccountId: _selectedSourceAccount!.id,
            amount: amount,
            note: 'Bill Payment for ${widget.creditCard.name}',
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully paid ${Formatters.currency(amount)} towards ${widget.creditCard.name}',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment error: $e')),
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
    final isDark = theme.brightness == Brightness.dark;

    final allAccountsAsync = ref.watch(bankAccountsStreamProvider);
    final sourceAccounts = (allAccountsAsync.value ?? [])
        .where((a) => a.accountType != 'credit_card')
        .toList();

    if (_selectedSourceAccount == null && sourceAccounts.isNotEmpty) {
      _selectedSourceAccount = sourceAccounts.firstWhere(
        (a) => a.isDefault,
        orElse: () => sourceAccounts.first,
      );
    }

    final card = widget.creditCard;
    final totalLimit = card.creditLimit ?? 0.0;
    final debt = card.balance;
    final available = totalLimit > 0 ? (totalLimit - debt).clamp(0.0, totalLimit) : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pay Credit Card Bill',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${card.name} •••• ${card.accountNumberLast4 ?? ""}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Card Balance Summary Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('Current Debt', style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text(
                        Formatters.currency(debt),
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    height: 36,
                    width: 1,
                    color: isDark ? Colors.white12 : Colors.grey.shade300,
                  ),
                  Column(
                    children: [
                      Text('Available Limit', style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text(
                        totalLimit > 0 ? Formatters.currency(available) : 'N/A',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Payment Amount Options
            Text('Payment Option', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Full Outstanding'),
                  selected: _paymentOption == 'full',
                  onSelected: (val) {
                    if (val) _onOptionChanged('full');
                  },
                ),
                const SizedBox(width: 8),
                if (card.lastBillAmount != null && card.lastBillAmount! > 0) ...[
                  ChoiceChip(
                    label: Text('Last Bill (${Formatters.currency(card.lastBillAmount!)})'),
                    selected: _paymentOption == 'bill',
                    onSelected: (val) {
                      if (val) _onOptionChanged('bill');
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                ChoiceChip(
                  label: const Text('Custom'),
                  selected: _paymentOption == 'custom',
                  onSelected: (val) {
                    if (val) _onOptionChanged('custom');
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Amount Input Field
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              enabled: _paymentOption == 'custom',
              decoration: InputDecoration(
                labelText: 'Amount to Pay (₹)',
                prefixText: '₹ ',
                prefixIcon: const Icon(Icons.currency_rupee),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
            ),
            const SizedBox(height: 16),

            // Source Account Selector
            Text('Pay From Account', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<BankAccount>(
              value: _selectedSourceAccount,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                prefixIcon: const Icon(Icons.account_balance),
              ),
              items: sourceAccounts.map((acc) {
                return DropdownMenuItem<BankAccount>(
                  value: acc,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${acc.name} (${acc.bankName})'),
                      Text(
                        Formatters.currency(acc.balance),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (acc) => setState(() => _selectedSourceAccount = acc),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _isLoading ? 'Processing...' : 'Confirm & Clear Debt',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.narutoOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _submitPayment,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
