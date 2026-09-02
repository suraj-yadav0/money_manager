import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/database/database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/icon_helper.dart';
import '../../accounts/providers/account_providers.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../providers/sms_providers.dart';

class SmsSwipeCard extends ConsumerStatefulWidget {
  final SmsTransactionDetail detail;
  final double dragOffset; // Horizontal drag offset for stamp rendering
  final VoidCallback onEdit;
  final Function(Category) onCategoryChanged;
  final Function(BankAccount) onAccountChanged;

  const SmsSwipeCard({
    super.key,
    required this.detail,
    this.dragOffset = 0.0,
    required this.onEdit,
    required this.onCategoryChanged,
    required this.onAccountChanged,
  });

  @override
  ConsumerState<SmsSwipeCard> createState() => _SmsSwipeCardState();
}

class _SmsSwipeCardState extends ConsumerState<SmsSwipeCard> {
  bool _showRawSms = false;

  void _showCategoryPicker(BuildContext context) {
    final categoriesAsync = widget.detail.smsTransaction.type == 'income'
        ? ref.read(incomeCategoriesProvider)
        : ref.read(expenseCategoriesProvider);

    categoriesAsync.whenData((categories) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E1E2E)
                : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Category',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories.map((cat) {
                  final isSelected =
                      widget.detail.suggestedCategory?.id == cat.id;
                  return FilterChip(
                    selected: isSelected,
                    label: Text(cat.name),
                    avatar: Icon(IconHelper.getIcon(cat.icon), size: 18),
                    onSelected: (_) {
                      Navigator.pop(ctx);
                      widget.onCategoryChanged(cat);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    });
  }

  void _showAccountPicker(BuildContext context) {
    final accountsAsync = ref.read(bankAccountsStreamProvider);

    accountsAsync.whenData((accounts) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E1E2E)
                : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Bank Account / Card',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...accounts.map((acc) {
                final isSelected = widget.detail.suggestedAccount?.id == acc.id;
                return ListTile(
                  leading: Icon(
                    acc.accountType == 'credit_card'
                        ? Icons.credit_card
                        : Icons.account_balance,
                    color: AppTheme.narutoOrange,
                  ),
                  title: Text(acc.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${acc.bankName} ${acc.accountNumberLast4 != null ? "•••• ${acc.accountNumberLast4}" : ""}'),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onAccountChanged(acc);
                  },
                );
              }),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final sms = widget.detail.smsTransaction;
    final isExpense = sms.type == 'expense';
    final accentColor = isExpense ? const Color(0xFFFF4B4B) : const Color(0xFF00E676);

    // Calculate swipe stamp opacity
    final rightProgress = (widget.dragOffset / 100).clamp(0.0, 1.0);
    final leftProgress = (-widget.dragOffset / 100).clamp(0.0, 1.0);

    return Container(
      constraints: const BoxConstraints(maxHeight: 520),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF262837).withOpacity(0.95),
                  const Color(0xFF1E1E2E).withOpacity(0.95),
                ]
              : [
                  Colors.white.withOpacity(0.95),
                  const Color(0xFFF4F6FA).withOpacity(0.95),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.12)
              : Colors.black.withOpacity(0.06),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Ambient Top Glow
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withOpacity(0.12),
                ),
              ),
            ),

            // Card Body Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row: Bank badge + Type chip + Payment mode
                  Row(
                    children: [
                      // Bank Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.outline.withOpacity(0.15),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              sms.paymentMode == 'Credit Card'
                                  ? Icons.credit_card
                                  : Icons.account_balance,
                              size: 14,
                              color: AppTheme.narutoOrange,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              sms.bankName ?? 'Bank Alert',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (sms.accountNumberLast4 != null) ...[
                              Text(
                                ' ••${sms.accountNumberLast4}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Spacer(),

                      // Type Chip (Debited / Credited)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: accentColor.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                              size: 12,
                              color: accentColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isExpense ? 'DEBITED' : 'CREDITED',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Payment Mode Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          sms.paymentMode ?? 'UPI',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Hero Amount
                  Center(
                    child: Column(
                      children: [
                        Text(
                          '${isExpense ? "-" : "+"} ${Formatters.currency(sms.amount)}',
                          style: GoogleFonts.outfit(
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (sms.balance != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Avl Bal: ${Formatters.currency(sms.balance!)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Merchant / Payee Tile
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.outline.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppTheme.narutoOrange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: AppTheme.narutoOrange,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sms.merchant ?? sms.sender,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${Formatters.date(sms.smsTimestamp)} • ${Formatters.time(sms.smsTimestamp)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: widget.onEdit,
                          tooltip: 'Edit details',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Interactive Category & Bank Account Selectors
                  Row(
                    children: [
                      // Category Chip Selector
                      Expanded(
                        child: InkWell(
                          onTap: () => _showCategoryPicker(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: colorScheme.outline.withOpacity(0.1)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  IconHelper.getIcon(
                                      widget.detail.suggestedCategory?.icon ??
                                          'more_horiz'),
                                  size: 16,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    widget.detail.suggestedCategory?.name ??
                                        'Category',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_down, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Bank Account Selector
                      Expanded(
                        child: InkWell(
                          onTap: () => _showAccountPicker(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: colorScheme.outline.withOpacity(0.1)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.account_balance,
                                    size: 16, color: Colors.teal),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    widget.detail.suggestedAccount?.name ??
                                        'Account',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_down, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Expandable Raw SMS View
                  InkWell(
                    onTap: () => setState(() => _showRawSms = !_showRawSms),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            _showRawSms
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _showRawSms ? 'Hide Original SMS' : 'View Original SMS',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_showRawSms) ...[
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        sms.body,
                        style: GoogleFonts.firaCode(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // GREEN "ADD" STAMP OVERLAY (On dragging right)
            if (rightProgress > 0)
              Positioned(
                top: 30,
                left: 30,
                child: Opacity(
                  opacity: rightProgress,
                  child: Transform.rotate(
                    angle: -math.pi / 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF00E676), width: 3),
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFF00E676).withOpacity(0.2),
                      ),
                      child: Text(
                        'ADD TRANSACTION',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF00E676),
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // RED "REJECT" STAMP OVERLAY (On dragging left)
            if (leftProgress > 0)
              Positioned(
                top: 30,
                right: 30,
                child: Opacity(
                  opacity: leftProgress,
                  child: Transform.rotate(
                    angle: math.pi / 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFFF334B), width: 3),
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFFFF334B).withOpacity(0.2),
                      ),
                      child: Text(
                        'DISMISS',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFFF334B),
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
