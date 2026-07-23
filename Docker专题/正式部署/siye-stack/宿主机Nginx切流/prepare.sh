#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_CONFIG="$SCRIPT_DIR/siyes-docker-edge.conf"
TARGET_CONFIG="/etc/nginx/sites-available/siyes-docker-edge"
TARGET_LINK="/etc/nginx/sites-enabled/siyes-docker-edge"

CONFLICTING_SITES=(
  siyes.cn
  draw.siyes.cn
  music-api.siyes.cn
  socket.siyes.cn
)

die() {
  echo "[ERROR] $*" >&2
  exit 1
}

[ "${EUID}" -eq 0 ] || die "Run with sudo: sudo ./prepare.sh"
[ -f "$SOURCE_CONFIG" ] || die "Missing $SOURCE_CONFIG"
[ ! -e "$TARGET_LINK" ] && [ ! -L "$TARGET_LINK" ] || \
  die "$TARGET_LINK is already enabled; no changes were made"

for command_name in nginx docker curl openssl sha256sum; do
  command -v "$command_name" >/dev/null || die "Missing command: $command_name"
done

for path in \
  /etc/letsencrypt/live/siyes-production/fullchain.pem \
  /etc/letsencrypt/live/siyes-production/privkey.pem \
  /etc/ssl/certs/ca-certificates.crt; do
  [ -r "$path" ] || die "Required TLS file is not readable: $path"
done

echo "[INFO] Validate the currently active host Nginx configuration"
nginx -t

echo "[INFO] Install the candidate without enabling or reloading it"
install -o root -g root -m 644 "$SOURCE_CONFIG" "$TARGET_CONFIG"

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TEMP_DIR"' EXIT

cat >"$TEMP_DIR/nginx.conf" <<EOF
pid $TEMP_DIR/nginx.pid;
error_log stderr notice;
events {}
http {
    include /etc/nginx/mime.types;
    include $TARGET_CONFIG;
}
EOF

echo "[INFO] Validate the candidate in an isolated Nginx configuration"
CANDIDATE_OUTPUT="$(nginx -t -c "$TEMP_DIR/nginx.conf" 2>&1)" || {
  printf '%s\n' "$CANDIDATE_OUTPUT" >&2
  die "Candidate configuration validation failed"
}
printf '%s\n' "$CANDIDATE_OUTPUT"

if printf '%s\n' "$CANDIDATE_OUTPUT" | grep -qi 'conflicting server name'; then
  die "Candidate validation contains a conflicting server name warning"
fi

if printf '%s\n' "$CANDIDATE_OUTPUT" | grep -qi 'protocol options redefined'; then
  die "Candidate validation contains a redefined protocol options warning"
fi

echo "[INFO] Candidate checksum"
sha256sum "$TARGET_CONFIG"

echo "[INFO] Known conflicting enabled-site links"
for site in "${CONFLICTING_SITES[@]}"; do
  path="/etc/nginx/sites-enabled/$site"
  if [ -L "$path" ]; then
    printf '[CONFLICT] %s -> %s\n' "$path" "$(readlink -- "$path")"
  elif [ -e "$path" ]; then
    printf '[BLOCKED] %s exists but is not a symbolic link\n' "$path"
  else
    printf '[ABSENT] %s\n' "$path"
  fi
done

echo "[INFO] Active server_name declarations related to siyes.cn"
ACTIVE_CONFIG="$(nginx -T 2>&1)" || die "Unable to read active Nginx configuration"
printf '%s\n' "$ACTIVE_CONFIG" |
  grep -nE 'server_name[^;]*(siyes\.cn|\.siyes\.cn)' || true

echo "[INFO] Docker edge state"
docker inspect \
  --format '{{.Name}} status={{.State.Status}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}} restarts={{.RestartCount}}' \
  siye-prod-edge-nginx

echo "[OK] Candidate installed but NOT enabled; host Nginx was NOT reloaded"
echo "[NEXT] Review this output before running sudo ./cutover.sh"
