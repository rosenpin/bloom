import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/history/presentation/session_summary_screen.dart';
import '../../features/onboarding/presentation/onboarding_screens.dart';
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
  final router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      final location = state.matchedLocation;
      if (location.startsWith('/onboarding')) return null;

      final completed = await onboardingRepository.hasCompletedProfile();
      if (location == '/') {
        return completed ? '/today' : '/onboarding';
      }
      if (!completed &&
          (location == '/today' ||
              location == '/plan' ||
              location == '/me' ||
              location == '/session' ||
              location.startsWith('/history/'))) {
        return '/onboarding';
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
        path: '/session',
        pageBuilder: (context, state) =>
            _takeoverPage(context, state, const SessionPlayerScreen()),
      ),
      GoRoute(
        path: '/history/session/:id',
        pageBuilder: (context, state) => _softPage(
          context,
          state,
          SessionSummaryScreen(sessionId: state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/plan/day/:dayIndex',
        pageBuilder: (context, state) => _softPage(
          context,
          state,
          PlanDayDetailScreen(
            dayIndex:
                int.tryParse(state.pathParameters['dayIndex'] ?? '') ?? -1,
          ),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _AppShell(navigationShell: navigationShell),
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

CustomTransitionPage<void> _onboardingPage(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  final index = _onboardingPaths.indexOf(state.matchedLocation);
  final direction = index < _lastOnboardingIndex ? -1.0 : 1.0;
  _onboardingDirection = direction;
  if (index >= 0) _lastOnboardingIndex = index;
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppMotion.duration(context, AppMotion.routeEntrance),
    reverseTransitionDuration: AppMotion.duration(context, AppMotion.routeExit),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return AnimatedBuilder(
        animation: Listenable.merge([animation, secondaryAnimation]),
        child: child,
        builder: (context, child) {
          final entering = AppMotion.entranceCurve.transform(animation.value);
          final leaving = AppMotion.standardCurve.transform(
            secondaryAnimation.value,
          );
          return Opacity(
            opacity: (entering * (1 - leaving)).clamp(0, 1),
            child: FractionalTranslation(
              translation: Offset(
                direction * (1 - entering) * 0.06 -
                    _onboardingDirection * leaving * 0.06,
                0,
              ),
              child: child,
            ),
          );
        },
      );
    },
  );
}

CustomTransitionPage<void> _softPage(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppMotion.duration(context, AppMotion.routeEntrance),
    reverseTransitionDuration: AppMotion.duration(context, AppMotion.routeExit),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.entranceCurve,
        reverseCurve: AppMotion.standardCurve,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

CustomTransitionPage<void> _takeoverPage(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppMotion.duration(context, AppMotion.layout),
    reverseTransitionDuration: AppMotion.exitDuration(
      context,
      AppMotion.layout,
    ),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.decisiveCurve,
        reverseCurve: AppMotion.standardCurve,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
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

    _switching = true;
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
        selectedIndex: widget.navigationShell.currentIndex,
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
