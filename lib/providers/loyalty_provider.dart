import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/loyalty_conversion.dart';
import '../models/loyalty_settings.dart';
import '../services/loyalty_service.dart';
import '../utils/firestore_utils.dart';
import 'tenant_provider.dart';

final loyaltyServiceProvider = Provider<LoyaltyService?>((ref) {
  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) return null;
  return LoyaltyService(tenant);
});

final loyaltySettingsProvider = StreamProvider<LoyaltySettings>((ref) {
  final service = ref.watch(loyaltyServiceProvider);
  if (service == null) {
    return Stream.value(const LoyaltySettings());
  }
  return service.watchSettings();
});

final loyaltyConversionsProvider = StreamProvider<List<LoyaltyConversion>>((
  ref,
) {
  final service = ref.watch(loyaltyServiceProvider);
  if (service == null) {
    return Stream.value(<LoyaltyConversion>[]);
  }
  return service.watchConversions(limit: 100);
});

final customerLoyaltyPointsProvider = StreamProvider.family<double, String>((
  ref,
  customerId,
) {
  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) {
    return Stream.value(0.0);
  }
  return tenant.customers().doc(customerId).snapshots().map((doc) {
    if (!doc.exists) return 0.0;
    final gameStats = doc.data()?['gameStats'] as Map<String, dynamic>? ?? {};
    return parseFirestoreDouble(gameStats['currentLeaderboardPoints']);
  });
});

final customerConversionsProvider =
    StreamProvider.family<List<LoyaltyConversion>, String>((ref, customerId) {
      final service = ref.watch(loyaltyServiceProvider);
      if (service == null) {
        return Stream.value(<LoyaltyConversion>[]);
      }
      return service.watchCustomerConversions(customerId);
    });
