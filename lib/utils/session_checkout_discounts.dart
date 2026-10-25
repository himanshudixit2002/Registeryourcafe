import '../models/customer.dart';
import '../models/membership_type_definition.dart';

/// Preview of %-of-subtotal discounts matching [TableService._calculateFinalBill]
/// (discount slice only — no credits or payment mode).
class SessionCheckoutDiscountPreview {
  final double totalAfterDiscounts;
  final Map<String, dynamic> appliedDiscounts;

  const SessionCheckoutDiscountPreview({
    required this.totalAfterDiscounts,
    required this.appliedDiscounts,
  });
}

/// Applies `membership` and `special` as independent percentages of [subtotal],
/// same order and formula as server-side billing.
SessionCheckoutDiscountPreview applySubtotalPercentageDiscounts({
  required double subtotal,
  Map<String, double>? discounts,
}) {
  double totalAfterDiscounts = subtotal;
  final Map<String, dynamic> appliedDiscounts = {};

  if (discounts != null) {
    final double membershipDiscount = discounts['membership'] ?? 0.0;
    if (membershipDiscount > 0) {
      totalAfterDiscounts -= subtotal * (membershipDiscount / 100);
      appliedDiscounts['membershipDiscountPercentage'] = membershipDiscount;
    }
    final double specialDiscount = discounts['special'] ?? 0.0;
    if (specialDiscount > 0) {
      totalAfterDiscounts -= subtotal * (specialDiscount / 100);
      appliedDiscounts['specialDiscountPercentage'] = specialDiscount;
    }
  }
  totalAfterDiscounts = totalAfterDiscounts < 0 ? 0 : totalAfterDiscounts;

  return SessionCheckoutDiscountPreview(
    totalAfterDiscounts: totalAfterDiscounts,
    appliedDiscounts: appliedDiscounts,
  );
}

/// Builds the map passed to [TableService.endSession]; returns null if empty.
Map<String, double>? discountsMapForEndSession({
  required double membershipPercent,
  required double specialPercent,
}) {
  final map = <String, double>{};
  if (membershipPercent > 0) {
    map['membership'] = membershipPercent;
  }
  if (specialPercent > 0) {
    map['special'] = specialPercent;
  }
  return map.isEmpty ? null : map;
}

/// Membership %-off subtotal when the customer has an active paid tier.
double membershipDiscountPercentForCustomer({
  required Customer customer,
  required List<MembershipTypeDefinition> definitions,
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  if (customer.membershipExpiry != null &&
      customer.membershipExpiry!.isBefore(n)) {
    return 0;
  }

  final id = normalizeMembershipTypeId(customer.membershipTypeId);
  MembershipTypeDefinition? def;
  for (final d in definitions) {
    if (d.id == id) {
      def = d;
      break;
    }
  }
  if (def == null || def.isRegular) return 0;
  final p = def.discountPercentage;
  return p > 0 ? p : 0;
}
