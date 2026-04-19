import Link from 'next/link';
import { BookingsWorkspace } from '@/components/appointments/bookings-workspace';
import { PaginationControls } from '@/components/ui/pagination-controls';
import { buttonStyles } from '@/components/ui/button';
import { requireAdminSession } from '@/lib/auth';
import { getAppointments } from '@/lib/dal';

type AppointmentsPageProps = {
  searchParams?: Promise<{ status?: string; page?: string }>;
};

const statusTabs = [
  { label: 'All sessions', value: '' },
  { label: 'Requested', value: 'requested' },
  { label: 'Confirmed', value: 'confirmed' },
  { label: 'Completed', value: 'completed' },
  { label: 'Cancelled', value: 'cancelled' },
  { label: 'Rejected', value: 'rejected' },
  { label: 'No show', value: 'no_show' },
];

export default async function AppointmentsPage({
  searchParams,
}: AppointmentsPageProps) {
  await requireAdminSession(['super_admin', 'support_ops', 'clinical_ops']);
  const params = searchParams ? await searchParams : {};
  const page = Math.max(1, Number(params.page || '1') || 1);
  const result = await getAppointments(params.status || '', page);

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap gap-3">
        {statusTabs.map((tab) => {
          const isActive = (params.status || '') === tab.value;
          const href = tab.value ? `/appointments?status=${tab.value}` : '/appointments';

          return (
            <Link
              key={tab.label}
              href={href}
              className={buttonStyles({
                variant: isActive ? 'primary' : 'outline',
                size: 'sm',
              })}
            >
              {tab.label}
            </Link>
          );
        })}
      </div>
      <BookingsWorkspace appointments={result.items} />
      <PaginationControls
        page={result.page}
        hasNextPage={result.hasNextPage}
        searchParams={{ status: params.status, page: params.page }}
      />
    </div>
  );
}
