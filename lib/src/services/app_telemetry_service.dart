import 'package:flutter/foundation.dart';

import 'backend_api_client.dart';

class AppTelemetryService {
  AppTelemetryService._();

  static final AppTelemetryService instance = AppTelemetryService._();

  final BackendApiClient _backendClient = BackendApiClient();

  Future<void> trackEvent(
    String eventName, {
    Map<String, dynamic> attributes = const <String, dynamic>{},
  }) async {
    try {
      await _backendClient.postJson(
        '/api/mobile-events',
        body: {'eventName': eventName, 'attributes': _sanitizeMap(attributes)},
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Telemetry event dropped: $eventName ($error)');
      }
    }
  }

  Future<void> captureError(
    Object error,
    StackTrace stack, {
    required String source,
    bool fatal = false,
  }) async {
    await trackEvent(
      'app.unhandled_error',
      attributes: {
        'source': source,
        'fatal': fatal,
        'errorType': error.runtimeType.toString(),
        'message': error.toString().substring(
          0,
          error.toString().length > 300 ? 300 : error.toString().length,
        ),
        'stackTop': stack.toString().split('\n').take(5).join('\n'),
      },
    );
  }

  Map<String, dynamic> _sanitizeMap(Map<String, dynamic> input) {
    final sanitized = <String, dynamic>{};
    for (final entry in input.entries) {
      sanitized[entry.key] = _sanitizeValue(entry.value);
    }
    return sanitized;
  }

  dynamic _sanitizeValue(dynamic value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is Iterable) {
      return value.take(20).map(_sanitizeValue).toList();
    }
    if (value is Map) {
      return value.map(
        (key, mapValue) => MapEntry(key.toString(), _sanitizeValue(mapValue)),
      );
    }
    return value.toString();
  }
}
