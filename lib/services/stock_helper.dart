import 'package:flutter/material.dart';

import '../firestore/tenant_firestore.dart';
import '../theme/app_theme.dart';
import '../utils/firestore_utils.dart';

class StockHelper {
  static final Map<String, _CachedStockData> _stockCache = {};
  static const Duration _cacheExpiry = Duration(seconds: 5);

  /// Gets the current stock quantity for an item.
  /// Uses caching to reduce Firestore reads for rapid operations.
  static Future<int?> getStockQuantity(TenantRef tenant, String itemId) async {
    // Check cache first
    final cached = _stockCache[itemId];
    if (cached != null && !cached.isExpired) {
      return cached.quantity;
    }

    try {
      final doc = await tenant.stockItems().doc(itemId).get();

      if (!doc.exists) return null;

      final quantity = parseFirestoreInt(doc.data()?['quantity']);

      // Cache the result
      _stockCache[itemId] = _CachedStockData(
        quantity: quantity,
        fetchedAt: DateTime.now(),
      );

      return quantity;
    } catch (e) {
      return null;
    }
  }

  /// Validates if adding one more item to cart is allowed.
  /// Returns an error message if not allowed, null if OK.
  static Future<String?> validateAddToCart({
    required TenantRef tenant,
    required String itemId,
    required int currentCartQuantity,
  }) async {
    final stockQty = await getStockQuantity(tenant, itemId);

    if (stockQty == null) {
      return 'Unable to verify stock availability.';
    }

    if (stockQty <= 0) {
      return 'This item is out of stock.';
    }

    if (currentCartQuantity >= stockQty) {
      return 'Only $stockQty available in stock.';
    }

    return null; // OK to add
  }

  /// Shows a snackbar with the given message.
  static void showStockError(BuildContext context, String message) {
    if (!context.mounted) return;

    final sem = AppSemanticColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: sem.onWarningContainer,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: sem.onWarningContainer),
              ),
            ),
          ],
        ),
        backgroundColor: sem.warningContainer,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Shows a success message when item is added.
  static void showAddedToCart(BuildContext context, String itemName) {
    if (!context.mounted) return;

    final sem = AppSemanticColors.of(context);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: sem.onSuccessContainer,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$itemName added to cart',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: sem.onSuccessContainer),
              ),
            ),
          ],
        ),
        backgroundColor: sem.successContainer,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  /// Clears the stock cache for a specific item.
  static void invalidateCache(String itemId) {
    _stockCache.remove(itemId);
  }

  /// Clears the entire stock cache.
  static void clearCache() {
    _stockCache.clear();
  }
}

class _CachedStockData {
  final int quantity;
  final DateTime fetchedAt;

  _CachedStockData({required this.quantity, required this.fetchedAt});

  bool get isExpired =>
      DateTime.now().difference(fetchedAt) > StockHelper._cacheExpiry;
}
