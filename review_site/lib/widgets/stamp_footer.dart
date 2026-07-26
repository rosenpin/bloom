import 'package:flutter/material.dart';
import 'package:programming_engine/programming_engine.dart';

import '../theme/app_colors.dart';

final class StampFooter extends StatelessWidget {
  const StampFooter({required this.plan, super.key});

  final Plan? plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      decoration: const BoxDecoration(
        color: AppColors.ink,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: plan == null
          ? const Text(
              'No engine stamps · plan assembly did not complete',
              style: TextStyle(color: AppColors.blush),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  _Stamp(
                    label: 'engineVersion',
                    value: plan!.stamps.engineVersion,
                  ),
                  _Stamp(label: 'configHash', value: plan!.stamps.configHash),
                  _Stamp(label: 'contentHash', value: plan!.stamps.contentHash),
                ],
              ),
            ),
    );
  }
}

final class _Stamp extends StatelessWidget {
  const _Stamp({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: '$label ',
              style: const TextStyle(
                color: AppColors.inkFaint,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: AppColors.paper,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}
