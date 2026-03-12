import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/presentation/glass_widgets.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/split_providers.dart';

class AddSplitExpenseScreen extends ConsumerStatefulWidget {
  final int groupId;
  final List<SplitMember> members;

  const AddSplitExpenseScreen({
    super.key,
    required this.groupId,
    required this.members,
  });

  @override
  ConsumerState<AddSplitExpenseScreen> createState() =>
      _AddSplitExpenseScreenState();
}

class _AddSplitExpenseScreenState
    extends ConsumerState<AddSplitExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _date = DateTime.now();
  int? _paidByMemberId;
  String _splitType = 'equal';
  bool _isLoading = false;

  // For custom split: memberId → TextEditingController
  late final Map<int, TextEditingController> _customShareControllers;
  // Which members are included in the split
  late final Map<int, bool> _memberIncluded;

  @override
  void initState() {
    super.initState();
    _customShareControllers = {
      for (final m in widget.members) m.id: TextEditingController(),
    };
    _memberIncluded = {for (final m in widget.members) m.id: true};
    if (widget.members.isNotEmpty) {
      _paidByMemberId = widget.members.first.id;
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    for (final c in _customShareControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_paidByMemberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select who paid')),
      );
      return;
    }

    final amount = double.parse(_amountController.text.trim());
    final includedIds = _memberIncluded.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (includedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one member to split with')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final service = ref.read(splitServiceProvider);
      if (_splitType == 'equal') {
        await service.addExpenseEqual(
          groupId: widget.groupId,
          paidByMemberId: _paidByMemberId!,
          amount: amount,
          description: _descController.text.trim(),
          date: _date,
          memberIds: includedIds,
        );
      } else {
        final shares = <int, double>{};
        for (final id in includedIds) {
          final v = double.tryParse(_customShareControllers[id]!.text.trim());
          if (v == null || v < 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Enter valid amounts for all included members'),
              ),
            );
            setState(() => _isLoading = false);
            return;
          }
          shares[id] = v;
        }
        await service.addExpenseCustom(
          groupId: widget.groupId,
          paidByMemberId: _paidByMemberId!,
          amount: amount,
          description: _descController.text.trim(),
          date: _date,
          memberShares: shares,
        );
      }
      if (mounted) Navigator.pop(context);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return GlassScaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            // Description
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'e.g. Dinner, Hotel',
                prefixIcon: Icon(Icons.description_rounded),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),

            // Amount
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (double.tryParse(v) == null || double.parse(v) <= 0) {
                  return 'Enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Date
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      '${_date.day}/${_date.month}/${_date.year}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Paid By
            Text(
              'Paid by',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.members.map((m) {
                final selected = _paidByMemberId == m.id;
                return ChoiceChip(
                  label: Text(m.name),
                  selected: selected,
                  selectedColor: AppTheme.narutoOrange,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : textColor,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (_) => setState(() => _paidByMemberId = m.id),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Split type
            Text(
              'Split type',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _SplitTypeChip(
                  label: 'Equal',
                  icon: Icons.people_alt_rounded,
                  selected: _splitType == 'equal',
                  onTap: () => setState(() => _splitType = 'equal'),
                ),
                const SizedBox(width: 12),
                _SplitTypeChip(
                  label: 'Custom',
                  icon: Icons.tune_rounded,
                  selected: _splitType == 'custom',
                  onTap: () => setState(() => _splitType = 'custom'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Member shares
            Text(
              'Split between',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ...widget.members.map((m) {
              final included = _memberIncluded[m.id] ?? true;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: included
                      ? AppTheme.narutoOrange.withOpacity(0.08)
                      : (isDark
                            ? Colors.white.withOpacity(0.04)
                            : Colors.black.withOpacity(0.02)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: included
                        ? AppTheme.narutoOrange.withOpacity(0.4)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: included,
                      activeColor: AppTheme.narutoOrange,
                      onChanged: (val) => setState(
                        () => _memberIncluded[m.id] = val ?? false,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        m.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (_splitType == 'custom' && included)
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _customShareControllers[m.id],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            hintText: '0.00',
                            prefixText: '₹',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Add Expense'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplitTypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SplitTypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? AppTheme.neonGradient : null,
          color: selected
              ? null
              : Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.07)
                  : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected
                  ? Colors.white
                  : (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : Colors.black54),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : (Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black87),
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
