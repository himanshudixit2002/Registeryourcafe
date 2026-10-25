import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider = Provider<Connectivity>((ref) => Connectivity());

/// True when there is no usable network path (offline / airplane mode).
final isOfflineProvider = StreamProvider<bool>((ref) async* {
  final c = ref.watch(connectivityProvider);
  bool offline(List<ConnectivityResult> r) =>
      r.isEmpty || r.every((x) => x == ConnectivityResult.none);

  yield offline(await c.checkConnectivity());
  yield* c.onConnectivityChanged.map(offline);
});
