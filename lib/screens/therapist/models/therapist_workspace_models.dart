import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/session_model.dart';
import '../../../src/auth/models/user_model.dart';

enum TherapistMoodInsightTone {
  uplifting,
  steady,
  watchful,
  privateData,
  neutral,
}

class TherapistPatientSummary {
  const TherapistPatientSummary({
    required this.user,
    required this.hasConsent,
    required this.moodTone,
    required this.relationshipLabel,
    required this.moodSummaryLabel,
    required this.moodSummaryDetail,
    this.lastInteractionAt,
    this.latestStatus,
    this.latestMood,
    this.latestMoodIntensity,
  });

  final AppUser user;
  final bool hasConsent;
  final DateTime? lastInteractionAt;
  final AppointmentStatus? latestStatus;
  final TherapistMoodInsightTone moodTone;
  final String relationshipLabel;
  final String moodSummaryLabel;
  final String moodSummaryDetail;
  final String? latestMood;
  final int? latestMoodIntensity;
}

class TherapistScheduleItem {
  const TherapistScheduleItem({
    required this.session,
    required this.patientName,
    required this.patientEmail,
    this.user,
  });

  final SessionModel session;
  final AppUser? user;
  final String patientName;
  final String patientEmail;

  DateTime get startsAt => session.scheduledAt;
  DateTime? get endsAt => session.scheduledEndAt;
  AppointmentStatus get status => session.status;
  bool get isPending => status == AppointmentStatus.requested;
  bool get isConfirmed => status == AppointmentStatus.confirmed;
  bool get isPast =>
      startsAt.isBefore(DateTime.now()) ||
      status == AppointmentStatus.completed ||
      status == AppointmentStatus.cancelled ||
      status == AppointmentStatus.rejected ||
      status == AppointmentStatus.noShow;
  bool get isToday {
    final now = DateTime.now();
    return startsAt.year == now.year &&
        startsAt.month == now.month &&
        startsAt.day == now.day;
  }
}

class TherapistDayOverview {
  const TherapistDayOverview({
    required this.date,
    required this.totalCount,
    required this.confirmedCount,
    required this.pendingCount,
  });

  final DateTime date;
  final int totalCount;
  final int confirmedCount;
  final int pendingCount;
}

class TherapistDashboardHeader {
  const TherapistDashboardHeader({
    required this.generatedAt,
    required this.upcomingWeek,
    required this.pendingRequests,
    required this.todayConfirmedSessions,
    required this.scheduleItems,
    this.patientCount = 0,
  });

  final DateTime generatedAt;
  final List<TherapistDayOverview> upcomingWeek;
  final List<TherapistScheduleItem> pendingRequests;
  final List<TherapistScheduleItem> todayConfirmedSessions;
  final List<TherapistScheduleItem> scheduleItems;
  final int patientCount;

  int get pendingCount => pendingRequests.length;
  int get todayConfirmedCount => todayConfirmedSessions.length;
}

enum TherapistScheduleView { today, upcoming, past }

enum TherapistScheduleStatusFilter { all, pending, confirmed, completed }

class TherapistPageResult<T> {
  const TherapistPageResult({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<T> items;
  final bool hasMore;
  final QueryDocumentSnapshot<Map<String, dynamic>>? nextCursor;
}

class TherapistUiNotice {
  const TherapistUiNotice({
    required this.message,
    this.title,
    this.isError = true,
    this.icon = Icons.info_outline_rounded,
  });

  final String message;
  final String? title;
  final bool isError;
  final IconData icon;
}
