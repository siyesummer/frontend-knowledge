#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="/opt/siye-production"
EDGE_DIR="$ROOT_DIR/edge"
EDGE_ENV="$EDGE_DIR/.env"
EDGE_COMPOSE="$EDGE_DIR/compose.yml"
EDGE_TLS_COMPOSE="$EDGE_DIR/compose.tls.yml"
EDGE_SERVICE="edge-nginx"
EDGE_CONTAINER="siye-prod-edge-nginx"
HOST_NGINX_SERVICE="nginx.service"

ACTIVE_CHECKS=(
  'siyes.cn|/|17032186'
  'www.siyes.cn|/|17032186'
  'music.siyes.cn|/|siyeWorld'
  'music-api.siyes.cn|/|<h1>'
  'linux-api.siyes.cn|/health|"status":"UP"'
  'socket.siyes.cn|/health|"service":"socket"'
  'sub2api.siyes.cn|/health|"status":"ok"'
  'draw.siyes.cn|/|<title>Vite + Vue + TS</title>'
)

die() {
  echo "[ERROR] $*" >&2
  return 1
}

require_root() {
  [ "${EUID}" -eq 0 ] || die "Run with sudo: sudo ./script.sh"
}

require_paths() {
  [ -f "$EDGE_ENV" ] || die "Missing $EDGE_ENV"
  [ -f "$EDGE_COMPOSE" ] || die "Missing $EDGE_COMPOSE"
  [ -f "$EDGE_TLS_COMPOSE" ] || die "Missing $EDGE_TLS_COMPOSE"
}

env_value() {
  local key="$1" file="$2"
  awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$file"
}

replace_env_value() {
  local file="$1" key="$2" value="$3" count
  count="$(grep -Ec "^${key}=" "$file" || true)"
  [ "$count" = "1" ] || die "$file must contain exactly one ${key}= entry (found $count)"
  sed -i -E "s|^${key}=.*|${key}=${value}|" "$file"
}

set_parallel_env() {
  local file="$1"
  replace_env_value "$file" EDGE_HTTP_BIND_ADDRESS 127.0.0.1
  replace_env_value "$file" EDGE_HTTP_HOST_PORT 18080
  replace_env_value "$file" EDGE_HTTPS_BIND_ADDRESS 127.0.0.1
  replace_env_value "$file" EDGE_HTTPS_HOST_PORT 18443
  replace_env_value "$file" EDGE_NGINX_SITES_FILE ./nginx/sites-https.conf
}

set_public_env() {
  local file="$1"
  replace_env_value "$file" EDGE_HTTP_BIND_ADDRESS 0.0.0.0
  replace_env_value "$file" EDGE_HTTP_HOST_PORT 80
  replace_env_value "$file" EDGE_HTTPS_BIND_ADDRESS 0.0.0.0
  replace_env_value "$file" EDGE_HTTPS_HOST_PORT 443
  replace_env_value "$file" EDGE_NGINX_SITES_FILE ./nginx/sites-https.conf
}

assert_parallel_env() {
  local file="$1"
  [ "$(env_value EDGE_HTTP_BIND_ADDRESS "$file")" = "127.0.0.1" ] || die "HTTP bind is not 127.0.0.1"
  [ "$(env_value EDGE_HTTP_HOST_PORT "$file")" = "18080" ] || die "HTTP port is not 18080"
  [ "$(env_value EDGE_HTTPS_BIND_ADDRESS "$file")" = "127.0.0.1" ] || die "HTTPS bind is not 127.0.0.1"
  [ "$(env_value EDGE_HTTPS_HOST_PORT "$file")" = "18443" ] || die "HTTPS port is not 18443"
  [[ "$(env_value EDGE_NGINX_SITES_FILE "$file")" == *sites-https.conf ]] || die "HTTPS sites file is not selected"
}

assert_public_env() {
  local file="$1"
  [ "$(env_value EDGE_HTTP_BIND_ADDRESS "$file")" = "0.0.0.0" ] || die "HTTP bind is not 0.0.0.0"
  [ "$(env_value EDGE_HTTP_HOST_PORT "$file")" = "80" ] || die "HTTP port is not 80"
  [ "$(env_value EDGE_HTTPS_BIND_ADDRESS "$file")" = "0.0.0.0" ] || die "HTTPS bind is not 0.0.0.0"
  [ "$(env_value EDGE_HTTPS_HOST_PORT "$file")" = "443" ] || die "HTTPS port is not 443"
  [[ "$(env_value EDGE_NGINX_SITES_FILE "$file")" == *sites-https.conf ]] || die "HTTPS sites file is not selected"
}

compose_edge() {
  local env_file="${EDGE_ENV_FILE:-$EDGE_ENV}"
  docker compose --env-file "$env_file" \
    -f "$EDGE_COMPOSE" \
    -f "$EDGE_TLS_COMPOSE" "$@"
}

check_edge_healthy() {
  local state
  state="$(docker inspect \
    --format '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
    "$EDGE_CONTAINER" 2>/dev/null)" || die "Cannot inspect $EDGE_CONTAINER"
  [ "$state" = "running healthy" ] || die "$EDGE_CONTAINER is not healthy: $state"
  echo "[OK] Docker edge is running and healthy"
}

wait_edge_healthy() {
  local attempt state
  for attempt in {1..30}; do
    state="$(docker inspect \
      --format '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
      "$EDGE_CONTAINER" 2>/dev/null || true)"
    if [ "$state" = "running healthy" ]; then
      echo "[OK] Docker edge became healthy ($attempt/30)"
      return 0
    fi
    echo "[WAIT] Docker edge is not ready ($attempt/30): ${state:-missing}"
    sleep 1
  done
  die "Docker edge did not become healthy"
}

endpoint_authority() {
  local host="$1" port="$2"
  if [ "$port" = "443" ] || [ "$port" = "80" ]; then
    printf '%s' "$host"
  else
    printf '%s:%s' "$host" "$port"
  fi
}

verify_https_routes() {
  local port="$1" label="$2" row host path expected body authority
  for row in "${ACTIVE_CHECKS[@]}"; do
    IFS='|' read -r host path expected <<<"$row"
    authority="$(endpoint_authority "$host" "$port")"
    body="$(curl --noproxy '*' --fail --silent --show-error --max-time 20 \
      --resolve "$host:$port:127.0.0.1" \
      "https://${authority}${path}")" || die "$label route failed: https://${authority}${path}"
    printf '%s' "$body" | grep -Fq "$expected" || die "$label response mismatch: $host$path"
    echo "[OK] $label $host$path"
  done
}

verify_http_redirects() {
  local port="$1" host result authority
  local hosts=(
    siyes.cn www.siyes.cn music.siyes.cn music-api.siyes.cn
    linux-api.siyes.cn socket.siyes.cn sub2api.siyes.cn
    draw.siyes.cn knowledge.siyes.cn
  )
  for host in "${hosts[@]}"; do
    authority="$(endpoint_authority "$host" "$port")"
    result="$(curl --noproxy '*' --silent --show-error --max-time 10 \
      --resolve "$host:$port:127.0.0.1" --output /dev/null \
      --write-out '%{http_code}|%{redirect_url}' "http://${authority}/")" || \
      die "HTTP request failed: $host"
    [ "$result" = "308|https://$host/" ] || die "Unexpected redirect for $host: $result"
    echo "[OK] HTTP redirect $host"
  done
}

verify_knowledge_pending() {
  local port="$1" authority status body_file
  authority="$(endpoint_authority knowledge.siyes.cn "$port")"
  body_file="$(mktemp)"
  status="$(curl --noproxy '*' --silent --show-error --max-time 10 \
    --resolve "knowledge.siyes.cn:$port:127.0.0.1" \
    --output "$body_file" --write-out '%{http_code}' \
    "https://${authority}/")" || {
      rm -f "$body_file"
      die "knowledge.siyes.cn HTTPS request failed"
    }
  if [ "$status" != "503" ] || ! grep -Fq '"status":"pending"' "$body_file"; then
    rm -f "$body_file"
    die "knowledge.siyes.cn did not return 503 pending"
  fi
  rm -f "$body_file"
  echo "[OK] knowledge.siyes.cn returns 503 pending"
}

verify_socket_polling() {
  local port="$1" authority headers body
  authority="$(endpoint_authority socket.siyes.cn "$port")"
  headers="$(mktemp)"
  body="$(curl --noproxy '*' --fail --silent --show-error --max-time 20 \
    --resolve "socket.siyes.cn:$port:127.0.0.1" \
    -H 'Origin: https://music.siyes.cn' \
    -D "$headers" "https://${authority}/socket.io/?EIO=4&transport=polling")" || {
      rm -f "$headers"
      die "Socket.IO polling failed"
    }
  [[ "$body" == 0\{* ]] || { rm -f "$headers"; die "Unexpected Socket.IO response"; }
  grep -Fqi 'access-control-allow-origin: https://music.siyes.cn' "$headers" || {
    rm -f "$headers"
    die "Socket.IO CORS header missing"
  }
  rm -f "$headers"
  echo "[OK] Socket.IO polling and CORS"
}
