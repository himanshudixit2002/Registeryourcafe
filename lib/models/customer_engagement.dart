import 'package:cloud_firestore/cloud_firestore.dart';

enum LoyaltyTier {
  bronze,
  silver,
  gold,
  platinum;

  String get label {
    switch (this) {
      case bronze:
        return 'Bronze';
      case silver:
        return 'Silver';
      case gold:
        return 'Gold';
      case platinum:
        return 'Platinum';
    }
  }

  static LoyaltyTier fromPoints(int points) {
    if (points >= 10000) return platinum;
    if (points >= 5000) return gold;
    if (points >= 1000) return silver;
    return bronze;
  }
}

class CustomerPreference {
  final String customerId;
  final List<String> favoriteItems;
  final String? preferredTable;
  final String? dietaryNotes;
  final DateTime? birthday;
  final DateTime? anniversary;

  const CustomerPreference({
    required this.customerId,
    this.favoriteItems = const [],
    this.preferredTable,
    this.dietaryNotes,
    this.birthday,
    this.anniversary,
  });

  factory CustomerPreference.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return CustomerPreference(
      customerId: doc.id,
      favoriteItems: (d['favoriteItems'] as List?)?.whereType<String>().toList() ?? [],
      preferredTable: d['preferredTable'] as String?,
      dietaryNotes: d['dietaryNotes'] as String?,
      birthday: (d['birthday'] as Timestamp?)?.toDate(),
      anniversary: (d['anniversary'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'favoriteItems': favoriteItems,
    if (preferredTable != null) 'preferredTable': preferredTable,
    if (dietaryNotes != null) 'dietaryNotes': dietaryNotes,
    if (birthday != null) 'birthday': Timestamp.fromDate(birthday!),
    if (anniversary != null) 'anniversary': Timestamp.fromDate(anniversary!),
  };
}

class ReferralRecord {
  final String id;
  final String referrerCustomerId;
  final String referredCustomerId;
  final String referralCode;
  final bool rewardClaimed;
  final DateTime createdAt;

  const ReferralRecord({
    required this.id,
    required this.referrerCustomerId,
    required this.referredCustomerId,
    required this.referralCode,
    this.rewardClaimed = false,
    required this.createdAt,
  });

  factory ReferralRecord.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ReferralRecord(
      id: doc.id,
      referrerCustomerId: d['referrerCustomerId'] as String? ?? '',
      referredCustomerId: d['referredCustomerId'] as String? ?? '',
      referralCode: d['referralCode'] as String? ?? '',
      rewardClaimed: d['rewardClaimed'] as bool? ?? false,
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'referrerCustomerId': referrerCustomerId,
    'referredCustomerId': referredCustomerId,
    'referralCode': referralCode,
    'rewardClaimed': rewardClaimed,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}

class WaitlistEntry {
  final String id;
  final String customerName;
  final String customerPhone;
  final int partySize;
  final int estimatedWaitMinutes;
  final String status;
  final DateTime createdAt;

  const WaitlistEntry({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.partySize,
    this.estimatedWaitMinutes = 15,
    this.status = 'waiting',
    required this.createdAt,
  });

  factory WaitlistEntry.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return WaitlistEntry(
      id: doc.id,
      customerName: d['customerName'] as String? ?? '',
      customerPhone: d['customerPhone'] as String? ?? '',
      partySize: (d['partySize'] as num?)?.toInt() ?? 1,
      estimatedWaitMinutes:
          (d['estimatedWaitMinutes'] as num?)?.toInt() ?? 15,
      status: d['status'] as String? ?? 'waiting',
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'customerName': customerName,
    'customerPhone': customerPhone,
    'partySize': partySize,
    'estimatedWaitMinutes': estimatedWaitMinutes,
    'status': status,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}

class CustomerBadge {
  final String id;
  final String name;
  final String description;
  final String icon;
  final int requiredPoints;

  const CustomerBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.requiredPoints,
  });
}

class BadgeDefinitions {
  static const List<CustomerBadge> all = [
    CustomerBadge(
      id: 'first_visit',
      name: 'First Timer',
      description: 'Completed first visit',
      icon: 'star',
      requiredPoints: 0,
    ),
    CustomerBadge(
      id: 'regular',
      name: 'Regular',
      description: '10+ visits',
      icon: 'repeat',
      requiredPoints: 100,
    ),
    CustomerBadge(
      id: 'vip',
      name: 'VIP',
      description: '50+ visits',
      icon: 'diamond',
      requiredPoints: 500,
    ),
    CustomerBadge(
      id: 'champion',
      name: 'Champion',
      description: '100+ visits',
      icon: 'trophy',
      requiredPoints: 1000,
    ),
    CustomerBadge(
      id: 'legend',
      name: 'Legend',
      description: '500+ visits',
      icon: 'crown',
      requiredPoints: 5000,
    ),
    CustomerBadge(
      id: 'big_spender',
      name: 'Big Spender',
      description: 'Spent 50k+',
      icon: 'money',
      requiredPoints: 0,
    ),
    CustomerBadge(
      id: 'referrer',
      name: 'Referrer',
      description: 'Referred 5+ people',
      icon: 'share',
      requiredPoints: 0,
    ),
    CustomerBadge(
      id: 'reviewer',
      name: 'Reviewer',
      description: 'Left 10+ reviews',
      icon: 'rate_review',
      requiredPoints: 0,
    ),
  ];
}
