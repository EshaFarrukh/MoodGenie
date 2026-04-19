#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! java -version >/dev/null 2>&1; then
  local_jbr="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
  if [ -x "$local_jbr/bin/java" ]; then
    export JAVA_HOME="$local_jbr"
    export PATH="$JAVA_HOME/bin:$PATH"
  fi
fi

echo "==> Flutter dependencies"
cd "$ROOT_DIR"
flutter pub get

echo "==> Flutter tests"
flutter test

echo "==> Flutter analyze"
flutter analyze --no-fatal-infos

echo "==> Firebase rules tests"
cd "$ROOT_DIR/firebase_tests"
npm test

echo "==> Backend tests"
cd "$ROOT_DIR/backend"
npm test

echo "==> Admin tests"
cd "$ROOT_DIR/apps/admin"
npm test

echo "==> Admin production build"
npm run build

echo "==> Android release build"
cd "$ROOT_DIR"
flutter build apk --release

echo "==> Android artifact size budget"
"$ROOT_DIR/scripts/check_artifact_sizes.sh" android

echo "==> iOS no-codesign build"
flutter build ios --no-codesign

echo "==> iOS artifact size budget"
"$ROOT_DIR/scripts/check_artifact_sizes.sh" ios

echo "Release smoke completed successfully."
