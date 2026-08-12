/* Keyword-based auto categorization engine matching categorization_engine.dart */
import { StateManager } from '../state.js';
import { DbService } from '../db.js';

export const CategorizationEngine = {
  // Suggest category based on note text keyword matching
  suggestCategory(note, categories, rules) {
    if (!note || note.trim() === '') return null;
    
    const lowerNote = note.toLowerCase();
    const matches = {}; // categoryId -> total weight

    for (const rule of rules) {
      if (lowerNote.includes(rule.keyword.toLowerCase())) {
        const catId = rule.category_id;
        matches[catId] = (matches[catId] || 0) + (rule.weight || 1);
      }
    }

    const matchEntries = Object.entries(matches);
    if (matchEntries.length === 0) return null;

    // Find category ID with highest weight
    const bestCatId = matchEntries.reduce((best, current) => current[1] > best[1] ? current : best)[0];
    
    // Find category in state list (supporting either numeric ID or Firestore UUID)
    return categories.find(c => c.id == bestCatId || c.sync_id == bestCatId) || null;
  },

  // Learn from user's manual category correction
  async learnFromCorrection(note, categoryId) {
    if (!note || note.trim() === '') return;

    // Simple word extractor
    const words = note.toLowerCase().split(/\s+/);
    
    for (const word of words) {
      if (word.length < 3) continue; // skip short words

      // Check if categorization rule already exists for this keyword and category
      const existingRule = StateManager.state.categorizationRules.find(r => 
        r.keyword.toLowerCase() === word && 
        (r.category_id == categoryId)
      );

      if (existingRule) {
        // Increment weight
        const newWeight = (existingRule.weight || 1) + 1;
        await DbService.updateRuleWeight(existingRule.sync_id, existingRule.id, newWeight);
      } else {
        // Create new keyword rule
        await DbService.addRule(word, categoryId);
      }
    }
  }
};
