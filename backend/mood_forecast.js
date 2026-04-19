const { DateTime } = require('luxon');

const MIN_FORECAST_LOGS = 10;
const FORECAST_WINDOW_DAYS = 14;

const MOOD_SCORE_MAP = {
  terrible: 1,
  bad: 2,
  low: 2,
  okay: 3,
  neutral: 3,
  calm: 4,
  good: 4,
  happy: 4,
  great: 5,
  excited: 5,
};

function normalizeTimezone(timezone) {
  if (typeof timezone !== 'string' || timezone.trim().length === 0) {
    return 'UTC';
  }

  const candidate = timezone.trim();
  return DateTime.now().setZone(candidate).isValid ? candidate : 'UTC';
}

function asDateTime(value, timezone = 'UTC') {
  if (!value) {
    return null;
  }

  if (value instanceof Date) {
    return DateTime.fromJSDate(value, { zone: timezone });
  }

  if (typeof value.toDate === 'function') {
    return DateTime.fromJSDate(value.toDate(), { zone: timezone });
  }

  if (typeof value === 'number') {
    return DateTime.fromMillis(value, { zone: timezone });
  }

  if (typeof value === 'string') {
    const iso = DateTime.fromISO(value, { zone: timezone });
    return iso.isValid ? iso : null;
  }

  return null;
}

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function average(values) {
  if (!Array.isArray(values) || values.length === 0) {
    return 0;
  }
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

function standardDeviation(values) {
  if (!Array.isArray(values) || values.length <= 1) {
    return 0;
  }
  const mean = average(values);
  const variance = average(values.map((value) => (value - mean) ** 2));
  return Math.sqrt(variance);
}

function moodToBaseScore(mood) {
  if (typeof mood !== 'string') {
    return 3;
  }

  const normalized = mood.trim().toLowerCase();
  return MOOD_SCORE_MAP[normalized] || 3;
}

function weightedMoodScore(entry = {}) {
  const moodScore = moodToBaseScore(entry.mood);
  const intensity = clamp(Number(entry.intensity || 5), 1, 10);
  const energy = clamp(Number(entry.energyLevel || 5), 1, 10);
  const stress = clamp(Number(entry.stressLevel || 5), 1, 10);
  const hydration = clamp(Number(entry.waterIntake || 0), 0, 20);
  const sleep = clamp(Number(entry.sleepHours || 0), 0, 12);

  let score = moodScore * 16;
  score += (intensity - 5) * 2.5;
  score += (energy - 5) * 1.8;
  score -= (stress - 5) * 2.2;
  score += Math.min(hydration, 8) * 0.6;
  score += (Math.min(sleep, 9) - 6) * 1.5;

  return clamp(score, 0, 100);
}

function extractMoodTimestamp(entry, timezone) {
  return (
    asDateTime(entry.selectedDate, timezone) ||
    asDateTime(entry.createdAt, timezone) ||
    asDateTime(entry.timestamp, timezone)
  );
}

function normalizeMoodEntries(entries = [], timezone = 'UTC') {
  return entries
    .map((entry) => {
      const at = extractMoodTimestamp(entry, timezone);
      if (!at) {
        return null;
      }
      return {
        ...entry,
        at,
        score: weightedMoodScore(entry),
      };
    })
    .filter(Boolean)
    .sort((left, right) => left.at.toMillis() - right.at.toMillis());
}

function forecastBandFromScore(score) {
  if (score < 25) {
    return 'very_low';
  }
  if (score < 42) {
    return 'low';
  }
  if (score < 60) {
    return 'neutral';
  }
  if (score < 78) {
    return 'positive';
  }
  return 'very_positive';
}

function supportNeedLevelFromScore(score, volatility) {
  if (score < 30 || volatility > 18) {
    return 'high';
  }
  if (score < 50 || volatility > 10) {
    return 'medium';
  }
  return 'low';
}

function buildReasonCodes({
  latestSeven,
  latestThirty,
  todayEntries,
  weekdayEntries,
  missedRecentDays,
}) {
  const reasonCodes = [];
  const lastSevenAverage = average(latestSeven.map((entry) => entry.score));
  const lastThirtyAverage = average(latestThirty.map((entry) => entry.score));
  const weekdayAverage = average(weekdayEntries.map((entry) => entry.score));
  const todayAverage = average(todayEntries.map((entry) => entry.score));

  if (lastSevenAverage < lastThirtyAverage - 10) {
    reasonCodes.push('recent_downtrend');
  } else if (lastSevenAverage > lastThirtyAverage + 10) {
    reasonCodes.push('recent_uptrend');
  }

  if (weekdayEntries.length >= 2) {
    reasonCodes.push('weekday_pattern');
  }

  if (todayEntries.length > 0) {
    reasonCodes.push(todayAverage < 45 ? 'current_mood_low' : 'current_mood_present');
  }

  if (missedRecentDays >= 2) {
    reasonCodes.push('missed_recent_logs');
  }

  const avgStress = average(latestSeven.map((entry) => Number(entry.stressLevel || 5)));
  const avgSleep = average(latestSeven.map((entry) => Number(entry.sleepHours || 0)));
  if (avgStress >= 7) {
    reasonCodes.push('high_stress_pattern');
  }
  if (avgSleep > 0 && avgSleep < 6) {
    reasonCodes.push('low_sleep_pattern');
  }

  return reasonCodes;
}

function computeMoodForecast(entries = [], options = {}) {
  const timezone = normalizeTimezone(options.timezone);
  const now = asDateTime(options.now || new Date(), timezone) || DateTime.now().setZone(timezone);
  const normalized = normalizeMoodEntries(entries, timezone);

  const windowStart = now.minus({ days: FORECAST_WINDOW_DAYS - 1 }).startOf('day');
  const lastFourteen = normalized.filter((entry) => entry.at >= windowStart);
  if (lastFourteen.length < MIN_FORECAST_LOGS) {
    return null;
  }

  const lastSevenStart = now.minus({ days: 6 }).startOf('day');
  const lastThirtyStart = now.minus({ days: 29 }).startOf('day');
  const latestSeven = normalized.filter((entry) => entry.at >= lastSevenStart);
  const latestThirty = normalized.filter((entry) => entry.at >= lastThirtyStart);
  const weekdayEntries = normalized.filter(
    (entry) => entry.at.weekday === now.plus({ days: 1 }).weekday,
  );
  const todayEntries = normalized.filter((entry) => entry.at.hasSame(now, 'day'));

  const sevenAverage = average(latestSeven.map((entry) => entry.score));
  const thirtyAverage = average(latestThirty.map((entry) => entry.score));
  const weekdayAverage =
    weekdayEntries.length >= 2 ? average(weekdayEntries.map((entry) => entry.score)) : thirtyAverage;
  const todayAverage =
    todayEntries.length > 0 ? average(todayEntries.map((entry) => entry.score)) : sevenAverage;

  const recentVolatility = standardDeviation(latestSeven.map((entry) => entry.score));
  const missedRecentDays = Math.max(
    0,
    7 -
      new Set(
        latestSeven.map((entry) => entry.at.toFormat('yyyy-LL-dd')),
      ).size,
  );

  let predictedScore =
    sevenAverage * 0.45 +
    thirtyAverage * 0.25 +
    weekdayAverage * 0.15 +
    todayAverage * 0.15;

  if (missedRecentDays >= 3) {
    predictedScore -= 4;
  }

  predictedScore = clamp(predictedScore, 0, 100);

  const confidence =
    clamp(
      0.45 +
        Math.min(lastFourteen.length, 20) / 40 +
        Math.max(0, 14 - recentVolatility) / 40 -
        missedRecentDays / 20,
      0,
      0.98,
    );

  return {
    forecastDate: now.plus({ days: 1 }).startOf('day').toISODate(),
    predictedMoodBand: forecastBandFromScore(predictedScore),
    confidence: Number(confidence.toFixed(2)),
    supportNeedLevel: supportNeedLevelFromScore(predictedScore, recentVolatility),
    sourceWindow: {
      last14MoodLogs: lastFourteen.length,
      last7MoodLogs: latestSeven.length,
      last30MoodLogs: latestThirty.length,
      timezone,
    },
    reasonCodes: buildReasonCodes({
      latestSeven,
      latestThirty,
      todayEntries,
      weekdayEntries,
      missedRecentDays,
    }),
  };
}

module.exports = {
  MIN_FORECAST_LOGS,
  FORECAST_WINDOW_DAYS,
  computeMoodForecast,
  forecastBandFromScore,
  normalizeMoodEntries,
  normalizeTimezone,
  weightedMoodScore,
};
