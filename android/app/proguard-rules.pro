# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Jitsi Meet SDK & React Native
-keep class org.jitsi.meet.** { *; }
-keep class org.jitsi.meet.sdk.** { *; }
-keep class com.facebook.react.** { *; }
-dontwarn org.jitsi.meet.sdk.**
-dontwarn com.facebook.react.**

# Firebase & Google Play Services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Alarm & Notifications
-keep class dev.fluttercommunity.plus.androidalarmmanager.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class xyz.aliman.alarm.** { *; }

# Audio & Speech
-keep class xyz.luan.audioplayers.** { *; }
-keep class com.csdcorp.speech_to_text.** { *; }
-keep class com.llfbandit.record.** { *; }

# General Serialization / Reflection
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-dontwarn okhttp3.**
-dontwarn okio.**
