import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../core/database/database.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/formatters.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../goals/providers/goals_provider.dart';
import '../services/categorization_engine.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final TransactionWithCategory? transactionToEdit;

  const AddTransactionScreen({super.key, this.transactionToEdit});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  TransactionType _type = TransactionType.expense;
  Category? _selectedCategory;
  Goal? _selectedGoal;
  String? _selectedPaymentMode = 'Cash'; // Default to Cash
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isSuggestingCategory = false;
  String? _receiptImagePath;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.transactionToEdit != null) {
      final tx = widget.transactionToEdit!.transaction;
      final cat = widget.transactionToEdit!.category;

      _amountController.text = Formatters.currency(
        tx.amount,
      ).replaceAll(',', '');
      _noteController.text = tx.note ?? '';
      _type = TransactionType.values.firstWhere((e) => e.name == tx.type);
      _selectedCategory = cat;
      _selectedGoal = widget.transactionToEdit!.transaction.goalId != null
          ? Goal(
              id: widget.transactionToEdit!.transaction.goalId!,
              name: '', // Placeholder, will be fetched or handled
              targetAmount: 0,
              deadline: DateTime.now(),
              savedAmount: 0,
              isActive: true,
              isCompleted: false,
              createdAt: DateTime.now(),
            )
          : null; // Ideally fetch the goal or trust the ID
      _selectedPaymentMode =
          widget.transactionToEdit!.transaction.paymentMode ?? 'Cash';
      _selectedDate = tx.timestamp;
      _receiptImagePath = tx.receiptImagePath;
    } else {
      _selectedPaymentMode = 'Cash';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _suggestCategory(String note) async {
    if (note.length < 3) return;

    setState(() => _isSuggestingCategory = true);

    try {
      final engine = ref.read(categorizationEngineProvider);
      final suggestion = await engine.suggestCategory(note);

      if (suggestion != null && mounted) {
        setState(() => _selectedCategory = suggestion);
      }
    } finally {
      if (mounted) setState(() => _isSuggestingCategory = false);
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (image != null) {
        final savedPath = await _saveImageToAppDirectory(image);
        setState(() => _receiptImagePath = savedPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accessing camera: $e')),
        );
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (image != null) {
        final savedPath = await _saveImageToAppDirectory(image);
        setState(() => _receiptImagePath = savedPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accessing gallery: $e')),
        );
      }
    }
  }

  Future<String> _saveImageToAppDirectory(XFile image) async {
    final appDir = await getApplicationDocumentsDirectory();
    final receiptsDir = Directory(p.join(appDir.path, 'receipts'));
    
    // Create receipts directory if it doesn't exist
    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }
    
    // Generate unique filename using timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = p.extension(image.path);
    final fileName = 'receipt_$timestamp$extension';
    final savedPath = p.join(receiptsDir.path, fileName);
    
    // Copy image to app directory
    await File(image.path).copy(savedPath);
    
    return savedPath;
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),
            if (_receiptImagePath != null)
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Remove Photo'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _receiptImagePath = null);
                },
              ),
          ],
        ),
      ),
    );
  }


  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    // Category is optional if a goal is selected (goal acts as the category)
    if (_selectedCategory == null && _selectedGoal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category or goal')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final db = ref.read(databaseProvider);
      final amount = double.parse(_amountController.text.replaceAll(',', ''));

      // If goal is selected but no category, use 'Savings' category
      int categoryId;
      if (_selectedCategory != null) {
        categoryId = _selectedCategory!.id;
      } else {
        // Find the Savings category
        final savingsCategory = await (db.select(
          db.categories,
        )..where((c) => c.name.equals('Savings'))).getSingleOrNull();
        if (savingsCategory != null) {
          categoryId = savingsCategory.id;
        } else {
          // Fallback: use first expense category
          final firstCategory =
              await (db.select(db.categories)
                    ..where((c) => c.type.equals('expense'))
                    ..limit(1))
                  .getSingle();
          categoryId = firstCategory.id;
        }
      }

      if (widget.transactionToEdit != null) {
        // Update existing
        await (db.update(db.transactions)..where(
              (t) => t.id.equals(widget.transactionToEdit!.transaction.id),
            ))
            .write(
              TransactionsCompanion(
                amount: Value(amount),
                type: Value(_type.name),
                categoryId: Value(categoryId),
                goalId: Value(_selectedGoal?.id),
                timestamp: Value(_selectedDate),
                note: Value(
                  _noteController.text.isNotEmpty ? _noteController.text : null,
                ),
                paymentMode: Value(_selectedPaymentMode),
                receiptImagePath: Value(_receiptImagePath),
              ),
            );
      } else {
        // Insert new
        await db
            .into(db.transactions)
            .insert(
              TransactionsCompanion.insert(
                amount: amount,
                type: _type.name,
                categoryId: categoryId,
                goalId: Value(_selectedGoal?.id),
                timestamp: _selectedDate,
                note: Value(
                  _noteController.text.isNotEmpty ? _noteController.text : null,
                ),
                paymentMode: Value(_selectedPaymentMode),
                receiptImagePath: Value(_receiptImagePath),
              ),
            );

        // Add contribution to goal if selected
        if (_selectedGoal != null) {
          final goalService = ref.read(goalServiceProvider);
          await goalService.addContribution(
            goalId: _selectedGoal!.id,
            amount: amount,
            note: _noteController.text.isNotEmpty
                ? 'Expense: ${_noteController.text}'
                : 'Expense contribution',
          );
          // Refresh goal data
          ref.invalidate(activeGoalsProvider);
          ref.invalidate(activeGoalProvider);
        }
      }

      // Learn from this transaction if note is provided
      if (_noteController.text.isNotEmpty) {
        final engine = ref.read(categorizationEngineProvider);
        await engine.learnFromCorrection(
          _noteController.text,
          _selectedCategory!.id,
        );
      }

      // Refresh dashboard
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(recentTransactionsProvider);

      if (mounted) {
        Navigator.of(context).pop();
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

    final categoriesAsync = _type.isExpense
        ? ref.watch(expenseCategoriesProvider)
        : ref.watch(incomeCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.transactionToEdit != null
              ? 'Edit Transaction'
              : (_type.isExpense ? 'Add Expense' : 'Add Income'),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveTransaction,
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type Toggle
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTypeToggle(
                        'Expense',
                        TransactionType.expense,
                        colorScheme.error,
                      ),
                    ),
                    Expanded(
                      child: _buildTypeToggle(
                        'Income',
                        TransactionType.income,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Amount Input
              Text('Amount', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
                ],
                style: GoogleFonts.outfit(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  prefixText: '${AppConstants.currencySymbol} ',
                  prefixStyle: GoogleFonts.outfit(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                  hintText: '0',
                  hintStyle: GoogleFonts.outfit(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant.withAlpha(100),
                  ),
                  border: InputBorder.none,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter amount';
                  }
                  final parsed = double.tryParse(value.replaceAll(',', ''));
                  if (parsed == null || parsed <= 0) {
                    return 'Invalid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Note Input (triggers auto-categorization)
              Text('Note (optional)', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'e.g., Swiggy order, Uber ride',
                  suffixIcon: _isSuggestingCategory
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                onChanged: (value) {
                  // Debounce auto-categorization
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (_noteController.text == value) {
                      _suggestCategory(value);
                    }
                  });
                },
              ),
              const SizedBox(height: 24),

              // Category Selection
              Row(
                children: [
                  Text('Category', style: theme.textTheme.labelLarge),
                  if (_selectedCategory != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Auto-suggested',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              categoriesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
                data: (categories) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories.map((category) {
                    final isSelected = _selectedCategory?.id == category.id;
                    return FilterChip(
                      selected: isSelected,
                      label: Text(category.name),
                      avatar: Icon(_getCategoryIcon(category.icon), size: 18),
                      onSelected: (_) {
                        setState(() => _selectedCategory = category);
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Goal Selection (only for expenses)
              if (_type.isExpense) ...[
                Row(
                  children: [
                    Text(
                      'Link to Goal (optional)',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.savings_outlined,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ref
                    .watch(activeGoalsProvider)
                    .when(
                      loading: () => const SizedBox(
                        height: 40,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      error: (e, _) => Text('Error loading goals: $e'),
                      data: (goals) {
                        if (goals.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withAlpha(100),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'No active goals. Create one to link expenses.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: goals.map((goal) {
                            final isSelected = _selectedGoal?.id == goal.id;
                            final progress =
                                (goal.savedAmount / goal.targetAmount).clamp(
                                  0.0,
                                  1.0,
                                );
                            return FilterChip(
                              selected: isSelected,
                              label: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(goal.name),
                                  Text(
                                    '${Formatters.compactCurrency(goal.savedAmount)} / ${Formatters.compactCurrency(goal.targetAmount)}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: isSelected
                                          ? colorScheme.onSecondaryContainer
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              avatar: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: progress,
                                    strokeWidth: 2,
                                    backgroundColor:
                                        colorScheme.surfaceContainerHighest,
                                    color: colorScheme.primary,
                                  ),
                                  Icon(
                                    Icons.flag,
                                    size: 12,
                                    color: colorScheme.primary,
                                  ),
                                ],
                              ),
                              onSelected: (_) {
                                setState(() {
                                  if (isSelected) {
                                    _selectedGoal = null;
                                  } else {
                                    _selectedGoal = goal;
                                  }
                                });
                              },
                            );
                          }).toList(),
                        );
                      },
                    ),
                const SizedBox(height: 24),
              ],

              // Payment Mode Selection
              if (_type.isExpense) ...[
                Text('Payment Mode', style: theme.textTheme.labelLarge),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      [
                        'Cash',
                        'UPI',
                        'Debit Card',
                        'Credit Card',
                        'Net Banking',
                      ].map((mode) {
                        final isSelected = _selectedPaymentMode == mode;
                        return ChoiceChip(
                          label: Text(mode),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedPaymentMode = selected ? mode : null;
                            });
                          },
                          avatar: isSelected
                              ? Icon(
                                  Icons.check,
                                  size: 18,
                                  color: colorScheme.onSecondaryContainer,
                                )
                              : null,
                        );
                      }).toList(),
                ),
                const SizedBox(height: 24),
              ],

              // Date Selection
              Text('Date', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outline.withAlpha(50),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        Formatters.date(_selectedDate),
                        style: theme.textTheme.bodyLarge,
                      ),
                      const Spacer(),
                      Text(
                        Formatters.relativeDate(_selectedDate),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Receipt/Photo Section
              Text('Receipt / Photo (optional)', style: theme.textTheme.labelLarge),
              const SizedBox(height: 12),
              if (_receiptImagePath != null) ...[
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    GestureDetector(
                      onTap: () {
                        // Show full-screen image
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(
                                title: const Text('Receipt'),
                                backgroundColor: Colors.black,
                              ),
                              body: Center(
                                child: InteractiveViewer(
                                  child: Image.file(
                                    File(_receiptImagePath!),
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              backgroundColor: Colors.black,
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_receiptImagePath!),
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CircleAvatar(
                        backgroundColor: colorScheme.surface,
                        child: IconButton(
                          icon: Icon(Icons.close, color: colorScheme.error),
                          onPressed: () {
                            setState(() => _receiptImagePath = null);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton.icon(
                onPressed: _showImagePickerOptions,
                icon: Icon(_receiptImagePath != null ? Icons.edit : Icons.camera_alt),
                label: Text(_receiptImagePath != null ? 'Change Photo' : 'Add Photo'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeToggle(
    String label,
    TransactionType type,
    Color activeColor,
  ) {
    final isSelected = _type == type;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => setState(() {
        _type = type;
        _selectedCategory = null; // Reset category on type change
        _selectedGoal = null; // Reset goal on type change
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String iconName) {
    final iconMap = {
      'restaurant': Icons.restaurant,
      'directions_car': Icons.directions_car,
      'shopping_bag': Icons.shopping_bag,
      'movie': Icons.movie,
      'receipt_long': Icons.receipt_long,
      'local_hospital': Icons.local_hospital,
      'school': Icons.school,
      'spa': Icons.spa,
      'local_grocery_store': Icons.local_grocery_store,
      'more_horiz': Icons.more_horiz,
      'work': Icons.work,
      'laptop': Icons.laptop,
      'trending_up': Icons.trending_up,
      'attach_money': Icons.attach_money,
      'card_giftcard': Icons.card_giftcard,
      'savings': Icons.savings,
      'show_chart': Icons.show_chart,
      'family_restroom': Icons.family_restroom,
    };
    return iconMap[iconName] ?? Icons.category;
  }
}
