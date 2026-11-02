import 'package:agent_orchestration/data/models/task.dart';

const String _summarySeparator = ' · ';

const List<(TaskStatus, String)> _summaryOrder = <(TaskStatus, String)>[
  (TaskStatus.running, 'running'),
  (TaskStatus.waitingForApproval, 'waiting for approval'),
  (TaskStatus.failed, 'failed'),
  (TaskStatus.toDo, 'to do'),
];

String describeTaskSummary(List<Task> tasks) {
  final List<String> parts = <String>[];

  for (final (TaskStatus status, String phrase) in _summaryOrder) {
    final int count = tasks.where((Task task) => task.status == status).length;
    if (count > 0) {
      parts.add('$count $phrase');
    }
  }

  return parts.join(_summarySeparator);
}
