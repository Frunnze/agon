import 'package:agent_orchestration/bridge/codecs/identifier_codecs.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

final class OpenPersonStep implements JsonEncodable {
  OpenPersonStep({
    required this.runId,
    required this.taskId,
    required this.workspaceId,
    required this.stepName,
    required this.question,
    required List<String> choices,
    required this.askedAt,
  }) : choices = List<String>.unmodifiable(choices);

  factory OpenPersonStep.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return OpenPersonStep(
      runId: readField(fields, 'run_id', decodeRunId),
      taskId: readField(fields, 'task_id', decodeTaskId),
      workspaceId: readField(fields, 'workspace_id', decodeWorkspaceId),
      stepName: readField(fields, 'step_name', decodeText),
      question: readField(fields, 'question', decodeText),
      choices: readListField(fields, 'choices', decodeText),
      askedAt: readOptionalField(fields, 'asked_at', decodeMoment),
    );
  }

  final RunId runId;
  final TaskId taskId;
  final WorkspaceId workspaceId;
  final String stepName;
  final String question;
  final List<String> choices;
  final DateTime? askedAt;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'run_id': runId.value,
      'task_id': taskId.value,
      'workspace_id': workspaceId.value,
      'step_name': stepName,
      'question': question,
      'choices': choices,
      'asked_at': encodeOptionalMoment(askedAt),
    };
  }
}
