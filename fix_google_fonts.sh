#!/bin/bash

echo "🧹 Cleaning Flutter build cache..."
flutter clean

echo "📦 Removing pub cache lock..."
rm -rf ~/.pub-cache/hosted/pub.dartlang.org/google_fonts-*
rm -rf pubspec.lock

echo "🔄 Getting fresh dependencies..."
flutter pub get

echo "🏗️ Pre-building assets..."
flutter build bundle

echo "🧼 Cleaning iOS Pods..."
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..

echo "✅ Done! Now run: flutter run"

