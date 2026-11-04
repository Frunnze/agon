import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/scope.dart';

enum AgentKind {
  claudeCode('Claude Code'),
  codex('Codex'),
  geminiCli('Gemini CLI');

  const AgentKind(this.label);

  final String label;
}

enum StepKind { agent, person }

final class CanvasPosition {
  const CanvasPosition({required this.horizontal, required this.vertical});

  final double horizontal;
  final double vertical;
}

final class WorkflowAgent {
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

  WorkflowAgent copyWith({
    String? name,
    AgentKind? kind,
    String? task,
    RunnerTarget? runsOn,
    List<SkillId>? skills,
    bool? usesAutomaticSkills,
    CanvasPosition? position,
  }) {
    return WorkflowAgent(
      id: id,
      name: name ?? this.name,
      stepKind: stepKind,
      kind: kind ?? this.kind,
      task: task ?? this.task,
      runsOn: runsOn ?? this.runsOn,
      skills: skills ?? this.skills,
      usesAutomaticSkills: usesAutomaticSkills ?? this.usesAutomaticSkills,
      approvalPolicy: approvalPolicy,
      position: position ?? this.position,
    );
  }

  WorkflowAgent withApprovalPolicy(ApprovalPolicy? nextApprovalPolicy) {
    return WorkflowAgent(
      id: id,
      name: name,
      stepKind: stepKind,
      kind: kind,
      task: task,
      runsOn: runsOn,
      skills: skills,
      usesAutomaticSkills: usesAutomaticSkills,
      approvalPolicy: nextApprovalPolicy,
      position: position,
    );
  }
}

final class AgentConnection {
  const AgentConnection({
    required this.from,
    required this.to,
    required this.condition,
    required this.roundLimit,
  });

  final WorkflowAgentId from;
  final WorkflowAgentId to;
  final String? condition;
  final int? roundLimit;

  bool get isLoop => roundLimit != null;

  bool joinsSameSteps(AgentConnection other) {
    return other.from == from && other.to == to;
  }

  AgentConnection withCondition(String? nextCondition) {
    return AgentConnection(
      from: from,
      to: to,
      condition: nextCondition,
      roundLimit: roundLimit,
    );
  }

  AgentConnection withRoundLimit(int? nextRoundLimit) {
    return AgentConnection(
      from: from,
      to: to,
      condition: condition,
      roundLimit: nextRoundLimit,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AgentConnection &&
        joinsSameSteps(other) &&
        other.condition == condition &&
        other.roundLimit == roundLimit;
  }

  @override
  int get hashCode => Object.hash(from, to, condition, roundLimit);
}

final class WorkflowSignature {
  WorkflowSignature({
    required this.signedBy,
    required List<int> signature,
    required this.signedDocument,
    required this.signedAt,
  }) : signature = List<int>.unmodifiable(signature);

  final DeviceId signedBy;
  final List<int> signature;
  final String signedDocument;
  final DateTime signedAt;
}

enum SignatureState { signed, notSignedYet, changedNotSigned }

final class Workflow {
  Workflow({
    required this.id,
    required this.name,
    required this.availability,
    required List<WorkflowAgent> agents,
    required List<AgentConnection> connections,
    required this.signature,
  }) : agents = List<WorkflowAgent>.unmodifiable(agents),
       connections = List<AgentConnection>.unmodifiable(connections);

  final WorkflowId id;
  final String name;
  final WorkspaceScope availability;
  final List<WorkflowAgent> agents;
  final List<AgentConnection> connections;
  final WorkflowSignature? signature;

  WorkflowAgent findAgent(WorkflowAgentId agentId) {
    for (final WorkflowAgent agent in agents) {
      if (agent.id == agentId) {
        return agent;
      }
    }
    throw StateError('Workflow $name has no agent $agentId');
  }

  Workflow withName(String newName) {
    return Workflow(
      id: id,
      name: newName,
      availability: availability,
      agents: agents,
      connections: connections,
      signature: signature,
    );
  }

  Workflow withGraph({
    required List<WorkflowAgent> agents,
    required List<AgentConnection> connections,
  }) {
    return Workflow(
      id: id,
      name: name,
      availability: availability,
      agents: agents,
      connections: connections,
      signature: signature,
    );
  }
}

final class WorkflowDifference {
  const WorkflowDifference({required this.subject, required this.change});

  final String subject;
  final String change;
}

final class WorkflowChange {
  WorkflowChange({
    required this.workflowId,
    required this.changedBy,
    required this.changedAt,
    required this.summary,
    required List<WorkflowDifference> differences,
    required this.signedDocument,
    required this.changedDocument,
  }) : differences = List<WorkflowDifference>.unmodifiable(differences);

  final WorkflowId workflowId;
  final DeviceId changedBy;
  final DateTime changedAt;
  final String summary;
  final List<WorkflowDifference> differences;
  final String signedDocument;
  final String changedDocument;
}
