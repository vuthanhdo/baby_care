// POST /rest/v1/rpc/<function>: calls a public babycare_* SQL function as the caller, with named arguments taken
// from the JSON body, the way PostgREST does. Signatures are read from the catalog once, so a new migration that
// adds or changes a function needs no code change here, only an API restart.
import { asCaller, type Caller, type SQL } from '../db.ts';
import { notFound, restError, type RestError } from './errors.ts';

interface Argument { name: string; type: string; hasDefault: boolean }
interface Signature { name: string; args: Argument[] }

export async function loadSignatures(sql: SQL): Promise<Map<string, Signature>> {
  const rows = await sql<{ name: string; names: string[] | null; types: string[]; defaults: number }[]>`
    select p.proname as name, p.proargnames as names,
           array(select format_type(t, null) from unnest(p.proargtypes) as t) as types,
           p.pronargdefaults as defaults
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'babycare\\_%' and not p.proretset`;
  const map = new Map<string, Signature>();
  for (const row of rows) {
    const count = row.types.length;
    const args = row.types.map((type, index) => ({
      name: row.names?.[index] ?? `$${index + 1}`,
      type,
      hasDefault: index >= count - row.defaults,
    }));
    map.set(row.name, { name: row.name, args });
  }
  return map;
}

export type RpcResult = { status: 200; body: unknown } | RestError;

export async function callRpc(sql: SQL, signatures: Map<string, Signature>, name: string, params: unknown, caller: Caller): Promise<RpcResult> {
  const signature = signatures.get(name);
  if (!signature) return notFound(`Could not find the function public.${name} in the schema cache`);
  const body = (params && typeof params === 'object' && !Array.isArray(params) ? params : {}) as Record<string, unknown>;
  const unknownKey = Object.keys(body).find(key => !signature.args.some(arg => arg.name === key));
  if (unknownKey) return notFound(`Could not find the function public.${name}(${Object.keys(body).sort().join(', ')}) in the schema cache`);
  const missing = signature.args.find(arg => !arg.hasDefault && !(arg.name in body));
  if (missing) return notFound(`Could not find the function public.${name}(${Object.keys(body).sort().join(', ')}) in the schema cache`);

  const values: unknown[] = [];
  const named = signature.args.filter(arg => arg.name in body).map(arg => {
    const value = body[arg.name];
    values.push(encode(value, arg.type));
    // Identifiers come from the catalog, never from the request.
    return `"${arg.name}" := $${values.length}::${arg.type}`;
  });
  try {
    const rows = await asCaller(sql, caller, tx => tx.unsafe(`select to_jsonb(public."${signature.name}"(${named.join(', ')})) as result`, values as never[]));
    return { status: 200, body: rows[0]?.result ?? null };
  } catch (error) {
    return restError(error, caller);
  }
}

/**
 * JSON values as postgres.js parameters. postgres.js learns each parameter's type from the server and serializes
 * json/jsonb and arrays itself, so those go in as JS values (stringifying them first would encode them twice);
 * everything else goes in as text for Postgres to cast, as PostgREST does.
 */
function encode(value: unknown, type: string): unknown {
  if (value === null || value === undefined) return null;
  if (type === 'jsonb' || type === 'json') return value;
  if (type.endsWith('[]')) return Array.isArray(value) ? value.map(item => item === null ? null : String(item)) : value;
  if (typeof value === 'object') return JSON.stringify(value);
  return String(value);
}
