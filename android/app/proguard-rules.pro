# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Supabase / GoTrue / PostgREST
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# RevenueCat
-keep class com.revenuecat.purchases.** { *; }
-dontwarn com.revenuecat.purchases.**

# OkHttp (used by RevenueCat)
-dontwarn okhttp3.**
-dontwarn okio.**

# Gson (used by various plugins)
-keepattributes Signature
-keepattributes *Annotation*

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Keep Kotlin metadata
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**

# Google Play Core (deferred components)
-dontwarn com.google.android.play.core.**
