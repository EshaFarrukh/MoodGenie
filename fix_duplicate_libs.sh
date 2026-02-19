#!/bin/bash

# Script to fix duplicate -lc++ library warnings in Flutter iOS/macOS builds

echo "🧹 Cleaning Flutter build cache..."
flutter clean

echo "📦 Getting Flutter dependencies..."
flutter pub get

echo "🍎 Cleaning iOS Pods..."
cd ios
rm -rf Pods Podfile.lock
pod deintegrate 2>/dev/null || true
pod install
cd ..

echo "💻 Cleaning macOS Pods..."
cd macos
rm -rf Pods Podfile.lock
pod deintegrate 2>/dev/null || true
pod install
cd ..

echo "✅ Done! The duplicate -lc++ library warnings should be resolved."
echo "You can now run: flutter run"

