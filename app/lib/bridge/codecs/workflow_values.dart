import 'package:agent_orchestration/bridge/codecs/approval_values.dart';
import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/identifier_codecs.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

enum AgentKind implements WireNamed {
  claudeCode('claude_code'),
  codex('codex'),
  geminiCli('gemini_cli');

  const AgentKind(this.wireName);

  @override
  final String wireName;

  static AgentKind decode(Object? json) => decodeWireName(values, json);
}

enum StepKind implements WireNamed {
  agent('agent'),
  person('person');

  const StepKind(this.wireName);

  @override
  final String wireName;

  static StepKind decode(Object? json) => decodeWireName(values, json);
}

final class CanvasPosition implements JsonEncodable {
  const CanvasPosition({required this.horizontal, required this.vertical});

  factory CanvasPosition.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return CanvasPosition(
      horizontal: readField(fields, 'horizontal', decodeNumber),
      vertical: readField(fields, 'vertical', decodeNumber),
    );
  }

  final double horizontal;
  final double vertical;

  @override
  JsonObject toJson() {
    return <String, Object?>{'horizontal': horizontal, 'vertical': vertical};
  }
}

final class WorkflowAgent implements JsonEncodable {
  WorkflowAgent({
    required this.id,
    required this.name,
    required this.stepKind,
    required this.kind,
    required this.task,
    required this.runsOn,
    required List<SkillId> skills,
    required this.usesAutomaticSkills,
    required this.approvalPolicy,
    required this.position,
  }) : skills = List<SkillId>.unmodifiable(skills);

  factory WorkflowAgent.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return WorkflowAgent(
      id: readField(fields, 'id', decodeWorkflowAgentId),
      name: readField(fields, 'name', decodeText),
      stepKind:
          readOptionalField(fields, 'step_kind', StepKind.decode) ??
          StepKind.agent,
      kind: readOptionalField(fields, 'kind', AgentKind.decode),
      task: readField(fields, 'task', decodeText),
      runsOn: readField(fields, 'runs_on', RunnerTarget.fromJson),
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
      position: readField(fields, 'position', CanvasPosition.fromJson),
    );
  }

  final WorkflowAgentId id;
  final String name;
  final StepKind stepKind;
  final AgentKind? kind;
  final String task;
  final RunnerTarget runsOn;
  final List<SkillId> skills;
  final bool usesAutomaticSkills;
  final ApprovalPolicy? approvalPolicy;
  final CanvasPosition position;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'id': id.value,
      'name': name,
      'step_kind': stepKind.wireName,
      'kind': kind?.wireName,
      'task': task,
      'runs_on': runsOn.toJson(),
      'skills': skills,
      'uses_automatic_skills': usesAutomaticSkills,
      'approval_policy': approvalPolicy?.wireName,
      'position': position.toJson(),
    };
  }
}

final class AgentConnection implements JsonEncodable {
  const AgentConnection({
    required this.from,
    required this.to,
    required this.condition,
    required this.roundLimit,
  });

  factory AgentConnection.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return AgentConnection(
      from: readField(fields, 'from', decodeWorkflowAgentId),
      to: readField(fields, 'to', decodeWorkflowAgentId),
      condition: readOptionalField(fields, 'condition', decodeText),
      roundLimit: readOptionalField(fields, 'round_limit', decodeInteger),
    );
  }

  final WorkflowAgentId from;
  final WorkflowAgentId to;
  final String? condition;
  final int? roundLimit;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'from': from.value,
      'to': to.value,
      'condition': condition,
      'round_limit': roundLimit,
    };
  }
}

final class WorkflowSignature implements JsonEncodable {
  WorkflowSignature({
    required this.signedBy,
    required List<int> signature,
    required this.signedDocument,
  }) : signature = List<int>.unmodifiable(signature);

  factory WorkflowSignature.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return WorkflowSignature(
      signedBy: readField(fields, 'signed_by', decodeDeviceId),
      signature: readListField(fields, 'signature', decodeInteger),
      signedDocument: readField(fields, 'signed_document', decodeText),
    );
  }

  final DeviceId signedBy;
  final List<int> signature;
  final String signedDocument;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'signed_by': signedBy.value,
      'signature': signature,
      'signed_document': signedDocument,
    };
  }
}

final class Workflow implements JsonEncodable {
  Workflow({
    required this.id,
    required this.name,
    required this.availability,
    required List<WorkflowAgent> agents,
    required List<AgentConnection> connections,
    required this.signature,
  }) : agents = List<WorkflowAgent>.unmodifiable(agents),
       connections = List<AgentConnection>.unmodifiable(connections);

  factory Workflow.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return Workflow(
      id: readField(fields, 'id', decodeWorkflowId),
      name: readField(fields, 'name', decodeText),
      availability: readField(fields, 'availability', WorkspaceScope.fromJson),
      agents: readListField(fields, 'agents', WorkflowAgent.fromJson),
      connections: readListField(
        fields,
        'connections',
        AgentConnection.fromJson,
      ),
      signature: readOptionalField(
        fields,
        'signature',
        WorkflowSignature.fromJson,
      ),
    );
  }

  final WorkflowId id;
  final String name;
  final WorkspaceScope availability;
  final List<WorkflowAgent> agents;
  final List<AgentConnection> connections;
  final WorkflowSignature? signature;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'id': id.value,
      'name': name,
      'availability': availability.toJson(),
      'agents': encodeList(agents),
      'connections': encodeList(connections),
      'signature': signature?.toJson(),
    };
  }
}
