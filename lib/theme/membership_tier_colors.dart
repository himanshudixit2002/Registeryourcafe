import 'package:flutter/material.dart';

/// Brand colors for membership tier badges (not tied to light/dark scheme).
class MembershipTierColors {
  MembershipTierColors._();

  static Color surface(String membershipType) {
    switch (membershipType.toLowerCase()) {
      case 'gold':
        return const Color(0xFFFFD700);
      case 'silver':
        return const Color(0xFFC0C0C0);
      case 'bronze1':
      case 'bronze2':
      case 'bronze3':
        return const Color(0xFFCD7F32);
      default:
        return const Color(0xFFE0E0E0);
    }
  }

  static Color label(String membershipType) {
    switch (membershipType.toLowerCase()) {
      case 'gold':
        return const Color(0xFFB8860B);
      case 'silver':
        return const Color(0xFF808080);
      case 'bronze1':
      case 'bronze2':
      case 'bronze3':
        return const Color(0xFF8B4513);
      default:
        return const Color(0xFF616161);
    }
  }
}
