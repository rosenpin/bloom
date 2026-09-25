import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_sizes.dart';
import '../data/exercise_visual_source.dart';

part 'exercise_visual.g.dart';

typedef ExerciseVisualPlaybackBuilder =
    Widget Function({
      required Key key,
      required ExerciseVisualSource source,
      required Widget placeholder,
    });

@riverpod
ExerciseVisualPlaybackBuilder exerciseVisualPlaybackBuilder(Ref ref) =>
    ({required key, required source, required placeholder}) => switch (source) {
      BundledExerciseVideoSource video => ExerciseVideoPlayer(
        key: key,
        source: video,
        placeholder: placeholder,
      ),
      BundledStillsSource stills => ExerciseStillsPlayer(
        key: key,
        source: stills,
      ),
    };

class ExerciseVisual extends ConsumerWidget {
  const ExerciseVisual({
    required this.exerciseId,
    required this.exerciseName,
    required this.blockRoleLabel,
    this.height,
    this.aspectRatio,
    this.compact = false,
    super.key,
  }) : assert(height == null || aspectRatio == null);

  final String exerciseId;
  final String exerciseName;
  final String blockRoleLabel;
  final double? height;
  final double? aspectRatio;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = resolveExerciseVisualSource(exerciseId);
    final stills = exerciseStills(exerciseId);
    // Thumbnails hold still. A list of looping pictures is noise, and the
    // exercise itself is shown moving at full size.
    final thumbnail =
        compact &&
        aspectRatio == null &&
        (height ?? AppSizes.thumbnailLg) <= AppSizes.thumbnailLg;
    // A loop's first frame is its first still, so the still stands in while
    // the video loads and the handover is invisible.
    final placeholder = stills != null && source is BundledExerciseVideoSource
        ? Image.asset(
            stills.pos1Asset,
            key: const ValueKey('exercise-video-poster'),
            fit: BoxFit.contain,
          )
        : _ExerciseVisualPlaceholder(
            exerciseName: exerciseName,
            blockRoleLabel: blockRoleLabel,
            compact: compact,
          );
    final playback = thumbnail && stills != null
        ? Image.asset(
            stills.pos1Asset,
            key: const ValueKey('exercise-still-1'),
            fit: BoxFit.contain,
            frameBuilder: AppMotion.fadeInImage,
          )
        : source == null
        ? placeholder
        : ref.watch(exerciseVisualPlaybackBuilderProvider)(
            key: ValueKey('exercise-visual-$exerciseId'),
            source: source,
            placeholder: placeholder,
          );
    final visual = aspectRatio != null
        ? AspectRatio(aspectRatio: aspectRatio!, child: playback)
        : SizedBox(
            height: height ?? (compact ? AppSizes.thumbnailLg : 220),
            child: playback,
          );
    return ClipRRect(
      key: const ValueKey('exercise-visual'),
      borderRadius: compact ? AppRadii.smallBorder : AppRadii.largeBorder,
      child: SizedBox(width: double.infinity, child: visual),
    );
  }
}

/// Both positions of a move side by side and still, readable at a glance
/// between sets. Two 8:9 stills make one 16:9 picture, so nothing is cropped.
class ExerciseDiptych extends StatelessWidget {
  const ExerciseDiptych({
    required this.exerciseId,
    required this.exerciseName,
    required this.blockRoleLabel,
    super.key,
  });

  final String exerciseId;
  final String exerciseName;
  final String blockRoleLabel;

  @override
  Widget build(BuildContext context) {
    final stills = exerciseStills(exerciseId);
    return AspectRatio(
      key: const ValueKey('exercise-diptych'),
      aspectRatio: AppSizes.exerciseDiptychAspect,
      child: stills == null
          ? _ExerciseVisualPlaceholder(
              exerciseName: exerciseName,
              blockRoleLabel: blockRoleLabel,
              compact: false,
            )
          : ColoredBox(
              color: AppColors.paper,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, asset) in [
                    stills.pos1Asset,
                    stills.pos2Asset,
                  ].indexed) ...[
                    if (index == 1) const SizedBox(width: 2),
                    Expanded(
                      child: Image.asset(
                        asset,
                        key: ValueKey('exercise-diptych-${index + 1}'),
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                        frameBuilder: AppMotion.fadeInImage,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class ExerciseStillsPlayer extends StatefulWidget {
  const ExerciseStillsPlayer({required this.source, super.key});

  final BundledStillsSource source;

  @override
  State<ExerciseStillsPlayer> createState() => _ExerciseStillsPlayerState();
}

class _ExerciseStillsPlayerState extends State<ExerciseStillsPlayer>
    with SingleTickerProviderStateMixin {
  static const _hold = AppMotion.stillsHold;
  static const _fade = AppMotion.stillsCrossfade;
  static final _total = (_hold + _fade) * 2;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _total,
  );
  late final Animation<double> _secondOpacity = TweenSequence<double>([
    TweenSequenceItem(
      tween: ConstantTween<double>(0),
      weight: _hold.inMilliseconds.toDouble(),
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: _fade.inMilliseconds.toDouble(),
    ),
    TweenSequenceItem(
      tween: ConstantTween<double>(1),
      weight: _hold.inMilliseconds.toDouble(),
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 0,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: _fade.inMilliseconds.toDouble(),
    ),
  ]).animate(_controller);
  bool _showSecond = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precache();
    _syncPlayback();
  }

  @override
  void didUpdateWidget(covariant ExerciseStillsPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _controller.reset();
      _showSecond = false;
      _precache();
      _syncPlayback();
    }
  }

  void _precache() {
    precacheImage(AssetImage(widget.source.pos1Asset), context);
    precacheImage(AssetImage(widget.source.pos2Asset), context);
  }

  void _syncPlayback() {
    final shouldPlay =
        !AppMotion.isReduced(context) &&
        (ModalRoute.isCurrentOf(context) ?? true) &&
        TickerMode.valuesOf(context).enabled;
    if (shouldPlay && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldPlay && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.isReduced(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          widget.source.pos1Asset,
          key: const ValueKey('exercise-still-1'),
          fit: BoxFit.contain,
          frameBuilder: AppMotion.fadeInImage,
        ),
        if (reduced && _showSecond)
          Image.asset(
            widget.source.pos2Asset,
            key: const ValueKey('exercise-still-2'),
            fit: BoxFit.contain,
          ),
        if (!reduced)
          AnimatedBuilder(
            animation: _secondOpacity,
            builder: (context, child) =>
                Opacity(opacity: _secondOpacity.value, child: child),
            child: Image.asset(
              widget.source.pos2Asset,
              key: const ValueKey('exercise-still-2'),
              fit: BoxFit.contain,
            ),
          ),
        if (reduced)
          Positioned(
            right: AppSpacing.xs,
            bottom: AppSpacing.xs,
            child: Material(
              color: AppColors.ink.withValues(alpha: 0.72),
              borderRadius: AppRadii.smallBorder,
              child: InkWell(
                key: const ValueKey('exercise-still-flip'),
                borderRadius: AppRadii.smallBorder,
                onTap: () => setState(() => _showSecond = !_showSecond),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: Text(
                    '1 · 2',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppColors.paper),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class ExerciseVideoPlayer extends StatefulWidget {
  const ExerciseVideoPlayer({
    required this.source,
    required this.placeholder,
    super.key,
  });

  final BundledExerciseVideoSource source;
  final Widget placeholder;

  @override
  State<ExerciseVideoPlayer> createState() => _ExerciseVideoPlayerState();
}

class _ExerciseVideoPlayerState extends State<ExerciseVideoPlayer> {
  VideoPlayerController? _controller;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _beginLoad();
  }

  @override
  void didUpdateWidget(covariant ExerciseVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) _beginLoad();
  }

  @override
  void dispose() {
    _loadGeneration++;
    _disposeController(_controller);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final size = controller?.value.size ?? Size.zero;
    final ready =
        controller != null &&
        controller.value.isInitialized &&
        !controller.value.hasError &&
        size.width > 0 &&
        size.height > 0;
    // The placeholder stays underneath: a fresh video texture is transparent
    // until its first frame lands, and the fade covers that gap.
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.placeholder,
        if (ready)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: AppMotion.duration(context, AppMotion.visualFade),
            builder: (context, opacity, child) =>
                Opacity(opacity: opacity, child: child),
            child: FittedBox(
              fit: BoxFit.contain,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: VideoPlayer(controller),
              ),
            ),
          ),
      ],
    );
  }

  void _beginLoad() {
    final generation = ++_loadGeneration;
    _disposeController(_controller);
    _controller = null;
    unawaited(_initialize(generation));
  }

  Future<void> _initialize(int generation) async {
    final controller = VideoPlayerController.asset(widget.source.assetPath);
    try {
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
      await controller.dispose();
    }
  }

  void _handlePlaybackValue() {
    if (_controller?.value.hasError == true && mounted) setState(() {});
  }

  void _disposeController(VideoPlayerController? controller) {
    if (controller == null) return;
    controller.removeListener(_handlePlaybackValue);
    unawaited(controller.dispose());
  }
}

class _ExerciseVisualPlaceholder extends StatelessWidget {
  const _ExerciseVisualPlaceholder({
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
      key: const ValueKey('exercise-visual-placeholder'),
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
