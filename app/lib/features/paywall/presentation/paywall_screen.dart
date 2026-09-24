import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_sizes.dart';
import '../../plan/domain/plan_presentation.dart';
import '../entitlement_service.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _entrance = AnimationController(vsync: this);
  List<MembershipPlan>? _plans;
  String _selected = r'$rc_annual';
  String? _message;
  bool _busy = false;
  bool _storeUnavailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _entrance.duration = AppMotion.duration(context, AppMotion.entrance);
      _entrance.forward();
    });
    ref.read(appEventsLoggerProvider).paywallViewed();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _plans = null;
      _message = null;
      _storeUnavailable = false;
    });
    try {
      final plans = await ref.read(entitlementServiceProvider).loadPlans();
      if (!mounted) return;
      setState(() => _plans = plans);
    } on Object {
      if (!mounted) return;
      setState(() => _storeUnavailable = true);
    }
  }

  Future<void> _purchase() async {
    if (_busy || _plans == null) return;
    final plan = _plans!.firstWhere((plan) => plan.packageId == _selected);
    setState(() {
      _busy = true;
      _message = null;
    });
    final logger = ref.read(appEventsLoggerProvider);
    final memberships = ref.read(entitlementServiceProvider);
    logger.purchaseStarted(plan.productId);
    try {
      final status = await memberships.purchase(plan);
      if (!status.isPremium) throw StateError('No entitlement');
      logger.purchaseCompleted(plan.productId, trial: status.isTrial);
      unawaited(HapticFeedback.lightImpact());
      if (mounted) context.go('/today');
    } on PurchaseCancelled {
      logger.purchaseCancelled();
    } on Object {
      if (mounted) {
        setState(() => _message = 'That did not go through. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    ref.read(appEventsLoggerProvider).restoreTapped();
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final status = await ref.read(entitlementServiceProvider).restore();
      if (!mounted) return;
      if (status.isPremium) {
        context.go('/today');
      } else {
        setState(() => _message = 'No active membership found yet.');
      }
    } on Object {
      if (mounted) {
        setState(() => _message = 'Could not restore right now. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _redeem() async {
    if (_busy) return;
    ref.read(appEventsLoggerProvider).redeemCodeTapped();
    try {
      await ref.read(entitlementServiceProvider).redeemCode();
      if (!mounted) return;
      final status = await ref.read(entitlementServiceProvider).refresh();
      if (mounted && status.isPremium) context.go('/today');
    } on Object {
      if (mounted) {
        setState(() => _message = 'Could not open codes right now. Try again.');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref
          .read(entitlementServiceProvider)
          .refresh()
          .then((status) {
            if (mounted && status.isPremium) context.go('/today');
          })
          .catchError((Object _) {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final answers = ref.watch(onboardingAnswersProvider).value;
    final plans = _plans;
    final selected = plans?.firstWhere((plan) => plan.packageId == _selected);
    return Scaffold(
      key: const ValueKey('paywall-screen'),
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _appear(
                    0,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DecoratedBox(
                          decoration: const BoxDecoration(
                            color: AppColors.blushSoft,
                            borderRadius: AppRadii.largeBorder,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs,
                            ),
                            child: Text(
                              'Made for you',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: AppColors.roseDeep),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Your plan is ready.',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          answers == null
                              ? 'Your Bloom plan'
                              : PlanPresentation.planName(answers),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: AppColors.roseDeep),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _appear(
                    1,
                    Column(
                      children: const [
                        _Benefit(
                          icon: Icons.fitness_center_rounded,
                          text: 'Every weight chosen for you',
                        ),
                        _Benefit(
                          icon: Icons.swap_horiz_rounded,
                          text: 'A swap for every busy machine',
                        ),
                        _Benefit(
                          icon: Icons.auto_awesome_rounded,
                          text: 'A plan that adjusts each week',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (selected?.trialEligible == true)
                    _appear(2, const _TrialTimeline())
                  else if (plans != null)
                    _appear(
                      2,
                      const _Benefit(
                        icon: Icons.lock_open_rounded,
                        text: 'Your full plan unlocks today',
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  if (plans == null && !_storeUnavailable)
                    const _PlanSkeleton()
                  else if (_storeUnavailable)
                    _StoreUnavailable(onRetry: _load)
                  else ...[
                    for (final plan in plans!)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _PlanCard(
                          plan: plan,
                          selected: _selected == plan.packageId,
                          onTap: () =>
                              setState(() => _selected = plan.packageId),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    AppPressScale(
                      enabled: !_busy,
                      child: FilledButton(
                        key: const ValueKey('paywall-purchase'),
                        onPressed: _busy ? null : _purchase,
                        child: Text(
                          _busy
                              ? 'One moment...'
                              : selected?.trialEligible == true
                              ? 'Start my free week'
                              : 'Continue',
                        ),
                      ),
                    ),
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                          _message!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.inkSoft),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      selected?.trialEligible == true
                          ? '7 days free, then ${selected!.price} per year. Auto-renews until cancelled. Cancel anytime in Settings at least 24 hours before renewal.'
                          : '${selected?.price ?? ''} per ${_selected == r'$rc_annual' ? 'year' : 'month'}. Auto-renews until cancelled. Cancel anytime in Settings at least 24 hours before renewal.',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.xs,
                    children: [
                      TextButton(
                        onPressed: _busy ? null : _restore,
                        child: const Text('Restore purchases'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _redeem,
                        child: const Text('Redeem a code'),
                      ),
                    ],
                  ),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.xs,
                    children: [
                      TextButton(
                        onPressed: () => _open(
                          'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
                        ),
                        child: const Text('Terms of Use'),
                      ),
                      TextButton(
                        onPressed: () => _open(
                          'https://womensgym.github.io/bloom-site/privacy.html',
                        ),
                        child: const Text('Privacy'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _appear(int index, Widget child) => AnimatedBuilder(
    animation: _entrance,
    child: child,
    builder: (context, child) {
      final value = Curves.easeOut.transform(
        ((_entrance.value - index * 0.13) / 0.74).clamp(0.0, 1.0),
      );
      return Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: child,
        ),
      );
    },
  );
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: AppColors.blushSoft,
          child: Icon(
            icon,
            color: AppColors.roseDeep,
            size: AppSizes.iconMedium,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    ),
  );
}

class _TrialTimeline extends StatelessWidget {
  const _TrialTimeline();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: const BoxDecoration(
      color: AppColors.paper,
      borderRadius: AppRadii.mediumBorder,
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Today · full plan unlocked'),
        SizedBox(height: AppSpacing.sm),
        Text('Day 7 · first payment, unless you cancel'),
      ],
    ),
  );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });
  final MembershipPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final annual = plan.packageId == r'$rc_annual';
    return AnimatedContainer(
      key: ValueKey('paywall-plan-${plan.packageId}'),
      duration: AppMotion.duration(context, AppMotion.state),
      curve: AppMotion.standardCurve,
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: AppRadii.mediumBorder,
        border: Border.all(
          color: selected ? AppColors.rose : AppColors.line,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.mediumBorder,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.roseDeep : AppColors.inkFaint,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      annual ? 'Yearly' : 'Monthly',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (annual && plan.trialEligible)
                      const Text(
                        '7 days free',
                        style: TextStyle(
                          color: AppColors.roseDeep,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (annual && plan.pricePerMonth != null)
                      Text(
                        '${plan.pricePerMonth} per month',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${plan.price}/${annual ? 'yr' : 'mo'}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanSkeleton extends StatelessWidget {
  const _PlanSkeleton();
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < 2; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Container(
            height: 84,
            decoration: const BoxDecoration(
              color: AppColors.blushSoft,
              borderRadius: AppRadii.mediumBorder,
            ),
          ),
        ),
      const Text(
        'Finding your plans...',
        style: TextStyle(color: AppColors.inkSoft),
      ),
    ],
  );
}

class _StoreUnavailable extends StatelessWidget {
  const _StoreUnavailable({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: const BoxDecoration(
      color: AppColors.paper,
      borderRadius: AppRadii.mediumBorder,
    ),
    child: Column(
      children: [
        const Text(
          'The store is unavailable right now. Please try again.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}

Future<void> _open(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } on Object {
    // External links can fail while offline.
  }
}
