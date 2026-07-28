import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/exercise_video_source.dart';

typedef ExerciseVideoPlaybackBuilder =
    Widget Function({
      required Key key,
      required String exerciseId,
      required ExerciseVideoSource source,
      required Widget placeholder,
      required bool showAngleToggle,
    });

final exerciseVideoPlaybackBuilderProvider =
    Provider<ExerciseVideoPlaybackBuilder>(
      (ref) =>
          ({
            required key,
            required exerciseId,
            required source,
            required placeholder,
            required showAngleToggle,
          }) => ExerciseVideoPlayer(
            key: key,
            exerciseId: exerciseId,
            source: source,
            placeholder: placeholder,
            showAngleToggle: showAngleToggle,
          ),
    );

class ExerciseVisual extends ConsumerWidget {
  const ExerciseVisual({
    required this.exerciseId,
    required this.exerciseName,
    required this.blockRoleLabel,
    this.height,
    this.aspectRatio,
    this.compact = false,
    this.showAngleToggle = true,
    super.key,
  }) : assert(height == null || aspectRatio == null);

  final String exerciseId;
  final String exerciseName;
  final String blockRoleLabel;
  final double? height;
  final double? aspectRatio;
  final bool compact;
  final bool showAngleToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = resolveExerciseVideoSource(exerciseId);
    final placeholder = _ExerciseVideoPlaceholder(
      exerciseName: exerciseName,
      blockRoleLabel: blockRoleLabel,
      compact: compact,
    );
    final playback = source == null
        ? placeholder
        : ref.watch(exerciseVideoPlaybackBuilderProvider)(
            key: ValueKey('exercise-video-$exerciseId'),
            exerciseId: exerciseId,
            source: source,
            placeholder: placeholder,
            showAngleToggle: showAngleToggle,
          );
    final visual = aspectRatio != null
        ? AspectRatio(aspectRatio: aspectRatio!, child: playback)
        : SizedBox(height: height ?? 220, child: playback);
    return ClipRRect(
      key: const ValueKey('exercise-visual'),
      borderRadius: AppRadii.largeBorder,
      child: SizedBox(width: double.infinity, child: visual),
    );
  }
}

class ExerciseVideoPlayer extends ConsumerStatefulWidget {
  const ExerciseVideoPlayer({
    required this.exerciseId,
    required this.source,
    required this.placeholder,
    required this.showAngleToggle,
    super.key,
  });

  final String exerciseId;
  final ExerciseVideoSource source;
  final Widget placeholder;
  final bool showAngleToggle;

  @override
  ConsumerState<ExerciseVideoPlayer> createState() =>
      _ExerciseVideoPlayerState();
}

class _ExerciseVideoPlayerState extends ConsumerState<ExerciseVideoPlayer> {
  ExerciseVideoAngle _angle = ExerciseVideoAngle.side;
  VideoPlayerController? _controller;
  bool _failed = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _beginLoad(rebuild: false);
  }

  @override
  void didUpdateWidget(covariant ExerciseVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exerciseId == widget.exerciseId &&
        oldWidget.source == widget.source) {
      return;
    }
    _angle = ExerciseVideoAngle.side;
    _beginLoad();
  }

  @override
  void dispose() {
    _loadGeneration++;
    _disposeController(_controller);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    return Stack(
      fit: StackFit.expand,
      children: [
        _videoOrLoading(source),
        if (widget.showAngleToggle && source is StreamedExerciseVideoSource)
          Positioned(
            right: AppSpacing.xs,
            bottom: AppSpacing.xs,
            child: _AngleToggle(selected: _angle, onSelected: _selectAngle),
          ),
      ],
    );
  }

  Widget _videoOrLoading(ExerciseVideoSource source) {
    final controller = _controller;
    if (!_failed && controller != null && controller.value.isInitialized) {
      final size = controller.value.size;
      if (size.width > 0 && size.height > 0) {
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: VideoPlayer(controller),
            ),
          ),
        );
      }
    }
    if (!_failed && source is StreamedExerciseVideoSource) {
      return Stack(
        fit: StackFit.expand,
        children: [
          widget.placeholder,
          Image.network(
            source.thumbnailUrl(_angle),
            key: ValueKey(
              'exercise-video-thumbnail-${widget.exerciseId}-${_angle.name}',
            ),
            fit: BoxFit.cover,
            alignment: Alignment.center,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => widget.placeholder,
          ),
        ],
      );
    }
    return widget.placeholder;
  }

  void _selectAngle(ExerciseVideoAngle angle) {
    if (angle == _angle) return;
    setState(() => _angle = angle);
    _beginLoad();
  }

  void _beginLoad({bool rebuild = true}) {
    final generation = ++_loadGeneration;
    final previousController = _controller;
    _controller = null;
    _failed = false;
    _disposeController(previousController);
    if (rebuild && mounted) setState(() {});
    unawaited(_initialize(generation));
  }

  Future<void> _initialize(int generation) async {
    VideoPlayerController? controller;
    try {
      controller = switch (widget.source) {
        BundledExerciseVideoSource(:final assetPath) =>
          VideoPlayerController.asset(assetPath),
        StreamedExerciseVideoSource source => VideoPlayerController.file(
          await _cachedFile(source.videoUrl(_angle)),
        ),
      };
      await controller.initialize();
      await controller.setVolume(0);
      await controller.setLooping(true);
      await controller.play();
      if (!mounted || generation != _loadGeneration) {
        await controller.dispose();
        return;
      }
      controller.addListener(_handlePlaybackValue);
      setState(() => _controller = controller);
    } on Object {
      if (controller != null) await controller.dispose();
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _failed = true);
    }
  }

  Future<File> _cachedFile(String remoteUrl) async {
    final cache = await ref.read(exerciseVideoCacheProvider.future);
    return cache.getFile(remoteUrl);
  }

  void _handlePlaybackValue() {
    final controller = _controller;
    if (controller == null ||
        !controller.value.hasError ||
        _failed ||
        !mounted) {
      return;
    }
    setState(() => _failed = true);
  }

  void _disposeController(VideoPlayerController? controller) {
    if (controller == null) return;
    controller.removeListener(_handlePlaybackValue);
    unawaited(controller.dispose());
  }
}

class _ExerciseVideoPlaceholder extends StatelessWidget {
  const _ExerciseVideoPlaceholder({
    required this.exerciseName,
    required this.blockRoleLabel,
    required this.compact,
  });

  final String exerciseName;
  final String blockRoleLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('exercise-video-placeholder'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.blushSoft, AppColors.lavenderSoft],
        ),
      ),
      child: compact
          ? const Center(
              child: Icon(
                Icons.fitness_center_rounded,
                color: AppColors.roseDeep,
                size: 30,
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.fitness_center_rounded,
                    color: AppColors.roseDeep,
                    size: 42,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    exerciseName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    blockRoleLabel,
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
    );
  }
}

class _AngleToggle extends StatelessWidget {
  const _AngleToggle({required this.selected, required this.onSelected});

  final ExerciseVideoAngle selected;
  final ValueChanged<ExerciseVideoAngle> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ink.withValues(alpha: 0.72),
      borderRadius: AppRadii.smallBorder,
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AngleButton(
            label: 'Front',
            angle: ExerciseVideoAngle.front,
            selected: selected == ExerciseVideoAngle.front,
            onSelected: onSelected,
          ),
          _AngleButton(
            label: 'Side',
            angle: ExerciseVideoAngle.side,
            selected: selected == ExerciseVideoAngle.side,
            onSelected: onSelected,
          ),
        ],
      ),
    );
  }
}

class _AngleButton extends StatelessWidget {
  const _AngleButton({
    required this.label,
    required this.angle,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final ExerciseVideoAngle angle;
  final bool selected;
  final ValueChanged<ExerciseVideoAngle> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        key: ValueKey('exercise-video-angle-${angle.name}'),
        onTap: () => onSelected(angle),
        child: AnimatedContainer(
          duration: AppMotion.duration(context, AppMotion.feedback),
          curve: AppMotion.standardCurve,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          color: selected ? AppColors.paper : Colors.transparent,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: selected ? AppColors.ink : AppColors.paper,
            ),
          ),
        ),
      ),
    );
  }
}
