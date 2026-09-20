import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/database/database.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/account_providers.dart';

class AddAccountSheet extends ConsumerStatefulWidget {
  final BankAccount? accountToEdit;

  const AddAccountSheet({super.key, this.accountToEdit});

  @override
  ConsumerState<AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends ConsumerState<AddAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _last4Controller = TextEditingController();
  final _balanceController = TextEditingController();
  final _creditLimitController = TextEditingController();
  final _billingCycleDayController = TextEditingController();
  final _paymentDueDayController = TextEditingController();

  String _accountType = 'savings';
  String _selectedColor = '#FF5F1F';
  bool _isDefault = false;
  bool _autoNotifyBill = true;
  bool _isLoading = false;

  final List<String> _popularBanks = [
    'HDFC Bank',
    'State Bank of India',
    'ICICI Bank',
    'Axis Bank',
    'Kotak Mahindra Bank',
    'Punjab National Bank',
    'Paytm Payments Bank',
    'Cash',
  ];

  final List<String> _colors = [
    '#FF5F1F', // Orange
    '#1E88E5', // Blue
    '#00897B', // Teal
    '#E53935', // Red
    '#8E24AA', // Purple
    '#43A047', // Green
    '#FB8C00', // Amber
    '#3949AB', // Indigo
  ];

  @override
  void initState() {
    super.initState();
    if (widget.accountToEdit != null) {
      final acc = widget.accountToEdit!;
      _nameController.text = acc.name;
      _bankNameController.text = acc.bankName;
      _last4Controller.text = acc.accountNumberLast4 ?? '';
      _balanceController.text = acc.balance.toStringAsFixed(0);
      _accountType = acc.accountType;
      _selectedColor = acc.colorHex ?? '#FF5F1F';
      _isDefault = acc.isDefault;
      if (acc.creditLimit != null) {
        _creditLimitController.text = acc.creditLimit!.toStringAsFixed(0);
      }
      if (acc.billingCycleDay != null) {
        _billingCycleDayController.text = acc.billingCycleDay!.toString();
      }
      if (acc.paymentDueDay != null) {
        _paymentDueDayController.text = acc.paymentDueDay!.toString();
      }
      _autoNotifyBill = acc.autoNotifyBill;
    } else {
      _bankNameController.text = 'HDFC Bank';
      _nameController.text = 'HDFC Savings';
      _balanceController.text = '0';
      _creditLimitController.text = '50000';
      _billingCycleDayController.text = '15';
      _paymentDueDayController.text = '5';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bankNameController.dispose();
    _last4Controller.dispose();
    _balanceController.dispose();
    _creditLimitController.dispose();
    _billingCycleDayController.dispose();
    _paymentDueDayController.dispose();
    super.dispose();
  }

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final balance = double.tryParse(_balanceController.text.replaceAll(',', '')) ?? 0.0;
      final last4 = _last4Controller.text.trim().isEmpty ? null : _last4Controller.text.trim();
      final creditLimit = _accountType == 'credit_card'
          ? double.tryParse(_creditLimitController.text.replaceAll(',', ''))
          : null;
      final billingCycleDay = _accountType == 'credit_card'
          ? int.tryParse(_billingCycleDayController.text.trim())
          : null;
      final paymentDueDay = _accountType == 'credit_card'
          ? int.tryParse(_paymentDueDayController.text.trim())
          : null;

      if (widget.accountToEdit != null) {
        await ref.read(accountNotifierProvider.notifier).updateAccount(
              id: widget.accountToEdit!.id,
              name: _nameController.text.trim(),
              bankName: _bankNameController.text.trim(),
              last4: last4,
              accountType: _accountType,
              balance: balance,
              creditLimit: creditLimit,
              billingCycleDay: billingCycleDay,
              paymentDueDay: paymentDueDay,
              autoNotifyBill: _autoNotifyBill,
              colorHex: _selectedColor,
              isDefault: _isDefault,
            );
      } else {
        await ref.read(accountNotifierProvider.notifier).createAccount(
              name: _nameController.text.trim(),
              bankName: _bankNameController.text.trim(),
              last4: last4,
              accountType: _accountType,
              balance: balance,
              creditLimit: creditLimit,
              billingCycleDay: billingCycleDay,
              paymentDueDay: paymentDueDay,
              autoNotifyBill: _autoNotifyBill,
              colorHex: _selectedColor,
              isDefault: _isDefault,
            );
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving account: $e')),
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
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.accountToEdit != null ? 'Edit Bank Account' : 'Add Bank Account',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Account Type Chips
              Text('Account Type', style: theme.textTheme.labelMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildTypeChip('savings', 'Savings A/c', Icons.account_balance),
                  _buildTypeChip('current', 'Current A/c', Icons.business),
                  _buildTypeChip('credit_card', 'Credit Card', Icons.credit_card),
                  _buildTypeChip('wallet', 'Cash / Wallet', Icons.account_balance_wallet),
                ],
              ),
              const SizedBox(height: 16),

              // Bank Quick Pick
              Text('Bank Name', style: theme.textTheme.labelMedium),
              const SizedBox(height: 8),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _popularBanks.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final bank = _popularBanks[index];
                    final isSelected = _bankNameController.text == bank;
                    return ChoiceChip(
                      label: Text(bank, style: const TextStyle(fontSize: 12)),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _bankNameController.text = bank;
                            if (_nameController.text.isEmpty ||
                                _popularBanks.any((b) => _nameController.text.startsWith(b.split(' ')[0]))) {
                              _nameController.text = '$bank $_accountType';
                            }
                          });
                        }
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Custom Bank Name Field
              TextFormField(
                controller: _bankNameController,
                decoration: InputDecoration(
                  labelText: 'Bank / Institution Name',
                  prefixIcon: const Icon(Icons.account_balance_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter bank name' : null,
              ),
              const SizedBox(height: 16),

              // Account Display Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Account Nickname (e.g. Salary Account)',
                  prefixIcon: const Icon(Icons.label_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter nickname' : null,
              ),
              const SizedBox(height: 16),

              // Last 4 Digits & Balance Row
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _last4Controller,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Last 4 Digits',
                        hintText: '1234',
                        counterText: '',
                        prefixIcon: const Icon(Icons.pin_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _balanceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      decoration: InputDecoration(
                        labelText: _accountType == 'credit_card'
                            ? 'Current Debt / Outstanding (₹)'
                            : 'Current Balance (₹)',
                        prefixText: '₹ ',
                        prefixIcon: const Icon(Icons.currency_rupee),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_accountType == 'credit_card') ...[
                // Card Limit
                TextFormField(
                  controller: _creditLimitController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  decoration: InputDecoration(
                    labelText: 'Total Card Limit (₹)',
                    prefixText: '₹ ',
                    prefixIcon: const Icon(Icons.speed),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                  validator: (val) {
                    if (_accountType == 'credit_card' && (val == null || val.trim().isEmpty)) {
                      return 'Enter total card limit';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Statement Date & Due Date Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _billingCycleDayController,
                        keyboardType: TextInputType.number,
                        maxLength: 2,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Statement Day',
                          hintText: '1-31',
                          counterText: '',
                          prefixIcon: const Icon(Icons.calendar_month_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                        ),
                        validator: (val) {
                          if (_accountType == 'credit_card') {
                            final d = int.tryParse(val ?? '');
                            if (d == null || d < 1 || d > 31) return '1-31';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _paymentDueDayController,
                        keyboardType: TextInputType.number,
                        maxLength: 2,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Due Day',
                          hintText: '1-31',
                          counterText: '',
                          prefixIcon: const Icon(Icons.event_available_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                        ),
                        validator: (val) {
                          if (_accountType == 'credit_card') {
                            final d = int.tryParse(val ?? '');
                            if (d == null || d < 1 || d > 31) return '1-31';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto-Notify on Bill & Due Dates',
                      style: TextStyle(fontSize: 14)),
                  subtitle: const Text(
                      'Receive notifications when bill generates and before due date',
                      style: TextStyle(fontSize: 12)),
                  value: _autoNotifyBill,
                  onChanged: (val) => setState(() => _autoNotifyBill = val),
                ),
                const SizedBox(height: 12),
              ],

              // Color Selection
              Text('Account Color', style: theme.textTheme.labelMedium),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _colors.map((c) {
                  final colorInt = int.parse(c.replaceFirst('#', '0xFF'));
                  final isSelected = _selectedColor == c;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = c),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(colorInt),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Color(colorInt).withOpacity(0.6),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                )
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Set as default
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Set as Default Account'),
                subtitle: const Text('New transactions will default to this account'),
                value: _isDefault,
                onChanged: (val) => setState(() => _isDefault = val),
              ),
              const SizedBox(height: 20),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.narutoOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          widget.accountToEdit != null ? 'Update Account' : 'Add Account',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(String type, String label, IconData icon) {
    final isSelected = _accountType == type;
    return ChoiceChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _accountType = type);
      },
    );
  }
}
