import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/customer_feedback.dart';
import '../services/feedback_service.dart';
import 'tenant_provider.dart';

final feedbackServiceProvider = Provider<FeedbackService?>((ref) {
  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) return null;
  return FeedbackService(tenant);
});

final feedbackListProvider = StreamProvider<List<CustomerFeedback>>((ref) {
  final service = ref.watch(feedbackServiceProvider);
  if (service == null) return Stream.value([]);
  return service.watchFeedback();
});
