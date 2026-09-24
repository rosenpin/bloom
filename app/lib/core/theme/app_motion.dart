import 'package:flutter/material.dart';

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

  static bool isReduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// Returns [duration], or no time when the platform requests reduced motion.
  static Duration duration(BuildContext context, Duration duration) =>
      isReduced(context) ? instant : duration;

  /// Exits are intentionally quicker than their paired entrances.
  static Duration exitDuration(BuildContext context, Duration entrance) =>
      duration(
        context,
        Duration(microseconds: (entrance.inMicroseconds * 0.75).round()),
      );
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
