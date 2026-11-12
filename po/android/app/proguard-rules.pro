# ProGuard Rules for POS App Security & Anti-Tampering
-repackageclasses ''
-allowaccessmodification

-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

-assumenosideeffects class android.util.Log {
    public static int d(...);
    public static int v(...);
}

-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
