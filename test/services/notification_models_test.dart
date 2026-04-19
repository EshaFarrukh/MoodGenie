import 'package:flutter_test/flutter_test.dart';
import 'package:moodgenie/src/notifications/notification_models.dart';

void main() {
  group('AppNotificationItem.fromJson', () {
    test('parses notification payload fields safely', () {
      final item = AppNotificationItem.fromJson({
        'id': 'notif_1',
        'type': 'mood_forecast',
        'title': 'Forecast ready',
        'body': 'Your check-in forecast is available.',
        'deepLink': '/notifications/notif_1',
        'read': true,
        'createdAt': '2026-04-17T10:00:00.000Z',
        'sentAt': '2026-04-17T10:01:00.000Z',
        'readAt': '2026-04-17T10:02:00.000Z',
        'metadata': {'source': 'ai'},
      });

      expect(item.id, 'notif_1');
      expect(item.type, 'mood_forecast');
      expect(item.read, isTrue);
      expect(item.deepLink, '/notifications/notif_1');
      expect(item.createdAt, DateTime.parse('2026-04-17T10:00:00.000Z'));
      expect(item.sentAt, DateTime.parse('2026-04-17T10:01:00.000Z'));
      expect(item.readAt, DateTime.parse('2026-04-17T10:02:00.000Z'));
      expect(item.metadata['source'], 'ai');
    });

    test('falls back when dates and metadata are malformed', () {
      final item = AppNotificationItem.fromJson({
        'id': 'notif_2',
        'type': 'mood_quote',
        'title': 'Daily quote',
        'body': 'One step at a time.',
        'read': 'yes',
        'createdAt': '',
        'sentAt': 'not-a-date',
        'readAt': null,
      });

      expect(item.read, isFalse);
      expect(item.createdAt, isNull);
      expect(item.sentAt, isNull);
      expect(item.readAt, isNull);
      expect(item.metadata, isEmpty);
    });
  });

  group('NotificationPageResult.fromJson', () {
    test('keeps only well-shaped notification objects', () {
      final result = NotificationPageResult.fromJson({
        'notifications': [
          {
            'id': 'notif_1',
            'type': 'reminder',
            'title': 'Check in',
            'body': 'How are you feeling?',
            'read': false,
          },
          'invalid-entry',
          {
            'id': 'notif_2',
            'type': 'quote',
            'title': 'You are doing well',
            'body': 'Keep going.',
            'read': true,
          },
        ],
        'nextCursor': 'cursor_2',
      });

      expect(result.notifications, hasLength(2));
      expect(result.notifications.first.id, 'notif_1');
      expect(result.notifications.last.id, 'notif_2');
      expect(result.nextCursor, 'cursor_2');
    });
  });

  group('NotificationPreferencesModel', () {
    test('uses defaults when JSON fields are omitted', () {
      final model = NotificationPreferencesModel.fromJson(const {});

      expect(model.pushEnabled, isTrue);
      expect(model.emailEnabled, isTrue);
      expect(model.inAppEnabled, isTrue);
      expect(model.preferredReminderTime, '20:00');
      expect(model.quietHoursStart, '22:00');
      expect(model.quietHoursEnd, '08:00');
      expect(model.timezone, 'UTC');
      expect(model.locale, 'en');
    });

    test('copyWith updates selected fields and preserves the rest', () {
      final original = NotificationPreferencesModel.fromJson({
        'pushEnabled': true,
        'emailEnabled': true,
        'inAppEnabled': true,
        'dailyMoodReminderEnabled': true,
        'moodForecastEnabled': false,
        'moodQuotesEnabled': true,
        'appointmentPushEnabled': true,
        'appointmentEmailEnabled': false,
        'preferredReminderTime': '09:00',
        'quietHoursStart': '23:00',
        'quietHoursEnd': '07:00',
        'timezone': 'Asia/Karachi',
        'lockScreenPreviewMode': 'full',
        'wellnessFrequency': 'light',
        'quoteTone': 'gentle',
        'predictionStyle': 'subtle',
        'locale': 'en',
      });

      final updated = original.copyWith(
        pushEnabled: false,
        preferredReminderTime: '18:30',
        timezone: 'Europe/London',
      );

      expect(updated.pushEnabled, isFalse);
      expect(updated.preferredReminderTime, '18:30');
      expect(updated.timezone, 'Europe/London');
      expect(updated.emailEnabled, isTrue);
      expect(updated.predictionStyle, 'subtle');
    });

    test('serializes cleanly back to JSON', () {
      const model = NotificationPreferencesModel(
        pushEnabled: false,
        emailEnabled: true,
        inAppEnabled: true,
        dailyMoodReminderEnabled: false,
        moodForecastEnabled: true,
        moodQuotesEnabled: true,
        appointmentPushEnabled: false,
        appointmentEmailEnabled: true,
        preferredReminderTime: '21:15',
        quietHoursStart: '23:30',
        quietHoursEnd: '06:30',
        timezone: 'Asia/Karachi',
        lockScreenPreviewMode: 'generic',
        wellnessFrequency: 'standard',
        quoteTone: 'direct',
        predictionStyle: 'explicit',
        locale: 'en',
      );

      expect(model.toJson(), {
        'pushEnabled': false,
        'emailEnabled': true,
        'inAppEnabled': true,
        'dailyMoodReminderEnabled': false,
        'moodForecastEnabled': true,
        'moodQuotesEnabled': true,
        'appointmentPushEnabled': false,
        'appointmentEmailEnabled': true,
        'preferredReminderTime': '21:15',
        'quietHoursStart': '23:30',
        'quietHoursEnd': '06:30',
        'timezone': 'Asia/Karachi',
        'lockScreenPreviewMode': 'generic',
        'wellnessFrequency': 'standard',
        'quoteTone': 'direct',
        'predictionStyle': 'explicit',
        'locale': 'en',
      });
    });
  });
}
