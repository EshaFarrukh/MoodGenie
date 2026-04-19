import 'package:flutter/services.dart';

class LocalTimezoneService {
  LocalTimezoneService._();

  static const MethodChannel _channel = MethodChannel('moodgenie/device');

  static Future<String?> currentTimezone() async {
    try {
      final timezone = await _channel.invokeMethod<String>('getTimezone');
      final normalized = timezone?.trim();
      if (normalized == null || normalized.isEmpty) {
        return null;
      }
      return normalized;
    } catch (_) {
      return null;
    }
  }
}
