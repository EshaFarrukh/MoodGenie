import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodgenie/src/services/local_timezone_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('moodgenie/device');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('returns native timezone identifier when available', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getTimezone');
          return 'Asia/Karachi';
        });

    final timezone = await LocalTimezoneService.currentTimezone();

    expect(timezone, 'Asia/Karachi');
  });

  test('returns null when native timezone lookup fails', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(code: 'unavailable');
        });

    final timezone = await LocalTimezoneService.currentTimezone();

    expect(timezone, isNull);
  });
}
