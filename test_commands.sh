#!/bin/bash
# Quick Commands for MoodGenie App Testing

echo "🎯 MoodGenie - Streak Fix Testing Commands"
echo "=========================================="
echo ""

# Navigate to project directory
cd /Users/eshafarrukh/StudioProjects/MoodGenie

echo "📁 Current Directory: $(pwd)"
echo ""

# Function to show menu
show_menu() {
    echo "Choose an action:"
    echo "1) Clean project"
    echo "2) Get dependencies"
    echo "3) Run app"
    echo "4) Clean + Get dependencies + Run"
    echo "5) Check for errors"
    echo "6) View documentation"
    echo "7) Exit"
    echo ""
}

# Main loop
while true; do
    show_menu
    read -p "Enter choice [1-7]: " choice

    case $choice in
        1)
            echo "🧹 Cleaning project..."
            flutter clean
            echo "✅ Clean complete!"
            ;;
        2)
            echo "📦 Getting dependencies..."
            flutter pub get
            echo "✅ Dependencies updated!"
            ;;
        3)
            echo "🚀 Running app..."
            flutter run
            ;;
        4)
            echo "🔄 Full reset and run..."
            flutter clean
            flutter pub get
            flutter run
            ;;
        5)
            echo "🔍 Checking for errors..."
            flutter analyze
            ;;
        6)
            echo "📚 Documentation files:"
            echo ""
            echo "Main Files:"
            ls -lh IMPLEMENTATION_COMPLETE.md 2>/dev/null || echo "  - IMPLEMENTATION_COMPLETE.md"
            ls -lh STREAK_FIX_QUICKREF.md 2>/dev/null || echo "  - STREAK_FIX_QUICKREF.md"
            ls -lh TEST_STREAK_FIX.md 2>/dev/null || echo "  - TEST_STREAK_FIX.md"
            ls -lh STREAK_ALGORITHM_DETAILS.md 2>/dev/null || echo "  - STREAK_ALGORITHM_DETAILS.md"
            echo ""
            echo "To read: cat IMPLEMENTATION_COMPLETE.md"
            ;;
        7)
            echo "👋 Goodbye!"
            exit 0
            ;;
        *)
            echo "❌ Invalid choice. Please try again."
            ;;
    esac
    echo ""
    read -p "Press Enter to continue..."
    echo ""
done

