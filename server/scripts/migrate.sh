#!/usr/bin/env bash
# Applies db/*.sql (platform compatibility) and then migrations/*.sql (copied from supabase/migrations), each once,
# in file name order, recording them in babycare_platform.schema_migrations.
# Usage on the VPS, from /srv/babycare: scripts/migrate.sh [database]   (default: babycare)
set -euo pipefail
cd "$(dirname "$0")/.."
db=${1:-babycare}
psql() { docker compose exec -T db psql -X -v ON_ERROR_STOP=1 -U postgres -d "$db" -q "$@"; }

psql -c "create schema if not exists babycare_platform" \
     -c "create table if not exists babycare_platform.schema_migrations(version text primary key, applied_at timestamptz not null default now())"
for file in db/*.sql migrations/*.sql; do
  version=$(basename "$file")
  [ "$(psql -tA -c "select 1 from babycare_platform.schema_migrations where version = '$version'")" = "1" ] && continue
  # Some app migrations open and commit their own transaction; wrap only the others.
  if grep -qiE '^[[:space:]]*begin[[:space:]]*;' "$file"; then
    psql -f - < "$file"
  else
    psql --single-transaction -f - < "$file"
  fi
  psql -c "insert into babycare_platform.schema_migrations(version) values ('$version')"
  echo "applied $version"
done

# The API's login password comes from .env; sent on stdin so it never appears in a process list.
if [ -f .env ] && grep -q '^API_DB_PASSWORD=.' .env; then
  password=$(grep '^API_DB_PASSWORD=' .env | cut -d= -f2-)
  printf "alter role babycare_api login password '%s';\n" "$password" | psql -f -
fi
