import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/tournament_service.dart';
import 'tenant_provider.dart';

final tournamentServiceProvider = Provider<TournamentService>((ref) {
  return TournamentService(ref.watch(tenantRefProvider)!);
});
