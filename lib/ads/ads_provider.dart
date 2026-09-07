import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive/hive.dart';

import 'package:whistly/ads/ad_config.dart';
import 'package:whistly/ads/consent_manager.dart';

/// Owns all ad-related state: SDK initialisation (behind GDPR/UMP
/// consent), and interstitial preloading/showing with frequency caps.
///
/// `adsRemoved` mirrors the `'ads_removed'` flag in the shared
/// `'settings_box'` Hive box (the same box `ScoringSettings`,
/// `ThemeProvider` and `LocalizationProvider` use). It is read directly
/// from that box in [init] so this provider knows the correct value from
/// app start even before `PurchaseProvider` finishes querying the store —
/// and `PurchaseProvider` calls [setAdsRemoved] whenever the entitlement
/// changes (purchase, restore) to keep this provider's copy live. See
/// `lib/main.dart` for why this simple "shared key + setter" approach was
/// chosen over `ChangeNotifierProxyProvider`.
class AdsProvider extends ChangeNotifier {
  static const String _boxName = 'settings_box';
  static const String _adsRemovedKey = 'ads_removed';

  // ─── Interstitial frequency caps ───────────────────────────────────
  static const int _maxSessionShows = 3;
  static const Duration _minGapBetweenShows = Duration(minutes: 3);

  bool adsRemoved = false;
  bool initialized = false;

  InterstitialAd? _interstitialAd;
  bool _interstitialLoading = false;
  int _sessionShowCount = 0;
  DateTime? _lastShownAt;
  final Set<String> _shownForGameIds = {};

  bool get _adsSupportedOnThisPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Reads the persisted entitlement, then — unless ads are already
  /// removed or the platform doesn't support mobile ads — runs the UMP
  /// consent flow to completion before initialising the Mobile Ads SDK.
  Future<void> init() async {
    try {
      final box = await Hive.openBox(_boxName);
      adsRemoved = box.get(_adsRemovedKey, defaultValue: false) as bool;
    } catch (e) {
      debugPrint('AdsProvider: failed reading "$_adsRemovedKey" from Hive: $e');
    }

    if (!_adsSupportedOnThisPlatform) {
      // Desktop/web builds never touch the ads SDK.
      return;
    }

    if (adsRemoved) {
      // Paying users: skip the consent prompt and the SDK entirely —
      // there is nothing to request ads for.
      initialized = true;
      notifyListeners();
      return;
    }

    // GDPR/DMA (Belgium is in the EEA) + AdMob policy: consent MUST be
    // gathered and resolved before the SDK is initialised.
    await ConsentManager.gatherConsent();

    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint('AdsProvider: MobileAds.instance.initialize() failed: $e');
    }

    initialized = true;
    notifyListeners();
    preloadInterstitial();
  }

  /// Called by `PurchaseProvider` whenever the "Remove ads" entitlement
  /// changes (purchase completed, or restored on a new device).
  void setAdsRemoved(bool value) {
    if (adsRemoved == value) return;
    adsRemoved = value;
    if (value) {
      _interstitialAd?.dispose();
      _interstitialAd = null;
    }
    notifyListeners();
  }

  /// Loads an interstitial ahead of time so [maybeShowInterstitial] never
  /// has to block on a network round-trip. Safe to call repeatedly — it
  /// no-ops while a load is already in flight, an ad is already cached,
  /// ads are removed, or the session cap has been reached.
  void preloadInterstitial() {
    if (adsRemoved || !_adsSupportedOnThisPlatform) return;
    if (_interstitialAd != null || _interstitialLoading) return;
    if (_sessionShowCount >= _maxSessionShows) return;

    _interstitialLoading = true;
    InterstitialAd.load(
      adUnitId: AdConfig.interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialLoading = false;
        },
        onAdFailedToLoad: (error) {
          _interstitialLoading = false;
          debugPrint('AdsProvider: interstitial failed to load: $error');
        },
      ),
    );
  }

  /// Shows a preloaded interstitial if — and only if — every cap below
  /// allows it:
  ///  - ads have not been removed (purchased);
  ///  - at most one interstitial per completed game (pass the game's
  ///    unique [gameId] and it is tracked so a duplicate call for the
  ///    same game is a no-op);
  ///  - at most [_maxSessionShows] interstitials shown per app session;
  ///  - at least [_minGapBetweenShows] since the last one shown.
  /// Never blocks the caller waiting for a network load — if nothing is
  /// preloaded yet, this simply kicks off a preload for next time and
  /// returns, so a slow/failed ad never traps the UI.
  Future<void> maybeShowInterstitial({String? gameId}) async {
    if (adsRemoved || !_adsSupportedOnThisPlatform) return;
    if (gameId != null && _shownForGameIds.contains(gameId)) return;
    if (_sessionShowCount >= _maxSessionShows) return;

    final now = DateTime.now();
    if (_lastShownAt != null && now.difference(_lastShownAt!) < _minGapBetweenShows) {
      return;
    }

    final ad = _interstitialAd;
    if (ad == null) {
      // Nothing preloaded — never stall the caller. Kick off a preload
      // for the next opportunity and bail out silently.
      preloadInterstitial();
      return;
    }

    _interstitialAd = null; // consumed — a shown ad can't be reused.
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (dismissedAd) {
        dismissedAd.dispose();
        preloadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (failedAd, error) {
        debugPrint('AdsProvider: interstitial failed to show: $error');
        failedAd.dispose();
        preloadInterstitial();
      },
    );

    try {
      await ad.show();
      _sessionShowCount++;
      _lastShownAt = now;
      if (gameId != null) _shownForGameIds.add(gameId);
    } catch (e) {
      debugPrint('AdsProvider: ad.show() threw: $e');
      ad.dispose();
      preloadInterstitial();
    }
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    super.dispose();
  }
}
