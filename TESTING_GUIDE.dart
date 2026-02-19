// Example test code for Firebase Auth Therapist Signup Flow
// Add this to your test folder or use as reference

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:moodgenie/src/auth/auth_di.dart';
import 'package:moodgenie/src/auth/services/auth_service.dart';
import 'package:moodgenie/src/auth/widgets/auth_widgets.dart';
import 'package:moodgenie/screens/auth/therapist_signup_screen.dart';
import 'package:moodgenie/screens/therapist/therapist_dashboard_screen.dart';
import 'package:moodgenie/screens/home/home_screen.dart';
import 'package:moodgenie/screens/auth/login_screen.dart';
import 'package:moodgenie/screens/splash/splash_screen.dart';

// Manual Testing Guide
/*

## 🧪 **Manual Testing Steps**

### **Test 1: Therapist Signup Flow**
1. Run the app: `flutter run`
2. Should show login screen (since not authenticated)
3. Look for "Are you a therapist?" section
4. Tap "Sign Up as Therapist" button
5. Fill out the form:
   - Name: "Dr. Test Therapist"
   - Email: "test.therapist@example.com"
   - Password: "password123"
   - Confirm Password: "password123"
   - Check the terms checkbox
6. Tap "Create Therapist Account"
7. Should show loading state
8. Should navigate to Therapist Dashboard
9. Should show "Account Under Review" message
10. Should show personalized welcome: "Welcome, Dr. Test Therapist!"

### **Test 2: Firebase Document Creation**
1. After successful signup, check Firebase Console
2. Navigate to Firestore Database
3. Check `users` collection:
   - Document ID should be the user's UID
   - Should contain: email, name, role: "therapist", consentAccepted: false, timestamps
4. Check `therapists` collection:
   - Document ID should be the same UID
   - Should contain: userId, isApproved: false, createdAt timestamp

### **Test 3: Role-Based Routing**
1. Sign out from therapist dashboard (logout button)
2. Sign up as regular user (use signup screen, not therapist signup)
3. Should navigate to user home screen (not therapist dashboard)
4. Sign out and login as therapist again
5. Should navigate to therapist dashboard

### **Test 4: Login Updates lastLoginAt**
1. Login as therapist
2. Check Firestore users/{uid} document
3. lastLoginAt should be updated to current timestamp

### **Test 5: Error Handling**
1. Try signing up with existing email
2. Try weak password (less than 6 chars)
3. Try mismatched passwords
4. Try invalid email format
5. Should show appropriate error messages

### **Test 6: Loading States**
1. Observe loading indicators during signup
2. Button should be disabled during loading
3. Should show loading overlay during auth operations

### **Expected Firebase Structure After Tests**

```
users/
  {therapist-uid}/
    email: "test.therapist@example.com"
    name: "Dr. Test Therapist"
    role: "therapist"
    consentAccepted: false
    createdAt: {timestamp}
    lastLoginAt: {timestamp}

  {user-uid}/
    email: "test.user@example.com"
    name: "Test User"
    role: "user"
    consentAccepted: false
    createdAt: {timestamp}
    lastLoginAt: {timestamp}

therapists/
  {therapist-uid}/
    userId: {therapist-uid}
    isApproved: false
    createdAt: {timestamp}
```

*/

// Widget test example for therapist signup screen
void main() {
  testWidgets('Therapist signup screen renders correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (context) => AuthDependencyInjection.authService,
        child: MaterialApp(
          home: const TherapistSignUpScreen(),
        ),
      ),
    );

    // Verify that form fields are present
    expect(find.text('Join as Therapist'), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);
    expect(find.text('Create Therapist Account'), findsOneWidget);
  });

  testWidgets('RoleGate navigates correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (context) => AuthDependencyInjection.authService,
        child: MaterialApp(
          home: RoleGate(
            userHome: const HomeScreen(),
            therapistDashboard: const TherapistDashboardScreen(),
            loginScreen: const LoginScreen(),
            splashScreen: const SplashScreen(),
          ),
        ),
      ),
    );

    // Should show splash initially while loading auth state
    expect(find.byType(SplashScreen), findsOneWidget);
  });
}

// Example of how to use AuthService programmatically
class ExampleAuthUsage {
  static Future<void> testTherapistSignup() async {
    try {
      final authService = AuthDependencyInjection.authService;

      // Sign up as therapist
      await authService.signUpTherapist(
        email: 'test.therapist@example.com',
        password: 'password123',
        name: 'Dr. Test Therapist',
      );

      print('✅ Therapist signup successful');
      print('User role: ${authService.currentUser?.role}');
      print('User name: ${authService.currentUser?.name}');

    } catch (e) {
      print('❌ Therapist signup failed: $e');
    }
  }

  static Future<void> testSignIn() async {
    try {
      final authService = AuthDependencyInjection.authService;

      // Sign in
      await authService.signIn(
        email: 'test.therapist@example.com',
        password: 'password123',
      );

      print('✅ Sign in successful');
      print('User authenticated: ${authService.isAuthenticated}');

    } catch (e) {
      print('❌ Sign in failed: $e');
    }
  }
}
