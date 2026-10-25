import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/firestore_collections.dart';
import '../../models/guest_profile.dart';
import '../../models/public_booking_slot.dart';
import '../../models/public_floor_table.dart';
import '../../models/public_menu_item.dart';
import '../../models/public_venue_listing.dart';
import '../../models/tournament.dart';
import '../../models/venue_review.dart';
import '../../services/guest_profile_service.dart';
import '../../services/review_service.dart';
import '../../utils/app_logger.dart';

List<PublicVenueListing> _sortVenuesByName(List<PublicVenueListing> list) {
  final out = List<PublicVenueListing>.from(list);
  out.sort(
    (a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
  );
  return out;
}

List<PublicFloorTable> _sortFloorByName(List<PublicFloorTable> list) {
  final out = List<PublicFloorTable>.from(list);
  out.sort(
    (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  );
  return out;
}

List<PublicMenuItem> _sortMenuItems(List<PublicMenuItem> list) {
  final out = List<PublicMenuItem>.from(list);
  out.sort((a, b) {
    final o = a.sortOrder.compareTo(b.sortOrder);
    if (o != 0) return o;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return out;
}

/// Opt-in venue listings for anonymous discovery on the landing app.
/// Sorted in Dart so a composite index on `showOnDiscovery` + `displayName` is not required.
final publicVenuesProvider = StreamProvider<List<PublicVenueListing>>((ref) {
  return FirebaseFirestore.instance
      .collection(FirestoreCollections.publicVenues)
      .where('showOnDiscovery', isEqualTo: true)
      .limit(120)
      .snapshots()
      .map(
        (snap) => _sortVenuesByName(
          snap.docs.map(PublicVenueListing.fromFirestore).toList(growable: false),
        ),
      )
      .handleError((Object e, StackTrace st) {
        AppLogger.error('publicVenuesProvider failed', tag: 'Landing', error: e, stackTrace: st);
        return <PublicVenueListing>[];
      });
});

/// Live public floor for one company (empty stream if rules deny).
final publicFloorTablesFamily =
    StreamProvider.family<List<PublicFloorTable>, String>((ref, companyId) {
      return FirebaseFirestore.instance
          .collection(FirestoreCollections.companies)
          .doc(companyId)
          .collection(FirestoreCollections.publicFloor)
          .limit(50)
          .snapshots()
          .map(
            (snap) => _sortFloorByName(
              snap.docs
                  .map(PublicFloorTable.fromFirestore)
                  .toList(growable: false),
            ),
          )
          .handleError((Object e, StackTrace st) {
            AppLogger.error('publicFloorTablesFamily($companyId) failed', tag: 'Landing', error: e, stackTrace: st);
            return <PublicFloorTable>[];
          });
    });

/// Approved public holds for the live floor (no guest PII).
final publicBookingSlotsFamily =
    StreamProvider.family<List<PublicBookingSlot>, String>((ref, companyId) {
      return FirebaseFirestore.instance
          .collection(FirestoreCollections.companies)
          .doc(companyId)
          .collection(FirestoreCollections.publicBookingSlots)
          .limit(100)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map(PublicBookingSlot.fromFirestore)
                .toList(growable: false),
          )
          .handleError((Object e, StackTrace st) {
            AppLogger.error('publicBookingSlotsFamily($companyId) failed', tag: 'Landing', error: e, stackTrace: st);
            return <PublicBookingSlot>[];
          });
    });

final publicMenuItemsFamily =
    StreamProvider.family<List<PublicMenuItem>, String>((ref, companyId) {
      return FirebaseFirestore.instance
          .collection(FirestoreCollections.companies)
          .doc(companyId)
          .collection(FirestoreCollections.publicMenuItems)
          .limit(200)
          .snapshots()
          .map(
            (snap) => _sortMenuItems(
              snap.docs
                  .map(PublicMenuItem.fromFirestore)
                  .toList(growable: false),
            ),
          )
          .handleError((Object e, StackTrace st) {
            AppLogger.error('publicMenuItemsFamily($companyId) failed', tag: 'Landing', error: e, stackTrace: st);
            return <PublicMenuItem>[];
          });
    });

const _publicTournamentStatuses = {'draft', 'registration', 'inProgress'};

/// Public tournaments for one company (paths allowed by rules).
final publicTournamentsForCompanyFamily =
    StreamProvider.family<List<Tournament>, String>((ref, companyId) {
      return FirebaseFirestore.instance
          .collection(FirestoreCollections.companies)
          .doc(companyId)
          .collection(FirestoreCollections.tournaments)
          .where('showOnPublicLanding', isEqualTo: true)
          .limit(48)
          .snapshots()
          .map((snapshot) {
            final list = snapshot.docs
                .where((d) {
                  final status = d.data()['status'] as String?;
                  return status != null &&
                      _publicTournamentStatuses.contains(status);
                })
                .map(Tournament.fromFirestore)
                .toList(growable: false);
            list.sort((a, b) => a.startDate.compareTo(b.startDate));
            return list.take(24).toList(growable: false);
          })
          .handleError((Object e, StackTrace st) {
            AppLogger.error('publicTournamentsForCompanyFamily($companyId) failed', tag: 'Landing', error: e, stackTrace: st);
            return <Tournament>[];
          });
    });

/// Opt-in public carousel: `showOnPublicLanding == true` under any company.
/// Status filtered client-side to limit composite indexes.
final publicTournamentsProvider = StreamProvider<List<Tournament>>((ref) {
  const allowedStatuses = {'draft', 'registration', 'inProgress'};
  return FirebaseFirestore.instance
      .collectionGroup(FirestoreCollections.tournaments)
      .where('showOnPublicLanding', isEqualTo: true)
      .limit(48)
      .snapshots()
      .map((snapshot) {
        final list = snapshot.docs
            .where((d) {
              final status = d.data()['status'] as String?;
              return status != null && allowedStatuses.contains(status);
            })
            .map(Tournament.fromFirestore)
            .toList();
        list.sort((a, b) => a.startDate.compareTo(b.startDate));
        return list.take(8).toList(growable: false);
      })
      .handleError((Object e, StackTrace st) {
        AppLogger.error('publicTournamentsProvider failed', tag: 'Landing', error: e, stackTrace: st);
        return <Tournament>[];
      });
});

// ---------------------------------------------------------------------------
// Guest / consumer providers
// ---------------------------------------------------------------------------

final guestProfileServiceProvider =
    Provider<GuestProfileService>((ref) => GuestProfileService());

final reviewServiceProvider =
    Provider<ReviewService>((ref) => ReviewService());

final venueReviewsFamily =
    StreamProvider.family<List<VenueReview>, String>((ref, companyId) {
  return ref.watch(reviewServiceProvider).watchReviews(companyId);
});

final guestProfileFamily =
    StreamProvider.family<GuestProfile?, String>((ref, uid) {
  return ref.watch(guestProfileServiceProvider).watchProfile(uid);
});

final guestWalletBalanceFamily =
    StreamProvider.family<double, String>((ref, uid) {
  return ref.watch(guestProfileServiceProvider).watchWalletBalance(uid);
});
