#!/bin/bash
# COMPLETE FIX - Run this after uninstalling the app manually

echo "════════════════════════════════════════════════"
echo "  MoodGenie - Complete Rebuild & Fresh Install"
echo "════════════════════════════════════════════════"
echo ""
echo "⚠️  BEFORE RUNNING THIS SCRIPT:"
echo ""
echo "   📱 UNINSTALL the old app from your device:"
echo "      1. Long press MoodGenie app icon (2-3 seconds)"
echo "      2. Tap 'Uninstall'"
echo "      3. Confirm"
echo ""
read -p "Have you uninstalled the app? (y/n): " answer

if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
    echo ""
    echo "❌ Please uninstall the app first, then run this script again."
    echo ""
    echo "To uninstall:"
    echo "  • Long press the MoodGenie icon on your device"
    echo "  • Tap 'Uninstall'"
    echo "  • Confirm"
    echo ""
    exit 1
fi

echo ""
echo "✅ Great! Starting clean rebuild..."
echo ""

# Navigate to project directory
cd /Users/eshafarrukh/StudioProjects/MoodGenie

# Step 1: Clean
echo "🧹 Step 1/4: Cleaning build cache..."
flutter clean
if [ $? -ne 0 ]; then
    echo "❌ Flutter clean failed"
    exit 1
fi
echo "✅ Clean complete"
echo ""

# Step 2: Remove build artifacts
echo "🗑️  Step 2/4: Removing build artifacts..."
rm -rf build/
rm -rf .dart_tool/
echo "✅ Build artifacts removed"
echo ""

# Step 3: Get dependencies
echo "📦 Step 3/4: Getting dependencies..."
flutter pub get
if [ $? -ne 0 ]; then
    echo "❌ Flutter pub get failed"
    exit 1
fi
echo "✅ Dependencies updated"
echo ""

# Step 4: Run the app
echo "🚀 Step 4/4: Running fresh install..."
echo ""
echo "════════════════════════════════════════════════"
echo "  Starting Flutter..."
echo "════════════════════════════════════════════════"
echo ""
echo "⏱️  This will take 30-60 seconds..."
echo ""
echo "You should see:"
echo "  ✅ Login screen (if not logged in)"
echo "  ✅ MoodGenie Dashboard with gradient background"
echo "  ✅ Cards, buttons, bottom navigation"
echo "  ✅ NO MORE 'Flutter Demo Home Page'"
echo ""

flutter run
