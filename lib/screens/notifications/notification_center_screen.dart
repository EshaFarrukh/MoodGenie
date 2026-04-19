import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../src/navigation/app_navigator.dart';
import '../../src/notifications/app_notification_service.dart';
import '../../src/notifications/notification_models.dart';
import '../../src/theme/app_background.dart';
import '../../src/theme/app_theme.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final List<AppNotificationItem> _notifications = <AppNotificationItem>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _markingAllRead = false;
  String? _error;
  String? _loadMoreError;
  String? _nextCursor;

  @override
  void initState() {
    super.initState();
    final cached = context
        .read<AppNotificationService>()
        .cachedFirstNotificationPage;
    if (cached != null) {
      _notifications.addAll(cached.notifications);
      _nextCursor = cached.nextCursor;
      _loading = false;
      unawaited(_loadInitialPage(showSpinner: false, preferCache: false));
    } else {
      _loadInitialPage();
    }
  }

  Color _statusColor(String type) {
    if (type.startsWith('appointment_') || type == 'new_booking_request') {
      return const Color(0xFF1D4ED8);
    }
    return AppColors.primaryDeep;
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'mood_forecast_support':
        return Icons.insights_rounded;
      case 'mood_quote':
        return Icons.format_quote_rounded;
      case 'mood_daily_reminder':
        return Icons.mood_rounded;
      case 'new_booking_request':
        return Icons.assignment_rounded;
      case 'appointment_reminder_24h':
      case 'appointment_reminder_1h':
        return Icons.alarm_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  String _formatTimestamp(DateTime? value) {
    if (value == null) {
      return 'Just now';
    }
    return DateFormat('MMM d • h:mm a').format(value);
  }

  Future<void> _loadInitialPage({
    bool showSpinner = true,
    bool preferCache = true,
  }) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
        _loadMoreError = null;
      });
    } else {
      setState(() {
        _error = null;
        _loadMoreError = null;
      });
    }

    try {
      final result = await context
          .read<AppNotificationService>()
          .loadNotificationPage(preferCache: preferCache);
      if (!mounted) {
        return;
      }
      setState(() {
        _notifications
          ..clear()
          ..addAll(result.notifications);
        _nextCursor = result.nextCursor;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        if (_notifications.isEmpty) {
          _error = error.toString();
        }
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _nextCursor == null) {
      return;
    }

    setState(() {
      _loadingMore = true;
      _loadMoreError = null;
    });

    try {
      final result = await context
          .read<AppNotificationService>()
          .loadNotificationPage(cursor: _nextCursor);
      if (!mounted) {
        return;
      }
      setState(() {
        _notifications.addAll(result.notifications);
        _nextCursor = result.nextCursor;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingMore = false;
        _loadMoreError = error.toString();
      });
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAllRead) {
      return;
    }

    setState(() => _markingAllRead = true);
    try {
      await context.read<AppNotificationService>().markAllNotificationsRead();
      if (!mounted) {
        return;
      }
      setState(() {
        _notifications.replaceRange(
          0,
          _notifications.length,
          _notifications
              .map(
                (notification) => AppNotificationItem(
                  id: notification.id,
                  type: notification.type,
                  title: notification.title,
                  body: notification.body,
                  deepLink: notification.deepLink,
                  read: true,
                  createdAt: notification.createdAt,
                  sentAt: notification.sentAt,
                  readAt: DateTime.now(),
                  metadata: notification.metadata,
                ),
              )
              .toList(growable: false),
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _markingAllRead = false);
      }
    }
  }

  Future<void> _openNotification(AppNotificationItem notification) async {
    final service = context.read<AppNotificationService>();
    try {
      if (!notification.read) {
        await service.markNotificationRead(notification.id);
        if (!mounted) {
          return;
        }
        final index = _notifications.indexWhere(
          (item) => item.id == notification.id,
        );
        if (index >= 0) {
          setState(() {
            _notifications[index] = AppNotificationItem(
              id: notification.id,
              type: notification.type,
              title: notification.title,
              body: notification.body,
              deepLink: notification.deepLink,
              read: true,
              createdAt: notification.createdAt,
              sentAt: notification.sentAt,
              readAt: DateTime.now(),
              metadata: notification.metadata,
            );
          });
        }
      }
      handleNotificationDeepLink(notification.deepLink);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Widget _buildFooter() {
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(
              _loadMoreError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _loadMore,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry older notifications'),
            ),
          ],
        ),
      );
    }

    if (_nextCursor != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: OutlinedButton.icon(
            onPressed: _loadMore,
            icon: const Icon(Icons.history_rounded),
            label: const Text('Load older notifications'),
          ),
        ),
      );
    }

    return const SizedBox(height: 8);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppColors.headingDark,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _markingAllRead ? null : _markAllRead,
                        child: Text(
                          _markingAllRead ? 'Marking...' : 'Mark all read',
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                OutlinedButton.icon(
                                  onPressed: _loadInitialPage,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Retry inbox'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _notifications.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Your inbox is clear right now. Mood reminders and appointment updates will appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: _notifications.length + 1,
                          separatorBuilder: (_, index) =>
                              index == _notifications.length - 1
                              ? const SizedBox(height: 0)
                              : const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (index == _notifications.length) {
                              return _buildFooter();
                            }

                            final notification = _notifications[index];
                            final accent = _statusColor(notification.type);

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(
                                  alpha: notification.read ? 0.90 : 0.97,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: accent.withValues(
                                    alpha: notification.read ? 0.08 : 0.18,
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.08),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => _openNotification(notification),
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 46,
                                        height: 46,
                                        decoration: BoxDecoration(
                                          color: accent.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: Icon(
                                          _iconForType(notification.type),
                                          color: accent,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    notification.title,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color:
                                                          AppColors.headingDark,
                                                    ),
                                                  ),
                                                ),
                                                if (!notification.read)
                                                  Container(
                                                    width: 10,
                                                    height: 10,
                                                    decoration: BoxDecoration(
                                                      color: accent,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              notification.body,
                                              style: const TextStyle(
                                                color: AppColors.textSecondary,
                                                height: 1.4,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              _formatTimestamp(
                                                notification.createdAt ??
                                                    notification.sentAt,
                                              ),
                                              style: TextStyle(
                                                color: accent,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
