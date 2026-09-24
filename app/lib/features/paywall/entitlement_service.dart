import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/revenuecat_config.dart';

const _demoPremium = bool.fromEnvironment('BLOOM_PREMIUM_OVERRIDE');

class MembershipStatus {
  const MembershipStatus({
    this.isPremium = false,
    this.isTrial = false,
    this.willRenew = false,
    this.expirationDate,
    this.managementUrl,
    this.appUserId,
  });

  final bool isPremium;
  final bool isTrial;
  final bool willRenew;
  final DateTime? expirationDate;
  final String? managementUrl;
  final String? appUserId;
}

class MembershipPlan {
  const MembershipPlan({
    required this.packageId,
    required this.productId,
    required this.price,
    this.pricePerMonth,
    this.trialEligible = false,
  });

  final String packageId;
  final String productId;
  final String price;
  final String? pricePerMonth;
  final bool trialEligible;
}

class PurchaseCancelled implements Exception {}

abstract class EntitlementService {
  MembershipStatus get currentStatus;
  Stream<MembershipStatus> watchStatus();
  Future<List<MembershipPlan>> loadPlans();
  Future<MembershipStatus> purchase(MembershipPlan plan);
  Future<MembershipStatus> restore();
  Future<void> redeemCode();
  Future<MembershipStatus> refresh();
}

class RevenueCatEntitlementService implements EntitlementService {
  RevenueCatEntitlementService._();

  static final instance = RevenueCatEntitlementService._();

  final _updates = StreamController<MembershipStatus>.broadcast();
  MembershipStatus _status = const MembershipStatus();
  Future<void>? _configuration;
  String? _appUserId;
  final Map<String, Package> _packages = {};

  @override
  MembershipStatus get currentStatus => kDebugMode && _demoPremium
      ? MembershipStatus(isPremium: true, appUserId: _status.appUserId)
      : _status;

  Future<void> start(String? appUserId) => _configuration ??= _start(appUserId);

  Future<void> _start(String? appUserId) async {
    if (revenueCatAppleApiKey.isEmpty) return;
    try {
      final configuration = PurchasesConfiguration(revenueCatAppleApiKey)
        ..appUserID = appUserId;
      await Purchases.configure(configuration);
      _appUserId = await Purchases.appUserID;
      Purchases.addCustomerInfoUpdateListener(_receive);
      _receive(await Purchases.getCustomerInfo());
    } on Object {
      _configuration = null;
      // The store can be unavailable at launch. The paywall offers a retry.
    }
  }

  Future<void> identify(String appUserId) async {
    await start(null);
    if (revenueCatAppleApiKey.isEmpty) return;
    try {
      if (await Purchases.appUserID == appUserId) return;
      final info = (await Purchases.logIn(appUserId)).customerInfo;
      _appUserId = appUserId;
      _receive(info);
    } on Object {
      // A later auth event or store retry can recover this.
    }
  }

  void _receive(CustomerInfo info) {
    final entitlement = info.entitlements.active[revenueCatEntitlementId];
    _status = MembershipStatus(
      isPremium: entitlement?.isActive ?? false,
      isTrial: entitlement?.periodType == PeriodType.trial,
      willRenew: entitlement?.willRenew ?? false,
      expirationDate: DateTime.tryParse(entitlement?.expirationDate ?? ''),
      managementUrl: info.managementURL,
      appUserId: _appUserId ?? info.originalAppUserId,
    );
    _updates.add(currentStatus);
  }

  Future<void> _ready() async {
    await start(null);
    if (revenueCatAppleApiKey.isEmpty || !await Purchases.isConfigured) {
      throw StateError('Store unavailable');
    }
  }

  @override
  Stream<MembershipStatus> watchStatus() => Stream.multi((controller) {
    controller.add(currentStatus);
    final subscription = _updates.stream.listen(controller.add);
    controller.onCancel = subscription.cancel;
  });

  @override
  Future<List<MembershipPlan>> loadPlans() async {
    await _ready();
    final packages =
        (await Purchases.getOfferings()).current?.availablePackages ?? [];
    _packages.clear();
    for (final package in packages) {
      _packages[package.identifier] = package;
    }
    final annual = _packages[r'$rc_annual'];
    final monthly = _packages[r'$rc_monthly'];
    if (annual == null ||
        monthly == null ||
        annual.storeProduct.identifier != 'bloom_premium_annual' ||
        monthly.storeProduct.identifier != 'bloom_premium_monthly') {
      throw StateError('Plans unavailable');
    }
    bool eligible = false;
    try {
      final eligibility =
          await Purchases.checkTrialOrIntroductoryPriceEligibility([
            annual.storeProduct.identifier,
          ]);
      eligible =
          eligibility[annual.storeProduct.identifier]?.status ==
          IntroEligibilityStatus.introEligibilityStatusEligible;
    } on Object {
      // Unknown eligibility must not promise a trial.
    }
    return [
      MembershipPlan(
        packageId: annual.identifier,
        productId: annual.storeProduct.identifier,
        price: annual.storeProduct.priceString,
        pricePerMonth: annual.storeProduct.pricePerMonthString,
        trialEligible: eligible,
      ),
      MembershipPlan(
        packageId: monthly.identifier,
        productId: monthly.storeProduct.identifier,
        price: monthly.storeProduct.priceString,
      ),
    ];
  }

  @override
  Future<MembershipStatus> purchase(MembershipPlan plan) async {
    await _ready();
    final package = _packages[plan.packageId];
    if (package == null) throw StateError('Plan unavailable');
    try {
      _receive(
        (await Purchases.purchase(
          PurchaseParams.package(package),
        )).customerInfo,
      );
      return currentStatus;
    } on PlatformException catch (error) {
      if (PurchasesErrorHelper.getErrorCode(error) ==
          PurchasesErrorCode.purchaseCancelledError) {
        throw PurchaseCancelled();
      }
      rethrow;
    }
  }

  @override
  Future<MembershipStatus> restore() async {
    await _ready();
    _receive(await Purchases.restorePurchases());
    return currentStatus;
  }

  @override
  Future<void> redeemCode() async {
    await _ready();
    await Purchases.presentCodeRedemptionSheet();
  }

  @override
  Future<MembershipStatus> refresh() async {
    await _ready();
    await Purchases.invalidateCustomerInfoCache();
    _receive(await Purchases.getCustomerInfo());
    return currentStatus;
  }
}
