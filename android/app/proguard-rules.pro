# Flutter & Android Obfuscation and Hardening Rules

# Keep Flutter base classes and engine entry points
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep native MethodChannel interactions in MainActivity
-keep class com.example.pos.MainActivity { *; }

# Strip out all debug logging in the final compiled production binary
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
}

# Keep necessary type signatures and annotations
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Keep Hive database models intact to prevent serialization bugs
-keep class io.hive.** { *; }
-keep class com.example.pos.domain.models.** { *; }

# Ignore warnings about missing classes from deferred components or external packages
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
-dontwarn com.google.android.play.core.**
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn sun.misc.Unsafe
-dontwarn sun.security.action.GetPropertyAction
