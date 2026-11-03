import 'package:agent_orchestration/data/models/identifiers.dart';

final class OpenPersonStep {
  OpenPersonStep({
    required this.runId,
    required this.taskId,
    required this.workspaceId,
    required this.stepName,
    required this.question,
    required List<String> choices,
    required this.askedAt,
  }) : choices = List<String>.unmodifiable(choices);

  final RunId runId;
  final TaskId taskId;
  final WorkspaceId workspaceId;
  final String stepName;
  final String question;
  final List<String> choices;
  final DateTime? askedAt;
}
