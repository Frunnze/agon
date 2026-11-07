import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart';
import 'package:agent_orchestration/bridge/codecs/approval_views.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_run_json.dart';
import 'codec_rows.dart';

const List<ConstructorRow> approvalConstructorRows = <ConstructorRow>[
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'approval_action',
      buildJson: randomApprovalActionJson,
      decode: ApprovalAction.fromJson,
    ),
    rebuild: _rebuildApprovalAction,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'push_commits',
      buildJson: randomPushCommitsJson,
      decode: ApprovalAction.fromJson,
    ),
    rebuild: _rebuildApprovalAction,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'deploy',
      buildJson: randomDeployJson,
      decode: ApprovalAction.fromJson,
    ),
    rebuild: _rebuildApprovalAction,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'delete_branch_or_files',
      buildJson: randomDeleteBranchOrFilesJson,
      decode: ApprovalAction.fromJson,
    ),
    rebuild: _rebuildApprovalAction,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'sign_workflow',
      buildJson: randomSignWorkflowJson,
      decode: ApprovalAction.fromJson,
    ),
    rebuild: _rebuildApprovalAction,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'run_command',
      buildJson: randomRunCommandJson,
      decode: ApprovalAction.fromJson,
    ),
    rebuild: _rebuildApprovalAction,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'improve_skill',
      buildJson: randomImproveSkillJson,
      decode: ApprovalAction.fromJson,
    ),
    rebuild: _rebuildApprovalAction,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'approval_request',
      buildJson: randomApprovalRequestJson,
      decode: ApprovalRequest.fromJson,
    ),
    rebuild: _rebuildApprovalRequest,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'approval_view',
      buildJson: randomApprovalViewJson,
      decode: ApprovalView.fromJson,
    ),
    rebuild: _rebuildApprovalView,
  ),
];

const List<EncodableRow> approvalEncodableRows = <EncodableRow>[
  EncodableRow(
    typeName: 'signed_decision',
    buildJson: randomSignedDecisionJson,
    decode: SignedDecision.fromJson,
  ),
  EncodableRow(
    typeName: 'skill_change_view',
    buildJson: randomSkillChangeViewJson,
    decode: SkillChangeView.fromJson,
  ),
  EncodableRow(
    typeName: 'approvals_view',
    buildJson: randomApprovalsViewJson,
    decode: ApprovalsView.fromJson,
  ),
];

Object? randomPushCommitsJson(Random random) {
  return randomJsonOfKind<PushCommits>(
    random: random,
    buildJson: randomApprovalActionJson,
    decode: ApprovalAction.fromJson,
  );
}

Object? randomDeployJson(Random random) {
  return randomJsonOfKind<Deploy>(
    random: random,
    buildJson: randomApprovalActionJson,
    decode: ApprovalAction.fromJson,
  );
}

Object? randomDeleteBranchOrFilesJson(Random random) {
  return randomJsonOfKind<DeleteBranchOrFiles>(
    random: random,
    buildJson: randomApprovalActionJson,
    decode: ApprovalAction.fromJson,
  );
}

Object? randomSignWorkflowJson(Random random) {
  return randomJsonOfKind<SignWorkflow>(
    random: random,
    buildJson: randomApprovalActionJson,
    decode: ApprovalAction.fromJson,
  );
}

JsonEncodable _rebuildApprovalAction(JsonEncodable value) {
  final ApprovalAction action = value as ApprovalAction;
  return switch (action) {
    PushCommits() => PushCommits(
      repository: action.repository,
      branch: action.branch,
      commits: action.commits,
    ),
    Deploy() => Deploy(target: action.target),
    DeleteBranchOrFiles() => DeleteBranchOrFiles(
      repository: action.repository,
      what: action.what,
    ),
    SignWorkflow() => SignWorkflow(workflowId: action.workflowId),
    RunCommand() => RunCommand(
      tool: action.tool,
      summary: action.summary,
      command: action.command,
    ),
    ImproveSkill() => ImproveSkill(
      skillId: action.skillId,
      summary: action.summary,
      proposedInstructions: action.proposedInstructions,
    ),
  };
}

JsonEncodable _rebuildApprovalRequest(JsonEncodable value) {
  final ApprovalRequest request = value as ApprovalRequest;
  return ApprovalRequest(
    id: request.id,
    runId: request.runId,
    action: request.action,
    requestedBy: request.requestedBy,
    requestedAt: request.requestedAt,
    decision: request.decision,
  );
}

JsonEncodable _rebuildApprovalView(JsonEncodable value) {
  final ApprovalView view = value as ApprovalView;
  return ApprovalView(
    approval: view.approval,
    description: view.description,
    isWaiting: view.isWaiting,
    skillChange: view.skillChange,
  );
}
