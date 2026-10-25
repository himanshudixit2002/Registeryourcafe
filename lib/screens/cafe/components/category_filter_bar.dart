import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_card.dart';

class CategoryFilterBar extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  const CategoryFilterBar({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        physics: AppTheme.scrollPhysicsFor(context),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        separatorBuilder: (context, i) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = categories[i];
          final isSelected = selectedCategory == cat;
          return AppFilterChip(
            label: cat,
            isSelected: isSelected,
            onTap: () => onCategorySelected(cat),
          );
        },
      ),
    );
  }
}
