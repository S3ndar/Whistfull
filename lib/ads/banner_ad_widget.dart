import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import 'package:whistly/ads/ad_config.dart';
import 'package:whistly/ads/ads_provider.dart';

/// A full-width, orientation-anchored adaptive banner ad.
///
/// - Collapses to nothing (`SizedBox.shrink`) when ads are removed
///   (purchased), on a platform other than Android/iOS, or if the ad
///   failed to load — so it never leaves a dead grey box on screen.
/// - Reserves its final height as soon as the adaptive ad SIZE is known
///   (which is a quick local calculation, not a network round-trip),
///   before the actual ad creative has loaded — so the surrounding
///   layout never jumps once the ad appears.
/// - Loads exactly once, in [didChangeDependencies] (the earliest point
///   `MediaQuery` is available to a State).
class AdaptiveBannerAd extends StatefulWidget {
  /// Optional: fired whenever the height this widget reserves changes
  /// (a resolved adaptive size, or back to 0 when removed/unsupported/
  /// failed). Useful for a caller that needs to know the ad's height for
  /// some reason other than plain layout flow — e.g. a floating control
  /// positioned relative to it. Every current screen just places this
  /// widget as a normal, last-in-column child instead, so none of them
  /// pass this.
  final ValueChanged<double>? onHeightChanged;

  const AdaptiveBannerAd({super.key, this.onHeightChanged});

  @override
  State<AdaptiveBannerAd> createState() => _AdaptiveBannerAdState();
}

class _AdaptiveBannerAdState extends State<AdaptiveBannerAd> {
  BannerAd? _bannerAd;
  AdSize? _adSize;
  bool _failedToLoad = false;
  bool _requestedLoad = false;

  // kIsWeb is still checked explicitly: on Flutter web, defaultTargetPlatform
  // is derived from the browser's user agent, so it can report android/iOS
  // for a mobile browser even though google_mobile_ads has no web plugin at
  // all — kIsWeb rules that case out regardless of the underlying OS.
  bool get _supportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedLoad) return; // load exactly once per widget lifetime
    final adsRemoved = context.read<AdsProvider>().adsRemoved;
    if (!_supportedPlatform || adsRemoved) return;
    _requestedLoad = true;
    _loadAd();
  }

  Future<void> _loadAd() async {
    final width = MediaQuery.sizeOf(context).width.truncate();
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    if (!mounted) return;

    if (size == null) {
      setState(() => _failedToLoad = true);
      widget.onHeightChanged?.call(0);
      return;
    }

    // Reserve the correct height immediately — before the ad creative
    // itself has loaded — so nothing shifts later.
    setState(() => _adSize = size);
    widget.onHeightChanged?.call(size.height.toDouble());

    final ad = BannerAd(
      adUnitId: AdConfig.bannerUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (loadedAd) {
          if (!mounted) {
            loadedAd.dispose();
            return;
          }
          setState(() => _bannerAd = loadedAd as BannerAd);
        },
        onAdFailedToLoad: (failedAd, error) {
          debugPrint('AdaptiveBannerAd: failed to load: $error');
          failedAd.dispose();
          if (!mounted) return;
          setState(() {
            _failedToLoad = true;
            _adSize = null;
          });
          widget.onHeightChanged?.call(0);
        },
      ),
    );

    await ad.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adsRemoved = context.watch<AdsProvider>().adsRemoved;

    if (adsRemoved || !_supportedPlatform || _failedToLoad) {
      return const SizedBox.shrink();
    }

    final size = _adSize;
    if (size == null) {
      // Ad size not resolved yet (first frame or two) — reserve a
      // sensible default so nothing else jumps while we wait.
      return const SizedBox(height: 50, width: double.infinity);
    }

    final ad = _bannerAd;
    return SizedBox(
      width: size.width.toDouble(),
      height: size.height.toDouble(),
      child: ad == null ? const SizedBox.shrink() : AdWidget(ad: ad),
    );
  }
}
