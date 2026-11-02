import 'package:agent_orchestration/bridge/codecs/approval_values.dart'
    as node;
import 'package:agent_orchestration/data/models/approval.dart';

ApprovalDecision mapApprovalDecisionFromNode(node.ApprovalDecision decision) {
  return switch (decision) {
    node.ApprovalDecision.approved => ApprovalDecision.approved,
    node.ApprovalDecision.denied => ApprovalDecision.denied,
  };
}

node.ApprovalDecision mapApprovalDecisionToNode(ApprovalDecision decision) {
  return switch (decision) {
    ApprovalDecision.approved => node.ApprovalDecision.approved,
    ApprovalDecision.denied => node.ApprovalDecision.denied,
  };
}

ApprovalAction mapApprovalActionFromNode(node.ApprovalAction action) {
  return switch (action) {
    node.PushCommits() => PushCommitsAction(
      repository: action.repository,
      branch: action.branch,
      commits: action.commits,
    ),
    node.Deploy() => DeployAction(target: action.target),
    node.DeleteBranchOrFiles() => DeleteBranchOrFilesAction(
      repository: action.repository,
      what: action.what,
    ),
    node.SignWorkflow() => SignWorkflowAction(workflowId: action.workflowId),
  };
}

SignedDecision mapSignedDecisionFromNode(node.SignedDecision decision) {
  return SignedDecision(
    decision: mapApprovalDecisionFromNode(decision.decision),
    decidedBy: decision.decidedBy,
    decidedAt: decision.decidedAt,
    signature: decision.signature,
  );
}

ApprovalRequest mapApprovalRequestFromNode(node.ApprovalRequest request) {
  final node.SignedDecision? wireDecision = request.decision;
  final SignedDecision? decision = wireDecision == null
      ? null
      : mapSignedDecisionFromNode(wireDecision);

  return ApprovalRequest(
    id: request.id,
    runId: request.runId,
    action: mapApprovalActionFromNode(request.action),
    requestedBy: request.requestedBy,
    requestedAt: request.requestedAt,
    decision: decision,
  );
}
