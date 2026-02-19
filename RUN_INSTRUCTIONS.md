# 🚀 MoodGenie - Run Instructions

## ✅ What Was Fixed

1. **Removed missing image reference** - `google.png` was not in assets, replaced with icon
2. **All assets properly configured** - `pubspec.yaml` correctly references all images
3. **No compilation errors** - All Dart files are error-free
4. **Background images working** - Both login and home screens use proper background images

---

## 🎯 How to Run the App

### Option 1: Using the Fix Script (Recommended)

```bash
cd /Users/eshafarrukh/StudioProjects/MoodGenie
chmod +x fix_and_run.sh
./fix_and_run.sh
```

This script will:
- Clean Flutter cache
- Get dependencies
- Clean and reinstall iOS Pods (macOS only)
- Uninstall old Android app
- Run Flutter

---

### Option 2: Manual Steps

#### Step 1: Clean Everything
```bash
cd /Users/eshafarrukh/StudioProjects/MoodGenie
flutter clean
flutter pub get
```

#### Step 2: Clean iOS (if on macOS)
```bash
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
```

#### Step 3: Uninstall Old App

**For Android (using terminal):**
```bash
adb uninstall com.example.moodgenie
```

**For Android (manually):**
1. Open your Android device/emulator
2. Find the MoodGenie app
3. Long press the app icon
4. Tap "Uninstall"
5. Confirm

**For iOS Simulator:**
1. Open the Simulator
2. Long press the MoodGenie app icon
3. Click the X to delete
4. Confirm

#### Step 4: Run Flutter
```bash
flutter run
```

---

## 🔧 Troubleshooting

### Issue: "Unable to load asset: AssetManifest.json" (Google Fonts Error)
This happens when the Flutter build system hasn't generated the asset manifest properly.

**Quick Fix:**
```bash
cd /Users/eshafarrukh/StudioProjects/MoodGenie
chmod +x fix_google_fonts.sh
./fix_google_fonts.sh
```

**Manual Fix:**
```bash
# Stop the running app first (press 'q' in terminal)
flutter clean
rm -rf pubspec.lock
flutter pub get
flutter build bundle
```

Then run the app again with hot restart (press 'R' in the terminal, or stop and start again).

**Note:** The app now has fallback fonts, so even if Google Fonts fails, the app will still work with system fonts.

### Issue: "Duplicate libraries warning" (iOS/macOS)
This is just a warning and won't stop the app from running. The fix script handles this.

### Issue: "Asset not found"
- Make sure you ran `flutter pub get`
- Verify images exist in `assets/images/`:
  - ✅ `moodgenie_bg.png`
  - ✅ `login_bg.png`
  - ✅ `logo.png`
  - ✅ `img.png`

### Issue: "Old UI still showing"
**This is the most common issue!** You MUST uninstall the old app first:
- The old app is cached on your device
- Simply running `flutter run` won't replace it properly
- Use the uninstall steps above before running

### Issue: "No devices found"
- Make sure Android Emulator is running, OR
- Make sure iOS Simulator is running, OR
- Connect a physical device via USB

---

## 📱 Expected Result

After following these steps, you should see:

✅ **Login Screen:**
- Dreamy purple/pink cloud background
- Glass morphism login card
- Google sign-in button with icon

✅ **Home Screen:**
- Purple gradient background image
- Floating glass navigation bar at bottom
- Greeting with profile picture
- Glass cards for Quick Mood Check and AI Chat

---

## 🆘 Still Having Issues?

1. **Check the terminal output** - Look for specific error messages
2. **Verify device/emulator is running** - Run `flutter devices` to check
3. **Try running on a different device** - Switch between Android/iOS
4. **Check Firebase configuration** - Make sure `google-services.json` is in place

---

## 📝 Quick Reference Commands

```bash
# Check connected devices
flutter devices

# Run on specific device
flutter run -d <device-id>

# Run with verbose logging
flutter run -v

# Clean everything and start fresh
flutter clean && flutter pub get && flutter run
```

---

**Last Updated:** December 22, 2025  
**Status:** ✅ Ready to run

