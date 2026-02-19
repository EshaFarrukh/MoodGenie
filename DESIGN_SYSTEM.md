# MoodGenie Brand Colors & Design System

## 🎨 Official Brand Color Palette

### Primary Gradient Colors (Left to Right)
```dart
Color(0xFF8B7FD8)  // Purple - "Mood Purple"
Color(0xFFB87FD8)  // Purple-Pink blend
Color(0xFFD87FB8)  // Pink
Color(0xFFFF9966)  // Orange - "MoodGenie Orange"
Color(0xFFFFB366)  // Light Orange
```

### Background Gradient (Home Screen)
```dart
Color(0xFFF0ECFF)  // Very light purple (top-left)
Color(0xFFFFF0F8)  // Very light pink (middle)
Color(0xFFFFF5EC)  // Very light peach (bottom-right)
```

### Accent Colors
```dart
Color(0xFF8B7FD8)  // Primary Purple - buttons, icons, highlights
Color(0xFFFF9966)  // Primary Orange - CTA buttons, selected items
Color(0xFFF0ECFF)  // Light Purple Tint - pills, backgrounds
```

### Text Colors
```dart
Color(0xFF374151)  // Heading text - dark gray
Color(0xFF6B7280)  // Body text - medium gray
Color(0xFF4B5563)  // Secondary text - gray
Color(0xFFB0B0C3)  // Inactive/disabled - light gray
```

### UI Elements
```dart
Colors.white       // Card backgrounds, pure white
Color(0xFFF5F5F7)  // Splash screen background - light gray
```

---

## 📐 Design Specifications

### Typography
- **Logo**: 64px, Weight 700, Letter spacing -1.5
- **Headings**: 24px, Weight 700
- **Card Titles**: 15-16px, Weight 700
- **Body**: 13-14px, Weight 400
- **Small Text**: 12px, Weight 400

### Spacing
- **Card Padding**: 16px all sides
- **Section Spacing**: 16-24px between elements
- **Border Radius**: 
  - Cards: 24px
  - Buttons: 22px
  - Pills: 20px
  - Icons: 16px

### Shadows
```dart
BoxShadow(
  color: Colors.black.withOpacity(0.05),
  blurRadius: 18,
  offset: Offset(0, 8),
)
```

---

## 🎯 Component Color Usage

### Splash Screen
- Background: `Color(0xFFF5F5F7)`
- Logo Text: Gradient (all 5 brand colors)
- Underline: Gradient (all 5 brand colors)
- Loading Indicator: `Color(0xFF8B7FD8)`

### Home Dashboard
- Background: 3-color gradient (purple → pink → peach)
- Avatar Text: `Color(0xFF8B7FD8)`
- Quick Mood Title: `Color(0xFFFF9966)`
- Log Mood Button: `Color(0xFFFF9966)`
- Mood Pills: `Color(0xFFF0ECFF)` background
- Chat Icon: `Color(0xFF8B7FD8)`
- View Report Button: `Color(0xFF8B7FD8)`
- Chart Line: Gradient (`0xFF8B7FD8` → `0xFFB87FD8` → `0xFFFF9966`)
- Talk to MoodGenie Button: `Color(0xFF8B7FD8)`
- Therapist Button: `Color(0xFFFF9966)`

### Bottom Navigation
- Selected Item: `Color(0xFFFF9966)`
- Unselected Item: `Color(0xFFB0B0C3)`

---

## 🚀 Files Updated

1. **Created**: `/lib/screens/splash/splash_screen.dart`
   - Beautiful gradient logo
   - Curved underline decoration
   - Loading indicator

2. **Updated**: `/lib/main.dart`
   - Uses SplashScreen during Firebase initialization
   - Smooth transition to login/home

3. **Updated**: `/lib/screens/home/home_screen.dart`
   - Exact gradient background colors
   - All brand colors applied consistently
   - Purple (`0xFF8B7FD8`) for primary actions
   - Orange (`0xFFFF9966`) for CTAs and highlights

---

## ✨ Brand Identity

**Purple (`#8B7FD8`)**: Trust, calm, mental wellness
**Orange (`#FF9966`)**: Energy, warmth, positive action
**Pink (`#D87FB8`)**: Care, empathy, support

The gradient represents the journey from calm introspection to energized action! 🌈
