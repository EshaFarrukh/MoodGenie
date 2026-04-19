require('dotenv').config();

const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');
const { createNotificationServices } = require('./notifications');
const {
  ACTIVE_SLOT_STATUSES,
  DEFAULT_BUFFER_MINUTES,
  DEFAULT_SCHEDULE_TIMEZONE,
  DEFAULT_SESSION_DURATION_MINUTES,
  SLOT_HORIZON_DAYS,
  buildDateKeyFromDate,
  buildSlotId,
  computeNextAvailableAt,
  generateSlotsForDateRange,
  normalizeAvailabilityExceptions,
  normalizeScheduleSettings,
  normalizeWeeklyRules,
} = require('./therapist_scheduling');

const app = express();
const port = Number(process.env.PORT || 3000);
const IS_PRODUCTION = process.env.NODE_ENV === 'production';

const OLLAMA_URL = process.env.OLLAMA_URL || 'http://127.0.0.1:11434';
const OLLAMA_MODEL = process.env.OLLAMA_MODEL || 'moodgenie';
const OLLAMA_CHAT_TIMEOUT_MS = Number(
  process.env.OLLAMA_CHAT_TIMEOUT_MS || 60 * 1000,
);
const OLLAMA_NUM_PREDICT = Number(process.env.OLLAMA_NUM_PREDICT || 256);
const OLLAMA_TEMPERATURE = Number(process.env.OLLAMA_TEMPERATURE || 0.25);
const OLLAMA_REPEAT_PENALTY = Number(
  process.env.OLLAMA_REPEAT_PENALTY || 1.1,
);
const TURN_URLS = (process.env.TURN_URLS || '')
  .split(',')
  .map((value) => value.trim())
  .filter(Boolean);
const TURN_USERNAME = process.env.TURN_USERNAME || '';
const TURN_CREDENTIAL = process.env.TURN_CREDENTIAL || '';
const ALLOW_UNAUTHENTICATED_LOCAL =
  process.env.ALLOW_UNAUTHENTICATED_LOCAL === 'true';
const MAX_HISTORY_MESSAGES = Number(process.env.MAX_HISTORY_MESSAGES || 12);
const MAX_MESSAGE_LENGTH = Number(process.env.MAX_MESSAGE_LENGTH || 2000);
const RATE_LIMIT_WINDOW_MS = Number(
  process.env.RATE_LIMIT_WINDOW_MS || 5 * 60 * 1000,
);
const RATE_LIMIT_MAX_REQUESTS = Number(
  process.env.RATE_LIMIT_MAX_REQUESTS || 30,
);
const BOOTSTRAP_ADMIN_UIDS = (process.env.BOOTSTRAP_ADMIN_UIDS || '')
  .split(',')
  .map((value) => value.trim())
  .filter(Boolean);
const ENABLE_ADMIN_BOOTSTRAP =
  process.env.ENABLE_ADMIN_BOOTSTRAP === 'true';
const allowedOrigins = (process.env.ALLOWED_ORIGINS || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);
const ADMIN_ROLES = new Set([
  'super_admin',
  'clinical_ops',
  'support_ops',
  'trust_safety',
  'read_only_analytics',
]);
const ACTIVE_APPOINTMENT_STATUSES = new Set([
  'requested',
  'confirmed',
  'completed',
  'no_show',
]);
const CALL_ELIGIBLE_STATUSES = new Set(['confirmed', 'completed']);
const CANCELLABLE_STATUSES = new Set(['requested', 'confirmed']);
const DEFAULT_LIST_LIMIT = 50;
const MAX_LIST_LIMIT = 100;
const RECENT_AUTH_WINDOW_SECONDS = Number(
  process.env.RECENT_AUTH_WINDOW_SECONDS || 15 * 60,
);
const REQUEST_HOLD_HOURS = Number(process.env.REQUEST_HOLD_HOURS || 24);
const INTERNAL_JOB_SECRET = process.env.INTERNAL_JOB_SECRET || '';
const RELATIONSHIP_CACHE_TTL_MS = Number(
  process.env.RELATIONSHIP_CACHE_TTL_MS || 30 * 1000,
);
const ROOM_CACHE_TTL_MS = Number(process.env.ROOM_CACHE_TTL_MS || 15 * 1000);

const CHAT_FEW_SHOT_EXAMPLES = [
  {
    user: 'I feel so overwhelmed and I cannot focus on my studies.',
    assistant:
      "I'm sorry this feels this heavy right now. Do not try to fix the whole day at once. Pick one tiny step, like opening your notes or reading one page only. Small progress still counts. What subject feels hardest for you right now?",
  },
  {
    user: 'I feel mentally tired all the time.',
    assistant:
      "That sounds exhausting, and I'm glad you shared it. Try not to push yourself like you need to solve everything today. Start with one basic reset, drink water, sit somewhere quiet, and take a few slow breaths. Have you been feeling like this every day or only recently?",
  },
  {
    user: 'I feel lonely even when people are around me.',
    assistant:
      'That kind of loneliness can feel very heavy. You do not have to force yourself to look okay. For today, try one small act of connection, even a simple message to someone you trust or a short journal entry about what you wish people understood. Do you want to talk more about what feels missing?',
  },
  {
    user: 'My chest feels tight because I keep overthinking everything.',
    assistant:
      "I'm sorry you're dealing with that. Let's slow it down for one moment. Unclench your jaw, relax your shoulders, and take one slow breath in and one slow breath out. You do not need to solve every thought right now. Do you know what triggered the overthinking today?",
  },
  {
    user: 'My sleep schedule is so bad and it makes me feel worse.',
    assistant:
      'Poor sleep can make everything feel heavier. Do not try to fix the whole routine in one night. Start with one change only, like putting your phone away 20 minutes earlier or keeping the lights dim before bed. What part is hardest for you, falling asleep or waking up tired?',
  },
  {
    user: 'I have exams and I feel like I will fail everything.',
    assistant:
      'That pressure sounds intense, and it makes sense that you feel scared. Right now, do not think about every exam together. Choose one subject and one 20 minute study block. That is enough for this moment. Want to tell me which exam is stressing you most?',
  },
  {
    user: "I don't even know what I'm feeling.",
    assistant:
      "That is okay. You do not need perfect words. Try naming it in a simple way, heavy, numb, anxious, low, irritated, or mixed. Logging your mood can help you notice patterns without pressure. Want me to help you put today's feeling into words?",
  },
  {
    user: "I want to journal but I don't know what to write.",
    assistant:
      'Keep it very simple. Start with one line, right now I feel, then write whatever comes naturally. No need to sound deep or perfect. Even two honest sentences are enough. Do you want a few gentle journal prompts?',
  },
  {
    user: 'I think I need deeper help because these feelings keep coming back.',
    assistant:
      "I'm really glad you said that. Reaching for more support is a strong step, not a weak one. If these feelings keep repeating or getting heavier, connecting with a licensed therapist could really help. Would you like help preparing what to say in your first session?",
  },
  {
    user: 'I feel like I’m panicking and I cannot calm down.',
    assistant:
      "I'm here with you. Let's keep this very small. Put both feet on the floor and name five things you can see around you. Then take one slow breath. We are focusing only on this moment, not the whole day. Are you somewhere safe right now?",
  },
  {
    user: 'Everything is my fault.',
    assistant:
      'That thought sounds painful. When you’re overwhelmed, your mind can become very harsh with you. For now, do not argue with every thought. Just pause and ask, what is one thing I know for sure right now? What happened today that made you feel this way?',
  },
  {
    user: 'I have no motivation for anything.',
    assistant:
      'That can feel really draining. When motivation is low, try not to wait for energy before starting. Make the goal extremely small, like standing up, washing your face, or doing one task for five minutes. Tiny movement still matters. What feels easiest to start with today?',
  },
  {
    user: 'I feel nothing these days.',
    assistant:
      'Feeling numb can be unsettling too. It does not mean your struggle is not real. For today, focus on one grounding thing that brings even a little sensation, fresh air, cold water on your hands, or a short walk. Has this numb feeling been going on for a long time?',
  },
  {
    user: 'Do I have depression?',
    assistant:
      "I can’t diagnose mental health conditions, but I can help you notice what you’ve been experiencing and encourage you to speak with a licensed professional for a proper assessment. If you want, you can tell me what symptoms or feelings you’ve been having, and I can help you organize them clearly.",
  },
  {
    user: 'Tell me what medicine I should take for anxiety.',
    assistant:
      "I can’t recommend medicine or dosage. That decision should come from a qualified medical professional who understands your health history. I can help with calming strategies for this moment, or help you prepare questions to ask a doctor or therapist. What kind of support do you need right now?",
  },
];

function hasWildcardOrigin(origins) {
  return origins.some((origin) => origin === '*' || origin.includes('*'));
}

function getLocalBypassUser() {
  return {
    uid: 'local-dev-user',
    role: 'user',
    adminRoles: [],
    email: 'local-dev@example.com',
    name: 'Local Development User',
  };
}

function normalizeOllamaModelName(value) {
  if (typeof value !== 'string') {
    return null;
  }

  const normalized = value.trim().toLowerCase();
  return normalized.length > 0 ? normalized : null;
}

function ollamaModelVariants(value) {
  const normalized = normalizeOllamaModelName(value);
  if (!normalized) {
    return [];
  }

  if (normalized.includes(':')) {
    return [normalized, normalized.split(':')[0]];
  }

  return [normalized, `${normalized}:latest`];
}

function ollamaTagMatchesConfiguredModel(tagName, configuredModel = OLLAMA_MODEL) {
  const tagVariants = new Set(ollamaModelVariants(tagName));
  return ollamaModelVariants(configuredModel).some((variant) =>
    tagVariants.has(variant),
  );
}

function isOllamaTimeoutError(error) {
  if (!error || typeof error !== 'object') {
    return false;
  }

  return (
    error.name === 'TimeoutError' ||
    error.name === 'AbortError' ||
    error.code === 23 ||
    /timed out|aborted due to timeout/i.test(String(error.message || ''))
  );
}

function toOllamaRequestError(error, elapsedMs) {
  if (isOllamaTimeoutError(error)) {
    return createHttpError(
      504,
      'ollama_timeout',
      'The AI model took too long to respond.',
      {
        elapsedMs,
        timeoutMs: OLLAMA_CHAT_TIMEOUT_MS,
        model: OLLAMA_MODEL,
      },
    );
  }

  return createHttpError(
    502,
    'ollama_unavailable',
    'The AI service is unavailable right now.',
    {
      elapsedMs,
      model: OLLAMA_MODEL,
      reason: error instanceof Error ? error.message : String(error),
    },
  );
}

function backendAuthMode() {
  return ALLOW_UNAUTHENTICATED_LOCAL ? 'local_bypass' : 'real';
}

function buildBackendHealthPayload({
  ollamaReachable,
  modelReady = false,
  turnConfigured,
  details,
}) {
  const chatReady = ollamaReachable && modelReady;
  const callingReady = !IS_PRODUCTION || turnConfigured;
  const ok = chatReady && callingReady;
  const notificationPushReady = firebaseAdminReady;
  const notificationEmailReady = Boolean(
    process.env.POSTMARK_SERVER_TOKEN && process.env.POSTMARK_FROM_EMAIL,
  );
  const notificationJobsReady = Boolean(INTERNAL_JOB_SECRET);

  return {
    ok,
    status: ok ? 'healthy' : 'degraded',
    chatMode: chatReady ? 'live' : 'degraded',
    ollama: ollamaReachable ? 'connected' : 'unreachable',
    model: OLLAMA_MODEL,
    configuredModel: OLLAMA_MODEL,
    modelReady,
    backendAuthMode: backendAuthMode(),
    authRequired: !ALLOW_UNAUTHENTICATED_LOCAL,
    firebaseAdminReady,
    turnConfigured,
    callingReady,
    notificationPushReady,
    notificationEmailReady,
    notificationJobsReady,
    notificationProvidersReady:
      notificationPushReady && notificationEmailReady && notificationJobsReady,
    ...(details ? { details } : {}),
  };
}

function resolvedProjectId(env = process.env) {
  return (
    env.FIREBASE_PROJECT_ID ||
    env.GOOGLE_CLOUD_PROJECT ||
    env.GCLOUD_PROJECT ||
    ''
  ).trim();
}

function buildFirebaseAdminOptions(env = process.env) {
  const projectId = resolvedProjectId(env);
  const clientEmail = typeof env.FIREBASE_CLIENT_EMAIL === 'string'
    ? env.FIREBASE_CLIENT_EMAIL
    : '';
  const privateKey = typeof env.FIREBASE_PRIVATE_KEY === 'string'
    ? env.FIREBASE_PRIVATE_KEY
    : '';

  if (projectId && clientEmail.trim() && privateKey.trim()) {
    return {
      projectId,
      credential: admin.credential.cert({
        projectId,
        clientEmail: clientEmail.trim(),
        privateKey: privateKey.replace(/\\n/g, '\n'),
      }),
    };
  }

  if (projectId) {
    return {
      projectId,
      credential: admin.credential.applicationDefault(),
    };
  }

  return undefined;
}

app.disable('x-powered-by');
app.use(
  cors({
    origin(origin, callback) {
      if (!origin || allowedOrigins.includes(origin)) {
        callback(null, true);
        return;
      }
      callback(new Error('Origin not allowed by CORS policy'));
    },
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  }),
);
app.use(express.json({ limit: '64kb' }));

let firebaseAdminReady = false;
try {
  if (!admin.apps.length) {
    admin.initializeApp(buildFirebaseAdminOptions());
  }
  firebaseAdminReady = true;
} catch (error) {
  console.error(
    '[startup] Firebase Admin initialization failed:',
    error.message,
  );
}

function getStartupValidationErrors(config) {
  const errors = [];

  if (config.isProduction && config.allowedOrigins.length === 0) {
    errors.push(
      'ALLOWED_ORIGINS must be configured explicitly in production.',
    );
  }

  if (config.isProduction && hasWildcardOrigin(config.allowedOrigins)) {
    errors.push(
      'ALLOWED_ORIGINS cannot contain wildcard entries in production.',
    );
  }

  if (config.isProduction && config.allowUnauthenticatedLocal) {
    errors.push(
      'ALLOW_UNAUTHENTICATED_LOCAL cannot be enabled in production.',
    );
  }

  if (config.isProduction && config.enableAdminBootstrap) {
    errors.push(
      'ENABLE_ADMIN_BOOTSTRAP must be disabled in production after initial provisioning.',
    );
  }

  if (config.isProduction && !config.firebaseAdminReady) {
    errors.push(
      'Firebase Admin must initialize successfully before production startup.',
    );
  }

  return errors;
}

function validateStartupConfiguration() {
  const errors = getStartupValidationErrors({
    isProduction: IS_PRODUCTION,
    allowedOrigins,
    allowUnauthenticatedLocal: ALLOW_UNAUTHENTICATED_LOCAL,
    enableAdminBootstrap: ENABLE_ADMIN_BOOTSTRAP,
    firebaseAdminReady,
  });

  if (errors.length > 0) {
    const message = errors.join(' ');
    console.error(`[startup] ${message}`);
    process.exit(1);
  }
}

validateStartupConfiguration();

const rateBuckets = new Map();
const relationshipSummaryCache = new Map();
const callRoomCache = new Map();

function log(level, message, details = {}) {
  const payload = {
    level,
    message,
    ...details,
    timestamp: new Date().toISOString(),
  };
  const serialized = JSON.stringify(payload);
  if (level === 'error') {
    console.error(serialized);
    return;
  }
  if (level === 'warn') {
    console.warn(serialized);
    return;
  }
  console.log(serialized);
}

function logInfo(message, details = {}) {
  log('info', message, details);
}

function logWarn(message, details = {}) {
  log('warn', message, details);
}

function logError(message, details = {}) {
  log('error', message, details);
}

function runDeferredTask(label, task, details = {}) {
  Promise.resolve()
    .then(task)
    .catch((error) => {
      logWarn(`${label} failed`, {
        ...details,
        error: error instanceof Error ? error.message : String(error),
      });
    });
}

function getCachedValue(cache, key) {
  const entry = cache.get(key);
  if (!entry) {
    return null;
  }
  if (entry.expiresAt <= Date.now()) {
    cache.delete(key);
    return null;
  }
  return entry.value;
}

function setCachedValue(cache, key, value, ttlMs) {
  cache.set(key, {
    value,
    expiresAt: Date.now() + ttlMs,
  });
  return value;
}

function createHttpError(status, code, message, details = undefined) {
  const error = new Error(message);
  error.status = status;
  error.code = code;
  error.details = details;
  return error;
}

function asyncRoute(handler) {
  return async (req, res) => {
    try {
      await handler(req, res);
    } catch (error) {
      handleRouteError(req, res, error);
    }
  };
}

function handleRouteError(req, res, error) {
  const status = Number(error.status || 500);
  const code = error.code || 'internal_error';
  const message =
    status >= 500 && IS_PRODUCTION
      ? 'Request failed. Please try again shortly.'
      : (error.message || 'Request failed. Please try again shortly.');

  logError('Request failed', {
    path: req.path,
    method: req.method,
    status,
    code,
    uid: req.user?.uid,
    details: error.details,
    error: error.message,
  });

  res.status(status).json({ error: message, code });
}

function firestoreDb() {
  if (!firebaseAdminReady) {
    throw createHttpError(
      503,
      'firebase_admin_unavailable',
      'Backend authentication is not configured.',
    );
  }
  return admin.firestore();
}

function nowTimestamp() {
  return admin.firestore.FieldValue.serverTimestamp();
}

function clampLimit(rawLimit) {
  const limit = Number(rawLimit || DEFAULT_LIST_LIMIT);
  if (!Number.isFinite(limit) || limit <= 0) {
    return DEFAULT_LIST_LIMIT;
  }
  return Math.min(limit, MAX_LIST_LIMIT);
}

function hasTurnConfiguration() {
  return (
    TURN_URLS.length > 0 &&
    TURN_USERNAME.trim().length > 0 &&
    TURN_CREDENTIAL.trim().length > 0
  );
}

function sanitizeTelemetryValue(value, depth = 0) {
  if (depth > 3) {
    return '[max-depth]';
  }
  if (
    value === null ||
    typeof value === 'string' ||
    typeof value === 'number' ||
    typeof value === 'boolean'
  ) {
    return value;
  }
  if (Array.isArray(value)) {
    return value.slice(0, 20).map((entry) => sanitizeTelemetryValue(entry, depth + 1));
  }
  if (typeof value === 'object') {
    const sanitized = {};
    for (const [key, entry] of Object.entries(value).slice(0, 30)) {
      sanitized[key] = sanitizeTelemetryValue(entry, depth + 1);
    }
    return sanitized;
  }
  return String(value);
}

function normalizeAppRole(value) {
  if (typeof value !== 'string') {
    return 'user';
  }
  const normalized = value.trim().toLowerCase();
  if (normalized === 'therapist' || normalized === 'admin') {
    return normalized;
  }
  return 'user';
}

function parseExplicitAppRole(value) {
  if (typeof value !== 'string') {
    return null;
  }
  const normalized = value.trim().toLowerCase();
  if (normalized === 'therapist' || normalized === 'admin') {
    return normalized;
  }
  if (normalized === 'user') {
    return 'user';
  }
  return null;
}

function normalizeAdminRoles(value) {
  const values = Array.isArray(value) ? value : [value];
  return values
    .filter((entry) => typeof entry === 'string')
    .map((entry) => entry.trim().toLowerCase())
    .filter((entry) => ADMIN_ROLES.has(entry));
}

function ensureNonEmptyString(value, fieldName) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw createHttpError(400, 'validation_error', `${fieldName} is required.`);
  }
  return value.trim();
}

function asDate(value) {
  if (!value) {
    return null;
  }
  if (value instanceof Date) {
    return value;
  }
  if (typeof value.toDate === 'function') {
    return value.toDate();
  }
  if (typeof value === 'number') {
    const fromMillis = new Date(value);
    return Number.isNaN(fromMillis.valueOf()) ? null : fromMillis;
  }
  const parsed = new Date(value);
  return Number.isNaN(parsed.valueOf()) ? null : parsed;
}

function toIso(value) {
  const date = asDate(value);
  return date ? date.toISOString() : null;
}

function sanitizeHistory(history) {
  if (!Array.isArray(history)) {
    return [];
  }

  return history
    .slice(-MAX_HISTORY_MESSAGES)
    .map((entry) => {
      if (!entry || typeof entry !== 'object') {
        return null;
      }

      const role = entry.role === 'assistant' ? 'assistant' : 'user';
      const content =
        typeof entry.content === 'string'
          ? entry.content.trim().slice(0, MAX_MESSAGE_LENGTH)
          : '';

      if (!content) {
        return null;
      }

      return { role, content };
    })
    .filter(Boolean);
}

function normalizeLocaleTag(value, fallback = 'en') {
  if (typeof value !== 'string') {
    return fallback;
  }

  const normalized = value.trim().toLowerCase();
  if (!normalized) {
    return fallback;
  }

  if (normalized.startsWith('ur')) {
    return 'ur';
  }
  if (normalized.startsWith('en')) {
    return 'en';
  }
  if (normalized.startsWith('pa') || normalized.startsWith('punjabi')) {
    return 'pa';
  }

  return normalized;
}

function containsUrduScript(text = '') {
  return /[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]/.test(String(text));
}

function countKeywordHits(text, keywords) {
  if (!text) {
    return 0;
  }

  return keywords.reduce((count, keyword) => {
    const pattern = new RegExp(`(^|\\s)${keyword}(?=\\s|$)`, 'i');
    return count + (pattern.test(text) ? 1 : 0);
  }, 0);
}

const ROMAN_URDU_MARKERS = [
  'mujhe',
  'mjhe',
  'mjy',
  'mera',
  'meri',
  'mere',
  'tum',
  'aap',
  'main',
  'mein',
  'mai',
  'hain',
  'hai',
  'hun',
  'ho',
  'kya',
  'kya',
  'kyun',
  'q',
  'nahi',
  'nahi',
  'nai',
  'nh',
  'bohat',
  'boht',
  'kr',
  'kar',
  'raha',
  'rahi',
  'horahi',
  'dard',
  'thora',
  'zyada',
  'samajh',
  'baat',
  'mar',
  'gae',
  'gayi',
];

const ROMAN_PUNJABI_MARKERS = [
  'menu',
  'mainu',
  'tusi',
  'tuhada',
  'sanu',
  'kida',
  'kiwen',
  'lagda',
  'hunda',
  'rehya',
  'rehyae',
  'rehi',
  'aan',
  'ae',
  've',
  'naal',
  'gal',
];

const ENGLISH_STYLE_MARKERS = [
  'i',
  'my',
  'me',
  'feel',
  'feeling',
  'pain',
  'anxious',
  'help',
  'please',
  'what',
  'why',
  'how',
  'today',
  'doctor',
];

function inferChatReplyStyle(text = '', preferredLocale = 'en') {
  const raw = String(text || '').trim();
  const lowered = raw.toLowerCase();

  if (containsUrduScript(raw)) {
    return 'urdu_script';
  }

  const latinTokenCount = (lowered.match(/[a-z]+/g) || []).length;
  const romanUrduHits = countKeywordHits(lowered, ROMAN_URDU_MARKERS);
  const romanPunjabiHits = countKeywordHits(lowered, ROMAN_PUNJABI_MARKERS);
  const englishHits = countKeywordHits(lowered, ENGLISH_STYLE_MARKERS);

  if (latinTokenCount > 0) {
    if (romanPunjabiHits >= 3 || (romanPunjabiHits >= 2 && englishHits === 0)) {
      return englishHits >= 2 ? 'mixed_english_roman' : 'roman_punjabi';
    }

    if (romanUrduHits >= 3 || (romanUrduHits >= 2 && englishHits === 0)) {
      return englishHits >= 2 ? 'mixed_english_roman' : 'roman_urdu';
    }
  }

  const locale = normalizeLocaleTag(preferredLocale, 'en');
  if (locale === 'ur') {
    return latinTokenCount > 0 ? 'roman_urdu' : 'urdu_script';
  }
  if (locale === 'pa') {
    return 'roman_punjabi';
  }
  return 'english';
}

function buildChatSystemPrompt({ preferredLocale = 'en', replyStyle = 'english' }) {
  const locale = normalizeLocaleTag(preferredLocale, 'en');

  const styleInstruction =
    {
      urdu_script: 'Reply in clear Urdu script.',
      roman_urdu: 'Reply in simple Roman Urdu.',
      roman_punjabi: 'Reply in simple Roman Punjabi using Latin letters.',
      mixed_english_roman:
        'Reply in the same mixed English and Roman Urdu style as the user.',
      english: 'Reply in clear English.',
    }[replyStyle] || 'Reply in the same language as the user.';

  return [
    'You are MoodGenie, a calm, supportive, emotionally safe mental wellness assistant inside the MoodGenie app.',
    'Your role is to support users with gentle emotional check-ins, help them reflect on feelings, suggest small coping steps, encourage healthy routines, and guide them toward app features like mood logging, journaling, therapist booking, and wellness exercises when suitable.',
    'Your tone must be warm, calm, respectful, reassuring, human, short, and clear.',
    'Never sound robotic, preachy, overly dramatic, or unrelated to the user’s message.',
    'First validate the user’s feeling.',
    'Then give one small practical step.',
    'Then ask one gentle follow-up question only if it is appropriate.',
    'Keep replies short, usually 60 to 90 words.',
    'Use simple language and emotionally safe wording.',
    'Do not overload the user with too many steps.',
    'Be supportive and nonjudgmental.',
    'Encourage healthy coping.',
    'Respect user feelings even when they are confused, upset, or stressed.',
    'Do not diagnose any mental illness.',
    'Do not claim to be a therapist, psychologist, psychiatrist, or doctor.',
    'Do not prescribe medicine, dosage, treatment plans, or medical tests.',
    'Do not encourage dependency on you.',
    'Do not shame the user, minimize their feelings, or say everything will definitely be fine.',
    'Do not pretend to know facts you do not know.',
    'If the user asks for diagnosis, medicine, or clinical judgment, say you cannot provide that and encourage a licensed professional.',
    'If the user asks whether they have depression, anxiety, bipolar disorder, OCD, PTSD, or any other condition, do not confirm or deny it.',
    'If the user asks for medical interpretation, redirect safely.',
    'If the user mentions physical pain or medical symptoms, be honest that you are not a doctor, give cautious general guidance, and recommend urgent medical care if symptoms are severe, sudden, worsening, or make walking or breathing difficult.',
    'If the user mentions suicide, self-harm, wanting to die, hurting themselves, harming others, abuse, or immediate danger, stop normal conversation and give a supportive but urgent safety response. Encourage emergency services, a local crisis line, or a trusted person immediately. Tell them not to stay alone if they are in danger. Do not provide harmful instructions. Do not continue casual coaching in a crisis moment.',
    'If suitable, suggest logging their mood in the app.',
    'If suitable, suggest journaling.',
    'If suitable, suggest a short breathing or grounding exercise.',
    'If the user needs more support, suggest therapist booking in the app.',
    'If the user feels emotionally overloaded, break help into one very small next step.',
    'Usually respond as one short paragraph.',
    'Only use 2 to 3 very short bullet points when clearly helpful.',
    'End with one gentle question when appropriate.',
    'Always finish with a complete final sentence.',
    'Answer the user’s latest message directly, clearly, and relevantly.',
    'Do not invent unrelated stories, rhymes, jokes, or random text.',
    'Do not change the topic away from what the user just asked.',
    'If the message is unclear, say you did not fully understand and ask one short clarifying question in the same language.',
    `Preferred app locale: ${locale}.`,
    `Detected reply style: ${replyStyle}.`,
    styleInstruction,
    'Always mirror the user’s language and script as closely as possible.',
    'If the user writes in Roman Urdu, reply in Roman Urdu.',
    'If the user writes in Urdu script, reply in Urdu script.',
    'If the user mixes English with Roman Urdu, mirror that naturally.',
    'Never output gibberish, malformed sentences, or unrelated content.',
  ].join('\n');
}

function buildChatFewShotMessages() {
  return CHAT_FEW_SHOT_EXAMPLES.flatMap((example) => [
    { role: 'user', content: example.user },
    { role: 'assistant', content: example.assistant },
  ]);
}

function buildChatFinalInstruction() {
  return [
    'Respond in the MoodGenie style shown in the examples above.',
    'Keep the reply emotionally safe, short, warm, and clear.',
    'Validate first.',
    'Then give one small practical step.',
    'Then ask one gentle follow up question when appropriate.',
    'Do not diagnose.',
    'Do not prescribe medication.',
    'Do not add extra sections, labels, or explanations about your own role.',
  ].join('\n');
}

function normalizeScreenContext(value) {
  if (typeof value !== 'string') {
    return 'chat';
  }

  const normalized = value.trim().toLowerCase();
  if (!normalized) {
    return 'chat';
  }

  const aliases = new Map([
    ['mood', 'mood_tracker'],
    ['mood_tracker', 'mood_tracker'],
    ['mood-tracker', 'mood_tracker'],
    ['mood tracker', 'mood_tracker'],
    ['journal', 'journal'],
    ['journaling', 'journal'],
    ['journal_screen', 'journal'],
    ['journal screen', 'journal'],
    ['breathing', 'breathing_exercise'],
    ['breathing_exercise', 'breathing_exercise'],
    ['breathing-exercise', 'breathing_exercise'],
    ['breathing exercise', 'breathing_exercise'],
    ['exercise', 'breathing_exercise'],
    ['chat', 'chat'],
  ]);

  return aliases.get(normalized) || 'chat';
}

function buildScreenContextInstruction(screenContext = 'chat') {
  switch (normalizeScreenContext(screenContext)) {
    case 'mood_tracker':
      return [
        'The user is on the Mood Tracker screen.',
        'Help them identify and describe their current mood in simple words.',
        'Encourage mood logging without pressure.',
      ].join('\n');
    case 'journal':
      return [
        'The user is on the Journal screen.',
        'Help them begin writing with soft, simple prompts.',
        'Do not overwhelm them.',
        'Give only one to three prompts.',
        'Be gentle, brief, and reflective.',
        'Encourage mood logging without pressure.',
      ].join('\n');
    case 'breathing_exercise':
      return [
        'The user is on the Breathing Exercise screen.',
        'Guide the user into one short calming exercise.',
        'Keep instructions very simple.',
        'Use short sentences.',
        'Sound calm and steady.',
      ].join('\n');
    default:
      return '';
  }
}

function looksLikeDiagnosisRequest(text = '') {
  const value = String(text || '').toLowerCase();
  const keywords = [
    'do i have depression',
    'do i have anxiety',
    'do i have ocd',
    'do i have ptsd',
    'do i have bipolar',
    'am i depressed',
    'am i anxious',
    'can you diagnose me',
    'is this depression',
    'is this anxiety',
    'kya mujhe depression hai',
    'kya mujhe anxiety hai',
    'kya mujhe ocd hai',
    'kya mujhe ptsd hai',
    'kya mujhe bipolar hai',
    'kya ye depression hai',
    'kya ye anxiety hai',
    'kya mujhay depression hai',
    'kya mujhay anxiety hai',
    'کیا مجھے ڈپریشن ہے',
    'کیا مجھے اینگزائٹی ہے',
    'کیا یہ ڈپریشن ہے',
    'کیا یہ اینگزائٹی ہے',
    'تشخیص',
    'diagnosis',
  ];
  return keywords.some((keyword) => value.includes(keyword));
}

function looksLikeMedicineRequest(text = '') {
  const value = String(text || '').toLowerCase();
  const keywords = [
    'what medicine should i take',
    'which medicine should i take',
    'what medicine for anxiety',
    'what medicine for depression',
    'recommend medicine',
    'recommend medication',
    'dosage',
    'tablet',
    'pill',
    'antidepressant',
    'anti anxiety medicine',
    'konsi medicine loon',
    'konsi dawa loon',
    'kon si dawa loon',
    'anxiety ke liye dawa',
    'depression ke liye dawa',
    'medicine batao',
    'dawa batao',
    'دوائی',
    'دوا',
    'کون سی دوا',
    'کون سی دوائی',
  ];
  return keywords.some((keyword) => value.includes(keyword));
}

function buildDiagnosisOverrideReply(replyStyle = 'english') {
  if (replyStyle === 'urdu_script') {
    return 'میں ذہنی صحت کی تشخیص نہیں کر سکتا، لیکن میں آپ کی کیفیت کو سمجھنے میں مدد کر سکتا ہوں اور مناسب سپورٹ کے لیے کسی لائسنس یافتہ پروفیشنل سے بات کرنے کی حوصلہ افزائی کروں گا۔ اگر آپ چاہیں تو آپ اپنی علامات یا احساسات بتا سکتے ہیں، میں انہیں واضح انداز میں ترتیب دینے میں مدد کر سکتا ہوں۔';
  }

  if (
    replyStyle === 'roman_urdu' ||
    replyStyle === 'roman_punjabi' ||
    replyStyle === 'mixed_english_roman'
  ) {
    return 'Main mental health conditions ki tashkhees nahi kar sakta, lekin main aap ko yeh samajhne mein madad kar sakta hoon ke aap kya feel kar rahe hain, aur proper support ke liye kisi licensed professional se baat karne ka mashwara de sakta hoon.';
  }

  return "I can’t diagnose mental health conditions, but I can help you reflect on what you’re feeling and suggest speaking with a licensed professional for proper support.";
}

function buildMedicineOverrideReply(replyStyle = 'english') {
  if (replyStyle === 'urdu_script') {
    return 'میں دوا یا اس کی مقدار تجویز نہیں کر سکتا۔ اس کے لیے براہِ کرم کسی مستند ڈاکٹر یا ذہنی صحت کے پروفیشنل سے بات کریں۔';
  }

  if (
    replyStyle === 'roman_urdu' ||
    replyStyle === 'roman_punjabi' ||
    replyStyle === 'mixed_english_roman'
  ) {
    return 'Main medicine ya dosage recommend nahi kar sakta. Is ke liye kisi qualified doctor ya mental health professional se baat karein.';
  }

  return 'I can’t recommend medicine or dosage. For that, please speak with a qualified doctor or mental health professional.';
}

function containsAny(text = '', keywords = []) {
  const value = String(text || '').toLowerCase();
  return keywords.some((keyword) => value.includes(keyword));
}

function shouldUseGuidedWellnessReply(text = '', screenContext = 'chat') {
  if (normalizeScreenContext(screenContext) !== 'chat') {
    return true;
  }

  return containsAny(text, [
    'i feel',
    'overwhelm',
    'study',
    'exam',
    'tired',
    'lonely',
    'overthink',
    'sleep',
    'motivation',
    'numb',
    'panic',
    'fault',
    'journal',
    'mood',
    'mujhe',
    'mjhe',
    'mera',
    'meri',
    'dil',
    'bhari',
    'samajh',
    'feel kar',
    'dard',
    'ghabra',
    'parhai',
    'udas',
    'akela',
    'tanha',
    'thak',
    'neend',
    'دل',
    'بھاری',
    'سمجھ',
    'محسوس',
    'اداس',
    'گھبرا',
    'نیند',
    'درد',
  ]);
}

function buildEnglishGuidedReply(userMessage, screenContext = 'chat') {
  const value = String(userMessage || '').toLowerCase();
  const normalizedScreen = normalizeScreenContext(screenContext);

  if (normalizedScreen === 'mood_tracker') {
    return "That is okay. You do not need the perfect word for it. Try naming today's feeling in a simple way, like heavy, anxious, low, numb, irritated, or mixed. If you want, I can help you choose the closest mood label.";
  }

  if (normalizedScreen === 'journal') {
    return 'Let’s keep journaling very light. Start with one line: “Right now I feel…” and write whatever comes naturally. If you want, I can also give you one or two gentle prompts.';
  }

  if (normalizedScreen === 'breathing_exercise') {
    return 'Let’s keep this simple. Breathe in slowly for 4 seconds, hold for 4, then breathe out for 6. Repeat that three times, and only focus on this one breath at a time.';
  }

  if (containsAny(value, ['study', 'studies', 'exam', 'exams', 'focus'])) {
    return "I'm sorry this feels this heavy right now. Do not try to fix the whole day at once. Pick one tiny step, like opening your notes or reading one page only. Small progress still counts. What subject feels hardest for you right now?";
  }

  if (containsAny(value, ['mentally tired', 'tired all the time', 'exhaust', 'drained'])) {
    return "That sounds exhausting, and I'm glad you shared it. Try not to push yourself like you need to solve everything today. Start with one basic reset: drink water, sit somewhere quiet, and take a few slow breaths. Have you been feeling like this every day or only recently?";
  }

  if (containsAny(value, ['lonely', 'alone', 'isolated'])) {
    return 'That kind of loneliness can feel very heavy. You do not have to force yourself to look okay. For today, try one small act of connection, even a simple message to someone you trust or a short journal entry about what you wish people understood. Do you want to talk more about what feels missing?';
  }

  if (containsAny(value, ['overthink', 'overthinking', 'chest feels tight', 'chest tight', 'anxious', 'anxiety'])) {
    return "I'm sorry you're dealing with that. Let’s slow it down for one moment. Unclench your jaw, relax your shoulders, and take one slow breath in and one slow breath out. You do not need to solve every thought right now. Do you know what triggered the overthinking today?";
  }

  if (containsAny(value, ['sleep', 'sleep schedule', 'waking up tired', 'falling asleep'])) {
    return 'Poor sleep can make everything feel heavier. Do not try to fix the whole routine in one night. Start with one change only, like putting your phone away 20 minutes earlier or keeping the lights dim before bed. What part is hardest for you, falling asleep or waking up tired?';
  }

  if (containsAny(value, ["don't even know what i'm feeling", 'dont even know what im feeling', "don't know what i'm feeling"])) {
    return "That is okay. You do not need perfect words. Try naming it in a simple way, heavy, numb, anxious, low, irritated, or mixed. Logging your mood can help you notice patterns without pressure. Want me to help you put today’s feeling into words?";
  }

  if (containsAny(value, ['journal', "don't know what to write", 'dont know what to write'])) {
    return 'Keep it very simple. Start with one line, “Right now I feel…” then write whatever comes naturally. No need to sound deep or perfect. Even two honest sentences are enough. Do you want a few gentle journal prompts?';
  }

  if (containsAny(value, ['deeper help', 'keep coming back', 'need more support', 'need therapist'])) {
    return "I'm really glad you said that. Reaching for more support is a strong step, not a weak one. If these feelings keep repeating or getting heavier, connecting with a licensed therapist could really help. Would you like help preparing what to say in your first session?";
  }

  if (containsAny(value, ['panicking', 'panic', 'cannot calm down', "can't calm down"])) {
    return "I'm here with you. Let’s keep this very small. Put both feet on the floor and name five things you can see around you. Then take one slow breath. We are focusing only on this moment, not the whole day. Are you somewhere safe right now?";
  }

  if (containsAny(value, ['my fault', 'everything is my fault'])) {
    return 'That thought sounds painful. When you’re overwhelmed, your mind can become very harsh with you. For now, do not argue with every thought. Just pause and ask, what is one thing I know for sure right now? What happened today that made you feel this way?';
  }

  if (containsAny(value, ['no motivation', 'motivation', 'cannot do anything', "can't do anything"])) {
    return 'That can feel really draining. When motivation is low, try not to wait for energy before starting. Make the goal extremely small, like standing up, washing your face, or doing one task for five minutes. Tiny movement still matters. What feels easiest to start with today?';
  }

  if (containsAny(value, ['feel nothing', 'numb', 'empty'])) {
    return 'Feeling numb can be unsettling too. It does not mean your struggle is not real. For today, focus on one grounding thing that brings even a little sensation, like fresh air, cold water on your hands, or a short walk. Has this numb feeling been going on for a long time?';
  }

  if (containsAny(value, ['pain', 'foot', 'feet', 'leg', 'hurt'])) {
    return "I'm sorry you're dealing with pain. I’m not a doctor, but if the pain is severe, getting worse, swollen, or making it hard to walk, please seek medical care soon. For now, try to rest the area and avoid putting too much pressure on it. How long has the pain been there?";
  }

  if (containsAny(value, ['heavy', 'sad', 'low', 'upset'])) {
    return 'I’m sorry this feels so heavy right now. You do not need to figure out the whole feeling at once. Start by naming it in one simple word, like heavy, sad, anxious, or mixed. If you want, we can try to put today’s feeling into words together.';
  }

  return 'I’m here with you. Let’s keep this simple and take one small step only. Try telling me in one short line what feels heaviest right now, and I’ll respond gently and clearly.';
}

function buildRomanUrduGuidedReply(userMessage, screenContext = 'chat') {
  const value = String(userMessage || '').toLowerCase();
  const normalizedScreen = normalizeScreenContext(screenContext);

  if (normalizedScreen === 'mood_tracker') {
    return 'Yeh bilkul theek hai ke aap ko exact lafz na mil rahe hon. Aaj ki feeling ko simple tareeqay se naam dein, jaise heavy, anxious, low, numb, irritated, ya mixed. Agar chahein to main aap ko mood label choose karne mein madad kar sakta hoon.';
  }

  if (normalizedScreen === 'journal') {
    return 'Journal ko bohat simple rakhein. Sirf ek line se shuru karein: “Right now I feel…” aur jo naturally aaye woh likh dein. Agar chahein to main 1 ya 2 gentle prompts de sakta hoon.';
  }

  if (normalizedScreen === 'breathing_exercise') {
    return 'Chaliye isay bohat simple rakhte hain. 4 second saans andar lein, 4 second hold karein, phir 6 second mein bahar chhorein. Isay 3 dafa dohra lein aur sirf issi saans par focus rakhein.';
  }

  if (containsAny(value, ['study', 'studies', 'exam', 'exams', 'parhai', 'focus'])) {
    return 'Mujhe afsos hai ke yeh sab abhi itna heavy lag raha hai. Poore din ko ek saath theek karne ki koshish mat karein. Sirf ek chhota step lein, jaise notes kholna ya 10 minute study block. Abhi sab se mushkil subject konsa lag raha hai?';
  }

  if (containsAny(value, ['thak', 'tired', 'drained', 'exhaust'])) {
    return 'Yeh bohat thakane wala lag raha hai, aur main khush hoon ke aap ne share kiya. Aaj sab kuch solve karne ki zarurat nahi. Sirf ek basic reset karein: pani piyen, thori dair sukoon se baithen, aur 3 ahista saans lein. Kya yeh feeling roz hoti hai ya kuch dino se?';
  }

  if (containsAny(value, ['lonely', 'akela', 'akele', 'tanha'])) {
    return 'Aisi tanhai bohat heavy feel ho sakti hai. Aap ko theek dikhne ka natak karne ki zarurat nahi. Aaj ke liye sirf ek chhota connection step lein, jaise kisi bharosemand shakhs ko message karna ya journal mein likhna ke aap kya chahte hain ke log samjhein. Kya aap batana chahenge ke sab se zyada kya missing lag raha hai?';
  }

  if (containsAny(value, ['overthink', 'overthinking', 'ghabra', 'anxiety', 'chest', 'tight'])) {
    return 'Mujhe afsos hai ke aap yeh sab feel kar rahe hain. Chaliye ek pal ke liye cheezon ko slow karte hain. Apne shoulders relax karein aur ek ahista saans andar lein, phir bahar chhorein. Aap ko abhi har thought solve karne ki zarurat nahi. Aaj overthinking kis baat se trigger hui lagti hai?';
  }

  if (containsAny(value, ['sleep', 'neend'])) {
    return 'Poori neend na ho to sab kuch aur heavy lagta hai. Poora routine ek raat mein theek karne ki koshish mat karein. Sirf ek chhoti change se shuru karein, jaise sone se 20 minute pehle phone side par rakhna ya lights dim kar dena. Zyada mushkil kya lagta hai, neend aana ya uth kar thaka mehsoos karna?';
  }

  if (containsAny(value, ['samajh nahi', 'samajh nhi', 'kya feel', 'kya mehsoos'])) {
    return 'Yeh theek hai ke aap ko abhi exact words nahi mil rahe. Aaj ki feeling ko simple tareeqay se naam dene ki koshish karein, jaise heavy, numb, anxious, low, irritated, ya mixed. Mood log karna bina pressure ke pattern samajhne mein madad karta hai. Kya aap chahengi ke main aaj ki feeling ko words mein rakhne mein madad karun?';
  }

  if (containsAny(value, ['journal', 'likhna'])) {
    return 'Isay bohat simple rakhein. Sirf ek line se shuru karein: “Right now I feel…” aur jo naturally aaye woh likh dein. Perfect likhne ki zarurat nahi. Do sachay jumlay bhi kaafi hain. Kya aap chahti hain ke main 1 ya 2 gentle prompts doon?';
  }

  if (containsAny(value, ['deeper help', 'bar bar', 'baar baar', 'therapist', 'zyada support'])) {
    return 'Main bohat khush hoon ke aap ne yeh kaha. Zyada support lena kamzori nahi, balkeh strong step hai. Agar yeh feelings bar bar aa rahi hain ya aur heavy ho rahi hain, to licensed therapist se baat karna madadgar ho sakta hai. Kya aap pehli session mein kya kehna hai uski tayari mein madad chahengi?';
  }

  if (containsAny(value, ['panic', 'panicking', 'calm down', 'calm nahi'])) {
    return 'Main yahan hoon. Isay bohat chhota rakhte hain. Dono paon zameen par rakhein aur apne aas paas 5 cheezen dekhein. Phir ek ahista saans lein. Hum sirf iss lamhe par focus kar rahe hain, poore din par nahi. Kya aap iss waqt safe jagah par hain?';
  }

  if (containsAny(value, ['meri ghalti', 'my fault', 'sab meri ghalti'])) {
    return 'Yeh thought bohat painful lag raha hai. Jab insaan overwhelm hota hai to dimagh bohat sakht ho jata hai. Abhi har thought se behas mat karein. Sirf yeh poochein: is waqt ek cheez jo mujhe yaqeen se pata hai woh kya hai? Aaj kya hua jis ne aap ko aisa feel karwaya?';
  }

  if (containsAny(value, ['motivation', 'dil nahi', 'kuch karne ka dil nahi'])) {
    return 'Yeh bohat draining lag sakta hai. Jab motivation low ho to energy ka wait karne ki zarurat nahi hoti. Goal ko bohat chhota kar dein, jaise uthna, munh dhona, ya 5 minute ka ek task. Chhoti movement bhi matter karti hai. Aaj sab se asaan shuruat kya lagti hai?';
  }

  if (containsAny(value, ['numb', 'kuch mehsoos nahi', 'feel nothing'])) {
    return 'Numb feel karna bhi unsettling hota hai. Is ka matlab yeh nahi ke aap ki struggle real nahi hai. Aaj ke liye sirf ek grounding cheez try karein, jaise thori fresh air, thanda pani haathon par, ya chhoti walk. Kya yeh numb feeling kaafi arsay se chal rahi hai?';
  }

  if (containsAny(value, ['dard', 'foot', 'pair', 'paon', 'pain'])) {
    return 'Mujhe afsos hai ke aap ko dard ho raha hai. Main doctor nahi hoon, lekin agar dard bohat zyada hai, soojan hai, chalna mushkil ho raha hai, ya dard barhta ja raha hai to doctor ya clinic se jaldi rabta karein. Filhal jitna ho sake araam karein aur zyada pressure na dein. Dard kab se hai?';
  }

  if (containsAny(value, ['dil bhari', 'bhari lag', 'udas', 'heavy', 'low'])) {
    return 'Mujhe afsos hai ke aap ka dil itna bhari lag raha hai. Aap ko poori feeling ko ek saath samajhna zaruri nahi. Sirf ek simple lafz se shuru karein, jaise heavy, udaas, anxious, ya mixed. Agar chahein to hum mil kar is feeling ko words mein rakh sakte hain.';
  }

  return 'Main yahan hoon aur aap ki baat sun raha hoon. Isay bohat simple rakhte hain. Aap ek short line mein bata dein ke is waqt sab se heavy kya lag raha hai, main usi hisaab se jawab dunga.';
}

function buildUrduGuidedReply(userMessage, screenContext = 'chat') {
  const value = String(userMessage || '');
  const normalizedScreen = normalizeScreenContext(screenContext);

  if (normalizedScreen === 'mood_tracker') {
    return 'یہ بالکل ٹھیک ہے کہ آپ کو ابھی درست لفظ نہ مل رہا ہو۔ آج کی کیفیت کو سادہ لفظ میں نام دیں، جیسے بھاری، پریشان، اداس، سن، یا ملی جلی۔ اگر چاہیں تو میں آپ کی مدد کر سکتا ہوں کہ آج کے موڈ کو کس طرح لکھا جائے۔';
  }

  if (normalizedScreen === 'journal') {
    return 'جرنل کو بہت سادہ رکھیں۔ صرف ایک لائن سے شروع کریں: “اس وقت میں محسوس کر رہا/رہی ہوں…” پھر جو دل میں آئے وہ لکھ دیں۔ اگر چاہیں تو میں ایک دو نرم سوال بھی دے سکتا ہوں۔';
  }

  if (normalizedScreen === 'breathing_exercise') {
    return 'چلیے اسے بہت سادہ رکھتے ہیں۔ 4 سیکنڈ سانس اندر لیں، 4 سیکنڈ روکیں، پھر 6 سیکنڈ میں باہر نکالیں۔ یہ 3 بار دہرائیں اور صرف اسی سانس پر توجہ رکھیں۔';
  }

  if (containsAny(value, ['سمجھ نہیں', 'کیا محسوس', 'محسوس نہیں'])) {
    return 'یہ ٹھیک ہے کہ آپ کو ابھی اپنے احساسات کے لیے درست لفظ نہیں مل رہا۔ آج کی کیفیت کو سادہ انداز میں نام دینے کی کوشش کریں، جیسے بھاری، اداس، پریشان، سن، یا ملی جلی۔ اگر چاہیں تو میں آپ کے ساتھ مل کر اسے لفظوں میں ڈال سکتا ہوں۔';
  }

  if (containsAny(value, ['دل بھاری', 'اداس', 'بھاری'])) {
    return 'مجھے افسوس ہے کہ آپ کا دل اتنا بھاری لگ رہا ہے۔ آپ کو اس احساس کو ایک ہی بار میں پوری طرح سمجھنے کی ضرورت نہیں۔ صرف ایک سادہ لفظ سے آغاز کریں، جیسے اداس، بھاری، پریشان، یا ملی جلی کیفیت۔ کیا آپ چاہیں گے کہ ہم اس احساس کو مل کر واضح کریں؟';
  }

  if (containsAny(value, ['درد', 'پاؤں', 'پیر'])) {
    return 'مجھے افسوس ہے کہ آپ کو درد ہو رہا ہے۔ میں ڈاکٹر نہیں ہوں، لیکن اگر درد بہت زیادہ ہے، سوجن ہے، چلنا مشکل ہو رہا ہے، یا درد بڑھ رہا ہے تو جلد ڈاکٹر یا کلینک سے رابطہ کریں۔ ابھی کے لیے جتنا ممکن ہو آرام کریں۔ درد کب سے ہے؟';
  }

  return 'میں آپ کی بات کے ساتھ ہوں۔ ابھی سب کچھ ایک ساتھ سمجھنے کی ضرورت نہیں۔ بس ایک سادہ جملے میں بتائیں کہ اس وقت سب سے زیادہ بھاری کیا لگ رہا ہے، میں اسی حساب سے نرمی سے جواب دوں گا۔';
}

function buildGuidedWellnessReply({ userMessage, replyStyle, screenContext = 'chat' }) {
  switch (replyStyle) {
    case 'urdu_script':
      return buildUrduGuidedReply(userMessage, screenContext);
    case 'roman_urdu':
    case 'roman_punjabi':
    case 'mixed_english_roman':
      return buildRomanUrduGuidedReply(userMessage, screenContext);
    default:
      return buildEnglishGuidedReply(userMessage, screenContext);
  }
}

function looksLikeLowQualityChatReply(userMessage = '', reply = '') {
  const normalizedReply = String(reply || '').trim().toLowerCase();
  if (!normalizedReply) {
    return true;
  }

  if (normalizedReply.length < 24) {
    return true;
  }

  const suspiciousPhrases = [
    'shadi mein jaldi',
    'bachchey ki chahat',
    'aap mere samne nikle',
    'tere chai jaana',
    'dost ke baare',
  ];
  if (suspiciousPhrases.some((phrase) => normalizedReply.includes(phrase))) {
    return true;
  }

  if (containsAny(userMessage, ['samajh nahi', 'samajh nhi', 'what i am feeling', 'kya feel'])) {
    return !containsAny(normalizedReply, [
      'feeling',
      'feel',
      'mood',
      'heavy',
      'numb',
      'anxious',
      'low',
      'irritated',
      'words',
      'lafz',
      'mood log',
      'محسوس',
      'موڈ',
    ]);
  }

  if (containsAny(userMessage, ['dil bhari', 'bhari lag', 'heavy', 'low', 'sad'])) {
    return !containsAny(normalizedReply, [
      'heavy',
      'sad',
      'low',
      'feeling',
      'mood',
      'udaas',
      'bhari',
      'محسوس',
      'اداس',
      'بھاری',
    ]);
  }

  return false;
}

function isLikelyTruncatedReply(text = '') {
  const trimmed = String(text || '').trim();
  if (!trimmed) {
    return true;
  }

  if (/[.!?؟۔]["')\]]*$/.test(trimmed)) {
    return false;
  }

  const lastToken = trimmed.split(/\s+/).pop()?.toLowerCase() || '';
  const danglingTokens = new Set([
    'a',
    'an',
    'the',
    'to',
    'for',
    'and',
    'or',
    'but',
    'if',
    'with',
    'about',
    'suggest',
    'would',
    'like',
    'can',
    'could',
    'kya',
    'aur',
    'ke',
    'ki',
    'ka',
    'mein',
    'main',
  ]);

  if (danglingTokens.has(lastToken)) {
    return true;
  }

  return trimmed.length >= 40;
}

function buildCrisisOverrideReply(replyStyle = 'english') {
  if (replyStyle === 'urdu_script') {
    return (
      'مجھے بہت افسوس ہے کہ آپ اس طرح محسوس کر رہے ہیں۔ اگر آپ کو لگتا ہے کہ آپ خود کو نقصان پہنچا سکتے ہیں یا آپ فوری خطرے میں ہیں تو ابھی اپنی مقامی ایمرجنسی سروس سے رابطہ کریں۔\n\n' +
      '🇺🇸 US/Canada: 988 Suicide & Crisis Lifeline\n' +
      '🇬🇧 UK/ROI: Samaritans 116 123\n' +
      '🇵🇰 Pakistan: Umang 0311-7786264\n\n' +
      'اگر آپ چاہیں تو اپنا ملک بتا دیں، میں درست ہیلپ لائن شیئر کر دوں گا۔ کیا آپ اس وقت محفوظ ہیں؟'
    );
  }

  if (replyStyle === 'roman_urdu' || replyStyle === 'roman_punjabi') {
    return (
      'Mujhe bohat afsos hai ke aap is tarah feel kar rahe hain. Agar aap ko lagta hai ke aap khud ko nuqsan pohncha sakte hain ya aap foran danger mein hain, to abhi apni local emergency service ko call karein.\n\n' +
      '🇺🇸 US/Canada: 988 Suicide & Crisis Lifeline\n' +
      '🇬🇧 UK/ROI: Samaritans 116 123\n' +
      '🇵🇰 Pakistan: Umang 0311-7786264\n\n' +
      'Agar aap chahein to apna mulk bata dein aur main sahi helpline share kar doon. Kya aap is waqt safe hain?'
    );
  }

  if (replyStyle === 'mixed_english_roman') {
    return (
      "I'm really sorry you're feeling this way. Agar aap ko lagta hai ke aap khud ko hurt kar sakte hain ya aap immediate danger mein hain, please call your local emergency number right now.\n\n" +
      '🇺🇸 US/Canada: 988 Suicide & Crisis Lifeline\n' +
      '🇬🇧 UK/ROI: Samaritans 116 123\n' +
      '🇵🇰 Pakistan: Umang 0311-7786264\n\n' +
      'Agar aap apna country batayein to main sahi crisis contact share kar doon. Are you safe right now?'
    );
  }

  return (
    "I'm really sorry you're feeling this way. " +
    "If you're in immediate danger or might hurt yourself, please call your local emergency number right now.\n\n" +
    '🇺🇸 US/Canada: 988 Suicide & Crisis Lifeline\n' +
    '🇬🇧 UK/ROI: Samaritans 116 123\n' +
    '🇵🇰 Pakistan: Umang 0311-7786264\n\n' +
    "If you tell me your country, I'll share the right crisis contacts.\n\n" +
    'Are you safe right now?'
  );
}

function looksLikeCrisis(text = '') {
  const raw = String(text || '');
  const value = raw.toLowerCase();
  const keywords = [
    'suicide',
    'kill myself',
    'end my life',
    'self harm',
    'self-harm',
    'hurt myself',
    'want to die',
    'no reason to live',
    'end it all',
    'better off dead',
    'khudkushi',
    'khud kushi',
    'apni jaan',
    'jaan de',
    'mar jana',
    'mar jaon',
    'mar jaun',
    'mar jaunga',
    'mar jaungi',
    'mar gae to',
    'mar gaye to',
    'مرنا چاہتا',
    'مرنا چاہتی',
    'خودکشی',
    'اپنی جان',
    'جان دینا',
    'مجھے مرنا',
  ];
  return keywords.some((keyword) => value.includes(keyword));
}

function rateLimitKey(req) {
  return req.user?.uid || req.ip || 'anonymous';
}

function applyRateLimit(req, res, next) {
  const key = rateLimitKey(req);
  const now = Date.now();
  const bucket = rateBuckets.get(key);

  if (!bucket || now - bucket.windowStart >= RATE_LIMIT_WINDOW_MS) {
    rateBuckets.set(key, { windowStart: now, count: 1 });
    next();
    return;
  }

  if (bucket.count >= RATE_LIMIT_MAX_REQUESTS) {
    res
      .status(429)
      .json({ error: 'Too many requests. Please try again shortly.' });
    return;
  }

  bucket.count += 1;
  rateBuckets.set(key, bucket);
  next();
}

async function authenticateRequest(req, res, next) {
  if (ALLOW_UNAUTHENTICATED_LOCAL) {
    req.user = getLocalBypassUser();
    next();
    return;
  }

  if (!firebaseAdminReady) {
    res
      .status(503)
      .json({ error: 'Backend authentication is not configured.' });
    return;
  }

  const authorization = req.get('Authorization') || '';
  if (!authorization.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Authentication required.' });
    return;
  }

  const idToken = authorization.slice('Bearer '.length).trim();
  if (!idToken) {
    res.status(401).json({ error: 'Authentication required.' });
    return;
  }

  try {
    req.user = await admin.auth().verifyIdToken(idToken);
    next();
  } catch (error) {
    logWarn('Rejected invalid auth token', {
      reason: error.code || error.message,
    });
    res.status(401).json({ error: 'Invalid authentication token.' });
  }
}

async function fetchDocumentData(collectionName, documentId) {
  const snapshot = await firestoreDb()
    .collection(collectionName)
    .doc(documentId)
    .get();
  if (!snapshot.exists) {
    return null;
  }
  return { id: snapshot.id, ...snapshot.data() };
}

async function resolveActorContext(req) {
  if (req.actorContext) {
    return req.actorContext;
  }

  const uid = req.user?.uid;
  if (!uid) {
    throw createHttpError(401, 'authentication_required', 'Authentication required.');
  }

  const [userDoc, therapistProfile] = await Promise.all([
    fetchDocumentData('users', uid),
    fetchDocumentData('therapists', uid),
  ]);

  const role =
    parseExplicitAppRole(req.user?.role) ||
    parseExplicitAppRole(userDoc?.role) ||
    (therapistProfile ? 'therapist' : 'user');

  req.actorContext = {
    uid,
    role,
    email: req.user?.email || userDoc?.email || null,
    userDoc,
    therapistProfile,
    isApprovedTherapist: therapistProfile?.isApproved === true,
    displayName: userDoc?.name || req.user?.name || req.user?.email || uid,
  };
  return req.actorContext;
}

async function resolveAdminContext(req) {
  if (req.adminContext) {
    return req.adminContext;
  }

  const actor = await resolveActorContext(req);
  const adminProfile = await fetchDocumentData('admin_users', actor.uid);
  let roles = normalizeAdminRoles(
    req.user?.adminRoles || req.user?.adminRole || adminProfile?.roles,
  );

  if (
    roles.length === 0 &&
    ENABLE_ADMIN_BOOTSTRAP &&
    BOOTSTRAP_ADMIN_UIDS.includes(actor.uid)
  ) {
    roles = ['super_admin'];
  }

  if (adminProfile?.status === 'disabled') {
    throw createHttpError(
      403,
      'admin_access_disabled',
      'Admin access has been disabled for this account.',
    );
  }

  if (roles.length === 0) {
    throw createHttpError(
      403,
      'admin_access_required',
      'Administrator access is required.',
    );
  }

  req.adminContext = {
    ...actor,
    adminProfile,
    adminRoles: roles,
  };
  return req.adminContext;
}

async function requireAdmin(req, allowedRoles = null) {
  const adminContext = await resolveAdminContext(req);
  if (
    Array.isArray(allowedRoles) &&
    allowedRoles.length > 0 &&
    !adminContext.adminRoles.some((role) => allowedRoles.includes(role))
  ) {
    throw createHttpError(
      403,
      'insufficient_admin_permissions',
      'You do not have permission to perform this action.',
    );
  }
  return adminContext;
}

async function writeAdminAuditLog({
  actor,
  action,
  targetType,
  targetId,
  metadata = {},
}) {
  const payload = {
    actorId: actor.uid,
    actorRoles: actor.adminRoles || [],
    actorEmail: actor.email || null,
    action,
    targetType,
    targetId,
    metadata,
    createdAt: nowTimestamp(),
  };
  await firestoreDb().collection('admin_audit_logs').add(payload);
}

function serializeAppointmentSnapshot(snapshot) {
  const data = snapshot.data() || {};
  return {
    id: snapshot.id,
    userId: data.userId || null,
    therapistId: data.therapistId || null,
    status: String(data.status || 'requested').trim().toLowerCase(),
    scheduledAt: toIso(data.scheduledAt),
    scheduledEndAt: toIso(data.scheduledEndAt),
    updatedAt: toIso(data.updatedAt),
    createdAt: toIso(data.createdAt),
    meetingRoomId: data.meetingRoomId || null,
    userName: data.userName || null,
    therapistName: data.therapistName || null,
    slotId: data.slotId || null,
    timezone: data.timezone || null,
    decisionReason: data.decisionReason || null,
    confirmedAt: toIso(data.confirmedAt),
    rejectedAt: toIso(data.rejectedAt),
    cancelledAt: toIso(data.cancelledAt),
    completedAt: toIso(data.completedAt),
    noShowAt: toIso(data.noShowAt),
    statusUpdatedBy: data.statusUpdatedBy || null,
  };
}

function buildChatRoomId(userId, therapistId) {
  return [userId, therapistId].sort().join('_');
}

function buildCallRoomId(appointmentId) {
  return `call_${appointmentId}`;
}

function ensureParticipant(actorUid, appointment) {
  if (
    actorUid !== appointment.userId &&
    actorUid !== appointment.therapistId
  ) {
    throw createHttpError(
      403,
      'appointment_access_denied',
      'You do not have access to this appointment.',
    );
  }
}

function assertAppointmentTransition({ actorUid, appointment, nextStatus }) {
  const currentStatus = String(appointment.status || 'requested')
    .trim()
    .toLowerCase();

  if (currentStatus === nextStatus) {
    return { actorType: actorUid === appointment.userId ? 'user' : 'therapist' };
  }

  if (actorUid === appointment.userId) {
    if (
      nextStatus === 'cancelled' &&
      CANCELLABLE_STATUSES.has(currentStatus)
    ) {
      return { actorType: 'user' };
    }
    throw createHttpError(
      403,
      'invalid_appointment_transition',
      'Users can only cancel requested or confirmed appointments.',
    );
  }

  if (actorUid === appointment.therapistId) {
    if (
      currentStatus === 'requested' &&
      ['confirmed', 'rejected'].includes(nextStatus)
    ) {
      return { actorType: 'therapist' };
    }
    if (
      currentStatus === 'confirmed' &&
      ['completed', 'cancelled', 'no_show'].includes(nextStatus)
    ) {
      return { actorType: 'therapist' };
    }
    throw createHttpError(
      403,
      'invalid_appointment_transition',
      'Therapists cannot perform that transition from the current status.',
    );
  }

  throw createHttpError(
    403,
    'appointment_access_denied',
    'You do not have access to update this appointment.',
  );
}

function normalizeDecisionReason(value) {
  if (typeof value !== 'string') {
    return null;
  }
  const normalized = value.trim();
  return normalized.length > 0 ? normalized.slice(0, 500) : null;
}

function buildAppointmentStatusPatch({
  nextStatus,
  actorUid,
  reason = null,
}) {
  const patch = {
    status: nextStatus,
    updatedAt: nowTimestamp(),
    statusUpdatedBy: actorUid,
  };
  const timestampFieldByStatus = {
    confirmed: 'confirmedAt',
    rejected: 'rejectedAt',
    completed: 'completedAt',
    cancelled: 'cancelledAt',
    no_show: 'noShowAt',
  };
  const timestampField = timestampFieldByStatus[nextStatus];
  if (timestampField) {
    patch[timestampField] = nowTimestamp();
  }

  if (reason) {
    patch.decisionReason = reason;
  } else if (['confirmed', 'completed'].includes(nextStatus)) {
    patch.decisionReason = admin.firestore.FieldValue.delete();
  }

  return patch;
}

function serializeScheduleSlot(snapshot) {
  const data = snapshot.data() || {};
  return {
    slotId: snapshot.id,
    therapistId: data.therapistId || null,
    dateKey: data.dateKey || null,
    timezone: data.timezone || null,
    status: typeof data.status === 'string' ? data.status : 'open',
    appointmentId: data.appointmentId || null,
    heldUntil: asDate(data.heldUntil),
    startAt: asDate(data.startAt),
    endAt: asDate(data.endAt),
    startTime: data.startTime || null,
    endTime: data.endTime || null,
    blockedReason: data.blockedReason || null,
    createdAt: asDate(data.createdAt),
  };
}

function scheduleSettingsFromTherapistData(data = {}) {
  return normalizeScheduleSettings({
    timezone: data.timezone,
    acceptingNewPatients: data.acceptingNewPatients,
    sessionDurationMinutes: data.sessionDurationMinutes,
    bufferMinutes: data.bufferMinutes,
  });
}

async function syncPublicTherapistDirectory(therapistId, therapistData) {
  if (!therapistData) {
    return;
  }

  const publicRef = firestoreDb().collection('public_therapists').doc(therapistId);
  const publicSnapshot = await publicRef.get();
  const nextAvailableAt = asDate(therapistData.nextAvailableAt);

  if (
    therapistData.isApproved !== true ||
    therapistData.credentialVerificationStatus !== 'verified'
  ) {
    if (publicSnapshot.exists) {
      await publicRef.delete();
    }
    return;
  }

  const payload = {
    therapistId,
    userId: therapistData.userId || therapistId,
    displayName: therapistData.displayName || therapistData.name || 'Therapist',
    professionalTitle: therapistData.professionalTitle || null,
    specialty: therapistData.specialty || null,
    yearsExperience: Number(therapistData.yearsExperience || 0) || 0,
    pricePerSession: Number(therapistData.pricePerSession || 0) || 0,
    bio: therapistData.bio || null,
    rating:
      typeof therapistData.rating === 'number'
        ? therapistData.rating
        : Number(therapistData.rating || 0) || 0,
    acceptingNewPatients: therapistData.acceptingNewPatients !== false,
    nextAvailableAt: nextAvailableAt || null,
    isApproved: true,
    credentialVerificationStatus: 'verified',
    verifiedAt:
      therapistData.credentialVerifiedAt || therapistData.reviewedAt || nowTimestamp(),
    updatedAt: nowTimestamp(),
    createdAt:
      publicSnapshot.data()?.createdAt ||
      therapistData.createdAt ||
      nowTimestamp(),
  };

  await publicRef.set(payload, { merge: true });
}

async function releaseExpiredPendingRequests(therapistId) {
  const therapistRef = firestoreDb().collection('therapists').doc(therapistId);
  const snapshot = await therapistRef.collection('bookable_slots').get();
  const now = new Date();
  const expiredSlots = snapshot.docs
    .map((doc) => ({ ref: doc.ref, data: serializeScheduleSlot(doc) }))
    .filter(
      (entry) =>
        entry.data.status === 'pending_request' &&
        entry.data.heldUntil instanceof Date &&
        entry.data.heldUntil.getTime() <= now.getTime(),
    );

  if (expiredSlots.length === 0) {
    return 0;
  }

  const batch = firestoreDb().batch();
  for (const entry of expiredSlots) {
    batch.set(
      entry.ref,
      {
        status: 'open',
        appointmentId: admin.firestore.FieldValue.delete(),
        heldUntil: admin.firestore.FieldValue.delete(),
        blockedReason: admin.firestore.FieldValue.delete(),
        updatedAt: nowTimestamp(),
      },
      { merge: true },
    );

    if (entry.data.appointmentId) {
      const appointmentRef = firestoreDb()
        .collection('appointments')
        .doc(entry.data.appointmentId);
      batch.set(
        appointmentRef,
        {
          status: 'cancelled',
          decisionReason: 'Request expired before therapist review.',
          cancelledAt: nowTimestamp(),
          updatedAt: nowTimestamp(),
        },
        { merge: true },
      );
    }
  }

  await batch.commit();
  return expiredSlots.length;
}

async function loadTherapistSchedulingState(therapistId) {
  const therapistRef = firestoreDb().collection('therapists').doc(therapistId);
  const [therapistSnapshot, rulesSnapshot, exceptionsSnapshot, slotsSnapshot] =
    await Promise.all([
      therapistRef.get(),
      therapistRef.collection('availability_rules').get(),
      therapistRef.collection('availability_exceptions').get(),
      therapistRef.collection('bookable_slots').get(),
    ]);

  if (!therapistSnapshot.exists) {
    throw createHttpError(404, 'therapist_not_found', 'Therapist not found.');
  }

  const therapistData = therapistSnapshot.data() || {};
  const settings = scheduleSettingsFromTherapistData(therapistData);
  const weeklyRules = normalizeWeeklyRules(
    rulesSnapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
  );
  const exceptions = normalizeAvailabilityExceptions(
    exceptionsSnapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
    settings.timezone,
  );
  const existingSlots = new Map(
    slotsSnapshot.docs.map((doc) => [doc.id, serializeScheduleSlot(doc)]),
  );

  return {
    therapistRef,
    therapistData,
    settings,
    weeklyRules,
    exceptions,
    existingSlots,
  };
}

async function materializeTherapistSlots(therapistId) {
  await releaseExpiredPendingRequests(therapistId);

  const {
    therapistRef,
    therapistData,
    settings,
    weeklyRules,
    exceptions,
    existingSlots,
  } = await loadTherapistSchedulingState(therapistId);

  const startDateKey = buildDateKeyFromDate(new Date(), settings.timezone);
  const generatedSlots = generateSlotsForDateRange({
    timezone: settings.timezone,
    weeklyRules,
    exceptions,
    sessionDurationMinutes: settings.sessionDurationMinutes,
    bufferMinutes: settings.bufferMinutes,
    startDateKey,
    horizonDays: SLOT_HORIZON_DAYS,
    existingSlots,
  });

  const generatedIds = new Set(generatedSlots.map((slot) => slot.slotId));
  const batch = firestoreDb().batch();
  for (const slot of generatedSlots) {
    const slotPayload = {
      therapistId,
      dateKey: slot.dateKey,
      timezone: slot.timezone,
      startAt: slot.startAt,
      endAt: slot.endAt,
      startTime: slot.startTime,
      endTime: slot.endTime,
      status: slot.status,
      blockedReason: admin.firestore.FieldValue.delete(),
      updatedAt: nowTimestamp(),
      createdAt:
        existingSlots.get(slot.slotId)?.createdAt || nowTimestamp(),
    };
    slotPayload.appointmentId =
      slot.appointmentId || admin.firestore.FieldValue.delete();
    slotPayload.heldUntil =
      slot.heldUntil || admin.firestore.FieldValue.delete();
    batch.set(
      therapistRef.collection('bookable_slots').doc(slot.slotId),
      slotPayload,
      { merge: true },
    );
  }

  for (const [slotId, slot] of existingSlots.entries()) {
    if (generatedIds.has(slotId)) {
      continue;
    }

    if (ACTIVE_SLOT_STATUSES.has(slot.status)) {
      continue;
    }

    batch.set(
      therapistRef.collection('bookable_slots').doc(slotId),
      {
        status: 'blocked',
        appointmentId: admin.firestore.FieldValue.delete(),
        heldUntil: admin.firestore.FieldValue.delete(),
        blockedReason: 'outside_schedule',
        updatedAt: nowTimestamp(),
      },
      { merge: true },
    );
  }

  const nextAvailableAt = computeNextAvailableAt(generatedSlots);
  batch.set(
    therapistRef,
    {
      timezone: settings.timezone,
      acceptingNewPatients: settings.acceptingNewPatients,
      sessionDurationMinutes: settings.sessionDurationMinutes,
      bufferMinutes: settings.bufferMinutes,
      nextAvailableAt: nextAvailableAt || null,
      updatedAt: nowTimestamp(),
    },
    { merge: true },
  );
  await batch.commit();

  await syncPublicTherapistDirectory(therapistId, {
    ...therapistData,
    ...settings,
    nextAvailableAt,
  });

  return {
    therapistId,
    therapistData,
    settings,
    weeklyRules,
    exceptions,
    nextAvailableAt: nextAvailableAt ? nextAvailableAt.toISOString() : null,
    generatedSlots,
  };
}

async function resolveConversationPair(actor, counterpartId) {
  const normalizedCounterpartId = ensureNonEmptyString(
    counterpartId,
    'counterpartId',
  );
  if (normalizedCounterpartId === actor.uid) {
    throw createHttpError(
      400,
      'validation_error',
      'counterpartId must be a different account.',
    );
  }

  const [counterpartUser, counterpartTherapistProfile] = await Promise.all([
    fetchDocumentData('users', normalizedCounterpartId),
    fetchDocumentData('therapists', normalizedCounterpartId),
  ]);

  const counterpartRole = counterpartTherapistProfile
    ? 'therapist'
    : normalizeAppRole(counterpartUser?.role);

  if (actor.role === 'therapist') {
    if (!actor.isApprovedTherapist) {
      throw createHttpError(
        403,
        'therapist_not_approved',
        'Only approved therapists can message or call patients.',
      );
    }
    if (counterpartRole !== 'user') {
      throw createHttpError(
        400,
        'validation_error',
        'Therapists can only open patient communication rooms.',
      );
    }
    return {
      userId: normalizedCounterpartId,
      therapistId: actor.uid,
      counterpartUser,
      counterpartTherapistProfile,
    };
  }

  if (actor.role !== 'user') {
    throw createHttpError(
      403,
      'unsupported_role',
      'This account cannot create communication rooms.',
    );
  }

  if (
    counterpartRole !== 'therapist' ||
    counterpartTherapistProfile?.isApproved !== true
  ) {
    throw createHttpError(
      403,
      'therapist_not_approved',
      'Only approved therapists can be contacted.',
    );
  }

  return {
    userId: actor.uid,
    therapistId: normalizedCounterpartId,
    counterpartUser,
    counterpartTherapistProfile,
  };
}

async function loadRelationshipSummary(userId, therapistId) {
  const cacheKey = `${userId}:${therapistId}`;
  const cached = getCachedValue(relationshipSummaryCache, cacheKey);
  if (cached) {
    return cached;
  }

  const snapshot = await firestoreDb()
    .collection('appointments')
    .where('userId', '==', userId)
    .limit(36)
    .get();

  const appointments = snapshot.docs
    .map((doc) => serializeAppointmentSnapshot(doc))
    .filter((appointment) => appointment.therapistId === therapistId)
    .sort((left, right) => {
      const leftTime =
        asDate(left.scheduledAt || left.updatedAt || left.createdAt)?.valueOf() ||
        0;
      const rightTime =
        asDate(right.scheduledAt || right.updatedAt || right.createdAt)?.valueOf() ||
        0;
      return rightTime - leftTime;
    });

  const latestAppointment = appointments[0] || null;
  const latestActiveAppointment =
    appointments.find((appointment) =>
      ACTIVE_APPOINTMENT_STATUSES.has(appointment.status),
    ) || null;
  const callEligibleAppointment =
    appointments.find((appointment) =>
      CALL_ELIGIBLE_STATUSES.has(appointment.status),
    ) || null;

  return setCachedValue(relationshipSummaryCache, cacheKey, {
    appointments,
    latestAppointment,
    latestActiveAppointment,
    callEligibleAppointment,
    hasAnyRelationship: appointments.length > 0,
    canCall: Boolean(callEligibleAppointment),
  }, RELATIONSHIP_CACHE_TTL_MS);
}

async function ensureAppointmentCallRoomDocument({
  appointmentId,
  audioOnly = false,
}) {
  if (IS_PRODUCTION && !hasTurnConfiguration()) {
    throw createHttpError(
      503,
      'calling_unavailable',
      'Calling is unavailable until TURN credentials are configured.',
    );
  }

  const appointmentRef = firestoreDb().collection('appointments').doc(appointmentId);
  const appointmentSnapshot = await appointmentRef.get();
  if (!appointmentSnapshot.exists) {
    throw createHttpError(
      404,
      'appointment_not_found',
      'Appointment not found.',
    );
  }

  const appointment = serializeAppointmentSnapshot(appointmentSnapshot);
  if (!CALL_ELIGIBLE_STATUSES.has(appointment.status)) {
    throw createHttpError(
      403,
      'appointment_not_call_ready',
      'Calls are only available after an appointment is confirmed.',
    );
  }

  const cacheKey = `${appointmentId}:${audioOnly ? 'audio' : 'video'}`;
  const cached = getCachedValue(callRoomCache, cacheKey);
  if (cached && cached.status === appointment.status) {
    return cached;
  }

  const roomId = appointment.meetingRoomId || buildCallRoomId(appointmentId);
  const participants = [appointment.userId, appointment.therapistId]
    .filter(Boolean)
    .sort();
  const roomRef = firestoreDb().collection('calls').doc(roomId);
  const existingRoom = await roomRef.get();
  const basePayload = {
    userId: appointment.userId,
    therapistId: appointment.therapistId,
    appointmentId,
    participants,
    audioOnly: Boolean(audioOnly),
    updatedAt: nowTimestamp(),
  };
  if (!existingRoom.exists) {
    await roomRef.set({
      ...basePayload,
      status: 'ready',
      createdAt: nowTimestamp(),
    });
  } else {
    await roomRef.set(basePayload, { merge: true });
  }

  if (!appointment.meetingRoomId) {
    await appointmentRef.set(
      {
        meetingRoomId: roomId,
        updatedAt: nowTimestamp(),
      },
      { merge: true },
    );
  }

  return setCachedValue(callRoomCache, cacheKey, {
    roomId,
    appointmentId,
    status: appointment.status,
  }, ROOM_CACHE_TTL_MS);
}

async function recordAIIncident({
  title,
  severity = 'medium',
  category,
  uid = null,
  source = 'backend',
  metadata = {},
}) {
  try {
    await firestoreDb().collection('ai_incidents').add({
      title,
      severity,
      status: 'open',
      category,
      userId: uid,
      source,
      assignedTo: null,
      opsNotes: null,
      metadata,
      createdAt: nowTimestamp(),
      updatedAt: nowTimestamp(),
    });
  } catch (error) {
    logWarn('Failed to persist AI incident', {
      category,
      uid,
      reason: error.message,
    });
  }
}

function requireRecentAuthentication(req, purpose) {
  const authTimeSeconds = Number(req.user?.auth_time || 0);
  if (!Number.isFinite(authTimeSeconds) || authTimeSeconds <= 0) {
    throw createHttpError(
      401,
      'recent_login_required',
      `Please sign in again before ${purpose}.`,
    );
  }

  const ageSeconds = Math.floor(Date.now() / 1000) - authTimeSeconds;
  if (ageSeconds > RECENT_AUTH_WINDOW_SECONDS) {
    throw createHttpError(
      401,
      'recent_login_required',
      `Please sign in again before ${purpose}.`,
      { ageSeconds, maxAgeSeconds: RECENT_AUTH_WINDOW_SECONDS },
    );
  }
}

function serializeExportValue(value) {
  if (Array.isArray(value)) {
    return value.map((entry) => serializeExportValue(entry));
  }

  if (value && typeof value === 'object') {
    if (typeof value.toDate === 'function') {
      return toIso(value);
    }

    const serialized = {};
    for (const [key, entry] of Object.entries(value)) {
      serialized[key] = serializeExportValue(entry);
    }
    return serialized;
  }

  return value ?? null;
}

function csvEscape(value) {
  const text = String(value ?? '');
  return `"${text.replace(/"/g, '""')}"`;
}

function exportDateSuffix() {
  const now = new Date();
  return `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(
    2,
    '0',
  )}-${String(now.getUTCDate()).padStart(2, '0')}`;
}

async function createDataRightsJob({
  userId,
  type,
  actor,
  requestSource = 'mobile_app',
}) {
  const jobRef = firestoreDb().collection('data_rights_jobs').doc();
  await jobRef.set({
    userId,
    type,
    status: 'processing',
    opsStatus: 'open',
    requestSource,
    requestedBy: actor.uid,
    requesterEmail: actor.email || null,
    requesterDisplayName: actor.displayName || actor.email || actor.uid,
    requesterRole: actor.role,
    createdAt: nowTimestamp(),
    updatedAt: nowTimestamp(),
  });
  return jobRef;
}

async function markDataRightsJob(jobRef, patch) {
  await jobRef.set(
    {
      ...patch,
      updatedAt: nowTimestamp(),
    },
    { merge: true },
  );
}

function getStorageBucket() {
  const bucketName =
    process.env.FIREBASE_STORAGE_BUCKET || admin.app().options.storageBucket;
  if (!bucketName) {
    return null;
  }
  return admin.storage().bucket(bucketName);
}

async function deleteStoragePrefix(prefix) {
  const bucket = getStorageBucket();
  if (!bucket) {
    return {
      deletedFiles: 0,
      warnings: ['storage_bucket_not_configured'],
    };
  }

  try {
    const [files] = await bucket.getFiles({ prefix });
    if (!files.length) {
      return { deletedFiles: 0, warnings: [] };
    }

    await Promise.all(
      files.map((file) =>
        file.delete({ ignoreNotFound: true }).catch(() => undefined),
      ),
    );
    return { deletedFiles: files.length, warnings: [] };
  } catch (error) {
    return {
      deletedFiles: 0,
      warnings: [error.message || 'storage_cleanup_failed'],
    };
  }
}

async function deleteDocumentRefs(refs) {
  if (!refs.length) {
    return 0;
  }

  let deleted = 0;
  for (let index = 0; index < refs.length; index += 400) {
    const batch = firestoreDb().batch();
    const chunk = refs.slice(index, index + 400);
    chunk.forEach((ref) => batch.delete(ref));
    await batch.commit();
    deleted += chunk.length;
  }
  return deleted;
}

function uniqueDocsById(...snapshots) {
  const docsById = new Map();
  snapshots.forEach((snapshot) => {
    snapshot?.docs?.forEach((doc) => {
      docsById.set(doc.id, doc);
    });
  });
  return Array.from(docsById.values());
}

async function deleteCallRoomById(roomId) {
  const roomRef = firestoreDb().collection('calls').doc(roomId);
  const [callerCandidates, calleeCandidates] = await Promise.all([
    roomRef.collection('callerCandidates').get(),
    roomRef.collection('calleeCandidates').get(),
  ]);

  await deleteDocumentRefs(callerCandidates.docs.map((doc) => doc.ref));
  await deleteDocumentRefs(calleeCandidates.docs.map((doc) => doc.ref));

  try {
    await roomRef.delete();
  } catch (_) {
    // Missing rooms should not fail the whole delete job.
  }

  return {
    callerCandidates: callerCandidates.size,
    calleeCandidates: calleeCandidates.size,
  };
}

async function deleteTherapistChatRoomById(roomId) {
  const roomRef = firestoreDb().collection('therapist_chats').doc(roomId);
  const messages = await roomRef.collection('messages').get();
  const deletedMessages = await deleteDocumentRefs(
    messages.docs.map((doc) => doc.ref),
  );
  const storageCleanup = await deleteStoragePrefix(`therapist_chats/${roomId}`);

  try {
    await roomRef.delete();
  } catch (_) {
    // Best effort.
  }

  return {
    deletedMessages,
    deletedFiles: storageCleanup.deletedFiles,
    warnings: storageCleanup.warnings,
  };
}

async function buildUserExportBundle(userId) {
  const db = firestoreDb();
  const [userSnapshot, moodSnapshot, aiChatSnapshot, appointmentSnapshot, chatRooms, callRooms] =
    await Promise.all([
      db.collection('users').doc(userId).get(),
      db.collection('moods').where('userId', '==', userId).get(),
      db.collection('chats').where('userId', '==', userId).get(),
      db.collection('appointments').where('userId', '==', userId).get(),
      db.collection('therapist_chats').where('userId', '==', userId).get(),
      db.collection('calls').where('userId', '==', userId).get(),
    ]);

  const therapistChatBundles = await Promise.all(
    chatRooms.docs.map(async (roomDoc) => {
      const messagesSnapshot = await roomDoc.ref.collection('messages').get();
      return {
        id: roomDoc.id,
        ...serializeExportValue(roomDoc.data()),
        messages: messagesSnapshot.docs.map((messageDoc) => ({
          id: messageDoc.id,
          ...serializeExportValue(messageDoc.data()),
        })),
      };
    }),
  );

  const moods = moodSnapshot.docs
    .map((doc) => ({ id: doc.id, ...serializeExportValue(doc.data()) }))
    .sort((left, right) => {
      const leftTime = asDate(
        left.selectedDate || left.createdAt || left.timestamp,
      )?.valueOf() || 0;
      const rightTime = asDate(
        right.selectedDate || right.createdAt || right.timestamp,
      )?.valueOf() || 0;
      return rightTime - leftTime;
    });

  const csvRows = [
    ['date', 'time', 'mood', 'intensity', 'note'].join(','),
    ...moods.map((entry) => {
      const timestamp = asDate(
        entry.selectedDate || entry.createdAt || entry.timestamp,
      );
      const date = timestamp
        ? timestamp.toISOString().slice(0, 10)
        : '';
      const time = timestamp
        ? timestamp.toISOString().slice(11, 16)
        : '';
      return [
        csvEscape(date),
        csvEscape(time),
        csvEscape(entry.mood || ''),
        csvEscape(entry.intensity || ''),
        csvEscape(entry.note || ''),
      ].join(',');
    }),
  ].join('\n');

  const exportPayload = {
    generatedAt: new Date().toISOString(),
    exportVersion: 1,
    profile: userSnapshot.exists
      ? {
          id: userSnapshot.id,
          ...serializeExportValue(userSnapshot.data()),
        }
      : null,
    moods,
    aiChats: aiChatSnapshot.docs.map((doc) => ({
      id: doc.id,
      ...serializeExportValue(doc.data()),
    })),
    appointments: appointmentSnapshot.docs.map((doc) => ({
      id: doc.id,
      ...serializeExportValue(doc.data()),
    })),
    therapistChats: therapistChatBundles,
    callHistory: callRooms.docs.map((doc) => ({
      id: doc.id,
      ...serializeExportValue(doc.data()),
    })),
  };

  return {
    fileName: `moodgenie_export_${exportDateSuffix()}.json`,
    mimeType: 'application/json',
    contentBase64: Buffer.from(
      JSON.stringify(exportPayload, null, 2),
      'utf8',
    ).toString('base64'),
    summary: {
      moodEntries: moodSnapshot.size,
      aiChats: aiChatSnapshot.size,
      appointments: appointmentSnapshot.size,
      therapistChats: chatRooms.size,
      callRooms: callRooms.size,
      therapistChatMessages: therapistChatBundles.reduce(
        (count, room) => count + room.messages.length,
        0,
      ),
      moodCsvBase64: Buffer.from(csvRows, 'utf8').toString('base64'),
    },
  };
}

async function deleteUserAccountData(userId) {
  const db = firestoreDb();
  const [
    moods,
    chats,
    userAppointments,
    therapistAppointments,
    userTherapistChatRooms,
    therapistTherapistChatRooms,
    userCallRooms,
    therapistCallRooms,
  ] = await Promise.all([
    db.collection('moods').where('userId', '==', userId).get(),
    db.collection('chats').where('userId', '==', userId).get(),
    db.collection('appointments').where('userId', '==', userId).get(),
    db.collection('appointments').where('therapistId', '==', userId).get(),
    db.collection('therapist_chats').where('userId', '==', userId).get(),
    db.collection('therapist_chats').where('therapistId', '==', userId).get(),
    db.collection('calls').where('userId', '==', userId).get(),
    db.collection('calls').where('therapistId', '==', userId).get(),
  ]);

  const appointments = uniqueDocsById(userAppointments, therapistAppointments);
  const therapistChatRooms = uniqueDocsById(
    userTherapistChatRooms,
    therapistTherapistChatRooms,
  );
  const callRooms = uniqueDocsById(userCallRooms, therapistCallRooms);

  const summary = {
    moods: 0,
    aiChats: 0,
    appointments: 0,
    therapistChatRooms: 0,
    therapistChatMessages: 0,
    callRooms: 0,
    callCandidates: 0,
    deletedStorageFiles: 0,
    warnings: [],
  };

  summary.moods = await deleteDocumentRefs(moods.docs.map((doc) => doc.ref));
  summary.aiChats = await deleteDocumentRefs(chats.docs.map((doc) => doc.ref));

  for (const roomDoc of therapistChatRooms) {
    const roomSummary = await deleteTherapistChatRoomById(roomDoc.id);
    summary.therapistChatRooms += 1;
    summary.therapistChatMessages += roomSummary.deletedMessages;
    summary.deletedStorageFiles += roomSummary.deletedFiles;
    summary.warnings.push(...roomSummary.warnings);
  }

  const roomIds = new Set(callRooms.map((doc) => doc.id).filter(Boolean));
  appointments.forEach((doc) => {
    const roomId = doc.data()?.meetingRoomId;
    if (typeof roomId === 'string' && roomId.trim()) {
      roomIds.add(roomId.trim());
    }
  });

  for (const roomId of roomIds) {
    const roomSummary = await deleteCallRoomById(roomId);
    summary.callRooms += 1;
    summary.callCandidates +=
      roomSummary.callerCandidates + roomSummary.calleeCandidates;
  }

  summary.appointments = await deleteDocumentRefs(
    appointments.map((doc) => doc.ref),
  );

  try {
    const therapistRef = db.collection('therapists').doc(userId);
    const publicTherapistRef = db.collection('public_therapists').doc(userId);
    const [availabilityRules, availabilityExceptions, bookableSlots] =
      await Promise.all([
        therapistRef.collection('availability_rules').get(),
        therapistRef.collection('availability_exceptions').get(),
        therapistRef.collection('bookable_slots').get(),
      ]);

    await deleteDocumentRefs(availabilityRules.docs.map((doc) => doc.ref));
    await deleteDocumentRefs(availabilityExceptions.docs.map((doc) => doc.ref));
    await deleteDocumentRefs(bookableSlots.docs.map((doc) => doc.ref));

    await Promise.allSettled([
      therapistRef.delete(),
      publicTherapistRef.delete(),
    ]);
  } catch (_) {
    summary.warnings.push('therapist_profile_cleanup_failed');
  }

  try {
    await db
      .collection('users')
      .doc(userId)
      .set({ consentedTherapists: [] }, { merge: true });
  } catch (_) {
    summary.warnings.push('consent_cleanup_failed');
  }

  try {
    await notificationServices.revokeUserNotificationData(userId);
  } catch (_) {
    summary.warnings.push('notification_cleanup_failed');
  }

  try {
    await db.collection('users').doc(userId).delete();
  } catch (_) {
    summary.warnings.push('user_profile_delete_failed');
  }

  await admin.auth().deleteUser(userId);

  return summary;
}

async function fetchOllamaResponse(messages) {
  const startedAt = Date.now();

  try {
    const response = await fetch(`${OLLAMA_URL}/api/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      signal: AbortSignal.timeout(OLLAMA_CHAT_TIMEOUT_MS),
      body: JSON.stringify({
        model: OLLAMA_MODEL,
        messages,
        stream: false,
        options: {
          num_predict: OLLAMA_NUM_PREDICT,
          temperature: OLLAMA_TEMPERATURE,
          repeat_penalty: OLLAMA_REPEAT_PENALTY,
        },
      }),
    });

    const elapsedMs = Date.now() - startedAt;

    if (!response.ok) {
      throw createHttpError(
        502,
        'ollama_upstream_error',
        `Ollama returned status ${response.status}.`,
        {
          elapsedMs,
          timeoutMs: OLLAMA_CHAT_TIMEOUT_MS,
          upstreamStatus: response.status,
          model: OLLAMA_MODEL,
        },
      );
    }

    const payload = await response.json();
    return { payload, elapsedMs };
  } catch (error) {
    const elapsedMs = Date.now() - startedAt;

    if (error?.status) {
      throw error;
    }

    throw toOllamaRequestError(error, elapsedMs);
  }
}

async function generateAiWellnessCopy({
  type,
  forecast,
  preferences,
  userDoc,
}) {
  const prompt = [
    'You write push notification copy for a mental-wellness app.',
    'Return exactly two lines.',
    'Line 1 starts with TITLE: and contains at most 60 characters.',
    'Line 2 starts with BODY: and contains at most 180 characters.',
    'Do not mention diagnosis, self-harm, suicide, therapy notes, or medical certainty.',
    'Do not claim certainty about the future. Use supportive but direct language.',
    `Notification type: ${type}`,
    `Quote tone: ${preferences.quoteTone}`,
    `Prediction style: ${preferences.predictionStyle}`,
    `Forecast mood band: ${forecast?.predictedMoodBand || 'unknown'}`,
    `Forecast confidence: ${forecast?.confidence ?? 'unknown'}`,
    `Support need level: ${forecast?.supportNeedLevel || 'unknown'}`,
    `Reason codes: ${(forecast?.reasonCodes || []).join(', ') || 'none'}`,
    `User locale: ${preferences.locale || userDoc?.locale || 'en'}`,
    `Timezone: ${preferences.timezone || userDoc?.timezone || 'UTC'}`,
  ].join('\n');

  const { payload } = await fetchOllamaResponse([
    {
      role: 'system',
      content:
        'You generate safe, concise notification copy for a wellness app. Follow every constraint exactly.',
    },
    {
      role: 'user',
      content: prompt,
    },
  ]);
  const content = String(payload?.message?.content || '').trim();
  const titleMatch = content.match(/TITLE:\s*(.+)/i);
  const bodyMatch = content.match(/BODY:\s*(.+)/i);
  if (!titleMatch || !bodyMatch) {
    throw new Error('invalid_ai_notification_copy');
  }
  return {
    title: titleMatch[1].trim(),
    body: bodyMatch[1].trim(),
  };
}

const notificationServices = createNotificationServices({
  db: firestoreDb,
  admin,
  createHttpError,
  nowTimestamp,
  logInfo,
  logWarn,
  logError,
  aiCopyGenerator: generateAiWellnessCopy,
});

function requireInternalJobAuth(req) {
  if (!INTERNAL_JOB_SECRET) {
    throw createHttpError(
      503,
      'internal_jobs_not_configured',
      'Internal job authentication is not configured.',
    );
  }

  const header =
    req.get('x-internal-job-key') ||
    (req.get('authorization') || '').replace(/^Bearer\s+/i, '').trim();

  if (header !== INTERNAL_JOB_SECRET) {
    throw createHttpError(
      403,
      'internal_job_auth_failed',
      'Internal job authentication failed.',
    );
  }
}

app.use((_, res, next) => {
  res.setHeader('Cache-Control', 'no-store');
  next();
});

app.get(
  '/api/health',
  asyncRoute(async (_, res) => {
    const turnConfigured = hasTurnConfiguration();
    try {
      const ollamaRes = await fetch(`${OLLAMA_URL}/api/tags`, {
        signal: AbortSignal.timeout(3000),
      });

      if (!ollamaRes.ok) {
        res.json(
          buildBackendHealthPayload({
            ollamaReachable: false,
            turnConfigured,
            details: `ollama_tags_${ollamaRes.status}`,
          }),
        );
        return;
      }

      const payload = await ollamaRes.json();
      const models = Array.isArray(payload?.models) ? payload.models : [];
      const modelReady = models.some((entry) =>
        ollamaTagMatchesConfiguredModel(entry?.name, OLLAMA_MODEL),
      );

      res.json(
        buildBackendHealthPayload({
          ollamaReachable: true,
          modelReady,
          turnConfigured,
          details:
            !modelReady
              ? `Configured model "${OLLAMA_MODEL}" is not installed in Ollama.`
              : !turnConfigured && IS_PRODUCTION
              ? 'TURN credentials are required for production calling readiness.'
              : undefined,
        }),
      );
    } catch (error) {
      res.json(
        buildBackendHealthPayload({
          ollamaReachable: false,
          turnConfigured,
          details: error.message,
        }),
      );
    }
  }),
);

app.post(
  '/api/chat',
  authenticateRequest,
  applyRateLimit,
  asyncRoute(async (req, res) => {
    const requestStartedAt = Date.now();
    const actor = await resolveActorContext(req);
    const userMessage =
      typeof req.body?.userMessage === 'string'
        ? req.body.userMessage.trim()
        : '';
    const history = sanitizeHistory(req.body?.history);
    const preferredLocale = actor.userDoc?.locale || 'en';
    const replyStyle = inferChatReplyStyle(userMessage, preferredLocale);
    const screenContext = normalizeScreenContext(req.body?.screenContext);
    const screenInstruction = buildScreenContextInstruction(screenContext);

    if (!userMessage) {
      throw createHttpError(400, 'validation_error', 'userMessage is required.');
    }

    if (userMessage.length > MAX_MESSAGE_LENGTH) {
      throw createHttpError(
        400,
        'validation_error',
        `userMessage exceeds ${MAX_MESSAGE_LENGTH} characters.`,
      );
    }

    if (looksLikeCrisis(userMessage)) {
      await recordAIIncident({
        title: 'Crisis language detected in AI chat',
        severity: 'high',
        category: 'crisis_language',
        uid: actor.uid || null,
        source: 'mobile_chat',
        metadata: {
          source: 'mobile_chat',
          replyStyle,
        },
      });
      res.json({
        ok: true,
        reply: buildCrisisOverrideReply(replyStyle),
        mode: 'crisis_override',
      });
      return;
    }

    if (looksLikeDiagnosisRequest(userMessage)) {
      res.json({
        ok: true,
        reply: buildDiagnosisOverrideReply(replyStyle),
        mode: 'diagnosis_override',
      });
      return;
    }

    if (looksLikeMedicineRequest(userMessage)) {
      res.json({
        ok: true,
        reply: buildMedicineOverrideReply(replyStyle),
        mode: 'medicine_override',
      });
      return;
    }

    if (shouldUseGuidedWellnessReply(userMessage, screenContext)) {
      res.json({
        ok: true,
        reply: buildGuidedWellnessReply({
          userMessage,
          replyStyle,
          screenContext,
        }),
        mode: 'guided_support',
      });
      return;
    }

    const messages = [
      {
        role: 'system',
        content: buildChatSystemPrompt({ preferredLocale, replyStyle }),
      },
      ...buildChatFewShotMessages(),
      ...(screenInstruction
        ? [{ role: 'system', content: screenInstruction }]
        : []),
      { role: 'system', content: buildChatFinalInstruction() },
      ...history,
      { role: 'user', content: userMessage },
    ];
    try {
      let { payload, elapsedMs } = await fetchOllamaResponse(messages);
      let reply = String(payload?.message?.content || '').trim();

      if (reply && isLikelyTruncatedReply(reply)) {
        const retryMessages = [
          {
            role: 'system',
            content:
              `${buildChatSystemPrompt({ preferredLocale, replyStyle })}\n` +
              'Your previous response was cut off. Regenerate the full answer from scratch in one short paragraph, under 80 words, and end with final punctuation.',
          },
          ...buildChatFewShotMessages(),
          ...(screenInstruction
            ? [{ role: 'system', content: screenInstruction }]
            : []),
          { role: 'system', content: buildChatFinalInstruction() },
          ...history,
          { role: 'user', content: userMessage },
        ];

        const retried = await fetchOllamaResponse(retryMessages);
        payload = retried.payload;
        elapsedMs += retried.elapsedMs;
        reply = String(payload?.message?.content || '').trim();
      }

      if (!reply) {
        throw new Error('empty_model_response');
      }

      const usedGuardedFallback = looksLikeLowQualityChatReply(
        userMessage,
        reply,
      );

      if (usedGuardedFallback) {
        reply = buildGuidedWellnessReply({
          userMessage,
          replyStyle,
          screenContext,
        });
      }

      logInfo('Chat response generated', {
        uid: actor.uid,
        historyLength: history.length,
        replyStyle,
        preferredLocale,
        screenContext,
        mode: usedGuardedFallback ? 'guarded_fallback' : 'live',
        ollamaElapsedMs: elapsedMs,
        totalElapsedMs: Date.now() - requestStartedAt,
        timeoutMs: OLLAMA_CHAT_TIMEOUT_MS,
      });

      res.json({
        ok: true,
        reply,
        mode: usedGuardedFallback ? 'guarded_fallback' : 'live',
      });
    } catch (error) {
      await recordAIIncident({
        title: 'AI backend request failed',
        severity: 'medium',
        category: 'backend_failure',
        uid: actor.uid || null,
        source: 'mobile_chat',
        metadata: {
          reason: error.message,
          replyStyle,
          preferredLocale,
          screenContext,
        },
      });

      const normalized =
        error?.status && error?.code
          ? error
          : toOllamaRequestError(error, null);

      logWarn('Chat response degraded', {
        uid: req.user?.uid,
        historyLength: history.length,
        totalElapsedMs: Date.now() - requestStartedAt,
        code: normalized.code || 'ollama_unavailable',
      });

      res.json({
        ok: false,
        reply: '',
        mode: 'degraded',
        details: normalized.message,
        error: normalized.message,
        code: normalized.code || 'ollama_unavailable',
      });
    }
  }),
);

app.post(
  '/api/mobile-events',
  authenticateRequest,
  applyRateLimit,
  asyncRoute(async (req, res) => {
    const actor = await resolveActorContext(req);
    const eventName = ensureNonEmptyString(req.body?.eventName, 'eventName')
      .toLowerCase()
      .slice(0, 120);
    const attributes = sanitizeTelemetryValue(req.body?.attributes || {});

    await firestoreDb().collection('release_health_events').add({
      source: 'mobile',
      eventName,
      attributes,
      userId: actor.uid,
      role: actor.role,
      createdAt: nowTimestamp(),
    });

    res.json({ ok: true });
  }),
);

app.get(
  '/api/notification-preferences',
  authenticateRequest,
  asyncRoute(async (req, res) => {
    const actor = await resolveActorContext(req);
    const result = await notificationServices.getNotificationPreferences(
      actor.uid,
      actor.role,
    );
    res.json({
      ok: true,
      preferences: result.preferences,
      role: result.role,
    });
  }),
);

app.put(
  '/api/notification-preferences',
  authenticateRequest,
  asyncRoute(async (req, res) => {
    const actor = await resolveActorContext(req);
    const preferences =
      await notificationServices.updateNotificationPreferences(
        actor.uid,
        req.body || {},
        actor.role,
      );
    res.json({ ok: true, preferences });
  }),
);

app.post(
  '/api/notifications/devices/register',
  authenticateRequest,
  asyncRoute(async (req, res) => {
    const actor = await resolveActorContext(req);
    const device = await notificationServices.registerDevice({
      uid: actor.uid,
      deviceId: ensureNonEmptyString(req.body?.deviceId, 'deviceId'),
      fcmToken: ensureNonEmptyString(req.body?.fcmToken, 'fcmToken'),
      platform: req.body?.platform,
      appVersion: req.body?.appVersion,
      locale: req.body?.locale,
      timezone: req.body?.timezone,
      pushPermissionStatus: req.body?.pushPermissionStatus,
    });
    res.json({ ok: true, device });
  }),
);

app.delete(
  '/api/notifications/devices/:deviceId',
  authenticateRequest,
  asyncRoute(async (req, res) => {
    const actor = await resolveActorContext(req);
    const deviceId = ensureNonEmptyString(req.params.deviceId, 'deviceId');
    await notificationServices.unregisterDevice(actor.uid, deviceId);
    res.json({ ok: true });
  }),
);

app.get(
  '/api/notifications',
  authenticateRequest,
  asyncRoute(async (req, res) => {
    const actor = await resolveActorContext(req);
    const result = await notificationServices.listNotifications(
      actor.uid,
      {
        limit: req.query.limit,
        cursor: typeof req.query.cursor === 'string' ? req.query.cursor : null,
      },
    );
    res.json({ ok: true, ...result });
  }),
);

app.post(
  '/api/notifications/read-all',
  authenticateRequest,
  asyncRoute(async (req, res) => {
    const actor = await resolveActorContext(req);
    const updated = await notificationServices.markAllNotificationsRead(
      actor.uid,
    );
    res.json({ ok: true, updated });
  }),
);

app.post(
  '/api/notifications/:notificationId/read',
  authenticateRequest,
  asyncRoute(async (req, res) => {
    const actor = await resolveActorContext(req);
    const notificationId = ensureNonEmptyString(
      req.params.notificationId,
      'notificationId',
    );
    await notificationServices.markNotificationRead(
      actor.uid,
      notificationId,
    );
    res.json({ ok: true, notificationId });
  }),
);

app.post(
  '/internal/jobs/generate-mood-forecasts',
  asyncRoute(async (req, res) => {
    requireInternalJobAuth(req);
    const result = await notificationServices.runGenerateMoodForecastsJob({
      limit: clampLimit(req.query.limit || req.body?.limit || 50),
      now: new Date(),
    });
    res.json({ ok: true, result });
  }),
);

app.post(
  '/internal/jobs/send-daily-mood-reminders',
  asyncRoute(async (req, res) => {
    requireInternalJobAuth(req);
    const result = await notificationServices.runDailyMoodReminderJob({
      limit: clampLimit(req.query.limit || req.body?.limit || 50),
      now: new Date(),
    });
    res.json({ ok: true, result });
  }),
);

app.post(
  '/internal/jobs/send-appointment-reminders',
  asyncRoute(async (req, res) => {
    requireInternalJobAuth(req);
    const result = await notificationServices.runAppointmentReminderJob({
      now: new Date(),
    });
    res.json({ ok: true, result });
  }),
);

app.post(
  '/internal/jobs/process-notification-retries',
  asyncRoute(async (req, res) => {
    requireInternalJobAuth(req);
    const result = await notificationServices.runNotificationRetryJob({
      limit: clampLimit(req.query.limit || req.body?.limit || 50),
      now: new Date(),
    });
    res.json({ ok: true, result });
  }),
);

app.post(
  '/api/data-rights/export',
  authenticateRequest,
  applyRateLimit,
  asyncRoute(async (req, res) => {
    const actor = await resolveActorContext(req);
    if (actor.role !== 'user') {
      throw createHttpError(
        403,
        'unsupported_role',
        'Only user accounts can request this export flow right now.',
      );
    }

    const jobRef = await createDataRightsJob({
      userId: actor.uid,
      type: 'export',
      actor,
    });

    try {
      const exportBundle = await buildUserExportBundle(actor.uid);
      const { moodCsvBase64, ...summary } = exportBundle.summary;

      await markDataRightsJob(jobRef, {
        status: 'completed',
        completedAt: nowTimestamp(),
        fileName: exportBundle.fileName,
        mimeType: exportBundle.mimeType,
        resultSummary: summary,
      });

      res.json({
        ok: true,
        jobId: jobRef.id,
        fileName: exportBundle.fileName,
        mimeType: exportBundle.mimeType,
        contentBase64: exportBundle.contentBase64,
        moodCsvBase64,
        summary,
      });
    } catch (error) {
      await markDataRightsJob(jobRef, {
        status: 'failed',
        completedAt: nowTimestamp(),
        errorMessage: error.message || 'export_failed',
      });
      throw error;
    }
  }),
);

app.post(
  '/api/data-rights/delete-account',
  authenticateRequest,
  applyRateLimit,
  asyncRoute(async (req, res) => {
    const actor = await resolveActorContext(req);
    if (actor.role !== 'user' && actor.role !== 'therapist') {
      throw createHttpError(
        403,
        'unsupported_role',
        'Only user and therapist accounts can delete themselves from this flow right now.',
      );
    }

    const confirmation = ensureNonEmptyString(
      req.body?.confirmation,
      'confirmation',
    );
    if (confirmation !== 'DELETE') {
      throw createHttpError(
        400,
        'validation_error',
        'Type DELETE to confirm account deletion.',
      );
    }

    requireRecentAuthentication(req, 'deleting your account');

    const jobRef = await createDataRightsJob({
      userId: actor.uid,
      type: 'delete_account',
      actor,
    });

    try {
      const deletionSummary = await deleteUserAccountData(actor.uid);
      await markDataRightsJob(jobRef, {
        status: 'completed',
        completedAt: nowTimestamp(),
        resultSummary: deletionSummary,
      });

      res.json({
        ok: true,
        jobId: jobRef.id,
        summary: deletionSummary,
      });
    } catch (error) {
      await markDataRightsJob(jobRef, {
        status: 'failed',
        completedAt: nowTimestamp(),
        errorMessage: error.message || 'delete_account_failed',
      });
      throw error;
    }
  }),
);

app.get(
  '/api/therapists/me/availability',
  authenticateRequest,
  asyncRoute(async (req, res) => {
    const actor = await resolveActorContext(req);
    if (actor.role !== 'therapist') {
      throw createHttpError(
        403,
        'therapist_access_required',
        'Only therapists can manage schedule availability.',
      );
    }

    const result = await materializeTherapistSlots(actor.uid);
    res.json({
      ok: true,
      therapistId: actor.uid,
      timezone: result.settings.timezone,
      acceptingNewPatients: result.settings.acceptingNewPatients,
      sessionDurationMinutes: result.settings.sessionDurationMinutes,
      bufferMinutes: result.settings.bufferMinutes,
      weeklyRules: result.weeklyRules,
      blockedDates: result.exceptions,
      nextAvailableAt: result.nextAvailableAt,
    });
  }),
);

app.post(
  '/api/therapists/me/availability',
  authenticateRequest,
  asyncRoute(async (req, res) => {
    const actor = await resolveActorContext(req);
    if (actor.role !== 'therapist') {
      throw createHttpError(
        403,
        'therapist_access_required',
        'Only therapists can manage schedule availability.',
      );
    }

    const settings = normalizeScheduleSettings({
      timezone: req.body?.timezone,
      acceptingNewPatients: req.body?.acceptingNewPatients,
      sessionDurationMinutes: req.body?.sessionDurationMinutes,
      bufferMinutes: req.body?.bufferMinutes,
    });
    const weeklyRules = normalizeWeeklyRules(req.body?.weeklyRules || []);
    const blockedDates = normalizeAvailabilityExceptions(
      req.body?.blockedDates || [],
      settings.timezone,
    );

    for (const rule of weeklyRules) {
      if (!rule.enabled) {
        continue;
      }
      if (!rule.startTime || !rule.endTime || rule.endTime <= rule.startTime) {
        throw createHttpError(
          400,
          'validation_error',
          'Enabled schedule rules need a valid start and end time.',
        );
      }
    }

    const therapistRef = firestoreDb().collection('therapists').doc(actor.uid);
    const [existingRules, existingExceptions] = await Promise.all([
      therapistRef.collection('availability_rules').get(),
      therapistRef.collection('availability_exceptions').get(),
    ]);

    const batch = firestoreDb().batch();
    batch.set(
      therapistRef,
      {
        timezone: settings.timezone,
        acceptingNewPatients: settings.acceptingNewPatients,
        sessionDurationMinutes: settings.sessionDurationMinutes,
        bufferMinutes: settings.bufferMinutes,
        updatedAt: nowTimestamp(),
      },
      { merge: true },
    );

    existingRules.docs.forEach((doc) => batch.delete(doc.ref));
    existingExceptions.docs.forEach((doc) => batch.delete(doc.ref));

    for (const rule of weeklyRules) {
      batch.set(therapistRef.collection('availability_rules').doc(`weekday-${rule.weekday}`), {
        weekday: rule.weekday,
        enabled: rule.enabled,
        startTime: rule.startTime,
        endTime: rule.endTime,
        updatedAt: nowTimestamp(),
        createdAt: nowTimestamp(),
      });
    }

    for (const exception of blockedDates) {
      batch.set(therapistRef.collection('availability_exceptions').doc(exception.dateKey), {
        dateKey: exception.dateKey,
        blocked: exception.blocked,
        note: exception.note,
        startTime: exception.startTime,
        endTime: exception.endTime,
        updatedAt: nowTimestamp(),
        createdAt: nowTimestamp(),
      });
    }

    await batch.commit();
    const result = await materializeTherapistSlots(actor.uid);

    res.json({
      ok: true,
      therapistId: actor.uid,
      timezone: result.settings.timezone,
      acceptingNewPatients: result.settings.acceptingNewPatients,
      sessionDurationMinutes: result.settings.sessionDurationMinutes,
      bufferMinutes: result.settings.bufferMinutes,
      weeklyRules: result.weeklyRules,
      blockedDates: result.exceptions,
      nextAvailableAt: result.nextAvailableAt,
      openSlots: result.generatedSlots.filter((slot) => slot.status === 'open').length,
    });
  }),
);

app.get(
  '/api/therapists/:therapistId/availability',
  authenticateRequest,
  asyncRoute(async (req, res) => {
    const therapistId = ensureNonEmptyString(req.params.therapistId, 'therapistId');
    const actor = await resolveActorContext(req);
    const result = await materializeTherapistSlots(therapistId);

    if (
      actor.uid !== therapistId &&
      (result.therapistData.isApproved !== true ||
        result.therapistData.credentialVerificationStatus !== 'verified')
    ) {
      throw createHttpError(
        403,
        'therapist_not_approved',
        'Only approved therapists can accept appointment requests.',
      );
    }

    const dateKey =
      buildDateKeyFromDate(req.query?.date, result.settings.timezone) ||
      buildDateKeyFromDate(new Date(), result.settings.timezone);
    const slots =
      actor.uid !== therapistId && result.settings.acceptingNewPatients === false
        ? []
        : result.generatedSlots
            .filter((slot) => slot.dateKey === dateKey && slot.status === 'open')
            .map((slot) => ({
              slotId: slot.slotId,
              dateKey: slot.dateKey,
              timezone: slot.timezone,
              status: slot.status,
              startAt: slot.startAt.toISOString(),
              endAt: slot.endAt.toISOString(),
              startTime: slot.startTime,
              endTime: slot.endTime,
            }));

    res.json({
      ok: true,
      therapistId,
      timezone: result.settings.timezone,
      acceptingNewPatients: result.settings.acceptingNewPatients,
      sessionDurationMinutes: result.settings.sessionDurationMinutes,
      bufferMinutes: result.settings.bufferMinutes,
      dateKey,
      nextAvailableAt: result.nextAvailableAt,
      slots,
    });
  }),
);

app.post(
  '/api/therapists/:therapistId/appointments/request',
  authenticateRequest,
  asyncRoute(async (req, res) => {
    const therapistId = ensureNonEmptyString(req.params.therapistId, 'therapistId');
    const slotId = ensureNonEmptyString(req.body?.slotId, 'slotId');
    const actor = await resolveActorContext(req);

    if (actor.role !== 'user') {
      throw createHttpError(
        403,
        'unsupported_role',
        'Only user accounts can request therapist appointments.',
      );
    }

    if (actor.uid === therapistId) {
      throw createHttpError(
        400,
        'validation_error',
        'You cannot book an appointment with yourself.',
      );
    }

    await releaseExpiredPendingRequests(therapistId);

    const therapistRef = firestoreDb().collection('therapists').doc(therapistId);
    const therapistUserRef = firestoreDb().collection('users').doc(therapistId);
    const userRef = firestoreDb().collection('users').doc(actor.uid);
    const slotRef = therapistRef.collection('bookable_slots').doc(slotId);
    const appointmentRef = firestoreDb().collection('appointments').doc();
    const consentGiven = req.body?.consentGiven !== false;
    const decisionReason = normalizeDecisionReason(req.body?.notes);

    await firestoreDb().runTransaction(async (transaction) => {
      const [therapistSnapshot, therapistUserSnapshot, userSnapshot, slotSnapshot] =
        await Promise.all([
          transaction.get(therapistRef),
          transaction.get(therapistUserRef),
          transaction.get(userRef),
          transaction.get(slotRef),
        ]);

      if (!therapistSnapshot.exists) {
        throw createHttpError(404, 'therapist_not_found', 'Therapist not found.');
      }
      if (!userSnapshot.exists) {
        throw createHttpError(404, 'user_not_found', 'User not found.');
      }
      if (!slotSnapshot.exists) {
        throw createHttpError(404, 'slot_not_found', 'Selected time slot is no longer available.');
      }

      const therapistData = therapistSnapshot.data() || {};
      if (
        therapistData.isApproved !== true ||
        therapistData.credentialVerificationStatus !== 'verified'
      ) {
        throw createHttpError(
          403,
          'therapist_not_approved',
          'Only approved therapists can receive appointment requests.',
        );
      }
      if (therapistData.acceptingNewPatients === false) {
        throw createHttpError(
          409,
          'bookings_paused',
          'This therapist is not accepting new booking requests right now.',
        );
      }

      const slot = serializeScheduleSlot(slotSnapshot);
      if (slot.status !== 'open') {
        throw createHttpError(
          409,
          'slot_not_available',
          'This time slot is no longer available.',
        );
      }
      if (!(slot.startAt instanceof Date) || slot.startAt.getTime() <= Date.now()) {
        throw createHttpError(
          409,
          'slot_in_past',
          'Please select a future time slot.',
        );
      }

      const userData = userSnapshot.data() || {};
      const therapistUserData = therapistUserSnapshot.exists
        ? therapistUserSnapshot.data() || {}
        : {};

      transaction.set(appointmentRef, {
        userId: actor.uid,
        userName: userData.name || actor.displayName || actor.email || 'User',
        userEmail: userData.email || actor.email || null,
        therapistId,
        therapistName:
          therapistData.displayName ||
          therapistUserData.name ||
          therapistData.professionalTitle ||
          'Therapist',
        scheduledAt: slot.startAt,
        scheduledEndAt: slot.endAt,
        timezone: slot.timezone || therapistData.timezone || DEFAULT_SCHEDULE_TIMEZONE,
        slotId,
        status: 'requested',
        notes: decisionReason,
        createdAt: nowTimestamp(),
        updatedAt: nowTimestamp(),
        statusUpdatedBy: actor.uid,
      });

      transaction.set(
        slotRef,
        {
          status: 'pending_request',
          appointmentId: appointmentRef.id,
          heldUntil: new Date(Date.now() + REQUEST_HOLD_HOURS * 60 * 60 * 1000),
          updatedAt: nowTimestamp(),
        },
        { merge: true },
      );

      const userPatch = {
        updatedAt: nowTimestamp(),
      };
      userPatch.consentedTherapists = consentGiven
        ? admin.firestore.FieldValue.arrayUnion(therapistId)
        : admin.firestore.FieldValue.arrayRemove(therapistId);
      transaction.set(userRef, userPatch, { merge: true });
    });

    const appointmentSnapshot = await appointmentRef.get();
    const appointment = serializeAppointmentSnapshot(appointmentSnapshot);
    res.json({
      ok: true,
      appointmentId: appointmentRef.id,
      appointment,
    });

    runDeferredTask(
      'appointment request follow-up',
      async () => {
        await materializeTherapistSlots(therapistId);
        await notificationServices.sendAppointmentEventNotifications({
          appointment,
          type: 'appointment_requested',
          dedupeKey: `${appointmentRef.id}_requested`,
        });
      },
      {
        appointmentId: appointmentRef.id,
        therapistId,
        type: 'appointment_requested',
      },
    );
  }),
);

app.post(
  '/api/appointments/:appointmentId/status',
  authenticateRequest,
  asyncRoute(async (req, res) => {
    const startedAt = Date.now();
    const appointmentId = ensureNonEmptyString(
      req.params.appointmentId,
      'appointmentId',
    );
    const nextStatus = ensureNonEmptyString(req.body?.status, 'status').toLowerCase();
    const actor = await resolveActorContext(req);
    const reason = normalizeDecisionReason(req.body?.reason);
    const appointmentRef = firestoreDb().collection('appointments').doc(appointmentId);
    let previousStatus = 'requested';

    await firestoreDb().runTransaction(async (transaction) => {
      const appointmentSnapshot = await transaction.get(appointmentRef);
      if (!appointmentSnapshot.exists) {
        throw createHttpError(
          404,
          'appointment_not_found',
          'Appointment not found.',
        );
      }

      const appointment = serializeAppointmentSnapshot(appointmentSnapshot);
      previousStatus = appointment.status;
      ensureParticipant(actor.uid, appointment);
      const transition = assertAppointmentTransition({
        actorUid: actor.uid,
        appointment,
        nextStatus,
      });

      if (
        transition.actorType === 'therapist' &&
        ['rejected', 'cancelled', 'no_show'].includes(nextStatus) &&
        !reason
      ) {
        throw createHttpError(
          400,
          'validation_error',
          'A reason is required for this therapist action.',
        );
      }

      let slotRef = null;
      let slotSnapshot = null;
      if (appointment.therapistId && appointment.slotId) {
        slotRef = firestoreDb()
          .collection('therapists')
          .doc(appointment.therapistId)
          .collection('bookable_slots')
          .doc(appointment.slotId);
        slotSnapshot = await transaction.get(slotRef);
      }

      transaction.set(
        appointmentRef,
        buildAppointmentStatusPatch({
          nextStatus,
          actorUid: actor.uid,
          reason,
        }),
        { merge: true },
      );

      if (slotRef && slotSnapshot?.exists) {
        const slotPatch = {
          updatedAt: nowTimestamp(),
        };

        if (nextStatus === 'confirmed') {
          slotPatch.status = 'booked';
          slotPatch.appointmentId = appointmentId;
          slotPatch.heldUntil = admin.firestore.FieldValue.delete();
        } else if (
          ['rejected', 'cancelled'].includes(nextStatus) &&
          appointment.scheduledAt &&
          new Date(appointment.scheduledAt).getTime() > Date.now()
        ) {
          slotPatch.status = 'open';
          slotPatch.appointmentId = admin.firestore.FieldValue.delete();
          slotPatch.heldUntil = admin.firestore.FieldValue.delete();
          slotPatch.blockedReason = admin.firestore.FieldValue.delete();
        } else if (['completed', 'no_show'].includes(nextStatus)) {
          slotPatch.status = 'booked';
          slotPatch.heldUntil = admin.firestore.FieldValue.delete();
        }

        transaction.set(slotRef, slotPatch, { merge: true });
      }
    });

    const refreshedAppointment = serializeAppointmentSnapshot(
      await appointmentRef.get(),
    );
    relationshipSummaryCache.delete(
      `${refreshedAppointment.userId}:${refreshedAppointment.therapistId}`,
    );
    callRoomCache.delete(`${appointmentId}:audio`);
    callRoomCache.delete(`${appointmentId}:video`);

    res.json({
      ok: true,
      appointmentId,
      status: refreshedAppointment.status,
      appointment: refreshedAppointment,
    });

    logInfo('Appointment status updated', {
      appointmentId,
      previousStatus,
      nextStatus: refreshedAppointment.status,
      actorUid: actor.uid,
      elapsedMs: Date.now() - startedAt,
    });

    runDeferredTask(
      'appointment status follow-up',
      async () => {
        if (refreshedAppointment.therapistId) {
          await materializeTherapistSlots(refreshedAppointment.therapistId);
        }

        if (previousStatus !== refreshedAppointment.status) {
          await notificationServices.sendAppointmentEventNotifications({
            appointment: refreshedAppointment,
            type: `appointment_${refreshedAppointment.status}`,
            reason,
            dedupeKey: `${appointmentId}_${refreshedAppointment.status}`,
          });
        }
      },
      {
        appointmentId,
        therapistId: refreshedAppointment.therapistId,
        previousStatus,
        nextStatus: refreshedAppointment.status,
      },
    );
  }),
);

app.post(
  '/api/appointments/:appointmentId/call-room',
  authenticateRequest,
  asyncRoute(async (req, res) => {
    const appointmentId = ensureNonEmptyString(
      req.params.appointmentId,
      'appointmentId',
    );
    const actor = await resolveActorContext(req);
    const appointmentSnapshot = await firestoreDb()
      .collection('appointments')
      .doc(appointmentId)
      .get();

    if (!appointmentSnapshot.exists) {
      throw createHttpError(
        404,
        'appointment_not_found',
        'Appointment not found.',
      );
    }

    const appointment = serializeAppointmentSnapshot(appointmentSnapshot);
    ensureParticipant(actor.uid, appointment);
    const room = await ensureAppointmentCallRoomDocument({
      appointmentId,
      audioOnly: Boolean(req.body?.audioOnly),
    });

    res.json({
      ok: true,
      roomId: room.roomId,
      appointmentId: room.appointmentId,
    });
  }),
);

app.post(
  '/api/therapist-chats/ensure-room',
  authenticateRequest,
  asyncRoute(async (req, res) => {
    const actor = await resolveActorContext(req);
    const pair = await resolveConversationPair(actor, req.body?.counterpartId);
    const relationship = await loadRelationshipSummary(
      pair.userId,
      pair.therapistId,
    );

    if (actor.role === 'therapist' && !relationship.hasAnyRelationship) {
      throw createHttpError(
        403,
        'relationship_required',
        'Therapists can only message users with an existing appointment relationship.',
      );
    }

    const roomId = buildChatRoomId(pair.userId, pair.therapistId);
    const relationshipType = relationship.callEligibleAppointment
      ? 'appointment'
      : relationship.latestActiveAppointment
      ? 'request'
      : 'prospect';

    await firestoreDb()
      .collection('therapist_chats')
      .doc(roomId)
      .set(
        {
          userId: pair.userId,
          therapistId: pair.therapistId,
          participants: [pair.userId, pair.therapistId].sort(),
          relationshipType,
          appointmentId:
            relationship.callEligibleAppointment?.id ||
            relationship.latestActiveAppointment?.id ||
            null,
          canCall: relationship.canCall,
          updatedAt: nowTimestamp(),
          createdAt: nowTimestamp(),
        },
        { merge: true },
      );

    res.json({
      ok: true,
      roomId,
      appointmentId:
        relationship.callEligibleAppointment?.id ||
        relationship.latestActiveAppointment?.id ||
        null,
      canCall: relationship.canCall,
      relationshipType,
    });
  }),
);

app.post(
  '/api/calls/ensure-room',
  authenticateRequest,
  asyncRoute(async (req, res) => {
    const actor = await resolveActorContext(req);
    let appointmentId = req.body?.appointmentId;

    if (appointmentId) {
      appointmentId = ensureNonEmptyString(appointmentId, 'appointmentId');
      const appointmentSnapshot = await firestoreDb()
        .collection('appointments')
        .doc(appointmentId)
        .get();

      if (!appointmentSnapshot.exists) {
        throw createHttpError(
          404,
          'appointment_not_found',
          'Appointment not found.',
        );
      }

      const appointment = serializeAppointmentSnapshot(appointmentSnapshot);
      ensureParticipant(actor.uid, appointment);
      const room = await ensureAppointmentCallRoomDocument({
        appointmentId,
        audioOnly: Boolean(req.body?.audioOnly),
      });

      res.json({
        ok: true,
        roomId: room.roomId,
        appointmentId: room.appointmentId,
      });
      return;
    }

    const pair = await resolveConversationPair(actor, req.body?.counterpartId);
    const relationship = await loadRelationshipSummary(
      pair.userId,
      pair.therapistId,
    );
    if (!relationship.callEligibleAppointment) {
      throw createHttpError(
        403,
        'call_relationship_required',
        'Calls are only available after a confirmed appointment.',
      );
    }

    const room = await ensureAppointmentCallRoomDocument({
      appointmentId: relationship.callEligibleAppointment.id,
      audioOnly: Boolean(req.body?.audioOnly),
    });

    res.json({
      ok: true,
      roomId: room.roomId,
      appointmentId: room.appointmentId,
    });
  }),
);

app.get(
  '/api/admin/me',
  authenticateRequest,
  asyncRoute(async (req, res) => {
    const adminContext = await requireAdmin(req);
    res.json({
      ok: true,
      admin: {
        uid: adminContext.uid,
        displayName:
          adminContext.adminProfile?.displayName ||
          adminContext.displayName ||
          adminContext.email,
        email: adminContext.email,
        roles: adminContext.adminRoles,
      },
    });
  }),
);

app.get(
  '/api/admin/dashboard/summary',
  authenticateRequest,
  asyncRoute(async (req, res) => {
    await requireAdmin(req);
    const db = firestoreDb();
    const [users, therapists, appointments, incidents, dataRequests] =
      await Promise.all([
        db.collection('users').get(),
        db.collection('therapists').get(),
        db.collection('appointments').get(),
        db.collection('ai_incidents').limit(MAX_LIST_LIMIT).get(),
        db.collection('data_rights_jobs').limit(MAX_LIST_LIMIT).get(),
      ]);

    const therapistDocs = therapists.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));
    const appointmentDocs = appointments.docs.map((doc) => doc.data());

    res.json({
      ok: true,
      summary: {
        totalUsers: users.size,
        totalTherapists: therapists.size,
        approvedTherapists: therapistDocs.filter(
          (therapist) => therapist.isApproved === true,
        ).length,
        therapistsAwaitingReview: therapistDocs.filter(
          (therapist) => therapist.isApproved !== true,
        ).length,
        openAppointments: appointmentDocs.filter((appointment) =>
          ['requested', 'confirmed'].includes(
            String(appointment.status || '').trim().toLowerCase(),
          ),
        ).length,
        completedAppointments: appointmentDocs.filter(
          (appointment) =>
            String(appointment.status || '').trim().toLowerCase() ===
            'completed',
        ).length,
        aiIncidents: incidents.size,
        openDataRightsJobs: dataRequests.docs.filter((doc) => {
          const status = String(doc.data().status || '').trim().toLowerCase();
          return status && !['completed', 'failed', 'cancelled'].includes(status);
        }).length,
      },
    });
  }),
);

app.get(
  '/api/admin/therapists/review-queue',
  authenticateRequest,
  asyncRoute(async (req, res) => {
    await requireAdmin(req, ['super_admin', 'clinical_ops']);
    const limit = clampLimit(req.query.limit);
    const therapistSnapshots = await firestoreDb()
      .collection('therapists')
      .limit(limit)
      .get();
    const pendingTherapists = therapistSnapshots.docs
      .map((doc) => ({ id: doc.id, ...doc.data() }))
      .filter((therapist) => therapist.isApproved !== true);

    const userIds = pendingTherapists
      .map((therapist) => therapist.userId || therapist.id)
      .filter(Boolean);
    const userDocs = await Promise.all(
      userIds.map((userId) => fetchDocumentData('users', userId)),
    );
    const usersById = new Map(userDocs.filter(Boolean).map((doc) => [doc.id, doc]));

    res.json({
      ok: true,
      therapists: pendingTherapists.map((therapist) => {
        const userDoc = usersById.get(therapist.userId || therapist.id);
        return {
          id: therapist.id,
          userId: therapist.userId || therapist.id,
          name: userDoc?.name || userDoc?.email || therapist.id,
          email: userDoc?.email || null,
          specialty: therapist.specialty || null,
          yearsExperience: therapist.yearsExperience || null,
          acceptingNewPatients:
            therapist.acceptingNewPatients !== false,
          reviewStatus: therapist.reviewStatus || 'pending',
          reviewedAt: toIso(therapist.reviewedAt),
          reviewedBy: therapist.reviewedBy || null,
        };
      }),
    });
  }),
);

app.get(
  '/api/admin/therapists/:therapistId',
  authenticateRequest,
  asyncRoute(async (req, res) => {
    await requireAdmin(req, ['super_admin', 'clinical_ops', 'support_ops']);
    const therapistId = ensureNonEmptyString(
      req.params.therapistId,
      'therapistId',
    );
    const [therapistDoc, userDoc] = await Promise.all([
      fetchDocumentData('therapists', therapistId),
      fetchDocumentData('users', therapistId),
    ]);

    if (!therapistDoc) {
      throw createHttpError(
        404,
        'therapist_not_found',
        'Therapist not found.',
      );
    }

    const appointmentSnapshot = await firestoreDb()
      .collection('appointments')
      .where('therapistId', '==', therapistId)
      .limit(MAX_LIST_LIMIT)
      .get();

    res.json({
      ok: true,
      therapist: {
        ...therapistDoc,
        name: userDoc?.name || userDoc?.email || therapistId,
        email: userDoc?.email || null,
        reviewedAt: toIso(therapistDoc.reviewedAt),
        createdAt: toIso(therapistDoc.createdAt),
        metrics: {
          appointments: appointmentSnapshot.size,
          confirmedAppointments: appointmentSnapshot.docs.filter((doc) => {
            const status = String(doc.data().status || '').trim().toLowerCase();
            return status === 'confirmed';
          }).length,
          completedAppointments: appointmentSnapshot.docs.filter((doc) => {
            const status = String(doc.data().status || '').trim().toLowerCase();
            return status === 'completed';
          }).length,
        },
      },
    });
  }),
);

app.post(
  '/api/admin/therapists/:therapistId/decision',
  authenticateRequest,
  asyncRoute(async (req, res) => {
    const adminContext = await requireAdmin(req, [
      'super_admin',
      'clinical_ops',
    ]);
    const therapistId = ensureNonEmptyString(
      req.params.therapistId,
      'therapistId',
    );
    const decision = ensureNonEmptyString(
      req.body?.decision,
      'decision',
    ).toLowerCase();
    const notes =
      typeof req.body?.notes === 'string' ? req.body.notes.trim().slice(0, 2000) : '';

    if (!['approve', 'reject', 'suspend'].includes(decision)) {
      throw createHttpError(
        400,
        'validation_error',
        'decision must be approve, reject, or suspend.',
      );
    }

    const therapistRef = firestoreDb().collection('therapists').doc(therapistId);
    const therapistSnapshot = await therapistRef.get();
    if (!therapistSnapshot.exists) {
      throw createHttpError(
        404,
        'therapist_not_found',
        'Therapist not found.',
      );
    }

    const decisionMap = {
      approve: {
        isApproved: true,
        reviewStatus: 'approved',
        accountStatus: 'active',
      },
      reject: {
        isApproved: false,
        reviewStatus: 'rejected',
        accountStatus: 'restricted',
      },
      suspend: {
        isApproved: false,
        reviewStatus: 'suspended',
        accountStatus: 'suspended',
      },
    };

    await therapistRef.set(
      {
        ...decisionMap[decision],
        reviewedAt: nowTimestamp(),
        reviewedBy: adminContext.uid,
        reviewNotes: notes || null,
        updatedAt: nowTimestamp(),
      },
      { merge: true },
    );

    await firestoreDb()
      .collection('therapist_review_cases')
      .doc(therapistId)
      .set(
        {
          therapistId,
          decision,
          notes: notes || null,
          reviewedBy: adminContext.uid,
          reviewedAt: nowTimestamp(),
          updatedAt: nowTimestamp(),
        },
        { merge: true },
      );

    await firestoreDb()
      .collection('therapist_review_events')
      .add({
        therapistId,
        decision,
        notes: notes || null,
        reviewedBy: adminContext.uid,
        reviewedAt: nowTimestamp(),
        reviewerRoles: adminContext.adminRoles,
      });

    await writeAdminAuditLog({
      actor: adminContext,
      action: `therapist.${decision}`,
      targetType: 'therapist',
      targetId: therapistId,
      metadata: {
        notesProvided: Boolean(notes),
      },
    });

    res.json({
      ok: true,
      therapistId,
      decision,
    });
  }),
);

app.get(
  '/api/admin/users',
  authenticateRequest,
  asyncRoute(async (req, res) => {
    await requireAdmin(req, [
      'super_admin',
      'support_ops',
      'clinical_ops',
      'read_only_analytics',
    ]);
    const limit = clampLimit(req.query.limit);
    const queryText =
      typeof req.query.q === 'string' ? req.query.q.trim().toLowerCase() : '';
    const snapshot = await firestoreDb().collection('users').limit(limit).get();
    const users = snapshot.docs
      .map((doc) => ({ id: doc.id, ...doc.data() }))
      .filter((user) => {
        if (!queryText) {
          return true;
        }
        const haystack = [user.id, user.name, user.email]
          .filter(Boolean)
          .join(' ')
          .toLowerCase();
        return haystack.includes(queryText);
      })
      .map((user) => ({
        id: user.id,
        name: user.name || user.email || user.id,
        email: user.email || null,
        role: normalizeAppRole(user.role),
        consentAccepted: user.consentAccepted === true,
        consentedTherapistsCount: Array.isArray(user.consentedTherapists)
          ? user.consentedTherapists.length
          : 0,
        createdAt: toIso(user.createdAt),
        lastLoginAt: toIso(user.lastLoginAt),
      }));

    res.json({ ok: true, users });
  }),
);

app.get(
  '/api/admin/users/:userId',
  authenticateRequest,
  asyncRoute(async (req, res) => {
    await requireAdmin(req, ['super_admin', 'support_ops', 'clinical_ops']);
    const userId = ensureNonEmptyString(req.params.userId, 'userId');
    const userDoc = await fetchDocumentData('users', userId);
    if (!userDoc) {
      throw createHttpError(404, 'user_not_found', 'User not found.');
    }

    const [appointments, moods] = await Promise.all([
      firestoreDb()
        .collection('appointments')
        .where('userId', '==', userId)
        .limit(MAX_LIST_LIMIT)
        .get(),
      firestoreDb().collection('moods').where('userId', '==', userId).get(),
    ]);

    res.json({
      ok: true,
      user: {
        id: userId,
        name: userDoc.name || userDoc.email || userId,
        email: userDoc.email || null,
        role: normalizeAppRole(userDoc.role),
        consentAccepted: userDoc.consentAccepted === true,
        consentedTherapists: Array.isArray(userDoc.consentedTherapists)
          ? userDoc.consentedTherapists
          : [],
        createdAt: toIso(userDoc.createdAt),
        lastLoginAt: toIso(userDoc.lastLoginAt),
        metrics: {
          moodEntries: moods.size,
          appointments: appointments.size,
          activeAppointments: appointments.docs.filter((doc) => {
            const status = String(doc.data().status || '').trim().toLowerCase();
            return ACTIVE_APPOINTMENT_STATUSES.has(status);
          }).length,
        },
      },
    });
  }),
);

app.get(
  '/api/admin/appointments',
  authenticateRequest,
  asyncRoute(async (req, res) => {
    await requireAdmin(req, [
      'super_admin',
      'support_ops',
      'clinical_ops',
      'read_only_analytics',
    ]);
    const limit = clampLimit(req.query.limit);
    const requestedStatus =
      typeof req.query.status === 'string'
        ? req.query.status.trim().toLowerCase()
        : '';
    const snapshot = await firestoreDb()
      .collection('appointments')
      .limit(limit)
      .get();

    const appointments = snapshot.docs
      .map((doc) => serializeAppointmentSnapshot(doc))
      .filter((appointment) =>
        requestedStatus ? appointment.status === requestedStatus : true,
      );

    res.json({ ok: true, appointments });
  }),
);

app.get(
  '/api/admin/audit-log',
  authenticateRequest,
  asyncRoute(async (req, res) => {
    await requireAdmin(req, [
      'super_admin',
      'support_ops',
      'clinical_ops',
      'trust_safety',
      'read_only_analytics',
    ]);
    const limit = clampLimit(req.query.limit);
    const snapshot = await firestoreDb()
      .collection('admin_audit_logs')
      .limit(limit)
      .get();

    const entries = snapshot.docs
      .map((doc) => ({ id: doc.id, ...doc.data() }))
      .map((entry) => ({
        id: entry.id,
        actorId: entry.actorId || null,
        actorEmail: entry.actorEmail || null,
        actorRoles: Array.isArray(entry.actorRoles) ? entry.actorRoles : [],
        action: entry.action || null,
        targetType: entry.targetType || null,
        targetId: entry.targetId || null,
        metadata: entry.metadata || {},
        createdAt: toIso(entry.createdAt),
      }));

    res.json({ ok: true, entries });
  }),
);

if (require.main === module) {
  app.listen(port, () => {
    logInfo('MoodGenie backend listening', {
      port,
      ollamaUrl: OLLAMA_URL,
      model: OLLAMA_MODEL,
      authRequired: !ALLOW_UNAUTHENTICATED_LOCAL,
      firebaseAdminReady,
    });
  });
}

module.exports = {
  app,
  buildBackendHealthPayload,
  buildFirebaseAdminOptions,
  getStartupValidationErrors,
  getLocalBypassUser,
  isOllamaTimeoutError,
  ollamaTagMatchesConfiguredModel,
  toOllamaRequestError,
};
