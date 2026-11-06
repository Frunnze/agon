import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import 'random_run_json.dart';
import 'wire_codec_properties.dart';

const List<WireCodec> approvalRecordCodecs = <WireCodec>[
  WireCodec(
    typeName: 'signed_decision',
    seed: 49350,
    buildJson: randomSignedDecisionJson,
    decode: SignedDecision.fromJson,
    requiredFields: <String>{
      'decision',
      'decided_by',
      'decided_at',
      'signature',
    },
    optionalFields: <String>{},
  ),
  WireCodec(
    typeName: 'approval_request',
    seed: 49360,
    buildJson: randomApprovalRequestJson,
    decode: ApprovalRequest.fromJson,
    requiredFields: <String>{'id', 'action', 'requested_by', 'requested_at'},
    optionalFields: <String>{'run_id', 'decision'},
  ),
];

const List<WireCodec> approvalActionCodecs = <WireCodec>[
  WireCodec(
    typeName: 'push_commits',
    seed: 49370,
    buildJson: _buildPushCommitsJson,
    decode: ApprovalAction.fromJson,
    requiredFields: <String>{'kind', 'repository', 'branch', 'commits'},
    optionalFields: <String>{},
  ),
  WireCodec(
    typeName: 'deploy',
    seed: 49380,
    buildJson: _buildDeployJson,
    decode: ApprovalAction.fromJson,
    requiredFields: <String>{'kind', 'target'},
    optionalFields: <String>{},
  ),
  WireCodec(
    typeName: 'delete_branch_or_files',
    seed: 49390,
    buildJson: _buildDeleteBranchOrFilesJson,
    decode: ApprovalAction.fromJson,
    requiredFields: <String>{'kind', 'repository', 'what'},
    optionalFields: <String>{},
  ),
  WireCodec(
    typeName: 'sign_workflow',
    seed: 49400,
    buildJson: _buildSignWorkflowJson,
    decode: ApprovalAction.fromJson,
    requiredFields: <String>{'kind', 'workflow_id'},
    optionalFields: <String>{},
  ),
  WireCodec(
    typeName: 'run_command',
    seed: 49410,
    buildJson: randomRunCommandJson,
    decode: ApprovalAction.fromJson,
    requiredFields: <String>{'kind', 'tool', 'summary', 'command'},
    optionalFields: <String>{},
  ),
  WireCodec(
    typeName: 'improve_skill',
    seed: 49420,
    buildJson: randomImproveSkillJson,
    decode: ApprovalAction.fromJson,
    requiredFields: <String>{
      'kind',
      'skill_id',
      'summary',
      'proposed_instructions',
    },
    optionalFields: <String>{},
  ),
];

JsonObject _buildPushCommitsJson(Random random) {
  return _buildActionJsonOfKind(random, PushCommits.kind);
}

JsonObject _buildDeployJson(Random random) {
  return _buildActionJsonOfKind(random, Deploy.kind);
}

JsonObject _buildDeleteBranchOrFilesJson(Random random) {
  return _buildActionJsonOfKind(random, DeleteBranchOrFiles.kind);
}

JsonObject _buildSignWorkflowJson(Random random) {
  return _buildActionJsonOfKind(random, SignWorkflow.kind);
}

JsonObject _buildActionJsonOfKind(Random random, String kind) {
  while (true) {
    final JsonObject actionJson = randomApprovalActionJson(random);
    if (actionJson['kind'] == kind) {
      return actionJson;
    }
  }
}
