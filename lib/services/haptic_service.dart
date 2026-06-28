// lib/services/haptic_service.dart
import 'package:flutter/services.dart';

class HapticService {
  // Toggle this from your settings page.
  static bool _enabled = true;

  static void setEnabled(bool value) => _enabled = value;

  static void subtle() {
    if (_enabled) HapticFeedback.lightImpact();
  }

  static void standard() {
    if (_enabled) HapticFeedback.mediumImpact();
  }

  static void prominent() {
    if (_enabled) HapticFeedback.heavyImpact();
  }

  static void selection() {
    if (_enabled) HapticFeedback.selectionClick();
  }
}
