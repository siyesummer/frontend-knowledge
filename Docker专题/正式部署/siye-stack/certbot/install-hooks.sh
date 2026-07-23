#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "[ERROR] Run this installer with sudo" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="/etc/letsencrypt/dnspod.env"
AUTH_TARGET="/usr/local/sbin/certbot-dnspod-auth"
CLEANUP_TARGET="/usr/local/sbin/certbot-dnspod-cleanup"
DEPLOY_DIR="/etc/letsencrypt/renewal-hooks/deploy"
DEPLOY_TARGET="$DEPLOY_DIR/reload-siye-edge"

if [ ! -f "$ENV_FILE" ]; then
  echo "[ERROR] Missing $ENV_FILE" >&2
  exit 1
fi

env_mode="$(stat -c '%a' "$ENV_FILE")"
env_owner="$(stat -c '%U:%G' "$ENV_FILE")"
if [ "$env_mode" != "600" ] || [ "$env_owner" != "root:root" ]; then
  echo "[ERROR] $ENV_FILE must be permission=600 owner=root:root" >&2
  exit 1
fi

bash -n "$SCRIPT_DIR/certbot-dnspod-auth"
bash -n "$SCRIPT_DIR/certbot-dnspod-cleanup"
bash -n "$SCRIPT_DIR/reload-siye-edge"

install -o root -g root -m 700 -d /var/lib/letsencrypt/dnspod
install -o root -g root -m 700 "$SCRIPT_DIR/certbot-dnspod-auth" "$AUTH_TARGET"
install -o root -g root -m 700 "$SCRIPT_DIR/certbot-dnspod-cleanup" "$CLEANUP_TARGET"
install -o root -g root -m 755 -d "$DEPLOY_DIR"
install -o root -g root -m 700 "$SCRIPT_DIR/reload-siye-edge" "$DEPLOY_TARGET"

bash -n "$AUTH_TARGET"
bash -n "$CLEANUP_TARGET"
bash -n "$DEPLOY_TARGET"

echo "[OK] Certbot DNSPod hooks installed"
stat -c 'path=%n permission=%a owner=%U:%G' \
  "$ENV_FILE" \
  "$AUTH_TARGET" \
  "$CLEANUP_TARGET" \
  "$DEPLOY_TARGET" \
  /var/lib/letsencrypt/dnspod

cat <<'NEXT_STEPS'

Next: configure the existing certificate with these hooks, then run a staging renewal test.
Do not execute the DNS hooks directly; Certbot provides their required environment variables.
NEXT_STEPS
