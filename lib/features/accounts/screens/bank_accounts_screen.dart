import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/database/database.dart';
import '../../../core/presentation/glass_widgets.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../providers/account_providers.dart';
import '../widgets/add_account_sheet.dart';

class BankAccountsScreen extends ConsumerWidget {
  const BankAccountsScreen({super.key});

  void _showAddEditSheet(BuildContext context, [BankAccount? account]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddAccountSheet(accountToEdit: account),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final accountsAsync = ref.watch(bankAccountsStreamProvider);
    final summary = ref.watch(accountBalanceSummaryProvider);

    return GlassScaffold(
      appBar: GlassAppBar(
        title: 'Bank Accounts & Cards',
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _showAddEditSheet(context),
            tooltip: 'Add Bank Account',
          ),
        ],
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error loading accounts: $e')),
        data: (accounts) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary Glass Card
              GlassContainer(
                padding: const EdgeInsets.all(20),
                gradientColors: [
                  AppTheme.narutoOrange.withOpacity(0.25),
                  AppTheme.electricAmber.withOpacity(0.1),
                ],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Liquid Funds',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.narutoOrange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${accounts.length} Accounts',
                            style: GoogleFonts.outfit(
                              color: AppTheme.narutoOrange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      Formatters.currency(summary.totalLiquid),
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (summary.totalCreditDebt > 0) ...[
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Credit Card Outstanding:',
                              style: theme.textTheme.bodySmall),
                          Text(
                            Formatters.currency(summary.totalCreditDebt),
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Linked Accounts & Cards',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              if (accounts.isEmpty) ...[
                GlassContainer(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.account_balance_outlined,
                          size: 48, color: colorScheme.primary),
                      const SizedBox(height: 12),
                      const Text(
                        'No bank accounts linked yet',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Add your bank accounts and credit cards to automatically match SMS alerts and keep your balances in sync.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Account'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.narutoOrange,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _showAddEditSheet(context),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                ...accounts.map((acc) => _buildAccountCard(context, ref, acc)),
              ],
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAccountCard(
      BuildContext context, WidgetRef ref, BankAccount account) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final colorHex = account.colorHex ?? '#FF5F1F';
    final cardColor = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));

    IconData typeIcon = Icons.account_balance;
    String typeLabel = 'Savings';
    if (account.accountType == 'credit_card') {
      typeIcon = Icons.credit_card;
      typeLabel = 'Credit Card';
    } else if (account.accountType == 'current') {
      typeIcon = Icons.business;
      typeLabel = 'Current A/c';
    } else if (account.accountType == 'wallet') {
      typeIcon = Icons.account_balance_wallet;
      typeLabel = 'Cash Wallet';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Bank Icon / Color Indicator
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: cardColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cardColor.withOpacity(0.4)),
              ),
              child: Icon(typeIcon, color: cardColor, size: 24),
            ),
            const SizedBox(width: 14),

            // Account Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          account.name,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (account.isDefault) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'DEFAULT',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        account.bankName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (account.accountNumberLast4 != null) ...[
                        Text(
                          ' •••• ${account.accountNumberLast4}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      Text(
                        '($typeLabel)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Balance & More options
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Formatters.currency(account.balance),
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: account.accountType == 'credit_card'
                        ? colorScheme.error
                        : colorScheme.onSurface,
                  ),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (val) async {
                    if (val == 'edit') {
                      _showAddEditSheet(context, account);
                    } else if (val == 'default') {
                      await ref
                          .read(accountNotifierProvider.notifier)
                          .setDefaultAccount(account.id);
                    } else if (val == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete Account?'),
                          content: Text(
                              'Are you sure you want to remove "${account.name}"? Existing transactions will keep their records.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                  backgroundColor: colorScheme.error),
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref
                            .read(accountNotifierProvider.notifier)
                            .deleteAccount(account.id);
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    if (!account.isDefault)
                      const PopupMenuItem(
                        value: 'default',
                        child: Row(
                          children: [
                            Icon(Icons.star_outline, size: 18),
                            SizedBox(width: 8),
                            Text('Set as Default'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
