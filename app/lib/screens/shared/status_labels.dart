import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

StatusLabel buildTaskStatusLabel(TaskStatus status) {
  switch (status) {
    case TaskStatus.toDo:
      return const StatusLabel(
        text: 'To do',
        tone: StatusTone.muted,
        icon: AppIconKind.clock,
      );
    case TaskStatus.running:
      return const StatusLabel(
        text: 'Running',
        tone: StatusTone.normal,
        icon: AppIconKind.spinner,
      );
    case TaskStatus.waitingForApproval:
      return const StatusLabel(
        text: 'Waiting for approval',
        tone: StatusTone.attention,
        icon: AppIconKind.approval,
      );
    case TaskStatus.failed:
      return const StatusLabel(
        text: 'Failed',
        tone: StatusTone.danger,
        icon: AppIconKind.alert,
      );
    case TaskStatus.done:
      return const StatusLabel(
        text: 'Done',
        tone: StatusTone.muted,
        icon: AppIconKind.check,
      );
  }
}

StatusLabel buildJobLastRunLabel(TaskStatus status) {
  switch (status) {
    case TaskStatus.toDo:
      return const StatusLabel(
        text: 'Not run yet',
        tone: StatusTone.muted,
        icon: AppIconKind.clock,
      );
    case TaskStatus.done:
      return const StatusLabel(
        text: 'Passed',
        tone: StatusTone.muted,
        icon: AppIconKind.check,
      );
    case TaskStatus.running:
    case TaskStatus.waitingForApproval:
    case TaskStatus.failed:
      return buildTaskStatusLabel(status);
  }
}

StatusLabel buildStepStatusLabel(StepStatus status) {
  switch (status) {
    case StepStatus.waiting:
      return const StatusLabel(
        text: 'Next',
        tone: StatusTone.muted,
        icon: AppIconKind.clock,
      );
    case StepStatus.running:
      return const StatusLabel(
        text: 'Running',
        tone: StatusTone.normal,
        icon: AppIconKind.spinner,
      );
    case StepStatus.waitingForApproval:
      return const StatusLabel(
        text: 'Waiting for approval',
        tone: StatusTone.attention,
        icon: AppIconKind.approval,
      );
    case StepStatus.done:
      return const StatusLabel(
        text: 'Done',
        tone: StatusTone.muted,
        icon: AppIconKind.check,
      );
    case StepStatus.failed:
      return const StatusLabel(
        text: 'Failed',
        tone: StatusTone.danger,
        icon: AppIconKind.alert,
      );
    case StepStatus.skipped:
      return const StatusLabel(
        text: 'Skipped',
        tone: StatusTone.muted,
        icon: AppIconKind.offline,
      );
  }
}
