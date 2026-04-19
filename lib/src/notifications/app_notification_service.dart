import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../navigation/app_navigator.dart';
import '../services/backend_api_client.dart';
import '../services/local_timezone_service.dart';
import 'notification_models.dart';

const AndroidNotificationChannel _wellnessChannel = AndroidNotificationChannel(
  'wellness_reminders',
  'Wellness reminders',
  description: 'Mood reminders, mood forecasts, and supportive check-ins.',
  importance: Importance.high,
);

const AndroidNotificationChannel _appointmentUpdatesChannel =
    AndroidNotificationChannel(
      'appointment_updates',
      'Appointment updates',
      description: 'Booking requests and appointment status updates.',
      importance: Importance.high,
    );

const AndroidNotificationChannel _appointmentRemindersChannel =
    AndroidNotificationChannel(
      'appointment_reminders',
      'Appointment reminders',
      description: 'Upcoming appointment reminders.',
      importance: Importance.high,
    );

const AndroidNotificationChannel _therapistOpsChannel =
    AndroidNotificationChannel(
      'therapist_ops',
      'Therapist operations',
      description: 'Therapist-side booking requests and operational notices.',
      importance: Importance.high,
    );

class AppNotificationService extends ChangeNotifier {
  AppNotificationService({
    BackendApiClient? apiClient,
    FirebaseMessaging? messaging,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _apiClient = apiClient ?? BackendApiClient(),
       _messaging = messaging ?? FirebaseMessaging.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin() {
    _authSubscription = _auth.authStateChanges().listen((_) {
      unawaited(_syncRegistrationForCurrentUser());
    });
  }

  final BackendApiClient _apiClient;
  final FirebaseMessaging _messaging;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FlutterLocalNotificationsPlugin _localNotifications;

  StreamSubscription<User?>? _authSubscription;
  bool _initialized = false;
  bool _permissionPromptShownThisSession = false;
  String _permissionStatus = 'unknown';
  String? _lastRegisteredDeviceId;
  String? _lastRegistrationError;
  NotificationPreferencesModel? _preferencesCache;
  NotificationPageResult? _firstNotificationPageCache;

  String get permissionStatus => _permissionStatus;
  String? get lastRegistrationError => _lastRegistrationError;
  NotificationPreferencesModel? get cachedPreferences => _preferencesCache;
  NotificationPageResult? get cachedFirstNotificationPage =>
      _firstNotificationPageCache;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) {
      return;
    }

    await _initializeLocalNotifications();
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: true,
    );
    _bindForegroundMessageHandlers();
    await _syncRegistrationForCurrentUser();

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      handleNotificationDeepLink(_extractDeepLink(initialMessage.data));
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> maybePromptForPermission(BuildContext context) async {
    if (kIsWeb || _permissionPromptShownThisSession) {
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    final settings = await _messaging.getNotificationSettings();
    _permissionStatus = settings.authorizationStatus.name;
    if (settings.authorizationStatus != AuthorizationStatus.notDetermined) {
      notifyListeners();
      return;
    }

    _permissionPromptShownThisSession = true;
    if (!context.mounted) {
      return;
    }

    final shouldRequest = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enable notifications'),
        content: const Text(
          'MoodGenie can remind you to log your mood, share appointment updates, and keep your therapist workflow current. We keep lock-screen previews generic by default.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    if (shouldRequest == true) {
      await requestPermissionAndRegister();
    }
  }

  Future<void> requestPermissionAndRegister() async {
    if (kIsWeb) {
      return;
    }

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    _permissionStatus = settings.authorizationStatus.name;
    notifyListeners();
    await _syncRegistrationForCurrentUser(force: true);
  }

  Future<NotificationPreferencesModel> fetchPreferences({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _preferencesCache != null) {
      return _preferencesCache!;
    }
    final payload = await _apiClient.getJson('/api/notification-preferences');
    final preferences = NotificationPreferencesModel.fromJson(
      (payload['preferences'] as Map<String, dynamic>?) ??
          const <String, dynamic>{},
    );
    _preferencesCache = preferences;
    return preferences;
  }

  Future<NotificationPreferencesModel> savePreferences(
    NotificationPreferencesModel preferences,
  ) async {
    final payload = await _apiClient.putJson(
      '/api/notification-preferences',
      body: preferences.toJson(),
    );
    final saved = NotificationPreferencesModel.fromJson(
      (payload['preferences'] as Map<String, dynamic>?) ??
          const <String, dynamic>{},
    );
    _preferencesCache = saved;
    return saved;
  }

  Future<NotificationPageResult> loadNotificationPage({
    int limit = 50,
    String? cursor,
    bool preferCache = false,
  }) async {
    final normalizedCursor = cursor?.trim();
    final isFirstPage = normalizedCursor == null || normalizedCursor.isEmpty;
    if (preferCache && isFirstPage && _firstNotificationPageCache != null) {
      return _firstNotificationPageCache!;
    }

    final query = <String>[
      'limit=$limit',
      if (!isFirstPage) 'cursor=${Uri.encodeQueryComponent(normalizedCursor)}',
    ].join('&');
    final payload = await _apiClient.getJson('/api/notifications?$query');
    final page = NotificationPageResult.fromJson(payload);
    if (isFirstPage) {
      _firstNotificationPageCache = page;
    }
    return page;
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _apiClient.postJson('/api/notifications/$notificationId/read');
    final page = _firstNotificationPageCache;
    if (page == null) {
      return;
    }
    final updated = page.notifications
        .map(
          (item) => item.id == notificationId
              ? AppNotificationItem(
                  id: item.id,
                  type: item.type,
                  title: item.title,
                  body: item.body,
                  deepLink: item.deepLink,
                  read: true,
                  createdAt: item.createdAt,
                  sentAt: item.sentAt,
                  readAt: DateTime.now(),
                  metadata: item.metadata,
                )
              : item,
        )
        .toList(growable: false);
    _firstNotificationPageCache = NotificationPageResult(
      notifications: updated,
      nextCursor: page.nextCursor,
    );
  }

  Future<void> markAllNotificationsRead() async {
    await _apiClient.postJson('/api/notifications/read-all');
    final page = _firstNotificationPageCache;
    if (page == null) {
      return;
    }
    _firstNotificationPageCache = NotificationPageResult(
      notifications: page.notifications
          .map(
            (item) => AppNotificationItem(
              id: item.id,
              type: item.type,
              title: item.title,
              body: item.body,
              deepLink: item.deepLink,
              read: true,
              createdAt: item.createdAt,
              sentAt: item.sentAt,
              readAt: DateTime.now(),
              metadata: item.metadata,
            ),
          )
          .toList(growable: false),
      nextCursor: page.nextCursor,
    );
  }

  Future<void> retryRegistration() async {
    await _syncRegistrationForCurrentUser(force: true);
  }

  Stream<int> unreadCountStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream<int>.value(0);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> notificationsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _initializeLocalNotifications() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        handleNotificationDeepLink(response.payload);
      },
    );

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(_wellnessChannel);
      await androidPlugin?.createNotificationChannel(
        _appointmentUpdatesChannel,
      );
      await androidPlugin?.createNotificationChannel(
        _appointmentRemindersChannel,
      );
      await androidPlugin?.createNotificationChannel(_therapistOpsChannel);
    }
  }

  void _bindForegroundMessageHandlers() {
    FirebaseMessaging.onMessage.listen((message) {
      unawaited(_showForegroundNotification(message));
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      handleNotificationDeepLink(_extractDeepLink(message.data));
    });
    _messaging.onTokenRefresh.listen((_) {
      unawaited(_syncRegistrationForCurrentUser(force: true));
    });
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (kIsWeb) {
      return;
    }

    final deepLink = _extractDeepLink(message.data);
    final type = (message.data['type'] as String?) ?? '';
    final notification = message.notification;
    final title =
        notification?.title ??
        (message.data['title'] as String?) ??
        'MoodGenie notification';
    final body =
        notification?.body ??
        (message.data['body'] as String?) ??
        'Open the app to review your latest update.';

    await _localNotifications.show(
      title.hashCode ^ body.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelIdForType(type),
          _channelNameForType(type),
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      ),
      payload: deepLink,
    );
  }

  Future<void> _syncRegistrationForCurrentUser({bool force = false}) async {
    if (kIsWeb) {
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      _lastRegistrationError = null;
      if (_lastRegisteredDeviceId != null) {
        try {
          await _apiClient.deleteJson(
            '/api/notifications/devices/${Uri.encodeComponent(_lastRegisteredDeviceId!)}',
          );
        } catch (_) {}
      }
      _lastRegisteredDeviceId = null;
      notifyListeners();
      return;
    }

    final settings = await _messaging.getNotificationSettings();
    _permissionStatus = settings.authorizationStatus.name;
    notifyListeners();

    if (![
      AuthorizationStatus.authorized,
      AuthorizationStatus.provisional,
    ].contains(settings.authorizationStatus)) {
      _lastRegistrationError = null;
      notifyListeners();
      return;
    }

    final token = await _messaging.getToken();
    if (token == null || token.trim().isEmpty) {
      _lastRegistrationError =
          'Push registration did not return a device token. Please try again.';
      notifyListeners();
      return;
    }

    final deviceId = _deviceIdFromToken(token);
    if (!force && _lastRegisteredDeviceId == deviceId) {
      return;
    }

    final registrationContext = await _loadRegistrationContext(user.uid);
    try {
      await _apiClient.postJson(
        '/api/notifications/devices/register',
        body: {
          'deviceId': deviceId,
          'fcmToken': token,
          'platform': defaultTargetPlatform.name,
          'appVersion': '1.0.0',
          'locale': registrationContext.locale,
          'timezone': registrationContext.timezone,
          'pushPermissionStatus': settings.authorizationStatus.name,
        },
        timeout: const Duration(seconds: 20),
      );
      _lastRegisteredDeviceId = deviceId;
      _lastRegistrationError = null;
      notifyListeners();
    } catch (error) {
      _lastRegistrationError = error.toString();
      notifyListeners();
    }
  }

  String? _extractDeepLink(Map<String, dynamic> data) {
    final value = data['deepLink'];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  String _deviceIdFromToken(String token) {
    return token
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')
        .substring(0, token.length > 100 ? 100 : token.length);
  }

  Future<({String locale, String timezone})> _loadRegistrationContext(
    String uid,
  ) async {
    final fallbackLocale = PlatformDispatcher.instance.locale.languageCode
        .toLowerCase();
    final fallbackTimezone =
        await LocalTimezoneService.currentTimezone() ?? 'UTC';

    try {
      final userRef = _firestore.collection('users').doc(uid);
      final snapshots = await Future.wait([
        userRef.get(),
        userRef.collection('preferences').doc('notifications').get(),
      ]);
      final userData = snapshots[0].data();
      final preferenceData = snapshots[1].data();

      final storedLocale = (preferenceData?['locale'] as String?)
          ?.trim()
          .toLowerCase();
      final storedTimezone =
          (preferenceData?['timezone'] as String?)?.trim().isNotEmpty == true
          ? (preferenceData!['timezone'] as String).trim()
          : (userData?['timezone'] as String?)?.trim();

      return (
        locale: storedLocale != null && storedLocale.isNotEmpty
            ? storedLocale
            : fallbackLocale,
        timezone: storedTimezone != null && storedTimezone.isNotEmpty
            ? storedTimezone
            : fallbackTimezone,
      );
    } catch (_) {
      return (locale: fallbackLocale, timezone: fallbackTimezone);
    }
  }

  String _channelIdForType(String type) {
    if (type == 'new_booking_request') {
      return _therapistOpsChannel.id;
    }
    if (type.startsWith('appointment_reminder')) {
      return _appointmentRemindersChannel.id;
    }
    if (type.startsWith('appointment_')) {
      return _appointmentUpdatesChannel.id;
    }
    return _wellnessChannel.id;
  }

  String _channelNameForType(String type) {
    if (type == 'new_booking_request') {
      return _therapistOpsChannel.name;
    }
    if (type.startsWith('appointment_reminder')) {
      return _appointmentRemindersChannel.name;
    }
    if (type.startsWith('appointment_')) {
      return _appointmentUpdatesChannel.name;
    }
    return _wellnessChannel.name;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
