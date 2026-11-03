import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';

final class KeptBranch {
  const KeptBranch({
    required this.repositoryAddress,
    required this.branch,
    required this.runner,
  });

  final String repositoryAddress;
  final String branch;
  final DeviceId runner;
}

List<KeptBranch> findKeptBranches({
  required Run run,
  required List<ApprovalRequest> approvals,
}) {
  if (run.status != RunStatus.done) {
    return const <KeptBranch>[];
  }

  final Map<String, KeptBranch?> keptBranchByRepository =
      <String, KeptBranch?>{};
  for (final ApprovalRequest approval in approvals) {
    final ApprovalAction action = approval.action;
    final SignedDecision? signedDecision = approval.decision;
    final bool isDecidedPushOfRun =
        approval.runId == run.id &&
        action is PushCommitsAction &&
        signedDecision != null;
    if (!isDecidedPushOfRun) {
      continue;
    }

    final bool isDenied = signedDecision.decision == ApprovalDecision.denied;
    keptBranchByRepository[action.repository] = isDenied
        ? KeptBranch(
            repositoryAddress: action.repository,
            branch: action.branch,
            runner: approval.requestedBy,
          )
        : null;
  }

  return List<KeptBranch>.unmodifiable(<KeptBranch>[
    for (final KeptBranch? kept in keptBranchByRepository.values) ?kept,
  ]);
}
