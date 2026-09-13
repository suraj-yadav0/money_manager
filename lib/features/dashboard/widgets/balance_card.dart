import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/utils/constants.dart';
import '../providers/dashboard_providers.dart';

/// Vibrant Hero Net Balance Card
class BalanceCard extends ConsumerWidget {
  const BalanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final currencySymbol = ref.watch(currencyProvider);
    final settingsAsync = ref.watch(userSettingsProvider);
    final currencyCode =
        settingsAsync.value?.currency ?? AppConstants.defaultCurrency;

    return statsAsync.when(
      loading: () => _buildLoadingCard(context),
      error: (e, st) {
        debugPrint('BALANCE_CARD_ERROR: $e\n$st');
        return _buildErrorCard(context, e.toString());
      },
      data: (stats) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF161A26),
                Color(0xFF0F1118),
                Color(0xFF090A0F),
              ],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: AppTheme.narutoOrange.withValues(alpha: 0.08),
                blurRadius: 32,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Ambient Decorative Circles
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.narutoOrange.withValues(alpha: 0.14),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: -30,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF00C6FF).withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.narutoOrange.withValues(alpha: 0.15),
                                border: Border.all(
                                  color: AppTheme.narutoOrange.withValues(alpha: 0.3),
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: AppTheme.narutoOrange,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Net Balance',
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFA1A7C4),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            currencyCode,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFCBD5E1),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Net Balance Figure
                    Text(
                      Formatters.currency(
                        stats.balance,
                        symbol: currencySymbol,
                      ),
                      style: GoogleFonts.outfit(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                        shadows: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Savings Rate Badge
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.trending_up,
                                size: 14,
                                color: Color(0xFF34D399),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${stats.savingsRate}% saved',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF34D399),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'In selected period',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Divider line
                    Container(
                      height: 1,
                      width: double.infinity,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    const SizedBox(height: 14),

                    // Inflow & Outflow details Row
                    Row(
                      children: [
                        // Inflow Section
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.16),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_downward_rounded,
                                  color: Color(0xFF34D399),
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Period Inflow',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        Formatters.currency(
                                          stats.totalIncome,
                                          symbol: currencySymbol,
                                        ),
                                        style: GoogleFonts.outfit(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF34D399),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Vertical Divider
                        Container(
                          width: 1,
                          height: 28,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        const SizedBox(width: 14),

                        // Outflow Section
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF2A4B).withValues(alpha: 0.16),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_upward_rounded,
                                  color: Color(0xFFF87171),
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Period Outflow',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        Formatters.currency(
                                          stats.totalExpenses,
                                          symbol: currencySymbol,
                                        ),
                                        style: GoogleFonts.outfit(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFFF87171),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingCard(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: AppTheme.narutoOrange.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }

  Widget _buildErrorCard(BuildContext context, String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Text('Error: $error'),
    );
  }
}
