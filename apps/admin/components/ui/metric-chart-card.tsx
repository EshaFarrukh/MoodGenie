import type { PropsWithChildren, ReactNode } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { cn } from '@/lib/utils';

export function MetricChartCard({
  title,
  description,
  action,
  children,
  footer,
  className,
  contentClassName,
}: PropsWithChildren<{
  title: string;
  description: string;
  action?: ReactNode;
  footer?: ReactNode;
  className?: string;
  contentClassName?: string;
}>) {
  return (
    <Card className={cn('overflow-hidden', className)}>
      <CardHeader className="border-b border-[var(--mg-border)] pb-3.5">
        <div className="min-w-0">
          <CardTitle>{title}</CardTitle>
          <CardDescription>{description}</CardDescription>
        </div>
        {action}
      </CardHeader>
      <CardContent className={cn('pt-4.5', contentClassName)}>{children}</CardContent>
      {footer ? <div className="border-t border-[var(--mg-border)] px-5 py-3.5">{footer}</div> : null}
    </Card>
  );
}
