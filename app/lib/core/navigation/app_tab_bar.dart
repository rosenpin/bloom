import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

/// A frosted glass capsule floating over the content. A blush lens springs to
/// the tab she taps, and snaps there when motion is reduced.
class AppTabBar extends StatefulWidget {
  const AppTabBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  State<AppTabBar> createState() => _AppTabBarState();
}

class _AppTabBarState extends State<AppTabBar>
    with SingleTickerProviderStateMixin {
  // Measured from iOS 26's own floating tab bar on the iPhone 17: sized to
  // its tabs and centred, 62 pt tall, 21 pt off the bottom edge, a lens 4 pt
  // inside the capsule.
  static const _height = 62.0;
  static const _tabWidth = 91.0;
  static const _margin = 21.0;
  static const _inset = 4.0;

  /// Frosted like the mockup's backdrop-filter: blur(22px) saturate(1.6).
  static final _frost = ImageFilter.compose(
    outer: const ColorFilter.matrix(_saturate160),
    inner: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
  );
  static const _tabs = [
    (
      key: ValueKey('today-tab'),
      label: 'Today',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    (
      key: ValueKey('plan-tab'),
      label: 'Plan',
      icon: Icons.calendar_today_outlined,
      selectedIcon: Icons.calendar_today_rounded,
    ),
    (
      key: ValueKey('me-tab'),
      label: 'Me',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  /// About 540 ms with a few percent of overshoot.
  static final _spring = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 540),
    bounce: 0.25,
  );

  /// The lens position in tabs, so 1.0 sits on Plan.
  late final AnimationController _lens = AnimationController.unbounded(
    vsync: this,
    value: widget.selectedIndex.toDouble(),
  );

  @override
  void didUpdateWidget(covariant AppTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = widget.selectedIndex.toDouble();
    if (target == oldWidget.selectedIndex.toDouble()) return;
    if (AppMotion.isReduced(context)) {
      _lens.value = target;
    } else {
      _lens.animateWith(
        SpringSimulation(_spring, _lens.value, target, _lens.velocity),
      );
    }
  }

  @override
  void dispose() {
    _lens.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    // The capsule keeps the same margin on its sides and below, and never
    // covers the system's own bottom chrome. iOS lets it reach 13 pt into the
    // 34 pt home-indicator zone, as its own tab bar does, stopping clear of
    // the indicator. On Android it floats a little above the gesture handle
    // or the three buttons.
    final bottom = math.max(
      _margin,
      inset + (defaultTargetPlatform == TargetPlatform.iOS ? -13 : 8),
    );
    // Increase Contrast is the nearest signal Flutter has to Reduce
    // Transparency, so the glass turns solid paper for it.
    final fill = MediaQuery.highContrastOf(context) ? 1.0 : 0.65;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Align(
        heightFactor: 1,
        child: SizedBox(
          width: _tabWidth * _tabs.length + _inset * 2,
          height: _height,
          child: CustomPaint(
            painter: const _OuterShadowPainter(),
            foregroundPainter: const _RimPainter(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_height / 2),
              child: BackdropFilter(
                filter: _frost,
                child: ColoredBox(
                  color: AppColors.paper.withValues(alpha: fill),
                  child: Padding(
                    padding: const EdgeInsets.all(_inset),
                    child: Stack(
                      children: [
                        AnimatedBuilder(animation: _lens, builder: _buildLens),
                        Material(
                          type: MaterialType.transparency,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < _tabs.length; i++)
                                Expanded(child: _buildTab(context, i)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLens(BuildContext context, Widget? child) {
    // It stretches a little along its path while it moves fast.
    final squash = (_lens.velocity.abs() / 6).clamp(0.0, 1.0);
    return Align(
      key: const ValueKey('tab-lens'),
      alignment: Alignment(_lens.value * 2 / (_tabs.length - 1) - 1, 0),
      child: FractionallySizedBox(
        widthFactor: 1 / _tabs.length,
        heightFactor: 1,
        child: Transform.scale(
          scaleX: 1 + 0.12 * squash,
          scaleY: 1 - 0.08 * squash,
          // Blush that lets the glass through a little, lighter at the top.
          child: DecoratedBox(
            decoration: ShapeDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.blushSoft.withValues(alpha: 0.6),
                  AppColors.blushSoft.withValues(alpha: 0.9),
                ],
              ),
              shape: const StadiumBorder(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTab(BuildContext context, int index) {
    final tab = _tabs[index];
    final selected = index == widget.selectedIndex;
    final color = selected ? AppColors.roseDeep : AppColors.inkSoft;
    return Semantics(
      key: tab.key,
      container: true,
      button: true,
      selected: selected,
      label: '${tab.label}, tab, ${index + 1} of ${_tabs.length}',
      onTap: () => widget.onSelected(index),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => widget.onSelected(index),
        customBorder: const StadiumBorder(),
        // No ripple: the lens is the answer to a tap. Keyboard focus still
        // shows, as a rose wash on the tab.
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: AppColors.roseDeep.withValues(alpha: 0.16),
        // Large text shrinks to fit the fixed capsule instead of overflowing.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? tab.selectedIcon : tab.icon, color: color),
              const SizedBox(height: 3),
              Text(
                tab.label,
                maxLines: 1,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The capsule's warm drop shadow, kept outside it so it never greys the glass.
class _OuterShadowPainter extends CustomPainter {
  const _OuterShadowPainter();

  static const _shadow = BoxShadow(
    color: Color(0x143D2B2A),
    offset: Offset(0, 6),
    blurRadius: 24,
    spreadRadius: -4,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final capsule = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );
    canvas.clipPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect((Offset.zero & size).inflate(60)),
        Path()..addRRect(capsule),
      ),
    );
    canvas.drawRRect(
      capsule.shift(_shadow.offset).inflate(_shadow.spreadRadius),
      _shadow.toPaint(),
    );
  }

  @override
  bool shouldRepaint(_OuterShadowPainter oldDelegate) => false;
}

/// A half-point light along the capsule's top edge, fading out by its middle,
/// like the mockup's inset highlight.
class _RimPainter extends CustomPainter {
  const _RimPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.25);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xE6FFFFFF), Color(0x00FFFFFF)],
          stops: [0, 0.55],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RimPainter oldDelegate) => false;
}

/// CSS saturate(1.6) as a colour matrix, with Rec. 709 luma weights.
const _saturate160 = <double>[
  1.4724, -0.4291, -0.0433, 0, 0, //
  -0.1276, 1.1709, -0.0433, 0, 0,
  -0.1276, -0.4291, 1.5567, 0, 0,
  0, 0, 0, 1, 0,
];
