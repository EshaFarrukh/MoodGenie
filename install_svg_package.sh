#!/bin/bash

echo "=========================================="
echo "📦 Installing flutter_svg package"
echo "=========================================="
echo ""

cd /Users/eshafarrukh/StudioProjects/MoodGenie

echo "Step 1: Getting new dependencies..."
flutter pub get

echo ""
echo "Step 2: Pre-building assets..."
flutter build bundle

echo ""
echo "=========================================="
echo "✅ DONE!"
echo "=========================================="
echo ""
echo "The SVG logo is now ready to use!"
echo ""
echo "To see the changes:"
echo "  - If app is running: Press 'R' for hot restart"
echo "  - If app is stopped: Run 'flutter run'"
echo ""

