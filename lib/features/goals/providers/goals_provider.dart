import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/app_state_provider.dart';

/// Provider for all goals (active and completed)
final allGoalsProvider = StreamProvider<List<Goal>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.goals)..orderBy([
        (g) => OrderingTerm.desc(g.isActive),
        (g) => OrderingTerm.desc(g.createdAt),
      ]))
      .watch();
});

/// Provider for all active goals
final activeGoalsProvider = StreamProvider<List<Goal>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.goals)
        ..where((g) => g.isActive.equals(true))
        ..orderBy([(g) => OrderingTerm.desc(g.createdAt)]))
      .watch();
});

/// Provider for the active (most recent) goal
final activeGoalProvider = StreamProvider<Goal?>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.goals)
        ..where((g) => g.isActive.equals(true))
        ..orderBy([(g) => OrderingTerm.desc(g.createdAt)])
        ..limit(1))
      .watchSingleOrNull();
});

/// Provider for a specific goal by ID
final goalByIdProvider = StreamProvider.family<Goal?, int>((ref, goalId) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.goals,
  )..where((g) => g.id.equals(goalId))).watchSingleOrNull();
});

/// Provider for goal progress percentage
final goalProgressProvider = Provider<double>((ref) {
  final goalAsync = ref.watch(activeGoalProvider);
  return goalAsync.maybeWhen(
    data: (goal) {
      if (goal == null) return 0;
      return (goal.savedAmount / goal.targetAmount).clamp(0.0, 1.0);
    },
    orElse: () => 0,
  );
});

/// Provider for contributions of a specific goal
final goalContributionsProvider =
    StreamProvider.family<List<GoalContribution>, int>((ref, goalId) {
      final db = ref.watch(databaseProvider);
      return (db.select(db.goalContributions)
            ..where((c) => c.goalId.equals(goalId))
            ..orderBy([(c) => OrderingTerm.desc(c.createdAt)]))
          .watch();
    });

/// Service class for goal operations
class GoalService {
  final AppDatabase db;

  GoalService(this.db);

  /// Add a contribution to a goal
  Future<void> addContribution({
    required int goalId,
    required double amount,
    String? note,
  }) async {
    await db.transaction(() async {
      // Insert the contribution record
      await db
          .into(db.goalContributions)
          .insert(
            GoalContributionsCompanion.insert(
              goalId: goalId,
              amount: amount,
              note: Value(note),
            ),
          );

      // Update the goal's savedAmount
      final goal = await (db.select(
        db.goals,
      )..where((g) => g.id.equals(goalId))).getSingle();

      final newSavedAmount = goal.savedAmount + amount;
      final isCompleted = newSavedAmount >= goal.targetAmount;

      await (db.update(db.goals)..where((g) => g.id.equals(goalId))).write(
        GoalsCompanion(
          savedAmount: Value(newSavedAmount),
          isCompleted: Value(isCompleted),
        ),
      );
    });
  }

  /// Create a new goal
  Future<int> createGoal({
    required String name,
    required double targetAmount,
    required DateTime deadline,
  }) async {
    return await db
        .into(db.goals)
        .insert(
          GoalsCompanion.insert(
            name: name,
            targetAmount: targetAmount,
            deadline: deadline,
          ),
        );
  }

  /// Update an existing goal
  Future<void> updateGoal({
    required int goalId,
    String? name,
    double? targetAmount,
    DateTime? deadline,
  }) async {
    await (db.update(db.goals)..where((g) => g.id.equals(goalId))).write(
      GoalsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        targetAmount: targetAmount != null
            ? Value(targetAmount)
            : const Value.absent(),
        deadline: deadline != null ? Value(deadline) : const Value.absent(),
      ),
    );
  }

  /// Delete a goal and its contributions
  Future<void> deleteGoal(int goalId) async {
    await db.transaction(() async {
      // Delete all contributions for this goal
      await (db.delete(
        db.goalContributions,
      )..where((c) => c.goalId.equals(goalId))).go();

      // Delete the goal
      await (db.delete(db.goals)..where((g) => g.id.equals(goalId))).go();
    });
  }

  /// Archive a completed goal
  Future<void> archiveGoal(int goalId) async {
    await (db.update(db.goals)..where((g) => g.id.equals(goalId))).write(
      const GoalsCompanion(isActive: Value(false)),
    );
  }

  /// Delete a contribution and update goal's savedAmount
  Future<void> deleteContribution(GoalContribution contribution) async {
    await db.transaction(() async {
      // Get the goal
      final goal = await (db.select(
        db.goals,
      )..where((g) => g.id.equals(contribution.goalId))).getSingle();

      // Update the goal's savedAmount
      final newSavedAmount = (goal.savedAmount - contribution.amount).clamp(
        0.0,
        double.infinity,
      );
      final isCompleted = newSavedAmount >= goal.targetAmount;

      await (db.update(
        db.goals,
      )..where((g) => g.id.equals(contribution.goalId))).write(
        GoalsCompanion(
          savedAmount: Value(newSavedAmount),
          isCompleted: Value(isCompleted),
        ),
      );

      // Delete the contribution
      await (db.delete(
        db.goalContributions,
      )..where((c) => c.id.equals(contribution.id))).go();
    });
  }

  /// Update a contribution amount
  Future<void> updateContribution({
    required GoalContribution contribution,
    required double newAmount,
    String? newNote,
  }) async {
    await db.transaction(() async {
      // Get the goal
      final goal = await (db.select(
        db.goals,
      )..where((g) => g.id.equals(contribution.goalId))).getSingle();

      // Calculate difference and update goal's savedAmount
      final difference = newAmount - contribution.amount;
      final newSavedAmount = (goal.savedAmount + difference).clamp(
        0.0,
        double.infinity,
      );
      final isCompleted = newSavedAmount >= goal.targetAmount;

      await (db.update(
        db.goals,
      )..where((g) => g.id.equals(contribution.goalId))).write(
        GoalsCompanion(
          savedAmount: Value(newSavedAmount),
          isCompleted: Value(isCompleted),
        ),
      );

      // Update the contribution
      await (db.update(
        db.goalContributions,
      )..where((c) => c.id.equals(contribution.id))).write(
        GoalContributionsCompanion(
          amount: Value(newAmount),
          note: newNote != null ? Value(newNote) : const Value.absent(),
        ),
      );
    });
  }
}

/// Provider for goal service
final goalServiceProvider = Provider<GoalService>((ref) {
  final db = ref.watch(databaseProvider);
  return GoalService(db);
});
