#!/bin/bash
# Uninstall MoodGenie app from Android device/emulator

echo "🗑️  Attempting to uninstall MoodGenie..."
echo ""
echo "Package name: com.example.moodgenie"
echo ""

# Check if adb is available
if ! command -v adb &> /dev/null; then
    echo "❌ adb command not found"
    echo ""
    echo "📱 Please uninstall manually:"
    echo "   1. Find the MoodGenie app icon on your device"
    echo "   2. Long press the app icon"
    echo "   3. Tap 'Uninstall'"
    echo "   4. Confirm"
    echo ""
    exit 1
fi

# Check if any devices are connected
if ! adb devices | grep -q 'device$'; then
    echo "❌ No Android devices/emulators found"
    echo ""
    echo "📱 Please:"
    echo "   1. Make sure your emulator is running, OR"
    echo "   2. Manually uninstall: Long press app icon → Uninstall"
    echo ""
    exit 1
fi

# Uninstall the app
echo "Uninstalling com.example.moodgenie..."
adb uninstall com.example.moodgenie

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ MoodGenie successfully uninstalled!"
    echo ""
    echo "🚀 Now run:"
    echo "   flutter run"
    echo ""
else
    echo ""
    echo "⚠️  Uninstall failed or app not found"
    echo ""
    echo "This might mean:"
    echo "   • App is already uninstalled (which is good!)"
    echo "   • App has a different package name"
    echo ""
    echo "📱 To manually uninstall:"
    echo "   1. Long press MoodGenie app icon"
    echo "   2. Tap 'Uninstall'"
    echo "   3. Confirm"
    echo ""
fi

