'use client';

import { useState } from 'react';
import type { ReactNode } from 'react';
import type { AdminSession } from '@/lib/types';
import { AdminHeader, type AdminChromeSummary } from '@/components/layout/admin-header';
import { AdminSidebar } from '@/components/layout/admin-sidebar';

type AdminShellProps = {
  admin: AdminSession;
  chrome: AdminChromeSummary;
  children: ReactNode;
};

export function AdminShell({ admin, chrome, children }: AdminShellProps) {
  const [collapsed, setCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);

  return (
    <div className="min-h-screen bg-[var(--mg-background)] text-[var(--mg-text)]">
      <div className="flex min-h-screen">
        <AdminSidebar
          roles={admin.roles}
          collapsed={collapsed}
          mobileOpen={mobileOpen}
          onToggleCollapse={() => setCollapsed((current) => !current)}
          onCloseMobile={() => setMobileOpen(false)}
        />
        <div className="min-w-0 flex-1">
          <AdminHeader
            admin={admin}
            chrome={chrome}
            onOpenMobileNav={() => setMobileOpen(true)}
          />
          <main className="mx-auto max-w-[1480px] px-4 py-4 md:px-6 lg:px-7 lg:py-5">
            {children}
          </main>
        </div>
      </div>
    </div>
  );
}
