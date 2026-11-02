import 'package:agent_orchestration/data/models/identifiers.dart';

sealed class ApprovalAction {
  const ApprovalAction();
}

final class PushCommitsAction extends ApprovalAction {
  PushCommitsAction({
    required this.repository,
    required this.branch,
    required List<String> commits,
  }) : commits = List<String>.unmodifiable(commits);

  final String repository;
  final String branch;
  final List<String> commits;
}

final class DeployAction extends ApprovalAction {
  const DeployAction({required this.target});

  final String target;
}

final class DeleteBranchOrFilesAction extends ApprovalAction {
  const DeleteBranchOrFilesAction({
    required this.repository,
    required this.what,
  });

  final String repository;
  final String what;
}

final class SignWorkflowAction extends ApprovalAction {
  const SignWorkflowAction({required this.workflowId});

  final WorkflowId workflowId;
}

enum ApprovalPolicy { askBeforeRiskyActions, neverAsk }

enum ApprovalDecision { approved, denied }

final class SignedDecision {
  SignedDecision({
    required this.decision,
    required this.decidedBy,
    required this.decidedAt,
    required List<int> signature,
  }) : signature = List<int>.unmodifiable(signature);

  final ApprovalDecision decision;
  final DeviceId decidedBy;
  final DateTime decidedAt;
  final List<int> signature;
}

final class ApprovalRequest {
  const ApprovalRequest({
    required this.id,
    required this.runId,
    required this.action,
    required this.requestedBy,
    required this.requestedAt,
    required this.decision,
  });

  final ApprovalId id;
  final RunId? runId;
  final ApprovalAction action;
  final DeviceId requestedBy;
  final DateTime requestedAt;
  final SignedDecision? decision;

  bool get isPending => decision == null;

  ApprovalRequest withDecision(SignedDecision signedDecision) {
    return ApprovalRequest(
      id: id,
      runId: runId,
      action: action,
      requestedBy: requestedBy,
      requestedAt: requestedAt,
      decision: signedDecision,
    );
  }
}
