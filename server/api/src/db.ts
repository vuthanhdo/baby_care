import postgres from 'postgres';

export type SQL = postgres.Sql;
export type Transaction = postgres.TransactionSql;

/** The claims a request runs with: `sub` is the signed-in user, absent for anon. */
export interface Caller {
  role: 'anon' | 'authenticated' | 'service_role';
  sub?: string;
  email?: string;
}

export function connect(url: string, options: postgres.Options<{}> = {}): SQL {
  // Dates stay ISO strings and bigints stay strings, as PostgREST returns them.
  return postgres(url, { max: 10, idle_timeout: 30, types: {}, transform: { undefined: null }, ...options });
}

/**
 * Runs `work` in a transaction as the caller, the way PostgREST does: `set local role` plus the JWT claims in
 * `request.jwt.claims` and `request.jwt.claim.sub`, which `auth.uid()` reads. Grants and RLS then decide.
 */
export async function asCaller<T>(sql: SQL, caller: Caller, work: (tx: Transaction) => Promise<T>): Promise<T> {
  return sql.begin(async tx => {
    const claims = JSON.stringify({ role: caller.role, sub: caller.sub, email: caller.email });
    await tx`select set_config('request.jwt.claims', ${claims}, true),
                    set_config('request.jwt.claim.sub', ${caller.sub ?? ''}, true),
                    set_config('role', ${caller.role}, true)`;
    return work(tx);
  }) as Promise<T>;
}
