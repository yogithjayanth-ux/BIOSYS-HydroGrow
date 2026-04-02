#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: bash scripts/docker_setup.sh [--web|--apk|--pull-only]

Ensures Docker is running, pulls images, and starts a service:
  --web       Start the Flutter web server (default)
  --apk       Build + export APK to dist/HydroGrow.apk
  --pull-only Only pull images (no containers started)
EOF
}

MODE="${1:---web}"
case "$MODE" in
  --web|--apk|--pull-only) ;;
  -h|--help) usage; exit 0 ;;
  *) echo "Unknown option: $MODE" >&2; usage >&2; exit 2 ;;
esac

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 127
  fi
}

require_cmd docker

wait_for_docker() {
  local timeout_s="${1:-180}"
  local start_ts
  start_ts="$(date +%s)"
  while true; do
    if docker info >/dev/null 2>&1; then
      return 0
    fi
    local now_ts
    now_ts="$(date +%s)"
    if (( now_ts - start_ts >= timeout_s )); then
      return 1
    fi
    sleep 2
  done
}

if ! docker info >/dev/null 2>&1; then
  if [[ "${OSTYPE:-}" == darwin* ]]; then
    echo "Docker daemon not running. Starting Docker Desktop..."
    open -a Docker >/dev/null 2>&1 || true
  else
    echo "Docker daemon not running. Start Docker, then re-run this script." >&2
  fi

  if ! wait_for_docker 240; then
    echo "Timed out waiting for Docker to start." >&2
    exit 1
  fi
fi

cd "$ROOT_DIR"
mkdir -p dist

echo "Pulling images..."
docker compose pull

case "$MODE" in
  --pull-only)
    echo "Done (pulled images)."
    ;;
  --web)
    echo "Starting web server on http://localhost:8080 ..."
    docker compose up flutter-web
    ;;
  --apk)
    docker compose run --rm flutter-apk
    echo "Wrote: dist/HydroGrow.apk"
    ;;
esac

