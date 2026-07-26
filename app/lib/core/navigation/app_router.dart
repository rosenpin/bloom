import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/onboarding/presentation/onboarding_screens.dart';
import '../../features/plan/presentation/plan_reveal_screen.dart';
import '../../features/session/presentation/session_player_screen.dart';
import '../../features/tabs/presentation/me_screen.dart';
import '../../features/tabs/presentation/plan_screen.dart';
import '../../features/tabs/presentation/today_screen.dart';
import '../providers.dart';

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
              location == '/session')) {
        return '/onboarding';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SizedBox.shrink()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/onboarding/age',
        builder: (context, state) => const AgeScreen(),
      ),
      GoRoute(
        path: '/onboarding/goal',
        builder: (context, state) => const GoalScreen(),
      ),
      GoRoute(
        path: '/onboarding/days',
        builder: (context, state) => const DaysScreen(),
      ),
      GoRoute(
        path: '/onboarding/session-length',
        builder: (context, state) => const SessionLengthScreen(),
      ),
      GoRoute(
        path: '/onboarding/experience',
        builder: (context, state) => const ExperienceScreen(),
      ),
      GoRoute(
        path: '/onboarding/emphasis',
        builder: (context, state) => const EmphasisScreen(),
      ),
      GoRoute(
        path: '/onboarding/activities',
        builder: (context, state) => const ActivitiesScreen(),
      ),
      GoRoute(
        path: '/onboarding/menstrual',
        builder: (context, state) => const MenstrualScreen(),
      ),
      GoRoute(
        path: '/onboarding/generating',
        builder: (context, state) => const GeneratingScreen(),
      ),
      GoRoute(
        path: '/onboarding/reveal',
        builder: (context, state) => const PlanRevealScreen(),
      ),
      GoRoute(
        path: '/session',
        builder: (context, state) => const SessionPlayerScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/today',
                builder: (context, state) => const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/plan',
                builder: (context, state) => const PlanScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/me',
                builder: (context, state) => const MeScreen(),
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

class _AppShell extends StatelessWidget {
  const _AppShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
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
