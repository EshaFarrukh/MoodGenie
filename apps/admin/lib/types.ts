export type AdminRole =
  | 'super_admin'
  | 'clinical_ops'
  | 'support_ops'
  | 'trust_safety'
  | 'read_only_analytics';

export type DashboardSummary = {
  totalUsers: number;
  totalTherapists: number;
  approvedTherapists: number;
  therapistsAwaitingReview: number;
  openAppointments: number;
  completedAppointments: number;
  aiIncidents: number;
  openDataRightsJobs: number;
};

export type PaginatedResult<T> = {
  items: T[];
  page: number;
  pageSize: number;
  hasNextPage: boolean;
};

export type AdminSession = {
  uid: string;
  email: string | null;
  displayName: string;
  roles: AdminRole[];
  authTime: string | null;
  authAgeSeconds: number | null;
  mfaVerified: boolean;
  signInProvider: string | null;
  bootstrapProvisioned: boolean;
};

export type TherapistReviewRow = {
  id: string;
  userId: string;
  name: string;
  email: string | null;
  professionalTitle: string | null;
  specialty: string | null;
  yearsExperience: number | null;
  acceptingNewPatients: boolean;
  reviewStatus: string;
  credentialVerificationStatus: string;
  reviewedAt: string | null;
  reviewedBy: string | null;
};

export type TherapistReviewHistoryEntry = {
  id: string;
  decision: string;
  notes: string | null;
  reviewedAt: string | null;
  reviewedBy: string | null;
  reviewerRoles: string[];
};

export type TherapistDetail = TherapistReviewRow & {
  accountStatus: string;
  reviewNotes: string | null;
  createdAt: string | null;
  displayName: string | null;
  bio: string | null;
  licenseNumber: string | null;
  licenseIssuingAuthority: string | null;
  licenseRegion: string | null;
  licenseExpiresAt: string | null;
  credentialEvidenceSummary: string | null;
  credentialSubmittedAt: string | null;
  credentialVerifiedAt: string | null;
  credentialVerifiedBy: string | null;
  verificationMethod: string | null;
  verificationReference: string | null;
  approvalBlockers: string[];
  metrics: {
    appointments: number;
    confirmedAppointments: number;
    completedAppointments: number;
  };
  history: TherapistReviewHistoryEntry[];
};

export type UserRow = {
  id: string;
  name: string;
  email: string | null;
  role: string;
  consentAccepted: boolean;
  consentedTherapistsCount: number;
  createdAt: string | null;
  lastLoginAt: string | null;
};

export type UserDetail = UserRow & {
  consentedTherapists: string[];
  metrics: {
    moodEntries: number;
    appointments: number;
    activeAppointments: number;
  };
  recentAppointments: AppointmentRow[];
  recentDataRightsJobs: DataRightsJob[];
};

export type AppointmentRow = {
  id: string;
  userId: string | null;
  therapistId: string | null;
  status: string;
  scheduledAt: string | null;
  updatedAt: string | null;
  meetingRoomId: string | null;
  userName: string | null;
  therapistName: string | null;
};

export type AppointmentTimelineEvent = {
  id: string;
  label: string;
  at: string | null;
};

export type AppointmentDetail = AppointmentRow & {
  createdAt: string | null;
  userEmail: string | null;
  therapistEmail: string | null;
  statusUpdatedBy: string | null;
  relationshipType: string | null;
  canCall: boolean;
  timeline: AppointmentTimelineEvent[];
  communication: {
    chatRoomId: string | null;
    chatUpdatedAt: string | null;
    callRoomId: string | null;
    callStatus: string | null;
    callUpdatedAt: string | null;
    audioOnly: boolean;
    callerId: string | null;
    callerCandidates: number;
    calleeCandidates: number;
  };
};

export type AuditEntry = {
  id: string;
  actorId: string | null;
  actorEmail: string | null;
  actorRoles: string[];
  action: string | null;
  targetType: string | null;
  targetId: string | null;
  metadata: Record<string, unknown>;
  createdAt: string | null;
};

export type FeatureFlag = {
  id: string;
  description: string;
  enabled: boolean;
  rollout: number;
  audience: string;
  updatedAt: string | null;
};

export type IncidentRow = {
  id: string;
  severity: string;
  status: string;
  title: string;
  category: string | null;
  source: string | null;
  userId: string | null;
  assignedTo: string | null;
  updatedAt: string | null;
  createdAt: string | null;
};

export type IncidentDetail = IncidentRow & {
  userName: string | null;
  userEmail: string | null;
  opsNotes: string | null;
  metadata: Record<string, unknown>;
};

export type DataRightsJob = {
  id: string;
  userId: string;
  type: string;
  status: string;
  opsStatus: string;
  requesterDisplayName: string | null;
  requesterEmail: string | null;
  requesterRole: string | null;
  requestSource: string | null;
  createdAt: string | null;
  updatedAt: string | null;
  completedAt: string | null;
  errorMessage: string | null;
  opsOwner: string | null;
  opsNotes: string | null;
  resultSummary: Record<string, unknown>;
};

export type SupportCase = {
  id: string;
  title: string;
  status: string;
  priority: string;
  owner: string | null;
  category: string | null;
  requesterId: string | null;
  summary: string | null;
  createdAt: string | null;
  updatedAt: string | null;
};

export type SystemHealthSnapshot = {
  therapistReviewBacklog: number;
  openAiIncidents: number;
  unassignedAiIncidents: number;
  highSeverityAiIncidents: number;
  privacyQueue: number;
  openAppointments: number;
  confirmedAppointmentsMissingRoom: number;
  activeCallRooms: number;
  stalePrivacyJobs: number;
  recentUnhandledErrors: number;
  recentAiDegradations: number;
  recentNotificationsSent: number;
  recentNotificationFailures: number;
  unreadNotifications: number;
  notificationDeadLetters: number;
};

export type NotificationFailureSummary = {
  type: string;
  count: number;
};

export type NotificationHealthSummary = {
  sentCount: number;
  failedCount: number;
  failureRate: number;
  emailFailures: number;
  pushFailures: number;
  unreadCount: number;
  unreadRate: number;
  deadLetters: number;
  pushOptOutUsers: number;
  emailOptOutUsers: number;
  mutedWellnessUsers: number;
  totalPreferenceProfiles: number;
  totalTrackedNotifications: number;
  topFailingTypes: NotificationFailureSummary[];
};
