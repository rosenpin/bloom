import 'package:flutter/material.dart';
import 'package:programming_engine/programming_engine.dart';

import '../theme/app_colors.dart';
import 'ui_labels.dart';

final class PlanTab extends StatelessWidget {
  const PlanTab({required this.result, super.key});

  final Result<Plan> result;

  @override
  Widget build(BuildContext context) {
    return switch (result) {
      Failure<Plan>(:final error) => _PlanFailure(error: error),
      Success<Plan>(:final value) => _PlanSuccess(plan: value),
    };
  }
}

final class _PlanFailure extends StatelessWidget {
  const _PlanFailure({required this.error});

  final PlanAssemblyError error;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        Card(
          color: AppColors.blushSoft,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Plan assembly failed',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(error.message),
                const SizedBox(height: 8),
                Text(
                  error.code.name,
                  style: const TextStyle(color: AppColors.roseDeep),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

final class _PlanSuccess extends StatelessWidget {
  const _PlanSuccess({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final exerciseCount = plan.days.fold<int>(
      0,
      (sum, day) => sum + day.exercises.length,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 36),
      children: <Widget>[
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              'Generated plan',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            _SummaryPill(label: '${plan.days.length} days'),
            _SummaryPill(label: '$exerciseCount slots'),
            _SummaryPill(label: 'Mesocycle ${plan.mesocycleIndex}'),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final week in plan.mesocycleCalendar)
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text('W${week.weekIndex} · ${weekKindLabel(week.kind)}'),
                backgroundColor: switch (week.kind) {
                  MesocycleWeekKind.build => AppColors.paper,
                  MesocycleWeekKind.easier => AppColors.lavenderSoft,
                  MesocycleWeekKind.push => AppColors.blushSoft,
                  MesocycleWeekKind.deload => AppColors.sageSoft,
                },
                side: const BorderSide(color: AppColors.line),
              ),
          ],
        ),
        if (plan.warnings.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          _Warnings(warnings: plan.warnings),
        ],
        const SizedBox(height: 18),
        for (final day in plan.days) ...<Widget>[
          _DayCard(day: day),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

final class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.blushSoft,
        border: Border.all(color: AppColors.blush),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        child: Text(label, style: const TextStyle(color: AppColors.roseDeep)),
      ),
    );
  }
}

final class _Warnings extends StatelessWidget {
  const _Warnings({required this.warnings});

  final List<EngineWarning> warnings;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.lavenderSoft,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(Icons.warning_amber_rounded, color: AppColors.lavender),
                SizedBox(width: 8),
                Text(
                  'Engine warnings',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final warning in warnings)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '• ${warning.code.name}'
                      '${warning.detail.isEmpty ? '' : ' · ${warning.detail}'}',
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 14, top: 2),
                      child: Text(
                        _warningGloss(warning.code),
                        style: const TextStyle(
                          color: AppColors.inkSoft,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final class _DayCard extends StatelessWidget {
  const _DayCard({required this.day});

  final PlanDay day;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.roseDeep,
                  foregroundColor: Colors.white,
                  child: Text(day.dayIndex.toString()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        dayKindLabel(day.kind),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${day.warmUpMinutes} min warm-up'
                        '${day.hasCardioFinisher ? ' · cardio finisher' : ''}',
                        style: const TextStyle(color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < day.exercises.length; index++)
              _ExerciseTile(exercise: day.exercises[index], index: index + 1),
          ],
        ),
      ),
    );
  }
}

final class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.exercise, required this.index});

  final PlanExercise exercise;
  final int index;

  @override
  Widget build(BuildContext context) {
    final dose = exercise.doseFor(MesocycleWeekKind.build);
    final support = supportEquipmentLabel(exercise.supportEquipment);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cream.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: SizedBox(
          width: 22,
          child: Text(
            '$index',
            style: const TextStyle(
              color: AppColors.inkFaint,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Text(
          exercise.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              Text(
                _doseText(dose),
                style: const TextStyle(
                  color: AppColors.roseDeep,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(blockRoleLabel(exercise.blockRole)),
              Text(
                '${equipmentLabel(exercise.resistanceEquipment)}'
                '${support.isEmpty ? '' : ' + $support'}',
              ),
            ],
          ),
        ),
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              exercise.orderedSwapCandidates.isEmpty
                  ? 'No eligible swaps'
                  : 'Swap options · compatibility order',
              style: const TextStyle(
                color: AppColors.inkSoft,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (exercise.orderedSwapCandidates.isNotEmpty)
            const SizedBox(height: 8),
          for (final candidate in exercise.orderedSwapCandidates)
            _SwapRow(candidate: candidate),
        ],
      ),
    );
  }
}

final class _SwapRow extends StatelessWidget {
  const _SwapRow({required this.candidate});

  final PlanSwapCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final isNotRecommended = candidate.tier == 3;
    final dose = candidate.doseFor(MesocycleWeekKind.build);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isNotRecommended
            ? AppColors.blushSoft
            : AppColors.paper.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: isNotRecommended ? AppColors.rose : AppColors.line,
        ),
      ),
      child: Row(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: isNotRecommended ? AppColors.roseDeep : AppColors.sageSoft,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: Text(
                'Tier ${candidate.tier}',
                style: TextStyle(
                  color: isNotRecommended ? Colors.white : AppColors.sage,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${candidate.name} · ${equipmentLabel(candidate.resistanceEquipment)}'
              '${dose == null ? '' : ' · ${_doseText(dose)}'}',
            ),
          ),
          if (isNotRecommended)
            const Text(
              'NOT RECOMMENDED',
              style: TextStyle(
                color: AppColors.roseDeep,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

String _doseText(Dose dose) => switch (dose) {
  RepsDose(:final sets, :final range, :final effort) =>
    '$sets × ${range.min}–${range.max} @ RPE ${effort.rpe}',
  TimedDose(:final sets, :final hold) => '$sets × ${hold.inSeconds}s',
};

String _warningGloss(WarningCode code) => switch (code) {
  WarningCode.invalidBodyMass =>
    'body mass was missing or invalid, so bodyweight was left out of the load calculation',
  WarningCode.bwContributionOutOfRange =>
    'the bodyweight contribution was outside its safe range, so the engine brought it back inside',
  WarningCode.invalidReps =>
    'the recorded rep count was invalid, so the engine used one rep',
  WarningCode.targetRepsOutOfRange =>
    'the rep target was outside this exercise’s range, so the engine brought it back inside',
  WarningCode.invertedRepRange =>
    'the rep range arrived backwards, so the engine put its limits in the right order',
  WarningCode.loadBelowEquipmentFloor =>
    'the recorded load was lighter than this equipment supports, so the lightest available load was used',
  WarningCode.lastLoadNotRepresentable =>
    'the recorded load is not available on this equipment, so the engine moved it to a real setting',
  WarningCode.nonFiniteLoad =>
    'the recorded load was not a usable number, so the lightest available load was used',
  WarningCode.negativeLayoff =>
    'the time since the last session was negative, so the engine treated it as zero days',
  WarningCode.invalidEquipmentStep =>
    'the equipment had an invalid load step, so the standard step for this equipment was used',
  WarningCode.clampedToEquipmentFloor =>
    'the calculated load was too light for this equipment, so the lightest available load was used',
  WarningCode.noRepresentableLoad =>
    'this load could not be expressed on the equipment, so the engine gave a rep target instead',
  WarningCode.gymComfortRelaxed =>
    'the catalog had no match at this comfort level, so the engine allowed more familiar gym options',
  WarningCode.experienceTierRelaxed =>
    'the catalog still had no match, so the engine allowed options from a broader experience level',
  WarningCode.weeklyDedupRelaxed =>
    'the catalog ran out of unused options for this slot this week, so an exercise repeats',
  WarningCode.blockDropped =>
    'the catalog had no safe match for this slot, so the engine left the slot out',
  WarningCode.danglingSwapSkipped =>
    'a saved swap points to an exercise that is no longer available, so the engine skipped it',
  WarningCode.invalidSwapSkipped =>
    'a saved swap did not fit this workout slot, so the engine skipped it',
  WarningCode.excludedExerciseSubstituted =>
    'an excluded exercise had a suitable swap, so the engine used the replacement',
  WarningCode.excludedExerciseHadNoSwap =>
    'an excluded exercise had no suitable swap, so the engine kept the planned exercise as a fallback',
  WarningCode.noPlanDayAvailable =>
    'the plan had no workout day available for this session',
  WarningCode.planWeekAlreadyComplete =>
    'all planned days were already completed this week, so the final day repeats',
  WarningCode.missingWeekDose =>
    'this exercise had no prescription for the current week, so the engine used a stable fallback',
  WarningCode.invalidMesocycleConfiguration =>
    'the mesocycle settings were invalid, so the engine brought them back to a usable range',
  WarningCode.unknownSessionExercise =>
    'a workout update named an exercise that is not in this session, so it was ignored',
  WarningCode.sessionEventIgnored =>
    'this workout update could not apply in the exercise’s current state, so it was ignored',
  WarningCode.sessionModifierAlreadyApplied =>
    'this workout adjustment was already applied, so the duplicate request was ignored',
  WarningCode.noEligibleSessionSwap =>
    'no suitable swap remained after the current filters and exclusions',
  WarningCode.calibrationFloorFailed =>
    'calibration reached the lightest safe load, so the engine stopped and offered an easier alternative',
  WarningCode.planEditTargetMissing =>
    'the requested plan edit could not find its original slot or replacement',
};
