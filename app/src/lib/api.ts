import { supabase } from './supabase';
import type { DayRow, MonthRow, PlanStatus, dayModelToRow } from './mappers';

/**
 * Base URL of the Node API. In dev this defaults to '/api', which the Vite dev
 * server proxies to the Node service (see vite.config.ts). In production set
 * VITE_API_URL to the deployed API origin, e.g. https://api.example.com/api.
 */
const API_URL = (import.meta.env.VITE_API_URL as string | undefined)?.replace(/\/$/, '') || '/api';

/** True when an API base is configured (always true given the '/api' default). */
export const isApiConfigured = Boolean(API_URL);

async function authHeader(): Promise<Record<string, string>> {
  if (!supabase) return {};
  const { data } = await supabase.auth.getSession();
  const token = data.session?.access_token;
  return token ? { Authorization: `Bearer ${token}` } : {};
}

async function apiFetch<T>(path: string, opts: RequestInit = {}): Promise<T> {
  const headers: Record<string, string> = {
    ...(opts.body ? { 'Content-Type': 'application/json' } : {}),
    ...(await authHeader()),
    ...((opts.headers as Record<string, string>) ?? {}),
  };
  const res = await fetch(`${API_URL}${path}`, { ...opts, headers });
  if (!res.ok) {
    let message = `Request failed (${res.status}).`;
    try {
      const body = await res.json();
      if (body?.error) message = body.error as string;
    } catch {
      /* non-JSON error body */
    }
    throw new Error(message);
  }
  if (res.status === 204) return undefined as T;
  return (await res.json()) as T;
}

// -------------------------------------------------------------------------
// Plans (public / admin-aware, resolved server-side from the JWT)
// -------------------------------------------------------------------------
export function getPlans() {
  return apiFetch<{ months: MonthRow[]; days: DayRow[] }>('/plans');
}

// -------------------------------------------------------------------------
// Current user
// -------------------------------------------------------------------------
export type MeProfile = { id: string; email: string | null; is_admin: boolean };

export function getMe() {
  return apiFetch<MeProfile>('/me');
}

export function getMyState() {
  return apiFetch<{
    progress: Array<{ day_number: number; completed: boolean }>;
    notes: Array<{ day_number: number; content: string }>;
  }>('/me/state');
}

export function putProgress(day: number, completed: boolean) {
  return apiFetch<{ ok: true }>(`/me/progress/${day}`, {
    method: 'PUT',
    body: JSON.stringify({ completed }),
  });
}

export function putNote(day: number, content: string) {
  return apiFetch<{ ok: true }>(`/me/notes/${day}`, {
    method: 'PUT',
    body: JSON.stringify({ content }),
  });
}

// -------------------------------------------------------------------------
// Admin CRUD
// -------------------------------------------------------------------------
export type MonthInputBody = {
  month_number: number;
  title: string;
  goal: string;
  project: unknown;
  status: PlanStatus;
};

export function adminSaveMonth(body: MonthInputBody) {
  return apiFetch<{ ok: true }>('/admin/months', {
    method: 'POST',
    body: JSON.stringify(body),
  });
}

/** dayRow is the mappers.ts dayModelToRow() output; caller adds month/status. */
export function adminSaveDay(
  monthNumber: number,
  dayRow: ReturnType<typeof dayModelToRow>,
  status: PlanStatus,
) {
  return apiFetch<{ ok: true }>('/admin/days', {
    method: 'POST',
    body: JSON.stringify({ ...dayRow, month_number: monthNumber, status }),
  });
}

export function adminSetMonthStatus(monthNumber: number, status: PlanStatus) {
  return apiFetch<{ ok: true }>(`/admin/months/${monthNumber}/status`, {
    method: 'PATCH',
    body: JSON.stringify({ status }),
  });
}

export function adminSetDayStatus(dayNumber: number, status: PlanStatus) {
  return apiFetch<{ ok: true }>(`/admin/days/${dayNumber}/status`, {
    method: 'PATCH',
    body: JSON.stringify({ status }),
  });
}

export function adminDeleteDay(dayNumber: number) {
  return apiFetch<{ ok: true }>(`/admin/days/${dayNumber}`, { method: 'DELETE' });
}

export function adminDeleteMonth(monthNumber: number) {
  return apiFetch<{ ok: true }>(`/admin/months/${monthNumber}`, { method: 'DELETE' });
}
