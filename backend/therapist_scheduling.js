const { DateTime } = require('luxon');

const DEFAULT_SCHEDULE_TIMEZONE = 'Asia/Karachi';
const DEFAULT_SESSION_DURATION_MINUTES = 60;
const DEFAULT_BUFFER_MINUTES = 15;
const SLOT_HORIZON_DAYS = 30;
const MAX_SESSION_DURATION_MINUTES = 180;
const MAX_BUFFER_MINUTES = 60;
const ACTIVE_SLOT_STATUSES = new Set(['pending_request', 'booked']);

function isValidTimezone(timezone) {
  return (
    typeof timezone === 'string' &&
    timezone.trim().length > 0 &&
    DateTime.now().setZone(timezone.trim()).isValid
  );
}

function normalizeTimezone(timezone) {
  return isValidTimezone(timezone)
    ? timezone.trim()
    : DEFAULT_SCHEDULE_TIMEZONE;
}

function clampMinutes(value, fallback, { minimum, maximum, step = 15 }) {
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) {
    return fallback;
  }

  const rounded = Math.round(numeric / step) * step;
  return Math.min(Math.max(rounded, minimum), maximum);
}

function normalizeTimeString(value) {
  if (typeof value !== 'string') {
    return null;
  }

  const match = /^(\d{1,2}):(\d{2})$/.exec(value.trim());
  if (!match) {
    return null;
  }

  const hours = Number(match[1]);
  const minutes = Number(match[2]);
  if (
    !Number.isInteger(hours) ||
    !Number.isInteger(minutes) ||
    hours < 0 ||
    hours > 23 ||
    minutes < 0 ||
    minutes > 59
  ) {
    return null;
  }

  return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
}

function buildDateKeyFromDate(dateLike, timezone = DEFAULT_SCHEDULE_TIMEZONE) {
  const date = asLuxonDate(dateLike, timezone);
  return date ? date.toFormat('yyyy-LL-dd') : null;
}

function asLuxonDate(value, timezone = DEFAULT_SCHEDULE_TIMEZONE) {
  if (value instanceof Date) {
    return DateTime.fromJSDate(value, { zone: timezone });
  }

  if (typeof value?.toDate === 'function') {
    return DateTime.fromJSDate(value.toDate(), { zone: timezone });
  }

  if (typeof value === 'string') {
    if (/^\d{4}-\d{2}-\d{2}$/.test(value.trim())) {
      const parsed = DateTime.fromISO(value.trim(), { zone: timezone });
      return parsed.isValid ? parsed.startOf('day') : null;
    }

    const parsed = DateTime.fromISO(value, { zone: timezone });
    return parsed.isValid ? parsed : null;
  }

  if (typeof value === 'number') {
    const parsed = DateTime.fromMillis(value, { zone: timezone });
    return parsed.isValid ? parsed : null;
  }

  return null;
}

function buildSlotId(dateKey, startTime) {
  const normalizedDateKey = buildDateKeyFromDate(dateKey) || dateKey;
  const normalizedTime = normalizeTimeString(startTime);
  if (!normalizedDateKey || !normalizedTime) {
    return null;
  }
  return `${normalizedDateKey}_${normalizedTime.replace(':', '')}`;
}

function normalizeWeeklyRules(rules = []) {
  const normalized = [];
  const seenWeekdays = new Set();

  for (const rawRule of Array.isArray(rules) ? rules : []) {
    const weekday = Number(rawRule?.weekday);
    if (!Number.isInteger(weekday) || weekday < 1 || weekday > 7) {
      continue;
    }

    if (seenWeekdays.has(weekday)) {
      continue;
    }
    seenWeekdays.add(weekday);

    const enabled = rawRule?.enabled !== false;
    const startTime = normalizeTimeString(rawRule?.startTime);
    const endTime = normalizeTimeString(rawRule?.endTime);

    normalized.push({
      weekday,
      enabled,
      startTime,
      endTime,
    });
  }

  normalized.sort((left, right) => left.weekday - right.weekday);
  return normalized;
}

function normalizeAvailabilityExceptions(exceptions = [], timezone = DEFAULT_SCHEDULE_TIMEZONE) {
  const normalized = [];
  const seenDateKeys = new Set();

  for (const rawException of Array.isArray(exceptions) ? exceptions : []) {
    const dateKey =
      buildDateKeyFromDate(rawException?.dateKey, timezone) ||
      buildDateKeyFromDate(rawException?.date, timezone);
    if (!dateKey || seenDateKeys.has(dateKey)) {
      continue;
    }
    seenDateKeys.add(dateKey);

    normalized.push({
      dateKey,
      blocked: rawException?.blocked !== false,
      note:
        typeof rawException?.note === 'string' && rawException.note.trim().length > 0
          ? rawException.note.trim()
          : null,
      startTime: normalizeTimeString(rawException?.startTime),
      endTime: normalizeTimeString(rawException?.endTime),
    });
  }

  normalized.sort((left, right) => left.dateKey.localeCompare(right.dateKey));
  return normalized;
}

function normalizeScheduleSettings(raw = {}) {
  return {
    timezone: normalizeTimezone(raw.timezone),
    acceptingNewPatients: raw.acceptingNewPatients !== false,
    sessionDurationMinutes: clampMinutes(
      raw.sessionDurationMinutes,
      DEFAULT_SESSION_DURATION_MINUTES,
      {
        minimum: 30,
        maximum: MAX_SESSION_DURATION_MINUTES,
      },
    ),
    bufferMinutes: clampMinutes(raw.bufferMinutes, DEFAULT_BUFFER_MINUTES, {
      minimum: 0,
      maximum: MAX_BUFFER_MINUTES,
    }),
  };
}

function buildRuleByWeekday(rules) {
  const map = new Map();
  for (const rule of normalizeWeeklyRules(rules)) {
    map.set(rule.weekday, rule);
  }
  return map;
}

function buildExceptionMap(exceptions, timezone) {
  const map = new Map();
  for (const exception of normalizeAvailabilityExceptions(exceptions, timezone)) {
    map.set(exception.dateKey, exception);
  }
  return map;
}

function resolveDayWindow({ date, rule, exception, timezone }) {
  if (!rule || rule.enabled === false) {
    return null;
  }

  if (exception?.blocked) {
    return null;
  }

  const startTime = exception?.startTime || rule.startTime;
  const endTime = exception?.endTime || rule.endTime;
  if (!startTime || !endTime) {
    return null;
  }

  const dateKey = date.toFormat('yyyy-LL-dd');
  const startAt = DateTime.fromISO(`${dateKey}T${startTime}`, {
    zone: timezone,
  });
  const endAt = DateTime.fromISO(`${dateKey}T${endTime}`, {
    zone: timezone,
  });

  if (!startAt.isValid || !endAt.isValid || endAt <= startAt) {
    return null;
  }

  return {
    startAt,
    endAt,
  };
}

function normalizeExistingSlot(slot = {}, timezone = DEFAULT_SCHEDULE_TIMEZONE) {
  return {
    slotId: slot.slotId || null,
    status: typeof slot.status === 'string' ? slot.status : 'open',
    appointmentId: slot.appointmentId || null,
    heldUntil: asLuxonDate(slot.heldUntil, timezone),
    startAt: asLuxonDate(slot.startAt, timezone),
    endAt: asLuxonDate(slot.endAt, timezone),
    note: slot.note || null,
    blockedReason: slot.blockedReason || null,
  };
}

function generateSlotsForDateRange({
  timezone = DEFAULT_SCHEDULE_TIMEZONE,
  weeklyRules = [],
  exceptions = [],
  sessionDurationMinutes = DEFAULT_SESSION_DURATION_MINUTES,
  bufferMinutes = DEFAULT_BUFFER_MINUTES,
  startDateKey,
  horizonDays = SLOT_HORIZON_DAYS,
  existingSlots = new Map(),
  now = DateTime.now().setZone(timezone),
}) {
  const startDate =
    asLuxonDate(startDateKey || now.toFormat('yyyy-LL-dd'), timezone)?.startOf(
      'day',
    ) || now.startOf('day');
  const rulesByWeekday = buildRuleByWeekday(weeklyRules);
  const exceptionMap = buildExceptionMap(exceptions, timezone);
  const normalizedExisting = new Map();

  for (const [slotId, slot] of existingSlots.entries()) {
    normalizedExisting.set(slotId, normalizeExistingSlot(slot, timezone));
  }

  const generatedSlots = [];
  for (let offset = 0; offset < horizonDays; offset += 1) {
    const date = startDate.plus({ days: offset });
    const dateKey = date.toFormat('yyyy-LL-dd');
    const window = resolveDayWindow({
      date,
      rule: rulesByWeekday.get(date.weekday),
      exception: exceptionMap.get(dateKey),
      timezone,
    });

    if (!window) {
      continue;
    }

    let cursor = window.startAt;
    const minimumStart = now.plus({ minutes: 5 });
    while (cursor.plus({ minutes: sessionDurationMinutes }) <= window.endAt) {
      if (cursor < minimumStart) {
        cursor = cursor.plus({
          minutes: sessionDurationMinutes + bufferMinutes,
        });
        continue;
      }

      const startTime = cursor.toFormat('HH:mm');
      const slotId = buildSlotId(dateKey, startTime);
      const endAt = cursor.plus({ minutes: sessionDurationMinutes });
      const existingSlot = normalizedExisting.get(slotId);
      const preserveStatus =
        existingSlot && ACTIVE_SLOT_STATUSES.has(existingSlot.status);

      generatedSlots.push({
        slotId,
        dateKey,
        timezone,
        startAt: cursor.toUTC().toJSDate(),
        endAt: endAt.toUTC().toJSDate(),
        startTime,
        endTime: endAt.toFormat('HH:mm'),
        status: preserveStatus ? existingSlot.status : 'open',
        appointmentId: preserveStatus ? existingSlot.appointmentId : null,
        heldUntil: preserveStatus && existingSlot.heldUntil
          ? existingSlot.heldUntil.toUTC().toJSDate()
          : null,
        blockedReason: null,
      });

      cursor = cursor.plus({
        minutes: sessionDurationMinutes + bufferMinutes,
      });
    }
  }

  return generatedSlots;
}

function computeNextAvailableAt(slots = [], now = new Date()) {
  const nowTime = now instanceof Date ? now.getTime() : new Date(now).getTime();
  return slots
    .filter((slot) => slot.status === 'open' && slot.startAt instanceof Date)
    .map((slot) => slot.startAt)
    .filter((slotDate) => slotDate.getTime() >= nowTime)
    .sort((left, right) => left.getTime() - right.getTime())[0] || null;
}

module.exports = {
  ACTIVE_SLOT_STATUSES,
  DEFAULT_BUFFER_MINUTES,
  DEFAULT_SCHEDULE_TIMEZONE,
  DEFAULT_SESSION_DURATION_MINUTES,
  SLOT_HORIZON_DAYS,
  buildDateKeyFromDate,
  buildSlotId,
  computeNextAvailableAt,
  generateSlotsForDateRange,
  isValidTimezone,
  normalizeAvailabilityExceptions,
  normalizeScheduleSettings,
  normalizeTimeString,
  normalizeWeeklyRules,
};
