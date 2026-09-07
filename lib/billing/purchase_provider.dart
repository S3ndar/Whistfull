import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:whistly/ads/ad_config.dart';
import 'package:whistly/ads/ads_provider.dart';

/// Owns the single "Remove ads" non-consumable in-app purchase.
///
/// The `adsRemoved` entitlement is persisted in the SAME `'settings_box'`
/// Hive box used by `ScoringSettings` / `ThemeProvider` /
/// `LocalizationProvider`, under the key `'ads_removed'` — so it survives
/// restarts even before the store round-trip in [init] completes.
///
/// Wiring to `AdsProvider`: this provider is handed the app's single
/// `AdsProvider` instance (see `lib/main.dart`) and calls
/// [AdsProvider.setAdsRemoved] every time the entitlement changes. See
/// `lib/main.dart` for why a direct setter call was chosen over
/// `ChangeNotifierProxyProvider`.
class PurchaseProvider extends ChangeNotifier {
  static const String _boxName = 'settings_box';
  static const String _adsRemovedKey = 'ads_removed';

  final AdsProvider? _adsProvider;

  PurchaseProvider({AdsProvider? adsProvider}) : _adsProvider = adsProvider;

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// Whether the store is reachable at all on this device.
  bool available = false;

  /// The persisted / confirmed entitlement.
  bool adsRemoved = false;

  /// True while a buy/restore round-trip is in flight, so the UI can
  /// disable the button and show a spinner instead of double-submitting.
  bool purchasePending = false;

  /// Localization key (e.g. 'purchase_failed', 'purchase_restored',
  /// 'purchase_unavailable') for the last event the UI should surface,
  /// or null. The UI is expected to translate it, show it once, then
  /// call [clearMessage].
  String? lastMessageKey;

  ProductDetails? _removeAdsProduct;
  ProductDetails? get removeAdsProduct => _removeAdsProduct;

  Future<void> init() async {
    // Read the persisted entitlement first so the UI is correct
    // immediately, even before (or if) the store round-trip below
    // succeeds.
    try {
      final box = await Hive.openBox(_boxName);
      adsRemoved = box.get(_adsRemovedKey, defaultValue: false) as bool;
    } catch (e) {
      debugPrint('PurchaseProvider: failed reading "$_adsRemovedKey" from Hive: $e');
    }
    _adsProvider?.setAdsRemoved(adsRemoved);

    try {
      available = await _iap.isAvailable();
    } catch (e) {
      debugPrint('PurchaseProvider: isAvailable() threw: $e');
      available = false;
    }

    if (!available) {
      notifyListeners();
      return;
    }

    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (Object e) => debugPrint('PurchaseProvider: purchaseStream error: $e'),
    );

    try {
      final response = await _iap.queryProductDetails({AdConfig.removeAdsProductId});
      if (response.error != null) {
        debugPrint('PurchaseProvider: queryProductDetails error: ${response.error}');
      }
      if (response.productDetails.isNotEmpty) {
        _removeAdsProduct = response.productDetails.first;
      }
    } catch (e) {
      debugPrint('PurchaseProvider: queryProductDetails threw: $e');
    }

    // Restore any prior entitlement (reinstalls, new devices) — results
    // arrive asynchronously via purchaseStream / _handlePurchase below.
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('PurchaseProvider: restorePurchases() during init threw: $e');
    }

    notifyListeners();
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      _handlePurchase(purchase);
    }
  }

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    if (purchase.productID == AdConfig.removeAdsProductId) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          purchasePending = true;
          notifyListeners();
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          purchasePending = false;
          await _setEntitlement(true);
          lastMessageKey = purchase.status == PurchaseStatus.restored
              ? 'purchase_restored'
              : null;
          notifyListeners();
          break;
        case PurchaseStatus.error:
          purchasePending = false;
          debugPrint('PurchaseProvider: purchase error: ${purchase.error}');
          lastMessageKey = 'purchase_failed';
          notifyListeners();
          break;
        case PurchaseStatus.canceled:
          purchasePending = false;
          notifyListeners();
          break;
      }
    }

    if (purchase.pendingCompletePurchase) {
      try {
        await _iap.completePurchase(purchase);
      } catch (e) {
        // completePurchase() can throw (e.g. PurchaseException) if the
        // platform fails to finish the transaction. Swallow it here —
        // like every other store call in this class — rather than
        // crashing the purchaseStream listener; an unfinished iOS
        // transaction is simply retried by the platform on next launch.
        debugPrint('PurchaseProvider: completePurchase() threw: $e');
      }
    }
  }

  Future<void> _setEntitlement(bool removed) async {
    adsRemoved = removed;
    _adsProvider?.setAdsRemoved(removed);
    try {
      final box = await Hive.openBox(_boxName);
      await box.put(_adsRemovedKey, removed);
    } catch (e) {
      debugPrint('PurchaseProvider: failed persisting "$_adsRemovedKey": $e');
    }
  }

  Future<void> buyRemoveAds() async {
    if (adsRemoved || purchasePending) return;

    final product = _removeAdsProduct;
    if (!available || product == null) {
      lastMessageKey = 'purchase_unavailable';
      notifyListeners();
      return;
    }

    final param = PurchaseParam(productDetails: product);
    try {
      purchasePending = true;
      notifyListeners();
      final started = await _iap.buyNonConsumable(purchaseParam: param);
      if (!started) {
        purchasePending = false;
        lastMessageKey = 'purchase_failed';
        notifyListeners();
      }
      // On success, the purchaseStream listener above drives the rest.
    } catch (e) {
      debugPrint('PurchaseProvider: buyNonConsumable() threw: $e');
      purchasePending = false;
      lastMessageKey = 'purchase_failed';
      notifyListeners();
    }
  }

  /// Apple requires a visible, always-available Restore Purchases
  /// control — see `lib/settings_page.dart`.
  Future<void> restorePurchases() async {
    if (!available) {
      lastMessageKey = 'purchase_unavailable';
      notifyListeners();
      return;
    }
    try {
      purchasePending = true;
      notifyListeners();
      await _iap.restorePurchases();
      // Result (restored / nothing to restore) arrives via purchaseStream.
    } catch (e) {
      debugPrint('PurchaseProvider: restorePurchases() threw: $e');
      lastMessageKey = 'purchase_failed';
    } finally {
      purchasePending = false;
      notifyListeners();
    }
  }

  /// Clears the one-shot message the UI just displayed.
  void clearMessage() {
    lastMessageKey = null;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
