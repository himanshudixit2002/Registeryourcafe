import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/shift.dart';
import '../services/shift_service.dart';
import 'tenant_provider.dart';

final shiftServiceProvider = Provider<ShiftService?>((ref) {
  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) return null;
  return ShiftService(tenant);
});

final shiftsProvider = StreamProvider<List<Shift>>((ref) {
  final service = ref.watch(shiftServiceProvider);
  if (service == null) return Stream.value([]);
  final today = DateTime.now();
  final start = DateTime(today.year, today.month, today.day);
  return service.watchShifts(fromDate: start);
});
