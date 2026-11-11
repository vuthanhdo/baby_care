#!/usr/bin/env bash
# Creates /srv/babycare/.env from .env.example and fills empty secrets with random values, without printing them.
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077
[ -f .env ] || cp .env.example .env
chmod 600 .env
for key in POSTGRES_PASSWORD API_DB_PASSWORD JWT_SECRET PUBLISHABLE_KEY; do
  if ! grep -q "^$key=" .env; then
    echo "$key=$(openssl rand -hex 24)" >> .env
    echo "generated $key"
  elif grep -q "^$key=$" .env; then
    sed -i "s/^$key=$/$key=$(openssl rand -hex 24)/" .env
    echo "generated $key"
  fi
done
