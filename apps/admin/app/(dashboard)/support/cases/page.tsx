import { PaginationControls } from '@/components/ui/pagination-controls';
import { SupportCaseWorkspace } from '@/components/support/support-case-workspace';
import { requireAdminSession } from '@/lib/auth';
import { getSupportCases } from '@/lib/dal';

type SupportCasesPageProps = {
  searchParams?: Promise<{ page?: string }>;
};

export default async function SupportCasesPage({
  searchParams,
}: SupportCasesPageProps) {
  await requireAdminSession(['super_admin', 'support_ops', 'clinical_ops']);
  const params = searchParams ? await searchParams : {};
  const page = Math.max(1, Number(params.page || '1') || 1);
  const result = await getSupportCases(page);
  const cases = result.items;

  return (
    <section className="space-y-6">
      <SupportCaseWorkspace cases={cases} />
      <PaginationControls
        page={result.page}
        hasNextPage={result.hasNextPage}
        searchParams={{ page: params.page }}
      />
    </section>
  );
}
