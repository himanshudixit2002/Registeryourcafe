import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Utility class for haptic feedback
/// Provides platform-aware haptic feedback methods
class HapticUtils {
  // Disable haptics on web
  static bool get _isSupported => !kIsWeb;

  /// Light haptic feedback for selections and toggles
  static void light() {
    if (_isSupported) {
      HapticFeedback.lightImpact();
    }
  }

  /// Medium haptic feedback for actions
  static void medium() {
    if (_isSupported) {
      HapticFeedback.mediumImpact();
    }
  }

  /// Heavy haptic feedback for significant events
  static void heavy() {
    if (_isSupported) {
      HapticFeedback.heavyImpact();
    }
  }

  /// Selection click for list items and options
  static void selection() {
    if (_isSupported) {
      HapticFeedback.selectionClick();
    }
  }

  /// Vibration pattern for errors
  static void error() {
    if (_isSupported) {
      HapticFeedback.heavyImpact();
      Future<void>.delayed(const Duration(milliseconds: 100), () {
        HapticFeedback.heavyImpact();
      });
    }
  }

  /// Vibration pattern for success
  static void success() {
    if (_isSupported) {
      HapticFeedback.mediumImpact();
    }
  }

  /// Vibration for warnings
  static void warning() {
    if (_isSupported) {
      HapticFeedback.mediumImpact();
    }
  }

  /// Subtle vibration for scrolling boundaries
  static void boundary() {
    if (_isSupported) {
      HapticFeedback.lightImpact();
    }
  }

  /// Vibration for navigation changes
  static void navigate() {
    if (_isSupported) {
      HapticFeedback.lightImpact();
    }
  }

  /// Vibration for button presses
  static void button() {
    if (_isSupported) {
      HapticFeedback.lightImpact();
    }
  }

  /// Vibration for swipe actions
  static void swipe() {
    if (_isSupported) {
      HapticFeedback.mediumImpact();
    }
  }

  /// Vibration for delete/destructive actions
  static void destructive() {
    if (_isSupported) {
      HapticFeedback.heavyImpact();
    }
  }
}
