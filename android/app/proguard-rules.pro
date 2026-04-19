# Keep Firebase and Flutter plugin metadata intact in release builds.
-keep class io.flutter.plugins.** { *; }
-keep class com.google.firebase.** { *; }
-dontwarn org.webrtc.**
