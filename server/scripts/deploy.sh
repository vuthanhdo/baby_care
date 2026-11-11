#!/usr/bin/env bash
# Copies the server folder, the app migrations and the SQL tests to the VPS and starts the stack.
# Usage on the Mac, from the repository root: server/scripts/deploy.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
host=${BABYCARE_VPS:-ubuntu@158.178.232.52}
key=${BABYCARE_VPS_KEY:-$HOME/Downloads/ssh-key-2026-10-28.key}
ssh_cmd="ssh -i $key"
# --delete leaves excluded paths alone: the secrets, the copied SQL and the data folders stay.
rsync -az --delete --exclude .env --exclude migrations --exclude sql-tests --exclude files --exclude backups \
  --exclude node_modules -e "$ssh_cmd" server/ "$host:/srv/babycare/"
rsync -az --delete -e "$ssh_cmd" supabase/migrations/ "$host:/srv/babycare/migrations/"
rsync -az --delete -e "$ssh_cmd" --include '*.sql' --exclude '*' supabase/tests/ "$host:/srv/babycare/sql-tests/"
# Database first and migrated (the API role and its password come from the migrations), then the API is rebuilt.
# The files folder belongs to the container's `node` user (uid 1000).
$ssh_cmd "$host" 'cd /srv/babycare && scripts/init-env.sh && sudo chown 1000:1000 /srv/babycare/files \
  && sudo install -m 644 cron/babycare-backup /etc/cron.d/babycare-backup \
  && sudo docker compose up -d --wait db && sudo scripts/migrate.sh \
  && sudo docker compose up -d --build --wait \
  && sudo docker compose exec -T caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile \
  && sudo docker compose ps \
  && grep "^PUBLISHABLE_KEY=" .env'
# The last line is the client key the app ships with (CloudConfiguration.publishableKey); it is public by design.
# The other values in .env are secrets and are never printed.
