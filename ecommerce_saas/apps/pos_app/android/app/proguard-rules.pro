# ProGuard Rules for POS App
# Protects against reverse engineering & fixes R8 missing class warnings

-repackageclasses ''
-allowaccessmodification

# Keep native Flutter engine interfaces
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Strip out debug log strings and sensitive prints in production APK/AAB
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
    public static int w(...);
}

# Keep Supabase / HTTP Models
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
-dontwarn okhttp3.**
-dontwarn okio.**

# Fix R8 missing class warnings for Google Play Core
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
