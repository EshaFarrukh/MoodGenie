#!/bin/bash

# 🔥 STOP THE APP FIRST! Press 'q' in your running Flutter terminal

echo "=========================================="
echo "🛠️  FIXING GOOGLE FONTS ISSUE"
echo "=========================================="
echo ""

echo "Step 1: Cleaning Flutter..."
flutter clean

echo ""
echo "Step 2: Removing lock file..."
rm -rf pubspec.lock

echo ""
echo "Step 3: Getting dependencies..."
flutter pub get

echo ""
echo "Step 4: Pre-building assets (this fixes AssetManifest.json)..."
flutter build bundle

echo ""
echo "Step 5: Cleaning iOS Pods..."
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..

echo ""
echo "=========================================="
echo "✅ DONE!"
echo "=========================================="
echo ""
echo "Now run your app with:"
echo "  flutter run"
echo ""
echo "Or press 'R' for hot restart if already running"
echo ""

