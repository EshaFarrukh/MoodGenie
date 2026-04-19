const crypto = require('node:crypto');
const { DateTime } = require('luxon');
const {
  computeMoodForecast,
  normalizeTimezone,
} = require('./mood_forecast');

const WELLNESS_NOTIFICATION_TYPES = new Set([
  'mood_daily_reminder',
  'mood_forecast_support',
  'mood_quote',
]);

const APPOINTMENT_NOTIFICATION_TYPES = new Set([
  'appointment_requested',
  'appointment_confirmed',
  'appointment_rejected',
  'appointment_cancelled',
  'appointment_completed',
  'appointment_no_show',
  'appointment_reminder_24h',
  'appointment_reminder_1h',
  'new_booking_request',
]);

const OPEN_AI_INCIDENT_STATUSES = new Set([
  'open',
  'acknowledged',
  'in_progress',
]);

const DEFAULT_REMINDER_TIME = '20:00';
const DEFAULT_QUIET_HOURS_START = '22:00';
const DEFAULT_QUIET_HOURS_END = '08:00';
const DEFAULT_CONFIDENCE_THRESHOLD = 0.68;
const FEATURE_FLAG_CACHE_TTL_MS = 60 * 1000;
const MAX_NOTIFICATION_RETRY_ATTEMPTS = 4;
const RETRY_BACKOFF_MINUTES = [5, 30, 120, 720];

const DEFAULT_NOTIFICATION_FLAGS = {
  predictive_mood_notifications: {
    id: 'predictive_mood_notifications',
    enabled: true,
    rollout: 100,
    audience: 'users',
  },
  ai_generated_notification_copy: {
    id: 'ai_generated_notification_copy',
    enabled: true,
    rollout: 100,
    audience: 'users',
  },
  appointment_emails: {
    id: 'appointment_emails',
    enabled: true,
    rollout: 100,
    audience: 'all',
  },
  therapist_push_ops: {
    id: 'therapist_push_ops',
    enabled: true,
    rollout: 100,
    audience: 'therapists',
  },
};

const LOCALIZED_COPY = {
  en: {
    preview: {
      wellnessTitle: 'MoodGenie check-in',
      wellnessBody: 'You have a new wellness notification.',
      appointmentTitle: 'MoodGenie appointment update',
      appointmentBody: 'You have a new appointment notification.',
    },
    appointmentEmail: {
      greeting: (recipientName) => (recipientName ? `Hi ${recipientName},` : 'Hello,'),
      whenFallback: 'your scheduled time',
      requestSubmittedSubject:
        'MoodGenie: your appointment request was submitted',
      requestSubmittedText: (counterpartName, when) =>
        `Your appointment request with ${counterpartName || 'your therapist'} for ${when} has been submitted and is awaiting review.\n\nOpen MoodGenie to track the latest status.`,
      newRequestSubject: 'MoodGenie: new therapy booking request',
      newRequestText: (when) =>
        `A new therapy booking request has been submitted for ${when}.\n\nOpen MoodGenie to review and respond.`,
      confirmedSubject: 'MoodGenie: appointment confirmed',
      confirmedText: (when) =>
        `Your appointment for ${when} is confirmed.\n\nOpen MoodGenie for session details.`,
      rejectedSubject: 'MoodGenie: appointment update',
      rejectedText: (when, reason) =>
        `Your appointment request for ${when} was declined.${reason ? ` Reason: ${reason}` : ''}\n\nOpen MoodGenie to review and book another slot.`,
      cancelledSubject: 'MoodGenie: appointment cancelled',
      cancelledText: (when, reason) =>
        `Your appointment for ${when} has been cancelled.${reason ? ` Reason: ${reason}` : ''}\n\nOpen MoodGenie for the latest details.`,
      completedSubject: 'MoodGenie: session completed',
      completedText: (when) =>
        `Your session for ${when} has been marked completed.\n\nOpen MoodGenie to review your recent care activity.`,
      noShowSubject: 'MoodGenie: appointment attendance update',
      noShowText: (when, reason) =>
        `Your appointment for ${when} has been marked as no-show.${reason ? ` Note: ${reason}` : ''}\n\nOpen MoodGenie for the latest details.`,
      reminder24hSubject: 'MoodGenie: appointment reminder for tomorrow',
      reminder24hText: (when) =>
        `This is a reminder about your appointment scheduled for ${when}.\n\nOpen MoodGenie to confirm your preparation and session details.`,
      reminder1hSubject: 'MoodGenie: appointment starts soon',
      reminder1hText: (when) =>
        `Your appointment is scheduled for ${when}.\n\nOpen MoodGenie to join when it is time.`,
      genericSubject: 'MoodGenie notification',
      genericText: 'You have a new MoodGenie update.\n\nOpen the app to review it.',
    },
    wellnessFallback: {
      forecastTitle: 'Mood pattern forecast',
      forecastBody: {
        gentle:
          'A gentle heads-up from your recent pattern. Take a few minutes tonight to set yourself up with a calming habit and a check-in tomorrow.',
        uplifting:
          'A supportive nudge for tomorrow. Take a few minutes tonight to set yourself up with a calming habit and a check-in tomorrow.',
        direct:
          'Your pattern suggests tomorrow may feel a bit different. Take a few minutes tonight to set yourself up with a calming habit and a check-in tomorrow.',
      },
      quoteTitle: 'MoodGenie quote for today',
      quoteBody: {
        gentle:
          'Small steps still count. Notice one good thing you can do for yourself today.',
        uplifting:
          'You have made it through hard days before. Today can still hold something kind.',
        direct: 'Pause, breathe, and give yourself credit for showing up today.',
      },
      reminderTitle: 'Mood check-in reminder',
      reminderBody:
        'Take a minute to log your mood today so MoodGenie can support you better.',
    },
    appointmentPush: {
      requestSubmittedTitle: 'Request submitted',
      requestSubmittedBody: (therapistName, when) =>
        `Your request with ${therapistName} for ${when} is pending review.`,
      confirmedTitle: 'Appointment confirmed',
      confirmedBody: (therapistName, when) =>
        `Your appointment with ${therapistName} for ${when} is confirmed.`,
      rejectedTitle: 'Request update',
      rejectedBody: (when, reason) =>
        reason
          ? `Your request for ${when} was declined. ${reason}`
          : `Your request for ${when} was declined.`,
      cancelledTitle: 'Appointment cancelled',
      cancelledBody: (when, reason) =>
        reason
          ? `Your appointment for ${when} was cancelled. ${reason}`
          : `Your appointment for ${when} was cancelled.`,
      completedTitle: 'Session completed',
      completedBody: (therapistName, when) =>
        `Your session with ${therapistName} for ${when} has been completed.`,
      noShowTitle: 'Attendance update',
      noShowBody: (when, reason) =>
        reason
          ? `Your appointment for ${when} was marked as no-show. ${reason}`
          : `Your appointment for ${when} was marked as no-show.`,
      reminder24hTitle: 'Appointment tomorrow',
      reminder24hBody: (therapistName, when) =>
        `Reminder: you have an appointment with ${therapistName} on ${when}.`,
      reminder1hTitle: 'Appointment starts soon',
      reminder1hBody: (therapistName, when) =>
        `Reminder: your appointment with ${therapistName} starts at ${when}.`,
      newBookingTitle: 'New booking request',
      newBookingBody: (userName, when) =>
        `${userName} requested a therapy session for ${when}.`,
      therapistConfirmedTitle: 'Appointment confirmed',
      therapistConfirmedBody: (userName, when) =>
        `The appointment with ${userName} for ${when} is confirmed.`,
      therapistRejectedTitle: 'Request declined',
      therapistRejectedBody: (when) =>
        `The booking request for ${when} has been marked declined.`,
      therapistCancelledTitle: 'Appointment cancelled',
      therapistCancelledBody: (userName, when, reason) =>
        reason
          ? `${userName}'s appointment for ${when} was cancelled. ${reason}`
          : `${userName}'s appointment for ${when} was cancelled.`,
      therapistCompletedTitle: 'Session completed',
      therapistCompletedBody: (userName, when) =>
        `The session with ${userName} for ${when} has been marked completed.`,
      therapistNoShowTitle: 'No-show recorded',
      therapistNoShowBody: (userName, when, reason) =>
        reason
          ? `${userName}'s appointment for ${when} was marked no-show. ${reason}`
          : `${userName}'s appointment for ${when} was marked no-show.`,
      therapistReminder24hTitle: 'Appointment tomorrow',
      therapistReminder24hBody: (userName, when) =>
        `Reminder: you are scheduled with ${userName} on ${when}.`,
      therapistReminder1hTitle: 'Appointment starts soon',
      therapistReminder1hBody: (userName, when) =>
        `Reminder: your session with ${userName} starts at ${when}.`,
    },
  },
  ur: {
    preview: {
      wellnessTitle: 'MoodGenie چیک اِن',
      wellnessBody: 'آپ کے لیے ایک نئی ویلنیس نوٹیفکیشن موجود ہے۔',
      appointmentTitle: 'MoodGenie اپائنٹمنٹ اپڈیٹ',
      appointmentBody: 'آپ کے لیے اپائنٹمنٹ کی نئی اطلاع موجود ہے۔',
    },
    appointmentEmail: {
      greeting: (recipientName) => (recipientName ? `السلام علیکم ${recipientName}،` : 'السلام علیکم،'),
      whenFallback: 'آپ کے مقررہ وقت',
      requestSubmittedSubject: 'MoodGenie: آپ کی اپائنٹمنٹ درخواست جمع ہوگئی',
      requestSubmittedText: (counterpartName, when) =>
        `آپ کی ${counterpartName || 'اپنے تھراپسٹ'} کے ساتھ ${when} کی اپائنٹمنٹ درخواست جمع ہوچکی ہے اور جائزے کے انتظار میں ہے۔\n\nتازہ ترین صورتحال دیکھنے کے لیے MoodGenie کھولیں۔`,
      newRequestSubject: 'MoodGenie: نئی تھراپی بکنگ درخواست',
      newRequestText: (when) =>
        `${when} کے لیے نئی تھراپی بکنگ درخواست موصول ہوئی ہے۔\n\nجائزہ لینے اور جواب دینے کے لیے MoodGenie کھولیں۔`,
      confirmedSubject: 'MoodGenie: اپائنٹمنٹ کنفرم ہوگئی',
      confirmedText: (when) =>
        `آپ کی ${when} کی اپائنٹمنٹ کنفرم ہوگئی ہے۔\n\nسیشن کی تفصیل کے لیے MoodGenie کھولیں۔`,
      rejectedSubject: 'MoodGenie: اپائنٹمنٹ اپڈیٹ',
      rejectedText: (when, reason) =>
        `آپ کی ${when} کی اپائنٹمنٹ درخواست مسترد کردی گئی ہے۔${reason ? ` وجہ: ${reason}` : ''}\n\nتفصیل دیکھنے اور نئی سلاٹ بک کرنے کے لیے MoodGenie کھولیں۔`,
      cancelledSubject: 'MoodGenie: اپائنٹمنٹ منسوخ ہوگئی',
      cancelledText: (when, reason) =>
        `آپ کی ${when} کی اپائنٹمنٹ منسوخ کردی گئی ہے۔${reason ? ` وجہ: ${reason}` : ''}\n\nتازہ ترین تفصیل کے لیے MoodGenie کھولیں۔`,
      completedSubject: 'MoodGenie: سیشن مکمل ہوگیا',
      completedText: (when) =>
        `آپ کا ${when} کا سیشن مکمل مارک کردیا گیا ہے۔\n\nاپنی حالیہ سرگرمی دیکھنے کے لیے MoodGenie کھولیں۔`,
      noShowSubject: 'MoodGenie: حاضری اپڈیٹ',
      noShowText: (when, reason) =>
        `آپ کی ${when} کی اپائنٹمنٹ کو نو شو مارک کردیا گیا ہے۔${reason ? ` نوٹ: ${reason}` : ''}\n\nمزید تفصیل کے لیے MoodGenie کھولیں۔`,
      reminder24hSubject: 'MoodGenie: کل کی اپائنٹمنٹ کی یاد دہانی',
      reminder24hText: (when) =>
        `یہ آپ کی ${when} کی اپائنٹمنٹ کی یاد دہانی ہے۔\n\nتیاری اور سیشن کی تفصیل کے لیے MoodGenie کھولیں۔`,
      reminder1hSubject: 'MoodGenie: اپائنٹمنٹ جلد شروع ہوگی',
      reminder1hText: (when) =>
        `آپ کی اپائنٹمنٹ ${when} پر مقرر ہے۔\n\nوقت ہونے پر شامل ہونے کے لیے MoodGenie کھولیں۔`,
      genericSubject: 'MoodGenie نوٹیفکیشن',
      genericText: 'آپ کے لیے MoodGenie میں نئی اپڈیٹ موجود ہے۔\n\nجائزہ لینے کے لیے ایپ کھولیں۔',
    },
    wellnessFallback: {
      forecastTitle: 'موڈ پیٹرن پیش گوئی',
      forecastBody: {
        gentle:
          'آپ کے حالیہ پیٹرن سے نرم سا اشارہ مل رہا ہے۔ آج رات چند منٹ نکالیں اور کل کے لیے خود کو ایک پُرسکون عادت کے ساتھ تیار کریں۔',
        uplifting:
          'کل کے لیے ایک حوصلہ افزا اشارہ۔ آج رات چند منٹ نکالیں اور کل کے لیے خود کو ایک پُرسکون عادت کے ساتھ تیار کریں۔',
        direct:
          'آپ کے پیٹرن سے لگتا ہے کہ کل کا دن کچھ مختلف محسوس ہوسکتا ہے۔ آج رات چند منٹ نکالیں اور کل کے لیے خود کو ایک پُرسکون عادت کے ساتھ تیار کریں۔',
      },
      quoteTitle: 'آج کے لیے MoodGenie قول',
      quoteBody: {
        gentle:
          'چھوٹے قدم بھی اہم ہوتے ہیں۔ آج اپنے لیے ایک اچھی چیز نوٹ کریں جو آپ کر سکتے ہیں۔',
        uplifting:
          'آپ پہلے بھی مشکل دن گزار چکے ہیں۔ آج بھی اپنے لیے کوئی نرمی ضرور نکالیں۔',
        direct: 'رکیں، سانس لیں، اور خود کو آج حاضر ہونے کا کریڈٹ دیں۔',
      },
      reminderTitle: 'موڈ چیک اِن یاد دہانی',
      reminderBody:
        'آج اپنا موڈ لاگ کرنے کے لیے ایک منٹ نکالیں تاکہ MoodGenie آپ کی بہتر مدد کر سکے۔',
    },
    appointmentPush: {
      requestSubmittedTitle: 'درخواست جمع ہوگئی',
      requestSubmittedBody: (therapistName, when) =>
        `${therapistName} کے ساتھ ${when} کے لیے آپ کی درخواست جائزے کے انتظار میں ہے۔`,
      confirmedTitle: 'اپائنٹمنٹ کنفرم ہوگئی',
      confirmedBody: (therapistName, when) =>
        `${therapistName} کے ساتھ ${when} کی آپ کی اپائنٹمنٹ کنفرم ہوگئی ہے۔`,
      rejectedTitle: 'درخواست اپڈیٹ',
      rejectedBody: (when, reason) =>
        reason
          ? `${when} کی آپ کی درخواست مسترد کردی گئی ہے۔ ${reason}`
          : `${when} کی آپ کی درخواست مسترد کردی گئی ہے۔`,
      cancelledTitle: 'اپائنٹمنٹ منسوخ ہوگئی',
      cancelledBody: (when, reason) =>
        reason
          ? `${when} کی آپ کی اپائنٹمنٹ منسوخ کردی گئی ہے۔ ${reason}`
          : `${when} کی آپ کی اپائنٹمنٹ منسوخ کردی گئی ہے۔`,
      completedTitle: 'سیشن مکمل ہوگیا',
      completedBody: (therapistName, when) =>
        `${therapistName} کے ساتھ ${when} کا آپ کا سیشن مکمل ہوگیا ہے۔`,
      noShowTitle: 'حاضری اپڈیٹ',
      noShowBody: (when, reason) =>
        reason
          ? `${when} کی آپ کی اپائنٹمنٹ کو نو شو مارک کردیا گیا ہے۔ ${reason}`
          : `${when} کی آپ کی اپائنٹمنٹ کو نو شو مارک کردیا گیا ہے۔`,
      reminder24hTitle: 'کل اپائنٹمنٹ ہے',
      reminder24hBody: (therapistName, when) =>
        `یاد دہانی: ${therapistName} کے ساتھ آپ کی اپائنٹمنٹ ${when} پر ہے۔`,
      reminder1hTitle: 'اپائنٹمنٹ جلد شروع ہوگی',
      reminder1hBody: (therapistName, when) =>
        `یاد دہانی: ${therapistName} کے ساتھ آپ کی اپائنٹمنٹ ${when} پر شروع ہوگی۔`,
      newBookingTitle: 'نئی بکنگ درخواست',
      newBookingBody: (userName, when) =>
        `${userName} نے ${when} کے لیے تھراپی سیشن کی درخواست دی ہے۔`,
      therapistConfirmedTitle: 'اپائنٹمنٹ کنفرم ہوگئی',
      therapistConfirmedBody: (userName, when) =>
        `${userName} کے ساتھ ${when} کی اپائنٹمنٹ کنفرم ہوگئی ہے۔`,
      therapistRejectedTitle: 'درخواست مسترد ہوگئی',
      therapistRejectedBody: (when) =>
        `${when} کی بکنگ درخواست مسترد کردی گئی ہے۔`,
      therapistCancelledTitle: 'اپائنٹمنٹ منسوخ ہوگئی',
      therapistCancelledBody: (userName, when, reason) =>
        reason
          ? `${userName} کی ${when} والی اپائنٹمنٹ منسوخ کردی گئی ہے۔ ${reason}`
          : `${userName} کی ${when} والی اپائنٹمنٹ منسوخ کردی گئی ہے۔`,
      therapistCompletedTitle: 'سیشن مکمل ہوگیا',
      therapistCompletedBody: (userName, when) =>
        `${userName} کے ساتھ ${when} کا سیشن مکمل ہوگیا ہے۔`,
      therapistNoShowTitle: 'نو شو ریکارڈ ہوگیا',
      therapistNoShowBody: (userName, when, reason) =>
        reason
          ? `${userName} کی ${when} والی اپائنٹمنٹ کو نو شو مارک کردیا گیا ہے۔ ${reason}`
          : `${userName} کی ${when} والی اپائنٹمنٹ کو نو شو مارک کردیا گیا ہے۔`,
      therapistReminder24hTitle: 'کل اپائنٹمنٹ ہے',
      therapistReminder24hBody: (userName, when) =>
        `یاد دہانی: ${userName} کے ساتھ آپ کا سیشن ${when} پر ہے۔`,
      therapistReminder1hTitle: 'اپائنٹمنٹ جلد شروع ہوگی',
      therapistReminder1hBody: (userName, when) =>
        `یاد دہانی: ${userName} کے ساتھ آپ کا سیشن ${when} پر شروع ہوگا۔`,
    },
  },
};

function defaultNotificationPreferences(role = 'user', timezone = 'UTC') {
  const isTherapist = role === 'therapist';
  return {
    pushEnabled: true,
    emailEnabled: true,
    inAppEnabled: true,
    dailyMoodReminderEnabled: !isTherapist,
    moodForecastEnabled: !isTherapist,
    moodQuotesEnabled: !isTherapist,
    appointmentPushEnabled: true,
    appointmentEmailEnabled: true,
    preferredReminderTime: DEFAULT_REMINDER_TIME,
    quietHoursStart: DEFAULT_QUIET_HOURS_START,
    quietHoursEnd: DEFAULT_QUIET_HOURS_END,
    timezone: normalizeTimezone(timezone),
    lockScreenPreviewMode: 'generic',
    wellnessFrequency: 'standard',
    quoteTone: 'direct',
    predictionStyle: 'explicit',
    locale: 'en',
  };
}

function normalizeBoolean(value, fallback) {
  if (typeof value === 'boolean') {
    return value;
  }
  return fallback;
}

function normalizeTimeOfDay(value, fallback) {
  if (typeof value !== 'string') {
    return fallback;
  }
  const normalized = value.trim();
  if (!/^\d{2}:\d{2}$/.test(normalized)) {
    return fallback;
  }
  const [hour, minute] = normalized.split(':').map((entry) => Number(entry));
  if (
    !Number.isInteger(hour) ||
    !Number.isInteger(minute) ||
    hour < 0 ||
    hour > 23 ||
    minute < 0 ||
    minute > 59
  ) {
    return fallback;
  }
  return normalized;
}

function normalizeChoice(value, allowedValues, fallback) {
  if (typeof value !== 'string') {
    return fallback;
  }
  const normalized = value.trim().toLowerCase();
  return allowedValues.includes(normalized) ? normalized : fallback;
}

function asTrimmedString(value) {
  if (typeof value !== 'string') {
    return null;
  }
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
}

function normalizeLocale(value, fallback = 'en') {
  if (typeof value !== 'string') {
    return fallback;
  }
  const normalized = value.trim().toLowerCase();
  if (normalized.startsWith('ur')) {
    return 'ur';
  }
  if (normalized.startsWith('en')) {
    return 'en';
  }
  return fallback;
}

function localizedCopy(locale) {
  return LOCALIZED_COPY[normalizeLocale(locale)] || LOCALIZED_COPY.en;
}

function normalizedRoleForAudience(role) {
  const normalized = String(role || '').trim().toLowerCase();
  return normalized === 'therapist' ? 'therapists' : 'users';
}

function hashRolloutBucket(value) {
  const hash = crypto.createHash('sha256').update(String(value)).digest();
  return hash.readUInt32BE(0) % 100;
}

function computeNextRetryAt(now, attempts) {
  const delayMinutes =
    RETRY_BACKOFF_MINUTES[Math.min(Math.max(attempts - 1, 0), RETRY_BACKOFF_MINUTES.length - 1)];
  return DateTime.fromJSDate(now).plus({ minutes: delayMinutes }).toJSDate();
}

function isLikelyTransientError(channel, error) {
  const message = String(error || '').trim().toLowerCase();
  if (!message) {
    return false;
  }

  if (channel === 'email') {
    if (
      message.includes('recipient email not available') ||
      message.includes('provider_not_configured') ||
      message.includes('postmark configuration missing')
    ) {
      return false;
    }
  }

  if (channel === 'push') {
    if (
      message.includes('registration-token-not-registered') ||
      message.includes('invalid-registration-token') ||
      message.includes('requested entity was not found') ||
      message.includes('no active push tokens') ||
      message.includes('token not registered')
    ) {
      return false;
    }
  }

  return true;
}

function isPermanentPushError(error) {
  const code = String(error?.code || '').toLowerCase();
  const message = String(error?.message || '').toLowerCase();
  return (
    code.includes('registration-token-not-registered') ||
    code.includes('invalid-registration-token') ||
    code.includes('invalid-argument') ||
    message.includes('token not registered') ||
    message.includes('requested entity was not found') ||
    message.includes('registration-token-not-registered') ||
    message.includes('invalid-registration-token')
  );
}

function normalizeNotificationPreferences(raw = {}, role = 'user') {
  const defaults = defaultNotificationPreferences(role, raw.timezone);
  return {
    pushEnabled: normalizeBoolean(raw.pushEnabled, defaults.pushEnabled),
    emailEnabled: normalizeBoolean(raw.emailEnabled, defaults.emailEnabled),
    inAppEnabled: normalizeBoolean(raw.inAppEnabled, defaults.inAppEnabled),
    dailyMoodReminderEnabled: normalizeBoolean(
      raw.dailyMoodReminderEnabled,
      defaults.dailyMoodReminderEnabled,
    ),
    moodForecastEnabled: normalizeBoolean(
      raw.moodForecastEnabled,
      defaults.moodForecastEnabled,
    ),
    moodQuotesEnabled: normalizeBoolean(
      raw.moodQuotesEnabled,
      defaults.moodQuotesEnabled,
    ),
    appointmentPushEnabled: normalizeBoolean(
      raw.appointmentPushEnabled,
      defaults.appointmentPushEnabled,
    ),
    appointmentEmailEnabled: normalizeBoolean(
      raw.appointmentEmailEnabled,
      defaults.appointmentEmailEnabled,
    ),
    preferredReminderTime: normalizeTimeOfDay(
      raw.preferredReminderTime,
      defaults.preferredReminderTime,
    ),
    quietHoursStart: normalizeTimeOfDay(
      raw.quietHoursStart,
      defaults.quietHoursStart,
    ),
    quietHoursEnd: normalizeTimeOfDay(
      raw.quietHoursEnd,
      defaults.quietHoursEnd,
    ),
    timezone: normalizeTimezone(raw.timezone || defaults.timezone),
    lockScreenPreviewMode: normalizeChoice(
      raw.lockScreenPreviewMode,
      ['generic', 'detailed'],
      defaults.lockScreenPreviewMode,
    ),
    wellnessFrequency: normalizeChoice(
      raw.wellnessFrequency,
      ['low', 'standard', 'high'],
      defaults.wellnessFrequency,
    ),
    quoteTone: normalizeChoice(
      raw.quoteTone,
      ['gentle', 'uplifting', 'direct'],
      defaults.quoteTone,
    ),
    predictionStyle: normalizeChoice(
      raw.predictionStyle,
      ['explicit'],
      defaults.predictionStyle,
    ),
    locale: normalizeLocale(raw.locale, defaults.locale),
  };
}

function buildNotificationId(type, dedupeKey) {
  const raw = `${type}_${dedupeKey || Date.now()}`;
  return raw.replace(/[^a-zA-Z0-9_-]/g, '_').slice(0, 120);
}

function resolveNotificationType(value, notificationId = '') {
  const direct = asTrimmedString(value);
  if (direct) {
    return direct;
  }

  const match = [...ALL_NOTIFICATION_TYPES]
    .sort((left, right) => right.length - left.length)
    .find((type) => notificationId.startsWith(`${type}_`));
  return match || 'unknown';
}

function buildNotificationFailureId(notificationId, channel) {
  return `${String(notificationId)}_${String(channel)}`
    .replace(/[^a-zA-Z0-9_-]/g, '_')
    .slice(0, 140);
}

function encodeNotificationCursor({ createdAt, id }) {
  if (!createdAt || !id) {
    return null;
  }

  return Buffer.from(
    JSON.stringify({
      createdAt,
      id,
    }),
    'utf8',
  ).toString('base64url');
}

function decodeNotificationCursor(cursor) {
  if (typeof cursor !== 'string' || cursor.trim().length === 0) {
    return null;
  }

  try {
    const decoded = JSON.parse(
      Buffer.from(cursor.trim(), 'base64url').toString('utf8'),
    );
    const createdAt = asDate(decoded?.createdAt);
    const id = asTrimmedString(decoded?.id);
    if (!createdAt || !id) {
      return null;
    }
    return { createdAt, id };
  } catch (_) {
    return null;
  }
}

function isAlreadyExistsError(error) {
  return (
    error?.code === 6 ||
    error?.code === 'already-exists' ||
    error?.code === 'already_exists' ||
    /already exists/i.test(String(error?.message || ''))
  );
}

function toIso(dateLike) {
  if (!dateLike) {
    return null;
  }
  if (dateLike instanceof Date) {
    return dateLike.toISOString();
  }
  if (typeof dateLike?.toDate === 'function') {
    return dateLike.toDate().toISOString();
  }
  const parsed = new Date(dateLike);
  return Number.isNaN(parsed.valueOf()) ? null : parsed.toISOString();
}

function asDate(dateLike) {
  if (!dateLike) {
    return null;
  }
  if (dateLike instanceof Date) {
    return dateLike;
  }
  if (typeof dateLike?.toDate === 'function') {
    return dateLike.toDate();
  }
  const parsed = new Date(dateLike);
  return Number.isNaN(parsed.valueOf()) ? null : parsed;
}

function formatTimeRangeLabel(dateLike, timezone, locale = 'en') {
  const timezoneName = normalizeTimezone(timezone);
  const value = asDate(dateLike);
  if (!value) {
    return null;
  }
  return DateTime.fromJSDate(value, { zone: timezoneName })
    .setLocale(normalizeLocale(locale))
    .toFormat('ccc, LLL d • h:mm a');
}

function isWellnessNotificationType(type) {
  return WELLNESS_NOTIFICATION_TYPES.has(type);
}

function isAppointmentNotificationType(type) {
  return APPOINTMENT_NOTIFICATION_TYPES.has(type);
}

function notificationDeepLinkForType(type, metadata = {}) {
  switch (type) {
    case 'mood_daily_reminder':
      return 'moodgenie://mood/log';
    case 'mood_forecast_support':
    case 'mood_quote':
      return 'moodgenie://mood/history';
    case 'new_booking_request':
      return 'moodgenie://therapist/requests';
    default:
      if (metadata.appointmentId) {
        const roleQuery = metadata.recipientRole
          ? `?role=${encodeURIComponent(metadata.recipientRole)}`
          : '';
        return `moodgenie://appointments/${metadata.appointmentId}${roleQuery}`;
      }
      return 'moodgenie://notifications';
  }
}

function buildGenericPreview(type, locale = 'en') {
  const copy = localizedCopy(locale).preview;
  if (isWellnessNotificationType(type)) {
    return {
      previewTitle: copy.wellnessTitle,
      previewBody: copy.wellnessBody,
    };
  }

  return {
    previewTitle: copy.appointmentTitle,
    previewBody: copy.appointmentBody,
  };
}

function appointmentEmailTemplate({
  type,
  appointment,
  recipientName,
  counterpartName,
  reason,
  locale = 'en',
}) {
  const copy = localizedCopy(locale).appointmentEmail;
  const when =
    formatTimeRangeLabel(
      appointment.scheduledAt,
      appointment.timezone || 'UTC',
      locale,
    ) || copy.whenFallback;
  const greeting = copy.greeting(recipientName);

  switch (type) {
    case 'appointment_requested':
      return {
        subject: copy.requestSubmittedSubject,
        text: `${greeting}\n\n${copy.requestSubmittedText(counterpartName, when)}`,
      };
    case 'new_booking_request':
      return {
        subject: copy.newRequestSubject,
        text: `${greeting}\n\n${copy.newRequestText(when)}`,
      };
    case 'appointment_confirmed':
      return {
        subject: copy.confirmedSubject,
        text: `${greeting}\n\n${copy.confirmedText(when)}`,
      };
    case 'appointment_rejected':
      return {
        subject: copy.rejectedSubject,
        text: `${greeting}\n\n${copy.rejectedText(when, reason)}`,
      };
    case 'appointment_cancelled':
      return {
        subject: copy.cancelledSubject,
        text: `${greeting}\n\n${copy.cancelledText(when, reason)}`,
      };
    case 'appointment_completed':
      return {
        subject: copy.completedSubject,
        text: `${greeting}\n\n${copy.completedText(when)}`,
      };
    case 'appointment_no_show':
      return {
        subject: copy.noShowSubject,
        text: `${greeting}\n\n${copy.noShowText(when, reason)}`,
      };
    case 'appointment_reminder_24h':
      return {
        subject: copy.reminder24hSubject,
        text: `${greeting}\n\n${copy.reminder24hText(when)}`,
      };
    case 'appointment_reminder_1h':
      return {
        subject: copy.reminder1hSubject,
        text: `${greeting}\n\n${copy.reminder1hText(when)}`,
      };
    default:
      return {
        subject: copy.genericSubject,
        text: `${greeting}\n\n${copy.genericText}`,
      };
  }
}

function fallbackWellnessCopy({ type, forecast, quoteTone, locale = 'en' }) {
  const copy = localizedCopy(locale).wellnessFallback;
  const tone = quoteTone || 'direct';
  if (type === 'mood_forecast_support' && forecast) {
    return {
      title: copy.forecastTitle,
      body: copy.forecastBody[tone] || copy.forecastBody.direct,
    };
  }

  if (type === 'mood_quote') {
    return {
      title: copy.quoteTitle,
      body: copy.quoteBody[tone] || copy.quoteBody.direct,
    };
  }

  return {
    title: copy.reminderTitle,
    body: copy.reminderBody,
  };
}

function localTimeMatchesPreference(now, preferredTime, timezone) {
  const zone = normalizeTimezone(timezone);
  const local = DateTime.fromJSDate(now, { zone });
  const [hour, minute] = preferredTime.split(':').map((value) => Number(value));
  return local.hour === hour && local.minute >= minute && local.minute < minute + 60;
}

function withinQuietHours(now, preferences) {
  const zone = normalizeTimezone(preferences.timezone);
  const local = DateTime.fromJSDate(now, { zone });
  const [startHour, startMinute] = preferences.quietHoursStart
    .split(':')
    .map((value) => Number(value));
  const [endHour, endMinute] = preferences.quietHoursEnd
    .split(':')
    .map((value) => Number(value));

  const minutes = local.hour * 60 + local.minute;
  const start = startHour * 60 + startMinute;
  const end = endHour * 60 + endMinute;

  if (start === end) {
    return false;
  }

  if (start < end) {
    return minutes >= start && minutes < end;
  }

  return minutes >= start || minutes < end;
}

function shouldSendWellnessToday(preferences, notificationCountToday) {
  if (preferences.wellnessFrequency === 'high') {
    return notificationCountToday < 2;
  }
  return notificationCountToday < 1;
}

function deliveryAllowed(type, channel, preferences) {
  if (channel === 'in_app') {
    return preferences.inAppEnabled;
  }
  if (channel === 'push') {
    if (!preferences.pushEnabled) {
      return false;
    }
    return isAppointmentNotificationType(type)
      ? preferences.appointmentPushEnabled
      : true;
  }
  if (channel === 'email') {
    if (!preferences.emailEnabled) {
      return false;
    }
    return isAppointmentNotificationType(type)
      ? preferences.appointmentEmailEnabled
      : false;
  }
  return false;
}

function mapNotificationDoc(snapshot) {
  const data = snapshot.data() || {};
  return {
    id: snapshot.id,
    type: data.type || null,
    title: data.title || null,
    body: data.body || null,
    previewTitle: data.previewTitle || null,
    previewBody: data.previewBody || null,
    channel: data.channel || 'in_app',
    deepLink: data.deepLink || null,
    status: data.status || 'sent',
    read: data.read === true,
    createdAt: toIso(data.createdAt),
    sentAt: toIso(data.sentAt),
    readAt: toIso(data.readAt),
    metadata: data.metadata || {},
  };
}

function createNotificationServices({
  db,
  admin,
  createHttpError,
  nowTimestamp,
  logInfo = () => {},
  logWarn = () => {},
  logError = () => {},
  fetchImpl = global.fetch,
  aiCopyGenerator = null,
  featureFlagOverride = null,
}) {
  let featureFlagCache = {
    expiresAt: 0,
    flags: DEFAULT_NOTIFICATION_FLAGS,
  };

  async function getUserProfile(uid) {
    const snapshot = await db().collection('users').doc(uid).get();
    if (!snapshot.exists) {
      return null;
    }
    return { id: snapshot.id, ...snapshot.data() };
  }

  async function getNotificationPreferences(uid, roleHint = 'user') {
    const [userDoc, preferencesSnapshot] = await Promise.all([
      getUserProfile(uid),
      db()
        .collection('users')
        .doc(uid)
        .collection('preferences')
        .doc('notifications')
        .get(),
    ]);

    const role =
      typeof userDoc?.role === 'string' ? userDoc.role.toLowerCase() : roleHint;
    const normalized = normalizeNotificationPreferences(
      {
        timezone: userDoc?.timezone,
        locale: userDoc?.locale,
        ...(preferencesSnapshot.data() || {}),
      },
      role,
    );

    if (!preferencesSnapshot.exists) {
      await db()
        .collection('users')
        .doc(uid)
        .collection('preferences')
        .doc('notifications')
        .set(
          {
            ...normalized,
            createdAt: nowTimestamp(),
            updatedAt: nowTimestamp(),
          },
          { merge: true },
        );
    }

    return {
      role,
      userDoc,
      preferences: normalized,
    };
  }

  async function getNotificationFeatureFlags() {
    if (typeof featureFlagOverride === 'function') {
      const provided = await featureFlagOverride();
      return {
        ...DEFAULT_NOTIFICATION_FLAGS,
        ...(provided || {}),
      };
    }

    if (featureFlagCache.expiresAt > Date.now()) {
      return featureFlagCache.flags;
    }

    const snapshot = await db().collection('feature_flags').limit(100).get();
    const merged = { ...DEFAULT_NOTIFICATION_FLAGS };
    for (const doc of snapshot.docs) {
      const data = doc.data() || {};
      merged[doc.id] = {
        id: doc.id,
        description: typeof data.description === 'string' ? data.description : '',
        enabled: data.enabled === true,
        rollout:
          typeof data.rollout === 'number'
            ? Math.max(0, Math.min(100, data.rollout))
            : 100,
        audience:
          typeof data.audience === 'string' && data.audience.trim().length > 0
            ? data.audience.trim().toLowerCase()
            : 'all',
      };
    }

    featureFlagCache = {
      expiresAt: Date.now() + FEATURE_FLAG_CACHE_TTL_MS,
      flags: merged,
    };
    return merged;
  }

  async function isFeatureEnabled(flagId, { userId, role = 'user' } = {}) {
    const flags = await getNotificationFeatureFlags();
    const flag = flags[flagId];
    if (!flag || flag.enabled !== true) {
      return false;
    }

    const audience = String(flag.audience || 'all').trim().toLowerCase();
    const normalizedRole = normalizedRoleForAudience(role);
    if (audience !== 'all' && audience !== normalizedRole) {
      return false;
    }

    const rollout =
      typeof flag.rollout === 'number'
        ? Math.max(0, Math.min(100, flag.rollout))
        : 100;
    if (rollout >= 100 || !userId) {
      return rollout > 0;
    }

    return hashRolloutBucket(`${flagId}:${userId}`) < rollout;
  }

  async function updateNotificationPreferences(uid, patch, roleHint = 'user') {
    const current = await getNotificationPreferences(uid, roleHint);
    const merged = normalizeNotificationPreferences(
      { ...current.preferences, ...patch },
      current.role,
    );

    await db()
      .collection('users')
      .doc(uid)
      .set(
        {
          locale: merged.locale,
          timezone: merged.timezone,
          updatedAt: nowTimestamp(),
        },
        { merge: true },
      );

    await db()
      .collection('users')
      .doc(uid)
      .collection('preferences')
      .doc('notifications')
      .set(
        {
          ...merged,
          updatedAt: nowTimestamp(),
        },
        { merge: true },
      );

    return merged;
  }

  async function registerDevice({
    uid,
    deviceId,
    fcmToken,
    platform,
    appVersion,
    locale,
    timezone,
    pushPermissionStatus,
  }) {
    if (
      typeof deviceId !== 'string' ||
      deviceId.trim().length === 0 ||
      typeof fcmToken !== 'string' ||
      fcmToken.trim().length === 0
    ) {
      throw createHttpError(
        400,
        'validation_error',
        'deviceId and fcmToken are required.',
      );
    }

    const normalizedDeviceId = deviceId.trim();
    const payload = {
      deviceId: normalizedDeviceId,
      fcmToken: fcmToken.trim(),
      platform: typeof platform === 'string' ? platform.trim().slice(0, 40) : 'unknown',
      appVersion:
        typeof appVersion === 'string' ? appVersion.trim().slice(0, 40) : null,
      locale:
        normalizeLocale(locale, 'en'),
      timezone: normalizeTimezone(timezone),
      pushPermissionStatus:
        typeof pushPermissionStatus === 'string'
          ? pushPermissionStatus.trim().slice(0, 30)
          : 'unknown',
      tokenStatus: 'active',
      lastSeenAt: nowTimestamp(),
      updatedAt: nowTimestamp(),
      createdAt: nowTimestamp(),
    };

    await db()
      .collection('users')
      .doc(uid)
      .collection('devices')
      .doc(normalizedDeviceId)
      .set(payload, { merge: true });

    return payload;
  }

  async function unregisterDevice(uid, deviceId) {
    await db()
      .collection('users')
      .doc(uid)
      .collection('devices')
      .doc(deviceId)
      .delete();
  }

  async function listNotifications(uid, options = 50) {
    const limit =
      typeof options === 'number' || typeof options === 'string'
        ? Math.min(Number(options) || 50, 100)
        : Math.min(Number(options?.limit) || 50, 100);
    const cursor = decodeNotificationCursor(options?.cursor);

    let query = db()
      .collection('users')
      .doc(uid)
      .collection('notifications')
      .orderBy('createdAt', 'desc')
      .orderBy('__name__', 'desc');

    if (cursor) {
      query = query.startAfter(cursor.createdAt, cursor.id);
    }

    const snapshot = await query.limit(limit + 1).get();
    const pageDocs = snapshot.docs.slice(0, limit);
    const hasMore = snapshot.docs.length > limit;
    const lastDoc = pageDocs.length > 0 ? pageDocs[pageDocs.length - 1] : null;

    return {
      notifications: pageDocs.map(mapNotificationDoc),
      nextCursor:
        hasMore && lastDoc
          ? encodeNotificationCursor({
              createdAt: toIso(lastDoc.data()?.createdAt),
              id: lastDoc.id,
            })
          : null,
    };
  }

  async function markNotificationRead(uid, notificationId) {
    await db()
      .collection('users')
      .doc(uid)
      .collection('notifications')
      .doc(notificationId)
      .set(
        {
          read: true,
          status: 'read',
          readAt: nowTimestamp(),
          updatedAt: nowTimestamp(),
        },
        { merge: true },
      );
  }

  async function markAllNotificationsRead(uid) {
    let updated = 0;

    while (true) {
      const snapshot = await db()
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('read', '==', false)
        .limit(100)
        .get();

      if (snapshot.empty) {
        return updated;
      }

      const batch = db().batch();
      for (const doc of snapshot.docs) {
        batch.set(
          doc.ref,
          {
            read: true,
            status: 'read',
            readAt: nowTimestamp(),
            updatedAt: nowTimestamp(),
          },
          { merge: true },
        );
      }
      await batch.commit();
      updated += snapshot.size;

      if (snapshot.size < 100) {
        return updated;
      }
    }
  }

  async function countWellnessNotificationsToday(uid, now) {
    const start = DateTime.fromJSDate(now).startOf('day').toJSDate();
    const snapshot = await db()
      .collection('users')
      .doc(uid)
      .collection('notifications')
      .where('createdAt', '>=', start)
      .limit(20)
      .get();

    return snapshot.docs.filter((doc) =>
      isWellnessNotificationType(String(doc.data().type || '')),
    ).length;
  }

  async function writeDeliveryLog({
    userId,
    notificationId,
    type = null,
    channel,
    status,
    provider = null,
    providerMessageId = null,
    error = null,
  }) {
    await db().collection('notification_delivery_logs').add({
      userId,
      notificationId,
      type,
      channel,
      status,
      provider,
      providerMessageId,
      error,
      createdAt: nowTimestamp(),
    });
  }

  async function writeFailure({
    userId,
    notificationId,
    type = null,
    channel,
    error,
    retryable = true,
    attempts = 1,
    nextRetryAt = null,
  }) {
    const failureId = buildNotificationFailureId(notificationId, channel);
    await db()
      .collection('notification_failures')
      .doc(failureId)
      .set({
      userId,
      notificationId,
      type,
      channel,
      error,
      retryable,
      attempts,
      status:
        retryable && attempts < MAX_NOTIFICATION_RETRY_ATTEMPTS
          ? 'pending'
          : 'dead_letter',
      nextRetryAt,
      firstFailedAt: nowTimestamp(),
      createdAt: nowTimestamp(),
      updatedAt: nowTimestamp(),
    }, { merge: true });
  }

  async function createInAppNotification({
    userId,
    type,
    title,
    body,
    deepLink,
    metadata = {},
    dedupeKey,
    locale = 'en',
  }) {
    const notificationId = buildNotificationId(type, dedupeKey);
    const docRef = db()
      .collection('users')
      .doc(userId)
      .collection('notifications')
      .doc(notificationId);
    const existing = await docRef.get();
    if (existing.exists) {
      return {
        notificationId,
        created: false,
        notification: mapNotificationDoc(existing),
      };
    }

    const preview = buildGenericPreview(type, locale);
    await docRef.set({
      type,
      title,
      body,
      previewTitle: preview.previewTitle,
      previewBody: preview.previewBody,
      channel: 'in_app',
      deepLink: deepLink || notificationDeepLinkForType(type, metadata),
      status: 'sent',
      read: false,
      metadata,
      createdAt: nowTimestamp(),
      sentAt: nowTimestamp(),
      updatedAt: nowTimestamp(),
    });

    await writeDeliveryLog({
      userId,
      notificationId,
      type,
      channel: 'in_app',
      status: 'sent',
    });

    return {
      notificationId,
      created: true,
      notification: {
        id: notificationId,
        type,
        title,
        body,
        previewTitle: preview.previewTitle,
        previewBody: preview.previewBody,
        channel: 'in_app',
        deepLink: deepLink || notificationDeepLinkForType(type, metadata),
        status: 'sent',
        read: false,
        metadata,
      },
    };
  }

  async function reserveNotificationJob({
    notificationId,
    userId,
    type,
    title,
    body,
    channels,
    metadata = {},
    dedupeKey = null,
    emailTemplate = null,
  }) {
    if (!notificationId) {
      return { duplicate: false };
    }

    try {
      await db().collection('notification_jobs').doc(notificationId).create({
        userId,
        type,
        title,
        body,
        channels,
        metadata,
        dedupeKey,
        emailTemplate,
        status: 'queued',
        createdAt: nowTimestamp(),
        updatedAt: nowTimestamp(),
      });
      return { duplicate: false };
    } catch (error) {
      if (isAlreadyExistsError(error)) {
        return { duplicate: true };
      }
      throw error;
    }
  }

  async function finalizeNotificationJob({
    notificationId,
    status,
    channelResults = {},
    lastError = null,
  }) {
    if (!notificationId) {
      return;
    }

    await db()
      .collection('notification_jobs')
      .doc(notificationId)
      .set(
        {
          status,
          channelResults,
          lastError,
          completedAt: nowTimestamp(),
          updatedAt: nowTimestamp(),
        },
        { merge: true },
      );
  }

  async function loadActiveDevices(userId) {
    const snapshot = await db()
      .collection('users')
      .doc(userId)
      .collection('devices')
      .limit(20)
      .get();

    return snapshot.docs
      .map((doc) => ({ id: doc.id, ...doc.data() }))
      .filter(
        (device) =>
          typeof device.fcmToken === 'string' &&
          device.fcmToken.trim().length > 0 &&
          device.tokenStatus !== 'disabled',
      );
  }

  async function disableDevice(userId, deviceId, reason) {
    if (!userId || !deviceId) {
      return;
    }

    await db()
      .collection('users')
      .doc(userId)
      .collection('devices')
      .doc(deviceId)
      .set(
        {
          tokenStatus: 'disabled',
          disabledReason: reason,
          updatedAt: nowTimestamp(),
        },
        { merge: true },
      );
  }

  async function sendPushNotification({
    userId,
    notificationId,
    type,
    title,
    body,
    metadata = {},
    preferences,
  }) {
    if (!deliveryAllowed(type, 'push', preferences)) {
      return { sent: false, reason: 'push_disabled' };
    }

    const devices = await loadActiveDevices(userId);
    const addressableDevices = devices
      .filter((device) =>
        ['authorized', 'provisional', 'granted'].includes(
          String(device.pushPermissionStatus || '').toLowerCase(),
        ),
      );
    const tokens = addressableDevices.map((device) => String(device.fcmToken).trim());

    if (tokens.length === 0) {
      await writeDeliveryLog({
        userId,
        notificationId,
        type,
        channel: 'push',
        status: 'skipped',
        provider: 'fcm',
        error: 'No active push tokens.',
      });
      return { sent: false, reason: 'no_tokens' };
    }

    const preview =
      preferences.lockScreenPreviewMode === 'detailed'
        ? { title, body }
        : buildGenericPreview(type, preferences.locale);

    try {
      const response = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: preview.title || preview.previewTitle,
          body: preview.body || preview.previewBody,
        },
        data: {
          type,
          deepLink: notificationDeepLinkForType(type, metadata),
          notificationId,
          ...Object.fromEntries(
            Object.entries(metadata).map(([key, value]) => [key, String(value)]),
          ),
        },
        android: {
          priority: 'high',
          notification: {
            channelId: isWellnessNotificationType(type)
              ? 'wellness_reminders'
              : type.startsWith('appointment_reminder')
              ? 'appointment_reminders'
              : type === 'new_booking_request'
              ? 'therapist_ops'
              : 'appointment_updates',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              contentAvailable: true,
            },
          },
        },
      });

      let successCount = 0;
      for (let index = 0; index < response.responses.length; index += 1) {
        const item = response.responses[index];
        if (item.success) {
          successCount += 1;
          await writeDeliveryLog({
            userId,
            notificationId,
            type,
            channel: 'push',
            status: 'sent',
            provider: 'fcm',
            providerMessageId: item.messageId || null,
          });
        } else {
          const device = addressableDevices[index];
          const errorMessage = item.error?.message || 'Unknown FCM error.';
          if (device && isPermanentPushError(item.error)) {
            await disableDevice(userId, device.id, errorMessage);
          }
          await writeDeliveryLog({
            userId,
            notificationId,
            type,
            channel: 'push',
            status: 'failed',
            provider: 'fcm',
            error: errorMessage,
          });
          await writeFailure({
            userId,
            notificationId,
            type,
            channel: 'push',
            error: errorMessage,
            retryable: isLikelyTransientError('push', errorMessage),
            nextRetryAt: isLikelyTransientError('push', errorMessage)
              ? computeNextRetryAt(new Date(), 1)
              : null,
          });
        }
      }

      return { sent: successCount > 0, successCount };
    } catch (error) {
      await writeDeliveryLog({
        userId,
        notificationId,
        type,
        channel: 'push',
        status: 'failed',
        provider: 'fcm',
        error: error.message,
      });
      await writeFailure({
        userId,
        notificationId,
        type,
        channel: 'push',
        error: error.message,
        retryable: isLikelyTransientError('push', error.message),
        nextRetryAt: isLikelyTransientError('push', error.message)
          ? computeNextRetryAt(new Date(), 1)
          : null,
      });
      return { sent: false, reason: error.message };
    }
  }

  async function sendEmailNotification({
    userId,
    notificationId,
    type,
    subject,
    text,
    preferences,
  }) {
    if (!deliveryAllowed(type, 'email', preferences)) {
      return { sent: false, reason: 'email_disabled' };
    }

    const user = await getUserProfile(userId);
    const recipient = typeof user?.email === 'string' ? user.email.trim() : '';
    const token = process.env.POSTMARK_SERVER_TOKEN || '';
    const fromEmail = process.env.POSTMARK_FROM_EMAIL || '';

    if (!recipient) {
      await writeDeliveryLog({
        userId,
        notificationId,
        type,
        channel: 'email',
        status: 'failed',
        provider: 'postmark',
        error: 'Recipient email not available.',
      });
      return { sent: false, reason: 'missing_recipient' };
    }

    if (!token || !fromEmail) {
      await writeDeliveryLog({
        userId,
        notificationId,
        type,
        channel: 'email',
        status: 'skipped',
        provider: 'postmark',
        error: 'Postmark configuration missing.',
      });
      return { sent: false, reason: 'provider_not_configured' };
    }

    try {
      const response = await fetchImpl('https://api.postmarkapp.com/email', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
          'X-Postmark-Server-Token': token,
        },
        body: JSON.stringify({
          From: fromEmail,
          To: recipient,
          Subject: subject,
          TextBody: text,
          MessageStream: 'outbound',
        }),
      });

      const payload = await response.json().catch(() => ({}));
      if (!response.ok) {
        const errorMessage =
          payload?.Message || `Postmark returned ${response.status}.`;
        await writeDeliveryLog({
          userId,
          notificationId,
          type,
          channel: 'email',
          status: 'failed',
          provider: 'postmark',
          error: errorMessage,
        });
        await writeFailure({
          userId,
          notificationId,
          type,
          channel: 'email',
          error: errorMessage,
          retryable: isLikelyTransientError('email', errorMessage),
          nextRetryAt: isLikelyTransientError('email', errorMessage)
            ? computeNextRetryAt(new Date(), 1)
            : null,
        });
        return { sent: false, reason: errorMessage };
      }

      await writeDeliveryLog({
        userId,
        notificationId,
        type,
        channel: 'email',
        status: 'sent',
        provider: 'postmark',
        providerMessageId: payload?.MessageID || null,
      });
      return { sent: true };
    } catch (error) {
      await writeDeliveryLog({
        userId,
        notificationId,
        type,
        channel: 'email',
        status: 'failed',
        provider: 'postmark',
        error: error.message,
      });
      await writeFailure({
        userId,
        notificationId,
        type,
        channel: 'email',
        error: error.message,
        retryable: isLikelyTransientError('email', error.message),
        nextRetryAt: isLikelyTransientError('email', error.message)
          ? computeNextRetryAt(new Date(), 1)
          : null,
      });
      return { sent: false, reason: error.message };
    }
  }

  async function generateWellnessCopy({ type, forecast, preferences, userDoc }) {
    const locale = preferences.locale || userDoc?.locale || 'en';
    const aiCopyEnabled = await isFeatureEnabled('ai_generated_notification_copy', {
      userId: userDoc?.id || null,
      role: 'user',
    });

    if (typeof aiCopyGenerator !== 'function' || !aiCopyEnabled) {
      return fallbackWellnessCopy({
        type,
        forecast,
        quoteTone: preferences.quoteTone,
        locale,
      });
    }

    try {
      const generated = await aiCopyGenerator({
        type,
        forecast,
        preferences,
        userDoc,
      });
      if (
        generated &&
        typeof generated.title === 'string' &&
        generated.title.trim().length > 0 &&
        typeof generated.body === 'string' &&
        generated.body.trim().length > 0
      ) {
        return {
          title: generated.title.trim().slice(0, 120),
          body: generated.body.trim().slice(0, 240),
        };
      }
    } catch (error) {
      logWarn('AI wellness copy generation failed', {
        uid: userDoc?.id || null,
        type,
        error: error.message,
      });
    }

    return fallbackWellnessCopy({
      type,
      forecast,
      quoteTone: preferences.quoteTone,
      locale,
    });
  }

  async function sendNotification({
    userId,
    type,
    title,
    body,
    metadata = {},
    channels = ['in_app'],
    dedupeKey,
    preferencesOverride = null,
    emailTemplate = null,
  }) {
    const { preferences } =
      preferencesOverride || (await getNotificationPreferences(userId));

    const notificationId = buildNotificationId(type, dedupeKey);
    const reservation = await reserveNotificationJob({
      notificationId,
      userId,
      type,
      title,
      body,
      channels,
      metadata,
      dedupeKey,
      emailTemplate,
    });

    if (reservation.duplicate) {
      return {
        notificationId,
        deduped: true,
        inAppCreated: false,
        push: null,
        email: null,
      };
    }

    const shouldCreateInApp =
      channels.includes('in_app') && deliveryAllowed(type, 'in_app', preferences);

    const created = shouldCreateInApp
      ? await createInAppNotification({
          userId,
          type,
          title,
          body,
          metadata,
          dedupeKey,
          locale: preferences.locale,
        })
      : {
          notificationId,
          created: false,
          notification: null,
        };

    const results = {
      notificationId,
      deduped: false,
      inAppCreated: created.created,
      push: null,
      email: null,
    };

    if (channels.includes('push')) {
      results.push = await sendPushNotification({
        userId,
        notificationId,
        type,
        title,
        body,
        metadata,
        preferences,
      });
    }

    if (channels.includes('email') && emailTemplate) {
      results.email = await sendEmailNotification({
        userId,
        notificationId,
        type,
        subject: emailTemplate.subject,
        text: emailTemplate.text,
        preferences,
      });
    }

    await finalizeNotificationJob({
      notificationId,
      status:
        results.inAppCreated ||
        results.push?.sent ||
        results.email?.sent
          ? 'sent'
          : 'skipped',
      lastError:
        results.push?.reason ||
        results.email?.reason ||
        (results.inAppCreated ? null : 'No enabled delivery channel succeeded.'),
      channelResults: {
        inAppCreated: results.inAppCreated,
        push: results.push,
        email: results.email,
      },
    });

    return results;
  }

  async function hasRecentOpenAiIncident(userId, now) {
    const threshold = DateTime.fromJSDate(now)
      .minus({ days: 3 })
      .toJSDate();
    const snapshot = await db()
      .collection('ai_incidents')
      .where('userId', '==', userId)
      .limit(20)
      .get();

    return snapshot.docs.some((doc) => {
      const data = doc.data() || {};
      const status = String(data.status || '').trim().toLowerCase();
      const createdAt = asDate(data.createdAt);
      return (
        OPEN_AI_INCIDENT_STATUSES.has(status) &&
        createdAt instanceof Date &&
        createdAt.getTime() >= threshold.getTime()
      );
    });
  }

  async function generateMoodForecastForUser(uid, roleHint = 'user', now = new Date()) {
    const { userDoc, preferences, role } = await getNotificationPreferences(uid, roleHint);
    if (role !== 'user') {
      return null;
    }

    const moodSnapshot = await db()
      .collection('moods')
      .where('userId', '==', uid)
      .limit(200)
      .get();

    const forecast = computeMoodForecast(
      moodSnapshot.docs.map((doc) => doc.data()),
      {
        now,
        timezone: preferences.timezone || userDoc?.timezone || 'UTC',
      },
    );

    if (!forecast) {
      return null;
    }

    await db()
      .collection('users')
      .doc(uid)
      .collection('mood_forecasts')
      .doc(forecast.forecastDate)
      .set(
        {
          ...forecast,
          generatedAt: nowTimestamp(),
        },
        { merge: true },
      );

    await db()
      .collection('users')
      .doc(uid)
      .set(
        {
          forecastRefreshNeeded: false,
          forecastGeneratedAt: nowTimestamp(),
          updatedAt: nowTimestamp(),
        },
        { merge: true },
      );

    return { forecast, userDoc, preferences };
  }

  async function runGenerateMoodForecastsJob({ limit = 50, now = new Date() } = {}) {
    const snapshot = await db().collection('users').limit(limit).get();
    let generated = 0;
    let skipped = 0;

    for (const doc of snapshot.docs) {
      const user = doc.data() || {};
      const role = typeof user.role === 'string' ? user.role.toLowerCase() : 'user';
      if (role !== 'user') {
        skipped += 1;
        continue;
      }

      const result = await generateMoodForecastForUser(doc.id, role, now);
      if (result) {
        generated += 1;
      } else {
        skipped += 1;
      }
    }

    return { generated, skipped };
  }

  async function runDailyMoodReminderJob({ limit = 50, now = new Date() } = {}) {
    const snapshot = await db().collection('users').limit(limit).get();
    let sent = 0;
    let skipped = 0;

    for (const doc of snapshot.docs) {
      const user = { id: doc.id, ...doc.data() };
      const role = typeof user.role === 'string' ? user.role.toLowerCase() : 'user';
      if (role !== 'user') {
        skipped += 1;
        continue;
      }

      const { preferences } = await getNotificationPreferences(doc.id, role);
      if (
        !preferences.dailyMoodReminderEnabled &&
        !preferences.moodForecastEnabled &&
        !preferences.moodQuotesEnabled
      ) {
        skipped += 1;
        continue;
      }

      if (!localTimeMatchesPreference(now, preferences.preferredReminderTime, preferences.timezone)) {
        skipped += 1;
        continue;
      }

      if (withinQuietHours(now, preferences)) {
        skipped += 1;
        continue;
      }

      const wellnessCountToday = await countWellnessNotificationsToday(doc.id, now);
      if (!shouldSendWellnessToday(preferences, wellnessCountToday)) {
        skipped += 1;
        continue;
      }

      const moodSnapshot = await db()
        .collection('moods')
        .where('userId', '==', doc.id)
        .limit(200)
        .get();
      const moodDocs = moodSnapshot.docs.map((entry) => entry.data());
      const localNow = DateTime.fromJSDate(now, {
        zone: preferences.timezone,
      });
      const loggedToday = moodDocs.some((entry) => {
        const createdAt = asDate(
          entry.selectedDate || entry.createdAt || entry.timestamp,
        );
        if (!createdAt) {
          return false;
        }
        return DateTime.fromJSDate(createdAt, {
          zone: preferences.timezone,
        }).hasSame(localNow, 'day');
      });

      const recentIncident = await hasRecentOpenAiIncident(doc.id, now);
      const forecast = computeMoodForecast(moodDocs, {
        now,
        timezone: preferences.timezone,
      });
      const predictiveNotificationsEnabled = await isFeatureEnabled(
        'predictive_mood_notifications',
        {
          userId: doc.id,
          role,
        },
      );

      let type = 'mood_daily_reminder';
      if (
        predictiveNotificationsEnabled &&
        preferences.moodForecastEnabled &&
        forecast &&
        forecast.confidence >= DEFAULT_CONFIDENCE_THRESHOLD &&
        !recentIncident
      ) {
        type = 'mood_forecast_support';
      } else if (preferences.moodQuotesEnabled && loggedToday) {
        type = 'mood_quote';
      }

      const copy = await generateWellnessCopy({
        type,
        forecast,
        preferences,
        userDoc: user,
      });

      const dateKey = localNow.toFormat('yyyy-LL-dd');
      await sendNotification({
        userId: doc.id,
        type,
        title: copy.title,
        body: copy.body,
        metadata: {
          dateKey,
          forecastDate: forecast?.forecastDate || null,
          predictedMoodBand: forecast?.predictedMoodBand || null,
          supportNeedLevel: forecast?.supportNeedLevel || null,
        },
        channels: ['in_app', 'push'],
        dedupeKey: dateKey,
      });
      sent += 1;
    }

    return { sent, skipped };
  }

  async function sendAppointmentEventNotifications({
    appointment,
    type,
    reason = null,
    dedupeKey,
  }) {
    const therapistName = appointment.therapistName || 'your therapist';
    const userName = appointment.userName || 'your patient';
    const therapistType = type === 'appointment_requested' ? 'new_booking_request' : type;
    const metadata = {
      appointmentId: appointment.id,
      appointmentStatus: appointment.status,
      scheduledAt: appointment.scheduledAt || null,
      timezone: appointment.timezone || null,
    };

    const results = [];
    if (appointment.userId) {
      const patientContext = await getNotificationPreferences(appointment.userId, 'user');
      const patientLocale = patientContext.preferences.locale;
      const patientCopy = localizedCopy(patientLocale).appointmentPush;
      const patientWhen =
        formatTimeRangeLabel(
          appointment.scheduledAt,
          appointment.timezone,
          patientLocale,
        ) || localizedCopy(patientLocale).appointmentEmail.whenFallback;
      const patientTextByType = {
        appointment_requested: {
          title: patientCopy.requestSubmittedTitle,
          body: patientCopy.requestSubmittedBody(therapistName, patientWhen),
        },
        appointment_confirmed: {
          title: patientCopy.confirmedTitle,
          body: patientCopy.confirmedBody(therapistName, patientWhen),
        },
        appointment_rejected: {
          title: patientCopy.rejectedTitle,
          body: patientCopy.rejectedBody(patientWhen, reason),
        },
        appointment_cancelled: {
          title: patientCopy.cancelledTitle,
          body: patientCopy.cancelledBody(patientWhen, reason),
        },
        appointment_completed: {
          title: patientCopy.completedTitle,
          body: patientCopy.completedBody(therapistName, patientWhen),
        },
        appointment_no_show: {
          title: patientCopy.noShowTitle,
          body: patientCopy.noShowBody(patientWhen, reason),
        },
        appointment_reminder_24h: {
          title: patientCopy.reminder24hTitle,
          body: patientCopy.reminder24hBody(therapistName, patientWhen),
        },
        appointment_reminder_1h: {
          title: patientCopy.reminder1hTitle,
          body: patientCopy.reminder1hBody(therapistName, patientWhen),
        },
      };
      const patientPayload = patientTextByType[type];
      const appointmentEmailsEnabled = await isFeatureEnabled('appointment_emails', {
        userId: appointment.userId,
        role: patientContext.role,
      });
      const patientEmail = appointmentEmailTemplate({
        type,
        appointment,
        recipientName: appointment.userName,
        counterpartName: therapistName,
        reason,
        locale: patientLocale,
      });

      if (patientPayload) {
        results.push(
          sendNotification({
            userId: appointment.userId,
            type,
            title: patientPayload.title,
            body: patientPayload.body,
            metadata: { ...metadata, recipientRole: 'user' },
            channels: [
              'in_app',
              'push',
              ...(appointmentEmailsEnabled ? ['email'] : []),
            ],
            dedupeKey: `${dedupeKey}_user`,
            emailTemplate: appointmentEmailsEnabled ? patientEmail : null,
            preferencesOverride: patientContext,
          }),
        );
      }
    }

    if (appointment.therapistId) {
      const therapistContext = await getNotificationPreferences(
        appointment.therapistId,
        'therapist',
      );
      const therapistLocale = therapistContext.preferences.locale;
      const therapistCopy = localizedCopy(therapistLocale).appointmentPush;
      const therapistWhen =
        formatTimeRangeLabel(
          appointment.scheduledAt,
          appointment.timezone,
          therapistLocale,
        ) || localizedCopy(therapistLocale).appointmentEmail.whenFallback;
      const therapistTextByType = {
        new_booking_request: {
          title: therapistCopy.newBookingTitle,
          body: therapistCopy.newBookingBody(userName, therapistWhen),
        },
        appointment_confirmed: {
          title: therapistCopy.therapistConfirmedTitle,
          body: therapistCopy.therapistConfirmedBody(userName, therapistWhen),
        },
        appointment_rejected: {
          title: therapistCopy.therapistRejectedTitle,
          body: therapistCopy.therapistRejectedBody(therapistWhen),
        },
        appointment_cancelled: {
          title: therapistCopy.therapistCancelledTitle,
          body: therapistCopy.therapistCancelledBody(
            userName,
            therapistWhen,
            reason,
          ),
        },
        appointment_completed: {
          title: therapistCopy.therapistCompletedTitle,
          body: therapistCopy.therapistCompletedBody(userName, therapistWhen),
        },
        appointment_no_show: {
          title: therapistCopy.therapistNoShowTitle,
          body: therapistCopy.therapistNoShowBody(
            userName,
            therapistWhen,
            reason,
          ),
        },
        appointment_reminder_24h: {
          title: therapistCopy.therapistReminder24hTitle,
          body: therapistCopy.therapistReminder24hBody(userName, therapistWhen),
        },
        appointment_reminder_1h: {
          title: therapistCopy.therapistReminder1hTitle,
          body: therapistCopy.therapistReminder1hBody(userName, therapistWhen),
        },
      };
      const therapistPayload = therapistTextByType[therapistType];
      const therapistPushOpsEnabled = await isFeatureEnabled('therapist_push_ops', {
        userId: appointment.therapistId,
        role: therapistContext.role,
      });
      const appointmentEmailsEnabled = await isFeatureEnabled('appointment_emails', {
        userId: appointment.therapistId,
        role: therapistContext.role,
      });
      const therapistEmail = appointmentEmailTemplate({
        type: therapistType,
        appointment,
        recipientName: appointment.therapistName,
        counterpartName: userName,
        reason,
        locale: therapistLocale,
      });

      if (therapistPayload) {
        results.push(
          sendNotification({
            userId: appointment.therapistId,
            type: therapistType,
            title: therapistPayload.title,
            body: therapistPayload.body,
            metadata: { ...metadata, recipientRole: 'therapist' },
            channels: [
              'in_app',
              ...(therapistPushOpsEnabled ? ['push'] : []),
              ...(appointmentEmailsEnabled ? ['email'] : []),
            ],
            dedupeKey: `${dedupeKey}_therapist`,
            emailTemplate: appointmentEmailsEnabled ? therapistEmail : null,
            preferencesOverride: therapistContext,
          }),
        );
      }
    }

    return Promise.all(results);
  }

  async function runAppointmentReminderJob({ now = new Date() } = {}) {
    const snapshot = await db()
      .collection('appointments')
      .where('status', '==', 'confirmed')
      .limit(200)
      .get();

    let sent = 0;
    let skipped = 0;
    for (const doc of snapshot.docs) {
      const appointment = { id: doc.id, ...doc.data() };
      const scheduledAt = asDate(appointment.scheduledAt);
      if (!scheduledAt) {
        skipped += 1;
        continue;
      }

      const diffMs = scheduledAt.getTime() - now.getTime();
      const diffHours = diffMs / (1000 * 60 * 60);

      let type = null;
      if (diffHours > 23 && diffHours <= 24) {
        type = 'appointment_reminder_24h';
      } else if (diffHours > 0 && diffHours <= 1) {
        type = 'appointment_reminder_1h';
      }

      if (!type) {
        skipped += 1;
        continue;
      }

      await sendAppointmentEventNotifications({
        appointment,
        type,
        dedupeKey: `${appointment.id}_${type}`,
      });
      sent += 1;
    }

    return { sent, skipped };
  }

  async function runNotificationRetryJob({ limit = 50, now = new Date() } = {}) {
    const snapshot = await db().collection('notification_failures').limit(limit).get();
    let processed = 0;
    let resolved = 0;
    let rescheduled = 0;
    let deadLetters = 0;
    let skipped = 0;

    for (const doc of snapshot.docs) {
      const failure = doc.data() || {};
      const retryable = failure.retryable !== false;
      const status = String(failure.status || 'pending').trim().toLowerCase();
      const nextRetryAt = asDate(failure.nextRetryAt);
      if (
        !retryable ||
        status === 'dead_letter' ||
        (nextRetryAt instanceof Date && nextRetryAt.getTime() > now.getTime())
      ) {
        skipped += 1;
        continue;
      }

      processed += 1;
      const notificationId = asTrimmedString(failure.notificationId);
      const channel = asTrimmedString(failure.channel);
      const userId = asTrimmedString(failure.userId);
      if (!notificationId || !channel || !userId) {
        await doc.ref.set(
          {
            status: 'dead_letter',
            retryable: false,
            updatedAt: nowTimestamp(),
            lastError: 'Notification failure is missing required retry context.',
          },
          { merge: true },
        );
        deadLetters += 1;
        continue;
      }

      const jobSnapshot = await db()
        .collection('notification_jobs')
        .doc(notificationId)
        .get();
      if (!jobSnapshot.exists) {
        await doc.ref.set(
          {
            status: 'dead_letter',
            retryable: false,
            updatedAt: nowTimestamp(),
            lastError: 'Notification job payload no longer exists.',
          },
          { merge: true },
        );
        deadLetters += 1;
        continue;
      }

      const job = jobSnapshot.data() || {};
      const preferencesContext = await getNotificationPreferences(
        userId,
        asTrimmedString(job.metadata?.recipientRole) || 'user',
      );

      let result = { sent: false, reason: 'unsupported_retry_channel' };
      if (channel === 'push') {
        result = await sendPushNotification({
          userId,
          notificationId,
          type: job.type,
          title: job.title,
          body: job.body,
          metadata: job.metadata || {},
          preferences: preferencesContext.preferences,
        });
      } else if (channel === 'email') {
        if (!job.emailTemplate?.subject || !job.emailTemplate?.text) {
          result = { sent: false, reason: 'missing_email_template' };
        } else {
          result = await sendEmailNotification({
            userId,
            notificationId,
            type: job.type,
            subject: job.emailTemplate.subject,
            text: job.emailTemplate.text,
            preferences: preferencesContext.preferences,
          });
        }
      }

      if (result.sent) {
        await doc.ref.delete();
        await finalizeNotificationJob({
          notificationId,
          status: 'sent',
          channelResults: {
            ...(job.channelResults || {}),
            [channel]: result,
          },
        });
        resolved += 1;
        continue;
      }

      const attempts = Math.max(Number(failure.attempts || 1), 1) + 1;
      const retryableNow =
        attempts < MAX_NOTIFICATION_RETRY_ATTEMPTS &&
        isLikelyTransientError(channel, result.reason);

      if (!retryableNow) {
        await doc.ref.set(
          {
            attempts,
            status: 'dead_letter',
            retryable: false,
            updatedAt: nowTimestamp(),
            lastError: result.reason,
          },
          { merge: true },
        );
        await finalizeNotificationJob({
          notificationId,
          status: 'dead_letter',
          lastError: result.reason,
          channelResults: {
            ...(job.channelResults || {}),
            [channel]: result,
          },
        });
        deadLetters += 1;
        continue;
      }

      await doc.ref.set(
        {
          attempts,
          status: 'pending',
          retryable: true,
          nextRetryAt: computeNextRetryAt(now, attempts),
          updatedAt: nowTimestamp(),
          lastError: result.reason,
        },
        { merge: true },
      );
      await finalizeNotificationJob({
        notificationId,
        status: 'retrying',
        lastError: result.reason,
        channelResults: {
          ...(job.channelResults || {}),
          [channel]: result,
        },
      });
      rescheduled += 1;
    }

    return {
      processed,
      resolved,
      rescheduled,
      deadLetters,
      skipped,
    };
  }

  async function revokeUserNotificationData(uid) {
    const [deviceSnapshot, notificationSnapshot, notificationJobSnapshot] = await Promise.all([
      db().collection('users').doc(uid).collection('devices').get(),
      db().collection('users').doc(uid).collection('notifications').get(),
      db().collection('notification_jobs').where('userId', '==', uid).limit(200).get(),
    ]);

    const batch = db().batch();
    for (const doc of deviceSnapshot.docs) {
      batch.delete(doc.ref);
    }
    for (const doc of notificationSnapshot.docs) {
      batch.delete(doc.ref);
    }
    for (const doc of notificationJobSnapshot.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
  }

  async function summarizeNotificationHealth() {
    const [deliveryLogs, failures, unreadNotifications, notifications, preferenceDocs] =
      await Promise.all([
        db().collection('notification_delivery_logs').limit(500).get(),
        db().collection('notification_failures').limit(500).get(),
        db()
          .collectionGroup('notifications')
          .where('read', '==', false)
          .limit(500)
          .get(),
        db()
          .collectionGroup('notifications')
          .limit(500)
          .get(),
        db()
          .collectionGroup('preferences')
          .where(admin.firestore.FieldPath.documentId(), '==', 'notifications')
          .limit(500)
          .get(),
      ]);

    const deliveryDocs = deliveryLogs.docs.map((doc) => doc.data() || {});
    const sentCount = deliveryDocs.filter((doc) => doc.status === 'sent').length;
    const failedCount = deliveryDocs.filter((doc) => doc.status === 'failed').length;
    const emailFailures = deliveryDocs.filter(
      (doc) => doc.channel === 'email' && doc.status === 'failed',
    ).length;
    const pushFailures = deliveryDocs.filter(
      (doc) => doc.channel === 'push' && doc.status === 'failed',
    ).length;

    const preferenceRows = preferenceDocs.docs.map((doc) => doc.data() || {});
    const pushOptOutUsers = preferenceRows.filter((doc) => doc.pushEnabled === false).length;
    const emailOptOutUsers = preferenceRows.filter((doc) => doc.emailEnabled === false).length;
    const mutedWellnessUsers = preferenceRows.filter(
      (doc) =>
        doc.dailyMoodReminderEnabled === false &&
        doc.moodForecastEnabled === false &&
        doc.moodQuotesEnabled === false,
    ).length;

    const totalNotifications = notifications.size;
    const unreadCount = unreadNotifications.size;
    const failureDocs = failures.docs.map((doc) => doc.data() || {});
    const deadLetterCount = failureDocs.filter((data) => {
      return String(data.status || '').trim().toLowerCase() === 'dead_letter';
    }).length;

    const failingTypes = new Map();
    for (const doc of failureDocs) {
      const type = resolveNotificationType(doc.type, doc.notificationId);
      failingTypes.set(type, (failingTypes.get(type) || 0) + 1);
    }

    const topFailingTypes = [...failingTypes.entries()]
      .sort((left, right) => right[1] - left[1])
      .slice(0, 5)
      .map(([type, count]) => ({ type, count }));

    return {
      sentCount,
      failedCount,
      failureRate:
        sentCount + failedCount > 0
          ? Number((failedCount / (sentCount + failedCount)).toFixed(2))
          : 0,
      emailFailures,
      pushFailures,
      unreadCount,
      unreadRate:
        totalNotifications > 0
          ? Number((unreadCount / totalNotifications).toFixed(2))
          : 0,
      deadLetters: deadLetterCount,
      pushOptOutUsers,
      emailOptOutUsers,
      mutedWellnessUsers,
      totalPreferenceProfiles: preferenceRows.length,
      topFailingTypes,
      totalTrackedNotifications: totalNotifications,
    };
  }

  return {
    buildNotificationId,
    createInAppNotification,
    defaultNotificationPreferences,
    generateMoodForecastForUser,
    getNotificationPreferences,
    listNotifications,
    markAllNotificationsRead,
    markNotificationRead,
    normalizeNotificationPreferences,
    registerDevice,
    revokeUserNotificationData,
    runAppointmentReminderJob,
    runDailyMoodReminderJob,
    runGenerateMoodForecastsJob,
    runNotificationRetryJob,
    sendAppointmentEventNotifications,
    sendNotification,
    summarizeNotificationHealth,
    unregisterDevice,
    updateNotificationPreferences,
  };
}

module.exports = {
  APPOINTMENT_NOTIFICATION_TYPES,
  WELLNESS_NOTIFICATION_TYPES,
  createNotificationServices,
  defaultNotificationPreferences,
  normalizeNotificationPreferences,
};
