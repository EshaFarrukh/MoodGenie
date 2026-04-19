import type { AdminRole } from '@/lib/types';

export type NavIcon =
  | 'dashboard'
  | 'users'
  | 'therapists'
  | 'bookings'
  | 'reports'
  | 'mood'
  | 'notifications'
  | 'flags'
  | 'settings';

export type NavItem = {
  href: string;
  label: string;
  description: string;
  icon: NavIcon;
  allowedRoles?: AdminRole[];
};

export const NAV_ITEMS: NavItem[] = [
  {
    href: '/',
    label: 'Dashboard',
    description: 'Platform overview, KPIs, and quick actions.',
    icon: 'dashboard',
  },
  {
    href: '/users',
    label: 'Users',
    description: 'Search accounts, roles, consent, and mood activity.',
    icon: 'users',
    allowedRoles: ['super_admin', 'support_ops', 'clinical_ops'],
  },
  {
    href: '/therapists/review-queue',
    label: 'Therapists',
    description: 'Approval queue, verification, and credential review.',
    icon: 'therapists',
    allowedRoles: ['super_admin', 'clinical_ops', 'support_ops'],
  },
  {
    href: '/appointments',
    label: 'Bookings',
    description: 'Sessions, schedules, communication, and status flow.',
    icon: 'bookings',
    allowedRoles: ['super_admin', 'support_ops', 'clinical_ops'],
  },
  {
    href: '/reports',
    label: 'Reports',
    description: 'Operational trends, exports, and engagement analytics.',
    icon: 'reports',
    allowedRoles: ['super_admin', 'support_ops', 'trust_safety', 'read_only_analytics'],
  },
  {
    href: '/mood-analytics',
    label: 'Mood Analytics',
    description: 'Mood distribution, wellbeing trends, and risk signals.',
    icon: 'mood',
    allowedRoles: ['super_admin', 'clinical_ops', 'read_only_analytics', 'trust_safety'],
  },
  {
    href: '/notifications',
    label: 'Notifications',
    description: 'Delivery health, opt-outs, and workflow messaging.',
    icon: 'notifications',
    allowedRoles: ['super_admin', 'support_ops', 'trust_safety', 'read_only_analytics'],
  },
  {
    href: '/ai-ops/incidents',
    label: 'Incident Flags',
    description: 'Crisis alerts, unsafe AI, complaints, and resolution flow.',
    icon: 'flags',
    allowedRoles: ['super_admin', 'trust_safety', 'support_ops'],
  },
  {
    href: '/settings',
    label: 'Settings',
    description: 'Feature flags, security posture, and platform controls.',
    icon: 'settings',
    allowedRoles: ['super_admin', 'trust_safety'],
  },
];

type PageMeta = {
  title: string;
  description: string;
  breadcrumbs: string[];
};

const FALLBACK_PAGE_META: PageMeta = {
  title: 'Admin Portal',
  description:
    'Operate MoodGenie with high-trust controls across users, therapists, incidents, and platform configuration.',
  breadcrumbs: ['Admin'],
};

export function getPageMeta(pathname: string): PageMeta {
  if (pathname === '/') {
    return {
      title: 'Executive Dashboard',
      description:
        'Track adoption, therapist operations, platform risk, and launch readiness from one high-trust operational surface.',
      breadcrumbs: ['Admin', 'Dashboard'],
    };
  }

  const directMatch = NAV_ITEMS.find((item) => item.href === pathname);
  if (directMatch) {
    return {
      title: directMatch.label,
      description: directMatch.description,
      breadcrumbs: ['Admin', directMatch.label],
    };
  }

  if (pathname.startsWith('/users/')) {
    return {
      title: 'User Profile',
      description:
        'Inspect account health, privacy workflows, therapist sharing, and recent activity without touching raw production data manually.',
      breadcrumbs: ['Admin', 'Users', 'Profile'],
    };
  }

  if (pathname.startsWith('/therapists/')) {
    return {
      title: 'Therapist Review',
      description:
        'Review credentials, operational readiness, historical decisions, and public profile presentation from one secure workspace.',
      breadcrumbs: ['Admin', 'Therapists', 'Review'],
    };
  }

  if (pathname.startsWith('/appointments/')) {
    return {
      title: 'Session Detail',
      description:
        'Diagnose lifecycle, communication readiness, and operational mismatches across a single booking.',
      breadcrumbs: ['Admin', 'Bookings', 'Session detail'],
    };
  }

  if (pathname.startsWith('/ai-ops/incidents/')) {
    return {
      title: 'Incident Review',
      description:
        'Triage unsafe AI outputs, crisis signals, and trust escalations with a durable operational audit trail.',
      breadcrumbs: ['Admin', 'Incident Flags', 'Case review'],
    };
  }

  if (pathname.startsWith('/support/')) {
    return {
      title: 'Operations Workspace',
      description:
        'Manage support, privacy, and cross-functional operational workflows from a shared command surface.',
      breadcrumbs: ['Admin', 'Operations'],
    };
  }

  if (pathname.startsWith('/config/feature-flags')) {
    return {
      title: 'Settings',
      description:
        'Control launch posture, AI safety switches, notification rollouts, and privileged platform configuration.',
      breadcrumbs: ['Admin', 'Settings', 'Feature flags'],
    };
  }

  if (pathname.startsWith('/ops/notification-health')) {
    return {
      title: 'Notifications',
      description:
        'Monitor delivery health, user fatigue risk, and rollout readiness for MoodGenie notification systems.',
      breadcrumbs: ['Admin', 'Notifications'],
    };
  }

  if (pathname.startsWith('/ops/system-health')) {
    return {
      title: 'System Health',
      description:
        'Understand live operational posture across therapist review, AI reliability, sessions, and client impact.',
      breadcrumbs: ['Admin', 'System health'],
    };
  }

  return FALLBACK_PAGE_META;
}
