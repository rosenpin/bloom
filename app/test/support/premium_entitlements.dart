import 'package:womens_gym/features/paywall/entitlement_service.dart';

class PremiumEntitlements implements EntitlementService {
  const PremiumEntitlements();

  static const _status = MembershipStatus(isPremium: true);

  @override
  MembershipStatus get currentStatus => _status;

  @override
  Stream<MembershipStatus> watchStatus() => Stream.value(_status);

  @override
  Future<List<MembershipPlan>> loadPlans() => throw UnimplementedError();

  @override
  Future<MembershipStatus> purchase(MembershipPlan plan) =>
      throw UnimplementedError();

  @override
  Future<MembershipStatus> restore() => throw UnimplementedError();

  @override
  Future<void> redeemCode() => throw UnimplementedError();

  @override
  Future<MembershipStatus> refresh() async => _status;
}
