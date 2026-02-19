#!/bin/bash

# Fix Assets Script for MoodGenie
# This script will clean and rebuild the app to fix asset loading issues

echo "🧹 Cleaning Flutter build cache..."
flutter clean

echo "📦 Getting dependencies..."
flutter pub get

echo "🔨 Rebuilding the app..."
flutter build ios --debug

echo "✅ Done! Now try running: flutter run"

