import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/presentation/count_text.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/host_text.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/screens/projects/project_text.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

const String _contextSeparator = ' · ';

String describeApprovalRepository(String address, DeviceNames deviceNames) {
  if (parseLocalFolderAddress(address) == null) {
    return address;
  }
  final String folder = describeRepositoryPath(address);
  final String place = describeRepositoryPlace(address, deviceNames);
  return '$folder $place';
}

String _findWorkflowName(WorkflowId workflowId, List<Workflow> workflows) {
  return findRecord<Workflow>(
    workflows,
    matches: (Workflow workflow) => workflow.id == workflowId,
    kind: 'workflow',
    identifier: workflowId.value,
  ).name;
}

String _describeCommitCount(int commitCount) {
  return describeCount(commitCount, singular: 'commit', plural: 'commits');
}

String _describeAskingAgent(String? runLabel) {
  if (runLabel == null) {
    return 'An agent';
  }
  return 'The agent in $runLabel';
}

String describePushRequest({
  required String? runLabel,
  required int commitCount,
}) {
  final String commits = _describeCommitCount(commitCount);
  return '${_describeAskingAgent(runLabel)} wants to push $commits.';
}

String describeActionRequest({required String? runLabel}) {
  return '${_describeAskingAgent(runLabel)} asks before it does this.';
}

String describeApprovalTitle(ApprovalAction action, List<Workflow> workflows) {
  switch (action) {
    case PushCommitsAction(:final List<String> commits):
      final String commitCount = _describeCommitCount(commits.length);
      final String path = describeRepositoryPath(action.repository);
      return 'Push $commitCount to $path';
    case DeployAction(:final String target):
      return 'Deploy to $target';
    case DeleteBranchOrFilesAction(:final String what):
      return 'Delete $what in ${describeRepositoryPath(action.repository)}';
    case SignWorkflowAction(:final WorkflowId workflowId):
      return 'Sign workflow ${_findWorkflowName(workflowId, workflows)}';
  }
}

String describeDecisionReason({
  required ApprovalDecision decision,
  required ApprovalAction action,
  required List<Workflow> workflows,
}) {
  final String verb = switch (decision) {
    ApprovalDecision.approved => 'Approve',
    ApprovalDecision.denied => 'Deny',
  };
  return '$verb: ${describeApprovalTitle(action, workflows)}';
}

List<TextSegment> describeApprovalContext({
  required ApprovalAction action,
  required String? runLabel,
  required WorkflowChange? change,
}) {
  final List<String> parts = <String>[];
  if (runLabel != null) {
    parts.add(runLabel);
  }

  switch (action) {
    case PushCommitsAction(:final String branch):
      parts.add('branch $branch');
    case DeployAction():
    case DeleteBranchOrFilesAction():
      break;
    case SignWorkflowAction():
      if (change == null) {
        return const <TextSegment>[TextSegment('Not signed yet')];
      }
      return segmentHostNames(change.summary);
  }

  return <TextSegment>[TextSegment(parts.join(_contextSeparator))];
}

String describeWaitingApprovals(int count) {
  if (count < 1) {
    throw ArgumentError.value(count, 'count', 'Nothing is waiting');
  }
  if (count == 1) {
    return '1 waiting. It needs your passkey.';
  }
  return '$count waiting. Each one needs your passkey.';
}
