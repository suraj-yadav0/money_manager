import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database.dart';
import '../providers/app_state_provider.dart';
import '../providers/auth_providers.dart';
import '../../features/dashboard/providers/dashboard_providers.dart';
import '../../features/goals/providers/goals_provider.dart';
import '../../features/accounts/providers/account_providers.dart';

/// Service responsible for exporting and importing complete JSON backups
class BackupService {
  final AppDatabase _db;

  BackupService(this._db);

  /// Serialize all database records to a JSON Map
  Future<Map<String, dynamic>> createBackupPayload() async {
    final userSettings = await _db.select(_db.userSettings).getSingleOrNull();
    final categories = await _db.select(_db.categories).get();
    final bankAccounts = await _db.select(_db.bankAccounts).get();
    final transactions = await _db.select(_db.transactions).get();
    final goals = await _db.select(_db.goals).get();
    final goalContributions = await _db.select(_db.goalContributions).get();
    final assets = await _db.select(_db.assets).get();

    return {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'userSettings': userSettings?.toJson(),
      'categories': categories.map((c) => c.toJson()).toList(),
      'bankAccounts': bankAccounts.map((b) => b.toJson()).toList(),
      'transactions': transactions.map((t) => t.toJson()).toList(),
      'goals': goals.map((g) => g.toJson()).toList(),
      'goalContributions': goalContributions.map((c) => c.toJson()).toList(),
      'assets': assets.map((a) => a.toJson()).toList(),
    };
  }

  /// Write backup JSON to a cache file and open the system share sheet
  Future<bool> exportAndShareBackup() async {
    final payload = await createBackupPayload();
    final jsonString = const JsonEncoder.withIndent('  ').convert(payload);

    final tempDir = await getTemporaryDirectory();
    final dateTag = DateTime.now().toIso8601String().split('T').first;
    final file = File('${tempDir.path}/money_manager_backup_$dateTag.json');
    await file.writeAsString(jsonString);

    final xFile = XFile(file.path, mimeType: 'application/json');
    final result = await Share.shareXFiles(
      [xFile],
      subject: 'Money Manager Backup $dateTag',
      text: 'Money Manager Complete Backup ($dateTag)',
    );

    return result.status == ShareResultStatus.success;
  }

  /// Open file picker, select a backup JSON file, and restore into database
  Future<Map<String, int>?> importBackup(WidgetRef ref) async {
    final pickerResult = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (pickerResult == null || pickerResult.files.single.path == null) {
      return null;
    }

    final file = File(pickerResult.files.single.path!);
    final content = await file.readAsString();
    final dynamic rawData = jsonDecode(content);

    if (rawData is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup file format');
    }

    int txCount = 0;
    int catCount = 0;
    int accCount = 0;
    int goalCount = 0;
    int assetCount = 0;

    // 1. Categories
    if (rawData['categories'] is List) {
      for (final catJson in rawData['categories'] as List) {
        if (catJson is! Map<String, dynamic>) continue;
        try {
          final cat = Category.fromJson(catJson);
          final existing = await (_db.select(_db.categories)
                ..where((c) => c.name.equals(cat.name)))
              .getSingleOrNull();
          if (existing == null) {
            await _db.into(_db.categories).insert(
                  cat.toCompanion(false),
                  mode: InsertMode.insertOrReplace,
                );
            catCount++;
          }
        } catch (e) {
          debugPrint('Error restoring category: $e');
        }
      }
    }

    // 2. Bank Accounts
    if (rawData['bankAccounts'] is List) {
      for (final accJson in rawData['bankAccounts'] as List) {
        if (accJson is! Map<String, dynamic>) continue;
        try {
          final acc = BankAccount.fromJson(accJson);
          final existing = await (_db.select(_db.bankAccounts)
                ..where((a) =>
                    a.name.equals(acc.name) &
                    (acc.accountNumberLast4 != null
                        ? a.accountNumberLast4.equals(acc.accountNumberLast4!)
                        : a.accountNumberLast4.isNull())))
              .getSingleOrNull();
          if (existing == null) {
            await _db.into(_db.bankAccounts).insert(
                  acc.toCompanion(false),
                  mode: InsertMode.insertOrReplace,
                );
            accCount++;
          } else {
            await (_db.update(_db.bankAccounts)
                  ..where((a) => a.id.equals(existing.id)))
                .write(acc.toCompanion(false));
          }
        } catch (e) {
          debugPrint('Error restoring bank account: $e');
        }
      }
    }

    // 3. Goals
    if (rawData['goals'] is List) {
      for (final goalJson in rawData['goals'] as List) {
        if (goalJson is! Map<String, dynamic>) continue;
        try {
          final goal = Goal.fromJson(goalJson);
          await _db.into(_db.goals).insert(
                goal.toCompanion(false),
                mode: InsertMode.insertOrReplace,
              );
          goalCount++;
        } catch (e) {
          debugPrint('Error restoring goal: $e');
        }
      }
    }

    // 4. Assets
    if (rawData['assets'] is List) {
      for (final assetJson in rawData['assets'] as List) {
        if (assetJson is! Map<String, dynamic>) continue;
        try {
          final asset = Asset.fromJson(assetJson);
          await _db.into(_db.assets).insert(
                asset.toCompanion(false),
                mode: InsertMode.insertOrReplace,
              );
          assetCount++;
        } catch (e) {
          debugPrint('Error restoring asset: $e');
        }
      }
    }

    // 5. Transactions
    if (rawData['transactions'] is List) {
      for (final txJson in rawData['transactions'] as List) {
        if (txJson is! Map<String, dynamic>) continue;
        try {
          final tx = Transaction.fromJson(txJson);
          await _db.into(_db.transactions).insert(
                tx.toCompanion(false),
                mode: InsertMode.insertOrReplace,
              );
          txCount++;
        } catch (e) {
          debugPrint('Error restoring transaction: $e');
        }
      }
    }

    // 6. User Settings
    if (rawData['userSettings'] is Map<String, dynamic>) {
      try {
        final settings = UserSetting.fromJson(rawData['userSettings']);
        await _db.into(_db.userSettings).insertOnConflictUpdate(
              settings.toCompanion(false),
            );
      } catch (e) {
        debugPrint('Error restoring user settings: $e');
      }
    }

    // Deduplicate any bank accounts that might have clashed
    await _db.deduplicateBankAccounts();

    // Invalidate state providers to refresh all screens
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(recentTransactionsProvider);
    ref.invalidate(allTransactionsProvider);
    ref.invalidate(bankAccountsStreamProvider);
    ref.invalidate(activeGoalsProvider);
    ref.invalidate(userSettingsProvider);

    // Trigger cloud sync if signed in
    final currentUser = ref.read(currentUserProvider);
    if (currentUser != null) {
      ref.read(syncNotifierProvider.notifier).triggerSync();
    }

    return {
      'transactions': txCount,
      'categories': catCount,
      'bankAccounts': accCount,
      'goals': goalCount,
      'assets': assetCount,
    };
  }
}

/// Provider for BackupService
final backupServiceProvider = Provider<BackupService>((ref) {
  final db = ref.watch(databaseProvider);
  return BackupService(db);
});
