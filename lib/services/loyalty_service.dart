import 'package:cloud_firestore/cloud_firestore.dart';
import '../firestore/tenant_firestore.dart';
import '../models/app_user.dart';
import '../models/loyalty_conversion.dart';
import '../models/loyalty_settings.dart';
import '../utils/app_logger.dart';
import '../utils/firestore_utils.dart';
import 'credit_service.dart';

class LoyaltyConversionResult {
  final bool success;
  final double pointsConverted;
  final double creditsAwarded;
  final String? error;

  const LoyaltyConversionResult({
    required this.success,
    this.pointsConverted = 0,
    this.creditsAwarded = 0,
    this.error,
  });
}

class LoyaltyService {
  LoyaltyService(this._tenant);

  final TenantRef _tenant;
  static const String _settingsDocId = 'default';

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  Stream<LoyaltySettings> watchSettings() {
    return _tenant
        .loyaltySettings()
        .doc(_settingsDocId)
        .snapshots()
        .map(
          (doc) => doc.exists
              ? LoyaltySettings.fromFirestore(doc)
              : const LoyaltySettings(),
        );
  }

  Future<LoyaltySettings> getSettings() async {
    final doc = await _tenant.loyaltySettings().doc(_settingsDocId).get();
    return doc.exists
        ? LoyaltySettings.fromFirestore(doc)
        : const LoyaltySettings();
  }

  Future<void> updateSettings(LoyaltySettings settings) async {
    await _tenant
        .loyaltySettings()
        .doc(_settingsDocId)
        .set(settings.toFirestore(), SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------------
  // Conversion
  // ---------------------------------------------------------------------------

  Future<LoyaltyConversionResult> convertPointsToCredits({
    required String customerId,
    required double pointsToConvert,
    required AppUser performedBy,
  }) async {
    try {
      final settings = await getSettings();

      if (!settings.isEnabled) {
        return const LoyaltyConversionResult(
          success: false,
          error: 'Loyalty program is currently disabled',
        );
      }

      if (pointsToConvert <= 0) {
        return const LoyaltyConversionResult(
          success: false,
          error: 'Points to convert must be greater than 0',
        );
      }

      if (pointsToConvert % settings.pointsPerConversion != 0) {
        return LoyaltyConversionResult(
          success: false,
          error:
              'Points must be in multiples of ${settings.pointsPerConversion}',
        );
      }

      if (pointsToConvert < settings.minimumPointsToConvert) {
        return LoyaltyConversionResult(
          success: false,
          error:
              'Minimum ${settings.minimumPointsToConvert} points required to convert',
        );
      }

      final units = pointsToConvert / settings.pointsPerConversion;
      final creditsToAward = units * settings.creditsPerConversion;

      final conversionRef = _tenant.loyaltyConversions().doc();

      final result = await _tenant.db.runTransaction<LoyaltyConversionResult>((
        transaction,
      ) async {
        final customerRef = _tenant.customers().doc(customerId);
        final customerSnap = await transaction.get(customerRef);

        if (!customerSnap.exists) {
          throw Exception('Customer not found');
        }

        final customerData = customerSnap.data()!;
        final gameStats =
            customerData['gameStats'] as Map<String, dynamic>? ?? {};
        final currentPoints = parseFirestoreDouble(
          gameStats['currentLeaderboardPoints'],
        );

        if (currentPoints < pointsToConvert) {
          throw Exception(
            'Insufficient points. Available: ${currentPoints.toStringAsFixed(0)}, '
            'Requested: ${pointsToConvert.toStringAsFixed(0)}',
          );
        }

        final customerName = customerData['name'] as String? ?? '';
        final customerPhone = customerData['phoneNumber'] as String? ?? '';

        transaction.update(customerRef, {
          'gameStats.currentLeaderboardPoints': FieldValue.increment(
            -pointsToConvert,
          ),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.update(customerRef, {
          'credits': FieldValue.increment(creditsToAward),
        });

        final creditTxRef = _tenant.creditTransactions(customerId).doc();
        transaction.set(creditTxRef, {
          'date': FieldValue.serverTimestamp(),
          'amount': creditsToAward,
          'type': 'loyaltyConversion',
          'method': 'credits',
          'note':
              'Loyalty: ${pointsToConvert.toStringAsFixed(0)} pts → ${creditsToAward.toStringAsFixed(0)} credits',
          'performedById': performedBy.uid,
          'performedByName': performedBy.name,
          'performedByRole': performedBy.role.name,
          'reference': {
            'type': CreditService.refLoyaltyConversion,
            'id': conversionRef.id,
          },
        });

        transaction.set(
          conversionRef,
          LoyaltyConversion(
            id: conversionRef.id,
            customerId: customerId,
            customerName: customerName,
            customerPhone: customerPhone,
            pointsConverted: pointsToConvert,
            creditsAwarded: creditsToAward,
            conversionRate: settings.valuePerPoint,
            convertedAt: DateTime.now(),
            performedById: performedBy.uid,
            performedByName: performedBy.name,
            performedByRole: performedBy.role.name,
          ).toFirestore(),
        );

        return LoyaltyConversionResult(
          success: true,
          pointsConverted: pointsToConvert,
          creditsAwarded: creditsToAward,
        );
      });

      return result;
    } catch (e) {
      AppLogger.error(
        'Failed to convert loyalty points for customer $customerId',
        error: e,
        tag: 'LoyaltyService',
      );
      return LoyaltyConversionResult(
        success: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // History
  // ---------------------------------------------------------------------------

  Stream<List<LoyaltyConversion>> watchConversions({int limit = 50}) {
    return _tenant
        .loyaltyConversions()
        .orderBy('convertedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => LoyaltyConversion.fromFirestore(d)).toList(),
        );
  }

  Stream<List<LoyaltyConversion>> watchCustomerConversions(String customerId) {
    return _tenant
        .loyaltyConversions()
        .where('customerId', isEqualTo: customerId)
        .orderBy('convertedAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => LoyaltyConversion.fromFirestore(d)).toList(),
        );
  }

  Future<Map<String, dynamic>> getProgramStats() async {
    final snap = await _tenant.loyaltyConversions().get();

    double totalPointsConverted = 0;
    double totalCreditsAwarded = 0;
    final int totalConversions = snap.docs.length;

    for (final doc in snap.docs) {
      final data = doc.data();
      totalPointsConverted += parseFirestoreDouble(data['pointsConverted']);
      totalCreditsAwarded += parseFirestoreDouble(data['creditsAwarded']);
    }

    return {
      'totalConversions': totalConversions,
      'totalPointsConverted': totalPointsConverted,
      'totalCreditsAwarded': totalCreditsAwarded,
    };
  }
}
