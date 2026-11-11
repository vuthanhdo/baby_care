#!/usr/bin/env bash
# Creates a confirmed email account on the VPS without a confirmation email, or gives an existing one a new
# password: for the App Review demo account. The password goes over SSH stdin and is never printed or passed as an
# argument. Usage on the Mac, from the repository root:
#   server/scripts/create-user.sh AppStore/review-account.local.txt   # reads its "Email:" and "Password:" lines
#   server/scripts/create-user.sh                                     # asks for both
set -euo pipefail
cd "$(dirname "$0")/../.."
host=${BABYCARE_VPS:-ubuntu@158.178.232.52}
key=${BABYCARE_VPS_KEY:-$HOME/Downloads/ssh-key-2026-10-28.key}
if [ $# -ge 1 ]; then
  email=$(sed -n 's/^Email:[[:space:]]*//p' "$1" | head -n 1 | tr -d '\r' | sed 's/[[:space:]]*$//')
  password=$(sed -n 's/^Password:[[:space:]]*//p' "$1" | head -n 1 | tr -d '\r' | sed 's/[[:space:]]*$//')
else
  read -r -p "Email: " email
  read -r -s -p "Password: " password; echo
fi
if [ -z "$email" ] || [ -z "$password" ]; then echo "Email and password are required" >&2; exit 1; fi
EMAIL="$email" PASSWORD="$password" python3 -c 'import json, os; print(json.dumps({"email": os.environ["EMAIL"], "password": os.environ["PASSWORD"]}))' \
  | ssh -i "$key" "$host" 'cd /srv/babycare && sudo docker compose exec -T api node src/admin/createUser.ts'
