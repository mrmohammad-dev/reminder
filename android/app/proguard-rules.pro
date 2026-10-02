# flutter_local_notifications stores scheduled notifications with Gson;
# keep its model classes so scheduled reminders survive R8 in release.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-dontwarn com.google.errorprone.annotations.**

# App receivers / headless resync engine.
-keep class com.mohammad.reminder.** { *; }

# Flutter deferred components reference Play Core, which this app does not use.
-dontwarn com.google.android.play.core.**
