import 'package:cloud_firestore/cloud_firestore.dart';

class Recipe {
  final String id;
  final String itemId;
  final String itemName;
  final List<RecipeIngredient> ingredients;
  final String instructions;
  final int prepTimeMinutes;
  final DateTime updatedAt;

  const Recipe({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.ingredients,
    required this.instructions,
    this.prepTimeMinutes = 0,
    required this.updatedAt,
  });

  factory Recipe.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return Recipe(
      id: doc.id,
      itemId: d['itemId'] as String? ?? '',
      itemName: d['itemName'] as String? ?? '',
      ingredients: (d['ingredients'] as List?)
              ?.map((e) => RecipeIngredient.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      instructions: d['instructions'] as String? ?? '',
      prepTimeMinutes: (d['prepTimeMinutes'] as num?)?.toInt() ?? 0,
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'itemId': itemId,
    'itemName': itemName,
    'ingredients': ingredients.map((e) => e.toMap()).toList(),
    'instructions': instructions,
    'prepTimeMinutes': prepTimeMinutes,
    'updatedAt': Timestamp.fromDate(updatedAt),
  };
}

class RecipeIngredient {
  final String name;
  final double quantity;
  final String unit;

  const RecipeIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'quantity': quantity,
    'unit': unit,
  };

  factory RecipeIngredient.fromMap(Map<String, dynamic> m) => RecipeIngredient(
    name: m['name'] as String? ?? '',
    quantity: (m['quantity'] as num?)?.toDouble() ?? 0,
    unit: m['unit'] as String? ?? '',
  );
}

class AllergenInfo {
  final String itemId;
  final List<String> allergens;
  final String? dietaryNotes;

  const AllergenInfo({
    required this.itemId,
    required this.allergens,
    this.dietaryNotes,
  });

  Map<String, dynamic> toMap() => {
    'allergens': allergens,
    if (dietaryNotes != null) 'dietaryNotes': dietaryNotes,
  };
}

class NutritionalInfo {
  final String itemId;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const NutritionalInfo({
    required this.itemId,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  Map<String, dynamic> toMap() => {
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
  };
}

class MenuVariant {
  final String name;
  final double priceModifier;

  const MenuVariant({required this.name, required this.priceModifier});

  Map<String, dynamic> toMap() => {
    'name': name,
    'priceModifier': priceModifier,
  };

  factory MenuVariant.fromMap(Map<String, dynamic> m) => MenuVariant(
    name: m['name'] as String? ?? '',
    priceModifier: (m['priceModifier'] as num?)?.toDouble() ?? 0,
  );
}

class FoodWasteEntry {
  final String id;
  final String itemName;
  final double quantity;
  final String reason;
  final DateTime date;
  final String recordedBy;

  const FoodWasteEntry({
    required this.id,
    required this.itemName,
    required this.quantity,
    required this.reason,
    required this.date,
    required this.recordedBy,
  });

  factory FoodWasteEntry.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return FoodWasteEntry(
      id: doc.id,
      itemName: d['itemName'] as String? ?? '',
      quantity: (d['quantity'] as num?)?.toDouble() ?? 0,
      reason: d['reason'] as String? ?? '',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      recordedBy: d['recordedBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'itemName': itemName,
    'quantity': quantity,
    'reason': reason,
    'date': Timestamp.fromDate(date),
    'recordedBy': recordedBy,
  };
}

class DailySpecial {
  final String id;
  final String itemId;
  final String itemName;
  final double? specialPrice;
  final String? description;
  final DateTime date;

  const DailySpecial({
    required this.id,
    required this.itemId,
    required this.itemName,
    this.specialPrice,
    this.description,
    required this.date,
  });

  factory DailySpecial.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return DailySpecial(
      id: doc.id,
      itemId: d['itemId'] as String? ?? '',
      itemName: d['itemName'] as String? ?? '',
      specialPrice: (d['specialPrice'] as num?)?.toDouble(),
      description: d['description'] as String?,
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'itemId': itemId,
    'itemName': itemName,
    if (specialPrice != null) 'specialPrice': specialPrice,
    if (description != null) 'description': description,
    'date': Timestamp.fromDate(date),
  };
}
