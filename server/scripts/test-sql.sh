#!/usr/bin/env bash
# Builds a throwaway database from scratch (platform + app migrations) and runs the SQL test suites from
# supabase/tests against it. Each suite rolls itself back; the real database is never touched.
# Usage on the VPS, from /srv/babycare: scripts/test-sql.sh
set -euo pipefail
cd "$(dirname "$0")/.."
admin() { docker compose exec -T db psql -X -v ON_ERROR_STOP=1 -U postgres -d postgres -q "$@"; }
admin -c "drop database if exists babycare_test" -c "create database babycare_test"
scripts/migrate.sh babycare_test > /dev/null
status=0
for name in consent backend sharing feedback features; do
  if out=$(docker compose exec -T db psql -X -v ON_ERROR_STOP=1 -U postgres -d babycare_test -tA -F ' ' -f "/sql/tests/$name.sql" 2>&1); then
    echo "$name: PASS ($(echo "$out" | grep -E '^[0-9]+( t)?$' | tail -1 | cut -d' ' -f1) checks)"
  else
    echo "$name: FAIL"; echo "$out" | grep -E 'ERROR|FAILED' | head -5; status=1
  fi
done
admin -c "drop database babycare_test"
exit $status
