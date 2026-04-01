#!/usr/bin/env bash
set -euo pipefail

if [[ "${OSTYPE:-}" != darwin* ]]; then
  echo "This helper is for macOS only (OSTYPE=$OSTYPE)." >&2
  exit 2
fi

SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}"
TOOLS_ZIP_URL="${ANDROID_CMDLINE_TOOLS_ZIP_URL:-https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip}"

echo "Android SDK root: $SDK_ROOT"
echo "Cmdline tools zip: $TOOLS_ZIP_URL"

mkdir -p "$SDK_ROOT/cmdline-tools"

tmp_dir="$(mktemp -d)"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT

cd "$tmp_dir"
curl -fL "$TOOLS_ZIP_URL" -o cmdline-tools.zip
unzip -q cmdline-tools.zip

rm -rf "$SDK_ROOT/cmdline-tools/latest"
mv cmdline-tools "$SDK_ROOT/cmdline-tools/latest"

export ANDROID_SDK_ROOT="$SDK_ROOT"
export PATH="$SDK_ROOT/cmdline-tools/latest/bin:$PATH"

sdkmanager --licenses < <(yes) >/dev/null

# Flutter 3.41.x defaults: compileSdk/targetSdk = 36 (Android 16).
sdkmanager \
  "platform-tools" \
  "platforms;android-36" \
  "build-tools;36.0.0"

echo "Installed Android SDK packages into: $SDK_ROOT"
echo "Next: flutter config --android-sdk \"$SDK_ROOT\""
