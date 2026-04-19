import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldPath, FieldValue } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { cache } from 'react';
import { mergeFeatureFlags } from '@/lib/feature-flags';
import { getFirebaseAdminApp } from '@/lib/firebase-admin';
import { getTherapistApprovalBlockers } from '@/lib/therapist-review';
import type {
  AdminSession,
  AppointmentDetail,
  AppointmentRow,
  AppointmentTimelineEvent,
  AuditEntry,
  DashboardSummary,
  DataRightsJob,
  FeatureFlag,
  IncidentDetail,
  IncidentRow,
  NotificationHealthSummary,
  PaginatedResult,
  SystemHealthSnapshot,
  SupportCase,
  TherapistDetail,
  TherapistReviewHistoryEntry,
  TherapistReviewRow,
  UserDetail,
  UserRow,
} from '@/lib/types';

function db() {
  return getFirestore(getFirebaseAdminApp());
}

function asRecord(value: unknown): Record<string, any> {
  if (value && typeof value === 'object') {
    return value as Record<string, any>;
  }
  return {};
}

function toIso(value: unknown): string | null {
  if (!value) {
    return null;
  }
  if (value instanceof Date) {
    return value.toISOString();
  }
  if (typeof value === 'object' && value !== null && 'toDate' in value) {
    const date = (value as { toDate(): Date }).toDate();
    return date.toISOString();
  }
  const parsed = new Date(String(value));
  return Number.isNaN(parsed.valueOf()) ? null : parsed.toISOString();
}

function normalizeStatus(value: unknown, fallback: string) {
  return typeof value === 'string' && value.trim()
    ? value.trim().toLowerCase()
    : fallback;
}

function asTrimmedString(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
}

function asNumber(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function buildChatRoomId(userId: string, therapistId: string) {
  return [userId, therapistId].sort().join('_');
}

function buildCallRoomId(appointmentId: string) {
  return `call_${appointmentId}`;
}

const ADMIN_PAGE_SIZE = 50;

function normalizePage(value: string | number | undefined) {
  const page = Number(value || 1);
  if (!Number.isFinite(page) || page < 1) {
    return 1;
  }
  return Math.floor(page);
}

type LightweightQuerySnapshot = {
  docs: Array<{ id: string; data(): unknown }>;
  size: number;
};

type LightweightAggregateSnapshot = {
  data(): { count: number };
};

const EMPTY_QUERY_SNAPSHOT: LightweightQuerySnapshot = {
  docs: [],
  size: 0,
};

function isFirestoreFailedPrecondition(error: unknown) {
  if (!error || typeof error !== 'object') {
    return false;
  }

  const code =
    'code' in error && typeof (error as { code?: unknown }).code !== 'undefined'
      ? String((error as { code?: unknown }).code).toLowerCase()
      : '';
  const message =
    'message' in error && typeof (error as { message?: unknown }).message === 'string'
      ? (error as { message: string }).message.toLowerCase()
      : '';

  return (
    code === '9' ||
    code === 'failed-precondition' ||
    message.includes('failed_precondition') ||
    message.includes('missing or insufficient permissions') === false &&
      message.includes('requires an index')
  );
}

async function safeQuerySnapshot(
  queryName: string,
  fetchSnapshot: () => Promise<LightweightQuerySnapshot>,
): Promise<LightweightQuerySnapshot> {
  try {
    return await fetchSnapshot();
  } catch (error) {
    if (isFirestoreFailedPrecondition(error)) {
      console.warn(
        `[admin] Falling back to empty results for ${queryName} because the required Firestore index is not available yet.`,
      );
      return EMPTY_QUERY_SNAPSHOT;
    }

    throw error;
  }
}

async function safeAggregateCount(
  queryName: string,
  fetchSnapshot: () => Promise<LightweightAggregateSnapshot>,
): Promise<number> {
  try {
    const snapshot = await fetchSnapshot();
    return Number(snapshot.data().count || 0);
  } catch (error) {
    if (isFirestoreFailedPrecondition(error)) {
      console.warn(
        `[admin] Falling back to 0 for ${queryName} because the required Firestore index is not available yet.`,
      );
      return 0;
    }

    throw error;
  }
}

function paginateRows<T>(rows: T[], page: number): PaginatedResult<T> {
  const normalizedPage = normalizePage(page);
  const start = (normalizedPage - 1) * ADMIN_PAGE_SIZE;
  const items = rows.slice(start, start + ADMIN_PAGE_SIZE);
  return {
    items,
    page: normalizedPage,
    pageSize: ADMIN_PAGE_SIZE,
    hasNextPage: rows.length > start + ADMIN_PAGE_SIZE,
  };
}

async function getCollectionPage(
  collectionName: string,
  page: number,
): Promise<{
  docs: Array<{ id: string; data: Record<string, any> }>;
  hasNextPage: boolean;
}> {
  const normalizedPage = normalizePage(page);
  const snapshot = await db()
    .collection(collectionName)
    .orderBy(FieldPath.documentId())
    .offset((normalizedPage - 1) * ADMIN_PAGE_SIZE)
    .limit(ADMIN_PAGE_SIZE + 1)
    .get();

  return {
    docs: snapshot.docs
      .slice(0, ADMIN_PAGE_SIZE)
      .map((doc) => ({ id: doc.id, data: asRecord(doc.data()) })),
    hasNextPage: snapshot.docs.length > ADMIN_PAGE_SIZE,
  };
}

function mapIncidentRow(id: string, source: Record<string, any>): IncidentRow {
  return {
    id,
    severity: normalizeStatus(source.severity, 'medium'),
    status: normalizeStatus(source.status, 'open'),
    title: source.title || 'Untitled incident',
    category:
      typeof source.category === 'string' ? source.category : null,
    source: typeof source.source === 'string' ? source.source : null,
    userId: typeof source.userId === 'string' ? source.userId : null,
    assignedTo:
      typeof source.assignedTo === 'string' ? source.assignedTo : null,
    updatedAt: toIso(source.updatedAt),
    createdAt: toIso(source.createdAt),
  };
}

function buildAppointmentTimeline(
  source: Record<string, any>,
): AppointmentTimelineEvent[] {
  const timeline = [
    { id: 'created', label: 'Created', at: toIso(source.createdAt) },
    { id: 'scheduled', label: 'Scheduled for', at: toIso(source.scheduledAt) },
    { id: 'confirmed', label: 'Confirmed', at: toIso(source.confirmedAt) },
    { id: 'rejected', label: 'Rejected', at: toIso(source.rejectedAt) },
    { id: 'cancelled', label: 'Cancelled', at: toIso(source.cancelledAt) },
    { id: 'completed', label: 'Completed', at: toIso(source.completedAt) },
    { id: 'no_show', label: 'Marked no-show', at: toIso(source.noShowAt) },
    { id: 'updated', label: 'Last updated', at: toIso(source.updatedAt) },
  ];

  return timeline
    .filter((entry) => entry.at)
    .sort((left, right) => {
      const leftTime = new Date(left.at || 0).valueOf();
      const rightTime = new Date(right.at || 0).valueOf();
      return leftTime - rightTime;
    });
}

function mapAppointmentRow(
  id: string,
  source: Record<string, any>,
): AppointmentRow {
  return {
    id,
    userId: source.userId || null,
    therapistId: source.therapistId || null,
    status: normalizeStatus(source.status, 'requested'),
    scheduledAt: toIso(source.scheduledAt),
    updatedAt: toIso(source.updatedAt),
    meetingRoomId: source.meetingRoomId || null,
    userName: source.userName || null,
    therapistName: source.therapistName || null,
  };
}

function mapDataRightsJob(
  id: string,
  source: Record<string, any>,
): DataRightsJob {
  return {
    id,
    userId: source.userId || 'unknown',
    type: source.type || 'export',
    status: normalizeStatus(source.status, 'pending'),
    opsStatus: normalizeStatus(source.opsStatus, 'open'),
    requesterDisplayName:
      typeof source.requesterDisplayName === 'string'
        ? source.requesterDisplayName
        : null,
    requesterEmail:
      typeof source.requesterEmail === 'string' ? source.requesterEmail : null,
    requesterRole:
      typeof source.requesterRole === 'string' ? source.requesterRole : null,
    requestSource:
      typeof source.requestSource === 'string' ? source.requestSource : null,
    createdAt: toIso(source.createdAt),
    updatedAt: toIso(source.updatedAt),
    completedAt: toIso(source.completedAt),
    errorMessage:
      typeof source.errorMessage === 'string' ? source.errorMessage : null,
    opsOwner: typeof source.opsOwner === 'string' ? source.opsOwner : null,
    opsNotes: typeof source.opsNotes === 'string' ? source.opsNotes : null,
    resultSummary: asRecord(source.resultSummary),
  };
}

function buildPublicTherapistProfile(
  therapistId: string,
  therapist: Record<string, any>,
  fallbackName: string | null,
) {
  return {
    therapistId,
    userId: therapist.userId || therapistId,
    displayName:
      asTrimmedString(therapist.displayName) ||
      asTrimmedString(fallbackName) ||
      'Therapist',
    professionalTitle: asTrimmedString(therapist.professionalTitle),
    specialty: asTrimmedString(therapist.specialty),
    yearsExperience: asNumber(therapist.yearsExperience),
    pricePerSession: asNumber(therapist.pricePerSession),
    bio: asTrimmedString(therapist.bio),
    rating: asNumber(therapist.rating),
    nextAvailableAt: therapist.nextAvailableAt || null,
    acceptingNewPatients: therapist.acceptingNewPatients !== false,
    isApproved: true,
    credentialVerificationStatus: 'verified',
    verifiedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
    createdAt: therapist.createdAt || FieldValue.serverTimestamp(),
  };
}

function assertTherapistApprovalReady(
  therapist: Record<string, any>,
  verificationMethod?: string,
  verificationReference?: string,
) {
  const missingFields = getTherapistApprovalBlockers(therapist, {
    verificationMethod,
    verificationReference,
    requireDecisionVerification: true,
  });

  if (missingFields.length > 0) {
    throw new Error(
      `Therapist approval is blocked until the credential file is complete: ${missingFields.join(', ')}.`,
    );
  }
}

export const getDashboardSummary = cache(async (): Promise<DashboardSummary> => {
  const [
    totalUsers,
    totalTherapists,
    approvedTherapists,
    openAppointments,
    completedAppointments,
    aiIncidents,
    openDataRightsJobs,
  ] = await Promise.all([
    safeAggregateCount('dashboard users total', () =>
      db().collection('users').count().get(),
    ),
    safeAggregateCount('dashboard therapists total', () =>
      db().collection('therapists').count().get(),
    ),
    safeAggregateCount('dashboard approved therapists', () =>
      db().collection('therapists').where('isApproved', '==', true).count().get(),
    ),
    safeAggregateCount('dashboard open appointments', () =>
      db()
        .collection('appointments')
        .where('status', 'in', ['requested', 'confirmed'])
        .count()
        .get(),
    ),
    safeAggregateCount('dashboard completed appointments', () =>
      db()
        .collection('appointments')
        .where('status', '==', 'completed')
        .count()
        .get(),
    ),
    safeAggregateCount('dashboard ai incidents total', () =>
      db().collection('ai_incidents').count().get(),
    ),
    safeAggregateCount('dashboard open data rights jobs', () =>
      db()
        .collection('data_rights_jobs')
        .where('opsStatus', 'in', ['open', 'acknowledged', 'in_progress'])
        .count()
        .get(),
    ),
  ]);

  return {
    totalUsers,
    totalTherapists,
    approvedTherapists,
    therapistsAwaitingReview: Math.max(0, totalTherapists - approvedTherapists),
    openAppointments,
    completedAppointments,
    aiIncidents,
    openDataRightsJobs,
  };
});

export async function getTherapistReviewQueue(
  page = 1,
): Promise<PaginatedResult<TherapistReviewRow>> {
  const normalizedPage = normalizePage(page);
  const therapistSnapshot = await db()
    .collection('therapists')
    .orderBy(FieldPath.documentId())
    .offset((normalizedPage - 1) * ADMIN_PAGE_SIZE)
    .limit(ADMIN_PAGE_SIZE + 1)
    .get();
  const pending = therapistSnapshot.docs
    .slice(0, ADMIN_PAGE_SIZE)
    .map((doc) => ({ id: doc.id, ...asRecord(doc.data()) }))
    .filter((doc) => (doc as any).isApproved !== true) as Array<
    Record<string, any> & { id: string }
  >;

  const userDocs = await Promise.all(
    pending.map((therapist) => db().collection('users').doc(therapist.userId || therapist.id).get()),
  );

  return {
    items: pending.map((therapist, index) => {
      const user = userDocs[index].exists ? asRecord(userDocs[index].data()) : {};
      return {
        id: therapist.id,
        userId: therapist.userId || therapist.id,
        name:
          therapist.displayName || user?.name || user?.email || therapist.id,
        email: user?.email || null,
        professionalTitle:
          typeof therapist.professionalTitle === 'string'
            ? therapist.professionalTitle
            : null,
        specialty: therapist.specialty || null,
        yearsExperience: therapist.yearsExperience || null,
        acceptingNewPatients: therapist.acceptingNewPatients !== false,
        reviewStatus: therapist.reviewStatus || 'pending',
        credentialVerificationStatus:
          therapist.credentialVerificationStatus || 'pending_review',
        reviewedAt: toIso(therapist.reviewedAt),
        reviewedBy: therapist.reviewedBy || null,
      };
    }),
    page: normalizedPage,
    pageSize: ADMIN_PAGE_SIZE,
    hasNextPage: therapistSnapshot.docs.length > ADMIN_PAGE_SIZE,
  };
}

export async function getTherapistById(
  therapistId: string,
): Promise<TherapistDetail | null> {
  const [therapistSnapshot, appointmentSnapshot, reviewCaseSnapshot, reviewEvents] =
    await Promise.all([
      db().collection('therapists').doc(therapistId).get(),
      db().collection('appointments').where('therapistId', '==', therapistId).limit(100).get(),
      db().collection('therapist_review_cases').doc(therapistId).get(),
      db().collection('therapist_review_events').where('therapistId', '==', therapistId).limit(50).get(),
    ]);

  if (!therapistSnapshot.exists) {
    return null;
  }

  const therapist = asRecord(therapistSnapshot.data());
  const userId = therapist.userId || therapistId;
  const userSnapshot = await db().collection('users').doc(userId).get();
  const user = userSnapshot.exists ? asRecord(userSnapshot.data()) : {};
  const history = reviewEvents.docs
    .map(
      (doc): Record<string, any> & { id: string } => ({
        id: doc.id,
        ...asRecord(doc.data()),
      }),
    )
    .sort((left, right) => {
      const leftTime = new Date(toIso(left.reviewedAt) || 0).valueOf();
      const rightTime = new Date(toIso(right.reviewedAt) || 0).valueOf();
      return rightTime - leftTime;
    })
    .map((entry): TherapistReviewHistoryEntry => ({
      id: entry.id,
      decision: entry.decision || 'pending',
      notes: entry.notes || null,
      reviewedAt: toIso(entry.reviewedAt),
      reviewedBy: entry.reviewedBy || null,
      reviewerRoles: Array.isArray(entry.reviewerRoles) ? entry.reviewerRoles : [],
    }));

  return {
    id: therapistId,
    userId,
    name:
      therapist.displayName || user.name || user.email || therapistId,
    email: user.email || null,
    displayName: asTrimmedString(therapist.displayName),
    professionalTitle: asTrimmedString(therapist.professionalTitle),
    specialty: therapist.specialty || null,
    yearsExperience:
      typeof therapist.yearsExperience === 'number'
        ? therapist.yearsExperience
        : null,
    acceptingNewPatients: therapist.acceptingNewPatients !== false,
    reviewStatus: therapist.reviewStatus || 'pending',
    credentialVerificationStatus:
      therapist.credentialVerificationStatus || 'pending_review',
    reviewedAt: toIso(therapist.reviewedAt),
    reviewedBy: therapist.reviewedBy || null,
    accountStatus: therapist.accountStatus || 'active',
    reviewNotes:
      therapist.reviewNotes ||
      (reviewCaseSnapshot.exists ? asRecord(reviewCaseSnapshot.data()).notes || null : null),
    createdAt: toIso(therapist.createdAt),
    bio: asTrimmedString(therapist.bio),
    licenseNumber: asTrimmedString(therapist.licenseNumber),
    licenseIssuingAuthority: asTrimmedString(therapist.licenseIssuingAuthority),
    licenseRegion: asTrimmedString(therapist.licenseRegion),
    licenseExpiresAt: toIso(therapist.licenseExpiresAt),
    credentialEvidenceSummary: asTrimmedString(
      therapist.credentialEvidenceSummary,
    ),
    credentialSubmittedAt: toIso(therapist.credentialSubmittedAt),
    credentialVerifiedAt: toIso(therapist.credentialVerifiedAt),
    credentialVerifiedBy: asTrimmedString(therapist.credentialVerifiedBy),
    verificationMethod: asTrimmedString(therapist.verificationMethod),
    verificationReference: asTrimmedString(therapist.verificationReference),
    approvalBlockers: getTherapistApprovalBlockers(therapist),
    metrics: {
      appointments: appointmentSnapshot.size,
      confirmedAppointments: appointmentSnapshot.docs.filter(
        (doc) => normalizeStatus(doc.data().status, 'requested') === 'confirmed',
      ).length,
      completedAppointments: appointmentSnapshot.docs.filter(
        (doc) => normalizeStatus(doc.data().status, 'requested') === 'completed',
      ).length,
    },
    history,
  };
}

export async function getUsers(
  search = '',
  page = 1,
): Promise<PaginatedResult<UserRow>> {
  const query = search.trim().toLowerCase();

  if (query) {
    const snapshot = await db().collection('users').limit(250).get();
    const users = snapshot.docs
      .map((doc) => ({ id: doc.id, ...asRecord(doc.data()) }))
      .filter((user) => {
        const row = user as any;
        return [row.id, row.name, row.email]
          .filter(Boolean)
          .join(' ')
          .toLowerCase()
          .includes(query);
      }) as Array<Record<string, any> & { id: string }>;
    const rows = users.map((user) => ({
        id: user.id,
        name: user.name || user.email || user.id,
        email: user.email || null,
        role: typeof user.role === 'string' ? user.role : 'user',
        consentAccepted: user.consentAccepted === true,
        consentedTherapistsCount: Array.isArray(user.consentedTherapists)
          ? user.consentedTherapists.length
          : 0,
        createdAt: toIso(user.createdAt),
        lastLoginAt: toIso(user.lastLoginAt),
      }));

    return paginateRows(rows, page);
  }

  const normalizedPage = normalizePage(page);
  const { docs, hasNextPage } = await getCollectionPage('users', normalizedPage);
  return {
    items: docs.map(({ id, data }) => ({
      id,
      name: data.name || data.email || id,
      email: data.email || null,
      role: typeof data.role === 'string' ? data.role : 'user',
      consentAccepted: data.consentAccepted === true,
      consentedTherapistsCount: Array.isArray(data.consentedTherapists)
        ? data.consentedTherapists.length
        : 0,
      createdAt: toIso(data.createdAt),
      lastLoginAt: toIso(data.lastLoginAt),
    })),
    page: normalizedPage,
    pageSize: ADMIN_PAGE_SIZE,
    hasNextPage,
  };
}

export async function getUserById(userId: string): Promise<UserDetail | null> {
  const [userSnapshot, appointmentSnapshot, moodSnapshot, dataRightsSnapshot] =
    await Promise.all([
      db().collection('users').doc(userId).get(),
      db().collection('appointments').where('userId', '==', userId).limit(25).get(),
      db().collection('moods').where('userId', '==', userId).get(),
      db().collection('data_rights_jobs').where('userId', '==', userId).limit(25).get(),
    ]);

  if (!userSnapshot.exists) {
    return null;
  }

  const user = asRecord(userSnapshot.data());
  const recentAppointments = appointmentSnapshot.docs
    .map((doc) => mapAppointmentRow(doc.id, asRecord(doc.data())))
    .sort((left, right) => {
      const leftTime = new Date(left.updatedAt || left.scheduledAt || 0).valueOf();
      const rightTime = new Date(right.updatedAt || right.scheduledAt || 0).valueOf();
      return rightTime - leftTime;
    });
  const recentDataRightsJobs = dataRightsSnapshot.docs
    .map((doc) => mapDataRightsJob(doc.id, asRecord(doc.data())))
    .sort((left, right) => {
      const leftTime = new Date(left.createdAt || 0).valueOf();
      const rightTime = new Date(right.createdAt || 0).valueOf();
      return rightTime - leftTime;
    });

  return {
    id: userId,
    name: user.name || user.email || userId,
    email: user.email || null,
    role: typeof user.role === 'string' ? user.role : 'user',
    consentAccepted: user.consentAccepted === true,
    consentedTherapistsCount: Array.isArray(user.consentedTherapists)
      ? user.consentedTherapists.length
      : 0,
    createdAt: toIso(user.createdAt),
    lastLoginAt: toIso(user.lastLoginAt),
    consentedTherapists: Array.isArray(user.consentedTherapists)
      ? user.consentedTherapists
      : [],
    metrics: {
      moodEntries: moodSnapshot.size,
      appointments: appointmentSnapshot.size,
      activeAppointments: appointmentSnapshot.docs.filter((doc) =>
        ['requested', 'confirmed', 'completed', 'no_show'].includes(
          normalizeStatus(doc.data().status, 'requested'),
        ),
      ).length,
    },
    recentAppointments,
    recentDataRightsJobs,
  };
}

export async function getAppointments(
  status = '',
  page = 1,
): Promise<PaginatedResult<AppointmentRow>> {
  const normalizedPage = normalizePage(page);
  const query = status
    ? db()
        .collection('appointments')
        .where('status', '==', status)
        .orderBy(FieldPath.documentId())
    : db().collection('appointments').orderBy(FieldPath.documentId());
  const snapshot = await query
    .offset((normalizedPage - 1) * ADMIN_PAGE_SIZE)
    .limit(ADMIN_PAGE_SIZE + 1)
    .get();

  return {
    items: snapshot.docs
      .slice(0, ADMIN_PAGE_SIZE)
      .map((doc) => mapAppointmentRow(doc.id, asRecord(doc.data()))),
    page: normalizedPage,
    pageSize: ADMIN_PAGE_SIZE,
    hasNextPage: snapshot.docs.length > ADMIN_PAGE_SIZE,
  };
}

export async function getAppointmentById(
  appointmentId: string,
): Promise<AppointmentDetail | null> {
  const appointmentSnapshot = await db()
    .collection('appointments')
    .doc(appointmentId)
    .get();

  if (!appointmentSnapshot.exists) {
    return null;
  }

  const appointment = asRecord(appointmentSnapshot.data());
  const userId =
    typeof appointment.userId === 'string' ? appointment.userId : null;
  const therapistId =
    typeof appointment.therapistId === 'string' ? appointment.therapistId : null;
  const meetingRoomId =
    typeof appointment.meetingRoomId === 'string'
      ? appointment.meetingRoomId
      : null;
  const normalizedAppointmentStatus = normalizeStatus(
    appointment.status,
    'requested',
  );
  const chatRoomId =
    userId && therapistId ? buildChatRoomId(userId, therapistId) : null;

  const [
    userSnapshot,
    therapistSnapshot,
    callSnapshot,
    chatSnapshot,
    callerCandidates,
    calleeCandidates,
  ] = await Promise.all([
    userId ? db().collection('users').doc(userId).get() : null,
    therapistId ? db().collection('users').doc(therapistId).get() : null,
    meetingRoomId ? db().collection('calls').doc(meetingRoomId).get() : null,
    chatRoomId
      ? db().collection('therapist_chats').doc(chatRoomId).get()
      : null,
    meetingRoomId
      ? db()
          .collection('calls')
          .doc(meetingRoomId)
          .collection('callerCandidates')
          .limit(100)
          .get()
      : null,
    meetingRoomId
      ? db()
          .collection('calls')
          .doc(meetingRoomId)
          .collection('calleeCandidates')
          .limit(100)
          .get()
      : null,
  ]);

  const user = userSnapshot?.exists ? asRecord(userSnapshot.data()) : {};
  const therapist = therapistSnapshot?.exists
    ? asRecord(therapistSnapshot.data())
    : {};
  const callData = callSnapshot?.exists ? asRecord(callSnapshot.data()) : {};
  const chatData = chatSnapshot?.exists ? asRecord(chatSnapshot.data()) : {};

  return {
    ...mapAppointmentRow(appointmentSnapshot.id, appointment),
    createdAt: toIso(appointment.createdAt),
    userEmail: typeof user.email === 'string' ? user.email : null,
    therapistEmail:
      typeof therapist.email === 'string' ? therapist.email : null,
    statusUpdatedBy:
      typeof appointment.statusUpdatedBy === 'string'
        ? appointment.statusUpdatedBy
        : null,
    relationshipType:
      typeof chatData.relationshipType === 'string'
        ? chatData.relationshipType
        : null,
    canCall: chatData.canCall === true,
    timeline: buildAppointmentTimeline(appointment),
    communication: {
      chatRoomId,
      chatUpdatedAt: toIso(chatData.updatedAt),
      callRoomId:
        meetingRoomId ||
        (normalizedAppointmentStatus === 'confirmed' ||
                normalizedAppointmentStatus === 'completed'
          ? buildCallRoomId(appointmentSnapshot.id)
          : null),
      callStatus:
        typeof callData.status === 'string'
          ? normalizeStatus(callData.status, 'ready')
          : null,
      callUpdatedAt: toIso(callData.updatedAt),
      audioOnly: callData.audioOnly === true,
      callerId: typeof callData.callerId === 'string' ? callData.callerId : null,
      callerCandidates: callerCandidates?.size ?? 0,
      calleeCandidates: calleeCandidates?.size ?? 0,
    },
  };
}

export async function getAIIncidents(
  page = 1,
): Promise<PaginatedResult<IncidentRow>> {
  const normalizedPage = normalizePage(page);
  const { docs, hasNextPage } = await getCollectionPage(
    'ai_incidents',
    normalizedPage,
  );
  return {
    items: docs
      .map(({ id, data }) => mapIncidentRow(id, data))
      .sort((left, right) => {
        const leftTime = new Date(left.createdAt || 0).valueOf();
        const rightTime = new Date(right.createdAt || 0).valueOf();
        return rightTime - leftTime;
      }),
    page: normalizedPage,
    pageSize: ADMIN_PAGE_SIZE,
    hasNextPage,
  };
}

export async function getAIIncidentById(
  incidentId: string,
): Promise<IncidentDetail | null> {
  const incidentSnapshot = await db().collection('ai_incidents').doc(incidentId).get();
  if (!incidentSnapshot.exists) {
    return null;
  }

  const incident = asRecord(incidentSnapshot.data());
  const userId = typeof incident.userId === 'string' ? incident.userId : null;
  const userSnapshot = userId
    ? await db().collection('users').doc(userId).get()
    : null;
  const user = userSnapshot?.exists ? asRecord(userSnapshot.data()) : {};

  return {
    ...mapIncidentRow(incidentSnapshot.id, incident),
    userName:
      typeof user.name === 'string'
        ? user.name
        : typeof user.email === 'string'
        ? user.email
        : userId,
    userEmail: typeof user.email === 'string' ? user.email : null,
    opsNotes: typeof incident.opsNotes === 'string' ? incident.opsNotes : null,
    metadata: asRecord(incident.metadata),
  };
}

export async function getSupportCases(
  page = 1,
): Promise<PaginatedResult<SupportCase>> {
  const normalizedPage = normalizePage(page);
  const { docs, hasNextPage } = await getCollectionPage(
    'support_cases',
    normalizedPage,
  );
  return {
    items: docs
      .map(({ id, data }) => ({
        id,
        title: data.title || 'Untitled case',
        status: data.status || 'open',
        priority: data.priority || 'normal',
        owner: typeof data.owner === 'string' ? data.owner : null,
        category: typeof data.category === 'string' ? data.category : null,
        requesterId:
          typeof data.requesterId === 'string' ? data.requesterId : null,
        summary: typeof data.summary === 'string' ? data.summary : null,
        createdAt: toIso(data.createdAt),
        updatedAt: toIso(data.updatedAt),
      }))
      .sort((left, right) => {
        const leftTime = new Date(left.updatedAt || left.createdAt || 0).valueOf();
        const rightTime = new Date(right.updatedAt || right.createdAt || 0).valueOf();
        return rightTime - leftTime;
      }),
    page: normalizedPage,
    pageSize: ADMIN_PAGE_SIZE,
    hasNextPage,
  };
}

export async function getDataRightsJobs(
  page = 1,
): Promise<PaginatedResult<DataRightsJob>> {
  const normalizedPage = normalizePage(page);
  const { docs, hasNextPage } = await getCollectionPage(
    'data_rights_jobs',
    normalizedPage,
  );
  return {
    items: docs
      .map(({ id, data }) => mapDataRightsJob(id, data))
      .sort((left, right) => {
        const leftTime = new Date(left.createdAt || 0).valueOf();
        const rightTime = new Date(right.createdAt || 0).valueOf();
        return rightTime - leftTime;
      }),
    page: normalizedPage,
    pageSize: ADMIN_PAGE_SIZE,
    hasNextPage,
  };
}

export async function getDataRightsJobById(
  jobId: string,
): Promise<DataRightsJob | null> {
  const snapshot = await db().collection('data_rights_jobs').doc(jobId).get();
  if (!snapshot.exists) {
    return null;
  }
  return mapDataRightsJob(snapshot.id, asRecord(snapshot.data()));
}

export async function getFeatureFlags(): Promise<FeatureFlag[]> {
  const snapshot = await db().collection('feature_flags').limit(100).get();
  const persistedFlags = snapshot.docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      description: data.description || '',
      enabled: data.enabled === true,
      rollout: typeof data.rollout === 'number' ? data.rollout : 100,
      audience: data.audience || 'all',
      updatedAt: toIso(data.updatedAt),
    };
  });
  return mergeFeatureFlags(persistedFlags);
}

export async function getAuditEntries(
  page = 1,
): Promise<PaginatedResult<AuditEntry>> {
  const normalizedPage = normalizePage(page);
  const { docs, hasNextPage } = await getCollectionPage(
    'admin_audit_logs',
    normalizedPage,
  );
  return {
    items: docs.map(({ id, data }) => ({
      id,
      actorId: data.actorId || null,
      actorEmail: data.actorEmail || null,
      actorRoles: Array.isArray(data.actorRoles) ? data.actorRoles : [],
      action: data.action || null,
      targetType: data.targetType || null,
      targetId: data.targetId || null,
      metadata: data.metadata || {},
      createdAt: toIso(data.createdAt),
    })),
    page: normalizedPage,
    pageSize: ADMIN_PAGE_SIZE,
    hasNextPage,
  };
}

export const getSystemHealthSnapshot = cache(
  async (): Promise<SystemHealthSnapshot> => {
    const since = new Date(Date.now() - 24 * 60 * 60 * 1000);

    const [
      totalTherapists,
      approvedTherapists,
      openAiIncidents,
      unassignedAiIncidents,
      highSeverityAiIncidents,
      privacyQueue,
      openAppointments,
      confirmedAppointmentsMissingRoom,
      activeCallRooms,
      stalePrivacyJobs,
      recentUnhandledErrors,
      recentNotificationsSent,
      recentNotificationFailures,
      unreadNotifications,
      notificationDeadLetters,
      recentAiDegradations,
    ] = await Promise.all([
      safeAggregateCount('health therapists total', () =>
        db().collection('therapists').count().get(),
      ),
      safeAggregateCount('health approved therapists', () =>
        db().collection('therapists').where('isApproved', '==', true).count().get(),
      ),
      safeAggregateCount('health open incidents', () =>
        db()
          .collection('ai_incidents')
          .where('status', 'in', ['open', 'acknowledged', 'in_progress'])
          .count()
          .get(),
      ),
      safeAggregateCount('health unassigned incidents', () =>
        db()
          .collection('ai_incidents')
          .where('status', 'in', ['open', 'acknowledged', 'in_progress'])
          .where('assignedTo', '==', null)
          .count()
          .get(),
      ),
      safeAggregateCount('health high severity incidents', () =>
        db()
          .collection('ai_incidents')
          .where('status', 'in', ['open', 'acknowledged', 'in_progress'])
          .where('severity', '==', 'high')
          .count()
          .get(),
      ),
      safeAggregateCount('health privacy queue', () =>
        db()
          .collection('data_rights_jobs')
          .where('opsStatus', 'in', ['open', 'acknowledged', 'in_progress'])
          .count()
          .get(),
      ),
      safeAggregateCount('health open appointments', () =>
        db()
          .collection('appointments')
          .where('status', 'in', ['requested', 'confirmed'])
          .count()
          .get(),
      ),
      safeAggregateCount('health appointments missing room', () =>
        db()
          .collection('appointments')
          .where('status', 'in', ['confirmed', 'completed'])
          .where('meetingRoomId', '==', null)
          .count()
          .get(),
      ),
      safeAggregateCount('health active call rooms', () =>
        db()
          .collection('calls')
          .where('status', 'in', ['ready', 'calling', 'connected'])
          .count()
          .get(),
      ),
      safeAggregateCount('health stale privacy jobs', () =>
        db()
          .collection('data_rights_jobs')
          .where('opsStatus', 'in', ['open', 'acknowledged', 'in_progress'])
          .where('createdAt', '<', since)
          .count()
          .get(),
      ),
      safeAggregateCount('health recent unhandled errors', () =>
        db()
          .collection('release_health_events')
          .where('eventName', '==', 'app.unhandled_error')
          .where('createdAt', '>=', since)
          .count()
          .get(),
      ),
      safeAggregateCount('health recent notifications sent', () =>
        db()
          .collection('notification_delivery_logs')
          .where('status', '==', 'sent')
          .where('createdAt', '>=', since)
          .count()
          .get(),
      ),
      safeAggregateCount('health recent notification failures', () =>
        db()
          .collection('notification_delivery_logs')
          .where('status', '==', 'failed')
          .where('createdAt', '>=', since)
          .count()
          .get(),
      ),
      safeAggregateCount('health unread notifications', () =>
        db().collectionGroup('notifications').where('read', '==', false).count().get(),
      ),
      safeAggregateCount('health notification dead letters', () =>
        db()
          .collection('notification_failures')
          .where('status', '==', 'dead_letter')
          .count()
          .get(),
      ),
      safeQuerySnapshot('health recent ai degradations', () =>
        db()
          .collection('release_health_events')
          .where('eventName', '==', 'chat.ai_status_changed')
          .where('createdAt', '>=', since)
          .limit(200)
          .get(),
      ).then((snapshot) =>
        snapshot.docs.filter((doc) => {
          const status = asRecord(doc.data()).attributes?.status;
          return ['degraded', 'fallback', 'crisis'].includes(String(status));
        }).length,
      ),
    ]);

    return {
      therapistReviewBacklog: Math.max(0, totalTherapists - approvedTherapists),
      openAiIncidents,
      unassignedAiIncidents,
      highSeverityAiIncidents,
      privacyQueue,
      openAppointments,
      confirmedAppointmentsMissingRoom,
      activeCallRooms,
      stalePrivacyJobs,
      recentUnhandledErrors,
      recentAiDegradations,
      recentNotificationsSent,
      recentNotificationFailures,
      unreadNotifications,
      notificationDeadLetters,
    };
  },
);

export const getNotificationHealthSummary = cache(
  async (): Promise<NotificationHealthSummary> => {
    const [
      sentCount,
      failedCount,
      emailFailures,
      pushFailures,
      unreadCount,
      totalTrackedNotifications,
      deadLetters,
      failureSnapshots,
      preferenceDocs,
    ] = await Promise.all([
      safeAggregateCount('notification sent count', () =>
        db()
          .collection('notification_delivery_logs')
          .where('status', '==', 'sent')
          .count()
          .get(),
      ),
      safeAggregateCount('notification failed count', () =>
        db()
          .collection('notification_delivery_logs')
          .where('status', '==', 'failed')
          .count()
          .get(),
      ),
      safeAggregateCount('notification email failures', () =>
        db()
          .collection('notification_delivery_logs')
          .where('status', '==', 'failed')
          .where('channel', '==', 'email')
          .count()
          .get(),
      ),
      safeAggregateCount('notification push failures', () =>
        db()
          .collection('notification_delivery_logs')
          .where('status', '==', 'failed')
          .where('channel', '==', 'push')
          .count()
          .get(),
      ),
      safeAggregateCount('notification unread count', () =>
        db().collectionGroup('notifications').where('read', '==', false).count().get(),
      ),
      safeAggregateCount('notification total count', () =>
        db().collectionGroup('notifications').count().get(),
      ),
      safeAggregateCount('notification dead letters', () =>
        db()
          .collection('notification_failures')
          .where('status', '==', 'dead_letter')
          .count()
          .get(),
      ),
      safeQuerySnapshot('notification failure types', () =>
        db().collection('notification_failures').limit(200).get(),
      ),
      safeQuerySnapshot('notification preferences ops summary', () =>
        db().collectionGroup('preferences').limit(500).get(),
      ),
    ]);

    const preferenceRows = preferenceDocs.docs
      .filter((doc) => doc.id === 'notifications')
      .map((doc) => asRecord(doc.data()));

    const failureTypeCounts = new Map<string, number>();
    for (const doc of failureSnapshots.docs) {
      const type = asTrimmedString(asRecord(doc.data()).type) || 'unknown';
      failureTypeCounts.set(type, (failureTypeCounts.get(type) || 0) + 1);
    }

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
        totalTrackedNotifications > 0
          ? Number((unreadCount / totalTrackedNotifications).toFixed(2))
          : 0,
      deadLetters,
      pushOptOutUsers: preferenceRows.filter((doc) => doc.pushEnabled === false)
        .length,
      emailOptOutUsers: preferenceRows.filter(
        (doc) => doc.emailEnabled === false,
      ).length,
      mutedWellnessUsers: preferenceRows.filter(
        (doc) =>
          doc.dailyMoodReminderEnabled === false &&
          doc.moodForecastEnabled === false &&
          doc.moodQuotesEnabled === false,
      ).length,
      totalPreferenceProfiles: preferenceRows.length,
      totalTrackedNotifications,
      topFailingTypes: [...failureTypeCounts.entries()]
        .sort((left, right) => right[1] - left[1])
        .slice(0, 5)
        .map(([type, count]) => ({ type, count })),
    };
  },
);

export async function applyTherapistDecision(params: {
  therapistId: string;
  decision: 'approve' | 'reject' | 'suspend';
  notes?: string;
  verificationMethod?: string;
  verificationReference?: string;
  actor: AdminSession;
}) {
  const notes = asTrimmedString(params.notes);
  if (!notes || notes.length < 12) {
    throw new Error(
      'Reviewer notes are required so therapist decisions remain auditable.',
    );
  }

  const therapistRef = db().collection('therapists').doc(params.therapistId);
  const [therapistSnapshot, userSnapshot] = await Promise.all([
    therapistRef.get(),
    db().collection('users').doc(params.therapistId).get(),
  ]);

  if (!therapistSnapshot.exists) {
    throw new Error('Therapist profile not found.');
  }

  const therapist = asRecord(therapistSnapshot.data());
  const user = userSnapshot.exists ? asRecord(userSnapshot.data()) : {};

  const decisionMap = {
    approve: {
      isApproved: true,
      reviewStatus: 'approved',
      accountStatus: 'active',
      credentialVerificationStatus: 'verified',
    },
    reject: {
      isApproved: false,
      reviewStatus: 'rejected',
      accountStatus: 'restricted',
      credentialVerificationStatus: 'rejected',
    },
    suspend: {
      isApproved: false,
      reviewStatus: 'suspended',
      accountStatus: 'suspended',
      credentialVerificationStatus: 'suspended',
    },
  } as const;

  if (params.decision === 'approve') {
    assertTherapistApprovalReady(
      therapist,
      params.verificationMethod,
      params.verificationReference,
    );
  }

  await therapistRef.set(
    {
      ...decisionMap[params.decision],
      reviewedAt: FieldValue.serverTimestamp(),
      reviewedBy: params.actor.uid,
      reviewNotes: notes,
      updatedAt: FieldValue.serverTimestamp(),
      verificationMethod:
        params.decision === 'approve'
          ? asTrimmedString(params.verificationMethod)
          : therapist.verificationMethod || null,
      verificationReference:
        params.decision === 'approve'
          ? asTrimmedString(params.verificationReference)
          : therapist.verificationReference || null,
      credentialVerifiedAt:
        params.decision === 'approve' ? FieldValue.serverTimestamp() : null,
      credentialVerifiedBy:
        params.decision === 'approve' ? params.actor.uid : null,
    },
    { merge: true },
  );

  if (params.decision === 'approve') {
    await db()
      .collection('public_therapists')
      .doc(params.therapistId)
      .set(
        buildPublicTherapistProfile(
          params.therapistId,
          therapist,
          asTrimmedString(user.name),
        ),
        { merge: true },
      );
  } else {
    await db().collection('public_therapists').doc(params.therapistId).delete().catch(() => null);
  }

  await db()
    .collection('therapist_review_cases')
    .doc(params.therapistId)
    .set(
      {
        therapistId: params.therapistId,
        decision: params.decision,
        notes,
        verificationMethod:
          params.decision === 'approve'
            ? asTrimmedString(params.verificationMethod)
            : null,
        verificationReference:
          params.decision === 'approve'
            ? asTrimmedString(params.verificationReference)
            : null,
        reviewedAt: FieldValue.serverTimestamp(),
        reviewedBy: params.actor.uid,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

  await db()
    .collection('therapist_review_events')
    .add({
      therapistId: params.therapistId,
      decision: params.decision,
      notes,
      verificationMethod:
        params.decision === 'approve'
          ? asTrimmedString(params.verificationMethod)
          : null,
      verificationReference:
        params.decision === 'approve'
          ? asTrimmedString(params.verificationReference)
          : null,
      reviewedAt: FieldValue.serverTimestamp(),
      reviewedBy: params.actor.uid,
      reviewerRoles: params.actor.roles,
    });

  await writeAuditLog(params.actor, `therapist.${params.decision}`, 'therapist', params.therapistId, {
    notes,
    previousReviewStatus: therapist.reviewStatus || 'pending',
    previousCredentialVerificationStatus:
      therapist.credentialVerificationStatus || 'pending_review',
    verificationMethod:
      params.decision === 'approve'
        ? asTrimmedString(params.verificationMethod)
        : null,
    verificationReferenceProvided:
      params.decision === 'approve' &&
      Boolean(asTrimmedString(params.verificationReference)),
  });
}

export async function upsertFeatureFlag(params: {
  id: string;
  description: string;
  enabled: boolean;
  rollout: number;
  audience: string;
  changeReason?: string;
  actor: AdminSession;
}) {
  const changeReason = asTrimmedString(params.changeReason);
  if (!changeReason || changeReason.length < 12) {
    throw new Error('Feature flag changes require a documented reason.');
  }

  await db()
    .collection('feature_flags')
    .doc(params.id)
    .set(
      {
        description: params.description,
        enabled: params.enabled,
        rollout: params.rollout,
        audience: params.audience,
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: params.actor.uid,
        lastChangeReason: changeReason,
      },
      { merge: true },
    );

  await writeAuditLog(
    params.actor,
    'feature_flag.upsert',
    'feature_flag',
    params.id,
    {
      enabled: params.enabled,
      rollout: params.rollout,
      audience: params.audience,
      changeReason,
    },
  );
}

export async function updateDataRightsJobOps(params: {
  jobId: string;
  opsStatus: 'open' | 'acknowledged' | 'in_progress' | 'closed';
  opsNotes?: string;
  opsOwner?: string;
  actor: AdminSession;
}) {
  const jobRef = db().collection('data_rights_jobs').doc(params.jobId);
  const snapshot = await jobRef.get();
  if (!snapshot.exists) {
    throw new Error('Privacy job not found.');
  }

  await jobRef
    .set(
      {
        opsStatus: params.opsStatus,
        opsNotes: params.opsNotes || null,
        opsOwner: params.opsOwner || params.actor.uid,
        opsUpdatedBy: params.actor.uid,
        opsUpdatedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

  await writeAuditLog(
    params.actor,
    'privacy_job.update_ops',
    'data_rights_job',
    params.jobId,
    {
      opsStatus: params.opsStatus,
      opsOwner: params.opsOwner || params.actor.uid,
      notesProvided: Boolean(params.opsNotes),
    },
  );
}

export async function updateAIIncidentOps(params: {
  incidentId: string;
  status: 'open' | 'acknowledged' | 'in_progress' | 'resolved';
  opsNotes?: string;
  assignedTo?: string;
  actor: AdminSession;
}) {
  const incidentRef = db().collection('ai_incidents').doc(params.incidentId);
  const snapshot = await incidentRef.get();
  if (!snapshot.exists) {
    throw new Error('AI incident not found.');
  }

  await incidentRef.set(
    {
      status: params.status,
      opsNotes: params.opsNotes || null,
      assignedTo: params.assignedTo || params.actor.uid,
      updatedAt: FieldValue.serverTimestamp(),
      resolvedAt:
        params.status === 'resolved' ? FieldValue.serverTimestamp() : null,
      updatedBy: params.actor.uid,
    },
    { merge: true },
  );

  await writeAuditLog(
    params.actor,
    'ai_incident.update_ops',
    'ai_incident',
    params.incidentId,
    {
      status: params.status,
      assignedTo: params.assignedTo || params.actor.uid,
      notesProvided: Boolean(params.opsNotes),
    },
  );
}

export async function createSupportCase(params: {
  title: string;
  summary?: string;
  priority: 'low' | 'normal' | 'high' | 'urgent';
  category: string;
  requesterId?: string;
  actor: AdminSession;
}) {
  const title = asTrimmedString(params.title);
  const summary = asTrimmedString(params.summary);
  const category = asTrimmedString(params.category);

  if (!title || title.length < 6) {
    throw new Error('Support cases need a clear title.');
  }

  if (!category) {
    throw new Error('Support cases need a category.');
  }

  const caseRef = db().collection('support_cases').doc();
  await caseRef.set({
    title,
    summary,
    category,
    priority: params.priority,
    status: 'open',
    owner: params.actor.uid,
    requesterId: asTrimmedString(params.requesterId),
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
    createdBy: params.actor.uid,
    updatedBy: params.actor.uid,
  });

  await writeAuditLog(
    params.actor,
    'support_case.create',
    'support_case',
    caseRef.id,
    {
      category,
      priority: params.priority,
      requesterId: asTrimmedString(params.requesterId),
      summaryProvided: Boolean(summary),
    },
  );
}

export async function updateSupportCase(params: {
  caseId: string;
  status: 'open' | 'in_progress' | 'waiting_on_user' | 'resolved' | 'closed';
  priority: 'low' | 'normal' | 'high' | 'urgent';
  owner?: string;
  summary?: string;
  actor: AdminSession;
}) {
  const caseRef = db().collection('support_cases').doc(params.caseId);
  const snapshot = await caseRef.get();
  if (!snapshot.exists) {
    throw new Error('Support case not found.');
  }

  const summary = asTrimmedString(params.summary);
  await caseRef.set(
    {
      status: params.status,
      priority: params.priority,
      owner: asTrimmedString(params.owner) || params.actor.uid,
      summary,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: params.actor.uid,
    },
    { merge: true },
  );

  await writeAuditLog(
    params.actor,
    'support_case.update',
    'support_case',
    params.caseId,
    {
      status: params.status,
      priority: params.priority,
      owner: asTrimmedString(params.owner) || params.actor.uid,
      summaryProvided: Boolean(summary),
    },
  );
}

async function writeAuditLog(
  actor: AdminSession,
  action: string,
  targetType: string,
  targetId: string,
  metadata: Record<string, unknown>,
) {
  await db().collection('admin_audit_logs').add({
    actorId: actor.uid,
    actorEmail: actor.email,
    actorRoles: actor.roles,
    action,
    targetType,
    targetId,
    metadata,
    createdAt: FieldValue.serverTimestamp(),
  });
}

function getStorageBucket() {
  const app = getFirebaseAdminApp();
  const bucketName =
    process.env.FIREBASE_STORAGE_BUCKET || app.options.storageBucket;
  if (!bucketName) {
    return null;
  }
  return getStorage(app).bucket(bucketName);
}

async function deleteStoragePrefix(prefix: string) {
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
      return { deletedFiles: 0, warnings: [] as string[] };
    }

    await Promise.all(
      files.map((file) =>
        file.delete({ ignoreNotFound: true }).catch(() => undefined),
      ),
    );
    return { deletedFiles: files.length, warnings: [] as string[] };
  } catch (error) {
    return {
      deletedFiles: 0,
      warnings: [
        error instanceof Error ? error.message : 'storage_cleanup_failed',
      ],
    };
  }
}

async function deleteDocumentRefs(
  refs: Array<{ delete(): Promise<unknown> }>,
): Promise<number> {
  if (!refs.length) {
    return 0;
  }

  let deleted = 0;
  for (let index = 0; index < refs.length; index += 400) {
    const batch = db().batch();
    const chunk = refs.slice(index, index + 400);
    chunk.forEach((ref) => batch.delete(ref as never));
    await batch.commit();
    deleted += chunk.length;
  }
  return deleted;
}

function uniqueDocsById(
  ...snapshots: Array<{ docs?: Array<{ id: string; ref: { delete(): Promise<unknown> }; data(): Record<string, any> }> } | null | undefined>
) {
  const docsById = new Map<
    string,
    { id: string; ref: { delete(): Promise<unknown> }; data(): Record<string, any> }
  >();
  snapshots.forEach((snapshot) => {
    snapshot?.docs?.forEach((doc) => {
      docsById.set(doc.id, doc);
    });
  });
  return Array.from(docsById.values());
}

async function deleteCallRoomById(roomId: string) {
  const roomRef = db().collection('calls').doc(roomId);
  const [callerCandidates, calleeCandidates] = await Promise.all([
    roomRef.collection('callerCandidates').get(),
    roomRef.collection('calleeCandidates').get(),
  ]);

  await deleteDocumentRefs(callerCandidates.docs.map((doc) => doc.ref));
  await deleteDocumentRefs(calleeCandidates.docs.map((doc) => doc.ref));

  try {
    await roomRef.delete();
  } catch {
    // Missing rooms should not fail the whole delete operation.
  }

  return {
    callerCandidates: callerCandidates.size,
    calleeCandidates: calleeCandidates.size,
  };
}

async function deleteTherapistChatRoomById(roomId: string) {
  const roomRef = db().collection('therapist_chats').doc(roomId);
  const messages = await roomRef.collection('messages').get();
  const deletedMessages = await deleteDocumentRefs(
    messages.docs.map((doc) => doc.ref),
  );
  const storageCleanup = await deleteStoragePrefix(`therapist_chats/${roomId}`);

  try {
    await roomRef.delete();
  } catch {
    // Best effort.
  }

  return {
    deletedMessages,
    deletedFiles: storageCleanup.deletedFiles,
    warnings: storageCleanup.warnings,
  };
}

async function revokeUserNotificationData(uid: string) {
  const [deviceSnapshot, notificationSnapshot, notificationJobSnapshot] =
    await Promise.all([
      db().collection('users').doc(uid).collection('devices').get(),
      db().collection('users').doc(uid).collection('notifications').get(),
      db().collection('notification_jobs').where('userId', '==', uid).limit(200).get(),
    ]);

  const refs = [
    ...deviceSnapshot.docs.map((doc) => doc.ref),
    ...notificationSnapshot.docs.map((doc) => doc.ref),
    ...notificationJobSnapshot.docs.map((doc) => doc.ref),
  ];
  await deleteDocumentRefs(refs);
}

async function deleteAccountProfile(uid: string) {
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
    db().collection('moods').where('userId', '==', uid).get(),
    db().collection('chats').where('userId', '==', uid).get(),
    db().collection('appointments').where('userId', '==', uid).get(),
    db().collection('appointments').where('therapistId', '==', uid).get(),
    db().collection('therapist_chats').where('userId', '==', uid).get(),
    db().collection('therapist_chats').where('therapistId', '==', uid).get(),
    db().collection('calls').where('userId', '==', uid).get(),
    db().collection('calls').where('therapistId', '==', uid).get(),
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
    warnings: [] as string[],
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
    const therapistRef = db().collection('therapists').doc(uid);
    const publicTherapistRef = db().collection('public_therapists').doc(uid);
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
  } catch {
    summary.warnings.push('therapist_profile_cleanup_failed');
  }

  try {
    await db()
      .collection('users')
      .doc(uid)
      .set({ consentedTherapists: [] }, { merge: true });
  } catch {
    summary.warnings.push('consent_cleanup_failed');
  }

  try {
    await revokeUserNotificationData(uid);
  } catch {
    summary.warnings.push('notification_cleanup_failed');
  }

  try {
    await db().collection('users').doc(uid).delete();
  } catch {
    summary.warnings.push('user_profile_delete_failed');
  }

  await getAuth(getFirebaseAdminApp()).deleteUser(uid);

  return summary;
}

export async function deleteUserProfile(params: {
  userId: string;
  actor: AdminSession;
}) {
  if (params.actor.uid === params.userId) {
    throw new Error(
      'Delete your own admin-linked account from the app itself, not from the admin portal.',
    );
  }

  const userRef = db().collection('users').doc(params.userId);
  const snapshot = await userRef.get();
  if (!snapshot.exists) {
    throw new Error('User profile not found.');
  }

  const summary = await deleteAccountProfile(params.userId);
  await writeAuditLog(params.actor, 'user.delete', 'user', params.userId, {
    summary,
  });
  return summary;
}

export async function deleteTherapistProfile(params: {
  therapistId: string;
  actor: AdminSession;
}) {
  if (params.actor.uid === params.therapistId) {
    throw new Error(
      'Delete your own admin-linked account from the app itself, not from the admin portal.',
    );
  }

  const therapistRef = db().collection('therapists').doc(params.therapistId);
  const snapshot = await therapistRef.get();
  if (!snapshot.exists) {
    throw new Error('Therapist profile not found.');
  }

  const summary = await deleteAccountProfile(params.therapistId);
  await writeAuditLog(
    params.actor,
    'therapist.delete',
    'therapist',
    params.therapistId,
    { summary },
  );
  return summary;
}
