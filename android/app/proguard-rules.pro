# Flutter Play Store Split
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Audioplayers
-keep class xyz.luan.audioplayers.** { *; }
-dontwarn xyz.luan.audioplayers.**

# General
-dontwarn okhttp3.**
-keep class com.lantechcomputers.smartschool.** { *; }