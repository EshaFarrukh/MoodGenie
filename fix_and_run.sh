#!/bin/bash
# Complete fix and run script for MoodGenie

set -e  # Exit on error


# Step 1: Clean Flutter
echo "1️⃣ Cleaning Flutter build cache..."
# Navigate to project directory
cd "$(dirname "$0")"
PROJECT_DIR=$(pwd)

fi
echo "✅ Clean complete"
echo ""

# Step 2: Get dependencies
echo "2️⃣ Getting Flutter dependencies..."
flutter pub get
if [ $? -ne 0 ]; then
    echo "❌ Flutter pub get failed"
    exit 1
fi
echo "✅ Dependencies fetched"
# Step 3: Clean and reinstall Pods (macOS only)

    # Clean iOS Pods
    if [ -d "ios" ]; then
        echo "3️⃣ Cleaning iOS Pods..."
        cd ios
        rm -rf Pods Podfile.lock .symlinks
        pod deintegrate 2>/dev/null || true
        pod install --repo-update 2>&1 | grep -v "duplicate libraries" || true
        cd "$PROJECT_DIR"
        echo "✅ iOS Pods cleaned and reinstalled"
        echo ""
    fi

    # Clean macOS Pods
    if [ -d "macos" ]; then
        echo "3️⃣ Cleaning macOS Pods..."
        cd macos
        rm -rf Pods Podfile.lock .symlinks
        pod deintegrate 2>/dev/null || true
        pod install --repo-update 2>&1 | grep -v "duplicate libraries" || true
        cd "$PROJECT_DIR"
        echo "✅ macOS Pods cleaned and reinstalled"
        echo ""
    fi
echo ""

# Step 4: Uninstall old app
echo "4️⃣ Attempting to uninstall old app..."

# Android
echo ""
    if adb devices 2>/dev/null | grep -q 'device$'; then
        echo "   → Uninstalling from Android device..."
        adb uninstall com.example.moodgenie 2>/dev/null || echo "   → App not installed on Android (OK)"

        echo "   → No Android device found"
