#!/bin/bash
# Complete rebuild script for MoodGenie

echo "🧹 Cleaning Flutter build cache..."
flutter clean

echo "🗑️  Removing build directory..."
rm -rf build/

echo "🗑️  Removing .dart_tool cache..."
rm -rf .dart_tool/

echo "📦 Getting dependencies..."
flutter pub get

echo "✅ Clean complete!"
echo ""
echo "⚠️  IMPORTANT: Before running 'flutter run':"
echo "   1. STOP any running Flutter app (press 'q' in terminal)"
echo "   2. UNINSTALL MoodGenie from your device/emulator"
echo "   3. Then run: flutter run"
echo ""
echo "Ready to run: flutter run"

