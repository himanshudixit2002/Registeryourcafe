import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/payment_mode.dart';
import '../utils/firestore_utils.dart';
import 'membership_type_definition.dart';

export '../constants/payment_mode.dart'
    show PaymentMethod, PaymentMethodExtension;

class CreditTopUp {
  final DateTime date;
  final double amount;
  final PaymentMethod paymentMethod;

  CreditTopUp({
    required this.date,
    required this.amount,
    required this.paymentMethod,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'date': Timestamp.fromDate(date),
      'amount': amount,
      'method': paymentMethod.toString().split('.').last.toLowerCase(),
    };
  }

  factory CreditTopUp.fromFirestore(Map<String, dynamic> data) {
    return CreditTopUp(
      date: (data['date'] as Timestamp).toDate(),
      amount: parseFirestoreDouble(data['amount']),
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) =>
            e.toString().split('.').last.toLowerCase() ==
            data['method'].toString().toLowerCase(),
        orElse: () => PaymentMethod.cash, // Default if parse fails
      ),
    );
  }
}

class MembershipRecord {
  final String id;
  final String type; // lowercase, e.g., bronze1, silver
  final bool active;

  MembershipRecord({
    required this.id,
    required this.type,
    required this.active,
  });

  factory MembershipRecord.fromMap(Map<String, dynamic> data) {
    return MembershipRecord(
      id: data['id'] as String? ?? '',
      type: (data['type'] as String? ?? '').toLowerCase(),
      active: data['active'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {'id': id, 'type': type, 'active': active};
}

class Customer {
  final String id;
  final String name;
  final String? email;
  final String phoneNumber;
  final String? pincode;
  final String? membershipId;
  final double credits;

  /// [MembershipTypeDefinition.id] stored in Firestore as `membershipType`.
  final String membershipTypeId;
  final DateTime? membershipExpiry;
  final DateTime lastCreditTopUpDate;
  final double lastCreditTopUpAmount;
  final PaymentMethod lastCreditTopUpMethod;
  final List<PaymentMethod> preferredPaymentMethods;
  final bool hasLowCreditAlert;
  final bool hasMembershipExpiryAlert;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<MembershipRecord> membershipHistory;
  final String creditCode; // 6-digit code for credit payments

  Customer({
    required this.id,
    required this.name,
    this.email,
    required this.phoneNumber,
    this.pincode,
    this.membershipId,
    required this.credits,
    required this.membershipTypeId,
    this.membershipExpiry,
    required this.lastCreditTopUpDate,
    required this.lastCreditTopUpAmount,
    required this.lastCreditTopUpMethod,
    required this.preferredPaymentMethods,
    required this.hasLowCreditAlert,
    required this.hasMembershipExpiryAlert,
    required this.createdAt,
    required this.updatedAt,
    required this.membershipHistory,
    this.creditCode = '',
  });

  factory Customer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final lastCreditTopUpData =
        data['lastCreditTopUp'] as Map<String, dynamic>? ?? {};

    List<MembershipRecord> history = [];
    if (data['membershipIds'] is List) {
      history = (data['membershipIds'] as List)
          .map(
            (e) => MembershipRecord.fromMap(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } else if (data['membershipId'] != null) {
      // backfill to history with single active record
      history = [
        MembershipRecord(
          id: '${data['membershipId']}',
          type: normalizeMembershipTypeId(data['membershipType'] as String?),
          active: true,
        ),
      ];
    }

    return Customer(
      id: doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String?,
      phoneNumber: data['phoneNumber'] as String? ?? '',
      pincode: data['pincode'] as String?,
      membershipId: data['membershipId'] as String?,
      credits: parseFirestoreDouble(data['credits']),
      membershipTypeId: normalizeMembershipTypeId(
        data['membershipType'] as String?,
      ),
      membershipExpiry: (data['membershipExpiry'] as Timestamp?)?.toDate(),
      lastCreditTopUpDate:
          (lastCreditTopUpData['date'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lastCreditTopUpAmount: parseFirestoreDouble(
        lastCreditTopUpData['amount'],
      ),
      lastCreditTopUpMethod: PaymentMethod.values.firstWhere(
        (e) =>
            e.toString().split('.').last.toLowerCase() ==
            (lastCreditTopUpData['method'] as String?)?.toLowerCase(),
        orElse: () => PaymentMethod.cash,
      ),
      preferredPaymentMethods: (data['preferredPaymentMethods'] as List? ?? [])
          .map(
            (method) => PaymentMethod.values.firstWhere(
              (e) =>
                  e.toString().split('.').last.toLowerCase() ==
                  (method as String?)?.toLowerCase(),
              orElse: () => PaymentMethod.cash,
            ),
          )
          .toList(),
      hasLowCreditAlert: data['alerts']?['lowCredit'] as bool? ?? false,
      hasMembershipExpiryAlert:
          data['alerts']?['membershipExpiry'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      membershipHistory: history,
      creditCode: data['creditCode'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    final lastTopUp = CreditTopUp(
      date: lastCreditTopUpDate,
      amount: lastCreditTopUpAmount,
      paymentMethod: lastCreditTopUpMethod,
    );

    return {
      'name': name,
      // A lowercase copy of the name for case-insensitive prefix search. Keep
      // this in sync with the canonical `name` field on every write.
      'nameLower': name.toLowerCase(),
      'email': email,
      'phoneNumber': phoneNumber,
      'pincode': pincode,
      'membershipId': membershipId,
      'credits': credits,
      'membershipType': membershipTypeId,
      'membershipExpiry': membershipExpiry != null
          ? Timestamp.fromDate(membershipExpiry!)
          : null,
      'lastCreditTopUp': lastTopUp.toFirestore(),
      'preferredPaymentMethods': preferredPaymentMethods
          .map((method) => method.toString().split('.').last.toLowerCase())
          .toList(),
      'alerts': {
        'lowCredit': hasLowCreditAlert,
        'membershipExpiry': hasMembershipExpiryAlert,
      },
      'createdAt':
          createdAt.isAtSameMomentAs(DateTime.fromMillisecondsSinceEpoch(0))
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'membershipIds': membershipHistory.map((e) => e.toMap()).toList(),
      'creditCode': creditCode,
    };
  }

  Customer copyWith({
    String? id,
    String? name,
    String? email,
    bool clearEmail = false,
    String? phoneNumber,
    String? pincode,
    bool clearPincode = false,
    String? membershipId,
    bool clearMembershipId = false,
    double? credits,
    String? membershipTypeId,
    DateTime? membershipExpiry,
    bool clearMembershipExpiry = false,
    DateTime? lastCreditTopUpDate,
    double? lastCreditTopUpAmount,
    PaymentMethod? lastCreditTopUpMethod,
    List<PaymentMethod>? preferredPaymentMethods,
    bool? hasLowCreditAlert,
    bool? hasMembershipExpiryAlert,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<MembershipRecord>? membershipHistory,
    String? creditCode,
  }) {
    return Customer(
      id: this.id, // ID should not change with copyWith
      name: name ?? this.name,
      email: clearEmail ? null : (email ?? this.email),
      phoneNumber: phoneNumber ?? this.phoneNumber,
      pincode: clearPincode ? null : (pincode ?? this.pincode),
      membershipId: clearMembershipId
          ? null
          : (membershipId ?? this.membershipId),
      credits: credits ?? this.credits,
      membershipTypeId: membershipTypeId ?? this.membershipTypeId,
      membershipExpiry: clearMembershipExpiry
          ? null
          : (membershipExpiry ?? this.membershipExpiry),
      lastCreditTopUpDate: lastCreditTopUpDate ?? this.lastCreditTopUpDate,
      lastCreditTopUpAmount:
          lastCreditTopUpAmount ?? this.lastCreditTopUpAmount,
      lastCreditTopUpMethod:
          lastCreditTopUpMethod ?? this.lastCreditTopUpMethod,
      preferredPaymentMethods:
          preferredPaymentMethods ?? this.preferredPaymentMethods,
      hasLowCreditAlert: hasLowCreditAlert ?? this.hasLowCreditAlert,
      hasMembershipExpiryAlert:
          hasMembershipExpiryAlert ?? this.hasMembershipExpiryAlert,
      createdAt: this.createdAt, // createdAt should not change with copyWith
      updatedAt:
          updatedAt ??
          this.updatedAt, // usually handled by serverTimestamp on write
      membershipHistory: membershipHistory ?? this.membershipHistory,
      creditCode: creditCode ?? this.creditCode,
    );
  }
}
