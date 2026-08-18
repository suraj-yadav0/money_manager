import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/sms_providers.dart';

class SmsSimulatorDialog extends ConsumerStatefulWidget {
  const SmsSimulatorDialog({super.key});

  @override
  ConsumerState<SmsSimulatorDialog> createState() => _SmsSimulatorDialogState();
}

class _SmsSimulatorDialogState extends ConsumerState<SmsSimulatorDialog> {
  final _senderController = TextEditingController(text: 'VM-HDFCBK');
  final _bodyController = TextEditingController();
  bool _isLoading = false;

  final List<Map<String, String>> _templates = [
    {
      'name': 'HDFC Swiggy UPI (₹450)',
      'sender': 'VM-HDFCBK',
      'body':
          'Dear Customer, INR 450.00 has been debited from your A/c ending 1234 on 15-AUG-26 at SWIGGY via UPI. Avl Bal: INR 24,550.00. Ref: 423456789012',
    },
    {
      'name': 'SBI Salary Credit (₹65,000)',
      'sender': 'AD-SBISMS',
      'body':
          'Dear Customer, your A/c 5678 has been credited by Rs. 65,000.00 on 01-AUG-26 by Salary/NEFT from ACME TECH CORP. Avail Bal: Rs. 75,000.00 - SBI',
    },
    {
      'name': 'ICICI Amazon Card Txn (₹3,499)',
      'sender': 'VK-ICICIB',
      'body':
          'Dear Customer, your ICICI Bank Credit Card ending 4001 has been used for a transaction of INR 3,499.00 at AMAZON on 10-AUG-26. Info: BIL*AMAZON. Avail Limit: INR 85,000.00.',
    },
    {
      'name': 'Axis Uber Ride (₹320)',
      'sender': 'AX-AXISBK',
      'body':
          'INR 320.00 debited from A/C no. XX3456 on 14-08-26 at UBER via UPI Ref 498765432101. Avail bal INR 11,680.00 - Axis Bank',
    },
    {
      'name': 'Paytm Chai Point (₹120)',
      'sender': 'PAYTMB',
      'body':
          'Paid Rs. 120 to Chai Point on 14 Aug 2026 using Paytm UPI from Bank A/c ending 1234. UPI Ref: 41238910',
    },
    {
      'name': 'Netflix Subscription (₹649)',
      'sender': 'VK-ICICIB',
      'body':
          'Acct XX4001 debited for Rs 649.00 on 12-Aug-26. Info: BIL*NETFLIX. Avail Bal: Rs 8,420.00.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _bodyController.text = _templates.first['body']!;
  }

  @override
  void dispose() {
    _senderController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _injectSms() async {
    final body = _bodyController.text.trim();
    final sender = _senderController.text.trim();
    if (body.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final tx = await ref
          .read(smsScanNotifierProvider.notifier)
          .simulateSms(body, sender: sender);

      if (mounted) {
        Navigator.pop(context);
        if (tx != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Simulated SMS added! Review the swipe card.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message was filtered (not a valid transaction or is OTP/Spam)'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _injectBatch() async {
    setState(() => _isLoading = true);
    try {
      int count = 0;
      for (final t in _templates.take(4)) {
        final tx = await ref
            .read(smsScanNotifierProvider.notifier)
            .simulateSms(t['body']!, sender: t['sender']!);
        if (tx != null) count++;
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $count sample transactions to Review Deck!'),
            backgroundColor: Colors.green,
          ),
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.science, color: AppTheme.narutoOrange),
                    const SizedBox(width: 8),
                    Text(
                      'SMS Transaction Simulator',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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
            const SizedBox(height: 6),
            Text(
              'Test SMS parsing and card deck swiping with realistic Indian bank SMS templates or your own text.',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),

            // Quick templates selector
            Text('Quick Bank Templates', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _templates.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final t = _templates[idx];
                  final isSelected = _bodyController.text == t['body'];
                  return ChoiceChip(
                    label: Text(t['name']!, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _senderController.text = t['sender']!;
                          _bodyController.text = t['body']!;
                        });
                      }
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            // Sender header
            TextFormField(
              controller: _senderController,
              decoration: InputDecoration(
                labelText: 'SMS Sender Header',
                hintText: 'e.g. VM-HDFCBK, AD-SBISMS',
                prefixIcon: const Icon(Icons.send_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
            ),
            const SizedBox(height: 12),

            // SMS Body
            TextFormField(
              controller: _bodyController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'SMS Message Body',
                hintText: 'Paste or edit financial SMS text...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _injectBatch,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Add 4 Samples'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _injectSms,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.narutoOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Inject & Parse SMS'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
