import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/firestore_utils.dart';

class LoyaltyConversion {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final double pointsConverted;
  final double creditsAwarded;
  final double conversionRate;
  final DateTime convertedAt;
  final String? performedById;
  final String? performedByName;
  final String? performedByRole;

  LoyaltyConversion({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.pointsConverted,
    required this.creditsAwarded,
    required this.conversionRate,
    required this.convertedAt,
    this.performedById,
    this.performedByName,
    this.performedByRole,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'pointsConverted': pointsConverted,
      'creditsAwarded': creditsAwarded,
      'conversionRate': conversionRate,
      'convertedAt': Timestamp.fromDate(convertedAt),
      if (performedById != null) 'performedById': performedById,
      if (performedByName != null) 'performedByName': performedByName,
      if (performedByRole != null) 'performedByRole': performedByRole,
    };
  }

  factory LoyaltyConversion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LoyaltyConversion(
      id: doc.id,
      customerId: data['customerId'] as String? ?? '',
      customerName: data['customerName'] as String? ?? '',
      customerPhone: data['customerPhone'] as String? ?? '',
      pointsConverted: parseFirestoreDouble(data['pointsConverted']),
      creditsAwarded: parseFirestoreDouble(data['creditsAwarded']),
      conversionRate: parseFirestoreDouble(
        data['conversionRate'],
        fallback: 0.5,
      ),
      convertedAt:
          (data['convertedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      performedById: data['performedById'] as String?,
      performedByName: data['performedByName'] as String?,
      performedByRole: data['performedByRole'] as String?,
    );
  }
}
