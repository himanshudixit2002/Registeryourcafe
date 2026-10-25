import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../firestore/tenant_firestore.dart';
import '../../../models/stock_item.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/info_placeholder.dart';
import '../../../widgets/loading_indicator.dart';
import 'sellable_stock_item_card.dart';

class ProductGrid extends StatelessWidget {
  final TenantRef tenant;
  final String selectedCategory;
  final String searchQuery;
  final void Function(StockItem) onAddToCart;
  final void Function(List<String>) onCategoriesFetched;

  const ProductGrid({
    super.key,
    required this.tenant,
    required this.selectedCategory,
    required this.searchQuery,
    required this.onAddToCart,
    required this.onCategoriesFetched,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: tenant
          .stockItems()
          .where('isSellable', isEqualTo: true)
          .where('isMerchandise', isEqualTo: false)
          .orderBy('category')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return InfoPlaceholder(
            iconData: Icons.error_outline_rounded,
            title: 'Error Loading Menu',
            message: snapshot.error.toString(),
            iconColor: Theme.of(context).colorScheme.error,
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: LoadingIndicator(message: 'Loading menu...'),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const InfoPlaceholder(
            iconData: Icons.no_food_outlined,
            title: 'No Items on Menu',
            message:
                'Items marked as "sellable" and not "merchandise" in Stock Management will appear here.',
          );
        }
        final sellableStockItems = snapshot.data!.docs
            .map((doc) => StockItem.fromFirestore(doc))
            .toList();

        final categories = <String>{};
        for (final item in sellableStockItems) {
          if (item.category != null && item.category!.trim().isNotEmpty) {
            categories.add(item.category!.trim());
          }
        }
        final newVisibleCategories = ['All', ...categories.toList()..sort()];

        WidgetsBinding.instance.addPostFrameCallback((_) {
          onCategoriesFetched(newVisibleCategories);
        });

        final List<StockItem> categoryFilteredItems = selectedCategory == 'All'
            ? sellableStockItems
            : sellableStockItems
                  .where((item) => item.category == selectedCategory)
                  .toList();

        List<StockItem> searchAndCategoryFilteredItems = categoryFilteredItems;
        if (searchQuery.isNotEmpty) {
          searchAndCategoryFilteredItems = categoryFilteredItems
              .where(
                (item) =>
                    item.name.toLowerCase().contains(
                      searchQuery.toLowerCase(),
                    ) ||
                    (item.description?.toLowerCase().contains(
                          searchQuery.toLowerCase(),
                        ) ??
                        false) ||
                    (item.category?.toLowerCase().contains(
                          searchQuery.toLowerCase(),
                        ) ??
                        false),
              )
              .toList();
        }

        if (searchAndCategoryFilteredItems.isEmpty) {
          String message = 'No items match your current filters.';
          if (searchQuery.isNotEmpty && categoryFilteredItems.isNotEmpty) {
            message = "No menu items match \"$searchQuery\" in this category.";
          } else if (searchQuery.isNotEmpty &&
              selectedCategory == 'All' &&
              sellableStockItems.isNotEmpty) {
            message =
                "No menu items match your search for \"$searchQuery\" across all categories.";
          } else if (searchQuery.isNotEmpty) {
            message = "No menu items found for \"$searchQuery\" ";
          } else if (selectedCategory != 'All') {
            message = "No items in the '$selectedCategory' category.";
          }
          return InfoPlaceholder(
            iconData: Icons.search_off_rounded,
            title: 'No Results',
            message: message,
          );
        }

        final bool isMobile = AppTheme.isMobile(context);
        final hPad = isMobile
            ? AppTheme.kSpacingSmall
            : AppTheme.kSpacingMedium;

        return ListView.separated(
          physics: AppTheme.scrollPhysicsFor(context),
          padding: EdgeInsets.fromLTRB(
            hPad,
            0,
            hPad,
            isMobile ? AppTheme.kSpacingMedium : AppTheme.kSpacingLarge,
          ),
          itemCount: searchAndCategoryFilteredItems.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final item = searchAndCategoryFilteredItems[index];
            return RepaintBoundary(
              key: ValueKey(item.id),
              child: SellableMenuListTile(
                stockItem: item,
                onAddToCart: onAddToCart,
              ),
            );
          },
        );
      },
    );
  }
}
