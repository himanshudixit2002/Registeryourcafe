import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/shell_route_index.dart';
import 'auth_provider.dart';
import 'company_module_provider.dart';
import 'permissions_provider.dart';

/// User-selected workspace tab (`null` = show first visible tab).
final shellRouteTitleProvider = StateProvider<String?>((ref) => null);

/// Visible tab titles (filtered + ordered like the main shell). For listeners.
final visibleShellTitlesProvider = Provider<List<String>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  final role = user?.role;
  final modules = ref.watch(workspaceModuleVisibilityProvider);
  final venueKind = ref.watch(venueKindProvider);
  final permissions = resolvedEffectivePermissions(
    ref.watch(effectivePermissionsProvider),
    user,
  );
  return visibleShellRouteTitles(
    role: role,
    modules: modules,
    permissions: permissions,
    venueKind: venueKind,
  );
});

/// Switch shell to [title] only if that tab is visible for the current user.
void navigateToShellTitleIfVisible(WidgetRef ref, String title) {
  final user = ref.read(appUserProvider).valueOrNull;
  final idx = shellRouteIndexForTitle(
    role: user?.role,
    modules: ref.read(workspaceModuleVisibilityProvider),
    permissions: resolvedEffectivePermissions(
      ref.read(effectivePermissionsProvider),
      user,
    ),
    venueKind: ref.read(venueKindProvider),
    title: title,
  );
  if (idx != null) {
    ref.read(shellRouteTitleProvider.notifier).state = title;
  }
}
