import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../history/domain/history_presentation.dart';
import '../../onboarding/presentation/onboarding_widgets.dart';
import '../../plan/domain/plan_presentation.dart';
import '../application/session_lifecycle_service.dart';
import '../domain/session_presentation.dart';

class ShareRecapScreen extends StatefulWidget {
  const ShareRecapScreen({
    required this.runtime,
    required this.recap,
    required this.onFinished,
    super.key,
  });

  final SessionRuntime runtime;
  final SessionRecap recap;
  final VoidCallback onFinished;

  @override
  State<ShareRecapScreen> createState() => _ShareRecapScreenState();
}

class _ShareRecapScreenState extends State<ShareRecapScreen> {
  final GlobalKey _cardBoundary = GlobalKey();
  bool _sharing = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      key: const ValueKey('share-recap-screen'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Share it',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('share-recap-close'),
                      onPressed: widget.onFinished,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 350),
                      child: RepaintBoundary(
                        key: _cardBoundary,
                        child: ShareRecapCard(
                          runtime: widget.runtime,
                          recap: widget.recap,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Builder(
                  builder: (buttonContext) => FilledButton.icon(
                    key: const ValueKey('share-recap-share'),
                    onPressed: _sharing ? null : () => _share(buttonContext),
                    icon: _sharing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.ios_share_rounded),
                    label: Text(_sharing ? 'Getting it ready' : 'Share'),
                  ),
                ),
                TextButton(
                  key: const ValueKey('share-recap-later'),
                  onPressed: widget.onFinished,
                  child: const Text('Maybe later'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _share(BuildContext buttonContext) async {
    setState(() => _sharing = true);
    final box = buttonContext.findRenderObject() as RenderBox?;
    final shareOrigin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _cardBoundary.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('Recap card is not ready.');
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) throw StateError('Recap image could not be made.');

      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/bloom-session-${widget.runtime.sessionId}.png',
      );
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              file.path,
              name: 'bloom-workout-recap.png',
              mimeType: 'image/png',
            ),
          ],
          sharePositionOrigin: shareOrigin,
        ),
      );
      if (mounted) widget.onFinished();
    } on Object {
      if (!mounted) return;
      setState(() => _sharing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your recap is ready, but sharing did not open.'),
        ),
      );
    }
  }
}

class ShareRecapCard extends StatelessWidget {
  const ShareRecapCard({required this.runtime, required this.recap, super.key});

  final SessionRuntime runtime;
  final SessionRecap recap;

  @override
  Widget build(BuildContext context) {
    final completedAt = runtime.startedAt.add(recap.duration);
    final dayName = PlanPresentation.dayName(runtime.day, runtime.answers);
    return AspectRatio(
      aspectRatio: 0.72,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.blushSoft, AppColors.blush, AppColors.cream],
          ),
          borderRadius: AppRadii.largeBorder,
          boxShadow: [
            BoxShadow(
              color: AppColors.roseDeep.withValues(alpha: 0.14),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: AppRadii.largeBorder,
          child: Stack(
            children: [
              Positioned(
                right: -16,
                top: 62,
                child: Opacity(
                  opacity: 0.08,
                  child: Transform.scale(
                    scale: 7,
                    child: const BloomMark(showWordmark: false),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BloomMark(),
                    const Spacer(),
                    Text(
                      '${HistoryPresentation.weekday(completedAt, uppercase: true)} · WEEK ${runtime.state.mesocycleWeekIndex} · DONE',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.roseDeep,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      dayName,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      SessionPresentation.formatLoad(
                        recap.totalLoad,
                        runtime.displayUnitSystem,
                      ),
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'moved today, ${SessionPresentation.dayComparison(recap.totalLoad)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.inkSoft,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        if (recap.weekStreak case final streak?)
                          _RecapChip(label: '$streak-week streak'),
                        _RecapChip(
                          label: HistoryPresentation.duration(recap.duration),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecapChip extends StatelessWidget {
  const _RecapChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.paper.withValues(alpha: 0.72),
        borderRadius: AppRadii.largeBorder,
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: AppColors.inkSoft),
      ),
    );
  }
}
