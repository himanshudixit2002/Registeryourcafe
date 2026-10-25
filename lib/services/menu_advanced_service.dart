import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/tenant_firestore.dart';
import '../models/menu_advanced.dart';

class MenuAdvancedService {
  final TenantRef _tenant;

  MenuAdvancedService(this._tenant);

  CollectionReference<Map<String, dynamic>> _recipes() =>
      _tenant.companyDoc().collection('recipes');

  CollectionReference<Map<String, dynamic>> _waste() =>
      _tenant.companyDoc().collection('foodWaste');

  CollectionReference<Map<String, dynamic>> _specials() =>
      _tenant.companyDoc().collection('dailySpecials');

  CollectionReference<Map<String, dynamic>> _priceHistory() =>
      _tenant.companyDoc().collection('priceHistory');

  Future<void> saveRecipe(Recipe recipe) async =>
      await _recipes().doc(recipe.itemId).set(recipe.toFirestore());

  Future<Recipe?> getRecipe(String itemId) async {
    final doc = await _recipes().doc(itemId).get();
    return doc.exists ? Recipe.fromFirestore(doc) : null;
  }

  Stream<List<Recipe>> watchRecipes() =>
      _recipes().snapshots().map(
        (s) => s.docs.map(Recipe.fromFirestore).toList(),
      );

  Future<void> updateAllergens(String itemId, List<String> allergens) async =>
      await _tenant.stockItems().doc(itemId).update({'allergens': allergens});

  Future<void> updateNutrition(String itemId, NutritionalInfo info) async =>
      await _tenant.stockItems().doc(itemId).update({'nutrition': info.toMap()});

  Future<void> toggleAvailability(String itemId, bool available) async =>
      await _tenant.stockItems().doc(itemId).update({'available': available});

  Future<void> addVariant(String itemId, MenuVariant variant) async =>
      await _tenant.stockItems().doc(itemId).update({
        'variants': FieldValue.arrayUnion([variant.toMap()]),
      });

  Future<void> logWaste(FoodWasteEntry entry) async =>
      await _waste().add(entry.toFirestore());

  Stream<List<FoodWasteEntry>> watchWaste({int limit = 50}) => _waste()
      .orderBy('date', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(FoodWasteEntry.fromFirestore).toList());

  Future<void> setDailySpecial(DailySpecial special) async =>
      await _specials().add(special.toFirestore());

  Stream<List<DailySpecial>> watchTodaySpecials() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    return _specials()
        .where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .snapshots()
        .map((s) => s.docs.map(DailySpecial.fromFirestore).toList());
  }

  Future<void> logPriceChange(
    String itemId,
    String itemName,
    double oldPrice,
    double newPrice,
  ) async {
    await _priceHistory().add({
      'itemId': itemId,
      'itemName': itemName,
      'oldPrice': oldPrice,
      'newPrice': newPrice,
      'changedAt': FieldValue.serverTimestamp(),
    });
  }
}
