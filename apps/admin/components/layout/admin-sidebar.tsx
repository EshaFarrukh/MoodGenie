'use client';

import Image from 'next/image';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  BellDot,
  CalendarRange,
  ChevronLeft,
  ChevronRight,
  HeartPulse,
  LayoutDashboard,
  LogOut,
  Settings2,
  ShieldAlert,
  Stethoscope,
  Users,
  FileBarChart2,
} from 'lucide-react';
import { NAV_ITEMS, type NavIcon } from '@/lib/navigation';
import { cn } from '@/lib/utils';
import type { AdminRole } from '@/lib/types';

type AdminSidebarProps = {
  roles: AdminRole[];
  collapsed: boolean;
  mobileOpen: boolean;
  onToggleCollapse: () => void;
  onCloseMobile: () => void;
};

const iconMap: Record<NavIcon, typeof LayoutDashboard> = {
  dashboard: LayoutDashboard,
  users: Users,
  therapists: Stethoscope,
  bookings: CalendarRange,
  reports: FileBarChart2,
  mood: HeartPulse,
  notifications: BellDot,
  flags: ShieldAlert,
  settings: Settings2,
};

export function AdminSidebar({
  roles,
  collapsed,
  mobileOpen,
  onToggleCollapse,
  onCloseMobile,
}: AdminSidebarProps) {
  const pathname = usePathname();

  const visibleItems = NAV_ITEMS.filter((item) => {
    if (!item.allowedRoles || item.allowedRoles.length === 0) {
      return true;
    }
    return roles.some((role) => item.allowedRoles?.includes(role));
  });

  return (
    <>
      <div
        className={cn(
          'fixed inset-0 z-30 bg-black/40 backdrop-blur-sm transition-opacity md:hidden',
          mobileOpen ? 'pointer-events-auto opacity-100' : 'pointer-events-none opacity-0',
        )}
        onClick={onCloseMobile}
      />
      <aside
        className={cn(
          'fixed inset-y-0 left-0 z-40 flex w-[260px] flex-col overflow-hidden border-r border-white/10 bg-[linear-gradient(180deg,#0a478f_0%,#0e5bb0_48%,#1180ce_100%)] px-3 py-4 text-white transition-all duration-300 md:sticky md:top-0 md:h-screen md:translate-x-0',
          collapsed ? 'md:w-[72px]' : 'md:w-[260px]',
          mobileOpen ? 'translate-x-0' : '-translate-x-full',
        )}
      >
        <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top_left,rgba(255,255,255,0.18),transparent_28%),radial-gradient(circle_at_bottom_left,rgba(0,180,216,0.18),transparent_35%),linear-gradient(180deg,rgba(255,255,255,0.06),rgba(255,255,255,0))]" />
        <div className="relative z-10 flex h-12 items-center justify-between gap-3 px-2">
          <div className={cn('min-w-0 flex items-center gap-3', collapsed && 'md:hidden')}>
            <div className="flex h-12 w-12 items-center justify-center overflow-hidden rounded-2xl border border-white/65 bg-white shadow-[0_16px_34px_rgba(0,31,77,0.28)]">
              <Image
                src="/moodgenie-logo-blue.png"
                alt="MoodGenie"
                width={40}
                height={40}
                className="h-9 w-9 object-contain"
                priority
              />
            </div>
            <div className="min-w-0">
              <div className="truncate text-[1.35rem] font-semibold tracking-[-0.04em] text-white">
                MoodGenie
              </div>
              <div className="truncate text-[11px] font-medium uppercase tracking-[0.18em] text-white/62">
                Admin console
              </div>
            </div>
          </div>
          {collapsed ? (
            <div className="hidden w-full justify-center md:flex">
              <div className="flex h-12 w-12 items-center justify-center overflow-hidden rounded-2xl border border-white/65 bg-white shadow-[0_16px_34px_rgba(0,31,77,0.28)]">
                <Image
                  src="/moodgenie-logo-blue.png"
                  alt="MoodGenie"
                  width={40}
                  height={40}
                  className="h-9 w-9 object-contain"
                  priority
                />
              </div>
            </div>
          ) : null}
          <button
            type="button"
            onClick={onToggleCollapse}
            className="hidden rounded-xl border border-white/12 bg-white/8 p-1.5 text-white/74 backdrop-blur-sm hover:bg-white/14 hover:text-white md:inline-flex"
            aria-label={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
          >
            {collapsed ? (
              <ChevronRight className="h-4 w-4" />
            ) : (
              <ChevronLeft className="h-4 w-4" />
            )}
          </button>
        </div>

        <nav className="relative z-10 mt-8 flex-1 space-y-1 overflow-y-auto px-1" aria-label="Admin navigation">
          {visibleItems.map((item) => {
            const Icon = iconMap[item.icon];
            const isActive =
              item.href === '/'
                ? pathname === '/'
                : pathname === item.href || pathname.startsWith(`${item.href}/`);

            return (
              <Link
                key={item.href}
                href={item.href}
                onClick={onCloseMobile}
                className={cn(
                  'group flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition-colors',
                  isActive
                    ? 'bg-white/16 text-white shadow-[inset_0_1px_0_rgba(255,255,255,0.08)]'
                    : 'text-white/76 hover:bg-white/10 hover:text-white',
                  collapsed && 'justify-center md:px-0',
                )}
              >
                <Icon className={cn('h-4 w-4 flex-shrink-0', isActive ? 'text-white' : 'text-white/72 group-hover:text-white')} />
                <span className={cn('truncate', collapsed && 'md:hidden')}>
                  {item.label}
                </span>
              </Link>
            );
          })}
        </nav>

        <div className="relative z-10 mt-auto px-1 pt-4 pb-2">
          <form action="/api/session/logout" method="post">
            <button
              type="submit"
              className={cn(
                'flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium text-white/76 transition-colors hover:bg-white/10 hover:text-white',
                collapsed && 'justify-center md:px-0',
              )}
            >
              <LogOut className="h-4 w-4 text-white/72" />
              <span className={cn('truncate', collapsed && 'md:hidden')}>Logout</span>
            </button>
          </form>
        </div>
      </aside>
    </>
  );
}
