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

/// Service managing bi-directional synchronization between local Drift DB and remote Cloud Firestore
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

  /// Pushes unsynced local Drift records to Cloud Firestore
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
        'updated_at': tx.updatedAt.toIso8601String(),
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
        'updated_at': g.updatedAt.toIso8601String(),
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
        'updated_at': a.updatedAt.toIso8601String(),
      };

      await userDocRef
          .collection('assets')
          .doc(syncId)
          .set(payload, SetOptions(merge: true));

      await (_db.update(_db.assets)..where((t) => t.id.equals(a.id)))
          .write(const AssetsCompanion(isSynced: Value(true)));
      totalUploaded++;
    }

    return totalUploaded;
  }

  /// Pulls remote Cloud Firestore records and merges into local Drift DB
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

    return totalDownloaded;
  }
}
