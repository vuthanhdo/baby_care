// GET /rest/v1/<table>: the PostgREST query subset the app uses on families, media_assets and app_feedback:
// select=a,b | *, <column>=eq.<value>, order=<column>.asc|desc[.nullsfirst|.nullslast], offset, limit.
// Column names are checked against the catalog before they reach SQL; RLS decides which rows come back.
import { asCaller, type Caller, type SQL } from '../db.ts';
import { restError, type RestError } from './errors.ts';

export const READABLE_TABLES = ['families', 'media_assets', 'app_feedback'] as const;

const fail = (status: number, code: string, message: string): RestError => ({ status, body: { code, message, details: null, hint: null } });

/** Table → column → SQL type, for the readable tables. */
export async function loadColumns(sql: SQL): Promise<Map<string, Map<string, string>>> {
  const rows = await sql<{ table_name: string; column_name: string; type: string }[]>`
    select c.relname as table_name, a.attname as column_name, format_type(a.atttypid, a.atttypmod) as type
    from pg_attribute a join pg_class c on c.oid = a.attrelid join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname in ${sql([...READABLE_TABLES])} and a.attnum > 0 and not a.attisdropped`;
  const map = new Map<string, Map<string, string>>();
  for (const row of rows) {
    if (!map.has(row.table_name)) map.set(row.table_name, new Map());
    map.get(row.table_name)!.set(row.column_name, row.type);
  }
  return map;
}

export async function readTable(sql: SQL, columns: Map<string, Map<string, string>>, table: string, query: URLSearchParams, caller: Caller):
  Promise<{ status: 200; body: unknown[] } | RestError> {
  const known = columns.get(table);
  if (!known) return fail(404, 'PGRST205', `Could not find the table 'public.${table}' in the schema cache`);
  const column = (name: string) => {
    if (!known.has(name)) throw fail(400, '42703', `column ${table}.${name} does not exist`);
    return `"${name}"`;
  };
  try {
    const selected = (query.get('select') ?? '*').split(',').map(part => part.trim()).filter(Boolean);
    const selectList = selected.length === 0 || selected.includes('*') ? '*' : selected.map(column).join(', ');
    const conditions: string[] = [];
    const values: unknown[] = [];
    let order = '';
    let limit: number | null = null;
    let offset = 0;
    for (const [key, value] of query) {
      if (key === 'select') continue;
      if (key === 'order') {
        order = value.split(',').map(term => {
          const [name, direction = 'asc', nulls] = term.split('.');
          if (direction !== 'asc' && direction !== 'desc') throw fail(400, 'PGRST100', `"failed to parse order (${term})"`);
          const nullsSQL = nulls === 'nullsfirst' ? ' nulls first' : nulls === 'nullslast' ? ' nulls last' : '';
          return `${column(name!)} ${direction}${nullsSQL}`;
        }).join(', ');
      } else if (key === 'limit') {
        limit = Math.max(0, Number.parseInt(value, 10) || 0);
      } else if (key === 'offset') {
        offset = Math.max(0, Number.parseInt(value, 10) || 0);
      } else if (value.startsWith('eq.')) {
        values.push(value.slice(3));
        // The value is cast to the column's type, as PostgREST does; uuids then match in any letter case.
        conditions.push(`${column(key)} = $${values.length}::${known.get(key)}`);
      } else {
        throw fail(400, 'PGRST100', `"failed to parse filter (${value})"`);
      }
    }
    const where = conditions.length ? ` where ${conditions.join(' and ')}` : '';
    const text = `select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb) as rows from (select ${selectList} from public."${table}"${where}`
      + `${order ? ` order by ${order}` : ''}${limit !== null ? ` limit ${limit}` : ''}${offset ? ` offset ${offset}` : ''}) t`;
    const rows = await asCaller(sql, caller, tx => tx.unsafe(text, values as never[]));
    return { status: 200, body: rows[0]?.rows ?? [] };
  } catch (error) {
    if (error && typeof error === 'object' && 'status' in error && 'body' in error) return error as RestError;
    return restError(error, caller);
  }
}
