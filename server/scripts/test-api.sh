#!/usr/bin/env bash
# Runs the API test suite (api/test) against a throwaway, freshly migrated database on the real Postgres 17, from a
# Node container on the compose network. The real database and files are never touched.
# Usage on the VPS, from /srv/babycare: scripts/test-api.sh
set -euo pipefail
cd "$(dirname "$0")/.."
admin() { docker compose exec -T db psql -X -v ON_ERROR_STOP=1 -U postgres -d postgres -q "$@"; }
admin -c "drop database if exists babycare_test" -c "create database babycare_test"
scripts/migrate.sh babycare_test > /dev/null
umask 077
envfile=$(mktemp)
trap 'rm -f "$envfile"; admin -c "drop database if exists babycare_test"' EXIT
{
  echo "TEST_DATABASE_URL=postgres://babycare_api:$(grep '^API_DB_PASSWORD=' .env | cut -d= -f2-)@db:5432/babycare_test"
  echo "TEST_ADMIN_URL=postgres://postgres:$(grep '^POSTGRES_PASSWORD=' .env | cut -d= -f2-)@db:5432/babycare_test"
} > "$envfile"
docker run --rm --network babycare_default --env-file "$envfile" -v "$PWD/api:/src:ro" -v "$PWD/db:/srv/babycare/server/db:ro" \
  -v "$PWD/migrations:/srv/babycare/supabase/migrations:ro" node:24-slim \
  sh -c 'cp -r /src /srv/babycare/server/api && cd /srv/babycare/server/api && npm ci --no-audit --no-fund --loglevel=error && node --test --test-concurrency=1 test/*.test.ts'
