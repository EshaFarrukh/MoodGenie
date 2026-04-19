'use client';

import { useMemo, useState } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import {
  Bell,
  ChevronDown,
  Menu,
  Search,
  ShieldCheck,
  TriangleAlert,
} from 'lucide-react';
import { getPageMeta } from '@/lib/navigation';
import { cn } from '@/lib/utils';
import type { AdminSession } from '@/lib/types';

export type AdminChromeAlert = {
  id: string;
  title: string;
  description: string;
  href: string;
  tone?: 'info' | 'warning' | 'danger';
};

export type AdminChromeSummary = {
  platformStatus: 'stable' | 'watch' | 'risk';
  pendingApprovals: number;
  unreadNotifications: number;
  openIncidents: number;
  alerts: AdminChromeAlert[];
};

type AdminHeaderProps = {
  admin: AdminSession;
  chrome: AdminChromeSummary;
  onOpenMobileNav: () => void;
};

export function AdminHeader({
  admin,
  chrome,
  onOpenMobileNav,
}: AdminHeaderProps) {
  const pathname = usePathname();
  const router = useRouter();
  const [query, setQuery] = useState('');
  const [notificationsOpen, setNotificationsOpen] = useState(false);
  const [profileOpen, setProfileOpen] = useState(false);

  const pageMeta = useMemo(() => getPageMeta(pathname), [pathname]);

  function handleSearchSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const normalized = query.trim();
    if (!normalized) {
      router.push('/users');
      return;
    }
    router.push(`/users?q=${encodeURIComponent(normalized)}`);
  }

  return (
    <header className="sticky top-0 z-20 border-b border-[var(--mg-border)] bg-white/78 px-4 py-3 backdrop-blur-md">
      <div className="mx-auto flex w-full max-w-7xl items-center justify-between gap-4">
        <div className="flex min-w-0 items-center gap-3">
          <button
            type="button"
            onClick={onOpenMobileNav}
            className="inline-flex rounded-xl p-1.5 text-[var(--mg-muted)] hover:bg-[var(--mg-primary-soft)] md:hidden"
            aria-label="Open navigation"
          >
            <Menu className="h-5 w-5" />
          </button>

          <div className="min-w-0">
            <h1 className="truncate text-lg font-semibold tracking-tight text-[var(--mg-heading)]">
              {pageMeta.title}
            </h1>
          </div>

          <div className="hidden ml-2 items-center lg:flex">
            <div
              className={cn(
                'inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-xs font-medium',
                chrome.platformStatus === 'risk'
                  ? 'bg-red-50 text-red-700'
                  : chrome.platformStatus === 'watch'
                  ? 'bg-amber-50 text-amber-700'
                  : 'bg-[var(--mg-primary-soft)] text-[var(--mg-primary-strong)]',
              )}
            >
              <ShieldCheck className="h-3 w-3" />
              {chrome.platformStatus === 'risk' ? 'At Risk' : chrome.platformStatus === 'watch' ? 'Needs Attention' : 'Healthy'}
            </div>
          </div>
        </div>

        <div className="flex items-center gap-4">
          <form onSubmit={handleSearchSubmit} className="hidden relative w-64 md:block">
            <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[var(--mg-muted)]" />
            <input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Search..."
              className="h-9 w-full rounded-xl border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] pl-9 pr-3 text-sm text-[var(--mg-heading)] outline-none transition focus:border-[var(--mg-primary)] focus:bg-white focus:ring-1 focus:ring-[var(--mg-primary)]"
            />
          </form>

          <div className="flex items-center gap-2 relative">
            <button
              type="button"
              className="relative rounded-xl p-2 text-[var(--mg-muted)] transition-colors hover:bg-[var(--mg-primary-soft)]"
              onClick={() => {
                setNotificationsOpen((current) => !current);
                setProfileOpen(false);
              }}
            >
              <Bell className="h-5 w-5" />
              {chrome.unreadNotifications > 0 ? (
                <span className="absolute right-1.5 top-1.5 inline-flex h-2 w-2 rounded-full bg-[var(--mg-accent)]" />
              ) : null}
            </button>

            {notificationsOpen ? (
              <div className="absolute right-0 top-12 z-40 w-80 rounded-[22px] border border-[var(--mg-border)] bg-white p-3 shadow-[var(--mg-shadow-md)]">
                <div className="mb-3 flex items-center justify-between px-1">
                  <span className="text-sm font-semibold text-[var(--mg-heading)]">Alerts</span>
                  <span className="rounded-full bg-[var(--mg-primary-soft)] px-2 py-0.5 text-xs font-medium text-[var(--mg-primary-strong)]">
                    {chrome.unreadNotifications}
                  </span>
                </div>
                <div className="max-h-80 space-y-1 overflow-y-auto">
                  {chrome.alerts.map((alert) => (
                    <a
                      key={alert.id}
                      href={alert.href}
                      className="block rounded-2xl p-2.5 transition-colors hover:bg-[var(--mg-surface-subtle)]"
                    >
                      <div className="flex items-start gap-3">
                        <TriangleAlert className={cn(
                          "h-4 w-4 mt-0.5",
                          alert.tone === 'danger' ? 'text-red-500' :
                          alert.tone === 'warning' ? 'text-amber-500' : 'text-[var(--mg-primary)]'
                        )} />
                        <div>
                          <div className="text-sm font-medium text-[var(--mg-heading)]">
                            {alert.title}
                          </div>
                          <p className="mt-0.5 text-xs text-[var(--mg-muted)]">
                            {alert.description}
                          </p>
                        </div>
                      </div>
                    </a>
                  ))}
                  {chrome.alerts.length === 0 && (
                    <div className="py-4 text-center text-sm text-[var(--mg-muted)]">
                      No active alerts
                    </div>
                  )}
                </div>
              </div>
            ) : null}

            <div className="mx-1 hidden h-5 w-[1px] bg-[var(--mg-border)] sm:block" />

            <button
              type="button"
              className="flex items-center gap-2 rounded-xl p-1.5 transition-colors hover:bg-[var(--mg-primary-soft)]"
              onClick={() => {
                setProfileOpen((current) => !current);
                setNotificationsOpen(false);
              }}
            >
              <div className="flex h-7 w-7 items-center justify-center rounded-full bg-[linear-gradient(135deg,var(--mg-primary-strong),var(--mg-primary))] text-xs font-medium text-white">
                {admin.displayName.charAt(0).toUpperCase()}
              </div>
              <ChevronDown className="hidden h-4 w-4 text-[var(--mg-muted)] sm:block" />
            </button>

            {profileOpen ? (
              <div className="absolute right-0 top-12 z-40 w-56 rounded-[22px] border border-[var(--mg-border)] bg-white p-1 shadow-[var(--mg-shadow-md)]">
                <div className="border-b border-[var(--mg-border)] px-3 py-2 text-sm">
                  <div className="truncate font-medium text-[var(--mg-heading)]">{admin.displayName}</div>
                  <div className="truncate text-xs text-[var(--mg-muted)]">{admin.email || admin.uid}</div>
                </div>
                <div className="px-3 py-2 text-xs text-[var(--mg-text)]">
                  <div className="mb-1">Roles: {admin.roles.join(', ')}</div>
                  <div>MFA: {admin.mfaVerified ? 'Enabled' : 'Disabled'}</div>
                </div>
              </div>
            ) : null}
          </div>
        </div>
      </div>
    </header>
  );
}
