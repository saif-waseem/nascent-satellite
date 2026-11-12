# ProGuard Rules for User Store App
-repackageclasses ''
-allowaccessmodification

-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Fix R8 missing class warnings for Google Play Core (used by Flutter deferred components)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
