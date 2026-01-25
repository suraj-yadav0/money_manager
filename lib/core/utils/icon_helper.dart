import 'package:flutter/material.dart';

class IconHelper {
  static IconData getIcon(String? iconName) {
    final iconMap = {
      'restaurant': Icons.restaurant,
      'directions_car': Icons.directions_car,
      'shopping_bag': Icons.shopping_bag,
      'movie': Icons.movie,
      'receipt_long': Icons.receipt_long,
      'local_hospital': Icons.local_hospital,
      'school': Icons.school,
      'spa': Icons.spa,
      'local_grocery_store': Icons.local_grocery_store,
      'more_horiz': Icons.more_horiz,
      'work': Icons.work,
      'laptop': Icons.laptop,
      'trending_up': Icons.trending_up,
      'attach_money': Icons.attach_money,
      'card_giftcard': Icons.card_giftcard,
      'savings': Icons.savings,
      'show_chart': Icons.show_chart, // Investments
      'family_restroom': Icons.family_restroom,
    };
    return iconMap[iconName] ?? Icons.category;
  }
}
