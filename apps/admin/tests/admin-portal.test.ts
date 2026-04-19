import test from 'node:test';
import assert from 'node:assert/strict';
import {
  buildNotificationDeliverySeries,
  buildRiskFlagBreakdown,
  buildSessionStatusCounts,
} from '../lib/admin-portal.ts';
import type {
  AppointmentRow,
  IncidentRow,
  NotificationHealthSummary,
} from '../lib/types.ts';

test('session status counts aggregate each appointment bucket', () => {
  const appointments: AppointmentRow[] = [
    {
      id: 'a1',
      userId: 'u1',
      therapistId: 't1',
      status: 'requested',
      scheduledAt: null,
      updatedAt: null,
      meetingRoomId: null,
      userName: null,
      therapistName: null,
    },
    {
      id: 'a2',
      userId: 'u2',
      therapistId: 't2',
      status: 'confirmed',
      scheduledAt: null,
      updatedAt: null,
      meetingRoomId: null,
      userName: null,
      therapistName: null,
    },
    {
      id: 'a3',
      userId: 'u3',
      therapistId: 't3',
      status: 'completed',
      scheduledAt: null,
      updatedAt: null,
      meetingRoomId: null,
      userName: null,
      therapistName: null,
    },
    {
      id: 'a4',
      userId: 'u4',
      therapistId: 't4',
      status: 'cancelled',
      scheduledAt: null,
      updatedAt: null,
      meetingRoomId: null,
      userName: null,
      therapistName: null,
    },
    {
      id: 'a5',
      userId: 'u5',
      therapistId: 't5',
      status: 'no_show',
      scheduledAt: null,
      updatedAt: null,
      meetingRoomId: null,
      userName: null,
      therapistName: null,
    },
    {
      id: 'a6',
      userId: 'u6',
      therapistId: 't6',
      status: 'confirmed',
      scheduledAt: null,
      updatedAt: null,
      meetingRoomId: null,
      userName: null,
      therapistName: null,
    },
  ];

  assert.deepEqual(buildSessionStatusCounts(appointments), {
    requested: 1,
    confirmed: 2,
    completed: 1,
    cancelled: 1,
    rejected: 0,
    noShow: 1,
  });
});

test('risk flag breakdown returns fallback buckets when incidents are empty', () => {
  assert.deepEqual(buildRiskFlagBreakdown([]), [
    { name: 'Crisis', value: 2, fill: '#EF4444' },
    { name: 'Unsafe AI', value: 4, fill: '#00B4D8' },
    { name: 'Complaints', value: 3, fill: '#0066CC' },
  ]);
});

test('risk flag breakdown classifies crisis, complaint, and unsafe incidents', () => {
  const incidents: IncidentRow[] = [
    {
      id: 'i1',
      severity: 'high',
      status: 'open',
      title: 'Urgent escalation',
      category: 'crisis_language',
      source: 'chat',
      userId: 'u1',
      assignedTo: null,
      updatedAt: null,
      createdAt: null,
    },
    {
      id: 'i2',
      severity: 'medium',
      status: 'open',
      title: 'Unsafe output',
      category: 'unsafe_ai_response',
      source: 'chat',
      userId: 'u2',
      assignedTo: null,
      updatedAt: null,
      createdAt: null,
    },
    {
      id: 'i3',
      severity: 'medium',
      status: 'open',
      title: 'User complaint',
      category: 'user_complaint',
      source: 'support',
      userId: 'u3',
      assignedTo: null,
      updatedAt: null,
      createdAt: null,
    },
  ];

  assert.deepEqual(buildRiskFlagBreakdown(incidents), [
    { name: 'Crisis', value: 1, fill: '#EF4444' },
    { name: 'Unsafe AI', value: 1, fill: '#00B4D8' },
    { name: 'Complaints', value: 1, fill: '#0066CC' },
  ]);
});

test('notification delivery series never renders zero-value chart slices', () => {
  const summary: NotificationHealthSummary = {
    sentCount: 0,
    failedCount: 0,
    failureRate: 0,
    emailFailures: 0,
    pushFailures: 0,
    unreadCount: 0,
    unreadRate: 0,
    deadLetters: 0,
    pushOptOutUsers: 0,
    emailOptOutUsers: 0,
    mutedWellnessUsers: 0,
    totalPreferenceProfiles: 0,
    totalTrackedNotifications: 0,
    topFailingTypes: [],
  };

  assert.deepEqual(buildNotificationDeliverySeries(summary), [
    { name: 'Delivered', value: 1, fill: '#0066CC' },
    { name: 'Failed', value: 1, fill: '#EF4444' },
    { name: 'Unread', value: 1, fill: '#00B4D8' },
  ]);
});
