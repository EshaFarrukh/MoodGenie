import { IncidentsWorkspace } from '@/components/incidents/incidents-workspace';
import { PaginationControls } from '@/components/ui/pagination-controls';
import { requireAdminSession } from '@/lib/auth';
import { getAIIncidents } from '@/lib/dal';

type AIIncidentsPageProps = {
  searchParams?: Promise<{ page?: string }>;
};

export default async function AIIncidentsPage({
  searchParams,
}: AIIncidentsPageProps) {
  await requireAdminSession(['super_admin', 'trust_safety', 'support_ops']);
  const params = searchParams ? await searchParams : {};
  const page = Math.max(1, Number(params.page || '1') || 1);
  const result = await getAIIncidents(page);

  return (
    <div className="space-y-6">
      <IncidentsWorkspace incidents={result.items} />
      <PaginationControls
        page={result.page}
        hasNextPage={result.hasNextPage}
        searchParams={{ page: params.page }}
      />
    </div>
  );
}
