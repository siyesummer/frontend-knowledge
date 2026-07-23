#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_root
require_paths

BACKUP_DIR="${1:-}"
[ -n "$BACKUP_DIR" ] || die "Usage: sudo ./rollback.sh /opt/siye-production/backups/docker-edge-direct-cutover/YYYYMMDD-HHMMSS"
case "$BACKUP_DIR" in
  "$ROOT_DIR"/backups/docker-edge-direct-cutover/*) ;;
  *) die "Unexpected backup path: $BACKUP_DIR" ;;
esac
[ -f "$BACKUP_DIR/edge.env.before" ] || die "Missing $BACKUP_DIR/edge.env.before"

echo "[ROLLBACK] Restore parallel Docker edge ports"
cp -a "$BACKUP_DIR/edge.env.before" "$EDGE_ENV"
assert_parallel_env "$EDGE_ENV"
compose_edge config --quiet
compose_edge up -d --no-deps --force-recreate "$EDGE_SERVICE"
wait_edge_healthy

echo "[ROLLBACK] Re-enable and start host Nginx"
nginx -t
systemctl enable "$HOST_NGINX_SERVICE"
systemctl start "$HOST_NGINX_SERVICE"
systemctl is-active --quiet "$HOST_NGINX_SERVICE" || die "Host Nginx did not start"

echo "[VERIFY] Restored parallel routes"
verify_https_routes 18443 "Restored Docker edge"
verify_http_redirects 18080
verify_knowledge_pending 18443
verify_socket_polling 18443

echo "[OK] Rollback completed from $BACKUP_DIR"
