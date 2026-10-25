import 'package:cloud_firestore/cloud_firestore.dart';

class GiftCard {
  final String id;
  final String code;
  final double originalBalance;
  final double currentBalance;
  final String? purchaserName;
  final String? recipientName;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? expiresAt;

  const GiftCard({
    required this.id,
    required this.code,
    required this.originalBalance,
    required this.currentBalance,
    this.purchaserName,
    this.recipientName,
    this.isActive = true,
    required this.createdAt,
    this.expiresAt,
  });

  factory GiftCard.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return GiftCard(
      id: doc.id,
      code: d['code'] as String? ?? '',
      originalBalance: (d['originalBalance'] as num?)?.toDouble() ?? 0,
      currentBalance: (d['currentBalance'] as num?)?.toDouble() ?? 0,
      purchaserName: d['purchaserName'] as String?,
      recipientName: d['recipientName'] as String?,
      isActive: d['isActive'] as bool? ?? true,
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (d['expiresAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'code': code,
        'originalBalance': originalBalance,
        'currentBalance': currentBalance,
        if (purchaserName != null) 'purchaserName': purchaserName,
        if (recipientName != null) 'recipientName': recipientName,
        'isActive': isActive,
        'createdAt': Timestamp.fromDate(createdAt),
        if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
      };
}

class MarketingCampaign {
  final String id;
  final String name;
  final String channel;
  final String message;
  final String status;
  final int targetCount;
  final int sentCount;
  final DateTime scheduledAt;
  final DateTime createdAt;

  const MarketingCampaign({
    required this.id,
    required this.name,
    required this.channel,
    required this.message,
    this.status = 'draft',
    this.targetCount = 0,
    this.sentCount = 0,
    required this.scheduledAt,
    required this.createdAt,
  });

  factory MarketingCampaign.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return MarketingCampaign(
      id: doc.id,
      name: d['name'] as String? ?? '',
      channel: d['channel'] as String? ?? 'whatsapp',
      message: d['message'] as String? ?? '',
      status: d['status'] as String? ?? 'draft',
      targetCount: (d['targetCount'] as num?)?.toInt() ?? 0,
      sentCount: (d['sentCount'] as num?)?.toInt() ?? 0,
      scheduledAt:
          (d['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'channel': channel,
        'message': message,
        'status': status,
        'targetCount': targetCount,
        'sentCount': sentCount,
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

class MarketingBudget {
  final String id;
  final String channel;
  final double allocated;
  final double spent;
  final String period;

  const MarketingBudget({
    required this.id,
    required this.channel,
    required this.allocated,
    this.spent = 0,
    required this.period,
  });

  factory MarketingBudget.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return MarketingBudget(
      id: doc.id,
      channel: d['channel'] as String? ?? '',
      allocated: (d['allocated'] as num?)?.toDouble() ?? 0,
      spent: (d['spent'] as num?)?.toDouble() ?? 0,
      period: d['period'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'channel': channel,
        'allocated': allocated,
        'spent': spent,
        'period': period,
      };
}
