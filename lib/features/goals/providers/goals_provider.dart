import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/app_state_provider.dart';

/// Provider for the active (most recent) goal
final activeGoalProvider = StreamProvider<Goal?>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.goals)
        ..where((g) => g.isActive.equals(true))
        ..orderBy([(g) => OrderingTerm.desc(g.createdAt)])
        ..limit(1))
      .watchSingleOrNull();
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
