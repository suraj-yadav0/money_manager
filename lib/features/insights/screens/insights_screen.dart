import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../transactions/screens/all_transactions_screen.dart';
import '../services/insights_engine.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(insightsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Insights',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
      ),
      body: insightsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (insights) {
          if (insights.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 64,
                      color: colorScheme.onSurfaceVariant.withAlpha(100),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No insights yet',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add more transactions to get personalized insights about your spending patterns.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: insights.length,
            itemBuilder: (context, index) {
              final insight = insights[index];
              return _InsightCard(insight: insight);
            },
          );
        },
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final Insight insight;

  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = _getSeverityColor(insight.severity);
    final icon = _getTypeIcon(insight.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight.title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _getSeverityLabel(insight.severity),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              insight.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (insight.tip != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withAlpha(50),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withAlpha(50),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        insight.tip!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (insight.actionText != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  if (insight.type == InsightType.spendingSpike ||
                      insight.type == InsightType.categoryDominance ||
                      insight.type == InsightType.weekendSpending ||
                      insight.type == InsightType.monthOverMonth) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AllTransactionsScreen(),
                      ),
                    );
                  } else if (insight.type == InsightType.budgetOverrun ||
                      insight.type == InsightType.forecastWarning) {
                    // Navigate to dashboard which has forecast and balance
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const DashboardScreen(),
                      ),
                      (route) => false,
                    );
                  }
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(insight.actionText!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getSeverityColor(InsightSeverity severity) {
    switch (severity) {
      case InsightSeverity.info:
        return AppTheme.categoryColors[0]; // Indigo
      case InsightSeverity.warning:
        return AppTheme.warning;
      case InsightSeverity.critical:
        return AppTheme.danger;
    }
  }

  String _getSeverityLabel(InsightSeverity severity) {
    switch (severity) {
      case InsightSeverity.info:
        return 'Insight';
      case InsightSeverity.warning:
        return 'Attention';
      case InsightSeverity.critical:
        return 'Action Required';
    }
  }

  IconData _getTypeIcon(InsightType type) {
    switch (type) {
      case InsightType.spendingSpike:
        return Icons.trending_up;
      case InsightType.budgetOverrun:
        return Icons.warning_amber;
      case InsightType.categoryDominance:
        return Icons.pie_chart;
      case InsightType.monthOverMonth:
        return Icons.compare_arrows;
      case InsightType.weekendSpending:
        return Icons.weekend;
      case InsightType.goalProgress:
        return Icons.flag;
      case InsightType.forecastWarning:
        return Icons.timeline;
    }
  }
}
