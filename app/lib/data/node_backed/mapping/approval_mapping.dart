import 'package:agent_orchestration/bridge/codecs/approval_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/approval_views.dart' as node;
import 'package:agent_orchestration/bridge/codecs/workflow_views.dart' as node;
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/diff_line.dart';

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

DiffLine _mapDiffLineFromNode(node.DiffLine line) {
  final DiffLineChange change = switch (line.change) {
    node.DiffLineChange.unchanged => DiffLineChange.unchanged,
    node.DiffLineChange.added => DiffLineChange.added,
    node.DiffLineChange.removed => DiffLineChange.removed,
  };
  return DiffLine(change: change, text: line.text);
}

SkillChangePreview? _mapSkillChangePreviewFromNode(
  node.SkillChangeView? skillChange,
) {
  if (skillChange == null) {
    return null;
  }

  return SkillChangePreview(
    skillName: skillChange.skillName,
    lines: <DiffLine>[
      for (final node.DiffLine line in skillChange.changes)
        _mapDiffLineFromNode(line),
    ],
  );
}

ApprovalAction mapApprovalActionFromNode(
  node.ApprovalAction action, {
  required node.SkillChangeView? skillChange,
}) {
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
    node.RunCommand() => RunCommandAction(
      tool: action.tool,
      command: action.command,
    ),
    node.ImproveSkill() => ImproveSkillAction(
      skillId: action.skillId,
      summary: action.summary,
      preview: _mapSkillChangePreviewFromNode(skillChange),
    ),
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

ApprovalRequest mapApprovalViewFromNode(node.ApprovalView view) {
  final node.ApprovalRequest request = view.approval;
  final node.SignedDecision? wireDecision = request.decision;
  final SignedDecision? decision = wireDecision == null
      ? null
      : mapSignedDecisionFromNode(wireDecision);

  return ApprovalRequest(
    id: request.id,
    runId: request.runId,
    action: mapApprovalActionFromNode(
      request.action,
      skillChange: view.skillChange,
    ),
    requestedBy: request.requestedBy,
    requestedAt: request.requestedAt,
    decision: decision,
  );
}
