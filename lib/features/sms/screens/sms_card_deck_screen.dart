import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/database/database.dart';
import '../../../core/presentation/glass_widgets.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../providers/sms_providers.dart';
import '../widgets/sms_swipe_card.dart';
import '../widgets/sms_simulator_dialog.dart';

class SmsCardDeckScreen extends ConsumerStatefulWidget {
  const SmsCardDeckScreen({super.key});

  @override
  ConsumerState<SmsCardDeckScreen> createState() => _SmsCardDeckScreenState();
}

class _SmsCardDeckScreenState extends ConsumerState<SmsCardDeckScreen>
    with SingleTickerProviderStateMixin {
  // Drag animation state
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  final List<int> _historyStack = []; // IDs of swiped cards for undo

  // Local overrides for top card (category, account, note, amount)
  Category? _overrideCategory;
  BankAccount? _overrideAccount;
  String? _overrideNote;
  double? _overrideAmount;

  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _resetOverrides() {
    _overrideCategory = null;
    _overrideAccount = null;
    _overrideNote = null;
    _overrideAmount = null;
  }

  void _swipeRight(SmsTransactionDetail card) {
    HapticFeedback.mediumImpact();
    final cardId = card.smsTransaction.id;
    _historyStack.add(cardId);

    ref.read(smsScanNotifierProvider.notifier).acceptCard(
          cardId,
          categoryId: _overrideCategory?.id ?? card.suggestedCategory?.id,
          accountId: _overrideAccount?.id ?? card.suggestedAccount?.id,
          note: _overrideNote ?? card.smsTransaction.merchant,
          amount: _overrideAmount ?? card.smsTransaction.amount,
        );

    _resetOverrides();
    setState(() {
      _dragOffset = Offset.zero;
      _isDragging = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added transaction: ${card.smsTransaction.merchant ?? "SMS"} (${Formatters.currency(card.smsTransaction.amount)})',
        ),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () => _undoLastSwipe(),
        ),
      ),
    );
  }

  void _swipeLeft(SmsTransactionDetail card) {
    HapticFeedback.lightImpact();
    final cardId = card.smsTransaction.id;
    _historyStack.add(cardId);

    ref.read(smsScanNotifierProvider.notifier).rejectCard(cardId);

    _resetOverrides();
    setState(() {
      _dragOffset = Offset.zero;
      _isDragging = false;
    });
  }

  void _undoLastSwipe() {
    if (_historyStack.isEmpty) return;
    final lastId = _historyStack.removeLast();
    ref.read(smsScanNotifierProvider.notifier).undoCard(lastId);
    HapticFeedback.selectionClick();
  }

  void _showEditDialog(SmsTransactionDetail card) {
    final noteCtrl = TextEditingController(
      text: _overrideNote ?? card.smsTransaction.merchant ?? card.smsTransaction.sender,
    );
    final amountCtrl = TextEditingController(
      text: (_overrideAmount ?? card.smsTransaction.amount).toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Transaction Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note / Merchant',
                prefixIcon: Icon(Icons.edit_note),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                prefixText: '₹ ',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newAmt = double.tryParse(amountCtrl.text.replaceAll(',', ''));
              setState(() {
                _overrideNote = noteCtrl.text.trim();
                if (newAmt != null && newAmt > 0) {
                  _overrideAmount = newAmt;
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final pendingAsync = ref.watch(pendingSmsTransactionsProvider);
    final scanState = ref.watch(smsScanNotifierProvider);

    return GlassScaffold(
      appBar: GlassAppBar(
        title: 'Review SMS Transactions',
        actions: [
          IconButton(
            icon: const Icon(Icons.science_outlined),
            tooltip: 'Simulate Test SMS',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const SmsSimulatorDialog(),
              );
            },
          ),
          IconButton(
            icon: scanState.isScanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            tooltip: 'Scan SMS Inbox',
            onPressed: scanState.isScanning
                ? null
                : () async {
                    final res = await ref
                        .read(smsScanNotifierProvider.notifier)
                        .scanInbox(forceFullScan: true);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(res.message)),
                      );
                    }
                  },
          ),
        ],
      ),
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error loading SMS: $e')),
        data: (cards) {
          if (cards.isEmpty) {
            return _buildEmptyState(context);
          }

          final topCard = cards.first;
          // Apply local overrides
          final activeCard = SmsTransactionDetail(
            smsTransaction: topCard.smsTransaction,
            suggestedCategory: _overrideCategory ?? topCard.suggestedCategory,
            suggestedAccount: _overrideAccount ?? topCard.suggestedAccount,
          );

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  // Progress indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${cards.length} Pending Review',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      if (_historyStack.isNotEmpty)
                        TextButton.icon(
                          onPressed: _undoLastSwipe,
                          icon: const Icon(Icons.undo, size: 16),
                          label: const Text('Undo', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Swipe instruction hint
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_back, size: 14, color: colorScheme.error),
                      const SizedBox(width: 4),
                      Text(
                        'Swipe Left to Reject',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.error.withOpacity(0.8),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Text(
                        'Swipe Right to Add',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.green.withOpacity(0.8),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward, size: 14, color: Colors.green),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Card Stack Area
                  Expanded(
                    child: Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          // 3rd card in background (if exists)
                          if (cards.length > 2)
                            Transform.translate(
                              offset: const Offset(0, 24),
                              child: Transform.scale(
                                scale: 0.88,
                                child: Opacity(
                                  opacity: 0.5,
                                  child: SmsSwipeCard(
                                    detail: cards[2],
                                    onEdit: () {},
                                    onCategoryChanged: (_) {},
                                    onAccountChanged: (_) {},
                                  ),
                                ),
                              ),
                            ),

                          // 2nd card in background (if exists)
                          if (cards.length > 1)
                            Transform.translate(
                              offset: const Offset(0, 12),
                              child: Transform.scale(
                                scale: 0.94,
                                child: Opacity(
                                  opacity: 0.8,
                                  child: SmsSwipeCard(
                                    detail: cards[1],
                                    onEdit: () {},
                                    onCategoryChanged: (_) {},
                                    onAccountChanged: (_) {},
                                  ),
                                ),
                              ),
                            ),

                          // TOP ACTIVE INTERACTIVE CARD
                          GestureDetector(
                            onPanStart: (_) {
                              setState(() => _isDragging = true);
                            },
                            onPanUpdate: (details) {
                              setState(() {
                                _dragOffset += details.delta;
                              });
                            },
                            onPanEnd: (details) {
                              final threshold = 100.0;
                              if (_dragOffset.dx > threshold || details.velocity.pixelsPerSecond.dx > 400) {
                                _swipeRight(activeCard);
                              } else if (_dragOffset.dx < -threshold || details.velocity.pixelsPerSecond.dx < -400) {
                                _swipeLeft(activeCard);
                              } else {
                                // Snap back
                                setState(() {
                                  _dragOffset = Offset.zero;
                                  _isDragging = false;
                                });
                              }
                            },
                            child: Transform.translate(
                              offset: _dragOffset,
                              child: Transform.rotate(
                                angle: _dragOffset.dx / 300 * 0.15,
                                child: SmsSwipeCard(
                                  detail: activeCard,
                                  dragOffset: _dragOffset.dx,
                                  onEdit: () => _showEditDialog(activeCard),
                                  onCategoryChanged: (cat) {
                                    setState(() => _overrideCategory = cat);
                                  },
                                  onAccountChanged: (acc) {
                                    setState(() => _overrideAccount = acc);
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Bottom Action Buttons (Reject, Edit, Undo, Accept)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Reject (Red X)
                      _buildCircularActionButton(
                        icon: Icons.close_rounded,
                        color: const Color(0xFFFF334B),
                        tooltip: 'Reject (Swipe Left)',
                        size: 60,
                        onPressed: () => _swipeLeft(activeCard),
                      ),

                      // Edit Details (Amber Pen)
                      _buildCircularActionButton(
                        icon: Icons.edit_note_rounded,
                        color: AppTheme.electricAmber,
                        tooltip: 'Edit Details',
                        size: 48,
                        onPressed: () => _showEditDialog(activeCard),
                      ),

                      // Undo (Blue)
                      _buildCircularActionButton(
                        icon: Icons.undo_rounded,
                        color: Colors.blueAccent,
                        tooltip: 'Undo',
                        size: 48,
                        onPressed: _historyStack.isNotEmpty ? _undoLastSwipe : null,
                      ),

                      // Accept (Green Check)
                      _buildCircularActionButton(
                        icon: Icons.check_rounded,
                        color: const Color(0xFF00E676),
                        tooltip: 'Add Transaction (Swipe Right)',
                        size: 60,
                        onPressed: () => _swipeRight(activeCard),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCircularActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required double size,
    required VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: onPressed != null
                  ? color.withOpacity(0.15)
                  : Colors.grey.withOpacity(0.1),
              border: Border.all(
                color: onPressed != null
                    ? color.withOpacity(0.4)
                    : Colors.grey.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: onPressed != null
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.25),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Icon(
                icon,
                color: onPressed != null ? color : Colors.grey,
                size: size * 0.45,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.neonGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.narutoOrange.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'All Caught Up!',
              style: GoogleFonts.outfit(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No new pending SMS transactions to review.\nWe will auto-detect incoming bank and UPI alerts.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.sync),
                  label: const Text('Scan Inbox'),
                  onPressed: () {
                    ref
                        .read(smsScanNotifierProvider.notifier)
                        .scanInbox(forceFullScan: true);
                  },
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.science),
                  label: const Text('Simulate SMS'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.narutoOrange,
                  ),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const SmsSimulatorDialog(),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
