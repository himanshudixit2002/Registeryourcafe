import 'package:registeryourcafe/models/venue_kind.dart';

import 'shell_route_titles.dart';

/// Reorders visible nav titles for dining-first vs kitchen-first workspaces.
void orderVisibleShellRoutesForVenue(List<String> items, VenueKind kind) {
  if (kind == VenueKind.gamingCafe || items.length < 2) return;

  final first = kind == VenueKind.restaurantCafe
      ? ShellRouteTitles.cafe
      : ShellRouteTitles.tables;
  final second = kind == VenueKind.restaurantCafe
      ? ShellRouteTitles.tables
      : ShellRouteTitles.cafe;

  final head = <String>[];
  if (items.contains(first)) head.add(first);
  if (items.contains(second)) head.add(second);
  final tail = items.where((t) => !head.contains(t)).toList();

  items
    ..clear()
    ..addAll(head)
    ..addAll(tail);
}
