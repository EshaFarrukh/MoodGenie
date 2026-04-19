import { TherapistsManagementWorkspace } from '@/components/therapists/therapists-management-workspace';
import { PaginationControls } from '@/components/ui/pagination-controls';
import { requireAdminSession } from '@/lib/auth';
import { getTherapistReviewQueue } from '@/lib/dal';

type TherapistReviewQueuePageProps = {
  searchParams?: Promise<{ page?: string }>;
};

export default async function TherapistReviewQueuePage({
  searchParams,
}: TherapistReviewQueuePageProps) {
  await requireAdminSession(['super_admin', 'clinical_ops', 'support_ops']);
  const params = searchParams ? await searchParams : {};
  const page = Math.max(1, Number(params.page || '1') || 1);
  const result = await getTherapistReviewQueue(page);

  return (
    <div className="space-y-6">
      <TherapistsManagementWorkspace therapists={result.items} />
      <PaginationControls
        page={result.page}
        hasNextPage={result.hasNextPage}
        searchParams={{ page: params.page }}
      />
    </div>
  );
}
