#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK_NAME="siye-prod-edge-net"

compose_core() {
  docker compose --env-file "$ROOT_DIR/core/.env" -f "$ROOT_DIR/core/compose.yml" "$@"
}

compose_sub2api() {
  docker compose --env-file "$ROOT_DIR/sub2api/.env" -f "$ROOT_DIR/sub2api/compose.yml" "$@"
}

compose_svg_draw() {
  docker compose --env-file "$ROOT_DIR/svg-draw/.env" -f "$ROOT_DIR/svg-draw/compose.yml" "$@"
}

compose_edge() {
  docker compose --env-file "$ROOT_DIR/edge/.env" -f "$ROOT_DIR/edge/compose.yml" "$@"
}

compose_edge_tls() {
  docker compose --env-file "$ROOT_DIR/edge/.env" \
    -f "$ROOT_DIR/edge/compose.yml" \
    -f "$ROOT_DIR/edge/compose.tls.yml" "$@"
}

ensure_shared_network() {
  if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    docker network create --driver bridge "$NETWORK_NAME" >/dev/null
  fi
}

require_env_files() {
  for file in core/.env sub2api/.env svg-draw/.env edge/.env; do
    test -f "$ROOT_DIR/$file" || {
      echo "missing server env: $ROOT_DIR/$file" >&2
      exit 1
    }
  done
}

config_http() {
  require_env_files
  compose_core config --quiet
  compose_sub2api config --quiet
  compose_svg_draw config --quiet
  compose_edge config --quiet
}

config_https() {
  require_env_files
  compose_core config --quiet
  compose_sub2api config --quiet
  compose_svg_draw config --quiet
  compose_edge_tls config --quiet
}

up_http() {
  config_http
  ensure_shared_network
  compose_core up -d
  compose_sub2api up -d
  compose_svg_draw up -d
  compose_edge up -d
}

up_https() {
  config_https
  ensure_shared_network
  compose_core up -d
  compose_sub2api up -d
  compose_svg_draw up -d
  compose_edge_tls up -d --no-deps --force-recreate edge-nginx
}

show_status() {
  compose_core ps
  compose_sub2api ps
  compose_svg_draw ps
  compose_edge ps
}

case "${1:-}" in
  config)
    config_http
    ;;
  config-https)
    config_https
    ;;
  pull)
    require_env_files
    compose_core pull
    compose_sub2api pull
    compose_svg_draw pull
    compose_edge pull
    ;;
  up)
    up_http
    ;;
  up-https)
    up_https
    ;;
  ps)
    require_env_files
    show_status
    ;;
  down-core)
    compose_core down
    ;;
  down-sub2api)
    compose_sub2api down
    ;;
  down-svg-draw)
    compose_svg_draw down
    ;;
  down-edge)
    compose_edge down
    ;;
  *)
    cat >&2 <<'USAGE'
Usage: ./stack.sh {config|config-https|pull|up|up-https|ps|down-core|down-sub2api|down-svg-draw|down-edge}

The down commands stop one Compose project only and never remove named volumes.
USAGE
    exit 2
    ;;
esac

