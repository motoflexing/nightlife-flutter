# R8 / ProGuard keep rules for the Nightlife release build.
#
# Base Android/Kotlin/AndroidX rules come from proguard-android-optimize.txt
# (referenced in build.gradle.kts). Flutter's own tooling contributes the core
# Flutter engine keep rules automatically. The rules below cover the plugins in
# pubspec.yaml that rely on reflection, generated code, or native <-> Dart
# channel classes that R8 would otherwise strip or rename.

# ---- Flutter engine / embedding -------------------------------------------
# Flutter uses reflection to register plugins (GeneratedPluginRegistrant) and
# to bridge platform channels.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# ---- Firebase (Core, Auth, Firestore, Storage, Messaging, Analytics,
#      Crashlytics) --------------------------------------------------------
# Firebase relies on reflection for model (de)serialization and on generated
# GMS classes. Crashlytics also needs unobfuscated stack frames to be useful.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
# Keep source file/line info so Crashlytics reports stay readable.
-keepattributes SourceFile,LineNumberTable
-keepattributes *Annotation*
-keepattributes Signature

# ---- firebase_messaging ----------------------------------------------------
# The background message handler is invoked reflectively via @pragma
# vm:entry-point; keep FCM service classes intact.
-keep class com.google.firebase.messaging.** { *; }

# ---- geolocator / geocoding ------------------------------------------------
-keep class com.baseflow.geolocator.** { *; }
-keep class com.baseflow.geocoding.** { *; }

# ---- google_maps_flutter ---------------------------------------------------
# The Maps SDK and the Flutter Maps plugin use reflection for renderer setup.
-keep class io.flutter.plugins.googlemaps.** { *; }
-keep class com.google.android.libraries.maps.** { *; }
-dontwarn com.google.android.libraries.maps.**

# ---- image_picker ----------------------------------------------------------
-keep class io.flutter.plugins.imagepicker.** { *; }

# ---- Play Core (deferred components / split installs) ----------------------
# Flutter's Gradle plugin references Play Core classes even when deferred
# components are unused; suppress the R8 warnings so the release build passes.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
