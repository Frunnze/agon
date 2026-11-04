import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

sealed class FormAction<V> {
  const FormAction({
    required this.label,
    required this.tone,
    required this.icon,
  });

  final String label;
  final ButtonTone tone;
  final AppIconKind? icon;
}

final class SubmitFormAction<V> extends FormAction<V> {
  const SubmitFormAction({
    required super.label,
    required super.tone,
    required this.onSubmitted,
    super.icon,
  });

  final Future<void> Function(V values) onSubmitted;
}

final class LeaveFormAction<V> extends FormAction<V> {
  const LeaveFormAction({required super.label, required this.onPressed})
    : super(tone: ButtonTone.secondary, icon: null);

  final VoidCallback onPressed;
}

class FormActionButtons<V> extends StatelessWidget {
  const FormActionButtons({
    required this.actions,
    required this.isSubmitting,
    required this.onSubmit,
    super.key,
  });

  final List<FormAction<V>> actions;
  final bool isSubmitting;
  final ValueChanged<SubmitFormAction<V>> onSubmit;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.space2,
      runSpacing: AppSpacing.space2,
      children: <Widget>[
        for (final FormAction<V> action in actions)
          AppButton(
            label: action.label,
            tone: action.tone,
            icon: action.icon,
            onPressed: isSubmitting ? null : () => _run(action),
          ),
      ],
    );
  }

  void _run(FormAction<V> action) {
    switch (action) {
      case LeaveFormAction<V>(:final VoidCallback onPressed):
        onPressed();
      case SubmitFormAction<V>():
        onSubmit(action);
    }
  }
}
