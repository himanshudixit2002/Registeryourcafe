import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'venue_kind.dart';
import '../utils/firestore_utils.dart';

/// Firestore stores this on customers as field `membershipType` (id string).
const String kRegularMembershipTypeId = 'regular';

String normalizeMembershipTypeId(String? raw) {
  if (raw == null || raw.isEmpty) return kRegularMembershipTypeId;
  var s = raw.toString().trim().toLowerCase();
  if (s.contains('.')) s = s.split('.').last;
  if (s == 'none') return kRegularMembershipTypeId;
  return s;
}

/// Tenant-configurable membership plan (`companies/{cid}/membership_type_definitions/{id}`).
class MembershipTypeDefinition {
  final String id;
  final String name;
  final int fee;
  final int creditsToAdd;
  final int? durationInDays;
  final double discountPercentage;
  final int tierLevel;

  /// Counter doc id under [membership_counters] (e.g. BRONZE1). Empty for [isRegular].
  final String idPrefix;
  final int colorArgb;
  final int sortOrder;
  final bool isArchived;

  /// Non-paying tier (e.g. walk-in). Only one seeded; receives no card ID.
  final bool isRegular;

  const MembershipTypeDefinition({
    required this.id,
    required this.name,
    required this.fee,
    required this.creditsToAdd,
    this.durationInDays,
    this.discountPercentage = 0,
    this.tierLevel = 0,
    this.idPrefix = '',
    required this.colorArgb,
    required this.sortOrder,
    this.isArchived = false,
    this.isRegular = false,
  });

  Color get color => Color(colorArgb);

  double get bonusPercentage {
    if (fee <= 0) return 0;
    return ((creditsToAdd / fee) - 1) * 100;
  }

  String get effectiveIdPrefix {
    if (idPrefix.trim().isNotEmpty) {
      return idPrefix.trim().toUpperCase();
    }
    return id.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  static List<MembershipTypeDefinition> defaultSeed() => [
    const MembershipTypeDefinition(
      id: kRegularMembershipTypeId,
      name: 'Regular',
      fee: 0,
      creditsToAdd: 0,
      durationInDays: null,
      discountPercentage: 0,
      tierLevel: 0,
      idPrefix: '',
      colorArgb: 0xFF9E9E9E,
      sortOrder: 0,
      isRegular: true,
    ),
    const MembershipTypeDefinition(
      id: 'bronze1',
      name: 'Bronze 1',
      fee: 500,
      creditsToAdd: 525,
      durationInDays: 365,
      discountPercentage: 5,
      tierLevel: 1,
      idPrefix: 'BRONZE1',
      colorArgb: 0xFF8D6E63,
      sortOrder: 1,
    ),
    const MembershipTypeDefinition(
      id: 'bronze2',
      name: 'Bronze 2',
      fee: 1000,
      creditsToAdd: 1100,
      durationInDays: 365,
      discountPercentage: 5,
      tierLevel: 2,
      idPrefix: 'BRONZE2',
      colorArgb: 0xFF795548,
      sortOrder: 2,
    ),
    const MembershipTypeDefinition(
      id: 'bronze3',
      name: 'Bronze 3',
      fee: 2000,
      creditsToAdd: 2300,
      durationInDays: 365,
      discountPercentage: 5,
      tierLevel: 3,
      idPrefix: 'BRONZE3',
      colorArgb: 0xFF6D4C41,
      sortOrder: 3,
    ),
    const MembershipTypeDefinition(
      id: 'silver',
      name: 'Silver',
      fee: 8000,
      creditsToAdd: 10000,
      durationInDays: 365,
      discountPercentage: 10,
      tierLevel: 4,
      idPrefix: 'SILVER',
      colorArgb: 0xFFB0BEC5,
      sortOrder: 4,
    ),
    const MembershipTypeDefinition(
      id: 'gold',
      name: 'Gold',
      fee: 16000,
      creditsToAdd: 20000,
      durationInDays: 365,
      discountPercentage: 15,
      tierLevel: 5,
      idPrefix: 'GOLD',
      colorArgb: 0xFFFFD700,
      sortOrder: 5,
    ),
  ];

  /// Dining / full-service: walk-in plus one simple prepaid tier (expand in Settings).
  static List<MembershipTypeDefinition> diningRestaurantDefaultSeed() => [
    const MembershipTypeDefinition(
      id: kRegularMembershipTypeId,
      name: 'Regular',
      fee: 0,
      creditsToAdd: 0,
      durationInDays: null,
      discountPercentage: 0,
      tierLevel: 0,
      idPrefix: '',
      colorArgb: 0xFF9E9E9E,
      sortOrder: 0,
      isRegular: true,
    ),
    const MembershipTypeDefinition(
      id: 'house_member',
      name: 'House member',
      fee: 1000,
      creditsToAdd: 1100,
      durationInDays: 365,
      discountPercentage: 5,
      tierLevel: 1,
      idPrefix: 'HOUSE',
      colorArgb: 0xFF8D6E63,
      sortOrder: 1,
    ),
  ];

  static List<MembershipTypeDefinition> defaultSeedForVenueKind(VenueKind kind) {
    switch (kind) {
      case VenueKind.gamingCafe:
        return defaultSeed();
      case VenueKind.diningCafe:
      case VenueKind.restaurantCafe:
        return diningRestaurantDefaultSeed();
    }
  }

  factory MembershipTypeDefinition.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return MembershipTypeDefinition(
        id: doc.id,
        name: doc.id,
        fee: 0,
        creditsToAdd: 0,
        colorArgb: 0xFF9E9E9E,
        sortOrder: 99,
        isRegular: doc.id == kRegularMembershipTypeId,
      );
    }
    return MembershipTypeDefinition(
      id: doc.id,
      name: data['name'] as String? ?? doc.id,
      fee: parseFirestoreInt(data['fee'], fallback: 0),
      creditsToAdd: parseFirestoreInt(data['creditsToAdd'], fallback: 0),
      durationInDays: parseFirestoreIntOrNull(data['durationInDays']),
      discountPercentage: parseFirestoreDouble(
        data['discountPercentage'],
        fallback: 0,
      ),
      tierLevel: parseFirestoreInt(data['tierLevel'], fallback: 0),
      idPrefix: data['idPrefix'] as String? ?? '',
      colorArgb: parseFirestoreInt(data['colorArgb'], fallback: 0xFF9E9E9E),
      sortOrder: parseFirestoreInt(data['sortOrder'], fallback: 99),
      isArchived: data['isArchived'] as bool? ?? false,
      isRegular: data['isRegular'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'fee': fee,
      'creditsToAdd': creditsToAdd,
      if (durationInDays != null) 'durationInDays': durationInDays,
      'discountPercentage': discountPercentage,
      'tierLevel': tierLevel,
      'idPrefix': idPrefix,
      'colorArgb': colorArgb,
      'sortOrder': sortOrder,
      'isArchived': isArchived,
      'isRegular': isRegular,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toFirestoreForCreate() {
    return {...toFirestore(), 'createdAt': FieldValue.serverTimestamp()};
  }

  MembershipTypeDefinition copyWith({
    String? id,
    String? name,
    int? fee,
    int? creditsToAdd,
    int? durationInDays,
    double? discountPercentage,
    int? tierLevel,
    String? idPrefix,
    int? colorArgb,
    int? sortOrder,
    bool? isArchived,
    bool? isRegular,
    bool clearDurationInDays = false,
  }) {
    return MembershipTypeDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      fee: fee ?? this.fee,
      creditsToAdd: creditsToAdd ?? this.creditsToAdd,
      durationInDays: clearDurationInDays
          ? null
          : (durationInDays ?? this.durationInDays),
      discountPercentage: discountPercentage ?? this.discountPercentage,
      tierLevel: tierLevel ?? this.tierLevel,
      idPrefix: idPrefix ?? this.idPrefix,
      colorArgb: colorArgb ?? this.colorArgb,
      sortOrder: sortOrder ?? this.sortOrder,
      isArchived: isArchived ?? this.isArchived,
      isRegular: isRegular ?? this.isRegular,
    );
  }
}

MembershipTypeDefinition? lookupMembershipType(
  List<MembershipTypeDefinition> definitions,
  String typeId,
) {
  final id = normalizeMembershipTypeId(typeId);
  for (final d in definitions) {
    if (d.id == id) return d;
  }
  return null;
}

String membershipDisplayName(
  String typeId,
  List<MembershipTypeDefinition> definitions,
) {
  return lookupMembershipType(definitions, typeId)?.name ??
      typeId.toUpperCase();
}

double membershipDiscountPercent(
  String typeId,
  List<MembershipTypeDefinition> definitions,
) {
  return lookupMembershipType(definitions, typeId)?.discountPercentage ?? 0;
}

bool membershipIsRegular(
  String typeId,
  List<MembershipTypeDefinition> definitions,
) {
  final d = lookupMembershipType(definitions, typeId);
  if (d != null) return d.isRegular;
  return normalizeMembershipTypeId(typeId) == kRegularMembershipTypeId;
}

bool membershipOutranks(
  String a,
  String b,
  List<MembershipTypeDefinition> definitions,
) {
  final da = lookupMembershipType(definitions, a);
  final db = lookupMembershipType(definitions, b);
  return (da?.tierLevel ?? 0) > (db?.tierLevel ?? 0);
}
