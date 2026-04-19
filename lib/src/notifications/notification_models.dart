class AppNotificationItem {
  const AppNotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.deepLink,
    required this.read,
    this.createdAt,
    this.sentAt,
    this.readAt,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String? deepLink;
  final bool read;
  final DateTime? createdAt;
  final DateTime? sentAt;
  final DateTime? readAt;
  final Map<String, dynamic> metadata;

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is! String || value.trim().isEmpty) {
        return null;
      }
      return DateTime.tryParse(value);
    }

    return AppNotificationItem(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      deepLink: json['deepLink'] as String?,
      read: json['read'] == true,
      createdAt: parseDate(json['createdAt']),
      sentAt: parseDate(json['sentAt']),
      readAt: parseDate(json['readAt']),
      metadata:
          (json['metadata'] as Map<String, dynamic>?) ??
          const <String, dynamic>{},
    );
  }
}

class NotificationPageResult {
  const NotificationPageResult({required this.notifications, this.nextCursor});

  final List<AppNotificationItem> notifications;
  final String? nextCursor;

  factory NotificationPageResult.fromJson(Map<String, dynamic> json) {
    final notifications = (json['notifications'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AppNotificationItem.fromJson)
        .toList();

    return NotificationPageResult(
      notifications: notifications,
      nextCursor: json['nextCursor'] as String?,
    );
  }
}

class NotificationPreferencesModel {
  const NotificationPreferencesModel({
    required this.pushEnabled,
    required this.emailEnabled,
    required this.inAppEnabled,
    required this.dailyMoodReminderEnabled,
    required this.moodForecastEnabled,
    required this.moodQuotesEnabled,
    required this.appointmentPushEnabled,
    required this.appointmentEmailEnabled,
    required this.preferredReminderTime,
    required this.quietHoursStart,
    required this.quietHoursEnd,
    required this.timezone,
    required this.lockScreenPreviewMode,
    required this.wellnessFrequency,
    required this.quoteTone,
    required this.predictionStyle,
    required this.locale,
  });

  final bool pushEnabled;
  final bool emailEnabled;
  final bool inAppEnabled;
  final bool dailyMoodReminderEnabled;
  final bool moodForecastEnabled;
  final bool moodQuotesEnabled;
  final bool appointmentPushEnabled;
  final bool appointmentEmailEnabled;
  final String preferredReminderTime;
  final String quietHoursStart;
  final String quietHoursEnd;
  final String timezone;
  final String lockScreenPreviewMode;
  final String wellnessFrequency;
  final String quoteTone;
  final String predictionStyle;
  final String locale;

  factory NotificationPreferencesModel.fromJson(Map<String, dynamic> json) {
    return NotificationPreferencesModel(
      pushEnabled: json['pushEnabled'] != false,
      emailEnabled: json['emailEnabled'] != false,
      inAppEnabled: json['inAppEnabled'] != false,
      dailyMoodReminderEnabled: json['dailyMoodReminderEnabled'] != false,
      moodForecastEnabled: json['moodForecastEnabled'] != false,
      moodQuotesEnabled: json['moodQuotesEnabled'] != false,
      appointmentPushEnabled: json['appointmentPushEnabled'] != false,
      appointmentEmailEnabled: json['appointmentEmailEnabled'] != false,
      preferredReminderTime:
          json['preferredReminderTime'] as String? ?? '20:00',
      quietHoursStart: json['quietHoursStart'] as String? ?? '22:00',
      quietHoursEnd: json['quietHoursEnd'] as String? ?? '08:00',
      timezone: json['timezone'] as String? ?? 'UTC',
      lockScreenPreviewMode:
          json['lockScreenPreviewMode'] as String? ?? 'generic',
      wellnessFrequency: json['wellnessFrequency'] as String? ?? 'standard',
      quoteTone: json['quoteTone'] as String? ?? 'direct',
      predictionStyle: json['predictionStyle'] as String? ?? 'explicit',
      locale: json['locale'] as String? ?? 'en',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pushEnabled': pushEnabled,
      'emailEnabled': emailEnabled,
      'inAppEnabled': inAppEnabled,
      'dailyMoodReminderEnabled': dailyMoodReminderEnabled,
      'moodForecastEnabled': moodForecastEnabled,
      'moodQuotesEnabled': moodQuotesEnabled,
      'appointmentPushEnabled': appointmentPushEnabled,
      'appointmentEmailEnabled': appointmentEmailEnabled,
      'preferredReminderTime': preferredReminderTime,
      'quietHoursStart': quietHoursStart,
      'quietHoursEnd': quietHoursEnd,
      'timezone': timezone,
      'lockScreenPreviewMode': lockScreenPreviewMode,
      'wellnessFrequency': wellnessFrequency,
      'quoteTone': quoteTone,
      'predictionStyle': predictionStyle,
      'locale': locale,
    };
  }

  NotificationPreferencesModel copyWith({
    bool? pushEnabled,
    bool? emailEnabled,
    bool? inAppEnabled,
    bool? dailyMoodReminderEnabled,
    bool? moodForecastEnabled,
    bool? moodQuotesEnabled,
    bool? appointmentPushEnabled,
    bool? appointmentEmailEnabled,
    String? preferredReminderTime,
    String? quietHoursStart,
    String? quietHoursEnd,
    String? timezone,
    String? lockScreenPreviewMode,
    String? wellnessFrequency,
    String? quoteTone,
    String? predictionStyle,
    String? locale,
  }) {
    return NotificationPreferencesModel(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      inAppEnabled: inAppEnabled ?? this.inAppEnabled,
      dailyMoodReminderEnabled:
          dailyMoodReminderEnabled ?? this.dailyMoodReminderEnabled,
      moodForecastEnabled: moodForecastEnabled ?? this.moodForecastEnabled,
      moodQuotesEnabled: moodQuotesEnabled ?? this.moodQuotesEnabled,
      appointmentPushEnabled:
          appointmentPushEnabled ?? this.appointmentPushEnabled,
      appointmentEmailEnabled:
          appointmentEmailEnabled ?? this.appointmentEmailEnabled,
      preferredReminderTime:
          preferredReminderTime ?? this.preferredReminderTime,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      timezone: timezone ?? this.timezone,
      lockScreenPreviewMode:
          lockScreenPreviewMode ?? this.lockScreenPreviewMode,
      wellnessFrequency: wellnessFrequency ?? this.wellnessFrequency,
      quoteTone: quoteTone ?? this.quoteTone,
      predictionStyle: predictionStyle ?? this.predictionStyle,
      locale: locale ?? this.locale,
    );
  }
}
