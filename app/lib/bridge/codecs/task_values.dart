import 'package:agent_orchestration/bridge/codecs/approval_values.dart';
import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/identifier_codecs.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/schedule_values.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_values.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

enum TaskStatus implements WireNamed {
  toDo('to_do'),
  running('running'),
  waitingForApproval('waiting_for_approval'),
  failed('failed'),
  done('done');

  const TaskStatus(this.wireName);

  @override
  final String wireName;

  static TaskStatus decode(Object? json) => decodeWireName(values, json);
}

enum TaskStart implements WireNamed {
  now('now'),
  later('later');

  const TaskStart(this.wireName);

  @override
  final String wireName;
}

sealed class TaskDoer implements JsonEncodable {
  const TaskDoer();

  factory TaskDoer.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    final String kind = readField(fields, 'kind', decodeText);
    return switch (kind) {
      OneAgent.kind => OneAgent(
        agent: readField(fields, 'agent', AgentKind.decode),
      ),
      WorkflowDoer.kind => WorkflowDoer(
        workflowId: readField(fields, 'workflow_id', decodeWorkflowId),
      ),
      _ => throw FormatException('unknown task doer $kind'),
    };
  }
}

final class OneAgent extends TaskDoer {
  const OneAgent({required this.agent});

  static const String kind = 'one_agent';

  final AgentKind agent;

  @override
  JsonObject toJson() {
    return <String, Object?>{'kind': kind, 'agent': agent.wireName};
  }
}

final class WorkflowDoer extends TaskDoer {
  const WorkflowDoer({required this.workflowId});

  static const String kind = 'workflow';

  final WorkflowId workflowId;

  @override
  JsonObject toJson() {
    return <String, Object?>{'kind': kind, 'workflow_id': workflowId.value};
  }
}

final class Task implements JsonEncodable {
  Task({
    required this.id,
    required this.title,
    required this.details,
    required this.projectId,
    required this.doer,
    required this.runsOn,
    required this.agentPlace,
    required List<SkillId> skills,
    required this.usesAutomaticSkills,
    required this.approvalPolicy,
    required this.schedule,
    required this.status,
    required this.createdAt,
  }) : skills = List<SkillId>.unmodifiable(skills);

  factory Task.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return Task(
      id: readField(fields, 'id', decodeTaskId),
      title: readField(fields, 'title', decodeText),
      details: readField(fields, 'details', decodeText),
      projectId: readField(fields, 'project_id', decodeProjectId),
      doer: readField(fields, 'doer', TaskDoer.fromJson),
      runsOn: readField(fields, 'runs_on', RunnerTarget.fromJson),
      agentPlace: readField(fields, 'agent_place', AgentPlace.decode),
      skills: readListField(fields, 'skills', decodeSkillId),
      usesAutomaticSkills: readField(
        fields,
        'uses_automatic_skills',
        decodeFlag,
      ),
      approvalPolicy: readOptionalField(
        fields,
        'approval_policy',
        ApprovalPolicy.decode,
      ),
      schedule: readOptionalField(fields, 'schedule', Schedule.fromJson),
      status: readField(fields, 'status', TaskStatus.decode),
      createdAt: readField(fields, 'created_at', decodeMoment),
    );
  }

  final TaskId id;
  final String title;
  final String details;
  final ProjectId projectId;
  final TaskDoer doer;
  final RunnerTarget runsOn;
  final AgentPlace agentPlace;
  final List<SkillId> skills;
  final bool usesAutomaticSkills;
  final ApprovalPolicy? approvalPolicy;
  final Schedule? schedule;
  final TaskStatus status;
  final DateTime createdAt;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'id': id.value,
      'title': title,
      'details': details,
      'project_id': projectId.value,
      'doer': doer.toJson(),
      'runs_on': runsOn.toJson(),
      'agent_place': agentPlace.wireName,
      'skills': skills,
      'uses_automatic_skills': usesAutomaticSkills,
      'approval_policy': approvalPolicy?.wireName,
      'schedule': schedule?.toJson(),
      'status': status.wireName,
      'created_at': encodeMoment(createdAt),
    };
  }
}

final class TaskSummary implements JsonEncodable {
  const TaskSummary({
    required this.toDo,
    required this.running,
    required this.waitingForApproval,
    required this.failed,
    required this.done,
  });

  factory TaskSummary.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return TaskSummary(
      toDo: readField(fields, 'to_do', decodeInteger),
      running: readField(fields, 'running', decodeInteger),
      waitingForApproval: readField(
        fields,
        'waiting_for_approval',
        decodeInteger,
      ),
      failed: readField(fields, 'failed', decodeInteger),
      done: readField(fields, 'done', decodeInteger),
    );
  }

  final int toDo;
  final int running;
  final int waitingForApproval;
  final int failed;
  final int done;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'to_do': toDo,
      'running': running,
      'waiting_for_approval': waitingForApproval,
      'failed': failed,
      'done': done,
    };
  }
}
