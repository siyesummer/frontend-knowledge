#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_root
require_paths
assert_parallel_env "$EDGE_ENV"

CANDIDATE="$SCRIPT_DIR/sites-https.conf"
TARGET="$EDGE_DIR/nginx/sites-https.conf"
BACKUP_ROOT="$ROOT_DIR/backups/edge-knowledge-route"
BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
CHANGED=0

[ -f "$CANDIDATE" ] || die "Missing candidate: $CANDIDATE"
[ -f "$TARGET" ] || die "Missing target: $TARGET"
grep -Fq 'server_name knowledge.siyes.cn;' "$CANDIDATE" || \
  die "Candidate does not contain knowledge.siyes.cn"
grep -Fq 'return 308 https://$host$request_uri;' "$CANDIDATE" || \
  die "Candidate does not contain HTTP to HTTPS redirects"

rollback_on_error() {
  local rc="$?"
  trap - ERR
  if [ "$CHANGED" = "1" ] && [ -f "$BACKUP_DIR/sites-https.conf.before" ]; then
    echo "[ROLLBACK] Restore previous Docker edge sites configuration" >&2
    cp -a "$BACKUP_DIR/sites-https.conf.before" "$TARGET"
    compose_edge up -d --no-deps --force-recreate "$EDGE_SERVICE" || true
    wait_edge_healthy || true
    echo "[ROLLBACK] Backup retained at $BACKUP_DIR" >&2
  fi
  exit "$rc"
}
trap rollback_on_error ERR

echo "[PRECHECK] Host Nginx remains active during this update"
systemctl is-active --quiet "$HOST_NGINX_SERVICE" || die "Host Nginx is not active"
check_edge_healthy

EDGE_IMAGE="$(env_value EDGE_NGINX_IMAGE "$EDGE_ENV")"
SIYES_HOME="$(env_value SIYES_HOME_DIR "$EDGE_ENV")"
TLS_DIR="$(env_value TLS_LETSENCRYPT_DIR "$EDGE_ENV")"
[ -n "$EDGE_IMAGE" ] || die "EDGE_NGINX_IMAGE is empty"
[ -d "$SIYES_HOME" ] || die "SIYES_HOME_DIR is invalid: $SIYES_HOME"
[ -d "$TLS_DIR" ] || die "TLS_LETSENCRYPT_DIR is invalid: $TLS_DIR"

echo "[PRECHECK] Validate candidate in an isolated Docker container"
docker run --rm \
  --network siye-prod-edge-net \
  -v "$EDGE_DIR/nginx/nginx.conf:/etc/nginx/nginx.conf:ro" \
  -v "$EDGE_DIR/nginx/upstreams.conf:/etc/nginx/siye/upstreams.conf:ro" \
  -v "$EDGE_DIR/nginx/proxy-common.conf:/etc/nginx/siye/proxy-common.conf:ro" \
  -v "$CANDIDATE:/etc/nginx/siye/sites.conf:ro" \
  -v "$SIYES_HOME:/var/www/siyes.cn:ro" \
  -v "$TLS_DIR:/etc/letsencrypt:ro" \
  "$EDGE_IMAGE" nginx -t

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"
cp -a "$TARGET" "$BACKUP_DIR/sites-https.conf.before"
docker inspect "$EDGE_CONTAINER" > "$BACKUP_DIR/edge-inspect-before.json"
docker exec "$EDGE_CONTAINER" nginx -T > "$BACKUP_DIR/nginx-T-before.txt" 2>&1

owner_uid="$(stat -c '%u' "$TARGET")"
owner_gid="$(stat -c '%g' "$TARGET")"
file_mode="$(stat -c '%a' "$TARGET")"

echo "[UPDATE] Install candidate and recreate only Docker edge"
CHANGED=1
install -o "$owner_uid" -g "$owner_gid" -m "$file_mode" "$CANDIDATE" "$TARGET"
compose_edge up -d --no-deps --force-recreate "$EDGE_SERVICE"
wait_edge_healthy

echo "[VERIFY] Updated parallel Docker edge"
verify_https_routes 18443 "Docker edge"
verify_http_redirects 18080
verify_knowledge_pending 18443
verify_socket_polling 18443

docker inspect "$EDGE_CONTAINER" > "$BACKUP_DIR/edge-inspect-after.json"
docker exec "$EDGE_CONTAINER" nginx -T > "$BACKUP_DIR/nginx-T-after.txt" 2>&1
ss -lntp > "$BACKUP_DIR/ports-after.txt"
sha256sum "$BACKUP_DIR"/* > "$BACKUP_DIR/SHA256SUMS"

systemctl is-active --quiet "$HOST_NGINX_SERVICE" || die "Host Nginx changed unexpectedly"
assert_parallel_env "$EDGE_ENV"

CHANGED=0
trap - ERR
echo "[OK] Docker edge knowledge route installed in parallel topology"
echo "[INFO] Backup: $BACKUP_DIR"
echo "[NEXT] Run sudo ./prepare.sh again"
