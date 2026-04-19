## Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

## Supabase / GoTrue / Realtime (uses reflection for JSON)
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

## SQLite (drift / sqlite3_flutter_libs)
-keep class eu.simonbinder.** { *; }
-keep class com.aspect.** { *; }

## Keep annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
