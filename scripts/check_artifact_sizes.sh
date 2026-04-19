#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-all}"

MAX_ANDROID_APK_MB="${MAX_ANDROID_APK_MB:-110}"
MAX_IOS_APP_MB="${MAX_IOS_APP_MB:-90}"

android_apk="$ROOT_DIR/build/app/outputs/flutter-apk/app-release.apk"
ios_runner_app="$ROOT_DIR/build/ios/iphoneos/Runner.app"

measure_mb() {
  du -sm "$1" | awk '{print $1}'
}

check_android() {
  if [ ! -f "$android_apk" ]; then
    echo "FAIL: Android APK is missing at $android_apk" >&2
    exit 1
  fi

  local size_mb
  size_mb="$(measure_mb "$android_apk")"
  echo "Android release APK size: ${size_mb}MB (budget: ${MAX_ANDROID_APK_MB}MB)"
  if [ "$size_mb" -gt "$MAX_ANDROID_APK_MB" ]; then
    echo "FAIL: Android release APK exceeds size budget." >&2
    exit 1
  fi
}

check_ios() {
  if [ ! -d "$ios_runner_app" ]; then
    echo "FAIL: iOS Runner.app is missing at $ios_runner_app" >&2
    exit 1
  fi

  local size_mb
  size_mb="$(measure_mb "$ios_runner_app")"
  echo "iOS Runner.app size: ${size_mb}MB (budget: ${MAX_IOS_APP_MB}MB)"
  if [ "$size_mb" -gt "$MAX_IOS_APP_MB" ]; then
    echo "FAIL: iOS Runner.app exceeds size budget." >&2
    exit 1
  fi
}

case "$MODE" in
  android)
    check_android
    ;;
  ios)
    check_ios
    ;;
  all)
    check_android
    check_ios
    ;;
  *)
    echo "Usage: $0 [android|ios|all]" >&2
    exit 1
    ;;
esac
