import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatNumber(value: number) {
  return new Intl.NumberFormat('en-US').format(value);
}

export function formatPercent(value: number) {
  return `${Math.round(value * 100)}%`;
}

export function formatRelativeLabel(timestamp: string | null) {
  if (!timestamp) {
    return 'Unavailable';
  }

  const parsed = new Date(timestamp);
  if (Number.isNaN(parsed.valueOf())) {
    return timestamp;
  }

  const now = Date.now();
  const deltaMinutes = Math.round((parsed.valueOf() - now) / 60000);
  const absMinutes = Math.abs(deltaMinutes);

  if (absMinutes < 60) {
    return deltaMinutes >= 0
      ? `in ${absMinutes} min`
      : `${absMinutes} min ago`;
  }

  const absHours = Math.round(absMinutes / 60);
  if (absHours < 24) {
    return deltaMinutes >= 0 ? `in ${absHours} hr` : `${absHours} hr ago`;
  }

  const absDays = Math.round(absHours / 24);
  return deltaMinutes >= 0 ? `in ${absDays} d` : `${absDays} d ago`;
}

export function formatDateLabel(timestamp: string | null) {
  if (!timestamp) {
    return 'Unavailable';
  }

  const parsed = new Date(timestamp);
  if (Number.isNaN(parsed.valueOf())) {
    return timestamp;
  }

  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  }).format(parsed);
}

export function formatDateTimeLabel(timestamp: string | null) {
  if (!timestamp) {
    return 'Unavailable';
  }

  const parsed = new Date(timestamp);
  if (Number.isNaN(parsed.valueOf())) {
    return timestamp;
  }

  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  }).format(parsed);
}

export function truncateChartLabel(value: string | number | null, max = 12) {
  if (value == null) {
    return '';
  }

  const text = String(value);
  if (text.length <= max) {
    return text;
  }

  return `${text.slice(0, Math.max(1, max - 1))}…`;
}
