import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/payment_mode.dart';
import '../utils/firestore_utils.dart';

enum RegistrationStatus { pending, approved, rejected, cancelled }

extension RegistrationStatusExtension on RegistrationStatus {
  String get displayName {
    switch (this) {
      case RegistrationStatus.pending:
        return 'Pending';
      case RegistrationStatus.approved:
        return 'Approved';
      case RegistrationStatus.rejected:
        return 'Rejected';
      case RegistrationStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get firestoreValue => name;

  static RegistrationStatus fromString(String value) {
    return RegistrationStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => RegistrationStatus.pending,
    );
  }
}

class TournamentRegistration {
  final String id;
  final String tournamentId;
  final String tournamentName;

  // Registrant info
  final String customerId;
  final String customerName;
  final String? customerPhone;

  // Financials
  final double entryFee;

  // Request details
  final RegistrationStatus status;
  final DateTime requestedAt;
  final String? requestNote;

  // Approval details (filled when approved)
  final DateTime? approvedAt;
  final String? approvedById;
  final String? approvedByName;
  final PaymentMethod? paymentMethod;
  final double? amountPaid;
  final String? transactionId; // Reference to sales transaction
  final String? paymentNote;

  // Rejection details (filled when rejected)
  final DateTime? rejectedAt;
  final String? rejectedById;
  final String? rejectedByName;
  final String? rejectionReason;

  // Refund details
  final bool isRefunded;
  final double? refundAmount;
  final double? creditsRefunded;
  final DateTime? refundedAt;
  final String? refundedById;
  final String? refundedByName;
  final String? refundNote;
  final String? refundPaymentMethod;

  // Flag to indicate if this is a public registration (from landing page)
  // Public registrations don't have a customerId initially
  final bool isPublicRegistration;

  TournamentRegistration({
    required this.id,
    required this.tournamentId,
    required this.tournamentName,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    this.entryFee = 0.0,
    this.status = RegistrationStatus.pending,
    required this.requestedAt,
    this.requestNote,
    this.approvedAt,
    this.approvedById,
    this.approvedByName,
    this.paymentMethod,
    this.amountPaid,
    this.transactionId,
    this.paymentNote,
    this.rejectedAt,
    this.rejectedById,
    this.rejectedByName,
    this.rejectionReason,
    this.isRefunded = false,
    this.refundAmount,
    this.creditsRefunded,
    this.refundedAt,
    this.refundedById,
    this.refundedByName,
    this.refundNote,
    this.refundPaymentMethod,
    this.isPublicRegistration = false,
  });

  factory TournamentRegistration.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TournamentRegistration(
      id: doc.id,
      tournamentId: data['tournamentId'] as String? ?? '',
      tournamentName: data['tournamentName'] as String? ?? '',
      customerId: data['customerId'] as String? ?? '',
      customerName: data['customerName'] as String? ?? '',
      customerPhone: data['customerPhone'] as String?,
      entryFee: parseFirestoreDouble(data['entryFee']),
      status: RegistrationStatusExtension.fromString(
        data['status'] as String? ?? 'pending',
      ),
      requestedAt:
          (data['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      requestNote: data['requestNote'] as String?,
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      approvedById: data['approvedById'] as String?,
      approvedByName: data['approvedByName'] as String?,
      paymentMethod: data['paymentMethod'] != null
          ? PaymentMethodExtension.fromStorageValue(
              data['paymentMethod'] as String?,
            )
          : null,
      amountPaid: parseFirestoreDoubleOrNull(data['amountPaid']),
      transactionId: data['transactionId'] as String?,
      paymentNote: data['paymentNote'] as String?,
      rejectedAt: (data['rejectedAt'] as Timestamp?)?.toDate(),
      rejectedById: data['rejectedById'] as String?,
      rejectedByName: data['rejectedByName'] as String?,
      rejectionReason: data['rejectionReason'] as String?,
      isRefunded: data['isRefunded'] as bool? ?? false,
      refundAmount: parseFirestoreDoubleOrNull(data['refundAmount']),
      creditsRefunded: parseFirestoreDoubleOrNull(data['creditsRefunded']),
      refundedAt: (data['refundedAt'] as Timestamp?)?.toDate(),
      refundedById: data['refundedById'] as String?,
      refundedByName: data['refundedByName'] as String?,
      refundNote: data['refundNote'] as String?,
      refundPaymentMethod: data['refundPaymentMethod'] as String?,
      isPublicRegistration: data['isPublicRegistration'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tournamentId': tournamentId,
      'tournamentName': tournamentName,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'entryFee': entryFee,
      'status': status.firestoreValue,
      'requestedAt': Timestamp.fromDate(requestedAt),
      'requestNote': requestNote,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'approvedById': approvedById,
      'approvedByName': approvedByName,
      'paymentMethod': paymentMethod?.storageValue,
      'amountPaid': amountPaid,
      'transactionId': transactionId,
      'paymentNote': paymentNote,
      'rejectedAt': rejectedAt != null ? Timestamp.fromDate(rejectedAt!) : null,
      'rejectedById': rejectedById,
      'rejectedByName': rejectedByName,
      'rejectionReason': rejectionReason,
      'isRefunded': isRefunded,
      'refundAmount': refundAmount,
      'creditsRefunded': creditsRefunded,
      'refundedAt': refundedAt != null ? Timestamp.fromDate(refundedAt!) : null,
      'refundedById': refundedById,
      'refundedByName': refundedByName,
      'refundNote': refundNote,
      'refundPaymentMethod': refundPaymentMethod,
      'isPublicRegistration': isPublicRegistration,
    };
  }

  TournamentRegistration copyWith({
    String? id,
    String? tournamentId,
    String? tournamentName,
    String? customerId,
    String? customerName,
    String? customerPhone,
    double? entryFee,
    RegistrationStatus? status,
    DateTime? requestedAt,
    String? requestNote,
    DateTime? approvedAt,
    bool clearApprovedAt = false,
    String? approvedById,
    String? approvedByName,
    PaymentMethod? paymentMethod,
    double? amountPaid,
    String? transactionId,
    String? paymentNote,
    DateTime? rejectedAt,
    bool clearRejectedAt = false,
    String? rejectedById,
    String? rejectedByName,
    String? rejectionReason,
    bool? isRefunded,
    double? refundAmount,
    double? creditsRefunded,
    DateTime? refundedAt,
    bool clearRefundedAt = false,
    String? refundedById,
    String? refundedByName,
    String? refundNote,
    String? refundPaymentMethod,
    bool? isPublicRegistration,
  }) {
    return TournamentRegistration(
      id: id ?? this.id,
      tournamentId: tournamentId ?? this.tournamentId,
      tournamentName: tournamentName ?? this.tournamentName,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      entryFee: entryFee ?? this.entryFee,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      requestNote: requestNote ?? this.requestNote,
      approvedAt: clearApprovedAt ? null : (approvedAt ?? this.approvedAt),
      approvedById: approvedById ?? this.approvedById,
      approvedByName: approvedByName ?? this.approvedByName,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      amountPaid: amountPaid ?? this.amountPaid,
      transactionId: transactionId ?? this.transactionId,
      paymentNote: paymentNote ?? this.paymentNote,
      rejectedAt: clearRejectedAt ? null : (rejectedAt ?? this.rejectedAt),
      rejectedById: rejectedById ?? this.rejectedById,
      rejectedByName: rejectedByName ?? this.rejectedByName,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      isRefunded: isRefunded ?? this.isRefunded,
      refundAmount: refundAmount ?? this.refundAmount,
      creditsRefunded: creditsRefunded ?? this.creditsRefunded,
      refundedAt: clearRefundedAt ? null : (refundedAt ?? this.refundedAt),
      refundedById: refundedById ?? this.refundedById,
      refundedByName: refundedByName ?? this.refundedByName,
      refundNote: refundNote ?? this.refundNote,
      refundPaymentMethod: refundPaymentMethod ?? this.refundPaymentMethod,
      isPublicRegistration: isPublicRegistration ?? this.isPublicRegistration,
    );
  }

  /// Check if registration is still editable
  bool get isEditable => status == RegistrationStatus.pending;

  /// Check if registration can be approved
  bool get canApprove => status == RegistrationStatus.pending;

  /// Check if registration can be rejected
  bool get canReject => status == RegistrationStatus.pending;
}
