import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reservation.dart';
import '../services/reservation_service.dart';
import 'tenant_provider.dart';

final reservationServiceProvider = Provider<ReservationService?>((ref) {
  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) return null;
  return ReservationService(tenant);
});

final reservationsProvider = StreamProvider<List<Reservation>>((ref) {
  final service = ref.watch(reservationServiceProvider);
  if (service == null) return Stream.value([]);
  final today = DateTime.now();
  final startOfToday = DateTime(today.year, today.month, today.day);
  return service.watchReservations(fromDate: startOfToday);
});
