import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../firestore/tenant_firestore.dart';
import '../../models/customer.dart';
import '../../models/session.dart';
import '../../models/table.dart';
import '../../providers/auth_provider.dart';
import '../../providers/table_provider.dart' show tableServiceProvider;
import '../../providers/tenant_provider.dart';
import '../../utils/credit_verification.dart';
import '../../utils/session_checkout_discounts.dart';
import '../../widgets/dialogs/bill_summary_dialog.dart';
import '../../widgets/dialogs/payment_method_dialog.dart';
import '../../widgets/dialogs/ptl_loser_selection_dialog.dart';
import 'package:registeryourcafe/constants/app_strings.dart';
import '../../utils/app_logger.dart';

/// Returns `false` if the Firestore update failed (logged). Used to detect
/// stuck billing locks when marking a session for checkout.
Future<bool> setSessionBillingInProgress(
  TenantRef? tenant,
  String sessionId,
  bool value,
) async {
  if (tenant == null) return false;
  try {
    await tenant.sessions().doc(sessionId).update({
      'billingInProgress': value,
      'billingMarkedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return true;
  } catch (e, st) {
    AppLogger.error(
      'setSessionBillingInProgress failed (sessionId=$sessionId, value=$value)',
      tag: 'Checkout',
      error: e,
      stackTrace: st,
    );
    return false;
  }
}

Future<void> autoPauseSessionForBilling(
  WidgetRef ref,
  TableSession session,
) async {
  if (!session.isPaused) {
    try {
      await ref.read(tableServiceProvider).pauseSession(session: session);
    } catch (e, st) {
      AppLogger.error(
        'autoPauseSessionForBilling failed',
        tag: 'Checkout',
        error: e,
        stackTrace: st,
      );
    }
  }
}

Future<void> autoResumeSessionAfterCancel(
  WidgetRef ref,
  TenantRef? tenant,
  TableSession session,
) async {
  if (tenant == null) return;
  try {
    final doc = await tenant.sessions().doc(session.id).get();
    if (doc.exists) {
      final currentSession = TableSession.fromFirestore(doc);
      if (currentSession.isPaused &&
          currentSession.status == SessionStatus.active) {
        await ref
            .read(tableServiceProvider)
            .resumeSession(session: currentSession);
      }
    }
  } catch (e, st) {
    AppLogger.error(
      'autoResumeSessionAfterCancel failed',
      tag: 'Checkout',
      error: e,
      stackTrace: st,
    );
  }
}

/// Shared billing / end-session flow (gaming and dining). Returns `true` when
/// the session was completed successfully; callers should pop their route.
Future<bool> runSessionCheckoutFlow({
  required BuildContext context,
  required WidgetRef ref,
  required TableSession session,
  required SnookerTable table,
  required Customer customer,
}) async {
  final tenant = ref.read(tenantRefProvider);
  if (tenant == null) {
    if (context.mounted) {
      final theme = Theme.of(context);
      final cs = theme.colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No company context',
            style: TextStyle(color: cs.onErrorContainer),
          ),
          backgroundColor: cs.errorContainer,
        ),
      );
    }
    return false;
  }

  final pendingOrders = await tenant
      .cafeOrders()
      .where('sessionId', isEqualTo: session.id)
      .where('status', whereIn: ['pending', 'preparing'])
      .limit(1)
      .get();

  if (!context.mounted) return false;
  if (pendingOrders.docs.isNotEmpty) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cafe Orders In Progress'),
        content: const Text(
          'There are still café items being prepared. Please wait until all orders are marked as "Ready" before billing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return false;
  }

  bool billingMarkerSet = false;
  Future<void> clearBillingMarkerIfSet() async {
    if (billingMarkerSet) {
      final cleared = await setSessionBillingInProgress(
        tenant,
        session.id,
        false,
      );
      if (!cleared) {
        AppLogger.warning(
          'Could not clear billingInProgress on session ${session.id}; table may need manual unlock',
          tag: 'Checkout',
        );
      }
      billingMarkerSet = false;
    }
  }

  final billingMarked = await setSessionBillingInProgress(
    tenant,
    session.id,
    true,
  );
  if (!billingMarked) {
    if (context.mounted) {
      final theme = Theme.of(context);
      final cs = theme.colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not lock session for billing. Check connection and try again.',
            style: TextStyle(color: cs.onErrorContainer),
          ),
          backgroundColor: cs.errorContainer,
        ),
      );
    }
    return false;
  }
  billingMarkerSet = true;
  if (session.isGaming) {
    await autoPauseSessionForBilling(ref, session);
  }

  if (!context.mounted) {
    await clearBillingMarkerIfSet();
    return false;
  }

  int? loserPlayerIdx;
  Customer payerCustomer = customer;

  if (session.isPTL) {
    final hasPlayerNames = session.playerNames.isNotEmpty;
    final actualPlayerCount = session.playerNames.length;

    if (!hasPlayerNames || actualPlayerCount < 2) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('PTL Players Incomplete'),
          content: Text(
            !hasPlayerNames
                ? 'No player names found for this PTL session.'
                : 'PTL requires at least 2 players. Only $actualPlayerCount player found.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (session.isGaming) {
        await autoResumeSessionAfterCancel(ref, tenant, session);
      }
      await clearBillingMarkerIfSet();
      return false;
    }

    if (!context.mounted) {
      await clearBillingMarkerIfSet();
      return false;
    }

    final selectedPlayer = await showDialog<int?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PTLLoserSelectionDialog(
        playerNames: session.playerNames,
        playerCount: actualPlayerCount,
      ),
    );

    if (selectedPlayer == null) {
      if (session.isGaming) {
        await autoResumeSessionAfterCancel(ref, tenant, session);
      }
      await clearBillingMarkerIfSet();
      return false;
    }
    loserPlayerIdx = selectedPlayer;

    if (session.playerIds.isNotEmpty &&
        loserPlayerIdx > 0 &&
        loserPlayerIdx <= session.playerIds.length) {
      final loserId = session.playerIds[loserPlayerIdx - 1];
      try {
        final snap = await tenant.customers().doc(loserId).get();
        if (snap.exists) {
          payerCustomer = Customer.fromFirestore(snap);
        }
      } catch (e, st) {
        if (AppLogger.isLikelyFirestorePermissionDenied(e)) {
          AppLogger.warning(
            'PTL payer customer load permission issue (loserId=$loserId) — using session customer',
            tag: 'Checkout',
          );
        } else {
          AppLogger.error(
            'PTL payer customer load failed (loserId=$loserId)',
            tag: 'Checkout',
            error: e,
            stackTrace: st,
          );
        }
      }
    }
  }

  if (!context.mounted) {
    await clearBillingMarkerIfSet();
    return false;
  }

  final previewSession = session.copyWith(
    endTime: DateTime.now(),
    loserPlayerIndex: loserPlayerIdx,
  );

  final billStep = await BillSummaryDialog.show(
    context,
    session: previewSession,
    customer: payerCustomer,
  );

  if (billStep == null) {
    if (session.isGaming) {
      await autoResumeSessionAfterCancel(ref, tenant, session);
    }
    await clearBillingMarkerIfSet();
    return false;
  }

  final checkoutDiscounts = billStep.discounts;
  final payableAfterDiscounts = applySubtotalPercentageDiscounts(
    subtotal: previewSession.calculateTotalBillAmount(),
    discounts: checkoutDiscounts,
  ).totalAfterDiscounts;

  if (!context.mounted) {
    await clearBillingMarkerIfSet();
    return false;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(session.isGaming ? 'Confirm End Session' : 'Confirm Close Table'),
      content: Text(
        session.isGaming
            ? 'Are you sure you want to mark this session as completed and free the table?'
            : 'Close this table and complete all orders?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text(AppStrings.cancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(session.isGaming ? 'Confirm End Session' : 'Confirm Close'),
        ),
      ],
    ),
  );

  if (confirmed != true) {
    if (session.isGaming) {
      await autoResumeSessionAfterCancel(ref, tenant, session);
    }
    await clearBillingMarkerIfSet();
    return false;
  }

  if (!context.mounted) {
    await clearBillingMarkerIfSet();
    return false;
  }

  final paymentResult = await showDialog<PaymentSelectionResult>(
    context: context,
    builder: (ctx) => PaymentMethodDialog(
      session: previewSession,
      customer: payerCustomer,
      payableAfterDiscounts: payableAfterDiscounts,
    ),
  );

  if (paymentResult == null || paymentResult.isCancelled) {
    if (session.isGaming) {
      await autoResumeSessionAfterCancel(ref, tenant, session);
    }
    await clearBillingMarkerIfSet();
    return false;
  }

  if (!context.mounted) {
    await clearBillingMarkerIfSet();
    return false;
  }

  if (paymentResult.isCredits && payerCustomer.creditCode.isNotEmpty) {
    final verified = await CreditVerification.verifyCreditCode(
      context,
      payerCustomer,
    );
    if (!verified) {
      if (session.isGaming) {
        await autoResumeSessionAfterCancel(ref, tenant, session);
      }
      await clearBillingMarkerIfSet();
      return false;
    }
  }

  if (!context.mounted) {
    await clearBillingMarkerIfSet();
    return false;
  }

  final paymentMethod = paymentResult.method;
  final currentUser = ref.read(appUserProvider).value;
  if (currentUser == null) {
    if (session.isGaming) {
      await autoResumeSessionAfterCancel(ref, tenant, session);
    }
    await clearBillingMarkerIfSet();
    if (context.mounted) {
      final theme = Theme.of(context);
      final cs = theme.colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not identify current user. Please log in again.',
            style: TextStyle(color: cs.onErrorContainer),
          ),
          backgroundColor: cs.errorContainer,
        ),
      );
    }
    return false;
  }

  try {
    await ref
        .read(tableServiceProvider)
        .endSession(
          session: session,
          table: table,
          customer: payerCustomer,
          paymentMethod: paymentMethod,
          completedBy: currentUser,
          loserPlayerIndex: loserPlayerIdx,
          discounts: checkoutDiscounts,
        );
    await clearBillingMarkerIfSet();
    return true;
  } catch (e) {
    if (session.isGaming) {
      await autoResumeSessionAfterCancel(ref, tenant, session);
    }
    await clearBillingMarkerIfSet();
    if (context.mounted) {
      final theme = Theme.of(context);
      final cs = theme.colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error ending session: ${e.toString()}',
            style: TextStyle(color: cs.onErrorContainer),
          ),
          backgroundColor: cs.errorContainer,
        ),
      );
    }
    return false;
  }
}
