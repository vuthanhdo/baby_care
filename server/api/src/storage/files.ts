// Photos and feedback screenshots on disk under <filesDirectory>/<bucket>/<name>. Every operation first touches the
// matching storage.objects row as the caller, so the policies in supabase/migrations allow or refuse it; the
// file system is only written once Postgres has agreed.
import { createHash } from 'node:crypto';
import { mkdir, readFile, rename, rm, writeFile } from 'node:fs/promises';
import { dirname, join, normalize, sep } from 'node:path';
import { asCaller, type Caller, type SQL } from '../db.ts';

export interface StorageFailure { status: number; body: { statusCode: string; error: string; message: string } }

const failure = (status: number, error: string, message: string): StorageFailure => ({ status, body: { statusCode: String(status), error, message } });

/** Object names as Supabase accepts them: relative, no empty, `.` or `..` segments, no control characters. */
export function safeObjectName(name: string): string | null {
  if (!name || name.startsWith('/') || name.length > 1024 || /[\u0000-\u001f\\]/.test(name)) return null;
  const parts = name.split('/');
  if (parts.some(part => part === '' || part === '.' || part === '..')) return null;
  return name;
}

function filePath(root: string, bucket: string, name: string): string {
  const path = normalize(join(root, bucket, name));
  if (!path.startsWith(normalize(join(root, bucket)) + sep)) throw new Error('path escapes the bucket');
  return path;
}

function storageError(error: unknown): StorageFailure {
  const { code, message } = (error ?? {}) as { code?: string; message?: string };
  if (code === '42501') return failure(403, 'Unauthorized', 'new row violates row-level security policy');
  if (code === '23505') return failure(409, 'Duplicate', 'The resource already exists');
  if (code === '23503') return notFound('Bucket not found');
  // Policy functions raise their own messages (CONSENT_REQUIRED); the app looks for them in `message`.
  if (code && (code === 'P0001' || code.startsWith('22') || code.startsWith('23'))) return failure(400, 'InvalidRequest', message ?? 'Invalid request');
  throw error;
}

/** Supabase answers a missing object with HTTP 400 and statusCode "404"; the app reads only the body. */
function notFound(message = 'Object not found'): StorageFailure {
  return { status: 400, body: { statusCode: '404', error: 'not_found', message } };
}

export interface UploadResult { id: string; key: string }

export async function uploadObject(sql: SQL, root: string, caller: Caller, bucket: string, rawName: string,
                                   bytes: Uint8Array, contentType: string, upsert: boolean): Promise<UploadResult | StorageFailure> {
  const name = safeObjectName(rawName);
  if (!name) return failure(400, 'Invalid key', `Invalid key: ${rawName}`);
  const [limits] = await sql<{ file_size_limit: string | null; allowed_mime_types: string[] | null }[]>`
    select file_size_limit, allowed_mime_types from storage.buckets where id = ${bucket}`;
  if (!limits) return notFound('Bucket not found');
  if (limits.file_size_limit && bytes.byteLength > Number(limits.file_size_limit)) {
    return failure(413, 'Payload too large', 'The object exceeded the maximum allowed size');
  }
  const mime = contentType.split(';')[0]!.trim().toLowerCase();
  if (limits.allowed_mime_types?.length && !limits.allowed_mime_types.includes(mime)) {
    return failure(415, 'invalid_mime_type', `mime type ${mime} is not supported`);
  }
  const metadata = { size: bytes.byteLength, mimetype: mime, eTag: `"${createHash('md5').update(bytes).digest('hex')}"`, contentLength: bytes.byteLength };
  const path = filePath(root, bucket, name);
  try {
    // The row is written first, as the caller, inside the same transaction as the file move: a refused policy
    // leaves no file, and a failed write leaves no row.
    const id = await asCaller(sql, caller, async tx => {
      const rows = upsert
        ? await tx<{ id: string }[]>`insert into storage.objects (bucket_id, name, owner, metadata) values (${bucket}, ${name}, ${caller.sub ?? null}, ${metadata as never})
            on conflict (bucket_id, name) do update set metadata = excluded.metadata, owner = excluded.owner, updated_at = now() returning id`
        : await tx<{ id: string }[]>`insert into storage.objects (bucket_id, name, owner, metadata) values (${bucket}, ${name}, ${caller.sub ?? null}, ${metadata as never}) returning id`;
      await mkdir(dirname(path), { recursive: true });
      const temporary = `${path}.${process.pid}.${Date.now()}.part`;
      await writeFile(temporary, bytes);
      await rename(temporary, path);
      return rows[0]!.id;
    });
    return { id, key: `${bucket}/${name}` };
  } catch (error) {
    return storageError(error);
  }
}

export async function downloadObject(sql: SQL, root: string, caller: Caller, bucket: string, rawName: string):
  Promise<{ bytes: Uint8Array; contentType: string } | StorageFailure> {
  const name = safeObjectName(rawName);
  if (!name) return failure(400, 'Invalid key', `Invalid key: ${rawName}`);
  // RLS hides rows the caller may not read, so "not allowed" and "missing" look the same, as on Supabase.
  const [row] = await asCaller(sql, caller, tx => tx<{ metadata: { mimetype?: string } | null }[]>`
    select metadata from storage.objects where bucket_id = ${bucket} and name = ${name}`);
  if (!row) return notFound();
  try {
    const bytes = await readFile(filePath(root, bucket, name));
    return { bytes, contentType: row.metadata?.mimetype ?? 'application/octet-stream' };
  } catch {
    return notFound();
  }
}

interface ObjectRow { id: string; name: string; bucket_id: string; owner: string | null; metadata: unknown; created_at: Date; updated_at: Date }

/**
 * Deletes the objects the caller may delete and answers Storage's FileObject list (dates in UTC, as supabase-swift
 * requires); objects the policies protect are silently skipped, as on Supabase.
 */
export async function removeObjects(sql: SQL, root: string, caller: Caller, bucket: string, names: string[]) {
  const valid = names.map(safeObjectName).filter((name): name is string => name !== null);
  if (!valid.length) return [];
  try {
    const removed = await asCaller(sql, caller, tx => tx<ObjectRow[]>`
      delete from storage.objects where bucket_id = ${bucket} and name = any(${valid})
      returning id, name, bucket_id, owner, metadata, created_at, updated_at`);
    for (const row of removed) await rm(filePath(root, bucket, row.name), { force: true });
    return removed.map(row => ({
      id: row.id, name: row.name, bucket_id: row.bucket_id, owner: row.owner, metadata: row.metadata,
      created_at: new Date(row.created_at).toISOString(), updated_at: new Date(row.updated_at).toISOString(),
      last_accessed_at: new Date(row.updated_at).toISOString(),
    }));
  } catch (error) {
    return storageError(error);
  }
}
