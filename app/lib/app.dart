import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/navigation/app_router.dart';
import 'core/providers.dart';
import 'core/theme/app_theme.dart';
import 'core/version_gate.dart';

class WomensGymApp extends ConsumerWidget {
  const WomensGymApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = ref.watch(startupVersionGateProvider);
    return MaterialApp.router(
      title: 'Bloom',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => gate.when(
        data: (decision) => decision.isBlocked
            ? VersionGateBlockingScreen(message: decision.message)
            : child ?? const SizedBox.shrink(),
        error: (error, stackTrace) => child ?? const SizedBox.shrink(),
        loading: () => child ?? const SizedBox.shrink(),
      ),
    );
  }
}
