import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerFeedback {
  final String id;
  final String? customerId;
  final String customerName;
  final int rating;
  final String comment;
  final String? sessionId;
  final DateTime createdAt;
  final String? response;

  const CustomerFeedback({
    required this.id,
    this.customerId,
    required this.customerName,
    required this.rating,
    required this.comment,
    this.sessionId,
    required this.createdAt,
    this.response,
  });

  factory CustomerFeedback.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CustomerFeedback(
      id: doc.id,
      customerId: data['customerId'] as String?,
      customerName: data['customerName'] as String? ?? 'Anonymous',
      rating: (data['rating'] as num?)?.toInt() ?? 0,
      comment: data['comment'] as String? ?? '',
      sessionId: data['sessionId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      response: data['response'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (customerId != null) 'customerId': customerId,
      'customerName': customerName,
      'rating': rating,
      'comment': comment,
      if (sessionId != null) 'sessionId': sessionId,
      'createdAt': Timestamp.fromDate(createdAt),
      if (response != null) 'response': response,
    };
  }
}
