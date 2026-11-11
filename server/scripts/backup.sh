#!/usr/bin/env bash
# Nightly backup on the VPS, run as root by /etc/cron.d/babycare-backup (installed by deploy.sh):
# - a pg_dump of the database;
# - a snapshot of the photo folder, hard-linked to the previous one, so unchanged photos take no extra space.
# Keeps the newest 14 of each. The copies sit on the same disk: they undo mistakes, not a lost disk.
# Restore: see server/README.md.
set -euo pipefail
cd /srv/babycare
dir=/srv/babycare/backups
stamp=$(date -u +%Y%m%d-%H%M)
install -d -m 700 "$dir"

# Custom format: compressed, and pg_restore can bring back a single table.
docker compose exec -T db pg_dump -U postgres -Fc babycare > "$dir/db-$stamp.dump.partial"
mv "$dir/db-$stamp.dump.partial" "$dir/db-$stamp.dump"

latest=$(ls -1d "$dir"/files-* 2>/dev/null | tail -n 1 || true)
rsync -a --delete ${latest:+--link-dest="$latest"} /srv/babycare/files/ "$dir/files-$stamp/"

# Names sort by time; everything but the newest 14 goes.
{ ls -1d "$dir"/db-*.dump 2>/dev/null || true; } | head -n -14 | xargs -r rm -f
{ ls -1d "$dir"/files-* 2>/dev/null || true; } | head -n -14 | xargs -r rm -rf

usage=$(df --output=pcent / | tail -n 1 | tr -dc 0-9)
echo "backup $stamp done, $(du -sh "$dir" | cut -f1) in backups, disk ${usage}% used"
if [ "$usage" -ge 80 ]; then echo "WARNING: disk ${usage}% used" >&2; fi
