import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Handles Google's User Messaging Platform (UMP) consent flow.
///
/// The developer is based in Belgium (EEA), where GDPR and the Digital
/// Markets Act (DMA) — and AdMob's own EU User Consent policy — require
/// that a consent form be shown to EEA/UK users and fully resolved BEFORE
/// any ad is requested. [gatherConsent] MUST be awaited to completion
/// before `MobileAds.instance.initialize()` runs (see `AdsProvider.init()`
/// in `lib/ads/ads_provider.dart`) — this is not optional.
///
/// This class never throws: every failure path (network error, SDK error,
/// no form required) resolves the returned future normally, so a broken
/// consent flow can never block app startup.
///
/// ─────────────────────────────────────────────────────────────────────
/// Testing the EEA flow from Belgium:
/// Belgium is itself in the EEA, so a real device there already exercises
/// the EEA consent path — but Google also remembers your consent decision
/// after the first run, and you may want to test the non-EEA path too.
/// For deterministic, repeatable testing, pass a debug geography:
///
///   ConsentDebugSettings(
///     debugGeography: DebugGeography.debugGeographyEea, // or ...NotEea
///     testIdentifiers: ['<your test device's hashed ID>'],
///   )
///
/// The hashed test device ID is printed to the debug console the first
/// time `requestConsentInfoUpdate` runs on a real device — copy it from
/// there. [gatherConsent] below already wires `ConsentDebugSettings` in,
/// gated behind `kDebugMode` so it can never ship in a release build; add
/// your device's hashed ID to the `testIdentifiers` list while testing.
/// ─────────────────────────────────────────────────────────────────────
class ConsentManager {
  ConsentManager._();

  /// Requests the latest consent info from Google and shows the consent
  /// form if one is required for this user (typically EEA/UK). Always
  /// completes, even on failure — see class doc.
  static Future<void> gatherConsent() async {
    final completer = Completer<void>();

    final params = ConsentRequestParameters(
      consentDebugSettings: kDebugMode
          ? ConsentDebugSettings(
              debugGeography: DebugGeography.debugGeographyEea,
              // TODO: add your test device's hashed ID while testing, e.g.
              // testIdentifiers: ['33BE2250B43518CCDA7DE426D04EE231'].
              testIdentifiers: const [],
            )
          : null,
    );

    void finish() {
      if (!completer.isCompleted) completer.complete();
    }

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () {
          // Consent info updated successfully; show the form if required.
          try {
            ConsentForm.loadAndShowConsentFormIfRequired((FormError? formError) {
              if (formError != null) {
                debugPrint(
                  'ConsentManager: consent form dismissed with error '
                  '${formError.errorCode}: ${formError.message}',
                );
              }
              finish();
            });
          } catch (e) {
            debugPrint('ConsentManager: loadAndShowConsentFormIfRequired threw: $e');
            finish();
          }
        },
        (FormError error) {
          debugPrint(
            'ConsentManager: requestConsentInfoUpdate failed '
            '${error.errorCode}: ${error.message}',
          );
          finish();
        },
      );
    } catch (e) {
      debugPrint('ConsentManager: gatherConsent() threw: $e');
      finish();
    }

    return completer.future;
  }

  /// Whether the app currently has permission to request ads, per the
  /// latest consent decision (false while an EEA consent form is still
  /// outstanding, or the SDK isn't ready). Call after [gatherConsent].
  static Future<bool> canRequestAds() async {
    try {
      return await ConsentInformation.instance.canRequestAds();
    } catch (e) {
      debugPrint('ConsentManager: canRequestAds() failed: $e');
      return false;
    }
  }
}
