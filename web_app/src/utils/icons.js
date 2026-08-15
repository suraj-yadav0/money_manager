/* Icon Helper utility (mapping database icon keys to Google Material Icons and Asset Emojis) */
export const IconHelper = {
  // Material icons mapping (string identifier -> Material Icon ligature text)
  getMaterialIcon(iconName) {
    const iconMap = {
      'restaurant': 'restaurant',
      'directions_car': 'directions_car',
      'shopping_bag': 'shopping_bag',
      'movie': 'local_movies',
      'receipt_long': 'receipt_long',
      'local_hospital': 'local_hospital',
      'school': 'school',
      'spa': 'spa',
      'local_grocery_store': 'local_grocery_store',
      'more_horiz': 'more_horiz',
      'work': 'work',
      'laptop': 'laptop',
      'trending_up': 'trending_up',
      'attach_money': 'attach_money',
      'card_giftcard': 'card_giftcard',
      'savings': 'savings',
      'show_chart': 'show_chart', // investments
      'family_restroom': 'family_restroom',
    };
    return iconMap[iconName] || 'category';
  },

  // Emojis for Asset types
  getAssetEmoji(type) {
    const emojiMap = {
      'savings': '💰',
      'investment': '📈',
      'property': '🏠',
      'gold': '🥇',
      'loan': '💳',
      'other': '📦'
    };
    return emojiMap[type] || '📦';
  },

  // Asset Labels
  getAssetLabel(type) {
    const labelMap = {
      'savings': 'Savings',
      'investment': 'Investments',
      'property': 'Property',
      'gold': 'Gold',
      'loan': 'Loans/Liabilities',
      'other': 'Other'
    };
    return labelMap[type] || 'Other';
  }
};

export const DEFAULT_CATEGORIES = [
  { id: 1, name: 'Food & Dining', icon: 'restaurant', type: 'expense', is_default: true },
  { id: 2, name: 'Transport', icon: 'directions_car', type: 'expense', is_default: true },
  { id: 3, name: 'Shopping', icon: 'shopping_bag', type: 'expense', is_default: true },
  { id: 4, name: 'Entertainment', icon: 'movie', type: 'expense', is_default: true },
  { id: 5, name: 'Bills & Utilities', icon: 'receipt_long', type: 'expense', is_default: true },
  { id: 6, name: 'Health', icon: 'local_hospital', type: 'expense', is_default: true },
  { id: 7, name: 'Education', icon: 'school', type: 'expense', is_default: true },
  { id: 8, name: 'Self Care', icon: 'spa', type: 'expense', is_default: true },
  { id: 9, name: 'Groceries', icon: 'local_grocery_store', type: 'expense', is_default: true },
  { id: 10, name: 'Gifts', icon: 'card_giftcard', type: 'expense', is_default: true },
  { id: 11, name: 'Savings', icon: 'savings', type: 'expense', is_default: true },
  { id: 12, name: 'Investments', icon: 'show_chart', type: 'expense', is_default: true },
  { id: 13, name: 'Family', icon: 'family_restroom', type: 'expense', is_default: true },
  { id: 14, name: 'Other', icon: 'more_horiz', type: 'expense', is_default: true },
  { id: 15, name: 'Salary', icon: 'work', type: 'income', is_default: true },
  { id: 16, name: 'Freelance', icon: 'laptop', type: 'income', is_default: true },
  { id: 17, name: 'Investment', icon: 'trending_up', type: 'income', is_default: true },
  { id: 18, name: 'Other Income', icon: 'attach_money', type: 'income', is_default: true }
];

export function findCategory(categories, categoryId) {
  if (!categories || !Array.isArray(categories)) categories = [];
  
  if (categoryId !== undefined && categoryId !== null) {
    // Direct match on id (strict or loose) or sync_id
    let cat = categories.find(c => c.id == categoryId || c.sync_id == categoryId);
    if (cat) return cat;

    // Numerical index match (1..18)
    const numId = parseInt(categoryId, 10);
    if (!isNaN(numId) && numId >= 1 && numId <= DEFAULT_CATEGORIES.length) {
      const def = DEFAULT_CATEGORIES[numId - 1];
      const matchByName = categories.find(c => c.name.toLowerCase() === def.name.toLowerCase());
      if (matchByName) return matchByName;
      return def;
    }

    // Name match
    if (typeof categoryId === 'string') {
      const matchByName = categories.find(c => c.name.toLowerCase() === categoryId.toLowerCase());
      if (matchByName) return matchByName;
      const defByName = DEFAULT_CATEGORIES.find(c => c.name.toLowerCase() === categoryId.toLowerCase());
      if (defByName) return defByName;
    }
  }

  return { name: 'Other', icon: 'more_horiz', type: 'expense' };
}

export function isInvestmentCategory(categories, categoryId) {
  const cat = findCategory(categories, categoryId);
  if (!cat) return false;
  const name = (cat.name || '').toLowerCase();
  return name === 'investments' || name === 'investment' || cat.icon === 'show_chart' || cat.icon === 'trending_up';
}
