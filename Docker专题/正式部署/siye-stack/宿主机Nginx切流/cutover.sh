#!/usr/bin/env bash
set -Eeuo pipefail

TARGET_CONFIG="/etc/nginx/sites-available/siyes-docker-edge"
TARGET_LINK="/etc/nginx/sites-enabled/siyes-docker-edge"
BACKUP_ROOT="/opt/siye-production/backups"
STATE_ROOT="/var/lib/siye-production/host-nginx-cutover"
ACTIVE_BACKUP_FILE="$STATE_ROOT/active-backup"
BACKUP_DIR=""
CHANGED=0

CONFLICTING_SITES=(
  siyes.cn
  draw.siyes.cn
  music-api.siyes.cn
  socket.siyes.cn
)

PROTECTED_SERVICES=(
  music-api.service
  linux-server.service
  easy-chat.service
)

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

check_protected_services() {
  local service

  for service in "${PROTECTED_SERVICES[@]}"; do
    systemctl is-active --quiet "$service" || die "$service is not active"
    echo "[OK] Protected service remains active: $service"
  done
}

validate_nginx() {
  local output

  output="$(nginx -t 2>&1)" || {
    printf '%s\n' "$output" >&2
    return 1
  }
  printf '%s\n' "$output"

  if printf '%s\n' "$output" | grep -qi 'conflicting server name'; then
    echo "[ERROR] Nginx reported a conflicting server name" >&2
    return 1
  fi

  if printf '%s\n' "$output" | grep -qi 'protocol options redefined'; then
    echo "[ERROR] Nginx reported redefined protocol options" >&2
    return 1
  fi
}

check_edge_container() {
  local state

  state="$(docker inspect \
    --format '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
    siye-prod-edge-nginx 2>/dev/null)" || die "Cannot inspect siye-prod-edge-nginx"

  [ "$state" = "running healthy" ] || \
    die "siye-prod-edge-nginx is not running and healthy: $state"
  echo "[OK] Docker edge is running and healthy"
}

verify_https_routes() {
  local port="$1"
  local layer="$2"
  local row host path expected body

  for row in "${ACTIVE_CHECKS[@]}"; do
    IFS='|' read -r host path expected <<<"$row"
    body="$(curl \
      --noproxy '*' \
      --fail \
      --silent \
      --show-error \
      --max-time 20 \
      --resolve "$host:$port:127.0.0.1" \
      "https://$host${port:+:$port}$path")" || \
      die "$layer route failed: https://$host${port:+:$port}$path"

    printf '%s' "$body" | grep -Fq "$expected" || \
      die "$layer response signature mismatch: $host$path"
    echo "[OK] $layer $host$path"
  done
}

verify_public_https_routes() {
  local row host path expected body

  for row in "${ACTIVE_CHECKS[@]}"; do
    IFS='|' read -r host path expected <<<"$row"
    body="$(curl \
      --noproxy '*' \
      --fail \
      --silent \
      --show-error \
      --max-time 20 \
      --resolve "$host:443:127.0.0.1" \
      "https://$host$path")" || die "Public HTTPS route failed: https://$host$path"

    printf '%s' "$body" | grep -Fq "$expected" || \
      die "Public HTTPS response signature mismatch: $host$path"
    echo "[OK] Public HTTPS $host$path"
  done
}

wait_for_new_nginx_generation() {
  local attempt body error_file

  error_file="$(mktemp)"

  for attempt in {1..20}; do
    if body="$(curl \
      --noproxy '*' \
      --fail \
      --silent \
      --show-error \
      --connect-timeout 2 \
      --max-time 5 \
      --resolve 'siyes.cn:443:127.0.0.1' \
      'https://siyes.cn/' 2>"$error_file")" && \
      printf '%s' "$body" | grep -Fq '17032186'; then
      rm -f -- "$error_file"
      echo "[OK] New host Nginx generation is serving siyes.cn"
      return 0
    fi

    echo "[WAIT] New host Nginx generation is not ready ($attempt/20)"
    sleep 1
  done

  echo "[ERROR] Last readiness error:" >&2
  cat "$error_file" >&2
  rm -f -- "$error_file"
  die "New host Nginx generation did not become ready within 20 seconds"
}

verify_socket_polling() {
  local body

  body="$(curl \
    --noproxy '*' \
    --fail \
    --silent \
    --show-error \
    --max-time 20 \
    --resolve 'socket.siyes.cn:443:127.0.0.1' \
    'https://socket.siyes.cn/socket.io/?EIO=4&transport=polling')" || \
    die "Public Socket.IO polling failed"

  [[ "$body" == 0\{* ]] || die "Unexpected Socket.IO polling response"
  echo "[OK] Public HTTPS Socket.IO polling"
}

verify_redirects_and_pending_host() {
  local hosts host result status body_file

  hosts=(
    siyes.cn
    www.siyes.cn
    music.siyes.cn
    music-api.siyes.cn
    linux-api.siyes.cn
    socket.siyes.cn
    sub2api.siyes.cn
    draw.siyes.cn
    knowledge.siyes.cn
  )

  for host in "${hosts[@]}"; do
    result="$(curl \
      --noproxy '*' \
      --silent \
      --show-error \
      --max-time 10 \
      --resolve "$host:80:127.0.0.1" \
      --output /dev/null \
      --write-out '%{http_code}|%{redirect_url}' \
      "http://$host/")" || die "HTTP redirect request failed: $host"

    [ "$result" = "308|https://$host/" ] || \
      die "Unexpected HTTP redirect for $host: $result"
    echo "[OK] HTTP redirect $host"
  done

  body_file="$(mktemp)"
  status="$(curl \
    --noproxy '*' \
    --silent \
    --show-error \
    --max-time 10 \
    --resolve 'knowledge.siyes.cn:443:127.0.0.1' \
    --output "$body_file" \
    --write-out '%{http_code}' \
    'https://knowledge.siyes.cn/')" || {
      rm -f -- "$body_file"
      die "knowledge.siyes.cn HTTPS request failed"
    }

  if [ "$status" != "503" ] || ! grep -Fq '"status":"pending"' "$body_file"; then
    rm -f -- "$body_file"
    die "knowledge.siyes.cn did not return the expected 503 pending response"
  fi
  rm -f -- "$body_file"
  echo "[OK] knowledge.siyes.cn presents valid TLS and returns 503 pending"
}

restore_links() {
  local site path target_file

  echo "[ROLLBACK] Restore enabled-site links from $BACKUP_DIR"

  if [ -L "$TARGET_LINK" ]; then
    rm -f -- "$TARGET_LINK"
  elif [ -e "$TARGET_LINK" ]; then
    echo "[ERROR] Refusing to remove non-symlink $TARGET_LINK" >&2
    return 1
  fi

  for site in "${CONFLICTING_SITES[@]}"; do
    path="/etc/nginx/sites-enabled/$site"
    target_file="$BACKUP_DIR/links/$site.target"

    if [ -L "$path" ]; then
      rm -f -- "$path"
    elif [ -e "$path" ]; then
      echo "[ERROR] Refusing to replace non-symlink $path" >&2
      return 1
    fi

    if [ -f "$target_file" ]; then
      ln -s -- "$(cat "$target_file")" "$path"
      echo "[ROLLBACK] Restored $path"
    fi
  done
}

on_error() {
  local status=$?
  trap - ERR

  if [ "$CHANGED" -eq 1 ] && [ -n "$BACKUP_DIR" ]; then
    set +e
    restore_links
    if validate_nginx; then
      systemctl reload nginx
      echo "[ROLLBACK] Host Nginx old enabled-site state restored"
    else
      echo "[CRITICAL] Restored links still fail nginx -t; host Nginx was not reloaded" >&2
    fi
  fi

  exit "$status"
}

trap on_error ERR

[ "${EUID}" -eq 0 ] || die "Run with sudo: sudo ./cutover.sh"

for command_name in nginx docker curl systemctl tar sha256sum; do
  command -v "$command_name" >/dev/null || die "Missing command: $command_name"
done

[ -f "$TARGET_CONFIG" ] || die "Run prepare.sh first; missing $TARGET_CONFIG"
[ ! -e "$TARGET_LINK" ] && [ ! -L "$TARGET_LINK" ] || \
  die "$TARGET_LINK is already enabled"

for path in \
  /etc/letsencrypt/live/siyes-production/fullchain.pem \
  /etc/letsencrypt/live/siyes-production/privkey.pem \
  /etc/ssl/certs/ca-certificates.crt; do
  [ -r "$path" ] || die "Required TLS file is not readable: $path"
done

echo "[PRECHECK] Current host Nginx configuration"
validate_nginx
check_protected_services
check_edge_container

echo "[PRECHECK] Eight routes directly through Docker edge on 18443"
verify_https_routes 18443 "Docker edge"

echo "[PRECHECK] Docker edge certificate identity"
echo | openssl s_client \
  -connect 127.0.0.1:18443 \
  -servername siyes.cn \
  -CAfile /etc/ssl/certs/ca-certificates.crt \
  -verify_return_error 2>/dev/null |
  openssl x509 -noout -subject -dates -ext subjectAltName

install -d -o root -g root -m 700 "$BACKUP_ROOT" "$STATE_ROOT"
BACKUP_DIR="$BACKUP_ROOT/host-nginx-cutover-$(date +%Y%m%d-%H%M%S)"
[ ! -e "$BACKUP_DIR" ] || die "Backup directory already exists: $BACKUP_DIR"
install -d -o root -g root -m 700 "$BACKUP_DIR" "$BACKUP_DIR/links"

echo "[BACKUP] Full /etc/nginx and current state"
tar -czf "$BACKUP_DIR/etc-nginx.tar.gz" -C / etc/nginx
nginx -T >"$BACKUP_DIR/nginx-T.txt" 2>"$BACKUP_DIR/nginx-T.stderr.txt"
docker inspect siye-prod-edge-nginx >"$BACKUP_DIR/edge-inspect.json"
sha256sum "$TARGET_CONFIG" >"$BACKUP_DIR/candidate-config.sha256"

for site in "${CONFLICTING_SITES[@]}"; do
  path="/etc/nginx/sites-enabled/$site"
  if [ -L "$path" ]; then
    readlink -- "$path" >"$BACKUP_DIR/links/$site.target"
  elif [ -e "$path" ]; then
    die "$path exists but is not a symbolic link; refusing to modify it"
  fi
done

find /etc/nginx/sites-enabled -maxdepth 1 -printf '%f|%y|%l\n' \
  >"$BACKUP_DIR/sites-enabled-before.txt"
sha256sum "$BACKUP_DIR/etc-nginx.tar.gz" >"$BACKUP_DIR/SHA256SUMS"
printf '%s\n' "$BACKUP_DIR" >"$ACTIVE_BACKUP_FILE"
chmod 600 "$ACTIVE_BACKUP_FILE"

CHANGED=1

echo "[CUTOVER] Disable only known conflicting enabled-site symlinks"
for site in "${CONFLICTING_SITES[@]}"; do
  path="/etc/nginx/sites-enabled/$site"
  if [ -L "$path" ]; then
    rm -f -- "$path"
    echo "[CUTOVER] Disabled $path"
  fi
done

ln -s -- "$TARGET_CONFIG" "$TARGET_LINK"
echo "[CUTOVER] Enabled $TARGET_LINK"

echo "[CUTOVER] Validate and reload host Nginx"
validate_nginx
systemctl reload nginx
systemctl is-active --quiet nginx || die "Host nginx.service is not active after reload"
wait_for_new_nginx_generation

echo "[VERIFY] Eight public HTTPS routes through host Nginx"
verify_public_https_routes
verify_socket_polling
verify_redirects_and_pending_host
check_protected_services
check_edge_container

CHANGED=0

echo "[OK] Host Nginx now proxies approved siyes.cn hosts to Docker edge"
echo "[INFO] Rollback state: $BACKUP_DIR"
echo "[INFO] Manual rollback: sudo ./rollback.sh '$BACKUP_DIR'"
