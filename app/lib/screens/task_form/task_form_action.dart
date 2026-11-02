import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

sealed class TaskFormAction {
  const TaskFormAction({
    required this.label,
    required this.tone,
    required this.icon,
  });

  final String label;
  final ButtonTone tone;
  final AppIconKind? icon;
}

final class SubmitFormAction extends TaskFormAction {
  const SubmitFormAction({
    required super.label,
    required super.tone,
    required this.onSubmitted,
    super.icon,
  });

  final Future<void> Function(TaskFormValues values) onSubmitted;
}

final class LeaveFormAction extends TaskFormAction {
  const LeaveFormAction({required super.label, required this.onPressed})
    : super(tone: ButtonTone.secondary, icon: null);

  final VoidCallback onPressed;
}
