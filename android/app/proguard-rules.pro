# Flutter-safe ProGuard/R8 keep rules.
#
# Keep the Flutter embedding and generated plugin registrant intact; without
# this, isMinifyEnabled release builds can crash at startup with
# ClassNotFoundException / MissingPluginException.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# Google Mobile Ads (AdMob) — keep the SDK's classes intact under R8.
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# Google Play Billing (used by the `in_app_purchase` plugin on Android) —
# keep the billing client classes intact under R8.
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**
