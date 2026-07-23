#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_root
require_paths
assert_parallel_env "$EDGE_ENV"

echo "[INFO] Current host Nginx configuration"
nginx -t
systemctl is-active --quiet "$HOST_NGINX_SERVICE" || die "Host Nginx is not active"
systemctl is-enabled --quiet "$HOST_NGINX_SERVICE" || die "Host Nginx is not enabled"

echo "[INFO] Current Docker edge state"
check_edge_healthy

echo "[INFO] Current parallel HTTPS routes"
verify_https_routes 18443 "Docker edge"
verify_http_redirects 18080
verify_knowledge_pending 18443
verify_socket_polling 18443

echo "[INFO] Validate public-port candidate without changing the server"
CANDIDATE="$(mktemp)"
trap 'rm -f "$CANDIDATE"' EXIT
cp -a "$EDGE_ENV" "$CANDIDATE"
set_public_env "$CANDIDATE"
assert_public_env "$CANDIDATE"
EDGE_ENV_FILE="$CANDIDATE" compose_edge config --quiet

echo "[INFO] Candidate edge port mapping"
printf 'HTTP=%s:%s HTTPS=%s:%s\n' \
  "$(env_value EDGE_HTTP_BIND_ADDRESS "$CANDIDATE")" \
  "$(env_value EDGE_HTTP_HOST_PORT "$CANDIDATE")" \
  "$(env_value EDGE_HTTPS_BIND_ADDRESS "$CANDIDATE")" \
  "$(env_value EDGE_HTTPS_HOST_PORT "$CANDIDATE")"

echo "[OK] Candidate validated; host Nginx was not stopped or reloaded"
echo "[NEXT] Review this output, then run sudo ./cutover.sh"
