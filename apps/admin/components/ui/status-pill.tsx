import { StatusBadge } from '@/components/ui/status-badge';

type StatusPillProps = {
  status: string;
};

export function StatusPill({ status }: StatusPillProps) {
  return <StatusBadge status={status} />;
}
