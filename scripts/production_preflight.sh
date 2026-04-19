#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_APP_ID="${1:-com.moodgenie.app}"

android_gradle="$ROOT_DIR/android/app/build.gradle.kts"
ios_pbxproj="$ROOT_DIR/ios/Runner.xcodeproj/project.pbxproj"
android_google="$ROOT_DIR/android/app/google-services.json"
ios_google="$ROOT_DIR/ios/Runner/GoogleService-Info.plist"
android_key_props="$ROOT_DIR/android/key.properties"
ios_privacy_manifest="$ROOT_DIR/ios/Runner/PrivacyInfo.xcprivacy"
ios_signing_xcconfig="$ROOT_DIR/ios/Flutter/Signing.xcconfig"

failures=()
warns=()

fail() {
  failures+=("$1")
}

warn() {
  warns+=("$1")
}

echo "==> Checking Android application identity"
grep -q "applicationId = \"$EXPECTED_APP_ID\"" "$android_gradle" ||
  fail "Android applicationId is not $EXPECTED_APP_ID in android/app/build.gradle.kts"

echo "==> Checking iOS bundle identifier"
grep -q "PRODUCT_BUNDLE_IDENTIFIER = $EXPECTED_APP_ID;" "$ios_pbxproj" ||
  fail "iOS PRODUCT_BUNDLE_IDENTIFIER is not $EXPECTED_APP_ID in ios/Runner.xcodeproj/project.pbxproj"

echo "==> Checking Android Firebase app binding"
grep -q "\"package_name\": \"$EXPECTED_APP_ID\"" "$android_google" ||
  fail "android/app/google-services.json is not aligned to $EXPECTED_APP_ID"

echo "==> Checking iOS Firebase app binding"
grep -A1 '<key>BUNDLE_ID</key>' "$ios_google" | grep -q "<string>$EXPECTED_APP_ID</string>" ||
  fail "ios/Runner/GoogleService-Info.plist is not aligned to $EXPECTED_APP_ID"

echo "==> Checking Android release signing"
if [ ! -f "$android_key_props" ]; then
  fail "android/key.properties is missing"
else
  grep -q 'replace-with-' "$android_key_props" &&
    fail "android/key.properties still contains example placeholder values"
  store_file="$(grep '^storeFile=' "$android_key_props" | cut -d= -f2-)"
  [ -n "$store_file" ] || fail "android/key.properties is missing storeFile"
  [ -f "$store_file" ] || fail "Android keystore file does not exist at $store_file"
fi

echo "==> Checking Android release fallback posture"
grep -q 'signingConfigs.getByName("debug")' "$android_gradle" &&
  fail "android/app/build.gradle.kts still falls back to debug signing for release"

echo "==> Checking iOS development team"
if ! grep -q 'DEVELOPMENT_TEAM = [A-Z0-9]\{10\};' "$ios_pbxproj"; then
  if [ ! -f "$ios_signing_xcconfig" ]; then
    fail "No DEVELOPMENT_TEAM is configured in ios/Runner.xcodeproj/project.pbxproj and ios/Flutter/Signing.xcconfig is missing"
  elif ! grep -q '^DEVELOPMENT_TEAM=[A-Z0-9]\{10\}$' "$ios_signing_xcconfig"; then
    fail "ios/Flutter/Signing.xcconfig does not declare a real DEVELOPMENT_TEAM"
  fi
fi

echo "==> Checking privacy manifest richness"
grep -q 'NSPrivacyAccessedAPITypes' "$ios_privacy_manifest" ||
  warn "Privacy manifest does not yet declare accessed API categories"

if [ ${#warns[@]} -gt 0 ]; then
  printf 'WARN: %s\n' "${warns[@]}"
fi

if [ ${#failures[@]} -gt 0 ]; then
  printf 'FAIL: %s\n' "${failures[@]}" >&2
  exit 1
fi

echo "Production preflight passed."
