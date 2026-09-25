import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/history/presentation/session_summary_screen.dart';
import '../../features/onboarding/presentation/onboarding_screens.dart';
import '../../features/paywall/presentation/paywall_screen.dart';
import '../../features/plan/presentation/plan_day_detail_screen.dart';
import '../../features/plan/presentation/plan_reveal_screen.dart';
import '../../features/session/presentation/session_player_screen.dart';
import '../../features/tabs/presentation/me_screen.dart';
import '../../features/tabs/presentation/plan_screen.dart';
import '../../features/tabs/presentation/today_screen.dart';
import '../providers.dart';
import '../theme/app_motion.dart';

part 'app_router.g.dart';

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final onboardingRepository = ref.watch(onboardingRepositoryProvider);
  final memberships = ref.watch(entitlementServiceProvider);
  final router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      final location = state.matchedLocation;
      if (location.startsWith('/onboarding')) return null;

      final completed = await onboardingRepository.hasCompletedProfile();
      if (completed) await memberships.whenReady();
      if (location == '/paywall' && !completed) return '/onboarding';
      if (location == '/paywall' && memberships.currentStatus.isPremium) {
        return '/today';
      }
      if (location == '/') {
        return completed
            ? (memberships.currentStatus.isPremium ? '/today' : '/paywall')
            : '/onboarding';
      }
      if (!completed &&
          (location == '/today' ||
              location == '/plan' ||
              location == '/me' ||
              location == '/session' ||
              location.startsWith('/history/') ||
              location.startsWith('/plan/day/'))) {
        return '/onboarding';
      }
      if (completed &&
          !memberships.currentStatus.isPremium &&
          (location == '/today' ||
              location == '/plan' ||
              location == '/me' ||
              location == '/session' ||
              location.startsWith('/history/') ||
              location.startsWith('/plan/day/'))) {
        return '/paywall';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) =>
            _softPage(context, state, const SizedBox.shrink()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) =>
            _onboardingPage(context, state, const WelcomeScreen()),
      ),
      GoRoute(
        path: '/onboarding/age',
        pageBuilder: (context, state) =>
            _onboardingPage(context, state, const AgeScreen()),
      ),
      GoRoute(
        path: '/onboarding/goal',
        pageBuilder: (context, state) =>
            _onboardingPage(context, state, const GoalScreen()),
      ),
      GoRoute(
        path: '/onboarding/days',
        pageBuilder: (context, state) =>
            _onboardingPage(context, state, const DaysScreen()),
      ),
      GoRoute(
        path: '/onboarding/session-length',
        pageBuilder: (context, state) =>
            _onboardingPage(context, state, const SessionLengthScreen()),
      ),
      GoRoute(
        path: '/onboarding/experience',
        pageBuilder: (context, state) =>
            _onboardingPage(context, state, const ExperienceScreen()),
      ),
      GoRoute(
        path: '/onboarding/comfort',
        pageBuilder: (context, state) =>
            _onboardingPage(context, state, const ComfortScreen()),
      ),
      GoRoute(
        path: '/onboarding/emphasis',
        pageBuilder: (context, state) =>
            _onboardingPage(context, state, const EmphasisScreen()),
      ),
      GoRoute(
        path: '/onboarding/activities',
        pageBuilder: (context, state) =>
            _onboardingPage(context, state, const ActivitiesScreen()),
      ),
      GoRoute(
        path: '/onboarding/menstrual',
        pageBuilder: (context, state) =>
            _onboardingPage(context, state, const MenstrualScreen()),
      ),
      GoRoute(
        path: '/onboarding/generating',
        pageBuilder: (context, state) =>
            _softPage(context, state, const GeneratingScreen()),
      ),
      GoRoute(
        path: '/onboarding/reveal',
        pageBuilder: (context, state) =>
            _softPage(context, state, const PlanRevealScreen()),
      ),
      GoRoute(
        path: '/paywall',
        pageBuilder: (context, state) =>
            _softPage(context, state, const PaywallScreen()),
      ),
      GoRoute(
        path: '/session',
        pageBuilder: (context, state) =>
            _takeoverPage(context, state, const SessionPlayerScreen()),
      ),
      GoRoute(
        path: '/history/session/:id',
        pageBuilder: (context, state) => _detailPage(
          context,
          state,
          SessionSummaryScreen(sessionId: state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/plan/day/:dayIndex',
        pageBuilder: (context, state) => _detailPage(
          context,
          state,
          PlanDayDetailScreen(
            dayIndex:
                int.tryParse(state.pathParameters['dayIndex'] ?? '') ?? -1,
          ),
        ),
      ),
      StatefulShellRoute.indexedStack(
        pageBuilder: (context, state, navigationShell) => _softPage(
          context,
          state,
          _AppShell(navigationShell: navigationShell),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/today',
                pageBuilder: (context, state) =>
                    _softPage(context, state, const TodayScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/plan',
                pageBuilder: (context, state) =>
                    _softPage(context, state, const PlanScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/me',
                pageBuilder: (context, state) =>
                    _softPage(context, state, const MeScreen()),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  final subscription = memberships.watchStatus().listen(
    (_) => router.refresh(),
  );
  ref.onDispose(() => unawaited(subscription.cancel()));
  ref.onDispose(router.dispose);
  return router;
}

const _onboardingPaths = [
  '/onboarding',
  '/onboarding/age',
  '/onboarding/goal',
  '/onboarding/days',
  '/onboarding/session-length',
  '/onboarding/experience',
  '/onboarding/comfort',
  '/onboarding/emphasis',
  '/onboarding/activities',
  '/onboarding/menstrual',
];
int _lastOnboardingIndex = 0;
double _onboardingDirection = 1;

/// Onboarding steps share one horizontal axis: forward travels left, back
/// travels right, and both the arriving and leaving step move the same way.
Page<void> _onboardingPage(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  final index = _onboardingPaths.indexOf(state.matchedLocation);
  // Page builders also run on router refreshes; only a real step change may
  // flip the direction, or a refresh mid-transition would reverse it.
  if (index >= 0 && index != _lastOnboardingIndex) {
    _onboardingDirection = index < _lastOnboardingIndex ? -1 : 1;
    _lastOnboardingIndex = index;
  }
  return _FadeThroughPage(
    key: state.pageKey,
    duration: AppMotion.duration(context, AppMotion.routeEntrance),
    reverseDuration: AppMotion.duration(context, AppMotion.routeExit),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        AppFadeThrough(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          enterFrom: Offset(0.06 * _onboardingDirection, 0),
          exitTo: Offset(-0.06 * _onboardingDirection, 0),
          child: child,
        ),
    child: child,
  );
}

/// Context changes (a new part of the app, not a step deeper) fade through
/// with a slight rise.
Page<void> _softPage(BuildContext context, GoRouterState state, Widget child) {
  return _FadeThroughPage(
    key: state.pageKey,
    duration: AppMotion.duration(context, AppMotion.routeEntrance),
    reverseDuration: AppMotion.duration(context, AppMotion.routeExit),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        AppFadeThrough(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          enterFrom: const Offset(0, 0.03),
          child: child,
        ),
    child: child,
  );
}

/// A page that fades through its siblings. When a screen replaces it, the
/// arriving screen's animation fades it out; a full-screen takeover rising
/// over it (see [_takeoverPage]) leaves it still underneath.
class _FadeThroughPage extends Page<void> {
  const _FadeThroughPage({
    required this.child,
    required this.duration,
    required this.reverseDuration,
    required this.transitionsBuilder,
    super.key,
  });

  final Widget child;
  final Duration duration;
  final Duration reverseDuration;
  final RouteTransitionsBuilder transitionsBuilder;

  @override
  Route<void> createRoute(BuildContext context) => _FadeThroughRoute(this);
}

class _FadeThroughRoute extends PageRoute<void> {
  _FadeThroughRoute(_FadeThroughPage page) : super(settings: page);

  _FadeThroughPage get _page => settings as _FadeThroughPage;

  @override
  Duration get transitionDuration => _page.duration;

  @override
  Duration get reverseTransitionDuration => _page.reverseDuration;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) =>
      !(nextRoute is PageRoute && nextRoute.fullscreenDialog);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => Semantics(
    scopesRoute: true,
    explicitChildNodes: true,
    child: _page.child,
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _page.transitionsBuilder(context, animation, secondaryAnimation, child);
}

/// Drill-down screens use the platform push, so iOS gets its edge swipe back.
/// Reduced motion keeps the instant soft page instead.
Page<void> _detailPage(
  BuildContext context,
  GoRouterState state,
  Widget child,
) => AppMotion.isReduced(context)
    ? _softPage(context, state, child)
    : MaterialPage<void>(key: state.pageKey, child: child);

/// The workout rises over Today as one opaque sheet and drops back down.
/// As a full-screen dialog, it leaves the screen beneath perfectly still.
CustomTransitionPage<void> _takeoverPage(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    fullscreenDialog: true,
    child: child,
    transitionDuration: AppMotion.duration(context, AppMotion.layout),
    reverseTransitionDuration: AppMotion.exitDuration(
      context,
      AppMotion.layout,
    ),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(
                CurvedAnimation(
                  parent: animation,
                  curve: AppMotion.entranceCurve,
                  reverseCurve: AppMotion.standardCurve,
                ),
              ),
          child: child,
        ),
  );
}

class _AppShell extends StatefulWidget {
  const _AppShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tabFade = AnimationController(
    vsync: this,
    value: 1,
  );
  bool _switching = false;
  int? _target;

  @override
  void didUpdateWidget(covariant _AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_switching &&
        oldWidget.navigationShell.currentIndex !=
            widget.navigationShell.currentIndex) {
      _tabFade.value = 0;
      _tabFade.animateTo(
        1,
        duration: AppMotion.duration(context, AppMotion.tab),
        curve: AppMotion.entranceCurve,
      );
    }
  }

  Future<void> _selectTab(int index) async {
    if (_switching) return;
    final currentIndex = widget.navigationShell.currentIndex;
    if (index == currentIndex) {
      widget.navigationShell.goBranch(index, initialLocation: true);
      return;
    }
    if (AppMotion.isReduced(context)) {
      widget.navigationShell.goBranch(index);
      return;
    }

    // The tab bar answers the tap at once, while the page fades through.
    setState(() {
      _switching = true;
      _target = index;
    });
    await _tabFade.animateTo(
      0,
      duration: AppMotion.duration(context, const Duration(milliseconds: 75)),
      curve: AppMotion.standardCurve,
    );
    if (!mounted) return;
    widget.navigationShell.goBranch(index);
    await _tabFade.animateTo(
      1,
      duration: AppMotion.duration(context, const Duration(milliseconds: 125)),
      curve: AppMotion.entranceCurve,
    );
    _switching = false;
    _target = null;
  }

  @override
  void dispose() {
    _tabFade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(opacity: _tabFade, child: widget.navigationShell),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _target ?? widget.navigationShell.currentIndex,
        animationDuration: AppMotion.duration(context, AppMotion.layout),
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            key: ValueKey('today-tab'),
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Today',
          ),
          NavigationDestination(
            key: ValueKey('plan-tab'),
            icon: Icon(Icons.view_agenda_outlined),
            selectedIcon: Icon(Icons.view_agenda_rounded),
            label: 'Plan',
          ),
          NavigationDestination(
            key: ValueKey('me-tab'),
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Me',
          ),
        ],
      ),
    );
  }
}
