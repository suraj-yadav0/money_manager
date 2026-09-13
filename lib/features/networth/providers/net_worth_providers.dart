import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/app_state_provider.dart';

/// Asset type enum for UI
enum AssetType {
  savings('savings', 'Savings', Icons.savings_outlined, false),
  investment('investment', 'Investments', Icons.trending_up, false),
  property('property', 'Property', Icons.home_outlined, false),
  gold('gold', 'Gold', Icons.workspace_premium_outlined, false),
  loan('loan', 'Loans', Icons.credit_card_outlined, true),
  other('other', 'Other', Icons.category_outlined, false);

  const AssetType(this.key, this.label, this.icon, this.isLiability);
  final String key;
  final String label;
  final IconData icon;
  final bool isLiability;

  static AssetType fromKey(String key) => AssetType.values.firstWhere(
    (e) => e.key == key,
    orElse: () => AssetType.other,
  );
}

/// Aggregate net worth data
class NetWorthData {
  final double totalIncome;
  final double totalExpenses;
  final double netWorth;
  final double goalSavings;
  final double totalAssets;
  final double totalLiabilities;

  NetWorthData({
    required this.totalIncome,
    required this.totalExpenses,
    required this.netWorth,
    required this.goalSavings,
    required this.totalAssets,
    required this.totalLiabilities,
  });

  factory NetWorthData.empty() => NetWorthData(
    totalIncome: 0,
    totalExpenses: 0,
    netWorth: 0,
    goalSavings: 0,
    totalAssets: 0,
    totalLiabilities: 0,
  );
}

/// Monthly breakdown for chart
class MonthlyNetWorth {
  final DateTime month;
  final double income;
  final double expenses;
  final double net;
  final double cumulativeNetWorth;

  MonthlyNetWorth({
    required this.month,
    required this.income,
    required this.expenses,
    required this.net,
    required this.cumulativeNetWorth,
  });
}

/// Streams all assets from the database
final assetsProvider = StreamProvider<List<Asset>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.assets,
  )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();
});

/// Provider for all-time net worth (includes assets & liabilities)
final netWorthProvider = FutureProvider<NetWorthData>((ref) async {
  final db = ref.watch(databaseProvider);

  final allTransactions = await db.select(db.transactions).get();
  final allAssets = await db.select(db.assets).get();

  double totalIncome = 0;
  double totalExpenses = 0;

  for (final tx in allTransactions) {
    if (tx.type == 'income') {
      totalIncome += tx.amount;
    } else {
      totalExpenses += tx.amount;
    }
  }

  // Get total goal savings
  final goals = await db.select(db.goals).get();
  final goalSavings = goals.fold<double>(0, (sum, g) => sum + g.savedAmount);

  // Calculate asset totals
  double totalAssetValue = 0;
  double totalLiabilityValue = 0;

  for (final asset in allAssets) {
    if (asset.isLiability) {
      totalLiabilityValue += asset.value;
    } else {
      totalAssetValue += asset.value;
    }
  }

  final cashflow = totalIncome - totalExpenses;
  final netWorth = cashflow + totalAssetValue - totalLiabilityValue;

  return NetWorthData(
    totalIncome: totalIncome,
    totalExpenses: totalExpenses,
    netWorth: netWorth,
    goalSavings: goalSavings,
    totalAssets: totalAssetValue,
    totalLiabilities: totalLiabilityValue,
  );
});

/// Provider for monthly net worth trend
final monthlyNetWorthProvider = FutureProvider<List<MonthlyNetWorth>>((
  ref,
) async {
  final db = ref.watch(databaseProvider);

  final allTransactions = await db.select(db.transactions).get();
  if (allTransactions.isEmpty) return [];

  // Group by month
  final Map<String, ({double income, double expenses})> monthlyData = {};

  for (final tx in allTransactions) {
    final key =
        '${tx.timestamp.year}-${tx.timestamp.month.toString().padLeft(2, '0')}';
    final existing = monthlyData[key] ?? (income: 0.0, expenses: 0.0);

    if (tx.type == 'income') {
      monthlyData[key] = (
        income: existing.income + tx.amount,
        expenses: existing.expenses,
      );
    } else {
      monthlyData[key] = (
        income: existing.income,
        expenses: existing.expenses + tx.amount,
      );
    }
  }

  // Sort by date and compute cumulative
  final sortedKeys = monthlyData.keys.toList()..sort();
  final result = <MonthlyNetWorth>[];
  double cumulative = 0;

  for (final key in sortedKeys) {
    final data = monthlyData[key]!;
    final net = data.income - data.expenses;
    cumulative += net;

    final parts = key.split('-');
    final month = DateTime(int.parse(parts[0]), int.parse(parts[1]));

    result.add(
      MonthlyNetWorth(
        month: month,
        income: data.income,
        expenses: data.expenses,
        net: net,
        cumulativeNetWorth: cumulative,
      ),
    );
  }

  return result;
});

/// Selected asset type filter for the UI
final selectedAssetTypeProvider = StateProvider<AssetType?>((ref) => null);
