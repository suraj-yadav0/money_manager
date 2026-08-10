import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../config/firebase_config.dart';
import '../database/database.dart';

/// Sync status enum
enum SyncStatus { idle, syncing, success, error, unconfigured }

/// Result details for synchronization
class SyncResult {
  final bool success;
  final String message;
  final int uploadedCount;
  final int downloadedCount;

  SyncResult({
    required this.success,
    required this.message,
    this.uploadedCount = 0,
    this.downloadedCount = 0,
  });
}

/// Service managing full bi-directional synchronization between local Drift DB and remote Cloud Firestore
/// Covers ALL 7 tables: Transactions, Goals, Assets, UserSettings, Categories, GoalContributions, CategorizationRules
class SyncService {
  final AppDatabase _db;
  final Uuid _uuid = const Uuid();

  SyncService(this._db);

  /// Triggers full synchronization (Upload local unsynced records, then Download remote cloud records)
  Future<SyncResult> syncAll() async {
    final db = FirebaseConfig.db;
    final auth = FirebaseConfig.auth;

    if (db == null || auth == null) {
      return SyncResult(
        success: false,
        message: 'Firebase is not configured yet. Operating in Local-Only mode.',
      );
    }

    final user = auth.currentUser;
    if (user == null) {
      return SyncResult(
        success: false,
        message: 'User is not logged in. Operating in Local-Only mode.',
      );
    }

    try {
      int uploaded = await _pushLocalData(user.uid);
      int downloaded = await _pullRemoteData(user.uid);

      return SyncResult(
        success: true,
        message: 'Cloud sync complete ($uploaded uploaded, $downloaded downloaded).',
        uploadedCount: uploaded,
        downloadedCount: downloaded,
      );
    } catch (e, stack) {
      debugPrint('Sync error: $e\n$stack');
      return SyncResult(
        success: false,
        message: 'Sync failed: ${e.toString()}',
      );
    }
  }

  /// Pushes unsynced local Drift records to Cloud Firestore across all 7 tables
  Future<int> _pushLocalData(String userId) async {
    final db = FirebaseConfig.db;
    if (db == null) return 0;
    int totalUploaded = 0;

    final userDocRef = db.collection('users').doc(userId);

    // 1. Transactions
    final unsyncedTx = await (_db.select(_db.transactions)
          ..where((t) => t.isSynced.equals(false)))
        .get();

    for (final tx in unsyncedTx) {
      final syncId = tx.syncId ?? _uuid.v4();
      if (tx.syncId == null) {
        await (_db.update(_db.transactions)..where((t) => t.id.equals(tx.id)))
            .write(TransactionsCompanion(syncId: Value(syncId)));
      }

      final payload = {
        'sync_id': syncId,
        'user_id': userId,
        'amount': tx.amount,
        'type': tx.type,
        'category_id': tx.categoryId,
        'goal_id': tx.goalId,
        'timestamp': tx.timestamp.toIso8601String(),
        'note': tx.note,
        'payment_mode': tx.paymentMode,
        'receipt_image_path': tx.receiptImagePath,
        'is_recurring': tx.isRecurring,
        'created_at': tx.createdAt.toIso8601String(),
        'updated_at': (tx.updatedAt ?? DateTime.now()).toIso8601String(),
      };

      await userDocRef
          .collection('transactions')
          .doc(syncId)
          .set(payload, SetOptions(merge: true));

      await (_db.update(_db.transactions)..where((t) => t.id.equals(tx.id)))
          .write(const TransactionsCompanion(isSynced: Value(true)));
      totalUploaded++;
    }

    // 2. Goals
    final unsyncedGoals = await (_db.select(_db.goals)
          ..where((t) => t.isSynced.equals(false)))
        .get();

    for (final g in unsyncedGoals) {
      final syncId = g.syncId ?? _uuid.v4();
      if (g.syncId == null) {
        await (_db.update(_db.goals)..where((t) => t.id.equals(g.id)))
            .write(GoalsCompanion(syncId: Value(syncId)));
      }

      final payload = {
        'sync_id': syncId,
        'user_id': userId,
        'name': g.name,
        'target_amount': g.targetAmount,
        'saved_amount': g.savedAmount,
        'deadline': g.deadline.toIso8601String(),
        'is_active': g.isActive,
        'is_completed': g.isCompleted,
        'created_at': g.createdAt.toIso8601String(),
        'updated_at': (g.updatedAt ?? DateTime.now()).toIso8601String(),
      };

      await userDocRef
          .collection('goals')
          .doc(syncId)
          .set(payload, SetOptions(merge: true));

      await (_db.update(_db.goals)..where((t) => t.id.equals(g.id)))
          .write(const GoalsCompanion(isSynced: Value(true)));
      totalUploaded++;
    }

    // 3. Assets
    final unsyncedAssets = await (_db.select(_db.assets)
          ..where((t) => t.isSynced.equals(false)))
        .get();

    for (final a in unsyncedAssets) {
      final syncId = a.syncId ?? _uuid.v4();
      if (a.syncId == null) {
        await (_db.update(_db.assets)..where((t) => t.id.equals(a.id)))
            .write(AssetsCompanion(syncId: Value(syncId)));
      }

      final payload = {
        'sync_id': syncId,
        'user_id': userId,
        'name': a.name,
        'type': a.type,
        'value': a.value,
        'is_liability': a.isLiability,
        'note': a.note,
        'created_at': a.createdAt.toIso8601String(),
        'updated_at': (a.updatedAt ?? DateTime.now()).toIso8601String(),
      };

      await userDocRef
          .collection('assets')
          .doc(syncId)
          .set(payload, SetOptions(merge: true));

      await (_db.update(_db.assets)..where((t) => t.id.equals(a.id)))
          .write(const AssetsCompanion(isSynced: Value(true)));
      totalUploaded++;
    }

    // 4. User Settings
    final unsyncedSettings = await (_db.select(_db.userSettings)
          ..where((s) => s.isSynced.equals(false)))
        .get();

    for (final s in unsyncedSettings) {
      final syncId = s.syncId ?? _uuid.v4();
      if (s.syncId == null) {
        await (_db.update(_db.userSettings)..where((u) => u.id.equals(s.id)))
            .write(UserSettingsCompanion(syncId: Value(syncId)));
      }

      final payload = {
        'sync_id': syncId,
        'user_id': userId,
        'monthly_income': s.monthlyIncome,
        'currency': s.currency,
        'is_onboarded': s.isOnboarded,
        'biometric_enabled': s.biometricEnabled,
        'show_income_chart': s.showIncomeChart,
        'created_at': s.createdAt.toIso8601String(),
        'updated_at': (s.updatedAt ?? DateTime.now()).toIso8601String(),
      };

      await userDocRef
          .collection('user_settings')
          .doc(syncId)
          .set(payload, SetOptions(merge: true));

      await (_db.update(_db.userSettings)..where((u) => u.id.equals(s.id)))
          .write(const UserSettingsCompanion(isSynced: Value(true)));
      totalUploaded++;
    }

    // 5. Categories
    final unsyncedCat = await (_db.select(_db.categories)
          ..where((c) => c.isSynced.equals(false)))
        .get();

    for (final c in unsyncedCat) {
      final syncId = c.syncId ?? _uuid.v4();
      if (c.syncId == null) {
        await (_db.update(_db.categories)..where((cat) => cat.id.equals(c.id)))
            .write(CategoriesCompanion(syncId: Value(syncId)));
      }

      final payload = {
        'sync_id': syncId,
        'user_id': userId,
        'name': c.name,
        'icon': c.icon,
        'monthly_budget': c.monthlyBudget,
        'type': c.type,
        'is_default': c.isDefault,
        'updated_at': (c.updatedAt ?? DateTime.now()).toIso8601String(),
      };

      await userDocRef
          .collection('categories')
          .doc(syncId)
          .set(payload, SetOptions(merge: true));

      await (_db.update(_db.categories)..where((cat) => cat.id.equals(c.id)))
          .write(const CategoriesCompanion(isSynced: Value(true)));
      totalUploaded++;
    }

    // 6. Goal Contributions
    final unsyncedGc = await (_db.select(_db.goalContributions)
          ..where((gc) => gc.isSynced.equals(false)))
        .get();

    for (final gc in unsyncedGc) {
      final syncId = gc.syncId ?? _uuid.v4();
      if (gc.syncId == null) {
        await (_db.update(_db.goalContributions)..where((g) => g.id.equals(gc.id)))
            .write(GoalContributionsCompanion(syncId: Value(syncId)));
      }

      final payload = {
        'sync_id': syncId,
        'user_id': userId,
        'goal_id': gc.goalId,
        'amount': gc.amount,
        'note': gc.note,
        'created_at': gc.createdAt.toIso8601String(),
        'updated_at': (gc.updatedAt ?? DateTime.now()).toIso8601String(),
      };

      await userDocRef
          .collection('goal_contributions')
          .doc(syncId)
          .set(payload, SetOptions(merge: true));

      await (_db.update(_db.goalContributions)..where((g) => g.id.equals(gc.id)))
          .write(const GoalContributionsCompanion(isSynced: Value(true)));
      totalUploaded++;
    }

    // 7. Categorization Rules
    final unsyncedRules = await (_db.select(_db.categorizationRules)
          ..where((r) => r.isSynced.equals(false)))
        .get();

    for (final r in unsyncedRules) {
      final syncId = r.syncId ?? _uuid.v4();
      if (r.syncId == null) {
        await (_db.update(_db.categorizationRules)..where((rule) => rule.id.equals(r.id)))
            .write(CategorizationRulesCompanion(syncId: Value(syncId)));
      }

      final payload = {
        'sync_id': syncId,
        'user_id': userId,
        'keyword': r.keyword,
        'category_id': r.categoryId,
        'weight': r.weight,
        'updated_at': (r.updatedAt ?? DateTime.now()).toIso8601String(),
      };

      await userDocRef
          .collection('categorization_rules')
          .doc(syncId)
          .set(payload, SetOptions(merge: true));

      await (_db.update(_db.categorizationRules)..where((rule) => rule.id.equals(r.id)))
          .write(const CategorizationRulesCompanion(isSynced: Value(true)));
      totalUploaded++;
    }

    return totalUploaded;
  }

  /// Pulls remote Cloud Firestore records and merges into local Drift DB across all 7 tables
  Future<int> _pullRemoteData(String userId) async {
    final db = FirebaseConfig.db;
    if (db == null) return 0;
    int totalDownloaded = 0;

    final userDocRef = db.collection('users').doc(userId);

    // Helper to safely parse dates from string or Firestore Timestamp
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.parse(value);
      return DateTime.now();
    }

    // 1. Pull Remote Transactions
    try {
      final snapshot = await userDocRef.collection('transactions').get();

      for (final doc in snapshot.docs) {
        final raw = doc.data();
        final syncId = (raw['sync_id'] as String?) ?? doc.id;

        final existing = await (_db.select(_db.transactions)
              ..where((t) => t.syncId.equals(syncId)))
            .getSingleOrNull();

        if (existing == null) {
          final timestamp = parseDate(raw['timestamp']);
          final createdAt = parseDate(raw['created_at']);
          final updatedAt = raw['updated_at'] != null
              ? parseDate(raw['updated_at'])
              : DateTime.now();

          await _db.into(_db.transactions).insert(
                TransactionsCompanion.insert(
                  syncId: Value(syncId),
                  amount: (raw['amount'] as num).toDouble(),
                  type: raw['type'] as String,
                  categoryId: raw['category_id'] as int? ?? 1,
                  goalId: Value(raw['goal_id'] as int?),
                  timestamp: timestamp,
                  note: Value(raw['note'] as String?),
                  paymentMode: Value(raw['payment_mode'] as String?),
                  receiptImagePath: Value(raw['receipt_image_path'] as String?),
                  isRecurring: Value(raw['is_recurring'] as bool? ?? false),
                  isSynced: const Value(true),
                  createdAt: Value(createdAt),
                  updatedAt: Value(updatedAt),
                ),
              );
          totalDownloaded++;
        }
      }
    } catch (e) {
      debugPrint('Error pulling transactions: $e');
    }

    // 2. Pull Remote Goals
    try {
      final snapshot = await userDocRef.collection('goals').get();

      for (final doc in snapshot.docs) {
        final raw = doc.data();
        final syncId = (raw['sync_id'] as String?) ?? doc.id;

        final existing = await (_db.select(_db.goals)
              ..where((g) => g.syncId.equals(syncId)))
            .getSingleOrNull();

        if (existing == null) {
          final deadline = parseDate(raw['deadline']);

          await _db.into(_db.goals).insert(
                GoalsCompanion.insert(
                  syncId: Value(syncId),
                  name: raw['name'] as String,
                  targetAmount: (raw['target_amount'] as num).toDouble(),
                  deadline: deadline,
                  savedAmount: Value((raw['saved_amount'] as num? ?? 0).toDouble()),
                  isActive: Value(raw['is_active'] as bool? ?? true),
                  isCompleted: Value(raw['is_completed'] as bool? ?? false),
                  isSynced: const Value(true),
                ),
              );
          totalDownloaded++;
        }
      }
    } catch (e) {
      debugPrint('Error pulling goals: $e');
    }

    // 3. Pull Remote Assets
    try {
      final snapshot = await userDocRef.collection('assets').get();

      for (final doc in snapshot.docs) {
        final raw = doc.data();
        final syncId = (raw['sync_id'] as String?) ?? doc.id;

        final existing = await (_db.select(_db.assets)
              ..where((a) => a.syncId.equals(syncId)))
            .getSingleOrNull();

        if (existing == null) {
          await _db.into(_db.assets).insert(
                AssetsCompanion.insert(
                  syncId: Value(syncId),
                  name: raw['name'] as String,
                  type: raw['type'] as String,
                  value: (raw['value'] as num).toDouble(),
                  isLiability: Value(raw['is_liability'] as bool? ?? false),
                  note: Value(raw['note'] as String?),
                  isSynced: const Value(true),
                ),
              );
          totalDownloaded++;
        }
      }
    } catch (e) {
      debugPrint('Error pulling assets: $e');
    }

    // 4. Pull Remote User Settings
    try {
      final snapshot = await userDocRef.collection('user_settings').get();

      for (final doc in snapshot.docs) {
        final raw = doc.data();
        final syncId = (raw['sync_id'] as String?) ?? doc.id;

        final existing = await (_db.select(_db.userSettings)
              ..where((s) => s.syncId.equals(syncId)))
            .getSingleOrNull();

        if (existing == null) {
          await _db.into(_db.userSettings).insertOnConflictUpdate(
                UserSettingsCompanion.insert(
                  id: const Value(1),
                  syncId: Value(syncId),
                  monthlyIncome: Value((raw['monthly_income'] as num? ?? 0).toDouble()),
                  currency: Value(raw['currency'] as String? ?? 'INR'),
                  isOnboarded: Value(raw['is_onboarded'] as bool? ?? false),
                  biometricEnabled: Value(raw['biometric_enabled'] as bool? ?? false),
                  showIncomeChart: Value(raw['show_income_chart'] as bool? ?? false),
                  isSynced: const Value(true),
                ),
              );
          totalDownloaded++;
        }
      }
    } catch (e) {
      debugPrint('Error pulling user_settings: $e');
    }

    // 5. Pull Remote Categories
    try {
      final snapshot = await userDocRef.collection('categories').get();

      for (final doc in snapshot.docs) {
        final raw = doc.data();
        final syncId = (raw['sync_id'] as String?) ?? doc.id;

        final existing = await (_db.select(_db.categories)
              ..where((c) => c.syncId.equals(syncId)))
            .getSingleOrNull();

        if (existing == null) {
          await _db.into(_db.categories).insert(
                CategoriesCompanion.insert(
                  syncId: Value(syncId),
                  name: raw['name'] as String,
                  icon: raw['icon'] as String,
                  monthlyBudget: Value((raw['monthly_budget'] as num?)?.toDouble()),
                  type: Value(raw['type'] as String? ?? 'expense'),
                  isDefault: Value(raw['is_default'] as bool? ?? false),
                  isSynced: const Value(true),
                ),
              );
          totalDownloaded++;
        }
      }
    } catch (e) {
      debugPrint('Error pulling categories: $e');
    }

    // 6. Pull Remote Goal Contributions
    try {
      final snapshot = await userDocRef.collection('goal_contributions').get();

      for (final doc in snapshot.docs) {
        final raw = doc.data();
        final syncId = (raw['sync_id'] as String?) ?? doc.id;

        final existing = await (_db.select(_db.goalContributions)
              ..where((gc) => gc.syncId.equals(syncId)))
            .getSingleOrNull();

        if (existing == null) {
          await _db.into(_db.goalContributions).insert(
                GoalContributionsCompanion.insert(
                  syncId: Value(syncId),
                  goalId: raw['goal_id'] as int,
                  amount: (raw['amount'] as num).toDouble(),
                  note: Value(raw['note'] as String?),
                  isSynced: const Value(true),
                ),
              );
          totalDownloaded++;
        }
      }
    } catch (e) {
      debugPrint('Error pulling goal_contributions: $e');
    }

    // 7. Pull Remote Categorization Rules
    try {
      final snapshot = await userDocRef.collection('categorization_rules').get();

      for (final doc in snapshot.docs) {
        final raw = doc.data();
        final syncId = (raw['sync_id'] as String?) ?? doc.id;

        final existing = await (_db.select(_db.categorizationRules)
              ..where((r) => r.syncId.equals(syncId)))
            .getSingleOrNull();

        if (existing == null) {
          await _db.into(_db.categorizationRules).insert(
                CategorizationRulesCompanion.insert(
                  syncId: Value(syncId),
                  keyword: raw['keyword'] as String,
                  categoryId: raw['category_id'] as int,
                  weight: Value(raw['weight'] as int? ?? 1),
                  isSynced: const Value(true),
                ),
              );
          totalDownloaded++;
        }
      }
    } catch (e) {
      debugPrint('Error pulling categorization_rules: $e');
    }

    return totalDownloaded;
  }
}
