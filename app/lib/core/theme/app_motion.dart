import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Shared timing and easing for motion across the app.
abstract final class AppMotion {
  static const Duration instant = Duration.zero;
  static const Duration feedback = Duration(milliseconds: 120);
  static const Duration state = Duration(milliseconds: 220);
  static const Duration layout = Duration(milliseconds: 300);
  static const Duration entrance = Duration(milliseconds: 450);

  static const Duration routeEntrance = Duration(milliseconds: 300);
  static const Duration routeExit = Duration(milliseconds: 225);
  static const Duration tab = Duration(milliseconds: 200);
  static const Duration setPop = Duration(milliseconds: 250);
  static const Duration completion = Duration(milliseconds: 500);
  static const Duration visualHold = Duration(milliseconds: 1200);
  static const Duration visualFade = Duration(milliseconds: 250);

  static const Curve standardCurve = Curves.easeOutQuart;
  static const Curve entranceCurve = Curves.easeOutQuint;
  static const Curve decisiveCurve = Curves.easeOutExpo;

  /// Android's "Remove animations" arrives as [MediaQueryData.disableAnimations];
  /// iOS Reduce Motion only as the platform's `reduceMotion` feature.
  static bool isReduced(BuildContext context) =>
      (MediaQuery.maybeOf(context)?.disableAnimations ?? false) ||
      WidgetsBinding
          .instance
          .platformDispatcher
          .accessibilityFeatures
          .reduceMotion;

  /// Returns [duration], or no time when the platform requests reduced motion.
  static Duration duration(BuildContext context, Duration duration) =>
      isReduced(context) ? instant : duration;

  /// Exits are intentionally quicker than their paired entrances.
  static Duration exitDuration(BuildContext context, Duration entrance) =>
      duration(
        context,
        Duration(microseconds: (entrance.inMicroseconds * 0.75).round()),
      );

  /// An [Image.frameBuilder]: an image that decodes after its first frame
  /// fades in instead of popping into place.
  static Widget fadeInImage(
    BuildContext context,
    Widget child,
    int? frame,
    bool wasSynchronouslyLoaded,
  ) => wasSynchronouslyLoaded
      ? child
      : AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: duration(context, visualFade),
          curve: Curves.easeOut,
          child: child,
        );

  /// Timing for every modal bottom sheet, so they all rise and settle alike.
  static AnimationStyle sheet(BuildContext context) => AnimationStyle(
    duration: duration(context, layout),
    reverseDuration: exitDuration(context, layout),
  );
}

/// A fade-through for swapping whole screens or stages.
///
/// The leaving layer clears in the first third of its exit and only then does
/// the arriving layer resolve, so two layouts never read on top of each
/// other. A layer leaves either by running [animation] in reverse (a pop, or
/// an [AnimatedSwitcher] swap) or by being covered, as [secondaryAnimation]
/// runs forward while the screen that replaces it arrives on top.
class AppFadeThrough extends AnimatedWidget {
  AppFadeThrough({
    required this.animation,
    required this.child,
    super.key,
    this.secondaryAnimation = kAlwaysDismissedAnimation,
    this.enterFrom = Offset.zero,
    this.exitTo = Offset.zero,
  }) : super(listenable: Listenable.merge([animation, secondaryAnimation]));

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  /// Fractional offset the arriving layer travels in from.
  final Offset enterFrom;

  /// Fractional offset the leaving layer travels out to.
  final Offset exitTo;

  // The leaving layer is gone at 35%, exactly when the arriving one starts.
  static const _exitFade = Interval(0, 0.35);
  static const _enterFade = Interval(0.35, 1, curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final popping = animation.status == AnimationStatus.reverse;
    // How far this layer has left: by popping, or by being covered.
    final gone = popping ? 1 - animation.value : secondaryAnimation.value;
    final arrived = popping ? 1.0 : animation.value;
    return Opacity(
      opacity: _enterFade.transform(arrived) * (1 - _exitFade.transform(gone)),
      child: FractionalTranslation(
        translation:
            enterFrom * (1 - AppMotion.entranceCurve.transform(arrived)) +
            exitTo * AppMotion.standardCurve.transform(gone),
        child: child,
      ),
    );
  }
}

/// Transform-only press feedback for large, decisive controls.
class AppPressScale extends StatefulWidget {
  const AppPressScale({
    required this.child,
    super.key,
    this.enabled = true,
    this.pressedScale = 0.98,
  });

  final Widget child;
  final bool enabled;
  final double pressedScale;

  @override
  State<AppPressScale> createState() => _AppPressScaleState();
}

class _AppPressScaleState extends State<AppPressScale> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (!widget.enabled || _pressed == pressed) return;
    setState(() => _pressed = pressed);
  }

  @override
  void didUpdateWidget(covariant AppPressScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _pressed) _pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: AppMotion.duration(context, AppMotion.feedback),
        curve: AppMotion.standardCurve,
        child: widget.child,
      ),
    );
  }
}

/// A loading spinner that only shows once a wait is long enough to notice.
/// Most local loads finish in a frame or two, and a spinner that flashes for
/// that long reads as a glitch.
class AppDelayedSpinner extends StatelessWidget {
  const AppDelayedSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        curve: const Interval(0.6, 1),
        builder: (context, opacity, child) =>
            Opacity(opacity: opacity, child: child),
        child: const CircularProgressIndicator(
          color: AppColors.rose,
          backgroundColor: AppColors.blushSoft,
        ),
      ),
    );
  }
}
