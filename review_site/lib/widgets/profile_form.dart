import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:programming_engine/programming_engine.dart';

import '../models/persona_presets.dart';
import '../models/review_form_state.dart';
import '../theme/app_colors.dart';
import 'ui_labels.dart';

final class ProfileForm extends StatefulWidget {
  const ProfileForm({required this.state, required this.onChanged, super.key});

  final ReviewFormState state;
  final ValueChanged<ReviewFormState> onChanged;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

final class _ProfileFormState extends State<ProfileForm> {
  late final TextEditingController _weeksController;
  late final TextEditingController _mesocycleController;
  late final TextEditingController _bodyMassController;
  late final FocusNode _bodyMassFocusNode;
  String? _bodyMassError;

  @override
  void initState() {
    super.initState();
    _weeksController = TextEditingController(
      text: widget.state.weeksTrained.toString(),
    );
    _mesocycleController = TextEditingController(
      text: widget.state.mesocycleIndex.toString(),
    );
    _bodyMassController = TextEditingController(
      text: _bodyMassText(widget.state),
    );
    _bodyMassFocusNode = FocusNode()..addListener(_handleBodyMassFocusChange);
  }

  @override
  void didUpdateWidget(ProfileForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncInteger(_weeksController, widget.state.weeksTrained);
    _syncInteger(_mesocycleController, widget.state.mesocycleIndex);
    if (oldWidget.state.unitSystem != widget.state.unitSystem ||
        (!_bodyMassFocusNode.hasFocus &&
            (double.tryParse(_bodyMassController.text) ?? -1) !=
                widget.state.displayBodyMass)) {
      _bodyMassController.text = _bodyMassText(widget.state);
    }
  }

  void _syncInteger(TextEditingController controller, int value) {
    if (int.tryParse(controller.text) != value) {
      controller.text = value.toString();
    }
  }

  @override
  void dispose() {
    _weeksController.dispose();
    _mesocycleController.dispose();
    _bodyMassController.dispose();
    _bodyMassFocusNode
      ..removeListener(_handleBodyMassFocusChange)
      ..dispose();
    super.dispose();
  }

  void _handleBodyMassFocusChange() {
    if (_bodyMassFocusNode.hasFocus) {
      if (_bodyMassError != null) {
        setState(() => _bodyMassError = null);
      }
      return;
    }
    _commitBodyMass();
  }

  void _commitBodyMass() {
    final entered = double.tryParse(_bodyMassController.text);
    if (entered == null || !entered.isFinite) {
      _bodyMassController.text = _bodyMassText(widget.state);
      setState(() => _bodyMassError = 'Enter a body mass');
      return;
    }
    final kg = widget.state.unitSystem.isMetric
        ? entered
        : Kg.fromLb(entered).value;
    final clampedKg = kg.clamp(20, 400).toDouble();
    final committed = widget.state.copyWith(bodyMassKg: clampedKg);
    _bodyMassController.text = _bodyMassText(committed);
    if (clampedKg != widget.state.bodyMassKg) {
      widget.onChanged(committed);
    } else if (_bodyMassError != null) {
      setState(() => _bodyMassError = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Material(
      color: AppColors.blushSoft.withValues(alpha: 0.38),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
        children: <Widget>[
          Text('Review profile', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text(
            'Every change runs the shipping algorithm and updates the share link.',
            style: TextStyle(color: AppColors.inkSoft, height: 1.35),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<PersonaPreset>(
            key: ValueKey<String>('preset-${state.toCanonicalJson()}'),
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Persona preset'),
            hint: const Text('Custom profile'),
            items: <DropdownMenuItem<PersonaPreset>>[
              for (final preset in personaPresets)
                DropdownMenuItem<PersonaPreset>(
                  value: preset,
                  child: Text(preset.name),
                ),
            ],
            onChanged: (preset) {
              if (preset != null) widget.onChanged(preset.state);
            },
          ),
          const SizedBox(height: 12),
          _enumField<AgeBand>(
            label: 'Age band',
            value: state.ageBand,
            values: AgeBand.values,
            labelFor: ageBandLabel,
            onChanged: (value) =>
                widget.onChanged(state.copyWith(ageBand: value)),
          ),
          _enumField<TrainingDaysPerWeek>(
            label: 'Training days',
            value: state.daysPerWeek,
            values: TrainingDaysPerWeek.values,
            labelFor: (value) => '${value.value} days / week',
            onChanged: (value) =>
                widget.onChanged(state.copyWith(daysPerWeek: value)),
          ),
          _enumField<SessionMinutes>(
            label: 'Session length',
            value: state.sessionMinutes,
            values: SessionMinutes.values,
            labelFor: (value) => '${value.value} minutes',
            onChanged: (value) =>
                widget.onChanged(state.copyWith(sessionMinutes: value)),
          ),
          _enumField<Goal>(
            label: 'Goal',
            value: state.goal,
            values: Goal.values,
            labelFor: goalLabel,
            onChanged: (value) => widget.onChanged(state.copyWith(goal: value)),
          ),
          _enumField<Emphasis>(
            label: 'Emphasis',
            value: state.emphasis,
            values: const <Emphasis>[
              Emphasis.balanced,
              Emphasis.glutes,
              Emphasis.back,
              Emphasis.arms,
              Emphasis.core,
              Emphasis.legs,
            ],
            labelFor: emphasisLabel,
            onChanged: (value) =>
                widget.onChanged(state.copyWith(emphasis: value)),
          ),
          _enumField<ProfileExperienceTier>(
            label: 'Experience',
            value: state.experienceTier,
            values: ProfileExperienceTier.values,
            labelFor: experienceLabel,
            onChanged: (value) =>
                widget.onChanged(state.copyWith(experienceTier: value)),
          ),
          _enumField<GymComfort>(
            label: 'Gym comfort',
            value: state.gymComfort,
            values: GymComfort.values,
            labelFor: comfortLabel,
            onChanged: (value) =>
                widget.onChanged(state.copyWith(gymComfort: value)),
          ),
          _numberField(
            label: 'Weeks trained',
            controller: _weeksController,
            onParsed: (value) => widget.onChanged(
              state.copyWith(weeksTrained: value.round().clamp(0, 520)),
            ),
          ),
          _numberField(
            label: 'Mesocycle index',
            controller: _mesocycleController,
            onParsed: (value) => widget.onChanged(
              state.copyWith(mesocycleIndex: value.round().clamp(1, 999)),
            ),
          ),
          _enumField<UnitSystem>(
            label: 'Gym unit system',
            value: state.unitSystem,
            values: UnitSystem.values,
            labelFor: (value) =>
                value.isMetric ? 'Metric (kg)' : 'Imperial (lb)',
            onChanged: (value) =>
                widget.onChanged(state.copyWith(unitSystem: value)),
          ),
          _bodyMassField(
            label: 'Body mass (${state.unitSystem.isMetric ? 'kg' : 'lb'})',
          ),
          const SizedBox(height: 2),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text('Other activities'),
            subtitle: const Text(
              'Collected and stamped; ignored by v1 assembly',
            ),
            children: <Widget>[
              for (final activity in ActivityKind.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DropdownButtonFormField<int>(
                    key: ValueKey<String>(
                      '${activity.name}-${state.otherActivities[activity] ?? 0}',
                    ),
                    initialValue: state.otherActivities[activity] ?? 0,
                    decoration: InputDecoration(
                      labelText: '${activityLabel(activity)} sessions / week',
                    ),
                    items: <DropdownMenuItem<int>>[
                      for (var count = 0; count <= 7; count++)
                        DropdownMenuItem<int>(
                          value: count,
                          child: Text(count.toString()),
                        ),
                    ],
                    onChanged: (count) {
                      final activities = <ActivityKind, int>{
                        ...state.otherActivities,
                      };
                      if (count == null || count == 0) {
                        activities.remove(activity);
                      } else {
                        activities[activity] = count;
                      }
                      widget.onChanged(
                        state.copyWith(otherActivities: activities),
                      );
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _enumField<T extends Enum>({
    required String label,
    required T value,
    required List<T> values,
    required String Function(T) labelFor,
    required ValueChanged<T> onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: DropdownButtonFormField<T>(
      key: ValueKey<String>('$label-${value.name}'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: <DropdownMenuItem<T>>[
        for (final item in values)
          DropdownMenuItem<T>(value: item, child: Text(labelFor(item))),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    ),
  );

  Widget _numberField({
    required String label,
    required TextEditingController controller,
    required ValueChanged<double> onParsed,
    bool allowDecimal = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(
          allowDecimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
        ),
      ],
      decoration: InputDecoration(labelText: label),
      onChanged: (value) {
        final parsed = double.tryParse(value);
        if (parsed != null) onParsed(parsed);
      },
    ),
  );

  Widget _bodyMassField({required String label}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: _bodyMassController,
      focusNode: _bodyMassFocusNode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      decoration: InputDecoration(labelText: label, errorText: _bodyMassError),
      onChanged: (_) {
        if (_bodyMassError != null) {
          setState(() => _bodyMassError = null);
        }
      },
      onSubmitted: (_) => _commitBodyMass(),
    ),
  );

  String _bodyMassText(ReviewFormState state) {
    final value = state.displayBodyMass;
    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(1);
  }
}
