import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import '../utils/phone_utils.dart';

class WhatsAppService {
  WhatsAppService._();

  /// Launches WhatsApp chat with a credit code message.
  ///
  /// [rawPhone] is expected to be the 10-digit mobile number stored in DB.
  static Future<void> sendCreditCode({
    required String rawPhone,
    required String customerName,
    required String creditCode,
  }) async {
    final message =
        'Hi $customerName, your Registeryourcafe credit code is *$creditCode*. '
        'Please keep it safe and show it when you wish to pay with credits.';

    await sendMessage(rawPhone: rawPhone, message: message);
  }

  /// Sends an arbitrary message to the given phone number.
  ///
  /// Automatically adds country code 91 if 10-digit number supplied.
  /// Throws if the phone number is invalid.
  static Future<void> sendMessage({
    required String rawPhone,
    required String message,
  }) async {
    if (!PhoneUtils.isValid(rawPhone)) {
      throw ArgumentError('Invalid phone number: $rawPhone');
    }

    final url = Uri.parse(
      PhoneUtils.getWhatsAppUrl(rawPhone, message: message),
    );

    final bool success = kIsWeb
        ? await launchUrl(url, webOnlyWindowName: '_blank')
        : await launchUrl(url, mode: LaunchMode.externalApplication);

    if (!success) {
      throw Exception('Could not open WhatsApp');
    }
  }

  /// Opens WhatsApp for a phone number without a pre-filled message.
  static Future<void> openChat({required String rawPhone}) async {
    if (!PhoneUtils.isValid(rawPhone)) {
      throw ArgumentError('Invalid phone number: $rawPhone');
    }

    final url = Uri.parse(PhoneUtils.getWhatsAppUrl(rawPhone));

    final bool success = kIsWeb
        ? await launchUrl(url, webOnlyWindowName: '_blank')
        : await launchUrl(url, mode: LaunchMode.externalApplication);

    if (!success) {
      throw Exception('Could not open WhatsApp');
    }
  }
}
