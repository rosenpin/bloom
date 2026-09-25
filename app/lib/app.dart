import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/navigation/app_router.dart';
import 'core/providers.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/version_gate.dart';
import 'data/sync/sync_service.dart';
import 'features/onboarding/presentation/onboarding_screens.dart';

class WomensGymApp extends ConsumerStatefulWidget {
  const WomensGymApp({super.key});

  @override
  ConsumerState<WomensGymApp> createState() => _WomensGymAppState();
}

class _WomensGymAppState extends ConsumerState<WomensGymApp>
    with WidgetsBindingObserver {
  late final SyncService _syncService;

  @override
  void initState() {
    super.initState();
    _syncService = ref.read(syncServiceProvider);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_bootstrap());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decoded during launch, so a first run's welcome photo is there with
    // the words instead of a beat later.
    precacheImage(const AssetImage(WelcomeScreen.image), context);
  }

  Future<void> _bootstrap() async {
    try {
      await ref.read(seedExerciseContentProvider.future);
      await ref.read(ensureAnonymousAuthProvider.future);
    } on Object {
      // Startup remains fully local if either dependency is unavailable.
    }
    if (mounted) _syncService.startForeground();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncService.startForeground();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _syncService.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncService.pause();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(seedExerciseContentProvider);
    final gate = ref.watch(startupVersionGateProvider);
    return MaterialApp.router(
      title: 'Bloom',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      routerConfig: ref.watch(routerProvider),
      // Paint the brand ground under every route, so screens that fade
      // through each other never show the black window between them.
      builder: (context, child) => ColoredBox(
        color: AppColors.paper,
        child: gate.when(
          data: (decision) => decision.isBlocked
              ? VersionGateBlockingScreen(message: decision.message)
              : child ?? const SizedBox.shrink(),
          error: (error, stackTrace) => child ?? const SizedBox.shrink(),
          loading: () => child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
