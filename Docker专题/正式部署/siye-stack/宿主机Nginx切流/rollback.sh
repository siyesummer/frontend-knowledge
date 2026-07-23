#!/usr/bin/env bash
set -Eeuo pipefail

TARGET_LINK="/etc/nginx/sites-enabled/siyes-docker-edge"
STATE_ROOT="/var/lib/siye-production/host-nginx-cutover"
ACTIVE_BACKUP_FILE="$STATE_ROOT/active-backup"

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

die() {
  echo "[ERROR] $*" >&2
  exit 1
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
}

[ "${EUID}" -eq 0 ] || die "Run with sudo: sudo ./rollback.sh [backup-directory]"

if [ "$#" -gt 1 ]; then
  die "Usage: sudo ./rollback.sh [backup-directory]"
fi

if [ "$#" -eq 1 ]; then
  BACKUP_DIR="$1"
else
  [ -f "$ACTIVE_BACKUP_FILE" ] || die "No active backup pointer: $ACTIVE_BACKUP_FILE"
  BACKUP_DIR="$(cat "$ACTIVE_BACKUP_FILE")"
fi

case "$BACKUP_DIR" in
  /opt/siye-production/backups/host-nginx-cutover-*) ;;
  *) die "Unexpected backup path: $BACKUP_DIR" ;;
esac

[ -d "$BACKUP_DIR/links" ] || die "Invalid backup directory: $BACKUP_DIR"
[ -f "$BACKUP_DIR/etc-nginx.tar.gz" ] || die "Missing Nginx backup archive"

echo "[ROLLBACK] Restore the four managed enabled-site links"

if [ -L "$TARGET_LINK" ]; then
  rm -f -- "$TARGET_LINK"
  echo "[ROLLBACK] Disabled $TARGET_LINK"
elif [ -e "$TARGET_LINK" ]; then
  die "Refusing to remove non-symlink $TARGET_LINK"
fi

for site in "${CONFLICTING_SITES[@]}"; do
  path="/etc/nginx/sites-enabled/$site"
  target_file="$BACKUP_DIR/links/$site.target"

  if [ -L "$path" ]; then
    rm -f -- "$path"
  elif [ -e "$path" ]; then
    die "Refusing to replace non-symlink $path"
  fi

  if [ -f "$target_file" ]; then
    ln -s -- "$(cat "$target_file")" "$path"
    echo "[ROLLBACK] Restored $path -> $(cat "$target_file")"
  else
    echo "[ROLLBACK] Restored absent state: $path"
  fi
done

echo "[ROLLBACK] Validate and reload host Nginx"
validate_nginx
systemctl reload nginx
systemctl is-active --quiet nginx || die "Host nginx.service is not active"

echo "[VERIFY] Protected systemd services were not modified"
for service in "${PROTECTED_SERVICES[@]}"; do
  systemctl is-active --quiet "$service" || die "$service is not active"
  echo "[OK] $service is active"
done

echo "[VERIFY] Host Nginx still owns public ports"
ss -lntp | grep -E 'LISTEN.+:(80|443)[[:space:]]' || \
  die "Public port 80/443 listener verification failed"

echo "[VERIFY] Main site responds through restored configuration"
status="$(curl \
  --noproxy '*' \
  --silent \
  --show-error \
  --max-time 10 \
  --resolve 'siyes.cn:80:127.0.0.1' \
  --output /dev/null \
  --write-out '%{http_code}' \
  'http://siyes.cn/')" || die "Restored main site request failed"

case "$status" in
  200|301|302|307|308) ;;
  *) die "Unexpected restored main site HTTP status: $status" ;;
esac

echo "[OK] Rollback completed from $BACKUP_DIR"
echo "[INFO] Full archive retained at $BACKUP_DIR/etc-nginx.tar.gz"
