import 'package:cloud_firestore/cloud_firestore.dart';

enum PromotionType {
  percentageDiscount,
  flatDiscount,
  happyHour,
  buyXGetY,
  couponCode;

  static PromotionType parse(String? value) {
    if (value == null) return PromotionType.percentageDiscount;
    for (final t in PromotionType.values) {
      if (t.name == value) return t;
    }
    return PromotionType.percentageDiscount;
  }

  String get label {
    switch (this) {
      case PromotionType.percentageDiscount:
        return 'Percentage discount';
      case PromotionType.flatDiscount:
        return 'Flat discount';
      case PromotionType.happyHour:
        return 'Happy hour';
      case PromotionType.buyXGetY:
        return 'Buy X Get Y';
      case PromotionType.couponCode:
        return 'Coupon code';
    }
  }
}

class Promotion {
  final String id;
  final String name;
  final String? description;
  final PromotionType type;
  final double value;
  final String? couponCode;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final String? startHour;
  final String? endHour;
  final DateTime createdAt;

  const Promotion({
    required this.id,
    required this.name,
    this.description,
    required this.type,
    required this.value,
    this.couponCode,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    this.startHour,
    this.endHour,
    required this.createdAt,
  });

  bool get isCurrentlyActive {
    if (!isActive) return false;
    final now = DateTime.now();
    if (now.isBefore(startDate) || now.isAfter(endDate)) return false;
    if (type == PromotionType.happyHour &&
        startHour != null &&
        endHour != null) {
      final currentHour = now.hour;
      final start = int.tryParse(startHour!.split(':').first) ?? 0;
      final end = int.tryParse(endHour!.split(':').first) ?? 24;
      return currentHour >= start && currentHour < end;
    }
    return true;
  }

  factory Promotion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Promotion(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String?,
      type: PromotionType.parse(data['type'] as String?),
      value: (data['value'] as num?)?.toDouble() ?? 0,
      couponCode: data['couponCode'] as String?,
      startDate:
          (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] as bool? ?? true,
      startHour: data['startHour'] as String?,
      endHour: data['endHour'] as String?,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      if (description != null) 'description': description,
      'type': type.name,
      'value': value,
      if (couponCode != null) 'couponCode': couponCode,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isActive': isActive,
      if (startHour != null) 'startHour': startHour,
      if (endHour != null) 'endHour': endHour,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
