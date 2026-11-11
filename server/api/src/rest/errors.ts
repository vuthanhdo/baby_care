// PostgREST-style errors: {code, message, details, hint} with the HTTP status PostgREST picks for each SQLSTATE,
// so the app's existing error mapping (CloudError.normalize) keeps working.
import type { Caller } from '../db.ts';

export interface RestError { status: number; body: { code: string; message: string; details: string | null; hint: string | null } }

interface PostgresError { code?: string; message?: string; detail?: string; hint?: string }

export function restError(error: unknown, caller: Caller): RestError {
  const pg = error as PostgresError;
  const code = typeof pg?.code === 'string' ? pg.code : 'XX000';
  const body = { code, message: pg?.message ?? 'Internal error', details: pg?.detail ?? null, hint: pg?.hint ?? null };
  return { status: statusFor(code, caller), body };
}

export function statusFor(code: string, caller: Caller): number {
  if (code === '42501') return caller.role === 'anon' ? 401 : 403;
  if (code === '23505' || code === '23503' || code === '40001') return 409;
  if (code === '42883' || code === '42P01' || code.startsWith('PGRST2')) return 404;
  if (code === 'P0001' || code.startsWith('22') || code.startsWith('23')) return 400;
  if (code === '57014') return 504;
  if (code.startsWith('08') || code === '53300') return 503;
  return 500;
}

export function notFound(message: string): RestError {
  return { status: 404, body: { code: 'PGRST202', message, details: null, hint: null } };
}
