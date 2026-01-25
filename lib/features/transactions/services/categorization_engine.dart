import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/app_state_provider.dart';

/// Categorization engine that uses rules to auto-categorize transactions
class CategorizationEngine {
  final AppDatabase db;

  CategorizationEngine(this.db);

  /// Get suggested category based on note text
  Future<Category?> suggestCategory(String note) async {
    if (note.isEmpty) return null;

    final rules = await db.select(db.categorizationRules).get();
    final lowerNote = note.toLowerCase();

    // Find matching rules
    final matches = <int, int>{}; // categoryId -> total weight

    for (final rule in rules) {
      if (lowerNote.contains(rule.keyword.toLowerCase())) {
        matches[rule.categoryId] =
            (matches[rule.categoryId] ?? 0) + rule.weight;
      }
    }

    if (matches.isEmpty) return null;

    // Get category with highest weight
    final bestCategoryId = matches.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    return (db.select(
      db.categories,
    )..where((c) => c.id.equals(bestCategoryId))).getSingleOrNull();
  }

  /// Learn from user's category correction
  Future<void> learnFromCorrection(String note, int categoryId) async {
    if (note.isEmpty) return;

    // Extract keywords from note (simple word extraction)
    final words = note.toLowerCase().split(RegExp(r'\s+'));

    for (final word in words) {
      if (word.length < 3) continue; // Skip short words

      // Check if rule already exists
      final existing =
          await (db.select(db.categorizationRules)
                ..where((r) => r.keyword.equals(word))
                ..where((r) => r.categoryId.equals(categoryId)))
              .getSingleOrNull();

      if (existing != null) {
        // Increase weight
        await (db.update(
          db.categorizationRules,
        )..where((r) => r.id.equals(existing.id))).write(
          CategorizationRulesCompanion(weight: Value(existing.weight + 1)),
        );
      } else {
        // Create new rule
        await db
            .into(db.categorizationRules)
            .insert(
              CategorizationRulesCompanion.insert(
                keyword: word,
                categoryId: categoryId,
              ),
            );
      }
    }
  }
}

/// Provider for categorization engine
final categorizationEngineProvider = Provider<CategorizationEngine>((ref) {
  final db = ref.watch(databaseProvider);
  return CategorizationEngine(db);
});
