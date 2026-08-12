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
