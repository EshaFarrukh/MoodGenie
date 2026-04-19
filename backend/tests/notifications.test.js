const test = require('node:test');
const assert = require('node:assert/strict');

const {
  createNotificationServices,
  defaultNotificationPreferences,
  normalizeNotificationPreferences,
} = require('../notifications');
const {
  MIN_FORECAST_LOGS,
  computeMoodForecast,
} = require('../mood_forecast');

function buildMoodEntry({
  mood = 'Good',
  intensity = 7,
  createdAt,
  stressLevel = 4,
  sleepHours = 7,
  hydrationLevel = 6,
  energyLevel = 6,
}) {
  return {
    mood,
    intensity,
    stressLevel,
    sleepHours,
    hydrationLevel,
    energyLevel,
    createdAt,
  };
}

function createFakeFirestore() {
  const docs = new Map();
  let autoId = 0;

  function clone(value) {
    return value == null ? value : JSON.parse(JSON.stringify(value));
  }

  function collectionEntries(path) {
    const prefix = `${path}/`;
    const depth = path.split('/').length + 1;
    return [...docs.entries()]
      .filter(([docPath]) => docPath.startsWith(prefix))
      .filter(([docPath]) => docPath.split('/').length === depth)
      .map(([docPath, data]) => ({
        id: docPath.split('/').pop(),
        path: docPath,
        data,
      }));
  }

  function createSnapshot(path) {
    const value = docs.get(path);
    return {
      id: path.split('/').pop(),
      exists: value !== undefined,
      data: () => clone(value),
      ref: createDocRef(path),
    };
  }

  function createDocRef(path) {
    return {
      id: path.split('/').pop(),
      path,
      async get() {
        return createSnapshot(path);
      },
      async set(data, options = {}) {
        const existing = docs.get(path) || {};
        docs.set(path, options.merge ? { ...existing, ...clone(data) } : clone(data));
      },
      async create(data) {
        if (docs.has(path)) {
          const error = new Error(`Document already exists for ${path}`);
          error.code = 'already-exists';
          throw error;
        }
        docs.set(path, clone(data));
      },
      async delete() {
        docs.delete(path);
      },
      collection(name) {
        return createCollectionRef(`${path}/${name}`);
      },
    };
  }

  function normalizeComparable(value) {
    if (value instanceof Date) {
      return value.getTime();
    }
    if (value && typeof value.toDate === 'function') {
      return value.toDate().getTime();
    }
    return value;
  }

  function resolveEntryField(entry, field) {
    if (field === '__name__') {
      return entry.id;
    }
    return entry.data?.[field];
  }

  function createCollectionRef(path) {
    let limitCount = Number.POSITIVE_INFINITY;
    const filters = [];
    const orderBys = [];
    let startAfterValues = null;

    return {
      path,
      doc(id) {
        return createDocRef(`${path}/${id}`);
      },
      async add(data) {
        autoId += 1;
        const id = `auto_${autoId}`;
        const ref = createDocRef(`${path}/${id}`);
        await ref.set(data);
        return ref;
      },
      limit(count) {
        limitCount = count;
        return this;
      },
      where(field, operator, value) {
        filters.push({ field, operator, value });
        return this;
      },
      orderBy(field, direction = 'asc') {
        orderBys.push({ field, direction });
        return this;
      },
      startAfter(...values) {
        startAfterValues = values;
        return this;
      },
      startAfterDocument(snapshot) {
        startAfterValues = orderBys.map((order) =>
          order.field === '__name__'
            ? snapshot.id
            : snapshot.data()?.[order.field],
        );
        return this;
      },
      async get() {
        let entries = collectionEntries(path).filter((entry) =>
          filters.every((filter) => {
            if (filter.operator === '==') {
              return resolveEntryField(entry, filter.field) === filter.value;
            }
            return true;
          }),
        );

        if (orderBys.length > 0) {
          entries = [...entries].sort((left, right) => {
            for (const order of orderBys) {
              const leftValue = normalizeComparable(
                resolveEntryField(left, order.field),
              );
              const rightValue = normalizeComparable(
                resolveEntryField(right, order.field),
              );
              if (leftValue == rightValue) {
                continue;
              }
              const finalDirection = order.direction === 'desc' ? -1 : 1;
              return leftValue < rightValue ? -1 * finalDirection : 1 * finalDirection;
            }
            return 0;
          });
        }

        if (startAfterValues != null && orderBys.length > 0) {
          entries = entries.filter((entry) => {
            for (let index = 0; index < orderBys.length; index += 1) {
              const order = orderBys[index];
              const entryValue = normalizeComparable(
                resolveEntryField(entry, order.field),
              );
              const cursorValue = normalizeComparable(startAfterValues[index]);
              if (entryValue == cursorValue) {
                continue;
              }
              if (order.direction === 'desc') {
                return entryValue < cursorValue;
              }
              return entryValue > cursorValue;
            }
            return false;
          });
        }

        entries = entries.slice(0, limitCount);
        return {
          size: entries.length,
          empty: entries.length === 0,
          docs: entries.map((entry) => ({
            id: entry.id,
            data: () => clone(entry.data),
            ref: createDocRef(entry.path),
          })),
        };
      },
    };
  }

  function createCollectionGroupRef(collectionName) {
    let limitCount = Number.POSITIVE_INFINITY;
    const filters = [];

    return {
      where(field, operator, value) {
        filters.push({ field, operator, value });
        return this;
      },
      limit(count) {
        limitCount = count;
        return this;
      },
      async get() {
        const entries = [...docs.entries()]
          .filter(([docPath]) => {
            const segments = docPath.split('/');
            return segments.length >= 2 && segments[segments.length - 2] === collectionName;
          })
          .map(([docPath, data]) => ({
            id: docPath.split('/').pop(),
            path: docPath,
            data,
          }))
          .filter((entry) =>
            filters.every((filter) => {
              if (filter.field === '__name__' || filter.field?._methodName === 'documentId') {
                return filter.operator === '==' ? entry.id === filter.value : true;
              }
              if (filter.operator === '==') {
                return entry.data?.[filter.field] === filter.value;
              }
              return true;
            }),
          )
          .slice(0, limitCount);

        return {
          size: entries.length,
          empty: entries.length === 0,
          docs: entries.map((entry) => ({
            id: entry.id,
            data: () => clone(entry.data),
            ref: createDocRef(entry.path),
          })),
        };
      },
    };
  }

  return {
    store: docs,
    factory: () => ({
      collection(name) {
        return createCollectionRef(name);
      },
      collectionGroup(name) {
        return createCollectionGroupRef(name);
      },
      batch() {
        return {
          set(ref, data, options) {
            return ref.set(data, options);
          },
          delete(ref) {
            return ref.delete();
          },
          async commit() {},
        };
      },
    }),
  };
}

test('notification preferences default to patient-safe wellness settings', () => {
  const prefs = defaultNotificationPreferences('user', 'Asia/Karachi');

  assert.equal(prefs.pushEnabled, true);
  assert.equal(prefs.dailyMoodReminderEnabled, true);
  assert.equal(prefs.moodForecastEnabled, true);
  assert.equal(prefs.appointmentEmailEnabled, true);
  assert.equal(prefs.timezone, 'Asia/Karachi');
  assert.equal(prefs.lockScreenPreviewMode, 'generic');
});

test('therapist notification defaults disable wellness nudges', () => {
  const prefs = defaultNotificationPreferences('therapist', 'UTC');

  assert.equal(prefs.dailyMoodReminderEnabled, false);
  assert.equal(prefs.moodForecastEnabled, false);
  assert.equal(prefs.moodQuotesEnabled, false);
  assert.equal(prefs.appointmentPushEnabled, true);
});

test('notification preferences normalization clamps invalid values safely', () => {
  const normalized = normalizeNotificationPreferences(
    {
      pushEnabled: false,
      preferredReminderTime: 'not-a-time',
      quietHoursStart: '24:00',
      quietHoursEnd: '02:00',
      timezone: '',
      lockScreenPreviewMode: 'exposed',
      wellnessFrequency: 'spam',
      quoteTone: 'aggressive',
      predictionStyle: 'magic',
      locale: 'ur-PK',
    },
    'user',
  );

  assert.equal(normalized.pushEnabled, false);
  assert.equal(normalized.preferredReminderTime, '20:00');
  assert.equal(normalized.quietHoursStart, '22:00');
  assert.equal(normalized.quietHoursEnd, '02:00');
  assert.equal(normalized.timezone, 'UTC');
  assert.equal(normalized.lockScreenPreviewMode, 'generic');
  assert.equal(normalized.wellnessFrequency, 'standard');
  assert.equal(normalized.quoteTone, 'direct');
  assert.equal(normalized.predictionStyle, 'explicit');
  assert.equal(normalized.locale, 'ur');
});

test('mood forecast requires a minimum history window before predicting', () => {
  const entries = Array.from({ length: MIN_FORECAST_LOGS - 1 }, (_, index) =>
    buildMoodEntry({
      createdAt: new Date(
        `2026-04-${String(index + 1).padStart(2, '0')}T10:00:00.000Z`,
      ),
    }),
  );

  const forecast = computeMoodForecast(entries, {
    now: new Date('2026-04-13T12:00:00.000Z'),
    timezone: 'UTC',
  });

  assert.equal(forecast, null);
});

test('mood forecast returns explicit structured support output when enough data exists', () => {
  const entries = Array.from({ length: MIN_FORECAST_LOGS + 2 }, (_, index) =>
    buildMoodEntry({
      mood: index < 5 ? 'Low' : 'Okay',
      intensity: index < 5 ? 3 : 6,
      stressLevel: index < 5 ? 8 : 5,
      energyLevel: index < 5 ? 3 : 6,
      createdAt: new Date(
        `2026-04-${String(index + 1).padStart(2, '0')}T10:00:00.000Z`,
      ),
    }),
  );

  const forecast = computeMoodForecast(entries, {
    now: new Date('2026-04-13T12:00:00.000Z'),
    timezone: 'UTC',
  });

  assert.ok(forecast);
  assert.equal(typeof forecast.forecastDate, 'string');
  assert.ok(
    ['very_low', 'low', 'neutral', 'positive', 'very_positive'].includes(
      forecast.predictedMoodBand,
    ),
  );
  assert.ok(forecast.confidence >= 0 && forecast.confidence <= 1);
  assert.ok(['low', 'medium', 'high'].includes(forecast.supportNeedLevel));
  assert.ok(Array.isArray(forecast.reasonCodes));
  assert.ok(forecast.reasonCodes.length > 0);
});

test('sendNotification only writes inbox notifications when the in_app channel is enabled', async () => {
  const fakeFirestore = createFakeFirestore();
  const services = createNotificationServices({
    db: fakeFirestore.factory,
    admin: {},
    createHttpError: (status, code, message) => {
      const error = new Error(message);
      error.status = status;
      error.code = code;
      return error;
    },
    nowTimestamp: () => new Date('2026-04-13T20:00:00.000Z'),
  });

  const preferences = defaultNotificationPreferences('user', 'UTC');
  const result = await services.sendNotification({
    userId: 'user-1',
    type: 'appointment_confirmed',
    title: 'Appointment confirmed',
    body: 'Your appointment is confirmed.',
    channels: ['push'],
    dedupeKey: 'appt_1',
    preferencesOverride: { preferences: { ...preferences, pushEnabled: false } },
  });

  assert.equal(result.inAppCreated, false);
  assert.equal(result.deduped, false);
  assert.equal(
    fakeFirestore.store.has(
      'users/user-1/notifications/appointment_confirmed_appt_1',
    ),
    false,
  );
  assert.equal(
    fakeFirestore.store.has('notification_jobs/appointment_confirmed_appt_1'),
    true,
  );
});

test('sendNotification dedupes repeated delivery attempts even without an inbox write', async () => {
  const fakeFirestore = createFakeFirestore();
  const services = createNotificationServices({
    db: fakeFirestore.factory,
    admin: {},
    createHttpError: (status, code, message) => {
      const error = new Error(message);
      error.status = status;
      error.code = code;
      return error;
    },
    nowTimestamp: () => new Date('2026-04-13T20:00:00.000Z'),
  });

  const preferences = defaultNotificationPreferences('user', 'UTC');
  const first = await services.sendNotification({
    userId: 'user-1',
    type: 'mood_daily_reminder',
    title: 'Check in',
    body: 'Log your mood today.',
    channels: ['push'],
    dedupeKey: '2026-04-13',
    preferencesOverride: { preferences: { ...preferences, pushEnabled: false } },
  });

  const second = await services.sendNotification({
    userId: 'user-1',
    type: 'mood_daily_reminder',
    title: 'Check in',
    body: 'Log your mood today.',
    channels: ['push'],
    dedupeKey: '2026-04-13',
    preferencesOverride: { preferences: { ...preferences, pushEnabled: false } },
  });

  assert.equal(first.deduped, false);
  assert.equal(second.deduped, true);
  assert.equal(second.notificationId, first.notificationId);
});

test('listNotifications returns a paginated response with nextCursor', async () => {
  const fakeFirestore = createFakeFirestore();
  fakeFirestore.store.set('users/user-1/notifications/note-1', {
    title: 'Newest',
    body: 'Newest body',
    type: 'appointment_confirmed',
    read: false,
    createdAt: new Date('2026-04-13T12:00:00.000Z'),
  });
  fakeFirestore.store.set('users/user-1/notifications/note-2', {
    title: 'Older',
    body: 'Older body',
    type: 'appointment_requested',
    read: false,
    createdAt: new Date('2026-04-12T12:00:00.000Z'),
  });
  fakeFirestore.store.set('users/user-1/notifications/note-3', {
    title: 'Oldest',
    body: 'Oldest body',
    type: 'mood_daily_reminder',
    read: true,
    createdAt: new Date('2026-04-11T12:00:00.000Z'),
  });

  const services = createNotificationServices({
    db: fakeFirestore.factory,
    admin: {},
    createHttpError: (status, code, message) => {
      const error = new Error(message);
      error.status = status;
      error.code = code;
      return error;
    },
    nowTimestamp: () => new Date('2026-04-13T20:00:00.000Z'),
  });

  const firstPage = await services.listNotifications('user-1', { limit: 2 });
  assert.equal(firstPage.notifications.length, 2);
  assert.equal(firstPage.notifications[0].id, 'note-1');
  assert.equal(firstPage.notifications[1].id, 'note-2');
  assert.ok(firstPage.nextCursor);

  const secondPage = await services.listNotifications('user-1', {
    limit: 2,
    cursor: firstPage.nextCursor,
  });
  assert.equal(secondPage.notifications.length, 1);
  assert.equal(secondPage.notifications[0].id, 'note-3');
  assert.equal(secondPage.nextCursor, null);
});

test('markAllNotificationsRead processes more than one batch of unread items', async () => {
  const fakeFirestore = createFakeFirestore();
  for (let index = 0; index < 105; index += 1) {
    fakeFirestore.store.set(`users/user-1/notifications/note-${index}`, {
      title: `Notification ${index}`,
      body: 'Unread',
      type: 'appointment_confirmed',
      read: false,
      createdAt: new Date(`2026-04-${String((index % 28) + 1).padStart(2, '0')}T12:00:00.000Z`),
    });
  }

  const services = createNotificationServices({
    db: fakeFirestore.factory,
    admin: {},
    createHttpError: (status, code, message) => {
      const error = new Error(message);
      error.status = status;
      error.code = code;
      return error;
    },
    nowTimestamp: () => new Date('2026-04-13T20:00:00.000Z'),
  });

  const updated = await services.markAllNotificationsRead('user-1');

  assert.equal(updated, 105);
  for (let index = 0; index < 105; index += 1) {
    assert.equal(
      fakeFirestore.store.get(`users/user-1/notifications/note-${index}`)?.read,
      true,
    );
  }
});

test('runNotificationRetryJob retries a queued push failure and clears it on success', async () => {
  const fakeFirestore = createFakeFirestore();
  fakeFirestore.store.set('users/user-1', {
    role: 'user',
    locale: 'en',
    timezone: 'UTC',
  });
  fakeFirestore.store.set('users/user-1/devices/device-1', {
    fcmToken: 'token-1',
    pushPermissionStatus: 'authorized',
    tokenStatus: 'active',
  });
  fakeFirestore.store.set('notification_jobs/appointment_confirmed_appt_1', {
    userId: 'user-1',
    type: 'appointment_confirmed',
    title: 'Appointment confirmed',
    body: 'Your appointment is confirmed.',
    channels: ['push'],
    metadata: { recipientRole: 'user' },
    status: 'retrying',
  });
  fakeFirestore.store.set(
    'notification_failures/appointment_confirmed_appt_1_push',
    {
      userId: 'user-1',
      notificationId: 'appointment_confirmed_appt_1',
      channel: 'push',
      retryable: true,
      attempts: 1,
      status: 'pending',
      nextRetryAt: new Date('2026-04-13T19:00:00.000Z'),
    },
  );

  const services = createNotificationServices({
    db: fakeFirestore.factory,
    admin: {
      messaging: () => ({
        sendEachForMulticast: async () => ({
          responses: [{ success: true, messageId: 'msg-1' }],
        }),
      }),
    },
    createHttpError: (status, code, message) => {
      const error = new Error(message);
      error.status = status;
      error.code = code;
      return error;
    },
    nowTimestamp: () => new Date('2026-04-13T20:00:00.000Z'),
  });

  const result = await services.runNotificationRetryJob({
    now: new Date('2026-04-13T20:00:00.000Z'),
  });

  assert.equal(result.processed, 1);
  assert.equal(result.resolved, 1);
  assert.equal(
    fakeFirestore.store.has(
      'notification_failures/appointment_confirmed_appt_1_push',
    ),
    false,
  );
  assert.equal(
    fakeFirestore.store.get('notification_jobs/appointment_confirmed_appt_1')
      ?.status,
    'sent',
  );
});

test('summarizeNotificationHealth reports delivery, unread, opt-out, and failure-template metrics', async () => {
  const fakeFirestore = createFakeFirestore();
  fakeFirestore.store.set('notification_delivery_logs/log-1', {
    notificationId: 'appointment_confirmed_appt_1',
    type: 'appointment_confirmed',
    channel: 'push',
    status: 'sent',
  });
  fakeFirestore.store.set('notification_delivery_logs/log-2', {
    notificationId: 'mood_quote_2026-04-13',
    type: 'mood_quote',
    channel: 'email',
    status: 'failed',
  });
  fakeFirestore.store.set('notification_failures/mood_quote_2026-04-13_email', {
    notificationId: 'mood_quote_2026-04-13',
    type: 'mood_quote',
    channel: 'email',
    status: 'dead_letter',
  });
  fakeFirestore.store.set('users/user-1/notifications/note-1', {
    type: 'appointment_confirmed',
    read: false,
  });
  fakeFirestore.store.set('users/user-2/notifications/note-2', {
    type: 'mood_quote',
    read: true,
  });
  fakeFirestore.store.set('users/user-1/preferences/notifications', {
    pushEnabled: false,
    emailEnabled: true,
    dailyMoodReminderEnabled: false,
    moodForecastEnabled: false,
    moodQuotesEnabled: false,
  });
  fakeFirestore.store.set('users/user-2/preferences/notifications', {
    pushEnabled: true,
    emailEnabled: false,
    dailyMoodReminderEnabled: true,
    moodForecastEnabled: true,
    moodQuotesEnabled: true,
  });

  const services = createNotificationServices({
    db: fakeFirestore.factory,
    admin: {
      firestore: {
        FieldPath: {
          documentId() {
            return { _methodName: 'documentId' };
          },
        },
      },
    },
    createHttpError: (status, code, message) => {
      const error = new Error(message);
      error.status = status;
      error.code = code;
      return error;
    },
    nowTimestamp: () => new Date('2026-04-13T20:00:00.000Z'),
  });

  const summary = await services.summarizeNotificationHealth();

  assert.equal(summary.sentCount, 1);
  assert.equal(summary.failedCount, 1);
  assert.equal(summary.failureRate, 0.5);
  assert.equal(summary.pushFailures, 0);
  assert.equal(summary.emailFailures, 1);
  assert.equal(summary.unreadCount, 1);
  assert.equal(summary.unreadRate, 0.5);
  assert.equal(summary.deadLetters, 1);
  assert.equal(summary.pushOptOutUsers, 1);
  assert.equal(summary.emailOptOutUsers, 1);
  assert.equal(summary.mutedWellnessUsers, 1);
  assert.deepEqual(summary.topFailingTypes, [{ type: 'mood_quote', count: 1 }]);
});
