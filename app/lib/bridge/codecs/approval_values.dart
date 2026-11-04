import 'package:agent_orchestration/bridge/codecs/identifier_codecs.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

const String unlabelledCommandSummary = 'Use a tool';

enum ApprovalPolicy implements WireNamed {
  askBeforeRiskyActions('ask_before_risky_actions'),
  neverAsk('never_ask');

  const ApprovalPolicy(this.wireName);

  @override
  final String wireName;

  static ApprovalPolicy decode(Object? json) {
    return decodeWireName(values, json);
  }
}

enum ApprovalDecision implements WireNamed {
  approved('approved'),
  denied('denied');

  const ApprovalDecision(this.wireName);

  @override
  final String wireName;

  static ApprovalDecision decode(Object? json) {
    return decodeWireName(values, json);
  }
}

sealed class ApprovalAction implements JsonEncodable {
  const ApprovalAction();

  factory ApprovalAction.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    final String kind = readField(fields, 'kind', decodeText);
    return switch (kind) {
      PushCommits.kind => PushCommits(
        repository: readField(fields, 'repository', decodeText),
        branch: readField(fields, 'branch', decodeText),
        commits: readListField(fields, 'commits', decodeText),
      ),
      Deploy.kind => Deploy(target: readField(fields, 'target', decodeText)),
      DeleteBranchOrFiles.kind => DeleteBranchOrFiles(
        repository: readField(fields, 'repository', decodeText),
        what: readField(fields, 'what', decodeText),
      ),
      SignWorkflow.kind => SignWorkflow(
        workflowId: readField(fields, 'workflow_id', decodeWorkflowId),
      ),
      RunCommand.kind => RunCommand(
        tool: readField(fields, 'tool', decodeText),
        summary:
            readOptionalField(fields, 'summary', decodeText) ??
            unlabelledCommandSummary,
        command: readField(fields, 'command', decodeText),
      ),
      ImproveSkill.kind => ImproveSkill(
        skillId: readField(fields, 'skill_id', decodeSkillId),
        summary: readField(fields, 'summary', decodeText),
        proposedInstructions: readField(
          fields,
          'proposed_instructions',
          decodeText,
        ),
      ),
      _ => throw FormatException('unknown approval action $kind'),
    };
  }
}

final class PushCommits extends ApprovalAction {
  PushCommits({
    required this.repository,
    required this.branch,
    required List<String> commits,
  }) : commits = List<String>.unmodifiable(commits);

  static const String kind = 'push_commits';

  final String repository;
  final String branch;
  final List<String> commits;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'kind': kind,
      'repository': repository,
      'branch': branch,
      'commits': commits,
    };
  }
}

final class Deploy extends ApprovalAction {
  const Deploy({required this.target});

  static const String kind = 'deploy';

  final String target;

  @override
  JsonObject toJson() => <String, Object?>{'kind': kind, 'target': target};
}

final class DeleteBranchOrFiles extends ApprovalAction {
  const DeleteBranchOrFiles({required this.repository, required this.what});

  static const String kind = 'delete_branch_or_files';

  final String repository;
  final String what;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'kind': kind,
      'repository': repository,
      'what': what,
    };
  }
}

final class SignWorkflow extends ApprovalAction {
  const SignWorkflow({required this.workflowId});

  static const String kind = 'sign_workflow';

  final WorkflowId workflowId;

  @override
  JsonObject toJson() {
    return <String, Object?>{'kind': kind, 'workflow_id': workflowId.value};
  }
}

final class RunCommand extends ApprovalAction {
  const RunCommand({
    required this.tool,
    required this.summary,
    required this.command,
  });

  static const String kind = 'run_command';

  final String tool;
  final String summary;
  final String command;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'kind': kind,
      'tool': tool,
      'summary': summary,
      'command': command,
    };
  }
}

final class ImproveSkill extends ApprovalAction {
  const ImproveSkill({
    required this.skillId,
    required this.summary,
    required this.proposedInstructions,
  });

  static const String kind = 'improve_skill';

  final SkillId skillId;
  final String summary;
  final String proposedInstructions;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'kind': kind,
      'skill_id': skillId.value,
      'summary': summary,
      'proposed_instructions': proposedInstructions,
    };
  }
}

final class SignedDecision implements JsonEncodable {
  SignedDecision({
    required this.decision,
    required this.decidedBy,
    required this.decidedAt,
    required List<int> signature,
  }) : signature = List<int>.unmodifiable(signature);

  factory SignedDecision.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return SignedDecision(
      decision: readField(fields, 'decision', ApprovalDecision.decode),
      decidedBy: readField(fields, 'decided_by', decodeDeviceId),
      decidedAt: readField(fields, 'decided_at', decodeMoment),
      signature: readListField(fields, 'signature', decodeInteger),
    );
  }

  final ApprovalDecision decision;
  final DeviceId decidedBy;
  final DateTime decidedAt;
  final List<int> signature;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'decision': decision.wireName,
      'decided_by': decidedBy.value,
      'decided_at': encodeMoment(decidedAt),
      'signature': signature,
    };
  }
}

final class ApprovalRequest implements JsonEncodable {
  const ApprovalRequest({
    required this.id,
    required this.runId,
    required this.action,
    required this.requestedBy,
    required this.requestedAt,
    required this.decision,
  });

  factory ApprovalRequest.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return ApprovalRequest(
      id: readField(fields, 'id', decodeApprovalId),
      runId: readOptionalField(fields, 'run_id', decodeRunId),
      action: readField(fields, 'action', ApprovalAction.fromJson),
      requestedBy: readField(fields, 'requested_by', decodeDeviceId),
      requestedAt: readField(fields, 'requested_at', decodeMoment),
      decision: readOptionalField(fields, 'decision', SignedDecision.fromJson),
    );
  }

  final ApprovalId id;
  final RunId? runId;
  final ApprovalAction action;
  final DeviceId requestedBy;
  final DateTime requestedAt;
  final SignedDecision? decision;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'id': id.value,
      'run_id': runId?.value,
      'action': action.toJson(),
      'requested_by': requestedBy.value,
      'requested_at': encodeMoment(requestedAt),
      'decision': decision?.toJson(),
    };
  }
}
