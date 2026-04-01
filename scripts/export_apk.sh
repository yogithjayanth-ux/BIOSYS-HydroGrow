#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
PROJECT_DIR="$ROOT_DIR/archive"
OUT_APK="$DIST_DIR/HydroGrow.apk"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--docker|--local]

Builds the Flutter Android APK and writes it to:
  $OUT_APK

--docker  Build inside Docker (requires Docker daemon running)
--local   Build on the host (requires Android SDK installed)
EOF
}

MODE="${1:-}"
if [[ "$MODE" == "-h" || "$MODE" == "--help" ]]; then
  usage
  exit 0
fi
if [[ -n "$MODE" && "$MODE" != "--docker" && "$MODE" != "--local" ]]; then
  echo "Unknown option: $MODE" >&2
  usage >&2
  exit 2
fi

mkdir -p "$DIST_DIR"

docker_daemon_ok() {
  command -v docker >/dev/null 2>&1 || return 1
  docker info >/dev/null 2>&1
}

if [[ "$MODE" == "--docker" || ( -z "$MODE" && docker_daemon_ok ) ]]; then
  cd "$ROOT_DIR"
  docker compose run --rm flutter-apk
  if [[ ! -f "$OUT_APK" ]]; then
    echo "APK build completed but $OUT_APK was not found." >&2
    exit 1
  fi
  echo "Wrote: $OUT_APK"
  exit 0
fi

cd "$PROJECT_DIR"
flutter pub get
flutter build apk --release

BUILT_APK="$PROJECT_DIR/build/app/outputs/flutter-apk/app-release.apk"
if [[ ! -f "$BUILT_APK" ]]; then
  echo "Build succeeded but output APK not found at: $BUILT_APK" >&2
  exit 1
fi

cp -f "$BUILT_APK" "$OUT_APK"
echo "Wrote: $OUT_APK"
