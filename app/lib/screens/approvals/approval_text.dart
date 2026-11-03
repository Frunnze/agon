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
const String _commandToolName = 'Bash';

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

String describeSkillChangeRequest({required String? runLabel}) {
  final String askingAgent = _describeAskingAgent(runLabel);
  return '$askingAgent wants to change these instructions.';
}

String describeToolUse(String tool) {
  if (tool == _commandToolName) {
    return 'Run a command';
  }
  return 'Use $tool';
}

String describeToolUseRequest({
  required String? runLabel,
  required String tool,
}) {
  final String askingAgent = _describeAskingAgent(runLabel);
  if (tool == _commandToolName) {
    return '$askingAgent wants to run a command.';
  }
  return '$askingAgent wants to use $tool.';
}

List<TextSegment> describeApprovalTitleSegments(
  ApprovalAction action,
  List<Workflow> workflows,
) {
  if (action is RunCommandAction) {
    return <TextSegment>[
      TextSegment('${describeToolUse(action.tool)}: '),
      TextSegment.monospace(action.command),
    ];
  }
  return <TextSegment>[TextSegment(describeApprovalTitle(action, workflows))];
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
    case RunCommandAction(:final String tool, :final String command):
      return '${describeToolUse(tool)}: $command';
    case ImproveSkillAction(:final SkillChangePreview? preview):
      if (preview == null) {
        return 'Improve a deleted skill';
      }
      return 'Improve skill ${preview.skillName}';
  }
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
    case RunCommandAction():
      break;
    case ImproveSkillAction(:final String summary):
      parts.add(summary);
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
    return '1 waiting. It needs your approval.';
  }
  return '$count waiting. Each one needs your approval.';
}

String _countWords(int count, String singular, String plural) {
  return count == 1 ? '1 $singular' : '$count $plural';
}

String describeWaitingWork({
  required int approvalCount,
  required int questionCount,
}) {
  if (questionCount == 0) {
    return describeWaitingApprovals(approvalCount);
  }

  final String questions = _countWords(questionCount, 'question', 'questions');
  if (approvalCount == 0) {
    return '$questions waiting for your answer';
  }
  final String approvals = _countWords(approvalCount, 'approval', 'approvals');
  return '$questions and $approvals waiting';
}
