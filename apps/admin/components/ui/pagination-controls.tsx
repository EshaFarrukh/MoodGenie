import Link from 'next/link';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import { buttonStyles } from '@/components/ui/button';

type PaginationControlsProps = {
  page: number;
  hasNextPage: boolean;
  searchParams?: Record<string, string | undefined>;
};

function buildHref(
  page: number,
  searchParams?: Record<string, string | undefined>,
) {
  const params = new URLSearchParams();
  Object.entries(searchParams || {}).forEach(([key, value]) => {
    if (value && key !== 'page') {
      params.set(key, value);
    }
  });
  if (page > 1) {
    params.set('page', String(page));
  }
  const query = params.toString();
  return query ? `?${query}` : '?';
}

export function PaginationControls({
  page,
  hasNextPage,
  searchParams,
}: PaginationControlsProps) {
  return (
    <div className="pagination-bar">
      <div className="space-y-1">
        <div className="text-sm font-semibold text-[var(--mg-heading)]">Page {page}</div>
        <div className="text-sm text-[var(--mg-muted)]">
          Use the controls to move through the operational queue without losing filters.
        </div>
      </div>
      <div className="pagination-bar__actions">
        {page > 1 ? (
          <Link
            href={buildHref(page - 1, searchParams)}
            className={buttonStyles({ variant: 'outline', size: 'sm' })}
          >
            <ChevronLeft className="h-4 w-4" />
            Previous
          </Link>
        ) : (
          <span
            className={buttonStyles({
              variant: 'outline',
              size: 'sm',
              className: 'pointer-events-none opacity-50',
            })}
          >
            <ChevronLeft className="h-4 w-4" />
            Previous
          </span>
        )}
        {hasNextPage ? (
          <Link
            href={buildHref(page + 1, searchParams)}
            className={buttonStyles({ variant: 'outline', size: 'sm' })}
          >
            Next
            <ChevronRight className="h-4 w-4" />
          </Link>
        ) : (
          <span
            className={buttonStyles({
              variant: 'outline',
              size: 'sm',
              className: 'pointer-events-none opacity-50',
            })}
          >
            Next
            <ChevronRight className="h-4 w-4" />
          </span>
        )}
      </div>
    </div>
  );
}
