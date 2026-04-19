import 'package:flutter_test/flutter_test.dart';
import 'package:moodgenie/src/services/backend_api_client.dart';

void main() {
  group('BackendApiClient URL safety', () {
    test('normalizes whitespace and trailing slashes', () {
      final url = BackendApiClient.normalizeBackendUrl(
        ' https://api.moodgenie.app/ ',
      );

      expect(url, 'https://api.moodgenie.app');
    });

    test('allows loopback HTTP URLs in debug mode', () {
      final url = BackendApiClient.enforceSafeBackendUrl(
        'http://127.0.0.1:3000',
        debugModeOverride: true,
      );

      expect(url, 'http://127.0.0.1:3000');
    });

    test('allows private LAN HTTP URLs in debug mode', () {
      final url = BackendApiClient.enforceSafeBackendUrl(
        'http://192.168.1.25:3000',
        debugModeOverride: true,
      );

      expect(url, 'http://192.168.1.25:3000');
    });

    test('allows Android emulator host in debug mode', () {
      final url = BackendApiClient.enforceSafeBackendUrl(
        'http://10.0.2.2:3000',
        debugModeOverride: true,
      );

      expect(url, 'http://10.0.2.2:3000');
    });

    test('rejects insecure public HTTP URLs even in debug mode', () {
      expect(
        () => BackendApiClient.enforceSafeBackendUrl(
          'http://example.com',
          debugModeOverride: true,
        ),
        throwsA(
          isA<BackendApiException>().having(
            (error) => error.code,
            'code',
            'insecure_backend_url',
          ),
        ),
      );
    });

    test('rejects HTTP URLs in non-debug builds', () {
      expect(
        () => BackendApiClient.enforceSafeBackendUrl(
          'http://127.0.0.1:3000',
          debugModeOverride: false,
        ),
        throwsA(isA<BackendApiException>()),
      );
    });

    test('rejects malformed backend URLs', () {
      expect(
        () => BackendApiClient.enforceSafeBackendUrl(
          '/api/chat',
          debugModeOverride: true,
        ),
        throwsA(
          isA<BackendApiException>().having(
            (error) => error.message,
            'message',
            'BACKEND_URL must be a valid absolute URL.',
          ),
        ),
      );
    });

    test('allows HTTPS URLs in all build modes', () {
      final url = BackendApiClient.enforceSafeBackendUrl(
        'https://api.moodgenie.app',
        debugModeOverride: false,
      );

      expect(url, 'https://api.moodgenie.app');
    });
  });
}
