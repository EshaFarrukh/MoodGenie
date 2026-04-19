import { UsersManagementTable } from '@/components/users/users-management-table';
import { PaginationControls } from '@/components/ui/pagination-controls';
import { requireAdminSession } from '@/lib/auth';
import { getUsers } from '@/lib/dal';

type UsersPageProps = {
  searchParams?: Promise<{ q?: string; page?: string }>;
};

export default async function UsersPage({ searchParams }: UsersPageProps) {
  await requireAdminSession(['super_admin', 'support_ops', 'clinical_ops']);
  const params = searchParams ? await searchParams : {};
  const page = Math.max(1, Number(params.page || '1') || 1);
  const result = await getUsers(params.q || '', page);

  return (
    <div className="space-y-6">
      <UsersManagementTable users={result.items} />
      <PaginationControls
        page={result.page}
        hasNextPage={result.hasNextPage}
        searchParams={{ q: params.q }}
      />
    </div>
  );
}
