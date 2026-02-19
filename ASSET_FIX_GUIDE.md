# Asset Loading Error Fix - MoodGenie

## Problem
The app is showing errors about missing assets:
- `Unable to load asset: "AssetManifest.json"`
- `Unable to load asset: "assets/images/auth_bg.png"`
- `Unable to load asset: "assets/logo/moodgenie_logo.svg"`
- Google Fonts errors

## Root Cause
1. The asset paths in the code didn't match the actual file locations
2. The build cache was corrupted (AssetManifest.json)
3. Some SVG files were referenced but didn't exist in the source assets folder

## Fixes Applied

### 1. Fixed Asset Paths ✅
- Changed `assets/images/auth_bg.png` → `assets/images/login_bg.png` in signup_screen.dart
- Changed `assets/images/moodgenie_logo.png` → `assets/logo/moodgenie_logo.png` in signup_screen.dart
- Changed `assets/logo/moodgenie_logo.svg` → `assets/logo/moodgenie_logo.png` in login_screen.dart

### 2. Verified Assets Exist ✅
- ✅ `assets/images/login_bg.png` - exists
- ✅ `assets/logo/moodgenie_logo.png` - exists  
- ✅ `assets/icons/google.svg` - exists
- ✅ `assets/images/moodgenie_bg.png` - exists
- ✅ `assets/images/logo.png` - exists

### 3. Verified pubspec.yaml ✅
```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/images/
    - assets/logo/
    - assets/icons/
```

## How to Fix

### Option 1: Run the Fix Script (Recommended)
```bash
cd /Users/eshafarrukh/StudioProjects/MoodGenie
chmod +x fix_assets.sh
./fix_assets.sh
flutter run
```

### Option 2: Manual Commands
```bash
cd /Users/eshafarrukh/StudioProjects/MoodGenie

# Step 1: Clean everything
flutter clean

# Step 2: Get dependencies
flutter pub get

# Step 3: Delete the app from your device/simulator
# On iOS Simulator: Long press the app icon → Delete App
# On Android: Settings → Apps → MoodGenie → Uninstall

# Step 4: Run the app
flutter run
```

## Why This Happens
- When asset paths change or files are moved, Flutter caches the old AssetManifest.json
- Hot reload/hot restart doesn't rebuild the asset manifest
- The only way to fix it is to do a full clean and rebuild
- Deleting the app from the device ensures a fresh install

## Verification
After running the fix, you should NOT see these errors:
- ❌ "Unable to load asset: AssetManifest.json"
- ❌ "Unable to load asset: assets/images/auth_bg.png"
- ❌ "Unable to load asset: assets/logo/moodgenie_logo.svg"

The app should display:
- ✅ Login screen with background image
- ✅ Logo image
- ✅ Google icon in the Google sign-in button
- ✅ Home screen with background image

## Note About Google Fonts Warning
The google_fonts package warning about AssetManifest.json is a side effect of the corrupted build cache. After running `flutter clean` and rebuilding, this warning should disappear.

