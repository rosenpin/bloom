import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme/app_spacing.dart';

final class VersionGateConfig {
  const VersionGateConfig({
    required this.recommendedVersion,
    required this.minSupportedVersion,
    this.message,
  });

  final String recommendedVersion;
  final String minSupportedVersion;
  final String? message;

  Map<String, Object?> toJson() => {
    'recommended_version': recommendedVersion,
    'min_supported_version': minSupportedVersion,
    'message': message,
  };

  factory VersionGateConfig.fromJson(Map<String, Object?> json) {
    return VersionGateConfig(
      recommendedVersion: json['recommended_version']! as String,
      minSupportedVersion: json['min_supported_version']! as String,
      message: json['message'] as String?,
    );
  }
}

final class VersionGateDecision {
  const VersionGateDecision({
    required this.isBlocked,
    required this.updateRecommended,
    this.message,
    this.usedCachedConfig = false,
  });

  const VersionGateDecision.allowed()
    : isBlocked = false,
      updateRecommended = false,
      message = null,
      usedCachedConfig = false;

  final bool isBlocked;
  final bool updateRecommended;
  final String? message;
  final bool usedCachedConfig;
}

abstract interface class VersionGate {
  Future<VersionGateDecision> check({required String currentVersion});
}

abstract interface class VersionGateRemote {
  Future<VersionGateConfig> fetch();
}

abstract interface class VersionGateCache {
  Future<VersionGateConfig?> read();
  Future<void> write(VersionGateConfig config);
}

final class SupabaseVersionGateRemote implements VersionGateRemote {
  const SupabaseVersionGateRemote(this._client);

  final SupabaseClient Function() _client;

  @override
  Future<VersionGateConfig> fetch() async {
    final row = await _client()
        .from('version_gate')
        .select('recommended_version,min_supported_version,message')
        .limit(1)
        .single();
    return VersionGateConfig.fromJson(row);
  }
}

final class SharedPreferencesVersionGateCache implements VersionGateCache {
  const SharedPreferencesVersionGateCache(this._preferences);

  static const _key = 'version_gate.last_known';
  final SharedPreferencesAsync _preferences;

  @override
  Future<VersionGateConfig?> read() async {
    final encoded = await _preferences.getString(_key);
    if (encoded == null) return null;
    return VersionGateConfig.fromJson(
      (jsonDecode(encoded) as Map<Object?, Object?>).cast<String, Object?>(),
    );
  }

  @override
  Future<void> write(VersionGateConfig config) =>
      _preferences.setString(_key, jsonEncode(config.toJson()));
}

/// Network, parsing, timeout, and cache failures all fail open.
///
/// A cached response can preserve an update nudge and its message during an
/// outage, but a hard block is only ever applied to a fresh successful check.
final class FailOpenVersionGate implements VersionGate {
  const FailOpenVersionGate({
    required this.remote,
    required this.cache,
    this.timeout = const Duration(seconds: 3),
  });

  final VersionGateRemote remote;
  final VersionGateCache cache;
  final Duration timeout;

  @override
  Future<VersionGateDecision> check({required String currentVersion}) async {
    try {
      final config = await remote.fetch().timeout(timeout);
      try {
        await cache.write(config);
      } on Object {
        // The remote result remains authoritative if only persistence failed.
      }
      return _decisionFor(currentVersion, config);
    } on Object {
      return _failOpenDecision(currentVersion);
    }
  }

  VersionGateDecision _decisionFor(
    String currentVersion,
    VersionGateConfig config,
  ) {
    return VersionGateDecision(
      isBlocked:
          compareVersions(currentVersion, config.minSupportedVersion) < 0,
      updateRecommended:
          compareVersions(currentVersion, config.recommendedVersion) < 0,
      message: config.message,
    );
  }

  Future<VersionGateDecision> _failOpenDecision(String currentVersion) async {
    try {
      final cached = await cache.read();
      if (cached == null) return const VersionGateDecision.allowed();
      return VersionGateDecision(
        isBlocked: false,
        updateRecommended:
            compareVersions(currentVersion, cached.recommendedVersion) < 0,
        message: cached.message,
        usedCachedConfig: true,
      );
    } on Object {
      return const VersionGateDecision.allowed();
    }
  }
}

/// Configurable replacement for [VersionGate] in widget and integration tests.
final class FakeVersionGate implements VersionGate {
  const FakeVersionGate(this.result);

  final VersionGateDecision result;

  @override
  Future<VersionGateDecision> check({required String currentVersion}) async =>
      result;
}

/// SemVer-style comparison. Build metadata is ignored and prereleases sort
/// before their corresponding release.
int compareVersions(String left, String right) {
  final a = _ParsedVersion.parse(left);
  final b = _ParsedVersion.parse(right);
  final width = a.core.length > b.core.length ? a.core.length : b.core.length;
  for (var index = 0; index < width; index++) {
    final comparison = (index < a.core.length ? a.core[index] : 0).compareTo(
      index < b.core.length ? b.core[index] : 0,
    );
    if (comparison != 0) return comparison;
  }

  if (a.preRelease.isEmpty && b.preRelease.isEmpty) return 0;
  if (a.preRelease.isEmpty) return 1;
  if (b.preRelease.isEmpty) return -1;
  final preWidth = a.preRelease.length > b.preRelease.length
      ? a.preRelease.length
      : b.preRelease.length;
  for (var index = 0; index < preWidth; index++) {
    if (index >= a.preRelease.length) return -1;
    if (index >= b.preRelease.length) return 1;
    final comparison = _compareIdentifier(
      a.preRelease[index],
      b.preRelease[index],
    );
    if (comparison != 0) return comparison;
  }
  return 0;
}

int _compareIdentifier(String left, String right) {
  final leftNumber = int.tryParse(left);
  final rightNumber = int.tryParse(right);
  if (leftNumber != null && rightNumber != null) {
    return leftNumber.compareTo(rightNumber);
  }
  if (leftNumber != null) return -1;
  if (rightNumber != null) return 1;
  return left.compareTo(right);
}

final class _ParsedVersion {
  const _ParsedVersion(this.core, this.preRelease);

  final List<int> core;
  final List<String> preRelease;

  factory _ParsedVersion.parse(String input) {
    var normalized = input.trim();
    if (normalized.startsWith('v')) normalized = normalized.substring(1);
    normalized = normalized.split('+').first;
    final pieces = normalized.split('-');
    final core = pieces.first
        .split('.')
        .map((piece) {
          final value = int.tryParse(piece);
          if (value == null || value < 0) {
            throw FormatException('Invalid version: $input');
          }
          return value;
        })
        .toList(growable: false);
    if (core.isEmpty || core.length > 4) {
      throw FormatException('Invalid version: $input');
    }
    final preRelease = pieces.length == 1
        ? const <String>[]
        : pieces.skip(1).join('-').split('.');
    if (preRelease.any((part) => part.isEmpty)) {
      throw FormatException('Invalid version: $input');
    }
    return _ParsedVersion(core, preRelease);
  }
}

class VersionGateBlockingScreen extends StatelessWidget {
  const VersionGateBlockingScreen({this.message, this.onUpdate, super.key});

  final String? message;
  final VoidCallback? onUpdate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        minimum: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.system_update_rounded, size: 52),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'A quick update',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message ??
                      'Update the app to keep your plan and sessions working smoothly.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: onUpdate ?? () {},
                  child: const Text('Update to continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
