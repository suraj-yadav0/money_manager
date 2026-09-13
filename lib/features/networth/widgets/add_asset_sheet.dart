import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/net_worth_providers.dart';

class AddAssetSheet extends ConsumerStatefulWidget {
  final Asset? existingAsset; // null = add, non-null = edit

  const AddAssetSheet({super.key, this.existingAsset});

  @override
  ConsumerState<AddAssetSheet> createState() => _AddAssetSheetState();
}

class _AddAssetSheetState extends ConsumerState<AddAssetSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _valueController;
  late TextEditingController _noteController;
  late AssetType _selectedType;

  bool get isEditing => widget.existingAsset != null;

  @override
  void initState() {
    super.initState();
    final asset = widget.existingAsset;
    _nameController = TextEditingController(text: asset?.name ?? '');
    _valueController = TextEditingController(
      text: asset != null ? asset.value.toStringAsFixed(0) : '',
    );
    _noteController = TextEditingController(text: asset?.note ?? '');
    _selectedType = asset != null
        ? AssetType.fromKey(asset.type)
        : AssetType.savings;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withAlpha(50),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                isEditing ? 'Edit Asset' : 'Add Asset',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Asset Type Chips
              Text('Type', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AssetType.values.map((type) {
                  final isSelected = _selectedType == type;
                  return ChoiceChip(
                    avatar: Icon(type.icon, size: 16),
                    label: Text(type.label),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedType = type);
                      }
                    },
                    selectedColor: AppTheme.narutoOrange.withAlpha(50),
                    labelStyle: GoogleFonts.inter(
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isSelected
                          ? AppTheme.narutoOrange
                          : theme.colorScheme.onSurface,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? AppTheme.narutoOrange
                          : (isDark
                                ? Colors.white.withAlpha(30)
                                : Colors.black.withAlpha(25)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Name Input
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  hintText: _getNameHint(),
                  prefixIcon: const Icon(Icons.label_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Value Input
              TextFormField(
                controller: _valueController,
                decoration: InputDecoration(
                  labelText: _selectedType.isLiability
                      ? 'Outstanding Amount'
                      : 'Current Value',
                  hintText: 'Enter amount',
                  prefixIcon: const Icon(Icons.currency_rupee),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a value';
                  }
                  final parsed = double.tryParse(value);
                  if (parsed == null || parsed < 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Note Input
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'E.g. Account number, details...',
                  prefixIcon: Icon(Icons.note_outlined),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  if (isEditing) ...[
                    // Delete button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _deleteAsset,
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppTheme.kuramaRed,
                        ),
                        label: Text(
                          'Delete',
                          style: GoogleFonts.inter(color: AppTheme.kuramaRed),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppTheme.kuramaRed),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: isEditing ? 2 : 1,
                    child: ElevatedButton.icon(
                      onPressed: _saveAsset,
                      icon: Icon(isEditing ? Icons.check : Icons.add),
                      label: Text(
                        isEditing ? 'Update' : 'Add Asset',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getNameHint() {
    switch (_selectedType) {
      case AssetType.savings:
        return 'E.g. SBI Savings Account';
      case AssetType.investment:
        return 'E.g. Mutual Fund, Stocks';
      case AssetType.property:
        return 'E.g. Flat in Mumbai';
      case AssetType.gold:
        return 'E.g. Gold Chain 10g';
      case AssetType.loan:
        return 'E.g. Home Loan, Car EMI';
      case AssetType.other:
        return 'E.g. PPF, FD';
    }
  }

  Future<void> _saveAsset() async {
    if (!_formKey.currentState!.validate()) return;

    final db = ref.read(databaseProvider);
    final now = DateTime.now();

    if (isEditing) {
      await (db.update(
        db.assets,
      )..where((t) => t.id.equals(widget.existingAsset!.id))).write(
        AssetsCompanion(
          name: Value(_nameController.text.trim()),
          type: Value(_selectedType.key),
          value: Value(double.parse(_valueController.text.trim())),
          isLiability: Value(_selectedType.isLiability),
          note: Value(
            _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          ),
          updatedAt: Value(now),
        ),
      );
    } else {
      await db
          .into(db.assets)
          .insert(
            AssetsCompanion.insert(
              name: _nameController.text.trim(),
              type: _selectedType.key,
              value: double.parse(_valueController.text.trim()),
              isLiability: Value(_selectedType.isLiability),
              note: Value(
                _noteController.text.trim().isEmpty
                    ? null
                    : _noteController.text.trim(),
              ),
            ),
          );
    }

    if (mounted) {
      ref.invalidate(netWorthProvider);
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _deleteAsset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Asset?'),
        content: Text(
          'Are you sure you want to delete "${widget.existingAsset!.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppTheme.kuramaRed),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      await (db.delete(
        db.assets,
      )..where((t) => t.id.equals(widget.existingAsset!.id))).go();

      if (mounted) {
        ref.invalidate(netWorthProvider);
        Navigator.of(context).pop(true);
      }
    }
  }
}
