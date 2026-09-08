import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;

/// Single source of truth for every AdMob ad unit ID and app ID used by
/// Whistly, plus the in-app-purchase product ID for "Remove ads".
///
/// ─────────────────────────────────────────────────────────────────────
/// TODO (BEFORE RELEASE): Flip [useTestAds] to `false` AND replace every
/// `_prod*` placeholder below with the REAL ad unit IDs created in the
/// AdMob console for the real, final `applicationId` (see the TODOs in
/// android/app/build.gradle.kts — this must happen after that ID is
/// finalised, since AdMob app/unit IDs are tied to the store listing).
/// Shipping with `useTestAds = true` serves only Google's test creative
/// and earns no revenue; shipping with it `false` and empty prod IDs will
/// crash ad loading or return "no fill" errors.
/// ─────────────────────────────────────────────────────────────────────
class AdConfig {
  AdConfig._();

  // TODO (BEFORE RELEASE): set this to false once real IDs are filled in
  // below and the app is ready to serve live ads.
  static const bool useTestAds = true;

  // ─── Google's official test ad unit IDs (safe to ship while testing;
  //     these always fill with Google's test creative and are never
  //     billed) ──────────────────────────────────────────────────────
  static const String _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testBannerIOS = 'ca-app-pub-3940256099942544/2934735716';
  static const String _testInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testInterstitialIOS = 'ca-app-pub-3940256099942544/4411468910';

  // Test AdMob APPLICATION ids (used in AndroidManifest.xml / Info.plist,
  // documented here for reference — NOT read by this class):
  //   Android: ca-app-pub-3940256099942544~3347511713
  //   iOS:     ca-app-pub-3940256099942544~1458002511

  // ─── Real production ad unit IDs ───────────────────────────────────
  // TODO (BEFORE RELEASE): fill these in from the AdMob console once the
  // app is registered under its final applicationId / bundle ID.
  static const String _prodBannerAndroid = ''; // TODO: real Android banner unit ID
  static const String _prodBannerIOS = ''; // TODO: real iOS banner unit ID
  static const String _prodInterstitialAndroid = ''; // TODO: real Android interstitial unit ID
  static const String _prodInterstitialIOS = ''; // TODO: real iOS interstitial unit ID

  /// Banner ad unit ID for the current platform.
  ///
  /// Callers MUST guard with a platform check (see `AdsProvider` /
  /// `AdaptiveBannerAd`'s `_supportedPlatform`) before touching this —
  /// AdMob has no plugin support outside Android/iOS, so this throws on
  /// anything else. Uses `defaultTargetPlatform` rather than `dart:io`'s
  /// `Platform` so this file (and anything importing it) stays compilable
  /// on `flutter build web`, which cannot import `dart:io` at all.
  static String get bannerUnitId {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return useTestAds ? _testBannerAndroid : _prodBannerAndroid;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return useTestAds ? _testBannerIOS : _prodBannerIOS;
    }
    throw UnsupportedError('AdConfig.bannerUnitId is only available on Android and iOS.');
  }

  /// Interstitial ad unit ID for the current platform. Same guarding
  /// requirement as [bannerUnitId].
  static String get interstitialUnitId {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return useTestAds ? _testInterstitialAndroid : _prodInterstitialAndroid;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return useTestAds ? _testInterstitialIOS : _prodInterstitialIOS;
    }
    throw UnsupportedError('AdConfig.interstitialUnitId is only available on Android and iOS.');
  }

  /// Non-consumable in-app-purchase product id for "Remove ads". Must
  /// match the product created in the Play Console / App Store Connect.
  static const String removeAdsProductId = 'whistly_remove_ads';
}
