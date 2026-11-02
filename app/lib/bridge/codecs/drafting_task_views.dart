import 'package:agent_orchestration/bridge/codecs/identifier_codecs.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_values.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

final class DraftingTaskView implements JsonEncodable {
  const DraftingTaskView({required this.taskId, required this.drafter});

  factory DraftingTaskView.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return DraftingTaskView(
      taskId: readField(fields, 'task_id', decodeTaskId),
      drafter: readField(fields, 'drafter', AgentKind.decode),
    );
  }

  final TaskId taskId;
  final AgentKind drafter;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'task_id': taskId.value,
      'drafter': drafter.wireName,
    };
  }
}

final class WorkflowAgentTaskView implements JsonEncodable {
  const WorkflowAgentTaskView({
    required this.workflowId,
    required this.taskId,
    required this.drafter,
  });

  factory WorkflowAgentTaskView.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return WorkflowAgentTaskView(
      workflowId: readField(fields, 'workflow_id', decodeWorkflowId),
      taskId: readField(fields, 'task_id', decodeTaskId),
      drafter: readField(fields, 'drafter', AgentKind.decode),
    );
  }

  final WorkflowId workflowId;
  final TaskId taskId;
  final AgentKind drafter;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'workflow_id': workflowId.value,
      'task_id': taskId.value,
      'drafter': drafter.wireName,
    };
  }
}
