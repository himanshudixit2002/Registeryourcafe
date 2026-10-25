/// Note written to session-linked order [refundHistory] when the parent
/// session refund marks the order refunded (no separate sales row needed).
const String kRefundHistoryNoteFullSessionRefund = 'Full session refund';

/// Legacy Firestore value; treat like [kRefundHistoryNoteFullSessionRefund]
/// when aggregating sales.
const String kRefundHistoryNoteSessionRefundLegacy =
    'Refunded as part of session refund';

bool isRefundNoteFromSessionLevelRefund(String? note) {
  if (note == null) return false;
  return note == kRefundHistoryNoteFullSessionRefund ||
      note == kRefundHistoryNoteSessionRefundLegacy;
}
