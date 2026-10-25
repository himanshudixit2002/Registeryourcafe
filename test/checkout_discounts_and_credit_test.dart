import 'package:flutter_test/flutter_test.dart';
import 'package:registeryourcafe/models/customer.dart';
import 'package:registeryourcafe/models/membership_type_definition.dart';
import 'package:registeryourcafe/utils/credit_verification.dart';
import 'package:registeryourcafe/utils/session_checkout_discounts.dart';

Customer _testCustomer({
  required String membershipTypeId,
  DateTime? membershipExpiry,
}) {
  final now = DateTime(2026, 6, 15);
  return Customer(
    id: 'c1',
    name: 'Test',
    phoneNumber: '1',
    credits: 0,
    membershipTypeId: membershipTypeId,
    membershipExpiry: membershipExpiry,
    lastCreditTopUpDate: now,
    lastCreditTopUpAmount: 0,
    lastCreditTopUpMethod: PaymentMethod.cash,
    preferredPaymentMethods: const [],
    hasLowCreditAlert: false,
    hasMembershipExpiryAlert: false,
    createdAt: now,
    updatedAt: now,
    membershipHistory: const [],
    creditCode: '123456',
  );
}

void main() {
  group('applySubtotalPercentageDiscounts', () {
    test('independent percentages on same subtotal', () {
      final r = applySubtotalPercentageDiscounts(
        subtotal: 1000,
        discounts: {'membership': 10, 'special': 5},
      );
      expect(r.totalAfterDiscounts, 850);
      expect(r.appliedDiscounts['membershipDiscountPercentage'], 10);
      expect(r.appliedDiscounts['specialDiscountPercentage'], 5);
    });

    test('clamps at zero', () {
      final r = applySubtotalPercentageDiscounts(
        subtotal: 100,
        discounts: {'membership': 80, 'special': 80},
      );
      expect(r.totalAfterDiscounts, 0);
    });

    test('null discounts returns subtotal', () {
      final r = applySubtotalPercentageDiscounts(subtotal: 50, discounts: null);
      expect(r.totalAfterDiscounts, 50);
      expect(r.appliedDiscounts, isEmpty);
    });
  });

  group('discountsMapForEndSession', () {
    test('returns null when both zero', () {
      expect(
        discountsMapForEndSession(membershipPercent: 0, specialPercent: 0),
        isNull,
      );
    });

    test('includes only positive entries', () {
      final m = discountsMapForEndSession(membershipPercent: 12, specialPercent: 0);
      expect(m, {'membership': 12});
    });
  });

  group('membershipDiscountPercentForCustomer', () {
    final definitions = [
      const MembershipTypeDefinition(
        id: 'gold',
        name: 'Gold',
        fee: 100,
        creditsToAdd: 100,
        discountPercentage: 15,
        tierLevel: 1,
        colorArgb: 0xFFFFD700,
        sortOrder: 1,
        isRegular: false,
      ),
    ];
    final now = DateTime(2026, 6, 15);

    test('expired membership yields zero', () {
      final c = _testCustomer(
        membershipTypeId: 'gold',
        membershipExpiry: now.subtract(const Duration(days: 1)),
      );
      expect(
        membershipDiscountPercentForCustomer(
          customer: c,
          definitions: definitions,
          now: now,
        ),
        0,
      );
    });

    test('paid tier with active expiry returns percentage', () {
      final c = _testCustomer(
        membershipTypeId: 'gold',
        membershipExpiry: now.add(const Duration(days: 30)),
      );
      expect(
        membershipDiscountPercentForCustomer(
          customer: c,
          definitions: definitions,
          now: now,
        ),
        15,
      );
    });

    test('regular tier yields zero', () {
      final c = _testCustomer(membershipTypeId: kRegularMembershipTypeId);
      expect(
        membershipDiscountPercentForCustomer(
          customer: c,
          definitions: definitions,
          now: now,
        ),
        0,
      );
    });
  });

  group('CreditVerification format helpers', () {
    test('isValidCreditCodeFormat', () {
      expect(CreditVerification.isValidCreditCodeFormat('123456'), true);
      expect(CreditVerification.isValidCreditCodeFormat(' 123456 '), true);
      expect(CreditVerification.isValidCreditCodeFormat('12345'), false);
      expect(CreditVerification.isValidCreditCodeFormat('abcdef'), false);
    });

    test('generateCreditCode is six digits', () {
      final code = CreditVerification.generateCreditCode();
      expect(CreditVerification.isValidCreditCodeFormat(code), true);
    });
  });
}
