#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_root
require_paths
assert_parallel_env "$EDGE_ENV"

BACKUP_ROOT="$ROOT_DIR/backups/docker-edge-direct-cutover"
BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
CHANGED=0

rollback_on_error() {
  local rc="$?"
  trap - ERR
  if [ "$CHANGED" = "1" ] && [ -d "$BACKUP_DIR" ]; then
    echo "[ROLLBACK] Direct Docker edge cutover failed; restoring parallel topology" >&2
    cp -a "$BACKUP_DIR/edge.env.before" "$EDGE_ENV"
    compose_edge up -d --no-deps --force-recreate "$EDGE_SERVICE" || true
    wait_edge_healthy || true
    systemctl enable "$HOST_NGINX_SERVICE" || true
    systemctl start "$HOST_NGINX_SERVICE" || true
    echo "[ROLLBACK] Manual recovery backup: $BACKUP_DIR" >&2
  fi
  exit "$rc"
}
trap rollback_on_error ERR

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"
cp -a "$EDGE_ENV" "$BACKUP_DIR/edge.env.before"
docker inspect "$EDGE_CONTAINER" > "$BACKUP_DIR/edge-inspect-before.json"
systemctl status "$HOST_NGINX_SERVICE" --no-pager > "$BACKUP_DIR/host-nginx-before.txt" || true
systemctl is-enabled "$HOST_NGINX_SERVICE" > "$BACKUP_DIR/host-nginx-enabled-before.txt" || true
ss -lntp > "$BACKUP_DIR/ports-before.txt"
nginx -T > "$BACKUP_DIR/nginx-T.txt" 2> "$BACKUP_DIR/nginx-T.stderr.txt"

echo "[PRECHECK] Candidate Compose configuration"
CANDIDATE="$(mktemp)"
trap 'rm -f "$CANDIDATE"' EXIT
cp -a "$EDGE_ENV" "$CANDIDATE"
set_public_env "$CANDIDATE"
assert_public_env "$CANDIDATE"
EDGE_ENV_FILE="$CANDIDATE" compose_edge config --quiet
rm -f "$CANDIDATE"
trap - EXIT

echo "[BACKUP] Saved state: $BACKUP_DIR"
echo "[CUTOVER] Stop host Nginx before claiming public ports"
CHANGED=1
systemctl stop "$HOST_NGINX_SERVICE"

echo "[CUTOVER] Switch edge to 0.0.0.0:80/443"
set_public_env "$EDGE_ENV"
compose_edge up -d --no-deps --force-recreate "$EDGE_SERVICE"
wait_edge_healthy

echo "[VERIFY] Direct Docker edge public HTTPS"
verify_https_routes 443 "Public Docker edge"
verify_http_redirects 80
verify_knowledge_pending 443
verify_socket_polling 443

echo "[VERIFY] Public port ownership"
for port in 80 443; do
  ss -lntp | grep -E "LISTEN.+:${port}[[:space:]]" | grep -q docker-proxy || \
    die "Docker edge does not own public port $port"
done
if ss -lntp | grep -E 'LISTEN.+:(18080|18443)[[:space:]]'; then
  die "Old parallel edge ports are still listening"
fi

echo "[CUTOVER] Disable host Nginx autostart"
systemctl disable "$HOST_NGINX_SERVICE"

docker inspect "$EDGE_CONTAINER" > "$BACKUP_DIR/edge-inspect-after.json"
systemctl is-enabled "$HOST_NGINX_SERVICE" > "$BACKUP_DIR/host-nginx-enabled-after.txt" || true
ss -lntp > "$BACKUP_DIR/ports-after.txt"
sha256sum "$BACKUP_DIR"/* > "$BACKUP_DIR/SHA256SUMS"

CHANGED=0
trap - ERR
echo "[OK] Docker edge now owns public 80/443"
echo "[INFO] Rollback backup: $BACKUP_DIR"
echo "[INFO] Host Nginx remains installed but disabled; old configuration was not deleted"
