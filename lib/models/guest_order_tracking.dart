import 'package:cloud_firestore/cloud_firestore.dart';

class GuestOrderTracking {
  final String id;
  final String companyId;
  final String venueName;
  final String guestUid;
  final String guestName;
  final List<Map<String, dynamic>> items;
  final double total;
  final String status;
  final String? promoCode;
  final double? discount;
  final double? tip;
  final String? scheduledFor;
  final DateTime createdAt;

  const GuestOrderTracking({
    required this.id,
    required this.companyId,
    required this.venueName,
    required this.guestUid,
    required this.guestName,
    required this.items,
    required this.total,
    this.status = 'pending',
    this.promoCode,
    this.discount,
    this.tip,
    this.scheduledFor,
    required this.createdAt,
  });

  factory GuestOrderTracking.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return GuestOrderTracking(
      id: doc.id,
      companyId: d['companyId'] as String? ?? '',
      venueName: d['venueName'] as String? ?? '',
      guestUid: d['guestUid'] as String? ?? '',
      guestName: d['guestName'] as String? ?? '',
      items: (d['items'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [],
      total: (d['total'] as num?)?.toDouble() ?? 0,
      status: d['status'] as String? ?? 'pending',
      promoCode: d['promoCode'] as String?,
      discount: (d['discount'] as num?)?.toDouble(),
      tip: (d['tip'] as num?)?.toDouble(),
      scheduledFor: d['scheduledFor'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
